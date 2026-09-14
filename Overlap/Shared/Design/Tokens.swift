import SwiftUI

/// Design tokens from the handoff. Values are the light/dark pairs given there;
/// items carry no per-item tint — one neutral serves every element.
enum Token {

    // MARK: - Surfaces

    static let surface = Color(light: .white, dark: .black)
    /// tvOS has its own near-black surface and ships dark only.
    static let tvSurface = Color(hex: 0x0A0A0C)
    static let grouped = Color(light: Color(hex: 0xF2F2F7), dark: Color(hex: 0x1C1C1E))
    static let sidebar = Color(light: Color(hex: 0xF7F7FA), dark: Color(hex: 0x1C1C1E))

    static let ink = Color(light: .black, dark: .white)
    /// Marks and terminal circles use the slightly-off black.
    static let mark = Color(light: Color(hex: 0x1C1C1E), dark: .white)

    static let labelSecondary = Color(
        light: Color(red: 60/255, green: 60/255, blue: 67/255, opacity: 0.6),
        dark: Color(red: 235/255, green: 235/255, blue: 245/255, opacity: 0.6)
    )
    static let labelTertiary = Color(
        light: Color(red: 60/255, green: 60/255, blue: 67/255, opacity: 0.45),
        dark: Color(red: 235/255, green: 235/255, blue: 245/255, opacity: 0.55)
    )
    static let hairline = Color(
        light: Color(red: 60/255, green: 60/255, blue: 67/255, opacity: 0.16),
        dark: Color(white: 1, opacity: 0.16)
    )
    static let hairlineWidth: CGFloat = 0.5

    static let accent = Color(hex: 0x007AFF)
    /// Accent as text on light needs the darker step for contrast.
    static let accentText = Color(light: Color(hex: 0x0060DF), dark: Color(hex: 0x007AFF))
    /// The one place tint appears. Brightened on dark so it holds up against
    /// black without shifting hue.
    static let revealAccent = Color(light: Color(hex: 0x5E5CE6), dark: Color(hex: 0x7D7AFF))
    /// Run-level warnings — the offline banner is the only user of this.
    static let warning = Color(light: Color(hex: 0xFFCC00), dark: Color(hex: 0xFFD426))

    // MARK: - Neutral item tint

    /// Every item renders in this one neutral. Replaces the seven family tints.
    static let itemFill = Color(
        light: Color(red: 142/255, green: 142/255, blue: 147/255, opacity: 0.15),
        dark: Color(red: 142/255, green: 142/255, blue: 147/255, opacity: 0.30)
    )
    static let itemHairline = Color(
        light: Color(red: 142/255, green: 142/255, blue: 147/255, opacity: 0.28),
        dark: Color(white: 1, opacity: 0.22)
    )
    /// A pill already loaded into a circle.
    static let heldFill = Color(
        light: Color(red: 60/255, green: 60/255, blue: 67/255, opacity: 0.05),
        dark: Color(white: 1, opacity: 0.06)
    )
    static let heldHairline = Color(
        light: Color(red: 60/255, green: 60/255, blue: 67/255, opacity: 0.14),
        dark: Color(white: 1, opacity: 0.14)
    )
    static let heldLabel = Color(
        light: Color(red: 60/255, green: 60/255, blue: 67/255, opacity: 0.4),
        dark: Color(red: 235/255, green: 235/255, blue: 245/255, opacity: 0.4)
    )

    /// Board dot grid. Needs its own light/dark pair — a fixed dark dot vanishes
    /// on the dark board.
    static let boardDot = Color(
        light: Color(red: 60/255, green: 60/255, blue: 67/255, opacity: 0.14),
        dark: Color(white: 1, opacity: 0.16)
    )

