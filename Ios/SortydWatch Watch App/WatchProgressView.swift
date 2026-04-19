// WatchProgressView.swift
// Sortyd Watch — Progress ring summary (second tab)

import SwiftUI

struct WatchProgressView: View {
    @EnvironmentObject var store: WatchStore

    var body: some View {
        if let list = store.activeList {
            VStack(spacing: 6) {

                // Ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 12)
                        .frame(width: 90, height: 90)

                    Circle()
                        .trim(from: 0, to: list.completionFraction)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "7C6FFF"), Color(hex: "3ECFFF")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6), value: list.completionFraction)

                    VStack(spacing: 1) {
                        Text("\(list.completionPercentage)%")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        Text("done")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // List name
                Text(list.emoji + " " + list.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                // Done count
                Text("\(list.tasks.filter(\.isCompleted).count) of \(list.tasks.count) tasks")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                // Motivational nudge
                if list.completionFraction >= 1.0 {
                    Label("All done!", systemImage: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(Color(hex: "3ECFFF"))
                } else if list.completionFraction >= 0.5 {
                    Label("Keep going!", systemImage: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(Color(hex: "7C6FFF"))
                }
            }
            .padding(.horizontal, 8)
        }
    }
}
