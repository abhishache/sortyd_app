// MARK: - AuthService.swift
// Sortyd — Cloud Authentication & Supabase Data Sync Service
// Uses masked sortyd.com domains (https://auth.sortyd.com & https://api.sortyd.com)
// backed by Sortyd's Supabase PostgreSQL database.

import Foundation
import Combine
import SwiftUI
import AuthenticationServices
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct UserProfile: Codable, Identifiable, Equatable {
    let id: String
    let email: String
    let name: String
    var createdAt: String?
}

final class WebAuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(macOS)
        return NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? ASPresentationAnchor()
        #elseif os(iOS)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            if let keyWindow = scene.windows.first(where: { $0.isKeyWindow }) {
                return keyWindow
            }
        }
        return scenes.first?.windows.first ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    private let baseURL = URL(string: "https://api.sortyd.com")!
    private let authURL = URL(string: "https://auth.sortyd.com")!
    private let tokenKey = "sortyd_auth_token"
    private let userKey  = "sortyd_auth_user"
    private let lastSyncKey = "sortyd_last_sync_timestamp"

    @Published private(set) var currentUser: UserProfile?
    @Published private(set) var authToken: String?
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var lastSyncDate: Date?
    @Published var syncErrorMessage: String?

    private var activeWebAuthSession: ASWebAuthenticationSession?

    var isAuthenticated: Bool {
        currentUser != nil && authToken != nil
    }

    private var sourceDeviceLabel: String {
        #if os(macOS)
        return Host.current().localizedName ?? "Sortyd for Mac"
        #elseif os(iOS)
        return UIDevice.current.name
        #else
        return "Sortyd Device"
        #endif
    }

    private var defaults: UserDefaults {
        UserDefaults(suiteName: "group.com.sortyd.sortyd") ?? UserDefaults.standard
    }

    private init() {
        if let token = defaults.string(forKey: tokenKey), !token.isEmpty {
            self.authToken = token
            if let userData = defaults.data(forKey: userKey),
               let user = try? JSONDecoder().decode(UserProfile.self, from: userData) {
                self.currentUser = user
            }
        }
        if let syncTime = defaults.object(forKey: lastSyncKey) as? Date {
            self.lastSyncDate = syncTime
        }

        if authToken != nil {
            Task { await verifySession() }
        }
    }

    // MARK: - Authentication API (Masked via auth.sortyd.com / api.sortyd.com)

    func signUp(email: String, password: String, name: String) async throws {
        let url = authURL.appendingPathComponent("api/auth/signup")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: String] = [
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
            "password": password,
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "AuthService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Network error"])
        }

        if http.statusCode != 200 {
            let errorMsg = parseErrorMessage(data) ?? "Sign up failed (code \(http.statusCode))"
            throw NSError(domain: "AuthService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }

        struct AuthResponse: Codable {
            let token: String
            let user: UserProfile
        }

        let decoded = try JSONDecoder().decode(AuthResponse.self, from: data)
        saveSession(token: decoded.token, user: decoded.user)
    }

    func signIn(email: String, password: String) async throws {
        let url = authURL.appendingPathComponent("api/auth/signin")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: String] = [
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
            "password": password
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "AuthService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Network error"])
        }

        if http.statusCode != 200 {
            let errorMsg = parseErrorMessage(data) ?? "Invalid email or password"
            throw NSError(domain: "AuthService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }

        struct AuthResponse: Codable {
            let token: String
            let user: UserProfile
        }

        let decoded = try JSONDecoder().decode(AuthResponse.self, from: data)
        saveSession(token: decoded.token, user: decoded.user)
    }

    func signInWithApple(userIdentifier: String, email: String?, fullName: String?) async throws {
        let url = authURL.appendingPathComponent("api/auth/apple")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: String] = ["userIdentifier": userIdentifier]
        if let email { payload["email"] = email }
        if let fullName { payload["fullName"] = fullName }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "AuthService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Network error"])
        }

        if http.statusCode != 200 {
            let errorMsg = parseErrorMessage(data) ?? "Apple Sign In failed"
            throw NSError(domain: "AuthService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }

        struct AuthResponse: Codable {
            let token: String
            let user: UserProfile
        }

        let decoded = try JSONDecoder().decode(AuthResponse.self, from: data)
        saveSession(token: decoded.token, user: decoded.user)
    }

    /// Masked Google OAuth Sign-In via https://auth.sortyd.com/oauth/google
    /// Shows "Sortyd Wants to Use sortyd.com to Sign In" — never exposing raw supabase.co URLs.
    func signInWithGoogle() async throws {
        let callbackScheme = "com.sortyd.sortyd"
        var components = URLComponents(url: authURL.appendingPathComponent("oauth/google"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "redirect_uri", value: "\(callbackScheme)://auth/callback")
        ]
        guard let startURL = components.url else {
            throw NSError(domain: "AuthService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid auth URL"])
        }

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: startURL,
                callbackURLScheme: callbackScheme
            ) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "AuthService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Google Sign-In was cancelled."]
                    ))
                }
            }
            session.presentationContextProvider = WebAuthContextProvider.shared
            session.prefersEphemeralWebBrowserSession = false
            self.activeWebAuthSession = session
            session.start()
        }

        self.activeWebAuthSession = nil
        guard let queryItems = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems,
              let token = queryItems.first(where: { $0.name == "token" })?.value,
              let id = queryItems.first(where: { $0.name == "id" })?.value,
              let email = queryItems.first(where: { $0.name == "email" })?.value else {
            throw NSError(domain: "AuthService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not complete Google Sign-In."])
        }

        let name = queryItems.first(where: { $0.name == "name" })?.value ?? email.components(separatedBy: "@").first ?? "Sortyd Member"
        let profile = UserProfile(id: id, email: email, name: name, createdAt: nil)
        saveSession(token: token, user: profile)
    }

    func signOut() {
        self.authToken = nil
        self.currentUser = nil
        self.lastSyncDate = nil
        defaults.removeObject(forKey: tokenKey)
        defaults.removeObject(forKey: userKey)
        defaults.removeObject(forKey: lastSyncKey)
    }

    private func verifySession() async {
        guard let token = authToken else { return }
        let url = baseURL.appendingPathComponent("api/auth/me")
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                struct MeResponse: Codable { let user: UserProfile }
                if let decoded = try? JSONDecoder().decode(MeResponse.self, from: data) {
                    self.currentUser = decoded.user
                }
            } else if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                signOut()
            }
        } catch {
            // Keep existing credentials offline
        }
    }

    // MARK: - Cloud Data Sync API (Supabase-backed via api.sortyd.com)

    @discardableResult
    func pushData(_ appData: AppData, allowDelete: Bool = true) async -> AppData? {
        guard let token = authToken, isAuthenticated else { return nil }
        isSyncing = true
        defer { isSyncing = false }

        let url = baseURL.appendingPathComponent("api/user/sync")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(appData)
            let payload: [String: Any] = [
                "data": try JSONSerialization.jsonObject(with: jsonData),
                "allowDelete": allowDelete,
                "sourceDevice": sourceDeviceLabel
            ]
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                let now = Date()
                self.lastSyncDate = now
                self.syncErrorMessage = nil
                defaults.set(now, forKey: lastSyncKey)

                struct PushResponse: Codable {
                    let data: AppData?
                }
                if let decoded = try? JSONDecoder().decode(PushResponse.self, from: data) {
                    return decoded.data
                }
            }
        } catch {
            self.syncErrorMessage = error.localizedDescription
        }
        return nil
    }

    func pullData() async throws -> AppData? {
        guard let token = authToken, isAuthenticated else { return nil }
        isSyncing = true
        defer { isSyncing = false }

        let url = baseURL.appendingPathComponent("api/user/sync")
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "AuthService", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "Failed to download cloud data"])
        }

        struct SyncResponse: Codable {
            let data: AppData?
            let updatedAt: String?
        }

        let decoded = try JSONDecoder().decode(SyncResponse.self, from: data)
        if decoded.data != nil {
            let now = Date()
            self.lastSyncDate = now
            defaults.set(now, forKey: lastSyncKey)
        }
        return decoded.data
    }

    // MARK: - Helpers

    private func saveSession(token: String, user: UserProfile) {
        self.authToken = token
        self.currentUser = user
        defaults.set(token, forKey: tokenKey)
        if let encoded = try? JSONEncoder().encode(user) {
            defaults.set(encoded, forKey: userKey)
        }
    }

    private func parseErrorMessage(_ data: Data) -> String? {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let err = obj["error"] as? String {
            return err
        }
        return nil
    }
}
