// MARK: - Theme.swift
// Sortyd v4 — Classic Blue/Purple Light & Charcoal Dark
// Philosophy: Light = crisp white/lavender + indigo/violet accents (original brand)
//             Dark  = pure charcoal steps (new) + cyan/violet accents (original brand)

import SwiftUI
import Combine

// ── Theme Manager ─────────────────────────────────────────────
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var isDark: Bool {
        didSet { UserDefaults.standard.set(isDark, forKey: "sortyd_is_dark_theme") }
    }

    @Published var selectedFont: AppFont {
        didSet { UserDefaults.standard.set(selectedFont.rawValue, forKey: "sortyd_app_font") }
    }

    private init() {
        if let savedDark = UserDefaults.standard.object(forKey: "sortyd_is_dark_theme") as? Bool {
            self.isDark = savedDark
        } else {
            self.isDark = UITraitCollection.current.userInterfaceStyle == .dark
        }

        if let savedFontRaw = UserDefaults.standard.string(forKey: "sortyd_app_font"),
           let savedFont = AppFont(rawValue: savedFontRaw) {
            self.selectedFont = savedFont
        } else {
            self.selectedFont = .rounded
        }
    }

    var colorScheme: ColorScheme { isDark ? .dark : .light }
}

// ── App Font Enum ──────────────────────────────────────────────
enum AppFont: String, CaseIterable {
    case rounded = "Rounded"
    case sans    = "Classic Sans"
    case serif   = "Editorial Serif"
    case mono    = "Technical Mono"

    var design: Font.Design {
        switch self {
        case .rounded: return .rounded
        case .sans:    return .default
        case .serif:   return .serif
        case .mono:    return .monospaced
        }
    }
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
    // Dark:  new charcoal steps (no blue/purple tint)
    // Light: original white/lavender steps (fully restored)
    static var bg0: Color { dark ? Color(hex: "#141414") : Color(hex: "#F2F2FA") }
    static var bg1: Color { dark ? Color(hex: "#1E1E1E") : Color(hex: "#FAFAFF") }
    static var bg2: Color { dark ? Color(hex: "#282828") : Color(hex: "#EAEAF5") }
    static var bg3: Color { dark ? Color(hex: "#333333") : Color(hex: "#DDDDF0") }

    // ── Primary Accent ────────────────────────────────────────
    // Dark:  cyan (unchanged from new theme)
    // Light: indigo (original)
    static var accent: Color    { dark ? Color(hex: "#00D9FF") : Color(hex: "#5A4ECC") }
    static var accentMid: Color { dark ? Color(hex: "#00D9FF").opacity(0.65) : Color(hex: "#5A4ECC").opacity(0.80) }
    static var accentDim: Color { dark ? Color(hex: "#00D9FF").opacity(0.14) : Color(hex: "#5A4ECC").opacity(0.12) }

    // Legacy alias
    static var amber: Color { accent }

    // ── Secondary Accent ──────────────────────────────────────
    // Dark:  teal (unchanged from new theme)
    // Light: cyan blue (original)
    static var coral: Color    { dark ? Color(hex: "#00C4B4") : Color(hex: "#0099C8") }
    static var coralMid: Color { dark ? Color(hex: "#00C4B4").opacity(0.65) : Color(hex: "#0099C8").opacity(0.80) }
    static var coralDim: Color { dark ? Color(hex: "#00C4B4").opacity(0.14) : Color(hex: "#0099C8").opacity(0.12) }

    static var mint: Color    { coral }
    static var mintMid: Color { coralMid }
    static var mintDim: Color { coralDim }

    // ── Tertiary Accent ───────────────────────────────────────
    // Dark:  unchanged from new theme
    // Light: deep indigo (original)
    static var indigo: Color { dark ? Color(hex: "#7AADA0") : Color(hex: "#4A3FBF") }

    // ── Semantic Status ───────────────────────────────────────
    // Dark:  unchanged from new theme
    // Light: original values
    static var success: Color { dark ? Color(hex: "#4FD49A") : Color(hex: "#12A362") }
    static var warning: Color { dark ? Color(hex: "#FFBC55") : Color(hex: "#D4850A") }
    static var danger:  Color { dark ? Color(hex: "#FF6B6B") : Color(hex: "#CC2222") }

    // ── Text ──────────────────────────────────────────────────
    // Dark:  unchanged from new theme
    // Light: original blue-tinted text hierarchy
    static var text0: Color { dark ? Color(hex: "#EDEDED") : Color(hex: "#0C0D16") }
    static var text1: Color { dark ? Color(hex: "#A0A0A0") : Color(hex: "#4A4A80") }
    static var text2: Color { dark ? Color(hex: "#636363") : Color(hex: "#9090B8") }

