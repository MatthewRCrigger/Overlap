import SwiftUI

/// Combine — the whole game on iPhone. Select input: tap for the left circle,
/// tap for the right, and the combine fires automatically.
struct CombineScreen: View {
    @Bindable var game: GameState
    @Environment(\.colorScheme) private var scheme
    @State private var animator = CombineAnimator()

    var body: some View {
        VStack(spacing: 0) {
            header
            stage
            CollectionShelf(game: game)
        }
        .background(Token.surface)
        .overlay(alignment: .center) { deadEndToast }
        .overlay(alignment: .center) { matchToast }
        .animation(Token.revealCurve, value: game.phase)
        .onChange(of: game.phase) { _, phase in
            if case .working = phase {
                Task { await animator.runConverge() }
            } else if case .idle = phase {
                animator.reset()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Overlap")
                    .font(.display(28))
                    .tracking(-28 * 0.03)
                    .foregroundStyle(Token.ink)
                // The counter never shows a total — only what the player has found.
                Text("\(game.collectedCount) collected · \(game.totalUntriedLeads) untried leads")
                    .monoMeta(10, color: Token.labelSecondary)
            }
            Spacer()
            HStack(spacing: 10) {
                GlassCircleButton(systemImage: "magnifyingglass") {}
                GlassCircleButton(systemImage: "line.3.horizontal") {}
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 58)
    }

    // MARK: - Venn stage

    private var stage: some View {
        VStack(spacing: 26) {
            VennStage(
                left: slotContent(game.slotA),
                right: slotContent(game.slotB),
                convergence: animator.convergence,
                blend: scheme == .dark ? .screen : .multiply,
                onTapLeft: game.acceptsInput ? { game.clearSlot(.left) } : nil,
                onTapRight: game.acceptsInput ? { game.clearSlot(.right) } : nil
            )
            Text(hintText)
                .monoMeta(10, color: Token.labelTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 250)
        }
        .frame(maxHeight: .infinity)
    }

    private func slotContent(_ id: ItemID?) -> (emoji: String, name: String)? {
        guard let id else { return nil }
        return (game.emoji(of: id), game.name(of: id))
    }

    private var hintText: String {
        if case .working = game.phase { return "Looking for the overlap…" }
        if game.slotA == nil { return "Tap an item for the left circle" }
        if game.slotB == nil { return "Now tap one for the right" }
        return "Looking for the overlap…"
    }

    // MARK: - Match

    /// The payoff, in place. Same on-screen treatment as "Nothing in common"
    /// so both outcomes read from the same spot and the player stays in the
    /// single game view for the whole session.
    @ViewBuilder
    private var matchToast: some View {
        if case .reveal(let reveal) = game.phase {
            MatchToast(game: game, reveal: reveal)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Dead end

    @ViewBuilder
    private var deadEndToast: some View {
        if case .deadEnd(let pair) = game.phase {
            let names = ComboEngine.parseInputs(of: pair).map { game.name(of: $0) }
            let recipe = names.count == 2 ? "\(names[0]) + \(names[1])" : "\(names[0]) + \(names[0])"
            VStack(spacing: 6) {
                Text("Nothing in common.")
                    .font(.control(15))
                    .foregroundStyle(Token.ink)
                Text("\(recipe) — empty lens")
                    .monoMeta(9.5, tracking: 0.1)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Token.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Token.Radius.card, style: .continuous)
                    .strokeBorder(Token.hairline, lineWidth: Token.hairlineWidth)
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// 44×44 glass circle with a blue glyph, per the header spec.
struct GlassCircleButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Token.accent)
                .frame(width: 44, height: 44)
                .background(.regularMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Token.hairline, lineWidth: Token.hairlineWidth))
        }
        .buttonStyle(.plain)
    }
}

/// The collection shelf: a wrapping pill grid with a bottom fade so a partial
/// row signals more content. Lazy — this runs into the thousands.
/// Ordering keeps the base four in front (they stay where the player learned
/// them) and lists later discoveries newest-first behind them.
struct CollectionShelf: View {
    let game: GameState

    private let columns = [GridItem(.adaptive(minimum: 96, maximum: 220), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your collection").monoMeta(10)
                Spacer()
                Text("Starters first").monoMeta(10)
            }
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(game.trayOrder, id: \.self) { id in
                        let isHeld = id == game.slotA || id == game.slotB
                        Button {
                            game.pick(id)
                        } label: {
                            ItemPill(
                                emoji: game.emoji(of: id),
                                name: game.name(of: id),
                                size: .iPhone,
                                style: isHeld ? .held : .normal
                            )
                        }
                        .buttonStyle(.plain)
                        // A pill loaded into a circle renders held and rejects input.
                        .disabled(isHeld || !game.acceptsInput)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 170)
            .overlay(alignment: .bottom) {
                // Bottom fade so a partial row signals more content. Decoration
                // only — a mask here would swallow taps on the pills beneath.
                LinearGradient(
                    colors: [Token.surface.opacity(0), Token.surface],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 28)
                .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 15)
        .padding(.bottom, 118)
        .hairline(.top)
        // Shelf pills settle back while a combine is resolving.
        .scaleEffect(game.acceptsInput ? 1 : 0.985)
        .animation(Token.pillChange, value: game.acceptsInput)
    }
}
