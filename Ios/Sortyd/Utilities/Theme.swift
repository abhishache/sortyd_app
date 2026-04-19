// MARK: - Theme.swift
// Sortyd v4 — Redesigned Dark Mode
// Philosophy: Deep obsidian base, electric cyan primary, violet secondary.
// Dark mode feels premium, spatial, alive — not just "inverted light".

import SwiftUI
import Combine

// ── Theme Manager ─────────────────────────────────────────────
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var isDark: Bool {
        didSet { UserDefaults.standard.set(isDark, forKey: "sortyd_is_dark_theme") }
    }

    private init() {
        if let saved = UserDefaults.standard.object(forKey: "sortyd_is_dark_theme") as? Bool {
            self.isDark = saved
        } else {
            self.isDark = UITraitCollection.current.userInterfaceStyle == .dark
        }
    }

    var colorScheme: ColorScheme { isDark ? .dark : .light }
}

// ── Color Extension ───────────────────────────────────────────
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a,r,g,b) = (255,(int>>8)*17,(int>>4 & 0xF)*17,(int & 0xF)*17)
        case 6:  (a,r,g,b) = (255,int>>16,int>>8 & 0xFF,int & 0xFF)
        case 8:  (a,r,g,b) = (int>>24,int>>16 & 0xFF,int>>8 & 0xFF,int & 0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255,
                  blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// ── Theme ─────────────────────────────────────────────────────
enum Theme {
    
    

    private static var dark: Bool { ThemeManager.shared.isDark }

    // ── Backgrounds ──────────────────────────────────────────
    // Dark: True deep black with a barely-there blue tint — feels like OLED depth.
    // Each layer is noticeably distinct yet cohesive. No muddy mid-grays.
    static var bg0: Color { dark ? Color(hex: "#07080F") : Color(hex: "#F2F2FA") }
    static var bg1: Color { dark ? Color(hex: "#0E1019") : Color(hex: "#FAFAFF") }
    static var bg2: Color { dark ? Color(hex: "#151722") : Color(hex: "#EAEAF5") }
    static var bg3: Color { dark ? Color(hex: "#1C1E2E") : Color(hex: "#DDDDF0") }

    // ── Primary Accent — Electric Cyan ───────────────────────
    // Kept exactly at #3ECFFF — brand color. Pop it harder in dark mode.
    static var accent: Color     { dark ? Color(hex: "#3ECFFF") : Color(hex: "#5A4ECC") }
    static var accentMid: Color  { dark ? Color(hex: "#3ECFFF").opacity(0.70) : Color(hex: "#5A4ECC").opacity(0.80) }
    static var accentDim: Color  { dark ? Color(hex: "#3ECFFF").opacity(0.16) : Color(hex: "#5A4ECC").opacity(0.12) }

    // Legacy alias
    static var amber: Color      { accent }

    // ── Secondary Accent — Violet Purple ─────────────────────
    static var coral: Color      { dark ? Color(hex: "#7C6FFF") : Color(hex: "#0099C8") }
    static var coralMid: Color   { dark ? Color(hex: "#7C6FFF").opacity(0.70) : Color(hex: "#0099C8").opacity(0.80) }
    static var coralDim: Color   { dark ? Color(hex: "#7C6FFF").opacity(0.16) : Color(hex: "#0099C8").opacity(0.12) }

    static var mint: Color       { coral }
    static var mintMid: Color    { coralMid }
    static var mintDim: Color    { coralDim }

    // ── Indigo — deep violet for secondary stats ──────────────
    static var indigo: Color     { dark ? Color(hex: "#4A3FBF") : Color(hex: "#4A3FBF") }

    // ── Semantic Status ───────────────────────────────────────
    // Vivid in dark mode — they need to punch through the dark bg
    static var success: Color    { dark ? Color(hex: "#1FE090") : Color(hex: "#12A362") }
    static var warning: Color    { dark ? Color(hex: "#FFB547") : Color(hex: "#D4850A") }
    static var danger:  Color    { dark ? Color(hex: "#FF5F5F") : Color(hex: "#CC2222") }

    // ── Text ─────────────────────────────────────────────────
    // text0: near-white with a barely-there cool tint (not pure white — eyes)
    // text1: muted mid tone — for labels, subtitles
    // text2: very muted — for placeholders, empty states
    static var text0: Color { dark ? Color(hex: "#DDE2FF") : Color(hex: "#0C0D16") }
    static var text1: Color { dark ? Color(hex: "#535680") : Color(hex: "#4A4A80") }
    static var text2: Color { dark ? Color(hex: "#2A2D4A") : Color(hex: "#9090B8") }

    // ── Structural ────────────────────────────────────────────
    static var sep: Color { dark ? Color(hex: "#07080F") : Color(hex: "#DDDDF0") }

    // Borders: subtle cyan at very low opacity creates depth in dark mode
    static var border:       Color { dark ? Color(hex: "#3ECFFF").opacity(0.07) : Color(hex: "#5A4ECC").opacity(0.12) }
    static var borderMid: Color { dark ? Color(hex: "#3ECFFF").opacity(0.13) : Color(hex: "#5A4ECC").opacity(0.18) }
    static var borderAccent: Color { dark ? Color(hex: "#3ECFFF").opacity(0.30) : Color(hex: "#5A4ECC").opacity(0.35) }
    static var borderCyan:   Color { dark ? Color(hex: "#7C6FFF").opacity(0.28) : Color(hex: "#0099C8").opacity(0.30) }

    // Semantic shortcuts
    static var background:     Color { bg0 }
    static var cardBackground: Color { bg1 }
    static var primaryText:    Color { text0 }
    static var secondaryText:  Color { text1 }
    static var mutedText:      Color { text2 }

    // ── Score Color Utility ───────────────────────────────────
    static func scoreColor(for score: Int) -> Color {
        if dark {
            if score >= 75 { return Color(hex: "#1FE090") }
            if score >= 50 { return Color(hex: "#3ECFFF") }
            if score >= 30 { return Color(hex: "#FFB547") }
            return Color(hex: "#FF5F5F")
        } else {
            if score >= 75 { return Color(hex: "#12A362") }
            if score >= 50 { return Color(hex: "#5A4ECC") }
            if score >= 30 { return Color(hex: "#D4850A") }
            return Color(hex: "#CC2222")
        }
    }

    // ── Heatmap — analytics (purple → blue) ──────────────────
    static func heatColor(fraction: Double) -> Color {
        guard fraction > 0 else {
            return dark ? Color(hex: "#0E1019") : Color(hex: "#F0EEF8")
        }
        let t = max(0, min(fraction, 1.0))
        if dark {
            let r = 124.0 + (62.0  - 124.0) * t
            let g = 111.0 + (207.0 - 111.0) * t
            return Color(red: r/255, green: g/255, blue: 1.0)
                .opacity(0.28 + t * 0.72)
        } else {
            let r = 90.0  + (0.0   - 90.0)  * t
            let g = 78.0  + (153.0 - 78.0)  * t
            let b = 204.0 + (200.0 - 204.0) * t
            return Color(red: r/255, green: g/255, blue: b/255)
                .opacity(0.25 + t * 0.75)
        }
    }

    // ── Heatmap — home calendar (purple → blue, task-count discrete) ─
    // Same colours as heatColor but snaps to whole-task steps so each
    // cell represents exactly N tasks completed, not a continuous blend.
    static func heatColorRG(fraction: Double, taskCount: Int) -> Color {
        guard fraction > 0 else {
            return dark ? Color(hex: "#0E1019") : Color(hex: "#F0EEF8")
        }
        let n    = max(1, taskCount)
        let step = min(Int((fraction * Double(n)).rounded()), n)
        let t    = Double(step) / Double(n)
        if dark {
            let r = 124.0 + (62.0  - 124.0) * t
            let g = 111.0 + (207.0 - 111.0) * t
            return Color(red: r/255, green: g/255, blue: 1.0)
                .opacity(0.28 + t * 0.72)
        } else {
            let r = 90.0  + (0.0   - 90.0)  * t
            let g = 78.0  + (153.0 - 78.0)  * t
            let b = 204.0 + (200.0 - 204.0) * t
            return Color(red: r/255, green: g/255, blue: b/255)
                .opacity(0.25 + t * 0.75)
        }
    }

    // ── Radii ─────────────────────────────────────────────────
    static let r4:  CGFloat = 4
    static let r8:  CGFloat = 8
    static let r12: CGFloat = 12
    static let r16: CGFloat = 16
    static let r20: CGFloat = 20
    static let r24: CGFloat = 24
    static let r32: CGFloat = 32

    // ── Spacing ───────────────────────────────────────────────
    static let s4:  CGFloat = 4
    static let s8:  CGFloat = 8
    static let s12: CGFloat = 12
    static let s16: CGFloat = 16
    static let s20: CGFloat = 20
    static let s24: CGFloat = 24
    static let s32: CGFloat = 32

    // ── Gradients ─────────────────────────────────────────────

    // Brand signature: cyan → violet
    static var logoGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: "#3ECFFF"), Color(hex: "#7C6FFF")],
                       startPoint: .leading, endPoint: .trailing)
    }

    static var logoGradientMid: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#3ECFFF").opacity(0.70), Color(hex: "#7C6FFF").opacity(0.70)],
            startPoint: .leading, endPoint: .trailing
        )
    }

    static var logoGradientDim: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#3ECFFF").opacity(0.12), Color(hex: "#7C6FFF").opacity(0.12)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // CTA primary
    static var amberGlow: LinearGradient {
        LinearGradient(colors: [Color(hex: "#3ECFFF"), Color(hex: "#7C6FFF")],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // Streaks / achievements
    static var mintGlow: LinearGradient {
        LinearGradient(colors: [Color(hex: "#7C6FFF"), Color(hex: "#3ECFFF")],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // Deep secondary
    static var indigoGlow: LinearGradient {
        LinearGradient(colors: [Color(hex: "#4A3FBF"), Color(hex: "#7C6FFF")],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // Chart area
    static var chartGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#3ECFFF").opacity(0.25), Color(hex: "#3ECFFF").opacity(0.0)],
            startPoint: .top, endPoint: .bottom
        )
    }

    // Subtle ambient card fill — gives depth without noise
    static var cardAmbient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#3ECFFF").opacity(0.03), Color.clear],
            startPoint: .top, endPoint: .bottom
        )
    }
}

// MARK: - View Modifiers
extension View {

    func cardShadow() -> some View {
        self.shadow(
            color: .black.opacity(ThemeManager.shared.isDark ? 0.45 : 0.10),
            radius: 14, x: 0, y: 6
        )
    }

    func amberGlow(intensity: Double = 0.35) -> some View {
        self.shadow(color: Color(hex: "#3ECFFF").opacity(intensity), radius: 18, x: 0, y: 4)
    }

    func logoGlow(intensity: Double = 0.40) -> some View {
        self.shadow(color: Color(hex: "#3ECFFF").opacity(intensity), radius: 24, x: 0, y: 6)
    }

    func mintGlow(intensity: Double = 0.35) -> some View {
        self.shadow(color: Color(hex: "#7C6FFF").opacity(intensity), radius: 18, x: 0, y: 4)
    }

    func dualGlow(violetIntensity: Double = 0.28, cyanIntensity: Double = 0.14) -> some View {
        self
            .shadow(color: Color(hex: "#3ECFFF").opacity(violetIntensity), radius: 28, x: 0, y: 0)
            .shadow(color: Color(hex: "#7C6FFF").opacity(cyanIntensity), radius: 12, x: 0, y: 0)
    }

    func darkCard(radius: CGFloat = Theme.r20, padding: CGFloat = Theme.s16) -> some View {
        self.padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.bg1)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Theme.border, lineWidth: 0.5)
                    )
            )
            .cardShadow()
    }

    func glowCard(radius: CGFloat = Theme.r20, padding: CGFloat = Theme.s16) -> some View {
        self.padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.bg1)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Theme.borderAccent, lineWidth: 1.0)
                    )
            )
            .amberGlow(intensity: 0.20)
    }

    func cyanCard(radius: CGFloat = Theme.r20, padding: CGFloat = Theme.s16) -> some View {
        self.padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.bg1)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Theme.borderCyan, lineWidth: 1.0)
                    )
            )
            .mintGlow(intensity: 0.18)
    }
}

// MARK: - Theme Toggle Button
struct ThemeToggleButton: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                ThemeManager.shared.isDark.toggle()
            }
        }) {
            ZStack {
                Circle()
                    .fill(Theme.bg2)
                    .overlay(Circle().strokeBorder(Theme.border, lineWidth: 0.5))
                    .frame(width: 34, height: 34)
                Image(systemName: ThemeManager.shared.isDark ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.accent)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ThemeManager.shared.isDark ? "Switch to light mode" : "Switch to dark mode")
    }
}

// MARK: - ThemeToggleRow
struct ThemeToggleRow: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack {
            Image(systemName: themeManager.isDark ? "moon.fill" : "sun.max.fill")
                .foregroundColor(Theme.accent)
                .frame(width: 24)
            Text("Appearance")
                .foregroundColor(Theme.text0)
            Spacer()
            Toggle("", isOn: $themeManager.isDark)
                .labelsHidden()
                .tint(Theme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Theme.r16, style: .continuous)
                .fill(Theme.bg1)
                .overlay(RoundedRectangle(cornerRadius: Theme.r16, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 0.5))
        )
    }
}
