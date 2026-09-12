import Foundation

/// Normalized identity for an element. `combos.json` has no numeric ids — the
/// display name *is* the identity, so every comparison goes through here.
/// See DATA-MODEL.md §1.
struct ItemID: Hashable, Codable, CustomStringConvertible {
    /// Trimmed, NFC-normalized, lowercased. The form used in combo keys.
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
    let name: String          // display-cased, as authored in `elements`
    let emoji: String
    let isBase: Bool
    let parents: [ItemID]?    // `discovered_from`, absent on base elements
}

struct Combo {
    let result: ItemID
    let resultName: String
    /// The pair's two inputs, resolved once at load. A self-pair stores one.
    /// Kept here so hot loops never re-parse the key.
    let inputs: [ItemID]
}

/// Counts from load-time validation. Logged, never fatal — the dictionary is
/// generated content and is expected to drift (DATA-MODEL.md §2).
struct DictionaryReport {
    var unnormalizedKeys = 0
    var resultsMissingFromElements = 0
    var danglingParents = 0
    var unreachableFromBase = 0
    var baseCount = 0
    var malformedEmoji = 0
    var comboCount = 0
    var elementCount = 0

    var summary: String {
        """
        combos.json: \(comboCount) combos, \(elementCount) elements, \
        base=\(baseCount) | unnormalized keys=\(unnormalizedKeys), \
        results missing=\(resultsMissingFromElements), dangling parents=\(danglingParents), \
        unreachable=\(unreachableFromBase), malformed emoji=\(malformedEmoji)
        """
    }
}

enum ComboEngineError: Error, LocalizedError {
    case resourceMissing(String)
    case malformedJSON(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .resourceMissing(let name):
            return "\(name) is missing from the app bundle."
        case .malformedJSON(let underlying):
            return "The dictionary could not be read: \(underlying.localizedDescription)"
        }
    }
}

/// Loads and queries the bundled dictionary. The only type that touches
/// `combos.json`; everything above it works in `ItemID`/`PairKey` terms.
final class ComboEngine: @unchecked Sendable {
    // All storage is written once during init and never mutated afterwards,
    // which is what makes sharing this across actors safe.
    private(set) var combos: [PairKey: Combo] = [:]
    private(set) var elements: [ItemID: Element] = [:]
    /// Every combo key, indexed under both of its inputs. The one index worth
    /// precomputing — it makes leads and dead-ends cheap (DATA-MODEL.md §2).
    private(set) var combosByElement: [ItemID: [PairKey]] = [:]
    private(set) var baseItems: [ItemID] = []
    private(set) var report = DictionaryReport()
    /// Stamp of the loaded dictionary, used to decide cache invalidation.
    private(set) var dataVersion: String = "unknown"

    // MARK: - Loading

    private struct RawFile: Decodable {
        struct RawCombo: Decodable { let result: String }
        struct RawElement: Decodable {
            let emoji: String?
            let base: Bool?
            let discovered_from: [String]?
        }
        let combos: [String: RawCombo]
        let elements: [String: RawElement]
    }

    init(bundle: Bundle = .main, resource: String = "combos") throws {
        guard let url = bundle.url(forResource: resource, withExtension: "json") else {
            throw ComboEngineError.resourceMissing("\(resource).json")
        }
        let data = try Data(contentsOf: url)
        let raw: RawFile
        do {
            raw = try JSONDecoder().decode(RawFile.self, from: data)
        } catch {
            throw ComboEngineError.malformedJSON(underlying: error)
        }
        dataVersion = Self.version(for: data)
        build(from: raw)
        validate()
    }

    /// Test/preview seam: build an engine from literal data.
    init(elements: [ItemID: Element], combos: [PairKey: Combo]) {
        self.elements = elements
        self.combos = combos
        baseItems = elements.filter { $0.value.isBase }.keys.sorted { $0.key < $1.key }
        indexCombos()
    }

    private static func version(for data: Data) -> String {
        // Cheap, stable stamp — size plus a hash of the bytes. Regenerating the
        // dictionary changes it; reordering whitespace does too, which is fine
        // (a false invalidation only costs one cache rebuild).
        "\(data.count)-\(String(format: "%08x", UInt32(truncatingIfNeeded: data.hashValue)))"
    }

    private func build(from raw: RawFile) {
        elements.reserveCapacity(raw.elements.count)
        for (name, e) in raw.elements {
            let id = ItemID(name)
            elements[id] = Element(
                name: name,
                emoji: Self.sanitize(emoji: e.emoji),
                isBase: e.base ?? false,
                parents: e.discovered_from?.map(ItemID.init)
            )
        }

        combos.reserveCapacity(raw.combos.count)
        for (key, c) in raw.combos {
            // Re-normalize rather than trusting the file's key form.
            let parts = key.split(separator: "+", maxSplits: 1).map(String.init)
            let pair: PairKey
            if parts.count == 2 {
                pair = PairKey(ItemID(parts[0]), ItemID(parts[1]))
            } else {
                pair = PairKey(rawKey: key)
            }
            if pair.key != key { report.unnormalizedKeys += 1 }
            let ins: [ItemID]
            if parts.count == 2 {
                let a = ItemID(parts[0]), b = ItemID(parts[1])
                ins = a == b ? [a] : [a, b]
            } else {
                ins = [ItemID(key)]
            }
            combos[pair] = Combo(result: ItemID(c.result), resultName: c.result, inputs: ins)
        }

        baseItems = elements
            .filter { $0.value.isBase }
            .sorted { Self.baseOrder($0.value.name) < Self.baseOrder($1.value.name) }
            .map(\.key)

        indexCombos()
    }

