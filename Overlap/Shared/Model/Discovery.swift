import Foundation

struct CraftContext: Codable, Hashable, Sendable {
    let text: String
    var key: String { "v1:" + text.lowercased().precomposedStringWithCanonicalMapping }
    static let none = CraftContext(text: "none")
    static let suggestions = ["Minecraft", "How To Train Your Dragon"]

    init(text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
        self.text = clean.isEmpty || clean.lowercased() == "none" ? "none" : clean
    }

    var isValid: Bool {
        text.utf16.count <= 256 && !text.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }
}

struct CraftItem: Codable, Hashable, Sendable {
    let name: String
    let emoji: String
    var id: ItemID { ItemID(name) }
}

struct CraftRecipe: Codable, Sendable {
    let left: CraftItem
    let right: CraftItem
    let result: CraftItem
    let context: CraftContext
    let source: String
    let promptVersion: String
    let generatedAt: String?
    var pair: PairKey { PairKey(left.id, right.id) }
}

struct Discovery: Codable, Identifiable, Sendable {
    let id: UUID
    let runID: UUID
    let recipe: CraftRecipe
    /// Legacy saves did not record discovery dates. Never invent those dates.
    let discoveredAt: Date?
}

struct CraftRun: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let context: CraftContext
    let createdAt: Date
    var discoveries: [Discovery] = []
    var save: SaveFile
}

struct RunArchive: Codable, Sendable {
    var version = 1
    var activeRunID: UUID
    var runs: [CraftRun]
}
