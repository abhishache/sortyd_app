// MARK: - ContentView.swift
// Sortyd v4 — Root (Theme-Aware Tab Bar) + AI Coach Tab

import SwiftUI
import FirebaseAnalytics

struct ContentView: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("sortyd_has_seen_onboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false

    init() {
        updateAppearance()
    }

    var body: some View {
        TabView(selection: $vm.selectedTab) {
            HomeView()
                .environmentObject(vm)
                .environmentObject(ThemeManager.shared)
                .tabItem { Label(vm.localized("Today"), systemImage: vm.selectedTab == 0 ? "checkmark.circle.fill" : "checkmark.circle") }
                .tag(0)

            ListManagementView()
                .environmentObject(vm)
                .environmentObject(ThemeManager.shared)
                .tabItem { Label(vm.localized("Lists"), systemImage: vm.selectedTab == 1 ? "list.bullet.circle.fill" : "list.bullet.circle") }
                .tag(1)

            AnalyticsView()
                .environmentObject(vm)
                .environmentObject(ThemeManager.shared)
                .tabItem { Label(vm.localized("Analytics"), systemImage: vm.selectedTab == 2 ? "chart.line.uptrend.xyaxis.circle.fill" : "chart.line.uptrend.xyaxis.circle") }
                .tag(2)

            AICoachView()
                .environmentObject(vm)
                .environmentObject(ThemeManager.shared)
                .tabItem { Label(vm.localized("Coach"), systemImage: vm.selectedTab == 3 ? "brain.head.profile" : "brain.head.profile") }
                .tag(3)
        }
        .tint(Theme.accent)
        .onReceive(ThemeManager.shared.$isDark) { _ in
            DispatchQueue.main.async { updateAppearance() }
        }
        .onAppear {
            if !hasSeenOnboarding { showOnboarding = true }
        }
        .overlay {
            if showOnboarding {
                OnboardingShowcaseView {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        showOnboarding = false
                    }
                    hasSeenOnboarding = true
                    Analytics.logEvent("onboarding_completed", parameters: nil)
                    vm.selectedTab = 0
                }
                .transition(.opacity)
            }
        }
    }
}

private func updateAppearance() {
    let isDark = ThemeManager.shared.isDark

    let tab = UITabBarAppearance()
    tab.configureWithOpaqueBackground()
    tab.backgroundColor = UIColor(Theme.bg1)
    tab.shadowColor = UIColor.clear

    let unselected = UITabBarItemAppearance()
    unselected.normal.iconColor = UIColor(Theme.text2)
    unselected.normal.titleTextAttributes = [.foregroundColor: UIColor(Theme.text2)]
    tab.stackedLayoutAppearance       = unselected
    tab.inlineLayoutAppearance        = unselected
    tab.compactInlineLayoutAppearance = unselected

    UITabBar.appearance().standardAppearance   = tab
    UITabBar.appearance().scrollEdgeAppearance = tab

    let nav = UINavigationBarAppearance()
    nav.configureWithOpaqueBackground()
    nav.backgroundColor = UIColor(Theme.bg0)
    nav.shadowColor = .clear
    nav.largeTitleTextAttributes = [
        .foregroundColor: UIColor(Theme.text0),
        .font: UIFont.systemFont(ofSize: 28, weight: .black)
    ]
    nav.titleTextAttributes = [
        .foregroundColor: UIColor(Theme.text0),
        .font: UIFont.systemFont(ofSize: 16, weight: .bold)
    ]
    UINavigationBar.appearance().standardAppearance   = nav
    UINavigationBar.appearance().scrollEdgeAppearance = nav

    let _ = isDark
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel())
        .environmentObject(ThemeManager.shared)
}
