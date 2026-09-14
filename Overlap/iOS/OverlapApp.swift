import SwiftUI

@main
struct OverlapApp: App {
    var body: some Scene {
        WindowGroup {
            AppRoot { game in
                // One board on every size class. The phone gets the compact
                // chrome — shelf under the board instead of a leading tray —
                // but it is the same screen, the same gesture, and the same
                // model. Collection and Chains are pushed from the shelf
                // header rather than owning tabs of their own, because a tab
                // bar over a shelf over a board is three stacked chromes.
                NavigationStack { BoardScreen(game: game) }
            }
        }
    }
}
