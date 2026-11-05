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
    var manuallyCompleted: Bool = false
    var createdAt: Date = Date()
    var weight: Double = 0.0
    var reminderTime: Date? = nil
    var healthType: String? = nil
    var healthTarget: Double? = nil
    var reminderIsOneTime: Bool = false

    var isHealthTask: Bool { healthType != nil }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: SortydTask, rhs: SortydTask) -> Bool { lhs.id == rhs.id }
}

enum AppLanguage: String, Codable {
    case english = "en"
    case arabic  = "ar"
    case spanish = "es"
    case chinese = "zh-Hans"
}

struct TaskList: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var emoji: String = "📋"
    var tasks: [SortydTask]
    var createdAt: Date = Date()
    var isArchived: Bool = false
    var isTodo: Bool?
    var isWeekly: Bool?

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
        let live = lists.filter { !$0.isArchived && $0.isWeekly != true }
        guard let id = activeListID else { return live.first }
        return live.first(where: { $0.id == id }) ?? live.first
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
    @Published var appLanguage: AppLanguage = .english

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
        
        if let langRaw = defaults.string(forKey: "sortyd_app_language"),
           let lang = AppLanguage(rawValue: langRaw) {
            self.appLanguage = lang
        }
        
        setupWatchConnectivity()
    }

    // MARK: Public API

    var activeList: TaskList? { appData.activeList }

    func toggleTask(_ task: SortydTask) {
        guard
            let listIdx = activeListIndex,
            let taskIdx = appData.lists[listIdx].tasks.firstIndex(where: { $0.id == task.id })
        else { return }

        let expected = appData.lists[listIdx].tasks[taskIdx].isCompleted
        appData.lists[listIdx].tasks[taskIdx].isCompleted.toggle()
        save(appData)
        sendToPhone(taskID: task.id, expected: expected, completed: !expected)
    }

    func refresh() {
        appData = load()
        requestFromPhone()
    }

    // MARK: Private helpers

    private var activeListIndex: Int? {
        guard let id = appData.activeList?.id else { return nil }
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
                if let langRaw = reply["appLanguage"] as? String,
                   let lang = AppLanguage(rawValue: langRaw) {
                    self.appLanguage = lang
                    self.defaults.set(langRaw, forKey: "sortyd_app_language")
                }
                self.isSyncing = false
            }
        }, errorHandler: { [weak self] _ in
            Task { @MainActor [weak self] in self?.isSyncing = false }
        })
    }

    private func sendToPhone(taskID: UUID, expected: Bool, completed: Bool) {
        let operation: [String: Any] = ["operationID": UUID().uuidString, "taskID": taskID.uuidString,
            "expectedCompleted": expected, "completed": completed, "sentAt": Date()]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(operation, replyHandler: nil) { _ in
                WCSession.default.transferUserInfo(operation)
            }
        } else {
            WCSession.default.transferUserInfo(operation)
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchStore: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {
        Task { @MainActor in requestFromPhone() }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            if let raw = message["appData"] as? Data,
               let decoded = try? JSONDecoder().decode(AppData.self, from: raw) {
                self.appData = decoded
                self.save(decoded)
            }
            if let langRaw = message["appLanguage"] as? String,
               let lang = AppLanguage(rawValue: langRaw) {
                self.appLanguage = lang
                self.defaults.set(langRaw, forKey: "sortyd_app_language")
            }
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext context: [String: Any]) {
        Task { @MainActor in
            if let raw = context["appData"] as? Data,
               let decoded = try? JSONDecoder().decode(AppData.self, from: raw) {
                self.appData = decoded
                self.save(decoded)
            }
            if let langRaw = context["appLanguage"] as? String,
               let lang = AppLanguage(rawValue: langRaw) {
                self.appLanguage = lang
                self.defaults.set(langRaw, forKey: "sortyd_app_language")
            }
        }
    }
}
