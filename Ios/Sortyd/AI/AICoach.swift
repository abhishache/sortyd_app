// MARK: - AICoach.swift
// Sortyd — AI Coach powered by Groq (free tier)
// Handles: Weekly Recap, Procrastination Detection, List Health,
//          Behavioural Pillars, NL Task Entry, Starter Lists

import Foundation
import Combine
import SwiftUI
import CryptoKit

// MARK: - Response Models

struct WeeklyRecap: Codable {
    let headline: String
    let summary: String
    let highlight: String
    let nudge: String
    let grade: String
    let gradeReason: String
}

struct ProcrastinationFlag: Codable, Identifiable {
    let id: UUID
    let taskTitle: String
    let daysSkipped: Int
    let suggestion: String
    let actionLabel: String
}

struct ListHealthReport: Codable {
    let score: Int
    let label: String
    let insight: String
    let tips: [String]
}

struct ParsedTask: Codable {
    let title: String
    let hasReminder: Bool
    let reminderHour: Int?
    let reminderMinute: Int?
}

struct StarterList: Codable {
    let emoji: String
    let listName: String
    let tasks: [String]
}

// MARK: - Behavioural Pillar Models

struct BehaviouralPillar: Codable, Identifiable {
    let id: UUID
    let name: String
    let emoji: String
    let score: Int
    let status: String
    let insight: String
    let tasks: [String]
    let advice: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let idStr = try? c.decode(String.self, forKey: .id),
           let uuid = UUID(uuidString: idStr) {
            id = uuid
        } else {
            id = UUID()
        }
        name    = try c.decode(String.self, forKey: .name)
        emoji   = try c.decode(String.self, forKey: .emoji)
        score   = try c.decode(Int.self,    forKey: .score)
        status  = try c.decode(String.self, forKey: .status)
        insight = try c.decode(String.self, forKey: .insight)
        tasks   = try c.decode([String].self, forKey: .tasks)
        advice  = try c.decode(String.self, forKey: .advice)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, emoji, score, status, insight, tasks, advice
    }
}

struct BehaviouralAnalysis: Codable {
    let pillars: [BehaviouralPillar]
    let overallInsight: String
    let criticalPillar: String
}

// MARK: - AICoach

@MainActor
final class AICoach: ObservableObject {

    static let shared = AICoach()

    @Published var weeklyRecap: WeeklyRecap?
    @Published var procrastinationFlags: [ProcrastinationFlag] = []
    @Published var listHealthReport: ListHealthReport?
    @Published var behaviouralAnalysis: BehaviouralAnalysis?
    @Published var isLoading = false
    @Published var isBehaviourLoading = false
    @Published var errorMessage: String?

    // ─── Groq config ─────────────────────────────────────────────────────────
    // Security: No secret is stored in the client binary.
    // Each request is authenticated by a HMAC-SHA256 signature over the
    // request body + a Unix timestamp, using a salt derived at build time
    // from public app metadata. The Cloudflare Worker recomputes the same
    // HMAC and rejects requests where the signature doesn't match or the
    // timestamp is stale (> 60 s). This makes replayed or forged requests
    // impossible without knowing the salt, which is never transmitted.
    //
    // To rotate: change hmacSalt here and update SORTYD_HMAC_SALT in the
    // Cloudflare Worker secret store. Both must match.

    private let model  = "llama-3.3-70b-versatile"
    private let apiURL = URL(string: "https://sortyd-proxy.abhishek918.workers.dev/api/ai")!

    // This is NOT a secret — it is a public HMAC salt derived from your
    // bundle ID + app name. It prevents trivial replay attacks but is not
    // a substitute for server-side rate limiting. The actual Groq API key
    // lives only in the Cloudflare Worker environment variable GROQ_API_KEY.
    private let hmacSalt = "com.sortyd.sortyd|Sortyd|v1"

    /// Throttle: minimum seconds between API calls
    private var lastCallTime: Date = .distantPast
    private let minCallInterval: TimeInterval = 5
    // ─────────────────────────────────────────────────────────────────────────

