import Foundation

// Standalone test executables compile the production coach without the app's SDK modules.
// Firebase delivery is verified separately in the signed test app.
enum AppTelemetry {
    static func aiResult(feature: String, outcome: String, startedAt: Date) {}
}
