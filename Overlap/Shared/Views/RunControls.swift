import SwiftUI

/// Plain functional controls; visual design and product terminology are deferred.
struct RunControls: View {
    let game: GameState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var context = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Runs") {
                    ForEach(game.runs) { run in
                        Button {
                            game.selectRun(run.id)
                        } label: {
                            Text("\(run.id == game.activeRunID ? "✓ " : "")\(run.name) · \(run.context.text)")
                        }
                    }
                }
                Section("Create run") {
                    TextField("Run name", text: $name)
                    TextField("Context (empty means none)", text: $context)
                    ForEach(CraftContext.suggestions, id: \.self) { suggestion in
                        Button(suggestion) { context = suggestion }
                    }
                    Button("Create") {
                        if game.createRun(name: name, context: context) { name = ""; context = ""; error = nil }
                        else { error = game.persistenceError ?? "Enter a name (up to 80 characters) and context (up to 256 characters, no control characters)." }
                    }
                    if let error { Text(error) }
                }
                Section("Sync") {
                    Text(game.syncStatus)
                    Button(game.isSyncing ? "Syncing…" : "Sync now") { Task { await game.synchronize() } }
                        .disabled(game.isSyncing)
                    if let error = game.persistenceError { Text(error) }
                }
                Section("Discovery history") {
                    ForEach(game.historyNewestFirst) { event in
                        VStack(alignment: .leading) {
                            Text("\(event.recipe.left.name) + \(event.recipe.right.name) → \(event.recipe.result.emoji) \(event.recipe.result.name)")
                            Text(event.recipe.context.text).font(.caption)
                            if let date = event.discoveredAt { Text(date, style: .date).font(.caption) }
                            else { Text("Imported discovery; date unknown").font(.caption) }
                        }
                    }
                }
            }
            .navigationTitle("Runs and history")
            .toolbar { Button("Done") { dismiss() } }
        }
        #if os(macOS)
        .frame(minWidth: 560, minHeight: 500)
        #endif
    }
}
