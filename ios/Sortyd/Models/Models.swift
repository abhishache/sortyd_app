// MARK: - Models.swift
// Sortyd — Core Data Models
// All Identifiable, Codable, and Hashable for SwiftUI + persistence

import Foundation
import SwiftUI

// MARK: - Task

struct SortydTask: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var isCompleted: Bool = false
    var manuallyCompleted: Bool = false
    var createdAt: Date = Date()
    var weight: Double = 0.0
    var reminderTime: Date? = nil
    var reminderIsOneTime: Bool = false
    var soundName: String? = nil
    var hexColor: String? = nil
    var durationMinutes: Int? = nil
    var healthType: String? = nil
    var healthTarget: Double? = nil

    var isHealthTask: Bool { healthType != nil }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: SortydTask, rhs: SortydTask) -> Bool { lhs.id == rhs.id }

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false,
         manuallyCompleted: Bool = false, createdAt: Date = Date(), weight: Double = 0.0,
         reminderTime: Date? = nil, reminderIsOneTime: Bool = false, soundName: String? = nil,
         hexColor: String? = nil, durationMinutes: Int? = nil, healthType: String? = nil, healthTarget: Double? = nil) {
        self.id = id; self.title = title; self.isCompleted = isCompleted
        self.manuallyCompleted = manuallyCompleted; self.createdAt = createdAt
        self.weight = weight.isFinite ? max(0, weight) : 0; self.reminderTime = reminderTime
        self.reminderIsOneTime = reminderIsOneTime; self.soundName = soundName
        self.hexColor = hexColor; self.durationMinutes = durationMinutes
        self.healthType = healthType; self.healthTarget = healthTarget
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decodeIfPresent(UUID.self,   forKey: .id)               ?? UUID()
        title            = try c.decode(String.self,          forKey: .title)
        isCompleted      = try c.decodeIfPresent(Bool.self,   forKey: .isCompleted)       ?? false
        manuallyCompleted = try c.decodeIfPresent(Bool.self,  forKey: .manuallyCompleted) ?? false
        createdAt        = try c.decodeIfPresent(Date.self,   forKey: .createdAt)         ?? Date()
        let decodedWeight = try c.decodeIfPresent(Double.self, forKey: .weight) ?? 0
        weight = decodedWeight.isFinite ? max(0, decodedWeight) : 0
        reminderTime      = try c.decodeIfPresent(Date.self,   forKey: .reminderTime)
        reminderIsOneTime = try c.decodeIfPresent(Bool.self,   forKey: .reminderIsOneTime) ?? false
        soundName         = try c.decodeIfPresent(String.self, forKey: .soundName)
        hexColor          = try c.decodeIfPresent(String.self, forKey: .hexColor)
        durationMinutes   = try c.decodeIfPresent(Int.self,    forKey: .durationMinutes)
        healthType        = try c.decodeIfPresent(String.self, forKey: .healthType)
        healthTarget     = try c.decodeIfPresent(Double.self, forKey: .healthTarget)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, isCompleted, manuallyCompleted, createdAt, weight,
             reminderTime, reminderIsOneTime, soundName, hexColor, durationMinutes, healthType, healthTarget
    }
}

// MARK: - Task List

