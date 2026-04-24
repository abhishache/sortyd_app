// MARK: - WidgetColors.swift
// SortydWidgetExtension — Unified Theme Colors (matching app theme)

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
    // ── Backgrounds (Matching actual app theme) ───────────────────────────────
    static let bg0   = Color(widgetHex: "#141414")   // true dark 
    static let bg1   = Color(widgetHex: "#1E1E1E")   // card surface
    static let bg2   = Color(widgetHex: "#282828")   // input / secondary surface
    static let bg3   = Color(widgetHex: "#333333")   // track ring
    
    // ── Text ──────────────────────────────────────────────────────────────────
    static let text0 = Color(widgetHex: "#FFFFFF")   // pristine white
    static let text1 = Color(widgetHex: "#A0A0A0")   // secondary
    static let text2 = Color(widgetHex: "#707070")   // muted

    // ── Theme Accents ─────────────────────────────────────────────────────────
    static let primary   = Color(widgetHex: "#3ECFFF") // Violet/Magenta accent
    static let secondary = Color(widgetHex: "#7C6FFF") // Cyan/Blue accent
    
    // Subdued variations
    static let primaryDim   = primary.opacity(0.6)
    static let secondaryDim = secondary.opacity(0.6)
    
    static let glassBorder = Color.white.opacity(0.12)
    
    // ── Health/Stat Colors ───────────────────────────────────────────────────
    static let orange  = Color(widgetHex: "#FF7043") // Calories
    static let yellow  = Color(widgetHex: "#FFCC00") // Streak
    static let skyBlue = Color(widgetHex: "#4FC3F7") // Steps
    
    
    // Dynamic status color fading from subdued to full bright primary
    static func statusColor(fraction: Double) -> Color {
        switch fraction {
        case 0:        return bg3
        case ..<0.40:  return secondaryDim
        case ..<0.80:  return primaryDim
        case ..<1.0:   return secondary
        default:       return primary
        }
    }

    // ── Solid Base (Replaces Mesh) ────────────────────────────────────────────
    static let meshGradient = SolidColorGradient(color: bg0)
    
    static let arcGradient = AngularGradient(
        colors: [secondary, primary],
        center: .center,
        startAngle: .degrees(-90),
        endAngle: .degrees(270)
    )

    static let barGradient = LinearGradient(
        colors: [secondary, primary],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static func bubbleHeat(_ fraction: Double) -> Color {
        if fraction == 0 { return bg2 }
        if fraction < 0.4 { return secondaryDim }
        if fraction < 0.8 { return primaryDim }
        return primary
    }
}

// A simple structure to act as a solid background mimicking the gradient type where needed.
struct SolidColorGradient: View {
    var color: Color
    var body: some View {
        color.ignoresSafeArea()
    }
}
