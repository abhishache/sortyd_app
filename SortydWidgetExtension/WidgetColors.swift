// MARK: - WidgetColors.swift
// SortydWidgetExtension — Design tokens mirrored from Theme.swift
// Widgets always render in dark mode using the deep space palette.
// Palette: #0C0D16 / #13141F backgrounds · #3ECFFF violet · #7C6FFF cyan
// (Widgets can't import the main app target, so we duplicate the raw values here.)

import SwiftUI

extension Color {
    init(widgetHex hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 3:  (a,r,g,b) = (255,(int>>8)*17,(int>>4 & 0xF)*17,(int & 0xF)*17)
        case 6:  (a,r,g,b) = (255,int>>16,int>>8 & 0xFF,int & 0xFF)
        case 8:  (a,r,g,b) = (int>>24,int>>16 & 0xFF,int>>8 & 0xFF,int & 0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255,
                  blue: Double(b)/255, opacity: Double(a)/255)
    }
}

enum WTheme {
    // ── Backgrounds — Deep space (mirrors Theme.swift dark mode) ─────────────
//    static let bg0   = Color(widgetHex: "#0C0D16")   // true dark canvas
//    static let bg1   = Color(widgetHex: "#13141F")   // card surface
//    static let bg2   = Color(widgetHex: "#1A1B2E")   // input / secondary surface
//    static let bg3   = Color(widgetHex: "#21223A")   // subtle fill / track ring
    static let bg0   = Color(widgetHex: "#111114")   // true dark — neutral near-black
    static let bg1   = Color(widgetHex: "#1A1A1F")   // card surface — cool grey
    static let bg2   = Color(widgetHex: "#222228")   // input / secondary surface
    static let bg3   = Color(widgetHex: "#2A2A32")   // subtle fill / track ring

    // ── Primary Accent — Violet #3ECFFF (mirrors Theme.accent dark mode) ─────
    static let amber = Color(widgetHex: "#3ECFFF")   // primary accent (violet)

    // ── Secondary Accent — Cyan #7C6FFF ──────────────────────────────────────
    static let coral = Color(widgetHex: "#7C6FFF")   // secondary / gradient partner
    static let mint  = Color(widgetHex: "#7C6FFF").opacity(0.65)  // tertiary / dimmed

    // ── Text ─────────────────────────────────────────────────────────────────
    static let text0 = Color(widgetHex: "#EEEEFF")   // primary — cool violet-white
    static let text1 = Color(widgetHex: "#7878AA")   // secondary
    static let text2 = Color(widgetHex: "#3A3A60")   // muted

    // ── Borders — dim violet glow edge ────────────────────────────────────────
    static let border = Color(widgetHex: "#3ECFFF").opacity(0.12)

    // ── Donut arc gradient — violet → cyan ────────────────────────────────────
    static let arcGradient = AngularGradient(
        colors: [
            Color(widgetHex: "#7C6FFF"),   // cyan at start
            Color(widgetHex: "#3ECFFF")    // violet at end
        ],
        center: .center,
        startAngle: .degrees(-90),
        endAngle: .degrees(270)
    )

    // ── Progress bar linear gradient — cyan → violet ──────────────────────────
    static let barGradient = LinearGradient(
        colors: [Color(widgetHex: "#7C6FFF"), Color(widgetHex: "#3ECFFF")],
        startPoint: .leading,
        endPoint: .trailing
    )

    // ── Heatmap — space base → violet → cyan intensity ramp ──────────────────
    static func heat(_ fraction: Double) -> Color {
        switch fraction {
        case 0:        return Color(widgetHex: "#13141F")
        case ..<0.20:  return Color(widgetHex: "#3ECFFF").opacity(0.20)
        case ..<0.40:  return Color(widgetHex: "#3ECFFF").opacity(0.40)
        case ..<0.60:  return Color(widgetHex: "#5A7FFF").opacity(0.65)
        case ..<0.80:  return Color(widgetHex: "#7C6FFF").opacity(0.80)
        default:       return Color(widgetHex: "#7C6FFF")
        }
    }
}
