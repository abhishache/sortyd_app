// MARK: - LaunchBufferView.swift
// Sortyd — Launch buffer screen with Liquid Glass icon backing

import SwiftUI

struct LaunchBufferView: View {
    @State private var appear = false
    @State private var glowPulse = false

    private let teal   = Color(hex: "#3ECFFF")
    private let violet = Color(hex: "#7C6FFF")

    var body: some View {
        ZStack {
            Theme.bg0
                .ignoresSafeArea()

            // Soft ambient orbs
            GeometryReader { geo in
                Circle()
                    .fill(RadialGradient(
                        colors: [teal.opacity(0.12), teal.opacity(0.02), .clear],
                        center: .center, startRadius: 0, endRadius: 160
                    ))
                    .frame(width: 320, height: 320)
                    .blur(radius: 50)
                    .offset(x: -geo.size.width * 0.15, y: -geo.size.height * 0.08)

                Circle()
                    .fill(RadialGradient(
                        colors: [violet.opacity(0.10), violet.opacity(0.02), .clear],
                        center: .center, startRadius: 0, endRadius: 120
                    ))
                    .frame(width: 240, height: 240)
                    .blur(radius: 45)
                    .offset(x: geo.size.width * 0.5, y: geo.size.height * 0.6)
            }
            .allowsHitTesting(false)

            // Icon with Liquid Glass backing
            iconView
                .scaleEffect(appear ? 1 : 0.7)
                .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) {
                appear = true
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(0.3)) {
                glowPulse = true
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if #available(iOS 26.0, *) {
            // Native Liquid Glass — lenses and refracts the background
            Image("AppIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(16)
                .glassEffect(
                    .regular.tint(teal.opacity(0.08)),
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                )
                .shadow(color: teal.opacity(glowPulse ? 0.25 : 0.08), radius: 28, y: 8)
                .shadow(color: .black.opacity(0.2), radius: 16, y: 10)
        } else {
            // Fallback for iOS < 26 — ultraThinMaterial approximation
            Image("AppIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(16)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(teal.opacity(0.06))
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.25), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    }
                )
                .shadow(color: teal.opacity(glowPulse ? 0.15 : 0.06), radius: 24, y: 8)
                .shadow(color: .black.opacity(0.25), radius: 20, y: 12)
        }
    }
}

#Preview("Dark") {
    LaunchBufferView()
        .environmentObject(ThemeManager.shared)
}

#Preview("Light") {
    LaunchBufferView()
        .onAppear { ThemeManager.shared.isDark = false }
        .environmentObject(ThemeManager.shared)
}

