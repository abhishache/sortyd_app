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

    /// Computed weight — set externally by the list via recalculateWeights()
    var weight: Double = 0.0

    /// Optional daily reminder time.
    var reminderTime: Date? = nil

    /// True when the reminder fires once at a specific date+time; false = daily repeating.
    var reminderIsOneTime: Bool = false

    // MARK: HealthKit fields (nil = regular checkbox task)

    /// "steps" | "calories" — nil means not a health task.
    var healthType: String? = nil

    /// User-defined numeric goal (e.g. 10000 steps, 500 kcal).
    var healthTarget: Double? = nil

    var isHealthTask: Bool { healthType != nil }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: SortydTask, rhs: SortydTask) -> Bool { lhs.id == rhs.id }

    // Forward-compatible decoder: non-optional fields with defaults use decodeIfPresent
    // so adding new fields in future versions never wipes existing task data.
    init(id: UUID = UUID(), title: String, isCompleted: Bool = false,
         manuallyCompleted: Bool = false, createdAt: Date = Date(), weight: Double = 0.0,
         reminderTime: Date? = nil, reminderIsOneTime: Bool = false,
         healthType: String? = nil, healthTarget: Double? = nil) {
        self.id = id; self.title = title; self.isCompleted = isCompleted
        self.manuallyCompleted = manuallyCompleted; self.createdAt = createdAt
        self.weight = weight; self.reminderTime = reminderTime
        self.reminderIsOneTime = reminderIsOneTime
        self.healthType = healthType; self.healthTarget = healthTarget
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decodeIfPresent(UUID.self,   forKey: .id)               ?? UUID()
        title            = try c.decode(String.self,          forKey: .title)
        isCompleted      = try c.decodeIfPresent(Bool.self,   forKey: .isCompleted)       ?? false
        manuallyCompleted = try c.decodeIfPresent(Bool.self,  forKey: .manuallyCompleted) ?? false
        createdAt        = try c.decodeIfPresent(Date.self,   forKey: .createdAt)         ?? Date()
        weight           = try c.decodeIfPresent(Double.self, forKey: .weight)            ?? 0.0
        reminderTime      = try c.decodeIfPresent(Date.self,   forKey: .reminderTime)
        reminderIsOneTime = try c.decodeIfPresent(Bool.self,   forKey: .reminderIsOneTime) ?? false
        healthType        = try c.decodeIfPresent(String.self, forKey: .healthType)
        healthTarget     = try c.decodeIfPresent(Double.self, forKey: .healthTarget)
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
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id         = try container.decode(UUID.self,             forKey: .id)
        name       = try container.decode(String.self,           forKey: .name)
        emoji      = try container.decodeIfPresent(String.self,  forKey: .emoji) ?? "📋"
        tasks      = try container.decode([SortydTask].self,     forKey: .tasks)
        createdAt  = try container.decodeIfPresent(Date.self,    forKey: .createdAt) ?? Date()
        isArchived = try container.decodeIfPresent(Bool.self,    forKey: .isArchived) ?? false
        recalculateWeights()
    }
    
    init(id: UUID = UUID(), name: String, emoji: String = "📋",
         tasks: [SortydTask] = [], createdAt: Date = Date(), isArchived: Bool = false) {
        self.id = id; self.name = name; self.emoji = emoji
        self.tasks = tasks; self.createdAt = createdAt; self.isArchived = isArchived
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, emoji, tasks, createdAt, isArchived
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
        if totalWeight > 0 {
            return tasks.reduce(0.0) { acc, task in
                if task.isHealthTask {
                    if task.isCompleted {
                        // Manual check always counts as fully done
                        return acc + task.weight
                    } else if let hp = healthValues[task.id] {
                        return acc + task.weight * hp
                    }
                } else if task.isCompleted {
                    return acc + task.weight
                }
                return acc
            }
        } else {
            let done = Double(tasks.filter(\.isCompleted).count)
            return done / Double(tasks.count)
        }
    }
    
    var completionFraction: Double { completionFraction(healthValues: [:]) }
    var completionPercentage: Int  { Int((completionFraction * 100).rounded()) }
    
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
    
    // MARK: - Daily Snapshot
    
    struct DailySnapshot: Identifiable, Codable {
        var id: UUID = UUID()
        var date: Date
        var listID: UUID
        var completionFraction: Double
        var completedTaskIDs: [UUID]
        var completionPercentage: Int { Int((completionFraction * 100).rounded()) }
        
        // Forward-compatible decoder: new fields added in future versions decode safely.
        init(id: UUID = UUID(), date: Date, listID: UUID, completionFraction: Double, completedTaskIDs: [UUID]) {
            self.id = id
            self.date = date
            self.listID = listID
            self.completionFraction = completionFraction
            self.completedTaskIDs = completedTaskIDs
        }
        
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id                = try c.decodeIfPresent(UUID.self,    forKey: .id)                ?? UUID()
            date              = try c.decode(Date.self,             forKey: .date)
            listID            = try c.decode(UUID.self,             forKey: .listID)
            completionFraction = try c.decode(Double.self,          forKey: .completionFraction)
            completedTaskIDs  = try c.decodeIfPresent([UUID].self,  forKey: .completedTaskIDs)  ?? []
        }
    }
    
    // MARK: - App State Wrapper
    
    struct AppData: Codable {
        var lists: [TaskList] = []
        var activeListID: UUID?
        var snapshots: [DailySnapshot] = []
        
        var activeList: TaskList? {
            let live = lists.filter { !$0.isArchived }
            guard let id = activeListID else { return live.first }
            return live.first(where: { $0.id == id }) ?? live.first
        }
        
        // Forward-compatible decoder: keeps user data intact when new fields are added.
        init(lists: [TaskList] = [], activeListID: UUID? = nil, snapshots: [DailySnapshot] = []) {
            self.lists = lists
            self.activeListID = activeListID
            self.snapshots = snapshots
        }
        
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            lists        = try c.decodeIfPresent([TaskList].self, forKey: .lists)        ?? []
            activeListID = try c.decodeIfPresent(UUID.self,       forKey: .activeListID)
            snapshots    = try c.decodeIfPresent([DailySnapshot].self, forKey: .snapshots) ?? []
        }
    }
    
    // MARK: - App Language
    
    enum AppLanguage: String, CaseIterable, Codable {
        case english = "en"
        case spanish = "es"
        case arabic  = "ar"
        
        var name: String {
            switch self {
            case .english: return "English"
            case .spanish: return "Español"
            case .arabic:  return "العربية"
            }
        }
        
        var locale: Locale {
            Locale(identifier: self.rawValue)
        }
        
        var isRTL: Bool {
            self == .arabic
        }
    }

