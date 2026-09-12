import SwiftUI

@main
struct OverlapMacApp: App {
    var body: some Scene {
        // No launch screen on Mac — the app opens into the window; first run is
        // the empty board.
        WindowGroup {
            AppRoot { game in
                BoardScreen(game: game)
                    .frame(minWidth: 900, minHeight: 600)
            }
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
