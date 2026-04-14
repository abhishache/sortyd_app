// MARK: - SortydApp.swift
// Sortyd v4 — Fixed: onOpenURL handler for widget deep links, single reset on launch

import SwiftUI

@main
struct SortydApp: App {
    @ObservedObject var themeManager = ThemeManager.shared
    @StateObject private var vm = AppViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ThemeManager.shared)
                .environmentObject(vm)
                .preferredColorScheme(ThemeManager.shared.colorScheme)
                .onAppear {
                    _ = WatchSessionManager.shared
                    vm.setupHealthAutoComplete()

                    // Schedule the 5:30 PM daily performance summary.
                    // Passes live lists + snapshots so the notification body
                    // reflects today's real progress, not generic placeholder text.
                    // Silent — only fires if the user has already granted permission.
                    let lists     = vm.lists
                    let snapshots = vm.snapshots
                    Task {
                        await NotificationManager.shared.scheduleDailySummaryIfPermitted(
                            lists:     lists,
                            snapshots: snapshots
                        )
                    }
                }
                // FIX: resetTasksIfNewDay is called here ONLY — not in AppViewModel.init().
                // On cold launch scenePhase transitions to .active immediately, so the
                // init() call and this handler were both firing in the same RunLoop tick.
                // That caused a double daily-reset: snapshots written twice for yesterday,
                // and in rare cases the tasks were cleared then a stale snapshot was written
                // on top of it. Now init() does not call reset; only this handler does.
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        vm.reloadFromDisk()      // re-sync widget/intent writes before reset
                        vm.resetTasksIfNewDay()
                    }
                    if newPhase == .background {
                        vm.flushToDisk()         // force write before iOS suspends
                    }
                }
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
                        vm.selectedTab = 0
                    }
                }
        }
    }
}
