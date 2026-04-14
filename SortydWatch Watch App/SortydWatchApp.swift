// SortydWatchApp.swift
// Sortyd — Apple Watch App Entry Point

import SwiftUI

@main
struct SortydWatchApp: App {
    @StateObject private var store = WatchStore()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(store)
        }
    }
}
