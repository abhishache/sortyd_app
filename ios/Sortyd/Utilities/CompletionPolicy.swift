import Foundation

/// Completion values enter through live health data, old history and generated tasks.
/// Keep them finite and bounded before calculations, persistence or integer conversion.
enum CompletionPolicy {
    static func fraction(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }

    static func percentage(_ value: Double) -> Int {
        Int((fraction(value) * 100).rounded())
    }

    static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0) { $0 + fraction($1) } / Double(values.count)
    }
}
