// MARK: - ReviewPromptView.swift
// Sortyd — App Store review prompt card

import SwiftUI

struct ReviewPromptView: View {
    @EnvironmentObject var themeManager: ThemeManager

    var onReview: () -> Void
    var onRemindLater: () -> Void

    @State private var starsVisible  = false
    @State private var cardOffset:  CGFloat = 60
    @State private var cardOpacity: Double  = 0

    var body: some View {
        ZStack {
            // Dimmed backdrop — tap outside = remind later
            Color.black.opacity(0.50)
                .ignoresSafeArea()
                .onTapGesture { animateOut(then: onRemindLater) }

            // Card
            VStack(spacing: 0) {
                headerBand
                bodySection
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.r24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.r24, style: .continuous)
                    .strokeBorder(Theme.borderAccent, lineWidth: 1.0)
            )
            .padding(.horizontal, 28)
            .cardShadow()
            .dualGlow(violetIntensity: 0.22, cyanIntensity: 0.10)
            .offset(y: cardOffset)
            .opacity(cardOpacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.76)) {
                cardOffset  = 0
                cardOpacity = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                starsVisible = true
            }
        }
    }

    // MARK: - Subviews

    private var headerBand: some View {
        ZStack {
            Theme.logoGradientDim
                .frame(maxWidth: .infinity)

            VStack(spacing: 14) {
                starRow
                    .padding(.top, 28)

                VStack(spacing: 6) {
                    Text("Your opinion travels far")
                        .font(Theme.h3)
                        .foregroundColor(Theme.text0)
                        .multilineTextAlignment(.center)

                    Text("Sortyd is free — your review is how it finds its people.")
                        .font(Theme.caption)
                        .foregroundColor(Theme.text2)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 22)
            }
        }
    }

    private var starRow: some View {
        HStack(spacing: 7) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: "star.fill")
                    .font(.system(size: 24, weight: .bold))
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
        VStack(spacing: 20) {
            Text("Every honest review helps Sortyd surface to people genuinely working to streamline their habits and goals — not just those who happen to scroll by.\n\nIt takes two minutes and means a lot.")
                .font(Theme.sub)
                .foregroundColor(Theme.text1)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 6)

            reviewButton
            remindLaterButton
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .background(Theme.bg1)
    }

    private var reviewButton: some View {
        Button {
            animateOut(then: onReview)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "star.bubble.fill")
                    .font(.system(size: 15, weight: .bold))
                Text("Leave a Review")
                    .font(Theme.body)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.amberGlow)
            .clipShape(RoundedRectangle(cornerRadius: Theme.r16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var remindLaterButton: some View {
        Button {
            animateOut(then: onRemindLater)
        } label: {
            Text("Remind me in a week")
                .font(Theme.sub)
                .foregroundColor(Theme.text2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Animation

    private func animateOut(then action: @escaping () -> Void) {
        withAnimation(.easeInOut(duration: 0.22)) {
            cardOffset  = 60
            cardOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            action()
        }
    }
}
