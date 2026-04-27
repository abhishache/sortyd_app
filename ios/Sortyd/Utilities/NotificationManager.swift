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

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    // Notification category / identifier prefix
    private let idPrefix  = "sortyd.task."
    private let summaryID = "sortyd.daily.summary"

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
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            // This is the ONE place we ask — user has just confirmed a reminder time.
            let granted = (try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            return granted
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Daily Performance Summary

    /// Call this from SortydApp.onAppear every launch, passing the current lists + snapshots.
    /// Builds a smart, data-driven notification body and schedules it for 5:30 PM daily.
    /// Silent — only runs if permission is already granted.
    func scheduleDailySummaryIfPermitted(lists: [TaskList], snapshots: [DailySnapshot]) async {
        let status = await currentStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else {
            return
        }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [summaryID])

        let (title, body) = buildSummaryContent(lists: lists, snapshots: snapshots)

        let content      = UNMutableNotificationContent()
        content.title    = title
        content.body     = body
        content.sound    = .default

        // Fire every day at 22:00 (10:00 PM) local time.
        var comps    = DateComponents()
        comps.hour   = 22
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

    /// Cancel the 5:30 PM daily summary notification (e.g. user toggles it off in settings).
    func cancelDailySummary() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [summaryID])
    }

    // MARK: - Smart Summary Builder

    /// Builds a concise, data-driven title + body (max 3 lines) for the 5:30 PM notification.
    private func buildSummaryContent(
        lists: [TaskList],
        snapshots: [DailySnapshot]
    ) -> (title: String, body: String) {

        let cal         = Calendar.current
        let today       = cal.startOfDay(for: Date())
        let activeLists = lists.filter { !$0.isArchived }

        guard !activeLists.isEmpty else {
            return ("📋 Daily Check-in", "Set up your first list to start tracking progress.")
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

        // ── Title — percentage in words, casual & direct ─────────────────────

        let title: String
        switch overallPct {
        case 100:     title = "Fully locked in today 🏆"
        case 85...99: title = "\(overallPct)% clocked in 💪"
        case 70...84: title = "\(overallPct)% on track ⚡"
        case 50...69: title = "\(overallPct)% in. Room to grow 📈"
        case 1...49:  title = "\(overallPct)% checked off today 🌱"
        default:      title = "Fresh slate tomorrow 🔄"
        }

        // ── Line 1 — motivational: short, no wrap (~35 chars max) ─────────────

        let line1: String
        if overallPct == 100 {
            line1 = hadGoodYesterday
                ? "Back-to-back clean days. Keep going. 🔥"
                : "Clean sweep. Everything ticked off. ✅"
        } else if let best = perfectLists.first {
            // Use only the list name, drop emoji to save space
            line1 = "\(best) was spotless. Hold that standard."
        } else if overallPct >= 70 {
            line1 = "Solid effort. The habit is holding. 💪"
        } else if overallPct >= 40 {
            line1 = "You showed up. Build on that tomorrow."
        } else {
            line1 = "Rough one. Tomorrow is a clean reset. 🔄"
        }

        // ── Line 2 — improvement: task name only, no list name/emoji ─────────

        let line2: String
        if overallPct == 100 {
            line2 = "Try adding a stretch goal tomorrow. 📈"
        } else if missedTasks.count == 1 {
            // Truncate task name to keep line short
            let task = String(missedTasks[0].prefix(22))
            line2 = "Do \"\(task)\" first thing tomorrow."
        } else if let worst = strugglingList, worstFraction < 0.5 {
            // Use only the list name, no emoji, truncated
            line2 = "\(worst) needs attention. Start there."
        } else if overallPct >= 80 {
            // missedTasks.count could be 0 if overallPct rounds down from 100 —
            // guard to prevent an index-out-of-bounds crash.
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

        return (title, [line1, line2].joined(separator: "\n"))
    }

    // MARK: - Task Reminders

    /// Schedule (or reschedule) a daily repeating notification for a task.
    /// Caller must have confirmed permission first via `requestPermissionIfNeeded()`.
    /// Now async — awaits both the removal of the old request and the addition of
    /// the new one so the notification is guaranteed to be registered with the
    /// system before the function returns.
    func scheduleReminder(for task: SortydTask, in list: TaskList) async {
        guard let reminderTime = task.reminderTime else { return }

        let center     = UNUserNotificationCenter.current()
        let identifier = idPrefix + task.id.uuidString

        // Await removal so the old request is fully cleared before we add the new one.
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            continuation.resume()
        }

        let content       = UNMutableNotificationContent()
        content.title     = list.emoji + " " + list.name
        content.body      = task.title
        content.sound     = UNNotificationSound(named: UNNotificationSoundName("gong.wav"))

        let comps: DateComponents
        let repeats: Bool
        if task.reminderIsOneTime {
            comps   = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderTime)
            repeats = false
        } else {
            var dc  = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            dc.second = 0
            comps   = dc
            repeats = true
        }
        let trigger  = UNCalendarNotificationTrigger(dateMatching: comps, repeats: repeats)

        let request = UNNotificationRequest(
            identifier: identifier,
            content:    content,
            trigger:    trigger
        )

        do {
            try await center.add(request)
        } catch {
        }
    }

    /// Cancel the notification for a specific task (e.g. when reminder is cleared or task deleted).
    func cancelReminder(for taskID: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [idPrefix + taskID.uuidString])
    }

    /// Cancel all Sortyd notifications (e.g. when a whole list is deleted).
    func cancelReminders(for taskIDs: [UUID]) {
        let ids = taskIDs.map { idPrefix + $0.uuidString }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}
