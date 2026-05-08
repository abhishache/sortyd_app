// MARK: - ReviewPromptView.swift
// Sortyd — App Store review prompt card

import SwiftUI

struct ReviewPromptCard: View {
    @EnvironmentObject var themeManager: ThemeManager

    var onReviewTapped: () -> Void
    var onDismissed: () -> Void

    @State private var starsVisible = false

    var body: some View {
        VStack(spacing: 0) {
            headerBand
            bodySection
        }
        .frame(maxWidth: 330)
        .clipShape(RoundedRectangle(cornerRadius: Theme.r24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.r24, style: .continuous)
                .strokeBorder(Theme.borderAccent, lineWidth: 1.0)
        )
        .cardShadow()
        .dualGlow(violetIntensity: 0.22, cyanIntensity: 0.10)
        .padding(.horizontal, 28) // Outer padding for safe area
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.spring(response: 0.50, dampingFraction: 0.58)) {
                    starsVisible = true
                }
            }
        }
    }

    // MARK: - Subviews

    private var headerBand: some View {
        ZStack {
            Theme.logoGradientDim
                .frame(maxWidth: .infinity)

            VStack(spacing: 12) {
                starRow
                    .padding(.top, 24)

                VStack(spacing: 4) {
                    Text("Your opinion travels far")
                        .font(Theme.h3)
                        .foregroundColor(Theme.text0)
                        .multilineTextAlignment(.center)

                    Text("Sortyd is free — your review is how it grows.")
                        .font(Theme.caption)
                        .foregroundColor(Theme.text2)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
        }
    }

    private var starRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: "star.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.logoGradient)
                    .scaleEffect(starsVisible ? 1.0 : 0.3)
                    .opacity(starsVisible ? 1.0 : 0.0)
                    .animation(
                        .spring(response: 0.50, dampingFraction: 0.58)
                            .delay(Double(i) * 0.075),
                        value: starsVisible
                    )
            }
        }
    }

    private var bodySection: some View {
        VStack(spacing: 18) {
            Text("Every honest review helps Sortyd surface to the right people. It takes two minutes and means a lot to us.")
                .font(Theme.sub)
                .foregroundColor(Theme.text1)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)

            VStack(spacing: 12) {
                reviewButton
                remindLaterButton
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .background(Theme.bg1)
    }

    private var reviewButton: some View {
        Button {
            onReviewTapped()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "star.bubble.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("Leave a Review")
                    .font(Theme.body)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.amberGlow)
            .clipShape(RoundedRectangle(cornerRadius: Theme.r16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var remindLaterButton: some View {
        Button {
            onDismissed()
        } label: {
            Text("Remind me later")
                .font(Theme.sub)
                .foregroundColor(Theme.text2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ReviewPromptCard(
        onReviewTapped: { print("Review tapped") },
        onDismissed: { print("Remind later tapped") }
    )
    .environmentObject(ThemeManager.shared)
}
