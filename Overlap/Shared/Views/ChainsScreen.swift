import SwiftUI

/// Chains index — the routes you've taken from the starting four to somewhere far.
struct ChainsScreen: View {
    let game: GameState

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    header
                    ForEach(game.chains) { chain in
                        NavigationLink {
                            ChainDetailScreen(game: game, chain: chain)
                        } label: {
                            ChainCard(game: game, chain: chain)
                        }
                        .buttonStyle(.plain)
                    }
                    looseEnds
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 118)
            }
            .background(Token.surface)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chains")
                .font(.display(38))
                .tracking(-38 * 0.035)
                .foregroundStyle(Token.ink)
            Text("\(game.chains.count) chains").monoMeta(11)
            Text("Every route you've taken from the starting four.")
                .font(.system(size: 14))
                .foregroundStyle(Token.labelSecondary)
        }
        .padding(.top, 58)
        .padding(.bottom, 6)
    }

    private var looseEnds: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Loose ends")
                .font(.display(22))
                .foregroundStyle(Token.ink)
            Text("\(game.looseEndCount) items in no chain — they combined into nothing, so far.")
                .font(.system(size: 13))
                .foregroundStyle(Token.labelSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Token.Radius.card, style: .continuous)
                .fill(Token.sidebar)
        )
    }
}

struct ChainCard: View {
    let game: GameState
    let chain: Chain

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                // Chain naming: the terminal element's name.
                Text(game.name(of: chain.terminal))
                    .font(.display(22))
                    .foregroundStyle(Token.ink)
                    .lineLimit(1)
                Spacer()
                Text("\(chain.combineCount) combines").monoMeta(9.5, tracking: 0.1)
            }

            HStack(alignment: .center, spacing: 0) {
                ChainCircles(game: game, chain: chain)
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Ends at").monoMeta(9, tracking: 0.1)
                    Text(game.name(of: chain.terminal))
                        .monoMeta(9, tracking: 0.1, color: Token.labelSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Token.Radius.card, style: .continuous)
                .fill(Token.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Token.Radius.card, style: .continuous)
                        .strokeBorder(Token.hairline, lineWidth: Token.hairlineWidth)
                )
        )
    }
}

/// The chain drawn as overlapping circles — the logo motif at data scale.
struct ChainCircles: View {
    let game: GameState
    let chain: Chain
    var limit: Int = 6

    var body: some View {
        HStack(spacing: -9) {
            ForEach(Array(chain.steps.prefix(limit).enumerated()), id: \.offset) { _, step in
                Circle()
                    .fill(Token.itemFill)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(game.emoji(of: step.result))
                            .font(.system(size: 14))
                    )
                    // Punch the circles apart against the surface.
                    .overlay(Circle().strokeBorder(Token.surface, lineWidth: 2))
            }
            // Terminal item is the solid ink circle.
            Circle()
                .fill(Token.mark)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(game.emoji(of: chain.terminal))
                        .font(.system(size: 17))
                )
                .overlay(Circle().strokeBorder(Token.surface, lineWidth: 2))
        }
    }
}

/// The receipt for one route, and a jumping-off point to continue it.
struct ChainDetailScreen: View {
    let game: GameState
    let chain: Chain

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                // Depth can far exceed the mock's 11, so the rail is lazy.
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(chain.steps.enumerated()), id: \.element.id) { index, step in
                        ChainStepRow(game: game, step: step, number: index + 1)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
        }
        .background(Token.surface)
        .safeAreaInset(edge: .bottom) { footer }
        .navigationBarBackButtonHidden(false)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(game.name(of: chain.terminal))
                    .font(.display(34))
                    .tracking(-34 * 0.035)
                    .foregroundStyle(Token.ink)
                    .lineLimit(2)
                Text("\(chain.itemCount) items · \(chain.combineCount) combines · \(game.untriedLeadCount(for: chain.terminal)) untried leads")
                    .monoMeta(11, tracking: 0.1)
            }
            Spacer()
            Circle()
                .fill(Token.mark)
                .frame(width: 52, height: 52)
                .overlay(
                    Text(game.emoji(of: chain.terminal))
                        .font(.system(size: 22))
                )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .hairline(.bottom)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                game.continueFrom(chain.terminal)
            } label: {
                Text("Continue this chain")
                    .font(.control(16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Capsule().fill(Token.accent))
            }
            Button {} label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17))
                    .foregroundStyle(Token.accent)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Token.grouped))
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.regularMaterial)
    }
}

struct ChainStepRow: View {
    let game: GameState
    let step: ChainStep
    let number: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // The rail: step number over a vertical hairline.
            VStack(spacing: 4) {
                Text(String(format: "%02d", number))
                    .monoMeta(9.5, tracking: 0.1)
                Rectangle()
                    .fill(Token.hairline)
                    .frame(width: Token.hairlineWidth)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 24)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    ItemPill(emoji: game.emoji(of: step.a), name: game.name(of: step.a), size: .inline)
                    Text("+").font(.mono(11)).foregroundStyle(Token.labelTertiary)
                    ItemPill(emoji: game.emoji(of: step.b), name: game.name(of: step.b), size: .inline)
                }
                HStack(spacing: 7) {
                    Text("↳").font(.system(size: 13)).foregroundStyle(Token.labelTertiary)
                    ItemPill(emoji: game.emoji(of: step.result), name: game.name(of: step.result), size: .inlineLarge)
                }
            }
            .padding(.bottom, 18)
        }
        // Steps that branch off the main line sit back.
        .opacity(step.isBranch ? 0.55 : 1)
    }
}
