import SwiftUI

/// The mark: two circles and a striped lens. Shape code, not an image asset, so
/// it scales and inverts. Proportions from the handoff's construction notes.
struct LogoMark: View {
    /// Circle diameter. The mark's full width is `2d − overlap`.
    var diameter: CGFloat = 96

    private var overlap: CGFloat { 0.36 * diameter }
    private var strokeWidth: CGFloat { 0.062 * diameter }
    private var bar: CGFloat { 0.05 * diameter }
    private var width: CGFloat { 2 * diameter - overlap }
    private var offset: CGFloat { diameter - overlap }
    /// Below ~40pt the bars merge; small sizes ship a solid knock-out instead.
    private var showsBars: Bool { diameter >= 40 }

    var body: some View {
        ZStack(alignment: .leading) {
            // Left circle: solid ink, clipping the striped lens.
            Circle()
                .fill(Token.mark)
                .frame(width: diameter, height: diameter)
                .overlay(alignment: .leading) { lens }

            // Right circle: transparent, ink ring.
            Circle()
                .strokeBorder(Token.mark, lineWidth: strokeWidth)
                .frame(width: diameter, height: diameter)
                .offset(x: offset)
        }
        .frame(width: width, height: diameter)
        .accessibilityHidden(true)
    }

    /// The lens is the right circle's intersection, knocked out of the ink.
    private var lens: some View {
        Group {
            if showsBars {
                bars
            } else {
                Rectangle().fill(Token.surface)
            }
        }
        // Clip the knock-out to the right circle, then back to the left one.
        .mask(
            Circle()
                .frame(width: diameter, height: diameter)
                .offset(x: offset)
                .frame(width: diameter, height: diameter, alignment: .leading)
        )
    }

    private var bars: some View {
        GeometryReader { geo in
            VStack(spacing: bar) {
                ForEach(0..<Int(geo.size.height / (bar * 2)) + 1, id: \.self) { _ in
                    Rectangle()
                        .fill(Token.surface)
                        .frame(height: bar)
                }
            }
        }
    }
}

/// Launch screen — identical to the app's first painted frame, so there's no
/// visible swap. Static: the mark must stay registered.
struct LaunchView: View {
    var markDiameter: CGFloat = 96
    var wordmarkSize: CGFloat = 52
    var taglineSize: CGFloat = 11
    var gap: CGFloat = 44
    var taglineGap: CGFloat = 14

    var body: some View {
        VStack(spacing: gap) {
            LogoMark(diameter: markDiameter)
            VStack(spacing: taglineGap) {
                Text("Overlap")
                    .font(.display(wordmarkSize))
                    .tracking(-wordmarkSize * 0.035)
                    .foregroundStyle(Token.ink)
                Text("What can two things become?")
                    .monoMeta(taglineSize, tracking: 0.24, color: Token.labelTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Token.surface)
    }
}
