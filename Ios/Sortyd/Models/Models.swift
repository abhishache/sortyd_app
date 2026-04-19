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

    // MARK: HealthKit fields (nil = regular checkbox task)

    /// "steps" | "calories" — nil means not a health task.
    var healthType: String? = nil

    /// User-defined numeric goal (e.g. 10000 steps, 500 kcal).
    var healthTarget: Double? = nil

    var isHealthTask: Bool { healthType != nil }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: SortydTask, rhs: SortydTask) -> Bool { lhs.id == rhs.id }
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
}

// MARK: - Daily Snapshot

struct DailySnapshot: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date
    var listID: UUID
    var completionFraction: Double
    var completedTaskIDs: [UUID]
    var completionPercentage: Int { Int((completionFraction * 100).rounded()) }
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
}
