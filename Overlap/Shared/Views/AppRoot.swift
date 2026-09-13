import SwiftUI

/// Initializes the four starting elements, then hands off to the platform's
/// board. Recipes live in the shared online service, not in the app bundle.
struct AppRoot<Board: View>: View {
    @ViewBuilder var board: (GameState) -> Board

    /// Held separately so SwiftUI establishes @Observable tracking on it.
    @State private var game: GameState?
    @State private var showingRuns = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let game {
                board(game)
                    .safeAreaInset(edge: .bottom) {
                        HStack {
                            Text("\(game.activeRun?.name ?? "Run") · \(game.context.text)").lineLimit(1)
                            Spacer()
                            Button("Runs and history") { showingRuns = true }
                        }
                        .padding(8)
                        .background(.regularMaterial)
                    }
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
