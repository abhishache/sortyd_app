// MARK: - NotificationManager.swift
// Sortyd — Lazy notification permission + daily task reminders
//
// Design principles:
//  • Permission is NEVER requested at app launch or on first clock tap.
//  • Permission is requested only at the moment the user confirms a time
//    (i.e. taps "Set" in the time picker).
//  • If the user has already granted permission, scheduling is silent.
//  • If denied, we surface a one-time settings nudge — no nag loops.

import Foundation
import UserNotifications

extension UNAuthorizationStatus {
    var isPermitted: Bool {
        #if os(iOS)
        return self == .authorized || self == .provisional || self == .ephemeral
        #else
        return self == .authorized || self == .provisional
        #endif
    }
}

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    // Notification category / identifier prefix
    private let idPrefix  = "sortyd.task."
    private let summaryID = "sortyd.daily.summary"
    private let coldNudgeID = "sortyd.cold-tasks.nudge"
    private var currentLists: [TaskList] = []
    private var reconciling = false
    private var reconcileAgain = false

    func updateTaskState(lists: [TaskList]) {
        currentLists = lists
        reconcileAgain = true
        for list in lists {
            for task in list.tasks where task.reminderTime == nil || task.isCompleted || list.isArchived {
                cancelReminder(for: task.id)
            }
        }
    }

    private func notificationIdentifiers(for taskID: UUID) -> [String] {
        let base = idPrefix + taskID.uuidString
        return [base, base + ".prior"]
    }

    // MARK: - Permission

    /// Current authorisation status — does NOT prompt.
    func currentStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Request permission only when the user explicitly sets a reminder time.
    /// Returns `true` if permission is granted (either already was, or just granted).
    /// Returns `false` if denied — caller shows a one-time settings nudge.
    func requestPermissionIfNeeded() async -> Bool {
        let status = await currentStatus()
        if status.isPermitted {
            return true
        }
        switch status {
        case .notDetermined:
            // This is the ONE place we ask — user has just confirmed a reminder time.
            let granted = (try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            return granted
        case .denied:
            return false
        default:
            return false
        }
    }

    // MARK: - Daily Performance Summary

    /// Call this from SortydApp.onAppear every launch, passing the current lists + snapshots.
    /// Builds a smart, data-driven notification body and schedules it for 11:00 PM daily.
    /// Silent — only runs if permission is already granted.
    func scheduleDailySummaryIfPermitted(lists: [TaskList], snapshots: [DailySnapshot]) async {
        let status = await currentStatus()
        guard status.isPermitted else {
            return
        }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [summaryID])

        let language = currentAppLanguage()
        // A repeating local notification cannot calculate fresh progress at delivery.
        // Keep its message timeless rather than repeating a stale performance report.
        let title = "Sortyd"
        let body: String
        switch language {
        case .arabic: body = "خذ لحظة لمراجعة يومك في Sortyd."
        case .spanish: body = "Dedica un momento a revisar tu día en Sortyd."
        case .chinese: body = "花一点时间在 Sortyd 回顾今天。"
        case .english: body = "Take a moment to review your day in Sortyd."
        }

        let content      = UNMutableNotificationContent()
        content.title    = title
        content.body     = body
        content.sound    = UNNotificationSound(named: UNNotificationSoundName("gong.wav"))

        // Fire every day at 23:00 (11:00 PM) local time.
        var comps    = DateComponents()
        comps.hour   = 23
        comps.minute = 0
        comps.second = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(
            identifier: summaryID,
            content:    content,
            trigger:    trigger
        )

        do {
            try await center.add(request)
        } catch {
        }
    }

    /// Cancel the 11:00 PM daily summary notification (e.g. user toggles it off in settings).
    func cancelDailySummary() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [summaryID])
    }

    // MARK: - Cold Task Nudge

    /// Schedules one gentle nudge every ~3 days for tasks that have gone quiet.
    /// Silent — only runs if permission is already granted, and it avoids the exact
    /// time slots already used by task reminders or the daily summary.
    func scheduleColdTaskNudgeIfPermitted(lists: [TaskList], snapshots: [DailySnapshot]) async {
        let status = await currentStatus()
        guard status.isPermitted else {
            return
        }

        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        guard !Task.isCancelled else { return }
        let coldTasks = buildColdTaskItems(lists: currentLists, snapshots: snapshots)

        guard !coldTasks.isEmpty else {
            center.removePendingNotificationRequests(withIdentifiers: [coldNudgeID])
            return
        }

        let existingTrigger = pending.first(where: { $0.identifier == coldNudgeID })?.trigger as? UNCalendarNotificationTrigger
        let existingDate = existingTrigger?.nextTriggerDate()
        guard let fireDate = existingDate ?? nextColdNudgeDate(avoiding: pending) else { return }
        let language = currentAppLanguage()
        let daysUntilDelivery = max(0, Calendar.current.dateComponents([.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: fireDate)).day ?? 0)
        let items = coldTasks.prefix(2).map { ColdTaskItem(title: $0.title, daysCold: $0.daysCold + daysUntilDelivery) }
        let (title, body) = buildColdNudgeContent(items: items, language: language)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound(named: UNNotificationSoundName("gong.wav"))
        content.threadIdentifier = "sortyd.cold-tasks"

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: coldNudgeID, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
        }
    }

    func cancelColdTaskNudge() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [coldNudgeID])
    }

    private struct ColdTaskItem {
        let title: String
        let daysCold: Int
    }

    private func buildColdTaskItems(lists: [TaskList], snapshots: [DailySnapshot]) -> [ColdTaskItem] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let activeLists = lists.filter { !$0.isArchived && !$0.isTodo && !$0.isWeekly }

        return activeLists.flatMap { list in
            let listSnapshots = snapshots.filter { $0.listID == list.id }
            let todayCompletedIDs = Set(
                listSnapshots
                    .filter { cal.isDate($0.date, inSameDayAs: today) }
                    .flatMap(\.completedTaskIDs)
            )

            return list.tasks.compactMap { task -> ColdTaskItem? in
                guard !task.isCompleted, !todayCompletedIDs.contains(task.id) else { return nil }

                let lastDoneDate = listSnapshots
                    .filter { $0.completedTaskIDs.contains(task.id) }
                    .map { cal.startOfDay(for: $0.date) }
                    .max()

                let referenceDate = lastDoneDate ?? cal.startOfDay(for: task.createdAt)
                let daysCold = max(0, cal.dateComponents([.day], from: referenceDate, to: today).day ?? 0)

                guard daysCold >= 3 else { return nil }
                return ColdTaskItem(title: task.title, daysCold: daysCold)
            }
        }
        .sorted {
            if $0.daysCold == $1.daysCold { return $0.title < $1.title }
            return $0.daysCold > $1.daysCold
        }
    }

    private func nextColdNudgeDate(avoiding pending: [UNNotificationRequest]) -> Date? {
        let cal = Calendar.current
        let now = Date()
        let base = cal.date(byAdding: .day, value: 3, to: now) ?? now.addingTimeInterval(3 * 24 * 60 * 60)

        for attempt in 0..<18 {
            let hour = Int.random(in: 9...20)
            let minuteOptions = [7, 17, 29, 41, 53]
            let minute = minuteOptions.randomElement() ?? 17
            let shiftedBase = cal.date(byAdding: .minute, value: attempt * 11, to: base) ?? base

            var comps = cal.dateComponents([.year, .month, .day], from: shiftedBase)
            comps.hour = hour
            comps.minute = minute
            comps.second = 0

            guard let candidate = cal.date(from: comps), candidate > now else { continue }
            if !conflictsWithPending(candidate: candidate, pending: pending) {
                return candidate
            }
        }

        var fallback = cal.dateComponents([.year, .month, .day], from: base)
        fallback.hour = 16
        fallback.minute = 37
        fallback.second = 0
        return cal.date(from: fallback)
    }

    private func conflictsWithPending(candidate: Date, pending: [UNNotificationRequest]) -> Bool {
        let cal = Calendar.current
        let candidateTime = cal.dateComponents([.hour, .minute], from: candidate)

        for request in pending where request.identifier != coldNudgeID {
            guard let trigger = request.trigger as? UNCalendarNotificationTrigger else { continue }

            if trigger.repeats {
                let triggerTime = trigger.dateComponents
                if triggerTime.hour == candidateTime.hour && triggerTime.minute == candidateTime.minute {
                    return true
                }
            } else if let nextDate = trigger.nextTriggerDate(),
                      abs(nextDate.timeIntervalSince(candidate)) < 10 * 60 {
                return true
            }
        }

        return false
    }

    private func buildColdNudgeContent(items: [ColdTaskItem], language: AppLanguage) -> (title: String, body: String) {
        let first = clippedTaskTitle(items.first?.title ?? "")
        let second = items.dropFirst().first.map { clippedTaskTitle($0.title) }
        let days = max(3, items.map(\.daysCold).max() ?? 3)

        switch language {
        case .spanish:
            let title = "Necesita atención ⚠️"
            if let second {
                return (title, "\"\(first)\" y \"\(second)\" llevan \(days) días sin actividad. Un toque para volver al ritmo.")
            }
            return (title, "\"\(first)\" lleva \(days) días sin actividad. Un toque para volver al ritmo.")

        case .arabic:
            let title = "يحتاج انتباهاً ⚠️"
            let dayText = arabicDaysPhrase(days)
            if let second {
                return (title, "«\(first)» و«\(second)» هادئتان منذ \(dayText). لمسة واحدة تعيدك للمسار.")
            }
            return (title, "«\(first)» هادئة منذ \(dayText). لمسة واحدة تعيدك للمسار.")

        case .chinese:
            let title = "需要关注 ⚠️"
            if let second {
                return (title, "「\(first)」和「\(second)」已有 \(days) 天没有记录。轻触一下，重回正轨。")
            }
            return (title, "「\(first)」已有 \(days) 天没有记录。轻触一下，重回正轨。")

        case .english:
            let title = "Needs attention ⚠️"
            if let second {
                return (title, "\"\(first)\" and \"\(second)\" haven't been logged for \(days) days. One tap to get back on track.")
            }
            return (title, "\"\(first)\" hasn't been logged for \(days) days. One tap to get back on track.")
        }
    }

    private func clippedTaskTitle(_ title: String) -> String {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count > 28 else { return cleaned }
        return String(cleaned.prefix(25)) + "..."
    }

    private func arabicDaysPhrase(_ days: Int) -> String {
        if days == 2 { return "يومين" }
        if (3...10).contains(days) { return "\(days) أيام" }
        return "\(days) يوماً"
    }

    private func currentAppLanguage() -> AppLanguage {
        let groupDefaults = UserDefaults(suiteName: "group.com.sortyd.sortyd")
        let raw = groupDefaults?.string(forKey: "sortyd_app_language")
            ?? UserDefaults.standard.string(forKey: "sortyd_app_language")
            ?? AppLanguage.english.rawValue
        return AppLanguage(rawValue: raw) ?? .english
    }

    // MARK: - Smart Summary Builder

    /// Builds a concise, data-driven title + body (max 3 lines) for the 11:00 PM notification.
    private func buildSummaryContent(
        lists: [TaskList],
        snapshots: [DailySnapshot],
        language: AppLanguage
    ) -> (title: String, body: String) {

        let cal         = Calendar.current
        let today       = cal.startOfDay(for: Date())
        let activeLists = lists.filter { !$0.isArchived && !$0.isTodo && !$0.isWeekly }

        guard !activeLists.isEmpty else {
            switch language {
            case .spanish:
                return ("📋 Registro diario", "Crea tu primera lista para empezar a medir tu progreso.")
            case .arabic:
                return ("📋 تسجيل يومي", "أنشئ قائمتك الأولى لبدء تتبع تقدمك.")
            case .chinese:
                return ("📋 每日签到", "创建你的第一个列表，开始追踪进度。")
            case .english:
                return ("📋 Daily Check-in", "Set up your first list to start tracking progress.")
            }
        }

        // ── Aggregate today's data ───────────────────────────────────────────

        var totalTasks      = 0
        var totalDone       = 0
        var missedTasks:    [String] = []
        var perfectLists:   [String] = []
        var worstFraction   = 1.0
        var strugglingList: String?  = nil

        for list in activeLists {
            let todaySnap = snapshots.first(where: {
                $0.listID == list.id && cal.isDate($0.date, inSameDayAs: today)
            })

            let completedIDs: Set<UUID>
            if let snap = todaySnap {
                completedIDs = Set(snap.completedTaskIDs)
            } else {
                completedIDs = Set(list.tasks.filter(\.isCompleted).map(\.id))
            }

            let listTotal = list.tasks.count
            let listDone  = list.tasks.filter { completedIDs.contains($0.id) }.count

            totalTasks += listTotal
            totalDone  += listDone

            for task in list.tasks where !completedIDs.contains(task.id) {
                missedTasks.append(task.title)
            }

            let fraction = listTotal > 0 ? Double(listDone) / Double(listTotal) : 1.0
            if fraction == 1.0 { perfectLists.append(list.name) }
            if fraction < worstFraction {
                worstFraction  = fraction
                strugglingList = list.name
            }
        }

        let overallPct = totalTasks > 0
            ? Int((Double(totalDone) / Double(totalTasks)) * 100)
            : 0

        // ── Yesterday context ────────────────────────────────────────────────

        let yesterday        = cal.date(byAdding: .day, value: -1, to: today) ?? today
        let hadGoodYesterday = activeLists.contains { list in
            let s = snapshots.first(where: { $0.listID == list.id && cal.isDate($0.date, inSameDayAs: yesterday) })
            return (s?.completionFraction ?? 0) >= 0.8
        }

        // ── Titles ──────────────────────────────────────────────────────────

        let title: String
        switch language {
        case .spanish:
            switch overallPct {
            case 100:     title = "Todo listo por hoy 🏆"
            case 85...99: title = "\(overallPct)% completado 💪"
            case 70...84: title = "\(overallPct)% en camino ⚡"
            case 50...69: title = "\(overallPct)% listo. Sigue así 📈"
            case 1...49:  title = "\(overallPct)% marcado hoy 🌱"
            default:      title = "Borrón y cuenta nueva 🔄"
            }
        case .arabic:
            switch overallPct {
            case 100:     title = "تم الإنجاز بالكامل 🏆"
            case 85...99: title = "تم إنجاز \(overallPct)% 💪"
            case 70...84: title = "\(overallPct)% على المسار ⚡"
            case 50...69: title = "تم \(overallPct)%. استمر بالنمو 📈"
            case 1...49:  title = "تم إنجاز \(overallPct)% اليوم 🌱"
            default:      title = "بداية جديدة غداً 🔄"
            }
        case .chinese:
            switch overallPct {
            case 100:     title = "今天全部完成 🏆"
            case 85...99: title = "完成 \(overallPct)% 💪"
            case 70...84: title = "\(overallPct)% 进展顺利 ⚡"
            case 50...69: title = "\(overallPct)% 完成，继续加油 📈"
            case 1...49:  title = "今天完成了 \(overallPct)% 🌱"
            default:      title = "明天重新开始 🔄"
            }
        case .english:
            switch overallPct {
            case 100:     title = "Fully locked in today 🏆"
            case 85...99: title = "\(overallPct)% clocked in 💪"
            case 70...84: title = "\(overallPct)% on track ⚡"
            case 50...69: title = "\(overallPct)% in. Room to grow 📈"
            case 1...49:  title = "\(overallPct)% checked off today 🌱"
            default:      title = "Fresh slate tomorrow 🔄"
            }
        }

        // ── Line 1 — motivational ───────────────────────────────────────────

        let line1: String
        switch language {
        case .spanish:
            if overallPct == 100 {
                line1 = hadGoodYesterday ? "Días seguidos perfectos. ¡Sigue! 🔥" : "Limpieza total. Todo marcado. ✅"
            } else if let best = perfectLists.first {
                line1 = "\(best) estuvo impecable. Mantén el nivel."
            } else if overallPct >= 70 {
                line1 = "Buen esfuerzo. El hábito se mantiene. 💪"
            } else if overallPct >= 40 {
                line1 = "Estuviste presente. Mañana más."
            } else {
                line1 = "Día difícil. Mañana reseteamos. 🔄"
            }
        case .arabic:
            if overallPct == 100 {
                line1 = hadGoodYesterday ? "أيام متتالية مذهلة. استمر! 🔥" : "إنجاز كامل. كل شيء تم. ✅"
            } else if let best = perfectLists.first {
                line1 = "قائمة «\(best)» كانت مثالية. حافظ على المستوى."
            } else if overallPct >= 70 {
                line1 = "جهد رائع. العادة مستمرة. 💪"
            } else if overallPct >= 40 {
                line1 = "لقد حضرت اليوم. ابنِ على ذلك غداً."
            } else {
                line1 = "يوم صعب. غداً بداية جديدة. 🔄"
            }
        case .chinese:
            if overallPct == 100 {
                line1 = hadGoodYesterday ? "连续两天全部完成，继续加油！🔥" : "全部完成，所有任务都打勾了。✅"
            } else if let best = perfectLists.first {
                line1 = "「\(best)」表现完美，保持这个水平。"
            } else if overallPct >= 70 {
                line1 = "努力得很好，习惯正在养成。💪"
            } else if overallPct >= 40 {
                line1 = "你今天出现了，明天继续积累。"
            } else {
                line1 = "今天有点难，明天重新开始。🔄"
            }
        case .english:
            if overallPct == 100 {
                line1 = hadGoodYesterday ? "Back-to-back clean days. Keep going. 🔥" : "Clean sweep. Everything ticked off. ✅"
            } else if let best = perfectLists.first {
                line1 = "\(best) was spotless. Hold that standard."
            } else if overallPct >= 70 {
                line1 = "Solid effort. The habit is holding. 💪"
            } else if overallPct >= 40 {
                line1 = "You showed up. Build on that tomorrow."
            } else {
                line1 = "Rough one. Tomorrow is a clean reset. 🔄"
            }
        }

        // ── Line 2 — improvement ────────────────────────────────────────────

        let line2: String
        switch language {
        case .spanish:
            if overallPct == 100 {
                line2 = "Intenta un reto extra mañana. 📈"
            } else if missedTasks.count == 1 {
                let task = String(missedTasks[0].prefix(22))
                line2 = "Haz \"\(task)\" primero mañana."
            } else if let worst = strugglingList, worstFraction < 0.5 {
                line2 = "\(worst) necesita atención. Empieza ahí."
            } else if overallPct >= 80 {
                if let first = missedTasks.first {
                    let task = String(first.prefix(22))
                    line2 = "Mueve \"\(task)\" a tu mañana."
                } else {
                    line2 = "Intenta un reto extra mañana. 📈"
                }
            } else {
                if let first = missedTasks.first {
                    let task = String(first.prefix(22))
                    line2 = "Empieza con \"\(task)\". Solo eso."
                } else {
                    line2 = "Añade tu primera tarea para mañana."
                }
            }
        case .arabic:
            if overallPct == 100 {
                line2 = "جرب إضافة هدف إضافي غداً. 📈"
            } else if missedTasks.count == 1 {
                let task = String(missedTasks[0].prefix(22))
                line2 = "ابدأ بـ «\(task)» أول شيء غداً."
            } else if let worst = strugglingList, worstFraction < 0.5 {
                line2 = "«\(worst)» تحتاج انتباهاً. ابدأ من هناك."
            } else if overallPct >= 80 {
                if let first = missedTasks.first {
                    let task = String(first.prefix(22))
                    line2 = "اجعل «\(task)» في أول صباحك."
                } else {
                    line2 = "جرب إضافة هدف إضافي غداً. 📈"
                }
            } else {
                if let first = missedTasks.first {
                    let task = String(first.prefix(22))
                    line2 = "ابدأ بـ «\(task)» غداً. هذا فقط."
                } else {
                    line2 = "أضف مهمتك الأولى وابدأ غداً بقوة."
                }
            }
        case .chinese:
            if overallPct == 100 {
                line2 = "明天试着增加一个挑战目标。📈"
            } else if missedTasks.count == 1 {
                let task = String(missedTasks[0].prefix(22))
                line2 = "明天先做「\(task)」。"
            } else if let worst = strugglingList, worstFraction < 0.5 {
                line2 = "「\(worst)」需要关注，从这里开始。"
            } else if overallPct >= 80 {
                if let first = missedTasks.first {
                    let task = String(first.prefix(22))
                    line2 = "把「\(task)」安排到明天早上。"
                } else {
                    line2 = "明天试着增加一个挑战目标。📈"
                }
            } else {
                if let first = missedTasks.first {
                    let task = String(first.prefix(22))
                    line2 = "明天以「\(task)」开始，就这一件事。"
                } else {
                    line2 = "添加你的第一个任务，明天全力以赴。"
                }
            }
        case .english:
            if overallPct == 100 {
                line2 = "Try adding a stretch goal tomorrow. 📈"
            } else if missedTasks.count == 1 {
                let task = String(missedTasks[0].prefix(22))
                line2 = "Do \"\(task)\" first thing tomorrow."
            } else if let worst = strugglingList, worstFraction < 0.5 {
                line2 = "\(worst) needs attention. Start there."
            } else if overallPct >= 80 {
                if let first = missedTasks.first {
                    let task = String(first.prefix(22))
                    line2 = "Reschedule \"\(task)\" to your morning."
                } else {
                    line2 = "Try adding a stretch goal tomorrow. 📈"
                }
            } else {
                if let first = missedTasks.first {
                    let task = String(first.prefix(22))
                    line2 = "Lead tomorrow with \"\(task)\". Just that."
                } else {
                    line2 = "Add your first task and start tomorrow strong."
                }
            }
        }

        return (title, [line1, line2].joined(separator: "\n"))
    }

    // MARK: - Task Reminders

    /// Schedule (or reschedule) a notification for a task.
    /// Caller must have confirmed permission first via `requestPermissionIfNeeded()`.
    /// Now async — awaits both the removal of the old request and the addition of
    /// the new one so the notification is guaranteed to be registered with the
    /// system before the function returns.
    func scheduleReminder(for candidate: SortydTask, in ignoredList: TaskList) async {
        await resyncTaskReminders(lists: currentLists)
    }

    private func installReminder(for candidate: SortydTask, in ignoredList: TaskList) async {
        // Delayed permission dialogs and undo actions must not revive deleted tasks.
        guard let list = currentLists.first(where: { $0.tasks.contains(where: { $0.id == candidate.id }) }),
              let task = list.tasks.first(where: { $0.id == candidate.id }) else {
            cancelReminder(for: candidate.id)
            return
        }

        let center = UNUserNotificationCenter.current()
        let ids = notificationIdentifiers(for: task.id)
        let identifier = ids[0]
        let priorID = ids[1]

        center.removePendingNotificationRequests(withIdentifiers: ids)

        let oneTime = task.reminderIsOneTime || list.isTodo || list.isWeekly
        guard let fireDate = ReminderPolicy.fireDate(reminder: task.reminderTime,
            oneTime: oneTime, weekly: list.isWeekly, archived: list.isArchived,
            completed: task.isCompleted) else {
            cancelReminder(for: task.id)
            return
        }

        let sound = UNNotificationSound(named: UNNotificationSoundName(task.soundName ?? "gong.wav"))
        let calendar = Calendar.current
        let isWeeklyPlannerTask = list.isWeekly

        if isWeeklyPlannerTask {
            let notifyAt = fireDate

            let content = UNMutableNotificationContent()
            content.title = list.emoji + " " + list.name
            let lang = currentAppLanguage()
            content.body = (lang == .arabic ? "تبدأ خلال 10 دقائق: " :
                (lang == .spanish ? "Empieza en 10 minutos: " :
                (lang == .chinese ? "10 分钟后开始：" : "Starts in 10 minutes: "))) + task.title
            content.sound = sound
            if fireDate == task.reminderTime { content.body = task.title }

            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: notifyAt)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: priorID, content: content, trigger: trigger)
            try? await center.add(request)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = list.emoji + " " + list.name
        content.body = task.title
        content.sound = sound

        let comps = calendar.dateComponents(
            oneTime ? [.year, .month, .day, .hour, .minute, .second] : [.hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: !oneTime)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try? await center.add(request)
    }

    func resyncTaskReminders(lists: [TaskList]) async {
        reconcileAgain = true
        guard !reconciling else { return }
        reconciling = true
        defer { reconciling = false }
        let status = await currentStatus()
        guard status.isPermitted else {
            return
        }

        repeat {
            reconcileAgain = false
            let liveLists = currentLists
            await cancelOrphanedNotifications(knownTaskIDs: Set(liveLists.flatMap { $0.tasks.map(\.id) }))
            for list in liveLists {
                for task in list.tasks {
                    await installReminder(for: task, in: list)
                }
            }
        } while reconcileAgain
    }

    /// Cancel the notification for a specific task (e.g. when reminder is cleared or task deleted).
    func cancelReminder(for taskID: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: notificationIdentifiers(for: taskID))
        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: notificationIdentifiers(for: taskID))
    }

    /// Cancel all Sortyd notifications (e.g. when a whole list is deleted).
    func cancelReminders(for taskIDs: [UUID]) {
        let ids = taskIDs.flatMap { notificationIdentifiers(for: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
    }

    /// One-time cleanup: removes the 4 AM TO DO reset notification that older builds scheduled.
    func cancelLegacyTodoResetNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["sortyd.todo.daily.reset"])
    }

    /// Sweep all pending sortyd.task.* notifications and cancel any whose task UUID is not in
    /// `knownTaskIDs`. Cleans up stale repeating alerts from TO DO tasks deleted by the 4 AM wipe.
    func cancelOrphanedNotifications(knownTaskIDs: Set<UUID>) async {
        let center  = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let staleIDs = pending.compactMap { req -> String? in
            guard req.identifier.hasPrefix(idPrefix) else { return nil }
            let raw = String(req.identifier.dropFirst(idPrefix.count))
            let uuidStr = raw.replacingOccurrences(of: ".prior", with: "")
            guard let uuid = UUID(uuidString: uuidStr), !knownTaskIDs.contains(uuid) else { return nil }
            return req.identifier
        }
        guard !staleIDs.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: staleIDs)
    }

}
