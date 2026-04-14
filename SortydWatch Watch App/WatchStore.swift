// WatchStore.swift
// Sortyd Watch — Source of truth, reads/writes shared App Group UserDefaults
// Uses the exact same keys as PersistenceManager on iOS so data stays in sync.

import Foundation
import Combine
import SwiftUI
import WatchConnectivity

// ── Shared models (copy of iOS Models.swift, kept identical) ─────────────────

struct SortydTask: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    var weight: Double = 0.0
    var reminderTime: Date? = nil

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: SortydTask, rhs: SortydTask) -> Bool { lhs.id == rhs.id }
}

struct TaskList: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var emoji: String = "📋"
    var tasks: [SortydTask]
    var createdAt: Date = Date()

    var completionFraction: Double {
        guard !tasks.isEmpty else { return 0 }
        return tasks.filter(\.isCompleted).reduce(0) { $0 + $1.weight }
    }
    var completionPercentage: Int { Int((completionFraction * 100).rounded()) }
}

struct AppData: Codable {
    var lists: [TaskList] = []
    var activeListID: UUID?
    var snapshots: [DailySnapshot] = []

    var activeList: TaskList? {
        guard let id = activeListID else { return lists.first }
        return lists.first(where: { $0.id == id }) ?? lists.first
    }
}

struct DailySnapshot: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date
    var listID: UUID
    var completionFraction: Double
    var completedTaskIDs: [UUID]
}

// ── Store ─────────────────────────────────────────────────────────────────────

@MainActor
final class WatchStore: NSObject, ObservableObject {

    // MARK: Published
    @Published var appData: AppData = AppData()
    @Published var isSyncing: Bool = false

    // MARK: Private
    private let suiteName = "group.com.sortyd.sortyd"
    private let dataKey   = "sortyd_app_data_v3"

    private var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
    }

    // MARK: Init
    override init() {
        super.init()
        appData = load()
        setupWatchConnectivity()
    }

    // MARK: Public API

    var activeList: TaskList? { appData.activeList }

    func toggleTask(_ task: SortydTask) {
        guard
            let listIdx = activeListIndex,
            let taskIdx = appData.lists[listIdx].tasks.firstIndex(where: { $0.id == task.id })
        else { return }

        appData.lists[listIdx].tasks[taskIdx].isCompleted.toggle()
        save(appData)
        sendToPhone()
    }

    func refresh() {
        appData = load()
        requestFromPhone()
    }

    // MARK: Private helpers

    private var activeListIndex: Int? {
        guard let id = appData.activeListID else {
            return appData.lists.isEmpty ? nil : 0
        }
        return appData.lists.firstIndex(where: { $0.id == id })
    }

    private func load() -> AppData {
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

    // MARK: WatchConnectivity

    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private func requestFromPhone() {
        guard WCSession.default.isReachable else { return }
        isSyncing = true
        WCSession.default.sendMessage(["request": "appData"], replyHandler: { [weak self] reply in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let raw = reply["appData"] as? Data,
                   let decoded = try? JSONDecoder().decode(AppData.self, from: raw) {
                    self.appData = decoded
                    self.save(decoded)
                }
                self.isSyncing = false
            }
        }, errorHandler: { [weak self] _ in
            Task { @MainActor [weak self] in self?.isSyncing = false }
        })
    }

    private func sendToPhone() {
        guard WCSession.default.isReachable,
              let encoded = try? JSONEncoder().encode(appData) else { return }
        WCSession.default.sendMessage(["appData": encoded], replyHandler: nil, errorHandler: nil)
    }
}

// MARK: - WCSessionDelegate
extension WatchStore: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {
        Task { @MainActor in requestFromPhone() }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any]) {
        guard let raw = message["appData"] as? Data,
              let decoded = try? JSONDecoder().decode(AppData.self, from: raw) else { return }
        Task { @MainActor in
            self.appData = decoded
            self.save(decoded)
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext context: [String: Any]) {
        guard let raw = context["appData"] as? Data,
              let decoded = try? JSONDecoder().decode(AppData.self, from: raw) else { return }
        Task { @MainActor in
            self.appData = decoded
            self.save(decoded)
        }
    }
}