    /// Water, Fire, Wind, Earth — the order the design shows them in.
    private static func baseOrder(_ name: String) -> Int {
        ["Water": 0, "Fire": 1, "Wind": 2, "Earth": 3][name] ?? 99
    }

    private func indexCombos() {
        combosByElement.removeAll(keepingCapacity: true)
        combosByElement.reserveCapacity(elements.count)
        for (pair, combo) in combos {
            for input in combo.inputs {
                combosByElement[input, default: []].append(pair)
            }
        }
    }

    /// The two inputs of a pair. Self-pairs collapse to one entry so a
    /// `water+water` recipe isn't double-counted as two leads.
    /// Prefer this instance method — it reads the stored inputs instead of
    /// re-parsing the key.
    func inputs(of pair: PairKey) -> [ItemID] {
        if let stored = combos[pair]?.inputs { return stored }
        return Self.parseInputs(of: pair)
    }

    /// Fallback for pairs absent from the dictionary (a miss still needs its
    /// inputs, e.g. to label the dead-end toast).
    static func parseInputs(of pair: PairKey) -> [ItemID] {
        let parts = pair.key.split(separator: "+", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return [ItemID(pair.key)] }
        let a = ItemID(parts[0]), b = ItemID(parts[1])
        return a == b ? [a] : [a, b]
    }

    private static func sanitize(emoji: String?) -> String {
        guard let e = emoji?.trimmingCharacters(in: .whitespacesAndNewlines),
              !e.isEmpty else { return "◇" }
        // Single grapheme expected; anything longer is malformed data. Take the
        // first cluster rather than dropping the item's mark entirely.
        return e.count == 1 ? e : String(e.prefix(1))
    }

    // MARK: - Validation (log, never crash)

    private func validate() {
        report.comboCount = combos.count
        report.elementCount = elements.count
        report.baseCount = baseItems.count

        for combo in combos.values where elements[combo.result] == nil {
            report.resultsMissingFromElements += 1
        }
        for element in elements.values {
            for parent in element.parents ?? [] where elements[parent] == nil {
                report.danglingParents += 1
            }
            if element.emoji == "◇" { report.malformedEmoji += 1 }
        }
        var scratch: [ItemID: Int] = [:]
        report.unreachableFromBase = elements.keys.count { depth(of: $0, cache: &scratch) == nil }

        print("[ComboEngine] \(report.summary)")
        if report.baseCount != 4 {
            print("[ComboEngine] warning: expected 4 base elements, found \(report.baseCount)")
        }
    }

    // MARK: - Queries

    func element(_ id: ItemID) -> Element? { elements[id] }
    func name(of id: ItemID) -> String { elements[id]?.name ?? id.key }
    func emoji(of id: ItemID) -> String { elements[id]?.emoji ?? "◇" }

    /// The result of combining two items, or nil for a dead end.
    func result(_ a: ItemID, _ b: ItemID) -> ItemID? {
        combos[PairKey(a, b)]?.result
    }

    /// Shortest number of combines from the base four. `nil` when the element
    /// is unreachable — a real condition in a sampled dictionary.
    /// Iterative walk: chains here run deep enough to make recursion unwise.
    /// The memo is caller-owned so the engine itself stays immutable.
    func depth(of id: ItemID, cache: inout [ItemID: Int]) -> Int? {
        if let cached = cache[id] { return cached }

        var stack: [ItemID] = [id]
        var onPath: Set<ItemID> = []

        while let current = stack.last {
            if cache[current] != nil { stack.removeLast(); onPath.remove(current); continue }
            guard let element = elements[current] else { stack.removeLast(); continue }

            if element.isBase {
                cache[current] = 0
                stack.removeLast(); onPath.remove(current)
                continue
            }
            guard let parents = element.parents, !parents.isEmpty else {
                stack.removeLast(); onPath.remove(current)
                continue // unreachable: stays absent from the cache
            }

            var pending: [ItemID] = []
            var deepest = -1
            var resolvable = true
            for parent in parents {
                if let d = cache[parent] {
                    deepest = max(deepest, d)
                } else if onPath.contains(parent) {
                    // Cycle in generated data — treat as unreachable.
                    resolvable = false
                } else if elements[parent] == nil {
                    resolvable = false // dangling parent
                } else {
                    pending.append(parent)
                }
            }

            if !pending.isEmpty {
                onPath.insert(current)
                stack.append(contentsOf: pending)
                continue
            }
            if resolvable && deepest >= 0 { cache[current] = deepest + 1 }
            stack.removeLast()
            onPath.remove(current)
        }
        return cache[id]
    }

    /// Combo keys involving this item. Cheap — straight index read.
    func recipes(involving id: ItemID) -> [PairKey] {
        combosByElement[id] ?? []
    }
}
