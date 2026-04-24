// WatchSessionManager.swift
// Add this file to your MAIN iOS Sortyd target (not the Watch target).
// It listens for Watch requests and pushes AppData updates automatically.

import Foundation
import Combine
import WatchConnectivity

@MainActor
final class WatchSessionManager: NSObject, ObservableObject {

    static let shared = WatchSessionManager()

    private let suiteName = "group.com.sortyd.sortyd"
    private let dataKey   = "sortyd_app_data_v3"

    private var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
    }

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // Call this whenever AppData changes on the iPhone side
    func pushToWatch(_ data: AppData) {
        guard WCSession.default.isPaired,
              WCSession.default.isWatchAppInstalled,
              let encoded = try? JSONEncoder().encode(data) else { return }

        // Use updateApplicationContext so Watch gets it on next wrist raise
        try? WCSession.default.updateApplicationContext(["appData": encoded])

        // Also send directly if reachable (Watch foregrounded)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["appData": encoded], replyHandler: nil, errorHandler: nil)
        }
    }

    func pushLanguageToWatch(_ langCode: String) {
        guard WCSession.default.isPaired,
              WCSession.default.isWatchAppInstalled else { return }

        try? WCSession.default.updateApplicationContext(["appLanguage": langCode])

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["appLanguage": langCode], replyHandler: nil, errorHandler: nil)
        }
    }

    private func currentAppData() -> AppData {
        guard
            let raw     = defaults.data(forKey: dataKey),
            let decoded = try? JSONDecoder().decode(AppData.self, from: raw)
        else { return AppData() }
        return decoded
    }

    private func save(_ data: AppData) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: dataKey)
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    // Watch requested latest data
    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        if message["request"] as? String == "appData" {
            Task { @MainActor in
                let data = self.currentAppData()
                let lang = UserDefaults.standard.string(forKey: "sortyd_app_language") ?? "en"
                var reply: [String: Any] = ["appLanguage": lang]
                if let encoded = try? JSONEncoder().encode(data) {
                    reply["appData"] = encoded
                }
                replyHandler(reply)
            }
        }
    }

    // Watch toggled a task while phone was foregrounded
    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any]) {
        guard let raw = message["appData"] as? Data else { return }
        Task { @MainActor in
            if let decoded = try? JSONDecoder().decode(AppData.self, from: raw) {
                self.save(decoded)
                NotificationCenter.default.post(name: .watchDidUpdateAppData, object: nil)
            }
        }
    }

    // Watch toggled a task while phone was backgrounded — arrives via application context
    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext context: [String: Any]) {
        guard let raw = context["appData"] as? Data else { return }
        Task { @MainActor in
            if let decoded = try? JSONDecoder().decode(AppData.self, from: raw) {
                self.save(decoded)
                NotificationCenter.default.post(name: .watchDidUpdateAppData, object: nil)
            }
        }
    }
}

extension Notification.Name {
    static let watchDidUpdateAppData = Notification.Name("watchDidUpdateAppData")
}
