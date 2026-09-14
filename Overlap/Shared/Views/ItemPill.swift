import SwiftUI

/// The item pill, at the sizes the handoff enumerates per platform and context.
struct PillSize {
    let height: CGFloat
    let paddingInline: CGFloat
    let emoji: CGFloat
    let label: CGFloat

    static let iPhone      = PillSize(height: 44, paddingInline: 15, emoji: 17, label: 15)
    static let iPadBoard   = PillSize(height: 46, paddingInline: 16, emoji: 18, label: 15.5)
    static let iPadTray    = PillSize(height: 40, paddingInline: 14, emoji: 16, label: 14)
    static let macBoard    = PillSize(height: 38, paddingInline: 13, emoji: 15, label: 13.5)
    static let macTray     = PillSize(height: 34, paddingInline: 12, emoji: 14, label: 13)
    static let inline      = PillSize(height: 30, paddingInline: 12, emoji: 13, label: 12.5)
    static let inlineLarge = PillSize(height: 36, paddingInline: 13, emoji: 15, label: 13.5)

    var radius: CGFloat { height / 2 }
}

enum PillStyle {
    /// Normal, tappable/draggable.
    case normal
    /// Loaded into a circle — dimmed and inert.
    case held
    /// An implied but undiscovered item; renders masked.
    case locked
}

/// Names run to three words, so pills never wrap: one line, tail-truncated.
/// The full name shows in the reveal and detail views.
struct ItemPill: View {
    let emoji: String
    let name: String
    var size: PillSize = .iPhone
    var style: PillStyle = .normal
    /// Dimmed while its copy is being dragged elsewhere.
    var isDragSource: Bool = false

    private var maxNameLength: Int { 18 }

    /// Measures a pill without rendering one, so the board can size drop
    /// targets and halos to the pill they actually belong to.
    static func width(emoji: String, name: String, size: PillSize) -> CGFloat {
        #if canImport(UIKit)
        let labelFont = UIFont.systemFont(ofSize: size.label, weight: .semibold)
        let emojiFont = UIFont.systemFont(ofSize: size.emoji)
        let labelWidth = (name as NSString)
            .size(withAttributes: [.font: labelFont]).width
        let emojiWidth = (emoji as NSString)
            .size(withAttributes: [.font: emojiFont]).width
        #elseif canImport(AppKit)
        let labelFont = NSFont.systemFont(ofSize: size.label, weight: .semibold)
        let emojiFont = NSFont.systemFont(ofSize: size.emoji)
        let labelWidth = (name as NSString)
            .size(withAttributes: [.font: labelFont]).width
        let emojiWidth = (emoji as NSString)
            .size(withAttributes: [.font: emojiFont]).width
        #else
        let labelWidth = CGFloat(name.count) * size.label * 0.55
        let emojiWidth = size.emoji * 1.2
        #endif
        // emoji + gap + label, inside the pill's own horizontal padding.
        return ceil(emojiWidth + 8 + labelWidth + size.paddingInline * 2)
    }

    var body: some View {
        HStack(spacing: 8) {
            if style == .locked {
                Text("?????")
                    .font(.mono(size.label * 0.85))
                    .tracking(size.label * 0.08)
                    .foregroundStyle(Token.heldLabel)
            } else {
                Text(emoji)
                    .font(.system(size: size.emoji))
                Text(name)
                    .font(.control(size.label))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(labelColor)
            }
        }
        .padding(.horizontal, size.paddingInline)
        .frame(height: size.height)
        .background(
            Capsule(style: .continuous).fill(fill)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(stroke, lineWidth: Token.hairlineWidth)
        )
        .opacity(isDragSource ? 0.45 : 1)
        .animation(Token.pillChange, value: style)
        .animation(Token.pillChange, value: isDragSource)
        // The pill is the primary touch target; 44pt minimum everywhere on touch.
        .contentShape(Capsule(style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(style == .locked ? "Undiscovered item" : name)
    }

    private var fill: Color {
        switch style {
        case .normal: Token.itemFill
        case .held:   Token.heldFill
        case .locked: Token.grouped
        }
    }

    private var stroke: Color {
        switch style {
        case .normal: Token.itemHairline
        case .held:   Token.heldHairline
        case .locked: Token.hairline
        }
    }

    private var labelColor: Color {
        style == .held ? Token.heldLabel : Token.ink
    }
}

/// The dragged pill — the only opaque thing on the board.
struct DraggedPill: View {
    let emoji: String
    let name: String
    var size: PillSize = .iPadBoard

    var body: some View {
        HStack(spacing: 8) {
            Text(emoji).font(.system(size: size.emoji))
            Text(name)
                .font(.control(size.label))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(Token.ink)
        }
        .padding(.horizontal, size.paddingInline)
        .frame(height: size.height)
        .background(Capsule(style: .continuous).fill(Color(light: .white, dark: Color(hex: 0x2C2C2E))))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color(red: 142/255, green: 142/255, blue: 147/255, opacity: 0.4),
                              lineWidth: Token.hairlineWidth)
        )
        .shadow(color: .black.opacity(0.24), radius: 25, y: 26)
        .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
        .rotationEffect(.degrees(-3))
        .scaleEffect(1.06)
    }
}
