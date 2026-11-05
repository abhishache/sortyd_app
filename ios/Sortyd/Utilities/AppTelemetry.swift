import Foundation
import FirebaseAnalytics
import FirebaseCrashlytics

/// Only fixed operation names, outcomes and timings belong in diagnostics.
/// Never include task titles, prompts, health values or server response bodies.
enum AppTelemetry {
    static func aiResult(feature: String, outcome: String, startedAt: Date) {
        let elapsed = max(0, min(86_400, Date().timeIntervalSince(startedAt)))
        Analytics.logEvent("ai_result", parameters: [
            "feature": feature,
            "outcome": outcome,
            "duration_ms": Int(elapsed * 1_000)
        ])
        Crashlytics.crashlytics().log("AI \(feature): \(outcome)")
    }
}