    private init() {}

    // MARK: - Weekly Recap

    func generateWeeklyRecap(lists: [TaskList], snapshots: [DailySnapshot]) async {
        isLoading = true
        errorMessage = nil

        let summary = buildWeekSummary(lists: lists, snapshots: snapshots)
        let windowDays = min(7, daysSinceInstall + 1)
        let newUserNote = daysSinceInstall < 7
            ? "Note: User installed \(daysSinceInstall + 1) day(s) ago — this is early data. Be encouraging, acknowledge they are just starting.\n"
            : ""
        let prompt = """
        You are a sharp, no-BS habit coach. You see patterns others miss.
        Rules: Use "you", never "the user". Name SPECIFIC tasks. Short punchy sentences. No fluff.
        \(newUserNote)
        DATA (\(windowDays) days, per-task daily breakdown):
        \(summary)

        ANALYSIS INSTRUCTIONS:
        - Look at which specific tasks were skipped and on which days
        - Identify the weakest task (lowest completion) and the strongest
        - Notice day-of-week patterns (e.g. weekends drop, Mondays strong)
        - Check if streaks are building or breaking
        - The headline should reference a SPECIFIC pattern you found

        Respond ONLY with valid JSON (no markdown, no backticks):
        {
          "headline": "Max 6 words + 1 emoji. Reference a specific finding (e.g. 'Weekends are killing you 💀' or 'Meditation streak on fire 🔥')",
          "summary": "2 sentences. Name the weakest task and strongest task BY NAME. State the specific pattern.",
          "highlight": "Name ONE specific task + what they did well. e.g. 'You hit Meditate 7/7 days — that's a real streak.'",
          "nudge": "ONE specific action targeting their weakest task. e.g. 'Do [task name] before breakfast tomorrow.' Verb-first, under 15 words.",
          "grade": "Letter grade: A, A-, B+, B, B-, C+, C, or D",
          "gradeReason": "Reference the data. e.g. 'You averaged 60% and skipped 3 tasks entirely on weekends.'"
        }
        """

        if let result: WeeklyRecap = await callGroq(prompt: prompt) {
            weeklyRecap = result
        } else if errorMessage == nil {
            // Network succeeded but response couldn't be parsed — show a clear message
            // rather than leaving the previous recap stale or the screen blank.
            errorMessage = "Couldn't read the AI response. Try again in a moment."
        }
        isLoading = false
    }

    // MARK: - Procrastination Detection

    func detectProcrastination(lists: [TaskList], snapshots: [DailySnapshot]) async {
        isLoading = true
        errorMessage = nil

        let flagData = buildProcrastinationData(lists: lists, snapshots: snapshots)
        guard !flagData.isEmpty else {
            procrastinationFlags = []
            isLoading = false
            return
        }

        let procWindow = min(14, daysSinceInstall + 1)
        let procNewNote = daysSinceInstall < 14
            ? "Note: App installed \(daysSinceInstall + 1) day(s) ago — only \(procWindow) days of data. Be constructive, not harsh.\n"
            : ""
        let prompt = """
        You are a direct habit coach who diagnoses WHY tasks get skipped.
        Rules: Use "you". Name each task. One punchy sentence. Diagnose the root cause, don't just say "try harder".
        \(procNewNote)
        These tasks are being skipped (includes completion rate, last done, and most-skipped day):
        \(flagData)

        ANALYSIS INSTRUCTIONS:
        - If "lastDone" is "never", the task may be too ambitious or poorly defined
        - If done 1-3 out of \(procWindow), there's a trigger/motivation problem
        - If "mostSkippedDay" clusters on weekends, it's a routine gap
        - Suggest a ROOT CAUSE: too vague? too hard? wrong time of day? no trigger? boring?

        Respond ONLY with valid JSON array (no markdown, no backticks):
        [
          {
            "id": "<same UUID>",
            "taskTitle": "<same title>",
            "daysSkipped": <\(procWindow) minus done count>,
            "suggestion": "Diagnose WHY. Under 20 words.",
            "actionLabel": "Shrink it" or "Reschedule" or "Remove it" or "Pair it"
          }
        ]
        Max 6 items. "Pair it" means attach it to an existing habit.
        """

        if let result: [ProcrastinationFlag] = await callGroqArray(prompt: prompt) {
            procrastinationFlags = result
        } else if errorMessage == nil {
            errorMessage = "Couldn't read the AI response. Try again in a moment."
        }
        isLoading = false
    }