    // ── Structural ────────────────────────────────────────────
    // Dark:  unchanged from new theme
    // Light: original lavender separator
    static var sep: Color { dark ? Color(hex: "#0D0D0D") : Color(hex: "#DDDDF0") }

    static var border:       Color { dark ? Color(hex: "#00D9FF").opacity(0.10) : Color(hex: "#5A4ECC").opacity(0.12) }
    static var borderMid:    Color { dark ? Color(hex: "#00D9FF").opacity(0.20) : Color(hex: "#5A4ECC").opacity(0.18) }
    static var borderAccent: Color { dark ? Color(hex: "#00D9FF").opacity(0.40) : Color(hex: "#5A4ECC").opacity(0.35) }
    static var borderCyan:   Color { dark ? Color(hex: "#00C4B4").opacity(0.35) : Color(hex: "#0099C8").opacity(0.30) }

    // Semantic shortcuts
    static var background:     Color { bg0 }
    static var cardBackground: Color { bg1 }
    static var primaryText:    Color { text0 }
    static var secondaryText:  Color { text1 }
    static var mutedText:      Color { text2 }

    // ── Score Color Utility ───────────────────────────────────
    // Dark:  unchanged from new theme
    // Light: original values
    static func scoreColor(for score: Int) -> Color {
        if dark {
            if score >= 75 { return Color(hex: "#4FD49A") }
            if score >= 50 { return Color(hex: "#00D9FF") }
            if score >= 30 { return Color(hex: "#FFBC55") }
            return Color(hex: "#FF6B6B")
        } else {
            if score >= 75 { return Color(hex: "#12A362") }
            if score >= 50 { return Color(hex: "#5A4ECC") }
            if score >= 30 { return Color(hex: "#D4850A") }
            return Color(hex: "#CC2222")
        }
    }

    // ── Heatmap — analytics ───────────────────────────────────
    // Dark:  green → cyan ramp (unchanged from new theme)
    // Light: purple → blue ramp (original)
    static func heatColor(fraction: Double) -> Color {
        guard fraction > 0 else {
            return dark ? Color(hex: "#1E1E1E") : Color(hex: "#F0EEF8")
        }
        let t = max(0, min(fraction, 1.0))
        if dark {
            let g = 196.0 + (217.0 - 196.0) * t
            let b = 180.0 + (255.0 - 180.0) * t
            return Color(red: 0, green: g/255, blue: b/255)
                .opacity(0.30 + t * 0.70)
        } else {
            let r = 90.0  + (0.0   - 90.0)  * t
            let g = 78.0  + (153.0 - 78.0)  * t
            let b = 204.0 + (200.0 - 204.0) * t
            return Color(red: r/255, green: g/255, blue: b/255)
                .opacity(0.25 + t * 0.75)
        }
    }