    /// Venn circle fill — the same neutral, at the heavier alpha the circles use.
    static let vennFill = Color(
        light: Color(red: 142/255, green: 142/255, blue: 147/255, opacity: 0.5),
        dark: Color(red: 142/255, green: 142/255, blue: 147/255, opacity: 0.5)
    )
    /// Label sitting on top of a filled Venn circle. The circle blends light in
    /// both themes (multiply on light, screen on dark), so this stays dark.
    static let vennLabel = Color(
        light: .black,
        dark: Color(hex: 0x1C1C1E)
    )
    static let vennEmptyStroke = Color(
        light: Color(red: 60/255, green: 60/255, blue: 67/255, opacity: 0.2),
        dark: Color(white: 1, opacity: 0.28)
    )

    // MARK: - Radii & shadows

    enum Radius {
        static let card: CGFloat = 18
        static let sheet: CGFloat = 20
        static let field: CGFloat = 12
        static let tvTile: CGFloat = 30
        static let tvVenn: CGFloat = 34
        static let macControl: CGFloat = 7
    }

    /// Card: `0 1px 2px rgba(0,0,0,.06), 0 8px 24px rgba(0,0,0,.04)`
    static func card<V: View>(_ view: V) -> some View {
        view
            .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
            .shadow(color: .black.opacity(0.04), radius: 12, y: 8)
    }

    // MARK: - Motion

    /// `cubic-bezier(.2,.9,.2,1)` — the reveal curve.
    static let revealCurve = Animation.timingCurve(0.2, 0.9, 0.2, 1, duration: 0.42)
    static let emojiPop = Animation.timingCurve(0.2, 0.9, 0.2, 1, duration: 0.5)
    static let pillChange = Animation.easeInOut(duration: 0.18)
    static let tintChange = Animation.easeInOut(duration: 0.3)
    static let toastRise = Animation.easeInOut(duration: 0.3)
    /// The combine sequence: circles converge, blend deepens, emoji scales, name lands.
    static let combineSequence = Animation.timingCurve(0.3, 0.85, 0.25, 1, duration: 0.9)
}

// MARK: - Typography

extension Font {
    /// SF Pro Display 700 — discovered names and large titles.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }
    /// SF 590 — control and pill labels.
    static func control(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
    /// SF Mono 500 — metadata, always uppercase with wide tracking.
    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}

extension View {
    /// Mono metadata: uppercase, tracked, tertiary by default.
    func monoMeta(_ size: CGFloat, tracking: CGFloat = 0.14, color: Color = Token.labelTertiary) -> some View {
        self.font(.mono(size))
            .tracking(size * tracking)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }

    /// A hairline on one edge. Purely decorative: the rule is an overlay, and
    /// an overlay that accepts hits sits above the view's own controls and
    /// eats their taps, so it must never be hit-testable.
    func hairline(_ edge: Edge) -> some View {
        overlay(alignment: edge.alignment) {
            Rectangle()
                .fill(Token.hairline)
                .frame(
                    width: edge == .leading || edge == .trailing ? Token.hairlineWidth : nil,
                    height: edge == .top || edge == .bottom ? Token.hairlineWidth : nil
                )
                .allowsHitTesting(false)
        }
    }
}

private extension Edge {
    var alignment: Alignment {
        switch self {
        case .top: .top
        case .bottom: .bottom
        case .leading: .leading
        case .trailing: .trailing
        }
    }
}

// MARK: - Color helpers

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// Resolves per appearance. tvOS has no light mode, so it takes the dark value.
    init(light: Color, dark: Color) {
        #if os(tvOS)
        self = dark
        #else
        self = Color(uiColorLike: light, dark: dark)
        #endif
    }
}

#if !os(tvOS)
#if canImport(UIKit)
import UIKit
private extension Color {
    init(uiColorLike light: Color, dark: Color) {
        self = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}
#elseif canImport(AppKit)
import AppKit
private extension Color {
    init(uiColorLike light: Color, dark: Color) {
        self = Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return isDark ? NSColor(dark) : NSColor(light)
        })
    }
}
#endif
#endif