    // MARK: - List Health

    func analyzeListHealth(list: TaskList, snapshots: [DailySnapshot]) async -> ListHealthReport? {
        let recentSnaps = snapshots.filter { $0.listID == list.id }.suffix(30)
        let avgCompletion = recentSnaps.isEmpty ? 0 :
            recentSnaps.map(\.completionFraction).reduce(0, +) / Double(recentSnaps.count)

        let recentCompletedIDs = Set(recentSnaps.flatMap(\.completedTaskIDs))
        let neverDoneTasks = list.tasks.filter { !recentCompletedIDs.contains($0.id) }.map(\.title)

        let prompt = """
        You are a habit coach who diagnoses list problems. Use "you", never "the user".

        List: "\(list.name)"
        Total tasks: \(list.tasks.count)
        Avg completion (30 days): \(Int(avgCompletion * 100))%
        Tasks NEVER completed in 30 days: \(neverDoneTasks.isEmpty ? "none" : neverDoneTasks.joined(separator: ", "))

        DIAGNOSIS RULES:
        - If never-completed tasks exist, the list has dead weight — call them out by name
        - If avg < 50%, the list is overloaded — suggest removing the weakest tasks
        - If tasks > 8, the list is too long for daily habits
        - If avg > 85%, the list might be too easy — suggest leveling up
        - Score should reflect: completion rate (60%), dead-weight tasks (25%), list size (15%)

        Respond ONLY with valid JSON (no markdown, no backticks):
        {
          "score": <0-100>,
          "label": "Healthy" or "Overloaded" or "Stale" or "Needs Work" or "Great Shape",
          "insight": "Name the problem. e.g. 'You have 3 tasks you've never done — they're dragging your score down.' Under 20 words.",
          "tips": ["Name a specific task or pattern in each tip. Verb-first, under 10 words.", "tip 2", "tip 3"]
        }
        """

        return await callGroq(prompt: prompt)
    }

    // MARK: - Behavioural Pillar Analysis

    func analyseBehaviouralPillars(lists: [TaskList], snapshots: [DailySnapshot]) async {
        isBehaviourLoading = true
        behaviouralAnalysis = nil

        let taskData = buildTaskCompletionData(lists: lists, snapshots: snapshots)
        guard !taskData.isEmpty else {
            isBehaviourLoading = false
            return
        }

        let prompt = """
        You are a habit coach who finds the real patterns. Use "you", never "the user".
        Be specific — name tasks, name days, name numbers.

        DATA (per task: completion rate, weekday vs weekend split, trend, current streak):
        \(taskData)

        ANALYSIS INSTRUCTIONS:
        - Group tasks into 2–4 behavioural pillars (Health, Discipline, Mindset, Learning, etc.)
        - The pillar score = average completion of its tasks. Don't inflate it.
        - Look at weekday vs weekend rates — if weekend drops >20%, call it out
        - Look at trends — DECLINING tasks are red flags, IMPROVING tasks are wins
        - Look at streaks – a 0-day streak on a daily task means it just broke
        - The overallInsight MUST name the single biggest pattern (e.g. "weekends", "one task dragging everything down", "steady improvement")

        Respond ONLY with valid JSON (no markdown, no backticks):
        {
          "pillars": [
            {
              "id": "<UUID string>",
              "name": "Pillar name",
              "emoji": "<single emoji>",
              "score": <0-100 based on actual completion data>,
              "status": "Strong" (75+) or "Developing" (50–74) or "Struggling" (<50),
              "insight": "Name specific tasks and numbers. e.g. 'You do Workout 80% on weekdays but 0% on weekends. The routine breaks when structure disappears.'",
              "tasks": ["exact task title 1", "exact task title 2"],
              "advice": "Target the weakest task in this pillar. e.g. 'Do [task] right after [strongest task] to piggyback the habit.' Under 15 words."
            }
          ],
          "overallInsight": "Name THE pattern. e.g. 'Your weekdays are strong but weekends erase the progress. 3 tasks hit 0% on Sat-Sun.' 2 sentences max.",
          "criticalPillar": "Name of the pillar needing most attention"
        }
        """

        if let result: BehaviouralAnalysis = await callGroq(prompt: prompt) {
            behaviouralAnalysis = result
        } else if errorMessage == nil {
            errorMessage = "Couldn't read the AI response. Try again in a moment."
        }
        isBehaviourLoading = false
    }

