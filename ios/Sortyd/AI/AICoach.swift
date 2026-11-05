// MARK: - AICoach.swift
// Sortyd — AI Coach using the Cloudflare inference proxy
// Handles: Weekly Recap, Procrastination Detection, List Health,
//          Behavioural Pillars, NL Task Entry, Starter Lists

import Foundation
import Combine
import SwiftUI

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

    init(id: UUID = UUID(), taskTitle: String, daysSkipped: Int, suggestion: String, actionLabel: String) {
        self.id = id
        self.taskTitle = taskTitle
        self.daysSkipped = daysSkipped
        self.suggestion = suggestion
        self.actionLabel = actionLabel
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let idStr = try? c.decode(String.self, forKey: .id),
           let uuid = UUID(uuidString: idStr) {
            id = uuid
        } else {
            id = UUID()
        }
        taskTitle = (try? c.decode(String.self, forKey: .taskTitle)) ?? "Habit Task"
        if let intDays = try? c.decode(Int.self, forKey: .daysSkipped) {
            daysSkipped = intDays
        } else if let dblDays = try? c.decode(Double.self, forKey: .daysSkipped) {
            daysSkipped = Int(dblDays.rounded())
        } else {
            daysSkipped = 3
        }
        suggestion = (try? c.decode(String.self, forKey: .suggestion)) ?? "Start with a 2-minute version right after your morning anchor."
        actionLabel = (try? c.decode(String.self, forKey: .actionLabel)) ?? "Do 2 min"
    }

    enum CodingKeys: String, CodingKey {
        case id, taskTitle, daysSkipped, suggestion, actionLabel
    }
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

struct CachedListAnalysis: Codable {
    var cachedAt: Date
    var weeklyRecap: WeeklyRecap?
    var procrastinationFlags: [ProcrastinationFlag]
    var behaviouralAnalysis: BehaviouralAnalysis?
}

struct BatchBehaviouralItem: Codable {
    let listId: String
    let pillars: [BehaviouralPillar]
    let overallInsight: String
    let criticalPillar: String
}

struct BatchWeeklyRecapItem: Codable {
    let listId: String
    let headline: String
    let summary: String
    let highlight: String
    let nudge: String
    let grade: String
    let gradeReason: String
}

struct BatchProcrastinationItem: Codable {
    let listId: String
    let flags: [ProcrastinationFlag]
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

    init(id: UUID = UUID(), name: String, emoji: String, score: Int, status: String, insight: String, tasks: [String], advice: String) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.score = score
        self.status = status
        self.insight = insight
        self.tasks = tasks
        self.advice = advice
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let idStr = try? c.decode(String.self, forKey: .id),
           let uuid = UUID(uuidString: idStr) {
            id = uuid
        } else {
            id = UUID()
        }
        name    = (try? c.decode(String.self, forKey: .name)) ?? "Core Habit"
        emoji   = (try? c.decode(String.self, forKey: .emoji)) ?? "🎯"
        if let intScore = try? c.decode(Int.self, forKey: .score) {
            score = max(0, min(100, intScore))
        } else if let dblScore = try? c.decode(Double.self, forKey: .score) {
            score = max(0, min(100, Int(dblScore.rounded())))
        } else {
            score = 75
        }
        status  = (try? c.decode(String.self, forKey: .status)) ?? (score >= 70 ? "Strong" : (score >= 45 ? "Developing" : "Struggling"))
        insight = (try? c.decode(String.self, forKey: .insight)) ?? "Consistent daily execution builds lasting momentum."
        tasks   = (try? c.decode([String].self, forKey: .tasks)) ?? []
        if let advStr = try? c.decode(String.self, forKey: .advice) {
            advice = advStr
        } else if let advArr = try? c.decode([String].self, forKey: .advice) {
            advice = advArr.joined(separator: " ")
        } else {
            advice = "Anchor this habit to a fixed time slot each day."
        }
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
    @Published var cacheAge: Date? = nil

    // The Worker selects the Cloudflare model and enforces request limits.
    private let model  = "llama3.1-8b"
    private let apiURL = URL(string: "https://api.sortyd.com/api/ai")!

    private let installationDefaults: UserDefaults
    private var observedHistoryStart: Date?
    private let requestSession: URLSession
    private var batchRequests: [String: Task<Void, Never>] = [:]

    init(defaults: UserDefaults? = nil, session: URLSession = .shared) {
        cacheDefaults = defaults ?? UserDefaults(suiteName: "group.com.sortyd.sortyd") ?? .standard
        installationDefaults = defaults ?? .standard
        requestSession = session
    }

    // MARK: - Weekly Recap