struct TaskList: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var emoji: String = "📋"
    var tasks: [SortydTask]
    var createdAt: Date = Date()
    var isArchived: Bool = false
    var isTodo: Bool = false
    var isWeekly: Bool = false

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id         = try container.decode(UUID.self,             forKey: .id)
        name       = try container.decode(String.self,           forKey: .name)
        emoji      = try container.decodeIfPresent(String.self,  forKey: .emoji) ?? "📋"
        tasks      = try container.decode([SortydTask].self,     forKey: .tasks)
        createdAt  = try container.decodeIfPresent(Date.self,    forKey: .createdAt) ?? Date()
        isArchived = try container.decodeIfPresent(Bool.self,    forKey: .isArchived) ?? false
        isTodo     = try container.decodeIfPresent(Bool.self,    forKey: .isTodo) ?? false
        isWeekly   = try container.decodeIfPresent(Bool.self,    forKey: .isWeekly) ?? false
        recalculateWeights()
    }

    init(id: UUID = UUID(), name: String, emoji: String = "📋",
         tasks: [SortydTask] = [], createdAt: Date = Date(), isArchived: Bool = false, isTodo: Bool = false, isWeekly: Bool = false) {
        self.id = id; self.name = name; self.emoji = emoji
        self.tasks = tasks; self.createdAt = createdAt; self.isArchived = isArchived
        self.isTodo = isTodo; self.isWeekly = isWeekly
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, emoji, tasks, createdAt, isArchived, isTodo, isWeekly
    }
    
    mutating func recalculateWeights() {
        guard !tasks.isEmpty else { return }
        let w = 1.0 / Double(tasks.count)
        for i in tasks.indices { tasks[i].weight = w }
    }
    
    // MARK: Completion — HealthKit-aware
    
    /// healthValues: [taskID: 0–1 progress] from HealthKitManager. Health tasks use live progress.
    func completionFraction(healthValues: [UUID: Double] = [:]) -> Double {
        guard !tasks.isEmpty else { return 0 }
        let totalWeight = tasks.reduce(0) { $0 + $1.weight }
        if totalWeight.isFinite, totalWeight > 0 {
            let completedWeight = tasks.reduce(0.0) { acc, task in
                if task.isHealthTask {
                    if task.isCompleted {
                        // Manual check always counts as fully done
                        return acc + task.weight
                    } else if let hp = healthValues[task.id] {
                        return acc + task.weight * CompletionPolicy.fraction(hp)
                    }
                } else if task.isCompleted {
                    return acc + task.weight
                }
                return acc
            }
            return CompletionPolicy.fraction(completedWeight / totalWeight)
        } else {
            let done = Double(tasks.filter(\.isCompleted).count)
            return done / Double(tasks.count)
        }
    }
    
    var completionFraction: Double { completionFraction(healthValues: [:]) }
    var completionPercentage: Int  { CompletionPolicy.percentage(completionFraction) }
    
    /// Returns the name without any leading emojis to prevent double icons in the UI.
    var cleanName: String {
        var n = name.trimmingCharacters(in: .whitespaces)
        while !n.isEmpty, n.first!.isEmoji {
            n.removeFirst()
            n = n.trimmingCharacters(in: .whitespaces)
        }
        return n
    }
}

// MARK: - Weekly Plan

