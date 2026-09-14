import SwiftUI

/// Initializes the four starting elements, then hands off to the platform's
/// board. Recipes live in the shared online service, not in the app bundle.
struct AppRoot<Board: View>: View {
    @ViewBuilder var board: (GameState) -> Board

    /// Held separately so SwiftUI establishes @Observable tracking on it.
    @State private var game: GameState?
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    /// The compact board carries run and context in its own header.
    private var boardNamesItsRun: Bool { sizeClass == .compact }
    #else
    private var boardNamesItsRun: Bool { false }
    #endif
    @State private var showingRuns = false
    @Environment(\.scenePhase) private var scenePhase

    /// The run bar is for platforms whose own chrome does not already name the
    /// run. The phone board puts run, context and counts in its header, so a
    /// second copy pinned under the shelf would be the same line twice — and
    /// an empty `safeAreaInset` still installs a container over that edge, so
    /// the modifier has to be absent rather than merely empty.
    @ViewBuilder
    private func boardWithRunBar(_ game: GameState) -> some View {
        if boardNamesItsRun {
            board(game)
        } else {
            board(game)
                .safeAreaInset(edge: .bottom) {
                    HStack {
                        Text(runLabel(game)).lineLimit(1)
                        Spacer()
                        Button("Runs and history") { showingRuns = true }
                    }
                    .padding(8)
                    .background(.regularMaterial)
                }
        }
    }

    private func runLabel(_ game: GameState) -> String {
        let run = game.activeRun?.name ?? "Run"
        return game.context.isUnset ? run : "\(run) · \(game.context.text)"
    }

    var body: some View {
        Group {
            if let game {
                boardWithRunBar(game)
                    .sheet(isPresented: $showingRuns) { RunControls(game: game) }
                    .task(id: "\(game.activeRunID)-\(game.discoveries.count)") {
                        guard CloudRunSync.isConfigured else { return }
                        do { try await Task.sleep(for: .seconds(3)) } catch { return }
                        await game.synchronize()
                    }
                    .onChange(of: scenePhase) { _, phase in
                        if phase == .active, CloudRunSync.isConfigured { Task { await game.synchronize() } }
                        if phase == .background { game.persist() }
                    }
                    .alert("Combination unavailable", isPresented: Binding(
                        get: { game.combinationFailure != nil },
                        set: { if !$0 { game.combinationFailure = nil } }
                    )) {
                        Button("Retry") { game.retryCombination() }
                        Button("Cancel", role: .cancel) { game.dismiss() }
                    } message: {
                        Text(game.combinationFailure?.message ?? "Try again shortly.")
                    }
            } else {
                LaunchView()
                    .task { game = GameState.shared }
            }
        }
    }
}
