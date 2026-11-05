import Foundation

@main
struct AICoachLiveChecks {
    @MainActor
    static func main() async throws {
        var results: [[String: Any]] = []
        for language in ["en", "ar", "es", "zh-Hans"] {
            let suite = "sortyd.ai-live-check.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            defaults.set(language, forKey: "sortyd_app_language")
            let coach = AICoach(defaults: defaults)
            let started = Date()
            let starter = await coach.generateStarterList(goal: "Read books and study a new language")
            let starterTime = Date().timeIntervalSince(started)
            let tasks = [SortydTask(title: "Read ten pages"), SortydTask(title: "Study vocabulary"), SortydTask(title: "Plan tomorrow")]
            var list = TaskList(name: "Learning", tasks: tasks)
            list.recalculateWeights()
            let snapshots = (0..<14).map { day in
                DailySnapshot(date: Calendar.current.date(byAdding: .day, value: -day, to: ReminderPolicy.dayStart(Date()))!,
                              listID: list.id, completionFraction: day % 3 == 0 ? 1 : 2.0 / 3,
                              completedTaskIDs: day % 3 == 0 ? tasks.map(\.id) : Array(tasks.prefix(2).map(\.id)))
            }
            let coachStarted = Date()
            await coach.fetchAllListsBatch(lists: [list], snapshots: snapshots)
            let coachTime = Date().timeIntervalSince(coachStarted)
            let cached = coach.loadBestAvailableCache(for: list.id)
            let cacheStarted = Date()
            await coach.fetchAllListsBatch(lists: [list], snapshots: snapshots)
            let cacheTime = Date().timeIntervalSince(cacheStarted)
            let validStarter = starter.map { (4...6).contains($0.tasks.count) && !$0.listName.isEmpty && $0.tasks.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } } ?? false
            let validCoach = cached.found && !cached.isStale && !(coach.behaviouralAnalysis?.pillars.isEmpty ?? true) && coach.weeklyRecap != nil
            let result: [String: Any] = [
                "language": language, "starter_pass": validStarter, "coach_pass": validCoach,
                "starter_seconds": starterTime, "coach_seconds": coachTime, "cached_seconds": cacheTime,
                "starter": starter.map { ["name": $0.listName, "tasks": $0.tasks] as [String: Any] } ?? [:],
                "coach_insight": coach.behaviouralAnalysis?.overallInsight ?? "",
                "weekly_headline": coach.weeklyRecap?.headline ?? "", "error": coach.errorMessage ?? ""
            ]
            results.append(result)
            print(String(data: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), encoding: .utf8)!)
            fflush(stdout)
        }
        if CommandLine.arguments.count > 1 {
            try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        }
        guard results.allSatisfy({ $0["starter_pass"] as? Bool == true && $0["coach_pass"] as? Bool == true && ($0["cached_seconds"] as? Double ?? 100) < 0.1 }) else {
            throw NSError(domain: "SortydLiveChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: "An AI language or cache check failed"])
        }
    }
}
