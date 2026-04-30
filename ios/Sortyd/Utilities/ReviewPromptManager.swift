// MARK: - ReviewPromptManager.swift
// Sortyd — App Store review prompt scheduler
//
// Schedule:
//   Day 7  → first prompt
//   Day 14 → second prompt (if deferred at day 7)
//   Monthly thereafter (30-day intervals)
//   Once the user taps "Review Now" → never shown again.

import Foundation

final class ReviewPromptManager {
    static let shared = ReviewPromptManager()
    private init() {}

    // Replace with Sortyd's numeric App Store ID once the listing is live.
    static let appStoreID = "6762193535"

    static var reviewURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }

    // MARK: - Persistence Keys

    private let defaults             = UserDefaults.standard
    private let keyInstallDate       = "sortyd.review.installDate"
    private let keyPromptCount       = "sortyd.review.promptCount"
    private let keyLastPromptDate    = "sortyd.review.lastPromptDate"
    private let keyHasReviewed       = "sortyd.review.hasReviewed"

    // MARK: - State

    var hasReviewed: Bool {
        get { defaults.bool(forKey: keyHasReviewed) }
        set { defaults.set(newValue, forKey: keyHasReviewed) }
    }

    // Set once on first access; never changed afterwards.
    var installDate: Date {
        if let d = defaults.object(forKey: keyInstallDate) as? Date { return d }
        let now = Date()
        defaults.set(now, forKey: keyInstallDate)
        return now
    }

    private var promptCount: Int {
        get { defaults.integer(forKey: keyPromptCount) }
        set { defaults.set(newValue, forKey: keyPromptCount) }
    }

    private var lastPromptDate: Date? {
        get { defaults.object(forKey: keyLastPromptDate) as? Date }
        set { defaults.set(newValue, forKey: keyLastPromptDate) }
    }

    // MARK: - Decision

    func shouldShowPrompt() -> Bool {
        guard !hasReviewed else { return false }

        let now = Date()
        let daysSinceInstall = daysBetween(installDate, and: now)

        switch promptCount {
        case 0:
            return daysSinceInstall >= 7
        case 1:
            guard let last = lastPromptDate else { return daysSinceInstall >= 14 }
            return daysBetween(last, and: now) >= 7
        default:
            guard let last = lastPromptDate else { return false }
            return daysBetween(last, and: now) >= 30
        }
    }

    // MARK: - Actions

    /// Call when the card is actually displayed to the user.
    func recordShown() {
        promptCount += 1
        lastPromptDate = Date()
    }

    /// Call when "Review Now" is tapped.
    func recordReviewed() {
        hasReviewed = true
    }

    // MARK: - Private

    private func daysBetween(_ from: Date, and to: Date) -> Double {
        to.timeIntervalSince(from) / 86_400
    }
}
