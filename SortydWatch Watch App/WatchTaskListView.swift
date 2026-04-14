// WatchTaskListView.swift
// Sortyd Watch — Scrollable task checklist for the active list

import SwiftUI

struct WatchTaskListView: View {
    @EnvironmentObject var store: WatchStore

    var body: some View {
        Group {
            if let list = store.activeList {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // Header
                        HStack(spacing: 6) {
                            Text(list.emoji)
                                .font(.title3)
                            Text(list.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                        }
                        .padding(.bottom, 8)

                        // Progress pill
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 6)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "7C6FFF"), Color(hex: "3ECFFF")],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: max(6, CGFloat(list.completionFraction) * 140),
                                    height: 6
                                )
                                .animation(.spring(response: 0.4), value: list.completionFraction)
                        }
                        .padding(.bottom, 12)

                        // Tasks
                        ForEach(list.tasks) { task in
                            WatchTaskRow(task: task)
                                .padding(.bottom, 6)
                        }

                        // Refresh button
                        Button {
                            store.refresh()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption2)
                                Text("Sync")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }
}

// MARK: - Task Row

struct WatchTaskRow: View {
    @EnvironmentObject var store: WatchStore
    let task: SortydTask

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                store.toggleTask(task)
            }
            WKInterfaceDevice.current().play(task.isCompleted ? .click : .success)
        } label: {
            HStack(spacing: 10) {
                // Checkbox
                ZStack {
                    Circle()
                        .strokeBorder(
                            task.isCompleted
                                ? Color(hex: "7C6FFF")
                                : Color.white.opacity(0.3),
                            lineWidth: 1.5
                        )
                        .frame(width: 22, height: 22)

                    if task.isCompleted {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "7C6FFF"), Color(hex: "3ECFFF")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 22, height: 22)

                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                // Title
                Text(task.title)
                    .font(.body)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .strikethrough(task.isCompleted, color: .secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty state

struct EmptyWatchView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundStyle(Color(hex: "7C6FFF"))
            Text("Open Sortyd\non your iPhone\nto get started")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Hex colour helper

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