    // ── Heatmap — home calendar ───────────────────────────────
    // Dark:  unchanged from new theme
    // Light: original purple → blue discrete steps
    static func heatColorRG(fraction: Double, taskCount: Int) -> Color {
        guard fraction > 0 else {
            return dark ? Color(hex: "#1E1E1E") : Color(hex: "#F0EEF8")
        }
        let n    = max(1, taskCount)
        let step = min(Int((fraction * Double(n)).rounded()), n)
        let t    = Double(step) / Double(n)
        if dark {
            let g = 196.0 + (217.0 - 196.0) * t
            let b = 180.0 + (255.0 - 180.0) * t
            return Color(red: 0, green: g/255, blue: b/255)
                .opacity(0.30 + t * 0.70)
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
    // Dark:  cyan → teal (unchanged from new theme)
    // Light: indigo → violet (original)
    static var logoGradient: LinearGradient {
        dark
            ? LinearGradient(colors: [Color(hex: "#00D9FF"), Color(hex: "#00C4B4")],
                             startPoint: .leading, endPoint: .trailing)
            : LinearGradient(colors: [Color(hex: "#5A4ECC"), Color(hex: "#7C6FFF")],
                             startPoint: .leading, endPoint: .trailing)
    }

    static var logoGradientMid: LinearGradient {
        dark
            ? LinearGradient(
                colors: [Color(hex: "#00D9FF").opacity(0.70), Color(hex: "#00C4B4").opacity(0.70)],
                startPoint: .leading, endPoint: .trailing)
            : LinearGradient(
                colors: [Color(hex: "#5A4ECC").opacity(0.70), Color(hex: "#7C6FFF").opacity(0.70)],
                startPoint: .leading, endPoint: .trailing)
    }

    static var logoGradientDim: LinearGradient {
        dark
            ? LinearGradient(
                colors: [Color(hex: "#00D9FF").opacity(0.12), Color(hex: "#00C4B4").opacity(0.12)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(
                colors: [Color(hex: "#5A4ECC").opacity(0.12), Color(hex: "#7C6FFF").opacity(0.12)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var amberGlow: LinearGradient {
        dark
            ? LinearGradient(colors: [Color(hex: "#00D9FF"), Color(hex: "#00C4B4")],
                             startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [Color(hex: "#5A4ECC"), Color(hex: "#7C6FFF")],
                             startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var mintGlow: LinearGradient {
        dark
            ? LinearGradient(colors: [Color(hex: "#00C4B4"), Color(hex: "#00D9FF")],
                             startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [Color(hex: "#7C6FFF"), Color(hex: "#5A4ECC")],
                             startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var indigoGlow: LinearGradient {
        dark
            ? LinearGradient(colors: [Color(hex: "#7AADA0"), Color(hex: "#00C4B4")],
                             startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [Color(hex: "#4A3FBF"), Color(hex: "#7C6FFF")],
                             startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var chartGradient: LinearGradient {
        dark
            ? LinearGradient(
                colors: [Color(hex: "#00D9FF").opacity(0.22), Color(hex: "#00D9FF").opacity(0.0)],
                startPoint: .top, endPoint: .bottom)
            : LinearGradient(
                colors: [Color(hex: "#5A4ECC").opacity(0.22), Color(hex: "#5A4ECC").opacity(0.0)],
                startPoint: .top, endPoint: .bottom)
    }

    static var cardAmbient: LinearGradient {
        dark
            ? LinearGradient(
                colors: [Color(hex: "#00D9FF").opacity(0.03), Color.clear],
                startPoint: .top, endPoint: .bottom)
            : LinearGradient(
                colors: [Color(hex: "#5A4ECC").opacity(0.03), Color.clear],
                startPoint: .top, endPoint: .bottom)
    }

    // ── Typography ────────────────────────────────────────────
    static func font(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design? = nil) -> Font {
        let selectedDesign = design ?? ThemeManager.shared.selectedFont.design
        return .system(size: size, weight: weight, design: selectedDesign)
    }

    // Semantic shorthands
    static var h1:     Font { font(size: 34, weight: .heavy) }
    static var h2:     Font { font(size: 24, weight: .bold) }
    static var h3:     Font { font(size: 20, weight: .bold) }
    static var body:   Font { font(size: 16, weight: .medium) }
    static var sub:    Font { font(size: 14, weight: .medium) }
    static var caption: Font { font(size: 12, weight: .semibold) }
    static var tiny:   Font { font(size: 10, weight: .bold) }
}

// MARK: - View Modifiers
extension View {

    func cardShadow() -> some View {
        self.shadow(
            color: .black.opacity(ThemeManager.shared.isDark ? 0.50 : 0.08),
            radius: 14, x: 0, y: 6
        )
    }

    func amberGlow(intensity: Double = 0.35) -> some View {
        self.shadow(
            color: ThemeManager.shared.isDark
                ? Color(hex: "#00D9FF").opacity(intensity)
                : Color(hex: "#5A4ECC").opacity(intensity),
            radius: 18, x: 0, y: 4
        )
    }

    func logoGlow(intensity: Double = 0.40) -> some View {
        self.shadow(
            color: ThemeManager.shared.isDark
                ? Color(hex: "#00D9FF").opacity(intensity)
                : Color(hex: "#5A4ECC").opacity(intensity),
            radius: 24, x: 0, y: 6
        )
    }

    func mintGlow(intensity: Double = 0.35) -> some View {
        self.shadow(
            color: ThemeManager.shared.isDark
                ? Color(hex: "#00C4B4").opacity(intensity)
                : Color(hex: "#7C6FFF").opacity(intensity),
            radius: 18, x: 0, y: 4
        )
    }

    func dualGlow(violetIntensity: Double = 0.28, cyanIntensity: Double = 0.14) -> some View {
        self
            .shadow(
                color: ThemeManager.shared.isDark
                    ? Color(hex: "#00D9FF").opacity(violetIntensity)
                    : Color(hex: "#5A4ECC").opacity(violetIntensity),
                radius: 28, x: 0, y: 0
            )
            .shadow(
                color: ThemeManager.shared.isDark
                    ? Color(hex: "#00C4B4").opacity(cyanIntensity)
                    : Color(hex: "#7C6FFF").opacity(cyanIntensity),
                radius: 12, x: 0, y: 0
            )
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
                Image(systemName: ThemeManager.shared.isDark ? "sun.max.fill" : "moon.fill")
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
            Image(systemName: themeManager.isDark ? "sun.max.fill" : "moon.fill")
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
