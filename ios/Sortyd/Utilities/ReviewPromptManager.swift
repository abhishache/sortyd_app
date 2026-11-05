// MARK: - ReviewPromptManager.swift
// Sortyd — App Store review prompt scheduler
//
// Schedule:
//   Day 7 → first prompt, then at most once every 7 days if deferred.
//   Once the App Store review link opens → stop automatic requests.
//   Opening the link does not establish that a review was submitted.

import Foundation

final class ReviewPromptManager {
    static let shared = ReviewPromptManager()
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    // Replace with Sortyd's numeric App Store ID once the listing is live.
    static let appStoreID = "6762193535"

    static var reviewURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }

    // MARK: - Persistence Keys

    private let defaults: UserDefaults
    private let keyInstallDate       = "sortyd.review.installDate"
    private let keyPromptCount       = "sortyd.review.promptCount"
    private let keyLastPromptDate    = "sortyd.review.lastPromptDate"
    private let keyHasReviewed       = "sortyd.review.hasReviewed"
    private let keyReviewLinkOpened  = "sortyd.review.linkOpened"

    // MARK: - State

    var hasOpenedReviewLink: Bool {
        // Preserve the suppression promised to people who used older releases.
        defaults.bool(forKey: keyReviewLinkOpened) || defaults.bool(forKey: keyHasReviewed)
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

    func shouldShowPrompt(now: Date = Date()) -> Bool {
        guard !hasOpenedReviewLink else { return false }

        let daysSinceInstall = daysBetween(installDate, and: now)

        guard daysSinceInstall >= 7 else { return false }
        guard let last = lastPromptDate else { return true }
        return daysBetween(last, and: now) >= 7
    }

    // MARK: - Actions

    /// Call when the card is actually displayed to the user.
    func recordShown(now: Date = Date()) {
        promptCount += 1
        lastPromptDate = now
    }

    /// Only call after the operating system confirms that the review link opened.
    func recordReviewLinkOpened() {
        defaults.set(true, forKey: keyReviewLinkOpened)
    }

    // MARK: - Private

    private func daysBetween(_ from: Date, and to: Date) -> Double {
        to.timeIntervalSince(from) / 86_400
    }
}
