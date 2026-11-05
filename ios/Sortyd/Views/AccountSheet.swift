// MARK: - AccountSheet.swift
// Sortyd — Cloud Account & Multi-Platform Sync (Backed by sortyd.com + Supabase)

import SwiftUI
import AuthenticationServices

struct AccountSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @StateObject private var auth = AuthService.shared

    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var fullName = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showSignOutConfirm = false

    private var localRegularListCount: Int {
        vm.lists.filter { !$0.isTodo && !$0.isWeekly && !$0.isArchived }.count
    }

    private var localTotalTaskCount: Int {
        vm.lists.reduce(0) { $0 + $1.tasks.count }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg0.ignoresSafeArea()

                // Ambient glass glow
                Circle()
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 280, height: 280)
                    .blur(radius: 70)
                    .offset(x: -110, y: -180)
                    .allowsHitTesting(false)

                Circle()
                    .fill(Theme.indigo.opacity(0.14))
                    .frame(width: 260, height: 260)
                    .blur(radius: 70)
                    .offset(x: 120, y: 160)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    // Explicit in-view header bar so Cancel/Close is always visible on macOS & iOS
                    HStack {
                        Text(auth.isAuthenticated ? vm.localized("Sortyd Cloud") : (isSignUp ? vm.localized("Create Account") : vm.localized("Sign In")))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.text0)

                        Spacer()

                        Button {
                            dismiss()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                Text(vm.localized("Close"))
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(Theme.text1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Theme.bg2)
                                    .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 0.8))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                    Divider().background(Color.white.opacity(0.08))

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            if auth.isAuthenticated, let user = auth.currentUser {
                                authenticatedView(user: user)
                            } else {
                                unauthenticatedView
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 18)
                    }
                }
            }
            .navigationTitle(auth.isAuthenticated ? vm.localized("Sortyd Cloud") : (isSignUp ? vm.localized("Create Account") : vm.localized("Sign In")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(vm.localized("Close")) { dismiss() }
                        .foregroundColor(Theme.text2)
                }
            }
            .confirmationDialog(
                vm.localized("Sign out of Sortyd?"),
                isPresented: $showSignOutConfirm,
                titleVisibility: .visible
            ) {
                Button(vm.localized("Sign Out"), role: .destructive) {
                    auth.signOut()
                }
                Button(vm.localized("Cancel"), role: .cancel) {}
            } message: {
                Text(vm.localized("Your local habit lists will remain on this device, but won't sync to your other devices until you sign back in."))
            }
        }
        #if os(macOS)
        .frame(width: 440, height: auth.isAuthenticated ? 460 : 540)
        #endif
    }

    // MARK: - Authenticated View

    private func authenticatedView(user: UserProfile) -> some View {
        VStack(spacing: 12) {
            // Compact Profile Card
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.accent.opacity(0.38), Theme.indigo.opacity(0.28)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)
                        .overlay(Circle().stroke(Theme.accent.opacity(0.55), lineWidth: 1.5))

                    Text(initials(for: user.name.isEmpty ? user.email : user.name))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.text0)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(user.name.isEmpty ? "Sortyd Member" : user.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.text0)

                    Text(user.email)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.text2)

                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.accent)
                        Text("sortyd.com • Verified Cloud")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.accent)
                    }
                    .padding(.top, 2)
                }
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Theme.accent.opacity(0.45), Color.white.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )

            // Synced Stats Summary
            HStack(spacing: 12) {
                syncedMetricPill(value: "\(localRegularListCount)", label: vm.localized("Habit Lists"), icon: "list.bullet.rectangle.portrait.fill", tint: Theme.accent)
                syncedMetricPill(value: "\(localTotalTaskCount)", label: vm.localized("Total Tasks"), icon: "checkmark.circle.fill", tint: Theme.indigo)
                syncedMetricPill(value: "\(vm.snapshots.count)", label: vm.localized("Snapshots"), icon: "flame.fill", tint: Theme.coral)
            }

            // Cloud Sync Status Card
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: auth.isSyncing ? "arrow.triangle.2.circlepath" : "icloud.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.accent)
                        .rotationEffect(.degrees(auth.isSyncing ? 360 : 0))
                        .animation(auth.isSyncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: auth.isSyncing)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.localized("Cloud Sync Active"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.text0)

                        Text(syncStatusText)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.text2)
                    }

                    Spacer()

                    if auth.isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }

                Divider().background(Color.white.opacity(0.08))

                Text(vm.localized("Your habit lists, task history, and weekly plans are backed up to Sortyd Cloud (sortyd.com) and synced across macOS, iOS, and Android."))
                    .font(.system(size: 12))
                    .foregroundColor(Theme.text2)
                    .lineSpacing(2)

                Button(action: {
                    Task {
                        await vm.syncWithCloud()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .semibold))
                        Text(auth.isSyncing ? vm.localized("Syncing...") : vm.localized("Sync Now"))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.accent.opacity(0.16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Theme.accent.opacity(0.45), lineWidth: 1)
                            )
                    )
                    .foregroundColor(Theme.accent)
                }
                .buttonStyle(.plain)
                .disabled(auth.isSyncing)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )

            // Sign Out Button
            Button(action: { showSignOutConfirm = true }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                    Text(vm.localized("Sign Out"))
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(Theme.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.danger.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Theme.danger.opacity(0.22), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
    }

    private func syncedMetricPill(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(tint)
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.text0)
            }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.text2)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - Unauthenticated View

    private var unauthenticatedView: some View {
        VStack(spacing: 18) {
            // Header icon
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.accent.opacity(0.24), Theme.indigo.opacity(0.20)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 68, height: 68)
                        .overlay(Circle().strokeBorder(Theme.accent.opacity(0.4), lineWidth: 1))
                    Image(systemName: "icloud.and.arrow.up.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(Theme.accent)
                }

                Text(vm.localized("Sync Across Mac, iOS & Android"))
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.text0)

                Text(vm.localized("Sign in via sortyd.com to back up your habit lists, streaks, and weekly plans everywhere."))
                    .font(.system(size: 13))
                    .foregroundColor(Theme.text2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            .padding(.top, 2)

            // Safe Local List Migration Banner
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.accent)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.localized("Automatic List Preservation"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.text0)
                    Text("Your \(localRegularListCount) existing habit list\(localRegularListCount == 1 ? "" : "s") and \(localTotalTaskCount) task\(localTotalTaskCount == 1 ? "" : "s") on this device will automatically merge into your account.")
                        .font(.system(size: 11.5))
                        .foregroundColor(Theme.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.accent.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Theme.accent.opacity(0.25), lineWidth: 1)
                    )
            )

            // Quick Social Sign-In Buttons (Google + Apple)
            VStack(spacing: 10) {
                Button(action: handleGoogleSignIn) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 22, height: 22)
                            Text("G")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(red: 0.26, green: 0.52, blue: 0.96))
                        }
                        Text(vm.localized("Continue with Google"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.text0)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLoading)

                SignInWithAppleButton(
                    .continue,
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: handleAppleSignIn
                )
                .signInWithAppleButtonStyle(.white)
                .frame(height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }

            // Divider
            HStack {
                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                Text(vm.localized("OR CONTINUE WITH EMAIL"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.text2)
                    .padding(.horizontal, 8)
                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
            }

            // Segmented mode picker
            HStack(spacing: 4) {
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isSignUp = false; errorMessage = nil } }) {
                    Text(vm.localized("Sign In"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(!isSignUp ? Theme.text0 : Theme.text2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(!isSignUp ? Theme.accent.opacity(0.22) : Color.clear)
                        )
                }
                .buttonStyle(.plain)

                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isSignUp = true; errorMessage = nil } }) {
                    Text(vm.localized("Create Account"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSignUp ? Theme.text0 : Theme.text2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(isSignUp ? Theme.accent.opacity(0.22) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.bg1)
            )

            // Error Message
            if let error = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Theme.danger)
                        .font(.system(size: 13))
                    Text(error)
                        .font(.system(size: 12.5))
                        .foregroundColor(Theme.danger)
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.danger.opacity(0.12))
                )
            }

            // Input Fields
            VStack(spacing: 10) {
                if isSignUp {
                    fieldContainer(icon: "person.fill", placeholder: vm.localized("Full Name")) {
                        TextField(vm.localized("Full Name"), text: $fullName)
                            .textFieldStyle(.plain)
                            .foregroundColor(Theme.text0)
                    }
                }

                fieldContainer(icon: "envelope.fill", placeholder: vm.localized("Email address")) {
                    TextField(vm.localized("Email address"), text: $email)
                        .textFieldStyle(.plain)
                        .foregroundColor(Theme.text0)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                }

                fieldContainer(icon: "lock.fill", placeholder: vm.localized("Password")) {
                    SecureField(vm.localized("Password (min 6 characters)"), text: $password)
                        .textFieldStyle(.plain)
                        .foregroundColor(Theme.text0)
                }
            }

            // Submit Button
            Button(action: submitForm) {
                HStack {
                    if isLoading {
                        ProgressView().tint(.black)
                    } else {
                        Text(isSignUp ? vm.localized("Create Account & Sync Lists") : vm.localized("Sign In & Merge Lists"))
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Theme.accent)
                )
                .foregroundColor(.black)
            }
            .buttonStyle(.plain)
            .disabled(isLoading || email.isEmpty || password.count < 6 || (isSignUp && fullName.isEmpty))
            .opacity((isLoading || email.isEmpty || password.count < 6 || (isSignUp && fullName.isEmpty)) ? 0.5 : 1.0)
        }
    }

    // MARK: - Helper Views

    private func fieldContainer<Content: View>(icon: String, placeholder: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Theme.text2)
                .frame(width: 20)

            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private var syncStatusText: String {
        if auth.isSyncing {
            return vm.localized("Syncing your data...")
        } else if let date = auth.lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return String(format: vm.localized("Last synced %@"), formatter.localizedString(for: date, relativeTo: Date()))
        } else {
            return vm.localized("Connected to sortyd.com")
        }
    }

    private func initials(for text: String) -> String {
        let parts = text.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(text.prefix(2)).uppercased()
    }

    // MARK: - Actions

    private func submitForm() {
        errorMessage = nil
        isLoading = true

        Task {
            do {
                if isSignUp {
                    try await auth.signUp(email: email, password: password, name: fullName)
                } else {
                    try await auth.signIn(email: email, password: password)
                }
                await vm.syncWithCloud()
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func handleGoogleSignIn() {
        errorMessage = nil
        isLoading = true
        Task {
            do {
                try await auth.signInWithGoogle()
                await vm.syncWithCloud()
                isLoading = false
            } catch {
                isLoading = false
                let nsErr = error as NSError
                if nsErr.code != ASWebAuthenticationSessionError.canceledLogin.rawValue {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userIdentifier = appleIDCredential.user
                let appleEmail = appleIDCredential.email
                let name = [appleIDCredential.fullName?.givenName, appleIDCredential.fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                isLoading = true
                Task {
                    do {
                        try await auth.signInWithApple(
                            userIdentifier: userIdentifier,
                            email: appleEmail,
                            fullName: name.isEmpty ? nil : name
                        )
                        await vm.syncWithCloud()
                        isLoading = false
                    } catch {
                        isLoading = false
                        errorMessage = error.localizedDescription
                    }
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}