    // MARK: - Natural Language Task Parsing

    func parseNaturalLanguageTask(_ input: String) async -> ParsedTask? {
        let prompt = """
        Parse this task input from a productivity app. Extract the task title and any time/reminder info.

        Input: "\(input)"

        Respond ONLY with valid JSON (no markdown, no backticks):
        {
          "title": "Clean task title, remove time references",
          "hasReminder": true or false,
          "reminderHour": <0-23 or null>,
          "reminderMinute": <0-59 or null>
        }

        Examples:
        "call mom at 6pm" → {"title":"Call mom","hasReminder":true,"reminderHour":18,"reminderMinute":0}
        "go for a run" → {"title":"Go for a run","hasReminder":false,"reminderHour":null,"reminderMinute":null}
        "team standup 9:30am" → {"title":"Team standup","hasReminder":true,"reminderHour":9,"reminderMinute":30}
        """

        return await callGroq(prompt: prompt)
    }

    // MARK: - Daily Summary (one-liner for 10 PM notification)

    /// Returns a single punchy sentence summarising today's performance on the active list.
    func generateDailySummary(for list: TaskList, snapshots: [DailySnapshot]) async -> String? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let todaySnap = snapshots.first(where: {
            $0.listID == list.id && cal.isDate($0.date, inSameDayAs: today)
        })

        let completedIDs = Set(todaySnap?.completedTaskIDs ?? [])
        let total = list.tasks.count
        let done  = list.tasks.filter { completedIDs.contains($0.id) }.count
        let pct   = total > 0 ? Int(Double(done) / Double(total) * 100) : 0

        let completedTitles = list.tasks.filter {  completedIDs.contains($0.id) }.map(\.title)
        let missedTitles    = list.tasks.filter { !completedIDs.contains($0.id) }.map(\.title)

        let prompt = """
        You are a sharp habit coach writing a single push notification sentence. No fluff, no filler.

        List: "\(list.name)"
        Tasks done today: \(done)/\(total) (\(pct)%)
        Completed: \(completedTitles.isEmpty ? "none" : completedTitles.joined(separator: ", "))
        Missed: \(missedTitles.isEmpty ? "none" : missedTitles.joined(separator: ", "))

       Rules:
        - Exactly ONE sentence. Max 12 words.
        - Use "you", never "the user".
        - If pct >= 80: celebrate a specific completed task.
        - If pct >= 50: acknowledge progress, name the biggest miss.
        - If pct < 50: be direct — name what was skipped, no sugarcoating.
        - Add 1 relevant emoji at the end.
        - Output ONLY the sentence. No quotes, no JSON, no explanation.
       """

