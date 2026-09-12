import Foundation

/// Normalized identity for an element. Display names are the identity, so all
/// comparisons use this normalized key.
struct ItemID: Hashable, Codable, CustomStringConvertible {
    let key: String

    init(_ name: String) {
        key = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
            .lowercased()
    }

    var description: String { key }
}

/// A pair of items, order-independent. Sorting happens once, at init.
struct PairKey: Hashable, Codable, CustomStringConvertible {
    let key: String

    init(_ a: ItemID, _ b: ItemID) {
        key = [a.key, b.key].sorted().joined(separator: "+")
    }

    init(rawKey: String) { key = rawKey }

    var description: String { key }
}

struct Element {
    let name: String
    let emoji: String
    let isBase: Bool
}

/// The app intentionally holds no recipe map. It only knows the four starting
/// elements; all combinations are resolved through the shared recipe service.
final class ComboEngine: @unchecked Sendable {
    private(set) var elements: [ItemID: Element]
    private(set) var baseItems: [ItemID]
    /// Changing this makes old saves safely re-persist under the remote model.
    let dataVersion = "remote-recipes-v1"

    init() {
        let base: [(name: String, emoji: String)] = [
            ("Water", "💧"),
            ("Fire", "🔥"),
            ("Wind", "🌬️"),
            ("Earth", "🌍"),
        ]
        baseItems = base.map { ItemID($0.name) }
        elements = Dictionary(uniqueKeysWithValues: base.map {
            (ItemID($0.name), Element(name: $0.name, emoji: $0.emoji, isBase: true))
        })
    }

    func element(_ id: ItemID) -> Element? { elements[id] }
    func name(of id: ItemID) -> String { elements[id]?.name ?? id.key }
    func emoji(of id: ItemID) -> String { elements[id]?.emoji ?? "◇" }

    /// A remote recipe key still needs to be decoded locally for save recovery
    /// and player-specific discovery chains.
    static func parseInputs(of pair: PairKey) -> [ItemID] {
        let parts = pair.key.split(separator: "+", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return [ItemID(pair.key)] }
        let a = ItemID(parts[0]), b = ItemID(parts[1])
        return a == b ? [a] : [a, b]
    }
}
