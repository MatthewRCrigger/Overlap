import SwiftUI

/// Initializes the four starting elements, then hands off to the platform's
/// board. Recipes live in the shared online service, not in the app bundle.
struct AppRoot<Board: View>: View {
    @ViewBuilder var board: (GameState) -> Board

    /// Held separately so SwiftUI establishes @Observable tracking on it.
    @State private var game: GameState?

    var body: some View {
        Group {
            if let game {
                board(game)
            } else {
                LaunchView()
                    .task { game = GameState(engine: ComboEngine()) }
            }
        }
    }
}
