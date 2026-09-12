import SwiftUI

@main
struct OverlapApp: App {
    var body: some Scene {
        WindowGroup {
            AppRoot { game in
                RootTabs(game: game)
            }
        }
    }
}

/// iPhone gets the floating glass tab bar; iPad gets the drag board instead —
/// same model, different input model per the handoff.
struct RootTabs: View {
    let game: GameState
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .regular {
            NavigationStack { BoardScreen(game: game) }
        } else {
            PhoneTabs(game: game)
        }
    }
}

struct PhoneTabs: View {
    let game: GameState
    @State private var tab: Tab = .combine

    enum Tab: String, CaseIterable, Identifiable {
        case combine = "Combine"
        case collection = "Collection"
        case chains = "Chains"
        var id: String { rawValue }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            switch tab {
            case .combine:    CombineScreen(game: game)
            case .collection: CollectionScreen(game: game)
            case .chains:     ChainsScreen(game: game)
            }
            tabBar
        }
        // The match is no longer a takeover — it shows in place on the Combine
        // screen, next to the Venn that produced it, so play never leaves the
        // one game view. See `CombineScreen.matchToast`.
        .animation(Token.revealCurve, value: game.phase)
        .ignoresSafeArea(.keyboard)
    }

    /// Floating glass bar: three equal items, a dot over a label.
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { option in
                let isActive = tab == option
                Button {
                    // Leaving Combine mid-reveal would strand the phase and
                    // refuse all input on return; clear it on the way out.
                    game.recoverIfStuck()
                    tab = option
                } label: {
                    VStack(spacing: 5) {
                        Circle()
                            .fill(isActive ? Token.accent : Color(red: 60/255, green: 60/255, blue: 67/255, opacity: 0.35))
                            .frame(width: 9, height: 9)
                        Text(option.rawValue)
                            .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                            .foregroundStyle(isActive ? Token.accent : Token.labelSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 62)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Token.hairline, lineWidth: Token.hairlineWidth))
        .shadow(color: .black.opacity(0.09), radius: 3, y: 1)
        .shadow(color: .black.opacity(0.1), radius: 17, y: 12)
        .padding(.horizontal, 16)
        .padding(.bottom, 44)
    }
}