struct WeeklyPlan: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var weekStartDate: Date
    var northStar: String = ""
    var weeklyTheme: String = ""
    var dailyFocus: [Int: String] = [:] // 1-7 for days of week
    var dayLoads: [Int: Int] = [:] // 0 = light, 1 = steady, 2 = deep
    var mustDoTasks: [String] = ["", "", ""]
    var antiGoals: [String] = ["", ""]
    var recoveryDay: Int = 7
    var weeklyReward: String = ""
    
    init(
        id: UUID = UUID(),
        weekStartDate: Date,
        northStar: String = "",
        weeklyTheme: String = "",
        dailyFocus: [Int: String] = [:],
        dayLoads: [Int: Int] = [:],
        mustDoTasks: [String] = ["", "", ""],
        antiGoals: [String] = ["", ""],
        recoveryDay: Int = 7,
        weeklyReward: String = ""
    ) {
        self.id = id
        self.weekStartDate = weekStartDate
        self.northStar = northStar
        self.weeklyTheme = weeklyTheme
        self.dailyFocus = dailyFocus
        self.dayLoads = dayLoads
        self.mustDoTasks = Array((mustDoTasks + ["", "", ""]).prefix(3))
        self.antiGoals = Array((antiGoals + ["", ""]).prefix(2))
        self.recoveryDay = min(max(recoveryDay, 1), 7)
        self.weeklyReward = weeklyReward
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        weekStartDate = try c.decodeIfPresent(Date.self, forKey: .weekStartDate) ?? WeeklyPlan.currentWeekStart()
        northStar = try c.decodeIfPresent(String.self, forKey: .northStar) ?? ""
        weeklyTheme = try c.decodeIfPresent(String.self, forKey: .weeklyTheme) ?? ""
        dailyFocus = try c.decodeIfPresent([Int: String].self, forKey: .dailyFocus) ?? [:]
        dayLoads = try c.decodeIfPresent([Int: Int].self, forKey: .dayLoads) ?? [:]
        mustDoTasks = Array(((try c.decodeIfPresent([String].self, forKey: .mustDoTasks) ?? []) + ["", "", ""]).prefix(3))
        antiGoals = Array(((try c.decodeIfPresent([String].self, forKey: .antiGoals) ?? []) + ["", ""]).prefix(2))
        recoveryDay = min(max(try c.decodeIfPresent(Int.self, forKey: .recoveryDay) ?? 7, 1), 7)
        weeklyReward = try c.decodeIfPresent(String.self, forKey: .weeklyReward) ?? ""
    }
    
    static func currentWeekStart() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        return calendar.date(from: components) ?? now
    }
}
    
    // MARK: - Daily Snapshot
    
    struct DailySnapshot: Identifiable, Codable {
        var id: UUID = UUID()
        var date: Date
        var listID: UUID
        var completionFraction: Double {
            didSet { completionFraction = CompletionPolicy.fraction(completionFraction) }
        }
        var completedTaskIDs: [UUID]
        var completionPercentage: Int { CompletionPolicy.percentage(completionFraction) }
        
        // Forward-compatible decoder: new fields added in future versions decode safely.
        init(id: UUID = UUID(), date: Date, listID: UUID, completionFraction: Double, completedTaskIDs: [UUID]) {
            self.id = id
            self.date = date
            self.listID = listID
            self.completionFraction = CompletionPolicy.fraction(completionFraction)
            self.completedTaskIDs = completedTaskIDs
        }
        
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id                = try c.decodeIfPresent(UUID.self,    forKey: .id)                ?? UUID()
            date              = try c.decode(Date.self,             forKey: .date)
            listID            = try c.decode(UUID.self,             forKey: .listID)
            completionFraction = CompletionPolicy.fraction(try c.decode(Double.self, forKey: .completionFraction))
            completedTaskIDs  = try c.decodeIfPresent([UUID].self,  forKey: .completedTaskIDs)  ?? []
        }
    }
    
    // MARK: - App State Wrapper
    
    struct AppData: Codable {
        var lists: [TaskList] = []
        var activeListID: UUID?
        var snapshots: [DailySnapshot] = []
        var weeklyPlan: WeeklyPlan?
        
        var activeList: TaskList? {
            let live = lists.filter { !$0.isArchived && !$0.isWeekly }
            guard let id = activeListID else { return live.first }
            return live.first(where: { $0.id == id }) ?? live.first
        }

        /// Like activeList but never returns the TO DO list — used by widgets and analytics.
        var activeRegularList: TaskList? {
            let live = lists.filter { !$0.isArchived && !$0.isTodo && !$0.isWeekly }
            if let id = activeListID, let match = live.first(where: { $0.id == id }) { return match }
            return live.first
        }
        
        // Forward-compatible decoder: keeps user data intact when new fields are added.
        init(lists: [TaskList] = [], activeListID: UUID? = nil, snapshots: [DailySnapshot] = [], weeklyPlan: WeeklyPlan? = nil) {
            self.lists = lists
            self.activeListID = activeListID
            self.snapshots = snapshots
            self.weeklyPlan = weeklyPlan
        }
        
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            lists        = try c.decodeIfPresent([TaskList].self, forKey: .lists)        ?? []
            activeListID = try c.decodeIfPresent(UUID.self,       forKey: .activeListID)
            snapshots    = try c.decodeIfPresent([DailySnapshot].self, forKey: .snapshots) ?? []
            weeklyPlan   = try c.decodeIfPresent(WeeklyPlan.self, forKey: .weeklyPlan)
        }
    }
    
    // MARK: - App Language
    
    enum AppLanguage: String, CaseIterable, Codable {
        case english = "en"
        case spanish = "es"
        case arabic  = "ar"
        case chinese = "zh-Hans"

        var name: String {
            switch self {
            case .english: return "English"
            case .spanish: return "Español"
            case .arabic:  return "العربية"
            case .chinese: return "中文"
            }
        }

        var locale: Locale {
            Locale(identifier: self.rawValue)
        }

        var isRTL: Bool {
            self == .arabic
        }
    }

    // MARK: - Daily Recap
    struct DailyRecapData: Codable, Equatable {
        let percentage: Int
        let message: String
        let emoji: String
        let listName: String
        let dateLabel: String
    }
