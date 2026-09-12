import SwiftUI

@main
struct OverlapTVApp: App {
    var body: some Scene {
        WindowGroup {
            AppRoot { game in
                TVCombineScreen(game: game)
            }
            .preferredColorScheme(.dark)
        }
    }
}

/// The same two picks with a remote, legible from a sofa. Dark only.
struct TVCombineScreen: View {
    let game: GameState
    @State private var animator = CombineAnimator()
    @State private var showingResetConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer()
            stage
            Spacer()
            focusRow
            legend
        }
        .padding(.horizontal, 56)
        .padding(.vertical, 44)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Token.tvSurface)
        .onChange(of: game.phase) { _, phase in
            if case .working = phase { Task { await animator.runConverge() } }
            if case .idle = phase { animator.reset() }
        }
        // Back clears the most recently filled circle before it exits the screen.
        .onExitCommand {
            if game.slotA != nil || game.slotB != nil {
                game.clearMostRecentSlot()
            }
        }
        // Same as iPhone: the match shows in place over the stage rather than
        // taking the screen over, so play stays in the one game view.
        .overlay {
            if case .reveal(let reveal) = game.phase {
                MatchToast(game: game, reveal: reveal, forceDark: true, isTV: true)
                    .transition(.opacity)
            }
        }
        .animation(Token.revealCurve, value: game.phase)
        .confirmationDialog("Reset your game?", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
            Button("Reset Progress", role: .destructive) {
                game.resetProgress()
            }
        } message: {
            Text("This permanently removes every discovery and attempted combination. You’ll start again with Water, Fire, Wind, and Earth.")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Overlap")
                    .font(.display(32))
                    .foregroundStyle(.white)
                Text("\(game.collectedCount) collected · \(game.totalUntriedLeads) untried leads")
                    .font(.mono(14))
                    .tracking(14 * 0.14)
                    .textCase(.uppercase)
                    .foregroundStyle(Color(red: 235/255, green: 235/255, blue: 245/255, opacity: 0.55))
            }
            Spacer()
            Button("Reset game") {
                showingResetConfirmation = true
            }
            .buttonStyle(.bordered)
            .tint(.red)
            Text(statusText)
                .font(.mono(17))
                .tracking(17 * 0.14)
                .textCase(.uppercase)
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .frame(height: 52)
                .background(Capsule().fill(Color.white.opacity(0.1)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        }
    }

    private var statusText: String {
        if case .working = game.phase { return "Looking…" }
        if game.slotA == nil { return "Pick item one" }
        if game.slotB == nil { return "Pick item two" }
        return "Looking…"
    }

    private var stage: some View {
        VennStage(
            left: slotContent(game.slotA),
            right: slotContent(game.slotB),
            stageSize: CGSize(width: 520, height: 250),
            overlap: 150,
            convergence: animator.convergence,
            // The dark surface inverts the blend.
            blend: .screen,
            emptyStrokeWidth: 2
        )
    }

    private func slotContent(_ id: ItemID?) -> (emoji: String, name: String)? {
        guard let id else { return nil }
        return (game.emoji(of: id), game.name(of: id))
    }

    /// A focus row of large tiles; the last one opens the full collection.
    private var focusRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 30) {
                ForEach(game.collectionNewestFirst.prefix(8), id: \.self) { id in
                    TVTile(
                        emoji: game.emoji(of: id),
                        label: game.name(of: id)
                    ) {
                        game.pick(id)
                    }
                }
                let remainder = max(0, game.collectedCount - 8)
                TVTile(emoji: "+\(remainder)", label: "All") {}
            }
            .padding(.vertical, 30)
        }
        .scrollIndicators(.hidden)
    }

    private var legend: some View {
        HStack(spacing: 26) {
            Text("◉ Select")
            Text("◎ Back clears the circle")
            Text("≡ Collection")
        }
        .font(.mono(14))
        .tracking(14 * 0.16)
        .textCase(.uppercase)
        .foregroundStyle(Color(red: 235/255, green: 235/255, blue: 245/255, opacity: 0.55))
        .padding(.top, 8)
    }
}

/// 128pt tile with the tvOS focus treatment — scale, lift, specular sheen.
/// There is no hover on tvOS; focus is the only state.
struct TVTile: View {
    let emoji: String
    let label: String
    let action: () -> Void

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: Token.Radius.tvTile, style: .continuous)
                        .fill(Color.white.opacity(0.22))
                    if isFocused {
                        RoundedRectangle(cornerRadius: Token.Radius.tvTile, style: .continuous)
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: .white.opacity(0.45), location: 0),
                                        .init(color: .clear, location: 0.46)
                                    ],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                    }
                    Text(emoji).font(.system(size: 50))
                }
                .frame(width: 128, height: 128)

                Text(label)
                    .font(isFocused ? .display(21) : .system(size: 19))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .offset(y: isFocused ? 6 : 0)
            }
            .scaleEffect(isFocused ? 1.14 : 1)
            .offset(y: isFocused ? -10 : 0)
            .opacity(isFocused ? 1 : 0.6)
            .shadow(color: .black.opacity(isFocused ? 0.6 : 0), radius: 30, y: 30)
            .animation(.easeOut(duration: 0.25), value: isFocused)
        }
        .buttonStyle(.plain)
    }
}
