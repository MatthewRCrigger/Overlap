import SwiftUI

/// Loads the dictionary, then hands off to the platform's board.
/// The game is unplayable without the dictionary, so load failure is a blocking
/// state with a retry — no partial play.
struct AppRoot<Board: View>: View {
    @ViewBuilder var board: (GameState) -> Board

    @State private var loadState: LoadState = .loading
    /// Held separately from `loadState` so SwiftUI establishes @Observable
    /// tracking on it. As an enum payload it was untracked and the UI never
    /// redrew on phase changes.
    @State private var game: GameState?

    private enum LoadState {
        case loading
        case ready
        case failed(String)
    }

    var body: some View {
        Group {
            switch loadState {
            case .loading:
                // Matches the launch screen exactly, so the swap is invisible.
                LaunchView()
                    .task { await load() }
            case .ready:
                if let game {
                    board(game)
                }
            case .failed(let message):
                DictionaryFailureView(message: message) {
                    loadState = .loading
                }
            }
        }
    }

    private func load() async {
        // Decode off the main actor — ~1MB of JSON, and this runs under the
        // launch screen.
        let result = await Task.detached(priority: .userInitiated) { () -> Result<ComboEngine, Error> in
            do { return .success(try ComboEngine()) }
            catch { return .failure(error) }
        }.value

        switch result {
        case .success(let engine):
            game = GameState(engine: engine)
            loadState = .ready
        case .failure(let error):
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            print("[AppRoot] dictionary load failed: \(message)")
            loadState = .failed(message)
        }
    }
}

struct DictionaryFailureView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            LogoMark(diameter: 64)
            VStack(spacing: 10) {
                Text("The dictionary didn’t load")
                    .font(.display(24))
                    .foregroundStyle(Token.ink)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(Token.labelSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            Button(action: retry) {
                Text("Try again")
                    .font(.control(15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .frame(height: 44)
                    .background(Capsule().fill(Token.accent))
            }
            .buttonStyle(.plain)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Token.surface)
    }
}
