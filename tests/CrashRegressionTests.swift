import Foundation

@main
struct CrashRegressionTests {
    static func main() {
        for invalid in [Double.nan, .infinity, -.infinity, -1, -Double.greatestFiniteMagnitude] {
            precondition(CompletionPolicy.percentage(invalid) == 0)
        }
        precondition(CompletionPolicy.percentage(.greatestFiniteMagnitude) == 100)
        precondition(CompletionPolicy.percentage(0.725) == 73)
        precondition(CompletionPolicy.average([]) == 0)
        precondition(CompletionPolicy.average([.nan, 1]) == 0.5)
        precondition(CompletionPolicy.average([.greatestFiniteMagnitude, 1]) == 1)
        var snapshot = DailySnapshot(date: Date(), listID: UUID(), completionFraction: .nan, completedTaskIDs: [])
        precondition(snapshot.completionPercentage == 0)
        snapshot.completionFraction = .infinity
        precondition(snapshot.completionFraction == 0)
        snapshot.completionFraction = 2
        precondition(snapshot.completionPercentage == 100)
        let snapshotData = try! JSONEncoder().encode(snapshot)
        precondition((try! JSONDecoder().decode(DailySnapshot.self, from: snapshotData)).completionPercentage == 100)
        var list = TaskList(name: "Test", tasks: [
            SortydTask(title: "First", isCompleted: true, weight: 2),
            SortydTask(title: "Second", weight: 2)
        ])
        precondition(list.completionPercentage == 50)
        list.tasks[0].weight = .infinity
        precondition(list.completionPercentage == 50)
        let healthTask = SortydTask(title: "Walk", weight: 1, healthType: "steps")
        let healthList = TaskList(name: "Health", tasks: [healthTask])
        precondition(healthList.completionFraction(healthValues: [healthTask.id: .nan]) == 0)
        precondition(healthList.completionFraction(healthValues: [healthTask.id: 3]) == 1)

        let first = StarterTaskDraft(title: "First")
        let second = StarterTaskDraft(title: "Second")
        let third = StarterTaskDraft(title: "Third")
        var drafts = [first, second, third]
        drafts.removeDraft(id: first.id)
        drafts.removeDraft(id: first.id) // A second tap on a disappearing row is harmless.
        drafts.updateDraftTitle(id: first.id, title: "Stale field callback")
        precondition(drafts.map(\.id) == [second.id, third.id])
        drafts.updateDraftTitle(id: second.id, title: "Edited second")
        precondition(drafts[0].title == "Edited second")
        precondition(drafts[1].title == "Third")
        drafts.removeDraft(id: third.id)
        drafts.removeDraft(id: second.id)
        precondition(drafts.isEmpty)
        drafts.append(StarterTaskDraft(title: "New generation"))
        drafts.updateDraftTitle(id: second.id, title: "Obsolete generation")
        precondition(drafts[0].title == "New generation")

        let suite = "sortyd.crash-regression.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let review = ReviewPromptManager(defaults: defaults)
        let installed = review.installDate
        let day: TimeInterval = 86_400
        precondition(!review.shouldShowPrompt(now: installed + 7 * day - 1))
        precondition(review.shouldShowPrompt(now: installed + 7 * day))
        review.recordShown(now: installed + 7 * day)
        precondition(!review.shouldShowPrompt(now: installed + 14 * day - 1))
        precondition(review.shouldShowPrompt(now: installed + 14 * day))
        // A failed open does not suppress future requests.
        precondition(!review.hasOpenedReviewLink)
        review.recordReviewLinkOpened()
        precondition(!review.shouldShowPrompt(now: installed + 30 * day))
        defaults.removeObject(forKey: "sortyd.review.linkOpened")
        defaults.set(true, forKey: "sortyd.review.hasReviewed")
        precondition(review.hasOpenedReviewLink)
        precondition(!review.shouldShowPrompt(now: installed + 30 * day))
        if CommandLine.arguments.count > 1 {
            let bundle = Bundle(path: CommandLine.arguments[1])!
            let key = "Help Sortyd reach more people"
            for language in ["ar", "es", "zh-Hans"] {
                precondition(AppLocalization.string(key, languageCode: language, bundle: bundle) != key)
            }
            precondition(AppLocalization.string(key, languageCode: "en", bundle: bundle) == key)
            let translatedCount = AppLocalization.string("%lld of %lld tasks completed", languageCode: "es", bundle: bundle)
            let formatted = String(format: translatedCount, Int64(2), Int64(5))
            precondition(formatted.contains("2") && formatted.contains("5") && !formatted.contains("%lld"))
        }
        print("Completion boundaries, stale task actions and seven day review regressions passed")
    }
}
