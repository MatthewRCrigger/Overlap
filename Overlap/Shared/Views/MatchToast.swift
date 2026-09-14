import SwiftUI

/// The match result, shown in place on the playfield.
///
/// The player stays in the game view for the whole session: a match is a toast
/// on the board, exactly as "Nothing in common" already is, rather than a
/// full-screen takeover. The takeover was also the freeze — on the drag
/// platforms nothing rendered `.reveal`, so the phase held input hostage with
/// no on-screen way to clear it.
struct MatchToast: View {
    let game: GameState
    let reveal: Reveal
    /// tvOS sits on its own near-black surface and needs the dark treatment
    /// regardless of the reported color scheme.
    var forceDark: Bool = false
    /// Sizes up for the 10-foot surface.
    var isTV: Bool = false

    @Environment(\.colorScheme) private var scheme
    /// Drives the emoji's pop only — never this view's visibility. A flag that
    /// gated visibility could lose the race with the parent transition and
    /// leave an invisible view swallowing taps.
    @State private var popped = false

    private var isDark: Bool { forceDark || scheme == .dark }

    var body: some View {
        VStack(spacing: isTV ? 14 : 10) {
            Text(game.emoji(of: reveal.result))
                .font(.system(size: isTV ? 64 : 40))
                .scaleEffect(popped ? 1 : 0.6)
                .animation(Token.emojiPop, value: popped)
                .onAppear {
                    popped = true
                    // Success fires for a new item only — an item you already
                    // owned is a result, not a discovery.
                    #if os(iOS)
                    if reveal.isNew {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                    #endif
                }

            Text(game.name(of: reveal.result))
                .font(.display(isTV ? 34 : 22))
                .tracking(-(isTV ? 34 : 22) * 0.03)
                .foregroundStyle(Token.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            // Omitted when the item was already collected.
            if reveal.isNew {
                Text("New to your collection")
                    .monoMeta(isTV ? 13 : 9.5, tracking: 0.18, color: Token.revealAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(Token.revealAccent.opacity(isDark ? 0.30 : 0.14))
                    )
            }

            recipeRow

            // Only the leads count survives from the old takeover's stat row —
            // it is the one number that tells the player where to go next.
            Text("\(game.untriedLeadCount(for: reveal.result)) leads out")
                .monoMeta(isTV ? 12 : 9.5, tracking: 0.12)
        }
        .padding(.horizontal, isTV ? 34 : 22)
        .padding(.vertical, isTV ? 26 : 18)
        .frame(maxWidth: isTV ? 460 : 320)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: Token.Radius.card, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Token.Radius.card, style: .continuous)
                .strokeBorder(Token.hairline, lineWidth: Token.hairlineWidth)
        )
        .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
        .shadow(color: .black.opacity(0.12), radius: 20, y: 14)
        .contentShape(RoundedRectangle(cornerRadius: Token.Radius.card, style: .continuous))
        // Tap the toast to clear it early; it also self-clears on a dwell.
        .onTapGesture { game.dismiss() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            reveal.isNew
                ? "New item: \(game.name(of: reveal.result))"
                : "Found \(game.name(of: reveal.result)), already collected"
        )
    }

    private var recipeRow: some View {
        HStack(spacing: 7) {
            ItemPill(
                emoji: game.emoji(of: reveal.a),
                name: game.name(of: reveal.a),
                size: isTV ? .inlineLarge : .inline
            )
            Text("+").font(.mono(isTV ? 14 : 12)).foregroundStyle(Token.labelTertiary)
            ItemPill(
                emoji: game.emoji(of: reveal.b),
                name: game.name(of: reveal.b),
                size: isTV ? .inlineLarge : .inline
            )
        }
    }
}
