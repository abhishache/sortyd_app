// MARK: - SortydWidgetBundle.swift
// SortydWidgetExtension — @main entry point
//
// This file is the ONLY @main in the widget extension.
// Xcode requires exactly one @main per target.
//
// Widgets registered here:
//   Home screen:
//     1. SortydSmallWidget      — systemSmall  (1×1) donut progress
//     2. SortydMediumWidget     — systemMedium (2×1) task list
//     3. SortydLargeWidget      — systemLarge  (2×2) full task list + stats
//     4. SortydMonthlyWidget    — systemLarge  (2×2) monthly heatmap
//   Lock screen (iOS 16+):
//     5. SortydLockCircularWidget    — accessoryCircular
//     6. SortydLockRectangularWidget — accessoryRectangular
//     7. SortydLockInlineWidget      — accessoryInline

import WidgetKit
import SwiftUI
@main
struct SortydWidgetBundle: WidgetBundle {
    var body: some Widget {
        // ── Home screen ──────────────────────────
        SortydSmallWidget()
        SortydMediumWidget()
        SortydLargeWidget()
        SortydMonthlyWidget()
        SortydMultiListWidget()
        // ── Lock screen ──────────────────────────
        SortydLockCircularWidget()
        SortydLockRectangularWidget()
        SortydLockInlineWidget()
    }
}
