// MARK: - ReviewPromptView.swift
// Sortyd — App Store review prompt card

import SwiftUI

struct ReviewPromptCard: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var onReviewTapped: () -> Void
    var onDismissed: () -> Void

    @State private var starsVisible = false
    @State private var contentHeight: CGFloat = 560

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    headerBand
                    bodySection
                }
                .background(GeometryReader { content in
                    Color.clear.preference(key: ReviewCardHeightKey.self, value: content.size.height)
                })
            }
            .onPreferenceChange(ReviewCardHeightKey.self) { contentHeight = $0 }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxWidth: 330)
            .frame(height: min(contentHeight, max(1, geometry.size.height - 32)))
            .background(Theme.bg1)
            .clipShape(RoundedRectangle(cornerRadius: Theme.r24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.r24, style: .continuous)
                    .strokeBorder(Theme.borderAccent, lineWidth: 1.0)
            )
            .cardShadow()
            .dualGlow(violetIntensity: 0.22, cyanIntensity: 0.10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 28) // Outer padding for safe area
        .onAppear {
            guard !reduceMotion else {
                starsVisible = true
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.spring(response: 0.50, dampingFraction: 0.58)) {
                    starsVisible = true
                }
            }
        }
    }

    // MARK: - Subviews

    private var headerBand: some View {
            VStack(spacing: 12) {
                starRow
                    .padding(.top, 24)

                VStack(spacing: 4) {
                    Text(vm.localized("Help Sortyd reach more people"))
                        .font(Theme.h3)
                        .foregroundColor(Theme.text0)
                        .multilineTextAlignment(.center)

                    Text(vm.localized("Sortyd is free, and honest feedback helps us keep it that way."))
                        .font(Theme.caption)
                        .foregroundColor(Theme.text1)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
            .frame(maxWidth: .infinity)
            .background(Theme.logoGradientDim)
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
                        reduceMotion ? nil : .spring(response: 0.50, dampingFraction: 0.58)
                            .delay(Double(i) * 0.075),
                        value: starsVisible
                    )
            }
        }
    }

    private var bodySection: some View {
        VStack(spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 11, weight: .bold))
                Text(vm.localized("30 seconds • one honest review"))
                    .font(Theme.caption.weight(.semibold))
            }
            .foregroundColor(Theme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Theme.accent.opacity(0.10))
            .clipShape(Capsule())

            Text(vm.localized("We build Sortyd to help more people build better days. Your honest App Store review is the feedback that helps us reach them."))
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
                Text(vm.localized("Review Sortyd in 30 seconds"))
                    .font(Theme.body)
            }
            .foregroundColor(ThemeManager.shared.isDark ? Color(hex: "#0A1A0A") : .white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .background(Theme.amberGlow)
            .clipShape(RoundedRectangle(cornerRadius: Theme.r16, style: .continuous))
        }
        .buttonStyle(PremiumPressStyle())
        .accessibilityHint(vm.localized("Opens the App Store so you can leave an honest review."))
    }

    private var remindLaterButton: some View {
        Button {
            onDismissed()
        } label: {
            Text(vm.localized("Remind me later"))
                .font(Theme.sub)
                .foregroundColor(Theme.text1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(PremiumPressStyle())
    }
}

private struct ReviewCardHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    ReviewPromptCard(
        onReviewTapped: { print("Review tapped") },
        onDismissed: { print("Remind later tapped") }
    )
    .environmentObject(ThemeManager.shared)
    .environmentObject(AppViewModel())
}