        guard let data = await postToGroqUnthrottled(prompt: prompt) else { return nil }
        return extractText(from: data)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n").first
    }

    /// MARK: - Starter List Generation
    
    func generateStarterList(goal: String) async -> StarterList? {
        let prompt = """
        You are a world-class habit coach helping someone build their first task list in Sortyd.
        Their goal: "\(goal)"

        YOUR JOB: Generate a complete, well-structured daily habit list that covers ALL dimensions of this goal.

        TASK COUNT RULES — this is critical:
        - ALWAYS generate between 4 and 6 tasks. Never fewer than 4. Never more than 6.
        - A list with 1–3 tasks is a failure. A list with 4–6 tasks is a success.
        - If the goal is broad (e.g. "get fit", "morning routine", "eat healthy"), find 6–8 distinct daily actions that together build that lifestyle.
        - If the goal is narrow (e.g. "walk 10,000 steps"), expand it into the surrounding habits that support and reinforce that goal (e.g. hydration, sleep, stretching, tracking).
        - Think in SYSTEMS, not single tasks. What does someone who has fully achieved this goal do every single day?

        TASK QUALITY RULES:
        - Each task must be concrete, completable in one sitting, and trackable as done/not done.
        - Vary the tasks — cover different times of day, different effort levels, different aspects of the goal.
        - Include at least one "anchor" habit (the core action), one "support" habit (enables the core), and one "reflection" or "tracking" habit.
        - Keep tasks short: 3–6 words. Capitalize the first word only.
        - No duplicates, no vague tasks like "Be healthy" or "Work on goal".

        EXAMPLES of good 6-task lists:
        Goal: "Get fit" →
          ["Morning workout — 30 min", "Walk 8,000 steps", "Drink 2.5L of water",
           "Eat a high-protein meal", "Stretch for 10 min", "Sleep by 10:30pm",
           "Log today's workout", "Prep gym bag tonight"]

        Goal: "Morning routine" →
          ["Wake up at 6:30am", "Drink water before coffee", "10-min morning stretch",
           "Cold shower", "Review today's priorities", "No phone for first 30 min",
           "Eat a real breakfast", "Journal 3 lines"]

        Goal: "Learn Spanish" →
          ["Duolingo — 15 min", "Learn 10 new vocab words", "Listen to Spanish podcast",
           "Review yesterday's vocab", "Watch one Spanish video", "Speak 5 sentences aloud",
           "Write 3 sentences in Spanish"]

        LIST NAME RULES:
        - Max 3 words, Title Case.
        - Should sound like a lifestyle identity, not a chore (e.g. "Fit Life System", "Morning Power Routine", "Language Builder").

        Respond ONLY with valid JSON (no markdown, no backticks, no explanation):
        {
          "emoji": "<single emoji that best represents the goal>",
          "listName": "<max 3 words, Title Case>",
          "tasks": ["Task 1", "Task 2", "Task 3", "Task 4", "Task 5"]
        }
        """

        return await callGroq(prompt: prompt)
    }

    // MARK: - Private: Groq API

    private func callGroq<T: Decodable>(prompt: String) async -> T? {
        guard let responseData = await postToGroq(prompt: prompt) else { return nil }
        return parseResponse(responseData)
    }

    private func callGroqArray<T: Decodable>(prompt: String) async -> [T]? {
        guard let responseData = await postToGroq(prompt: prompt) else { return nil }
        return parseArrayResponse(responseData)
    }

    // MARK: - HMAC request signing

    /// Signs the request body with HMAC-SHA256 using hmacSalt + current Unix timestamp.
    /// The Worker validates the signature and rejects requests older than 60 seconds.
    /// No secret leaves the server; the salt is public but makes blind replay impossible.
    private func signedRequest(body: Data) -> URLRequest {
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let message   = timestamp + "." + (String(data: body, encoding: .utf8) ?? "")
        let signature = hmac(message: message, key: hmacSalt)

        var request = URLRequest(url: apiURL)
        request.httpMethod    = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(timestamp,  forHTTPHeaderField: "x-sortyd-ts")
        request.setValue(signature,  forHTTPHeaderField: "x-sortyd-sig")
        request.httpBody = body
        return request
    }

    /// HMAC-SHA256 using CryptoKit — available on iOS 13+.
    private func hmac(message: String, key: String) -> String {
        let keyData  = SymmetricKey(data: Data(key.utf8))
        let mac      = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: keyData)
        return Data(mac).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Network calls

    private func postToGroq(prompt: String) async -> Data? {
        // Rate limiting — prevent API spam
        let now = Date()
        if now.timeIntervalSince(lastCallTime) < minCallInterval {
            errorMessage = "Please wait a moment before trying again."
            return nil
        }
        lastCallTime = now
        return await executeRequest(prompt: prompt)
    }

    private func postToGroqUnthrottled(prompt: String) async -> Data? {
        await executeRequest(prompt: prompt)
    }

    private func executeRequest(prompt: String) async -> Data? {
        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 1500,
            "temperature": 0.7
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else {
            errorMessage = "Failed to prepare request."
            return nil
        }

        let request = signedRequest(body: data)

        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                errorMessage = "AI service temporarily unavailable. Try again later."
                return nil
            }
            return responseData
        } catch let error as URLError where error.code == .notConnectedToInternet {
            errorMessage = "No internet connection. Connect and try again."
            return nil
        } catch let error as URLError where error.code == .timedOut {
            errorMessage = "Request timed out. Try again."
            return nil
        } catch {
            errorMessage = "Something went wrong. Please try again."
            return nil
        }
    }

    private func extractText(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let text = message["content"] as? String
        else { return nil }

        return text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseResponse<T: Decodable>(_ data: Data) -> T? {
        guard let text = extractText(from: data),
              let jsonData = text.data(using: .utf8)
        else {
            #if DEBUG
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            print("[AICoach] extractText failed. Raw response:\n\(raw)")
            #endif
            return nil
        }
        do {
            return try JSONDecoder().decode(T.self, from: jsonData)
        } catch {
            #if DEBUG
            print("[AICoach] JSON decode failed for \(T.self): \(error)")
            print("[AICoach] Raw model text:\n\(String(data: jsonData, encoding: .utf8) ?? "<nil>")")
            #endif
            return nil
        }
    }

    private func parseArrayResponse<T: Decodable>(_ data: Data) -> [T]? {
        guard let text = extractText(from: data),
              let jsonData = text.data(using: .utf8)
        else {
            #if DEBUG
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            print("[AICoach] extractText failed. Raw response:\n\(raw)")
            #endif
            return nil
        }
        do {
            return try JSONDecoder().decode([T].self, from: jsonData)
        } catch {
            #if DEBUG
            print("[AICoach] JSON array decode failed for \(T.self): \(error)")
            print("[AICoach] Raw model text:\n\(String(data: jsonData, encoding: .utf8) ?? "<nil>")")
            #endif
            return nil
        }
    }

    // MARK: - Private: Install Date

    private var installDate: Date {
        let key = "sortyd_install_date"
        let cal = Calendar.current
        if let d = UserDefaults.standard.object(forKey: key) as? Date { return cal.startOfDay(for: d) }
        return cal.startOfDay(for: Date())
    }

    private var daysSinceInstall: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return max(0, Calendar.current.dateComponents([.day], from: installDate, to: today).day ?? 0)
    }

    // MARK: - Private: Data Builders

    /// Rich weekly summary with per-task daily breakdown, streaks, and best/worst days.
    private func buildWeekSummary(lists: [TaskList], snapshots: [DailySnapshot]) -> String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // Clamp window to days since install so pre-install zeros don't pollute the data.
        let windowDays = min(7, daysSinceInstall + 1)
        var sections: [String] = []

        for list in lists {
            let listSnaps = snapshots.filter { $0.listID == list.id }
            var section = "LIST: \(list.emoji) \(list.name) (\(list.tasks.count) tasks)\n"

            // Daily overview
            var dailyPcts: [(day: String, pct: Int)] = []
            for dayOffset in (0..<windowDays).reversed() {
                guard let date = cal.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
                let snap = listSnaps.first(where: { cal.isDate($0.date, inSameDayAs: date) })
                let pct = snap.map { Int($0.completionFraction * 100) } ?? 0
                let dayName = cal.shortWeekdaySymbols[cal.component(.weekday, from: date) - 1]
                dailyPcts.append((dayName, pct))
            }
            section += "  Daily: " + dailyPcts.map { "\($0.day):\($0.pct)%" }.joined(separator: " ") + "\n"

            // Best and worst day
            if let best = dailyPcts.max(by: { $0.pct < $1.pct }) {
                section += "  Best day: \(best.day) (\(best.pct)%)"
            }
            if let worst = dailyPcts.min(by: { $0.pct < $1.pct }) {
                section += " | Worst day: \(worst.day) (\(worst.pct)%)\n"
            }

            // Per-task breakdown for the window
            section += "  Tasks this period:\n"
            for task in list.tasks {
                var doneDays: [String] = []
                var skippedDays: [String] = []
                for dayOffset in (0..<windowDays).reversed() {
                    guard let date = cal.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
                    let dayName = cal.shortWeekdaySymbols[cal.component(.weekday, from: date) - 1]
                    let snap = listSnaps.first(where: { cal.isDate($0.date, inSameDayAs: date) })
                    if let s = snap, s.completedTaskIDs.contains(task.id) {
                        doneDays.append(dayName)
                    } else {
                        skippedDays.append(dayName)
                    }
                }
                let doneCount = doneDays.count
                section += "    \(task.title): \(doneCount)/\(windowDays) days"
                if doneCount == windowDays {
                    section += " (PERFECT)"
                } else if doneCount == 0 {
                    section += " (NEVER DONE)"
                } else if !skippedDays.isEmpty {
                    section += " — skipped on: \(skippedDays.joined(separator: ", "))"
                }
                section += "\n"
            }

            // Current streak (consecutive 80%+ days ending today, capped at install window)
            var streak = 0
            for dayOffset in 0..<(daysSinceInstall + 1) {
                guard let date = cal.date(byAdding: .day, value: -dayOffset, to: today) else { break }
                let snap = listSnaps.first(where: { cal.isDate($0.date, inSameDayAs: date) })
                if let s = snap, s.completionFraction >= 0.8 {
                    streak += 1
                } else { break }
            }
            section += "  Current streak: \(streak) day\(streak == 1 ? "" : "s")"
            sections.append(section)
        }

        return sections.joined(separator: "\n\n")
    }

    /// Rich procrastination data — catches sporadic skippers, includes day-of-week patterns.
    private func buildProcrastinationData(lists: [TaskList], snapshots: [DailySnapshot]) -> String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // Only consider days since install — pre-install zeros would falsely inflate skip counts.
        let days = min(14, daysSinceInstall + 1)

        struct TaskFlag {
            let id: UUID
            let title: String
            let listName: String
            let doneCount: Int
            let totalDays: Int
            let skippedWeekdays: [String]  // e.g. ["Mon", "Tue", "Fri"]
            let lastDoneAgo: Int?          // days since last completed, nil if never
        }

        var flags: [TaskFlag] = []

        for list in lists {
            let listSnaps = snapshots.filter { $0.listID == list.id }

            for task in list.tasks {
                var doneCount = 0
                var skippedDayNames: [String] = []
                var lastDoneOffset: Int? = nil

                for offset in 0..<days {
                    guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
                    let snap = listSnaps.first(where: { cal.isDate($0.date, inSameDayAs: date) })
                    let dayName = cal.shortWeekdaySymbols[cal.component(.weekday, from: date) - 1]
                    if let s = snap, s.completedTaskIDs.contains(task.id) {
                        doneCount += 1
                        if lastDoneOffset == nil { lastDoneOffset = offset }
                    } else {
                        skippedDayNames.append(dayName)
                    }
                }

                // Flag tasks done less than 50% of the time (was: only never-done tasks)
                let rate = Double(doneCount) / Double(days)
                if rate < 0.5 {
                    flags.append(TaskFlag(
                        id: task.id, title: task.title, listName: list.name,
                        doneCount: doneCount, totalDays: days,
                        skippedWeekdays: skippedDayNames, lastDoneAgo: lastDoneOffset
                    ))
                }
            }
        }

        guard !flags.isEmpty else { return "" }

        // Sort by worst completion rate
        let sorted = flags.sorted { $0.doneCount < $1.doneCount }

        return sorted.prefix(6).map { f in
            let lastDone = f.lastDoneAgo.map { "\($0) days ago" } ?? "never"
            // Find most common skipped day-of-week
            let dayCounts = Dictionary(f.skippedWeekdays.map { ($0, 1) }, uniquingKeysWith: +)
            let worstDay = dayCounts.max(by: { $0.value < $1.value })?.key ?? "?"
            return """
            {"id":"\(f.id.uuidString)","taskTitle":"\(f.title)","listName":"\(f.listName)","done":\(f.doneCount),"outOf":\(f.totalDays),"lastDone":"\(lastDone)","mostSkippedDay":"\(worstDay)"}
            """
        }.joined(separator: "\n")
    }

    /// Rich task completion data with streaks, weekday/weekend split, and trend direction.
    private func buildTaskCompletionData(lists: [TaskList], snapshots: [DailySnapshot]) -> String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let days = min(14, daysSinceInstall + 1)
        var sections: [String] = []

        for list in lists {
            let listSnaps = snapshots.filter { $0.listID == list.id }
            var section = "LIST: \(list.emoji) \(list.name)\n"

            // Build day-by-day data
            var dayData: [(date: Date, weekday: Int, completedIDs: Set<UUID>)] = []
            for offset in 0..<days {
                guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
                let snap = listSnaps.first(where: { cal.isDate($0.date, inSameDayAs: date) })
                let ids = snap.map { Set($0.completedTaskIDs) } ?? []
                dayData.append((date, cal.component(.weekday, from: date), ids))
            }

            for task in list.tasks {
                let completedDays = dayData.filter { $0.completedIDs.contains(task.id) }.count
                let rate = Int(Double(completedDays) / Double(days) * 100)

                // Weekday vs weekend split
                let weekdayDone = dayData.filter { (2...6).contains($0.weekday) && $0.completedIDs.contains(task.id) }.count
                let weekdayTotal = dayData.filter { (2...6).contains($0.weekday) }.count
                let weekendDone = dayData.filter { [1, 7].contains($0.weekday) && $0.completedIDs.contains(task.id) }.count
                let weekendTotal = dayData.filter { [1, 7].contains($0.weekday) }.count

                let wdRate = weekdayTotal > 0 ? Int(Double(weekdayDone) / Double(weekdayTotal) * 100) : 0
                let weRate = weekendTotal > 0 ? Int(Double(weekendDone) / Double(weekendTotal) * 100) : 0

                // Trend: compare first 7 days vs last 7 days
                let recentDone = dayData.prefix(7).filter { $0.completedIDs.contains(task.id) }.count
                let olderDone = dayData.suffix(7).filter { $0.completedIDs.contains(task.id) }.count
                let trend: String
                if recentDone > olderDone + 1 { trend = "IMPROVING" }
                else if olderDone > recentDone + 1 { trend = "DECLINING" }
                else { trend = "STEADY" }

                // Current streak
                var streak = 0
                for day in dayData {
                    if day.completedIDs.contains(task.id) { streak += 1 }
                    else { break }
                }

                section += "  \(task.title): \(rate)% (\(completedDays)/\(days)d) "
                section += "| weekday:\(wdRate)% weekend:\(weRate)% "
                section += "| trend:\(trend) | streak:\(streak)d\n"
            }
            sections.append(section)
        }

        return sections.joined(separator: "\n")
    }
}
