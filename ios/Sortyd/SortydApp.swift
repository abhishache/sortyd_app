// MARK: - SortydApp.swift
// Sortyd v4 — Fixed: onOpenURL handler for widget deep links, single reset on launch

import SwiftUI
import Firebase
import FirebaseCrashlytics
#if os(iOS)
import Clarity
#endif

@main
struct SortydApp: App {
    @ObservedObject var themeManager = ThemeManager.shared
    @StateObject private var vm = AppViewModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        FirebaseApp.configure()
        Crashlytics.crashlytics().log("Application configured")
        _ = ReviewPromptManager.shared.installDate

        #if os(iOS)
        // Clarity records interaction paths while the UI is masked below.
        ClaritySDK.initialize(config: ClarityConfig(projectId: "ybfdycps9e"))
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .sortydClarityMask()
                #if os(macOS)
                .frame(minWidth: 1020, minHeight: 680)
                #else
                .frame(minWidth: 420, minHeight: 640)
                #endif
                .onAppear {
                    #if DEBUG
                    // Explicit local QA modes. Neither entry point exists in release builds.
                    if let languageArgument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--qa-language=") }),
                       let language = AppLanguage(rawValue: String(languageArgument.dropFirst("--qa-language=".count))) {
                        vm.setLanguage(language)
                    }
                    if ProcessInfo.processInfo.arguments.contains("--qa-review-prompt") {
                        vm.showReviewPrompt = true
                    }
                    if ProcessInfo.processInfo.arguments.contains("--qa-crashlytics") {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            fatalError("Sortyd diagnostic integration test")
                        }
                    }
                    #endif
                    #if os(iOS)
                    _ = WatchSessionManager.shared
                    #endif
                    vm.cancelLegacyNotifications()

                    // Let the first screen render before non-urgent startup work.
                    Task {
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        await MainActor.run {
                            vm.setupHealthAutoComplete()
                        }

                        let lists = vm.lists
                        let snapshots = vm.snapshots
                        await NotificationManager.shared.scheduleDailySummaryIfPermitted(
                            lists: lists,
                            snapshots: snapshots
                        )
                        await NotificationManager.shared.scheduleColdTaskNudgeIfPermitted(
                            lists: lists,
                            snapshots: snapshots
                        )
                    }
                }
                // Init resets before taking snapshots. This idempotent foreground check
                // also handles a new logical day after suspension.
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        vm.reloadFromDisk()      // re-sync widget/intent writes before reset
                        vm.resetTasksIfNewDay()

                        let lists     = vm.lists
                        let snapshots = vm.snapshots
                        Task {
                            await NotificationManager.shared.scheduleColdTaskNudgeIfPermitted(
                                lists:     lists,
                                snapshots: snapshots
                            )
                        }
                    }
                    if newPhase == .background {
                        vm.flushToDisk()         // force write before iOS suspends
                    }
                }
                .overlay {
                    if vm.showReviewPrompt {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture { vm.handleReviewRemindLater() }
                            .transition(.opacity.animation(.easeInOut(duration: 0.2)))

                        ReviewPromptCard(
                            onReviewTapped: { vm.handleReviewNow() },
                            onDismissed:    { vm.handleReviewRemindLater() }
                        )
                        .onAppear { vm.recordReviewPromptDisplayed() }
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.9).combined(with: .opacity),
                                removal:   .scale(scale: 0.95).combined(with: .opacity)
                            )
                            .animation(.spring(response: 0.35, dampingFraction: 0.8))
                        )
                        .zIndex(999)
                    }
                }
                #if os(iOS)
                // Watch toggled a task — reload AppViewModel so views refresh immediately
                .onReceive(NotificationCenter.default.publisher(for: .watchDidUpdateAppData)) { _ in
                    vm.reloadFromDisk()
                }
                #endif
                // FIX: onOpenURL handler added.
                //
                // WidgetLarge.swift emits Link(destination: URL(string: "sortyd://open")!)
                // but there was no handler in the app to receive it. The URL was silently
                // dropped by the system, so tapping the widget opened the app to whatever
                // tab happened to be foregrounded last — not the Today tab.
                //
                // This handler navigates to tab 0 (Today) for any sortyd:// URL,
                // which is the expected behaviour for a habit-tracking widget tap.
                // Extend the path/host matching here if you add more widget link types.
                .onOpenURL { url in
                    guard url.scheme == "sortyd" else { return }
                    // Small async hop so the scene is fully active before tab switch.
                    DispatchQueue.main.async {
                        vm.handleURL(url)
                    }
                }
                // These values must cover the complete tree, including the review overlay.
                .environmentObject(themeManager)
                .environmentObject(vm)
                .preferredColorScheme(themeManager.colorScheme)
                .environment(\.locale, vm.appLanguage.locale)
                .environment(\.layoutDirection, vm.appLanguage.isRTL ? .rightToLeft : .leftToRight)
        }
        #if os(macOS)
        .defaultSize(width: 1240, height: 820)
        .windowStyle(.hiddenTitleBar)
        #endif

        #if os(macOS)
        MenuBarExtra {
            SortydMenuBarPopoverView()
                .environmentObject(vm)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
        } label: {
            let pct = Int(((vm.activeList?.completionFraction ?? 0) * 100).rounded())
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill")
                Text("\(pct)%")
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
