// WatchContentView.swift
// Sortyd Watch — Root view with tab navigation

import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject var store: WatchStore

    var body: some View {
        if store.appData.lists.isEmpty {
            EmptyWatchView()
        } else {
            TabView {
                WatchTaskListView()
                WatchProgressView()
            }
            .tabViewStyle(.page)
        }
    }
}