    func generateWeeklyRecap(lists: [TaskList], snapshots: [DailySnapshot]) async {
        observeHistory(lists: lists, snapshots: snapshots)
        isLoading = true
        errorMessage = nil

        let summary = buildWeekSummary(lists: lists, snapshots: snapshots)
        let windowDays = min(7, daysSinceInstall + 1)
        let groupDefaults: UserDefaults? = cacheDefaults
        let language = AppLanguage(rawValue: groupDefaults?.string(forKey: "sortyd_app_language") ?? "en") ?? .english
        let langName = language == .arabic ? "Arabic" : (language == .spanish ? "Spanish" : (language == .chinese ? "Chinese" : "English"))
        let langNote = "IMPORTANT: You MUST respond in \(langName). Every single text value in the JSON must be written in fluent \(langName). Do not use English."

        let prompt = """
        You are a sharp, no-BS habit coach. You see patterns others miss.
        Rules: Use "you", never "the user". Name SPECIFIC tasks. Short punchy sentences. No fluff.
        \(langNote)
        \(newUserNote)
        DATA (\(windowDays) days, per-task daily breakdown):
        \(summary)

        ANALYSIS INSTRUCTIONS:
        - Look at which specific tasks were skipped and on which days.
        - Identify the weakest task (lowest completion) and the strongest.
        - Notice day-of-week patterns (e.g., weekends drop, Mondays strong).
        - Check if streaks are building or breaking.
        - The headline should reference a SPECIFIC pattern you found.
        - For Arabic: Ensure the tone is professional yet direct.
        - For Spanish: Use an encouraging but firm "tú" tone.

        Respond ONLY with valid JSON (no markdown, no backticks):
        {
          "headline": "Max 6 words + 1 emoji. Reference a specific finding.",
          "summary": "2 sentences. Name the weakest task and strongest task BY NAME. State the specific pattern.",
          "highlight": "Name ONE specific task + what they did well.",
          "nudge": "ONE specific action targeting their weakest task. Verb-first, under 15 words.",
          "grade": "Letter grade: A, A-, B+, B, B-, C+, C, or D",
          "gradeReason": "Reference the data explicitly."
        }
        """

        if let result: WeeklyRecap = await callCerebras(prompt: prompt, maxTokens: 1500) {
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
        observeHistory(lists: lists, snapshots: snapshots)
        isLoading = true
        errorMessage = nil

        let flagData = buildProcrastinationData(lists: lists, snapshots: snapshots)
        guard !flagData.isEmpty else {
            procrastinationFlags = []
            isLoading = false
            return
        }

        let procWindow = min(14, daysSinceInstall + 1)
        let groupDefaults: UserDefaults? = cacheDefaults
        let language = AppLanguage(rawValue: groupDefaults?.string(forKey: "sortyd_app_language") ?? "en") ?? .english
        let langName = language == .arabic ? "Arabic" : (language == .spanish ? "Spanish" : (language == .chinese ? "Chinese" : "English"))
        let langNote = "IMPORTANT: You MUST respond in \(langName). All JSON text values including taskTitle and suggestion must be in fluent \(langName)."

        let prompt = """
        You are a direct habit coach who diagnoses WHY tasks get skipped.
        Rules: Use "you". Name each task. One punchy sentence. Diagnose the root cause, don't just say "try harder".
        \(langNote)
        \(procNewNote)
        These tasks are being skipped (includes completion rate, last done, and most-skipped day):
        \(flagData)

        ANALYSIS INSTRUCTIONS:
        - If "lastDone" is "never", the task may be too ambitious or poorly defined.
        - If done 1-3 out of \(procWindow), there's a trigger/motivation problem.
        - If "mostSkippedDay" clusters on weekends, it's a routine gap.
        - Suggest a ROOT CAUSE: too vague? too hard? wrong time of day? no trigger? boring?
        - Ensure suggestions are culturally relevant for \(langName) speakers.

        Respond ONLY with valid JSON array (no markdown, no backticks):
        [
          {
            "id": "<same UUID>",
            "taskTitle": "<same title in \(langName)>",
            "daysSkipped": <\(procWindow) minus done count>,
            "suggestion": "Diagnose WHY. Under 20 words in \(langName).",
            "actionLabel": "Short localized label like 'Shrink it' or 'Reschedule'"
          }
        ]
        Max 6 items.
        """

        if let result: [ProcrastinationFlag] = await callCerebrasArray(prompt: prompt, maxTokens: 1500) {
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

        let groupDefaults: UserDefaults? = cacheDefaults
        let language = AppLanguage(rawValue: groupDefaults?.string(forKey: "sortyd_app_language") ?? "en") ?? .english
        let langName = language == .arabic ? "Arabic" : (language == .spanish ? "Spanish" : (language == .chinese ? "Chinese" : "English"))
        let langNote = "IMPORTANT: You MUST respond in \(langName). Every single text value in the JSON must be written in fluent \(langName). Do not use English."

        let prompt = """
        You are a habit coach who diagnoses list problems. Use "you", never "the user".
        \(langNote)

        List: "\(list.name)"
        Total tasks: \(list.tasks.count)
        Avg completion (30 days): \(CompletionPolicy.percentage(avgCompletion))%
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
          "label": "Translate 'Healthy' or 'Overloaded' or 'Stale' or 'Needs Work' or 'Great Shape' into \(langName)",
          "insight": "Name the problem. e.g. 'You have 3 tasks you've never done — they're dragging your score down.' Under 20 words.",
          "tips": ["Name a specific task or pattern in each tip. Verb-first, under 10 words.", "tip 2", "tip 3"]
        }
        """

        return await callCerebras(prompt: prompt, maxTokens: 1200)
    }

    // MARK: - Behavioural Pillar Analysis

    func analyseBehaviouralPillars(lists: [TaskList], snapshots: [DailySnapshot]) async {
        observeHistory(lists: lists, snapshots: snapshots)
        isBehaviourLoading = true
        behaviouralAnalysis = nil

        let taskData = buildTaskCompletionData(lists: lists, snapshots: snapshots)
        guard !taskData.isEmpty else {
            isBehaviourLoading = false
            return
        }

        let groupDefaults: UserDefaults? = cacheDefaults
        let language = AppLanguage(rawValue: groupDefaults?.string(forKey: "sortyd_app_language") ?? "en") ?? .english
        let langName = language == .arabic ? "Arabic" : (language == .spanish ? "Spanish" : (language == .chinese ? "Chinese" : "English"))
        let statusValues: String
        switch language {
        case .english:
            statusValues = "Strong, Developing, Struggling"
        case .spanish:
            statusValues = "Fuerte, En desarrollo, Con dificultades"
        case .arabic:
            statusValues = "قوي، قيد التطوير، متعثر"
        case .chinese:
            statusValues = "强项、发展中、需改善"
        }
        let langNote = "IMPORTANT: You MUST respond in \(langName). All JSON text values including pillar names, status, insights, and advice must be in fluent \(langName). For status, use ONLY one of these values: \(statusValues). Do not use English status words unless the language is English."

        let prompt = """
        You are a habit coach who finds the real patterns. Use "you", never "the user".
        Be specific — name tasks, name days, name numbers.
        \(langNote)

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
              "name": "Pillar name (Translate into \(langName))",
              "emoji": "<single emoji>",
              "score": <0-100 based on actual completion data>,
              "status": "One of: \(statusValues)",
              "insight": "Name exact tasks and quote only statistics explicitly present in DATA. If uncertain, describe the pattern without numbers.",
              "tasks": ["exact task title 1", "exact task title 2"],
              "advice": "Target the weakest task in this pillar. e.g. 'Do [task] right after [strongest task] to piggyback the habit.' Under 15 words."
            }
          ],
          "overallInsight": "Describe the largest pattern supported by DATA in at most two sentences. Never introduce example statistics.",
          "criticalPillar": "Name of the pillar needing most attention"
        }
        """

        if let result: BehaviouralAnalysis = await callCerebras(prompt: prompt, maxTokens: 2800) {
            behaviouralAnalysis = result
        } else if errorMessage == nil {
            errorMessage = "Couldn't read the AI response. Try again in a moment."
        }
        isBehaviourLoading = false
    }

    // MARK: - Natural Language Task Parsing

    func parseNaturalLanguageTask(_ input: String) async -> ParsedTask? {
        let groupDefaults: UserDefaults? = cacheDefaults
        let language = AppLanguage(rawValue: groupDefaults?.string(forKey: "sortyd_app_language") ?? "en") ?? .english
        let langName = language == .arabic ? "Arabic" : (language == .spanish ? "Spanish" : (language == .chinese ? "Chinese" : "English"))
        let langNote = "IMPORTANT: You MUST respond in \(langName). The parsed 'title' must be in \(langName)."

        let examples: String
        switch language {
        case .arabic:
            examples = """
            "اتصل بأمي الساعة 6 مساءً" → {"title":"اتصل بأمي","hasReminder":true,"reminderHour":18,"reminderMinute":0}
            "اذهب للجري" → {"title":"اذهب للجري","hasReminder":false,"reminderHour":null,"reminderMinute":null}
            "اجتماع الفريق 9:30 صباحاً" → {"title":"اجتماع الفريق","hasReminder":true,"reminderHour":9,"reminderMinute":30}
            "call mom at 6pm" → {"title":"اتصل بأمي","hasReminder":true,"reminderHour":18,"reminderMinute":0}
            """
        case .spanish:
            examples = """
            "llamar a mamá a las 6pm" → {"title":"Llamar a mamá","hasReminder":true,"reminderHour":18,"reminderMinute":0}
            "salir a correr" → {"title":"Salir a correr","hasReminder":false,"reminderHour":null,"reminderMinute":null}
            "reunión de equipo 9:30am" → {"title":"Reunión de equipo","hasReminder":true,"reminderHour":9,"reminderMinute":30}
            "call mom at 6pm" → {"title":"Llamar a mamá","hasReminder":true,"reminderHour":18,"reminderMinute":0}
            """
        case .chinese:
            examples = """
            "晚上6点给妈妈打电话" → {"title":"给妈妈打电话","hasReminder":true,"reminderHour":18,"reminderMinute":0}
            "去跑步" → {"title":"去跑步","hasReminder":false,"reminderHour":null,"reminderMinute":null}
            "上午9点30分团队会议" → {"title":"团队会议","hasReminder":true,"reminderHour":9,"reminderMinute":30}
            "call mom at 6pm" → {"title":"给妈妈打电话","hasReminder":true,"reminderHour":18,"reminderMinute":0}
            """
        default:
            examples = """
            "call mom at 6pm" → {"title":"Call mom","hasReminder":true,"reminderHour":18,"reminderMinute":0}
            "go for a run" → {"title":"Go for a run","hasReminder":false,"reminderHour":null,"reminderMinute":null}
            "team standup 9:30am" → {"title":"Team standup","hasReminder":true,"reminderHour":9,"reminderMinute":30}
            """
        }

        let prompt = """
        Parse this task input from a productivity app. Extract the task title and any time/reminder info.
        \(langNote)

        Input: "\(input)"

        Respond ONLY with valid JSON (no markdown, no backticks):
        {
          "title": "Clean task title in \(langName), remove time references",
          "hasReminder": true or false,
          "reminderHour": <0-23 or null>,
          "reminderMinute": <0-59 or null>
        }

        Examples (note: title is always in \(langName) regardless of input language):
        \(examples)
        """

        return await callCerebras(prompt: prompt, maxTokens: 900)
    }

    // MARK: - Daily Summary (one-liner for 10 PM notification)

    /// Returns a single punchy sentence summarising today's performance on the active list.
    func generateDailySummary(for list: TaskList, snapshots: [DailySnapshot]) async -> String? {
        guard !list.isArchived, !list.isTodo, !list.isWeekly else { return nil }

        let cal = Calendar.current
        let today = ReminderPolicy.dayStart(Date(), calendar: cal)
        let todaySnap = snapshots.first(where: {
            $0.listID == list.id && cal.isDate($0.date, inSameDayAs: today)
        })

        let completedIDs = Set(todaySnap?.completedTaskIDs ?? [])
        let total = list.tasks.count
        let done  = list.tasks.filter { completedIDs.contains($0.id) }.count
        let pct   = total > 0 ? Int(Double(done) / Double(total) * 100) : 0

        let completedTitles = list.tasks.filter {  completedIDs.contains($0.id) }.map(\.title)
        let missedTitles    = list.tasks.filter { !completedIDs.contains($0.id) }.map(\.title)

        let groupDefaults: UserDefaults? = cacheDefaults
        let language = AppLanguage(rawValue: groupDefaults?.string(forKey: "sortyd_app_language") ?? "en") ?? .english
        let langName = language == .arabic ? "Arabic" : (language == .spanish ? "Spanish" : (language == .chinese ? "Chinese" : "English"))
        let langNote = "IMPORTANT: You MUST respond in \(langName). Output ONLY the single sentence in \(langName)."

        let prompt = """
        You are a sharp habit coach writing a single push notification sentence. No fluff, no filler.
        \(langNote)

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

        guard let data = await executeRequest(prompt: prompt, maxTokens: 900) else { return nil }
        return extractText(from: data)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n").first
    }

    /// MARK: - Starter List Generation
    
    func generateStarterList(goal: String) async -> StarterList? {
        let startedAt = Date()
        errorMessage = nil
        let groupDefaults: UserDefaults? = cacheDefaults
        let language = AppLanguage(rawValue: groupDefaults?.string(forKey: "sortyd_app_language") ?? "en") ?? .english
        let langName = language == .arabic ? "Arabic" : (language == .spanish ? "Spanish" : (language == .chinese ? "Chinese" : "English"))
        let langNote = "IMPORTANT: You MUST respond in \(langName). The listName and every task in the tasks array must be in fluent \(langName)."

        let prompt = """
        You are a world-class habit coach helping someone build their first task list in Sortyd.
        Their goal: "\(goal)"
        \(langNote)

        YOUR JOB: Generate a complete, well-structured daily habit list that covers the goal the user actually asked for.

        TASK COUNT RULES — this is critical:
        - ALWAYS generate between 4 and 6 tasks. Never fewer than 4. Never more than 6.
        - If the goal is broad, find distinct daily actions that build that lifestyle.
        - If the goal is narrow, expand into directly related actions only.
        - Do not add generic wellness, fitness, hydration, sleep, or exercise tasks unless the user's goal is clearly about health, fitness, body, recovery, sleep, or phone usage.
        - Think in SYSTEMS, not single tasks.

        TASK QUALITY RULES:
        - Each task must be concrete and trackable.
        - Keep tasks short: 3–6 words in \(langName). Capitalize appropriately for the language.
        - For Arabic: Use natural, modern phrasing.
        - For Spanish: Use direct, actionable verbs.

        Stay strictly within the stated goal. Do not introduce exercise, calorie, step, sleep,
        or hydration tasks for learning, financial, creative, career, or household goals.
        For an explicitly fitness-related goal, make safe, achievable movement tasks appropriate
        to the goal, without prescribing aggressive calorie or exercise targets.

        CRITICAL — listName rules (violations will break the UI):
        - Return ONLY the core 1–3 word name. No emojis.
        - NEVER append filler words. Banned suffixes: System, Routine, Builder, Program, Habit, Habits, Plan, Journey, Challenge, Framework, Guide, Protocol, Method, Practice, Tracker, Log, Regimen, Schedule, Rutina, Sistema, Programa, Hábitos, Viaje, Desafío, نظام, روتين, برنامج, خطة
        - Examples of WRONG vs RIGHT:
          "get fit"        → WRONG: "Fitness System"    RIGHT: "Get Fit"
          "read more"      → WRONG: "Reading Habit"     RIGHT: "Read More"
          "wake up early"  → WRONG: "Early Riser Routine" RIGHT: "Wake Up Early"
          "learn Spanish"  → WRONG: "Spanish Builder"   RIGHT: "Learn Spanish"

        Respond ONLY with valid JSON (no markdown, no backticks):
        {
          "emoji": "single relevant emoji",
          "listName": "1–3 words, core goal only, in \(langName), NO filler suffixes",
          "tasks": ["Task 1 in \(langName)", "Task 2", "Task 3", "Task 4", "Task 5"]
        }
        """

        let result: StarterList? = await callCerebras(prompt: prompt, maxTokens: 1800)
        AppTelemetry.aiResult(feature: "starter_list", outcome: result == nil ? "failed" : "success", startedAt: startedAt)
        return result
    }

    // MARK: - Private: Cerebras API

    private func callCerebras<T: Decodable>(prompt: String, maxTokens: Int = 800) async -> T? {
        guard let responseData = await postToCerebras(prompt: prompt, maxTokens: maxTokens) else { return nil }
        return parseResponse(responseData)
    }

    private func callCerebrasArray<T: Decodable>(prompt: String, maxTokens: Int = 800) async -> [T]? {
        guard let responseData = await postToCerebras(prompt: prompt, maxTokens: maxTokens) else { return nil }
        return parseArrayResponse(responseData)
    }

    private func aiRequest(body: Data) -> URLRequest {
        var request = URLRequest(url: apiURL)
        request.httpMethod    = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }

    // MARK: - Caching (24h per list)

    private var cacheKey: String {
        let language = cacheDefaults.string(forKey: "sortyd_app_language") ?? "en"
        return "sortyd_ai_cache_v2_\(language)"
    }
    private let cacheDefaults: UserDefaults

    private func loadCache() -> [String: CachedListAnalysis] {
        guard let data = cacheDefaults.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode([String: CachedListAnalysis].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func saveCache(_ cache: [String: CachedListAnalysis]) {
        if let encoded = try? JSONEncoder().encode(cache) {
            cacheDefaults.set(encoded, forKey: cacheKey)
        }
    }

    private func isCacheValid(for entry: CachedListAnalysis) -> Bool {
        entry.behaviouralAnalysis != nil && entry.weeklyRecap != nil &&
        ReminderPolicy.dayStart(entry.cachedAt) == ReminderPolicy.dayStart(Date())
    }

    func loadFromCache(for listID: UUID) -> Bool {
        let cache = loadCache()
        let key = listID.uuidString
        guard let entry = cache[key], isCacheValid(for: entry) else { return false }
        weeklyRecap = entry.weeklyRecap
        procrastinationFlags = entry.procrastinationFlags
        behaviouralAnalysis = entry.behaviouralAnalysis
        cacheAge = entry.cachedAt
        return true
    }

    func loadBestAvailableCache(for listID: UUID) -> (found: Bool, isStale: Bool) {
        let cache = loadCache()
        let key = listID.uuidString
        guard let entry = cache[key] else {
            weeklyRecap = nil
            procrastinationFlags = []
            behaviouralAnalysis = nil
            cacheAge = nil
            return (false, false)
        }
        weeklyRecap = entry.weeklyRecap
        procrastinationFlags = entry.procrastinationFlags
        behaviouralAnalysis = entry.behaviouralAnalysis
        cacheAge = entry.cachedAt
        let isValid = isCacheValid(for: entry)
        return (entry.behaviouralAnalysis != nil, !isValid)
    }

    func buildLocalFallback(for list: TaskList, snapshots: [DailySnapshot]) -> CachedListAnalysis {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let listSnaps = snapshots.filter { $0.listID == list.id }
        let recentSnaps = (0..<7).compactMap { offset -> DailySnapshot? in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return listSnaps.first { cal.isDate($0.date, inSameDayAs: day) }
        }
        let avgRate: Int = {
            if !recentSnaps.isEmpty {
                let sum = recentSnaps.reduce(0.0) { $0 + $1.completionFraction }
                return max(0, min(100, Int((sum / Double(recentSnaps.count) * 100).rounded())))
            }
            return list.completionPercentage
        }()

        struct FallbackTaskStat {
            let id: UUID
            let title: String
            let score: Int
            let skipped: Int
        }

        let taskScores: [FallbackTaskStat] = list.tasks.map { t in
            if !recentSnaps.isEmpty {
                let doneDays = recentSnaps.filter { $0.completedTaskIDs.contains(t.id) }.count
                let sc = Int((Double(doneDays) / Double(recentSnaps.count) * 100).rounded())
                return FallbackTaskStat(id: t.id, title: t.title, score: sc, skipped: max(0, recentSnaps.count - doneDays))
            } else {
                let sc = t.isCompleted ? 100 : max(45, avgRate)
                return FallbackTaskStat(id: t.id, title: t.title, score: sc, skipped: t.isCompleted ? 0 : 3)
            }
        }

        let sortedTasks = taskScores.sorted { $0.score > $1.score }
        let strongest = sortedTasks.first?.title ?? list.cleanName
        let weakest = sortedTasks.last?.title ?? strongest

        let mid = max(1, (sortedTasks.count + 1) / 2)
        let primarySlice = Array(sortedTasks.prefix(mid))
        let secondarySlice = Array(sortedTasks.dropFirst(mid))

        let p1Sum = primarySlice.reduce(0) { $0 + $1.score }
        let p1Score = primarySlice.isEmpty ? avgRate : Int((Double(p1Sum) / Double(primarySlice.count)).rounded())
        let primaryTitles = primarySlice.map { $0.title }
        var pillars: [BehaviouralPillar] = [
            BehaviouralPillar(
                name: "\(list.cleanName) Anchor",
                emoji: list.emoji,
                score: p1Score,
                status: p1Score >= 70 ? "Strong" : (p1Score >= 45 ? "Developing" : "Struggling"),
                insight: "Your anchor habits (\(primaryTitles.joined(separator: ", "))) average \(p1Score)% completion over the last 7 days.",
                tasks: primaryTitles,
                advice: "Lock in \"\(strongest)\" at the exact same hour daily to protect your streak."
            )
        ]

        if !secondarySlice.isEmpty {
            let p2Sum = secondarySlice.reduce(0) { $0 + $1.score }
            let p2Score = Int((Double(p2Sum) / Double(secondarySlice.count)).rounded())
            let secondaryTitles = secondarySlice.map { $0.title }
            pillars.append(
                BehaviouralPillar(
                    name: "Follow-Through & Consistency",
                    emoji: "⚡",
                    score: p2Score,
                    status: p2Score >= 70 ? "Strong" : (p2Score >= 45 ? "Developing" : "Struggling"),
                    insight: "Secondary habits (\(secondaryTitles.joined(separator: ", "))) average \(p2Score)% completion.",
                    tasks: secondaryTitles,
                    advice: "Do \"\(weakest)\" immediately after \"\(strongest)\" to eliminate friction."
                )
            )
        }

        let grade: String = {
            if avgRate >= 90 { return "A" }
            if avgRate >= 82 { return "A-" }
            if avgRate >= 75 { return "B+" }
            if avgRate >= 66 { return "B" }
            if avgRate >= 58 { return "B-" }
            if avgRate >= 48 { return "C+" }
            return "C"
        }()

        let recap = WeeklyRecap(
            headline: "\(list.cleanName) at \(avgRate)% rhythm \(list.emoji)",
            summary: "\"\(strongest)\" leads your routine while \"\(weakest)\" is the main opportunity to lift daily completion.",
            highlight: "Consistent execution on \"\(strongest)\" is anchoring \(list.cleanName).",
            nudge: "Stack \"\(weakest)\" right after \"\(strongest)\" tomorrow.",
            grade: grade,
            gradeReason: "\(avgRate)% 7-day completion across \(list.tasks.count) habits."
        )

        let analysis = BehaviouralAnalysis(
            pillars: pillars,
            overallInsight: "Your \(list.cleanName) list is running at \(avgRate)% consistency. Pairing \"\(weakest)\" directly with \"\(strongest)\" will close your biggest daily gap.",
            criticalPillar: pillars.last?.name ?? "\(list.cleanName) Anchor"
        )

        let flags: [ProcrastinationFlag] = sortedTasks
            .filter { $0.skipped >= 3 }
            .prefix(2)
            .map { item in
                ProcrastinationFlag(
                    id: item.id,
                    taskTitle: item.title,
                    daysSkipped: item.skipped,
                    suggestion: "Start \"\(item.title)\" with a 2-minute version right after \"\(strongest)\".",
                    actionLabel: "Do 2 min"
                )
            }

        return CachedListAnalysis(
            cachedAt: Date(),
            weeklyRecap: recap,
            procrastinationFlags: flags,
            behaviouralAnalysis: analysis
        )
    }

    func fetchAndCache(list: TaskList, snapshots: [DailySnapshot], force: Bool = false) async {
        if !force && loadFromCache(for: list.id) {
            return
        }

        var cache = loadCache()
        let listKey = list.id.uuidString
        let fallback = buildLocalFallback(for: list, snapshots: snapshots)
        var entry = cache[listKey] ?? CachedListAnalysis(cachedAt: Date(), weeklyRecap: nil, procrastinationFlags: [], behaviouralAnalysis: nil)

        await analyseBehaviouralPillars(lists: [list], snapshots: snapshots)
        entry.behaviouralAnalysis = behaviouralAnalysis ?? fallback.behaviouralAnalysis

        await generateWeeklyRecap(lists: [list], snapshots: snapshots)
        entry.weeklyRecap = weeklyRecap ?? fallback.weeklyRecap

        await detectProcrastination(lists: [list], snapshots: snapshots)
        entry.procrastinationFlags = procrastinationFlags.isEmpty ? fallback.procrastinationFlags : procrastinationFlags

        behaviouralAnalysis = entry.behaviouralAnalysis
        weeklyRecap = entry.weeklyRecap
        procrastinationFlags = entry.procrastinationFlags
        errorMessage = nil

        entry.cachedAt = Date()
        cache[listKey] = entry
        saveCache(cache)
    }

    // MARK: - Batch Analysis Methods

    func fetchAllListsBatch(lists: [TaskList], snapshots: [DailySnapshot], force: Bool = false) async {
        let requestKey = cacheKey + lists.map { $0.id.uuidString }.sorted().joined()
        if let existing = batchRequests[requestKey] {
            await existing.value
            return
        }
        let work = Task { await self.performBatch(lists: lists, snapshots: snapshots, force: force) }
        batchRequests[requestKey] = work
        await work.value
        batchRequests.removeValue(forKey: requestKey)
    }

    private func performBatch(lists: [TaskList], snapshots: [DailySnapshot], force: Bool) async {
        let requestedCacheKey = cacheKey
        isLoading = true
        isBehaviourLoading = true
        errorMessage = nil

        let cache = loadCache()
        
        let listsToFetch: [TaskList]
        if force {
            listsToFetch = lists
        } else {
            listsToFetch = lists.filter { list in
                guard let entry = cache[list.id.uuidString] else { return true }
                return !isCacheValid(for: entry)
            }
        }

        guard !listsToFetch.isEmpty else {
            isLoading = false
            isBehaviourLoading = false
            return
        }

        async let behaviouralResult = batchAnalyseBehaviouralPillars(lists: listsToFetch, snapshots: snapshots)
        async let weeklyResult = batchGenerateWeeklyRecap(lists: listsToFetch, snapshots: snapshots)
        async let procrastinationResult = batchDetectProcrastination(lists: listsToFetch, snapshots: snapshots)

        let (behaviours, recaps, procrastinations) = await (behaviouralResult, weeklyResult, procrastinationResult)

        // A language switch while requests are running must not overwrite the new language's cache.
        guard requestedCacheKey == cacheKey else {
            isLoading = false
            isBehaviourLoading = false
            return
        }
        var updatedCache = loadCache()
        let fetchTime = Date()

        for list in listsToFetch {
            let listKey = list.id.uuidString
            let fallback = buildLocalFallback(for: list, snapshots: snapshots)
            var entry = updatedCache[listKey] ?? CachedListAnalysis(cachedAt: fetchTime, weeklyRecap: nil, procrastinationFlags: [], behaviouralAnalysis: nil)

            let matchedBehaviour = behaviours[listKey] ?? behaviours[listKey.uppercased()] ?? behaviours[listKey.lowercased()]
            let matchedRecap = recaps[listKey] ?? recaps[listKey.uppercased()] ?? recaps[listKey.lowercased()]
            let matchedFlags = procrastinations[listKey] ?? procrastinations[listKey.uppercased()] ?? procrastinations[listKey.lowercased()]

            entry.behaviouralAnalysis = matchedBehaviour ?? entry.behaviouralAnalysis ?? fallback.behaviouralAnalysis
            entry.weeklyRecap = matchedRecap ?? entry.weeklyRecap ?? fallback.weeklyRecap
            entry.procrastinationFlags = matchedFlags ?? (entry.procrastinationFlags.isEmpty ? fallback.procrastinationFlags : entry.procrastinationFlags)
            entry.cachedAt = fetchTime
            updatedCache[listKey] = entry
        }

        errorMessage = nil
        saveCache(updatedCache)

        isLoading = false
        isBehaviourLoading = false
    }

    func batchAnalyseBehaviouralPillars(lists: [TaskList], snapshots: [DailySnapshot]) async -> [String: BehaviouralAnalysis] {
        observeHistory(lists: lists, snapshots: snapshots)
        let taskData = buildTaskCompletionData(lists: lists, snapshots: snapshots)
        guard !taskData.isEmpty else {
            return [:]
        }

        let groupDefaults: UserDefaults? = cacheDefaults
        let language = AppLanguage(rawValue: groupDefaults?.string(forKey: "sortyd_app_language") ?? "en") ?? .english
        let langName = language == .arabic ? "Arabic" : (language == .spanish ? "Spanish" : (language == .chinese ? "Chinese" : "English"))
        let statusValues: String
        switch language {
        case .english:
            statusValues = "Strong, Developing, Struggling"
        case .spanish:
            statusValues = "Fuerte, En desarrollo, Con dificultades"
        case .arabic:
            statusValues = "قوي، قيد التطوير، متعثر"
        case .chinese:
            statusValues = "强项、发展中、需改善"
        }
        let langNote = "IMPORTANT: You MUST respond in \(langName). All JSON text values including pillar names, status, insights, and advice must be in fluent \(langName). For status, use ONLY one of these values: \(statusValues). Do not use English status words unless the language is English."

        let prompt = """
        You are a habit coach who finds the real patterns. Use "you", never "the user".
        Be specific — name tasks, name days, name numbers.
        \(langNote)

        You are analyzing multiple lists at once. You must provide a separate analysis for each list.
        Each list is identified by its ID in the input data. Do not mix tasks or coaching between different lists.

        DATA (per task: completion rate, weekday vs weekend split, trend, current streak):
        \(taskData)

        ANALYSIS INSTRUCTIONS:
        For each list:
        - Group tasks into 2–4 behavioural pillars (Health, Discipline, Mindset, Learning, etc.)
        - The pillar score = average completion of its tasks. Don't inflate it.
        - Look at weekday vs weekend rates — if weekend drops >20%, call it out
        - Look at trends — DECLINING tasks are red flags, IMPROVING tasks are wins
        - Look at streaks – a 0-day streak on a daily task means it just broke
        - The overallInsight MUST name the single biggest pattern (e.g. "weekends", "one task dragging everything down", "steady improvement")

        Respond ONLY with a valid JSON array of objects (no markdown, no backticks, no wrapping other than the array):
        [
          {
            "listId": "<exact UUID string of the list from the input>",
            "pillars": [
              {
                "id": "<UUID string>",
                "name": "Pillar name (Translate into \(langName))",
                "emoji": "<single emoji>",
                "score": <0-100 based on actual completion data>,
                "status": "One of: \(statusValues)",
                "insight": "Name exact tasks and quote only statistics explicitly present in DATA. If uncertain, describe the pattern without numbers.",
                "tasks": ["exact task title 1", "exact task title 2"],
                "advice": "Target the weakest task in this pillar. e.g. 'Do [task] right after [strongest task] to piggyback the habit.' Under 15 words."
              }
            ],
            "overallInsight": "Describe the largest pattern supported by DATA in at most two sentences. Never introduce example statistics.",
            "criticalPillar": "Name of the pillar needing most attention"
          }
        ]
        """

        if let result: [BatchBehaviouralItem] = await callCerebrasArray(prompt: prompt, maxTokens: 8000) {
            var dict: [String: BehaviouralAnalysis] = [:]
            for item in result {
                dict[item.listId] = BehaviouralAnalysis(pillars: item.pillars, overallInsight: item.overallInsight, criticalPillar: item.criticalPillar)
            }
            return dict
        }
        return [:]
    }

    func batchGenerateWeeklyRecap(lists: [TaskList], snapshots: [DailySnapshot]) async -> [String: WeeklyRecap] {
        observeHistory(lists: lists, snapshots: snapshots)
        let summary = buildWeekSummary(lists: lists, snapshots: snapshots)
        let windowDays = min(7, daysSinceInstall + 1)
        let groupDefaults: UserDefaults? = cacheDefaults
        let language = AppLanguage(rawValue: groupDefaults?.string(forKey: "sortyd_app_language") ?? "en") ?? .english
        let langName = language == .arabic ? "Arabic" : (language == .spanish ? "Spanish" : (language == .chinese ? "Chinese" : "English"))
        let langNote = "IMPORTANT: You MUST respond in \(langName). Every single text value in the JSON must be written in fluent \(langName). Do not use English."

        let prompt = """
        You are a sharp, no-BS habit coach. You see patterns others miss.
        Rules: Use "you", never "the user". Name SPECIFIC tasks. Short punchy sentences. No fluff.
        \(langNote)
        \(newUserNote)

        You are analyzing multiple lists at once. You must provide a separate weekly recap for each list.
        Each list is identified by its ID in the input data. Do not mix tasks or recaps between different lists.

        DATA (\(windowDays) days, per-task daily breakdown):
        \(summary)

        ANALYSIS INSTRUCTIONS:
        For each list:
        - Look at which specific tasks were skipped and on which days.
        - Identify the weakest task (lowest completion) and the strongest.
        - Notice day-of-week patterns (e.g., weekends drop, Mondays strong).
        - Check if streaks are building or breaking.
        - The headline should reference a SPECIFIC pattern you found.
        - For Arabic: Ensure the tone is professional yet direct.
        - For Spanish: Use an encouraging but firm "tú" tone.

        Respond ONLY with a valid JSON array of objects (no markdown, no backticks, no wrapping other than the array):
        [
          {
            "listId": "<exact UUID string of the list from the input>",
            "headline": "Max 6 words + 1 emoji. Reference a specific finding.",
            "summary": "2 sentences. Name the weakest task and strongest task BY NAME. State the specific pattern.",
            "highlight": "Name ONE specific task + what they did well.",
            "nudge": "ONE specific action targeting their weakest task. Verb-first, under 15 words.",
            "grade": "Letter grade: A, A-, B+, B, B-, C+, C, or D",
            "gradeReason": "Reference the data explicitly."
          }
        ]
        """

        if let result: [BatchWeeklyRecapItem] = await callCerebrasArray(prompt: prompt, maxTokens: 5000) {
            var dict: [String: WeeklyRecap] = [:]
            for item in result {
                dict[item.listId] = WeeklyRecap(
                    headline: item.headline,
                    summary: item.summary,
                    highlight: item.highlight,
                    nudge: item.nudge,
                    grade: item.grade,
                    gradeReason: item.gradeReason
                )
            }
            return dict
        }
        return [:]
    }

    func batchDetectProcrastination(lists: [TaskList], snapshots: [DailySnapshot]) async -> [String: [ProcrastinationFlag]] {
        observeHistory(lists: lists, snapshots: snapshots)
        let flagData = buildProcrastinationData(lists: lists, snapshots: snapshots)
        guard !flagData.isEmpty else {
            return [:]
        }

        let procWindow = min(14, daysSinceInstall + 1)
        let groupDefaults: UserDefaults? = cacheDefaults
        let language = AppLanguage(rawValue: groupDefaults?.string(forKey: "sortyd_app_language") ?? "en") ?? .english
        let langName = language == .arabic ? "Arabic" : (language == .spanish ? "Spanish" : (language == .chinese ? "Chinese" : "English"))
        let langNote = "IMPORTANT: You MUST respond in \(langName). All JSON fields suggestion and actionLabel must be in fluent \(langName)."

        let prompt = """
        You detect chronic avoidance and call it what it is. Be direct but action-focused.
        \(langNote)
        \(procNewNote)

        You are analyzing multiple lists at once. You must provide procrastination flags for each list.
        Each task entry in the input data has a "listId". Group the procrastination flags by their respective "listId".

        DATA (avoided tasks over \(procWindow) days):
        \(flagData)

        INSTRUCTIONS:
        For each flagged task:
        - Diagnose why they might be avoiding it.
        - Give a hyper-specific, micro-action recommendation to get started.
        - The actionLabel should be a button label that starts with a verb, e.g. "Do 2 min" or "Reset target".
        - The suggestion must name the task and be under 12 words.

        Respond ONLY with a valid JSON array of objects (no markdown, no backticks, no wrapping other than the array):
        [
          {
            "listId": "<exact UUID string of the list containing the task>",
            "flags": [
              {
                "id": "<UUID string of task from prompt data>",
                "taskTitle": "exact task title",
                "daysSkipped": <number of days skipped>,
                "suggestion": "sharp action advice. max 12 words.",
                "actionLabel": "Verby label. max 3 words."
              }
            ]
          }
        ]
        """

        if let result: [BatchProcrastinationItem] = await callCerebrasArray(prompt: prompt, maxTokens: 5000) {
            var dict: [String: [ProcrastinationFlag]] = [:]
            for item in result {
                dict[item.listId] = item.flags
            }
            return dict
        }
        return [:]
    }

    // MARK: - Network calls

    private func postToCerebras(prompt: String, maxTokens: Int = 800) async -> Data? {
        let groundedPrompt = prompt + "\nFor coaching based on history: use only the supplied metrics. Never invent completion rates, missed days, or trends. Do not copy example findings unless the data supports them. With fewer than seven observed days, explain that weekly patterns are not established."
        return await executeRequest(prompt: groundedPrompt, maxTokens: maxTokens)
    }

    private func executeRequest(prompt: String, maxTokens: Int = 800, attempt: Int = 0) async -> Data? {
        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": maxTokens,
            "temperature": 0.7,
            "reasoning_effort": "low",
            "reasoning_format": "hidden"
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else {
            errorMessage = "Failed to prepare request."
            return nil
        }

        let request = aiRequest(body: data)

        do {
            let (responseData, response) = try await requestSession.data(for: request)
            // Check for a Cerebras error in the body regardless of HTTP status
            // (the proxy forwards Cerebras errors with status 200). The error may
            // be nested under "error" OR at the top level (e.g. the per-minute
            // rate-limit error: {"message":...,"code":"request_quota_exceeded"}).
            if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               json["choices"] == nil,
               let msg = (json["error"] as? [String: Any])?["message"] as? String ?? json["message"] as? String {
                let lower = msg.lowercased()
                let code  = ((json["error"] as? [String: Any])?["code"] as? String ?? json["code"] as? String)?.lowercased() ?? ""

                let isPerMinute = lower.contains("per minute") || lower.contains("requests per") || code == "request_quota_exceeded" || lower.contains("too many requests")
                let isDaily     = lower.contains("per day") || lower.contains("tokens per day") || lower.contains("daily")

                if isPerMinute && !isDaily {
                    // Transient — the free tier caps requests per minute. Back off
                    // and retry a couple of times before giving up.
                    if attempt < 2 {
                        try? await Task.sleep(nanoseconds: UInt64(1_500_000_000 * (attempt + 1)))
                        return await executeRequest(prompt: prompt, maxTokens: maxTokens, attempt: attempt + 1)
                    }
                    errorMessage = "AI is busy right now. Tap the pulse to retry in a moment."
                } else if isDaily {
                    errorMessage = "Daily AI limit reached. Resets at midnight — try again later."
                } else if lower.contains("model") && lower.contains("not found") {
                    errorMessage = "AI model unavailable. Try again later."
                } else {
                    errorMessage = "AI service error: \(msg.prefix(80))."
                }
                return nil
            }
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                // 429 from the proxy/edge is also a transient rate limit — retry.
                if httpResponse.statusCode == 429, attempt < 2 {
                    try? await Task.sleep(nanoseconds: UInt64(1_500_000_000 * (attempt + 1)))
                    return await executeRequest(prompt: prompt, maxTokens: maxTokens, attempt: attempt + 1)
                }
                if httpResponse.statusCode == 429 || (500...599).contains(httpResponse.statusCode) {
                    errorMessage = "AI service temporarily unavailable (HTTP \(httpResponse.statusCode)). Tap the pulse to retry."
                } else {
                    errorMessage = "AI service temporarily unavailable (HTTP \(httpResponse.statusCode))."
                }
                return nil
            }
            return responseData
        } catch let error as URLError where [
            .notConnectedToInternet,
            .networkConnectionLost,
            .cannotFindHost,
            .cannotConnectToHost,
            .dnsLookupFailed,
            .dataNotAllowed,
            .internationalRoamingOff
        ].contains(error.code) {
            errorMessage = "No internet connection. Reconnect and try again."
            return nil
        } catch let error as URLError where error.code == .cancelled {
            return nil
        } catch let error as URLError where error.code == .timedOut {
            errorMessage = "Request timed out. Tap the pulse to retry."
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

        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let firstArr = cleaned.firstIndex(of: "["),
           let lastArr = cleaned.lastIndex(of: "]"),
           firstArr < lastArr {
            if let firstObj = cleaned.firstIndex(of: "{"), firstObj < firstArr,
               let lastObj = cleaned.lastIndex(of: "}"), lastObj > lastArr {
                return String(cleaned[firstObj...lastObj])
            }
            return String(cleaned[firstArr...lastArr])
        }
        if let firstObj = cleaned.firstIndex(of: "{"),
           let lastObj = cleaned.lastIndex(of: "}"),
           firstObj < lastObj {
            return String(cleaned[firstObj...lastObj])
        }
        return cleaned
    }

    private func parseResponse<T: Decodable>(_ data: Data) -> T? {
        guard let text = extractText(from: data),
              let jsonData = text.data(using: .utf8)
        else {
            return nil
        }
        do {
            return try JSONDecoder().decode(T.self, from: jsonData)
        } catch {
            return nil
        }
    }

    private func parseArrayResponse<T: Decodable>(_ data: Data) -> [T]? {
        guard let text = extractText(from: data),
              let jsonData = text.data(using: .utf8)
        else {
            return nil
        }
        do {
            return try JSONDecoder().decode([T].self, from: jsonData)
        } catch {
            return nil
        }
    }

    // MARK: - Private: Install Date

    private func observeHistory(lists: [TaskList], snapshots: [DailySnapshot]) {
        let earliest = (lists.map(\.createdAt) + snapshots.map(\.date)).min()
        if let earliest { observedHistoryStart = min(observedHistoryStart ?? earliest, earliest) }
    }

    private var installDate: Date {
        let stored = installationDefaults.object(forKey: "sortyd_install_date") as? Date
        let earliest = [stored, observedHistoryStart].compactMap { $0 }.min() ?? Date()
        return Calendar.current.startOfDay(for: earliest)
    }

    private var daysSinceInstall: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return max(0, Calendar.current.dateComponents([.day], from: installDate, to: today).day ?? 0)
    }

    private var newUserNote: String {
        if daysSinceInstall < 3 {
            return "NOTE: This user just started. Be extra encouraging and don't judge the lack of data."
        } else {
            return ""
        }
    }

    private var procNewNote: String {
        if daysSinceInstall < 5 {
            return "NOTE: The user is still building their routine. Focus on definition and setup tips."
        } else {
            return ""
        }
    }

    // MARK: - Private: Data Builders

    /// Rich weekly summary with per-task daily breakdown, streaks, and best/worst days.
    private func buildWeekSummary(lists: [TaskList], snapshots: [DailySnapshot]) -> String {
        let cal = Calendar.current
        let today = ReminderPolicy.dayStart(Date(), calendar: cal)
        // Clamp window to days since install so pre-install zeros don't pollute the data.
        let windowDays = min(7, daysSinceInstall + 1)
        var sections: [String] = []

        for list in lists {
            let listSnaps = snapshots.filter { $0.listID == list.id }
            var section = "LIST: \(list.emoji) \(list.name) (ID: \(list.id.uuidString)) (\(list.tasks.count) tasks)\n"

            // Daily overview
            var dailyPcts: [(day: String, pct: Int)] = []
            for dayOffset in (0..<windowDays).reversed() {
                guard let date = cal.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
                let snap = listSnaps.first(where: { cal.isDate($0.date, inSameDayAs: date) })
                let pct = snap.map { CompletionPolicy.percentage($0.completionFraction) } ?? 0
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
        let today = ReminderPolicy.dayStart(Date(), calendar: cal)
        // Only consider days since install — pre-install zeros would falsely inflate skip counts.
        let days = min(14, daysSinceInstall + 1)

        struct TaskFlag {
            let id: UUID
            let title: String
            let listName: String
            let listId: String
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
                        id: task.id, title: task.title, listName: list.name, listId: list.id.uuidString,
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
            {"id":"\(f.id.uuidString)","taskTitle":"\(f.title)","listName":"\(f.listName)","listId":"\(f.listId)","done":\(f.doneCount),"outOf":\(f.totalDays),"lastDone":"\(lastDone)","mostSkippedDay":"\(worstDay)"}
            """
        }.joined(separator: "\n")
    }

    /// Rich task completion data with streaks, weekday/weekend split, and trend direction.
    private func buildTaskCompletionData(lists: [TaskList], snapshots: [DailySnapshot]) -> String {
        let cal = Calendar.current
        let today = ReminderPolicy.dayStart(Date(), calendar: cal)
        let days = min(14, daysSinceInstall + 1)
        var sections: [String] = []

        for list in lists {
            let listSnaps = snapshots.filter { $0.listID == list.id }
            var section = "LIST: \(list.emoji) \(list.name) (ID: \(list.id.uuidString))\n"

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

        return sections.joined(separator: "\n\n")
    }
}
