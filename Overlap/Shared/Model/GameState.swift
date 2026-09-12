import Foundation
import CoreGraphics
import Observation

/// One step in a chain: the two inputs and what they produced.
struct ChainStep: Identifiable {
    let id = UUID()
    let a: ItemID
    let b: ItemID
    let result: ItemID
    let depth: Int
    /// Steps reached by a second path render dim; kept in the model, not pruned.
    var isBranch: Bool = false
}

/// A route from the base four out to one terminal item.
struct Chain: Identifiable {
    let id: ItemID          // the terminal element
    let terminal: ItemID
    let steps: [ChainStep]

    var combineCount: Int { steps.count }
    var itemCount: Int { steps.count + 1 }
}

/// The phase of the combine sequence. Input is refused outside `.idle`.
enum Phase: Equatable {
    case idle
    case working(PairKey)
    case reveal(Reveal)
    case deadEnd(PairKey)
}

struct Reveal: Equatable {
    let a: ItemID
    let b: ItemID
    let result: ItemID
    /// False when the item was already collected — suppresses the badge.
    let isNew: Bool
}

/// Duration of `working → reveal`. The anticipation beat, not latency cover —
/// the cache lookup is usually fast.
let combineDelay: Duration = .milliseconds(650)
/// Dead-end toast dwell.
let deadEndDwell: Duration = .milliseconds(1900)
/// Match toast dwell. The reveal is an in-place toast on every platform now,
/// not a takeover waiting on a button, so it self-clears on the same kind of
/// timer the dead end uses — a little longer, since there is more to read.
/// A tap clears it sooner.
let revealDwell: Duration = .milliseconds(2600)

/// Memo storage held outside `@Observable`. Derived values are read from view
/// bodies, so writing them must not publish a change — otherwise each render
/// invalidates the view that just rendered and SwiftUI spins.
@MainActor
final class DerivedCache {
    var leads: [ItemID: Int] = [:]
    var depths: [ItemID: Int] = [:]
    var chains: [Chain]?
    var totalLeads: Int?
    var looseEnds: Int?

    func reset() {
        leads.removeAll(keepingCapacity: true)
        chains = nil
        totalLeads = nil
        looseEnds = nil
        depths.removeAll(keepingCapacity: true)
    }
}

@MainActor
@Observable
final class GameState {
    let engine: ComboEngine

    private struct AIElement {
        let name: String
        let emoji: String
    }

    /// Discovered items, insertion-ordered — oldest first. The shelf shows the
    /// reverse ("newest first"); keeping insertion order here makes appends O(1).
    private(set) var collection: [ItemID] = []
    private(set) var collectionSet: Set<ItemID> = []
    /// Every pair attempted, hits and misses. A miss still consumes the lead.
    private(set) var tried: Set<PairKey> = []
    /// Per-device recipe metadata returned by the shared recipe service. The
    /// service is the global source of truth; this cache keeps saved discoveries
    /// readable offline after they have been made.
    private var aiElements: [ItemID: AIElement] = [:]
    private var aiCombos: [PairKey: ItemID] = [:]

    var slotA: ItemID?
    var slotB: ItemID?
    private(set) var phase: Phase = .idle

    /// iPad/Mac only — parked positions on the board.
    var boardItems: [ItemID: CGPoint] = [:]

    private let store: SaveStore
    private let fallbackClient: ComboFallbackClient
    /// The `working → reveal` delay. Cancelled only by a new combine or dismiss.
    private var resolveTask: Task<Void, Never>?
    /// Auto-clear timers (dead-end dwell, reveal failsafe). Kept separate so
    /// starting one can never cancel the resolve that started it.
    private var timerTask: Task<Void, Never>?
    /// Set when the loaded save predates the remote-recipe data model.
    private(set) var dictionaryDidChange = false

    // MARK: - Lifecycle

    init(
        engine: ComboEngine,
        store: SaveStore = SaveStore(),
        fallbackClient: ComboFallbackClient = ComboFallbackClient()
    ) {
        self.engine = engine
        self.store = store
        self.fallbackClient = fallbackClient
        restore()
    }

    private func restore() {
        guard let save = store.load() else {
            resetToBase()
            return
        }
        dictionaryDidChange = !save.dataVersion.isEmpty && save.dataVersion != engine.dataVersion

        aiElements = (save.aiElements ?? [:]).reduce(into: [:]) { out, entry in
            out[ItemID(entry.key)] = AIElement(name: entry.value.name, emoji: entry.value.emoji)
        }
        aiCombos = (save.aiCombos ?? [:]).reduce(into: [:]) { out, entry in
            out[PairKey(rawKey: entry.key)] = ItemID(entry.value)
        }

        // Saves created before the remote data model stored bundled discovery
        // names without metadata. Preserve them rather than dropping a
        // player's collection; a later recipe response replaces the ◇ marker.
        for name in save.collection {
            let id = ItemID(name)
            if engine.element(id) == nil, aiElements[id] == nil {
                aiElements[id] = AIElement(name: name, emoji: "◇")
            }
        }
        collection = save.collection.map(ItemID.init)
        collectionSet = Set(collection)
        tried = Set(save.tried.map(PairKey.init(rawKey:)))
        boardItems = save.board.reduce(into: [:]) { out, entry in
            let id = ItemID(entry.key)
            if collectionSet.contains(id) { out[id] = entry.value.cgPoint }
        }

        // Base items are always owned, even if a save predates one of them.
        for base in engine.baseItems where !collectionSet.contains(base) {
            collection.append(base)
            collectionSet.insert(base)
        }
        if collection.isEmpty { resetToBase() }
    }

    private func resetToBase() {
        collection = engine.baseItems
        collectionSet = Set(collection)
        tried = []
        boardItems = [:]
    }

    func persist() {
        var file = SaveFile()
        file.collection = collection.map(name(of:))
        file.tried = tried.map(\.key)
        file.board = boardItems.reduce(into: [:]) { out, entry in
            out[name(of: entry.key)] = SaveFile.BoardPoint(entry.value)
        }
        file.dataVersion = engine.dataVersion
        file.aiElements = aiElements.reduce(into: [:]) { out, entry in
            out[entry.key.key] = SaveFile.AIElement(name: entry.value.name, emoji: entry.value.emoji)
        }
        file.aiCombos = aiCombos.reduce(into: [:]) { out, entry in
            out[entry.key.key] = entry.value.key
        }
        // Off the main actor: this runs after every combine.
        store.saveInBackground(file)
    }

    // MARK: - Input

    /// True when the board will accept a pick or a drop.
    var acceptsInput: Bool {
        if case .idle = phase { return true }
        return false
    }

    /// Fills the first empty slot; fires the combine once both are full.
    /// Self-pairs are legal — the same item may occupy both circles.
    func pick(_ id: ItemID) {
        guard acceptsInput else { return }
        if slotA == nil {
            slotA = id
        } else if slotB == nil {
            slotB = id
        } else {
            return
        }
        if slotA != nil && slotB != nil { combine() }
    }

    /// Drag platforms drop one item onto another and combine in one gesture.
    func combine(_ a: ItemID, _ b: ItemID) {
        guard acceptsInput else { return }
        slotA = a
        slotB = b
        combine()
    }

    func clearSlot(_ side: Side) {
        guard acceptsInput else { return }
        switch side {
        case .left: slotA = nil
        case .right: slotB = nil
        }
    }

    /// tvOS Back clears the most recently filled circle.
    func clearMostRecentSlot() {
        guard acceptsInput else { return }
        if slotB != nil { slotB = nil } else { slotA = nil }
    }

    enum Side { case left, right }

    private func combine() {
        guard let a = slotA, let b = slotB else { return }
        let pair = PairKey(a, b)
        phase = .working(pair)
        // Recorded now, hit or miss — the attempt itself consumes the lead.
        tried.insert(pair)

        resolveTask?.cancel()
        timerTask?.cancel()
        resolveTask = Task { [weak self] in
            try? await Task.sleep(for: combineDelay)
            guard let self, !Task.isCancelled else { return }
            await self.resolve(pair: pair, a: a, b: b)
        }
    }

    private func resolve(pair: PairKey, a: ItemID, b: ItemID) async {
        if let result = result(a, b) {
            resolveKnown(pair: pair, a: a, b: b, result: result)
            return
        }

        guard !Task.isCancelled, case .working(pair) = phase else { return }
        guard let generated = await fallbackClient.combine(left: name(of: a), right: name(of: b)) else {
            phase = .deadEnd(pair)
            persist()
            timerTask = Task { [weak self] in
                try? await Task.sleep(for: deadEndDwell)
                guard let self, !Task.isCancelled else { return }
                if case .deadEnd = self.phase { self.dismiss() }
            }
            return
        }
        guard !Task.isCancelled, case .working(pair) = phase else { return }

        let result = ItemID(generated.name)
        aiCombos[pair] = result
        if engine.element(result) == nil {
            aiElements[result] = AIElement(name: generated.name, emoji: generated.emoji)
        }
        resolveKnown(pair: pair, a: a, b: b, result: result)
    }

    private func resolveKnown(pair: PairKey, a: ItemID, b: ItemID, result: ItemID) {
        let isNew = !collectionSet.contains(result)
        if isNew {
            collection.append(result)
            collectionSet.insert(result)
            invalidateDerived()
        }
        recordUndoPoint(pair: pair, addedResult: isNew ? result : nil)

        // Drag platforms: the result becomes a real pill on the board, landing
        // where the combine happened, so the match stays in the playfield
        // instead of taking the screen over.
        placeResultOnBoard(result, from: a, and: b)

        let outcome = Reveal(a: a, b: b, result: result, isNew: isNew)
        phase = .reveal(outcome)
        persist()

        // The match toast self-clears, the same way the dead-end toast does.
        // A phase that outlives its view refuses every tap, so the timer is
        // what guarantees input comes back whether or not the player taps.
        timerTask = Task { [weak self] in
            try? await Task.sleep(for: revealDwell)
            guard let self, !Task.isCancelled else { return }
            if case .reveal(let current) = self.phase, current == outcome {
                self.dismiss()
            }
        }
    }

    /// Puts the result on the board at the inputs' midpoint and clears the two
    /// consumed pills. Only meaningful where a board exists; on iPhone and tvOS
    /// `boardItems` is empty and this is a no-op.
    private func placeResultOnBoard(_ result: ItemID, from a: ItemID, and b: ItemID) {
        let pointA = boardItems[a]
        let pointB = boardItems[b]
        guard pointA != nil || pointB != nil else { return }

        // Self-pairs share one point; either input alone is enough to place it.
        let anchor = pointB ?? pointA!
        let landing: CGPoint
        if let pointA, let pointB, a != b {
            landing = CGPoint(x: (pointA.x + pointB.x) / 2, y: (pointA.y + pointB.y) / 2)
        } else {
            landing = anchor
        }

        // The inputs are spent by the combine; the result takes their place.
        boardItems[a] = nil
        boardItems[b] = nil
        boardItems[result] = landing
    }

    /// Recovers from a `.reveal` or `.deadEnd` that nothing dismissed. The
    /// reveal is meant to be dismissed by the player, but a phase that outlives
    /// its view refuses all input forever, which is unrecoverable without this.
    /// Cheap insurance on a state the player cannot otherwise escape.
    func recoverIfStuck() {
        switch phase {
        case .reveal, .deadEnd: dismiss()
        case .idle, .working: break
        }
    }

    /// Clears both circles and the result.
    func dismiss() {
        resolveTask?.cancel(); resolveTask = nil
        timerTask?.cancel(); timerTask = nil
        slotA = nil
        slotB = nil
        phase = .idle
    }

    /// "Use it as item one" — loads the result into the left circle.
    func continueFrom(_ id: ItemID) {
        resolveTask?.cancel(); resolveTask = nil
        timerTask?.cancel(); timerTask = nil
        phase = .idle
        slotA = id
        slotB = nil
    }

    // MARK: - Board (iPad/Mac)

    func park(_ id: ItemID, at point: CGPoint) {
        boardItems[id] = point
        persist()
    }

    /// Sweeps every parked item off the board. Nothing is lost — everything
    /// stays in the tray, this only clears the play surface.
    func clearBoard() {
        boardItems.removeAll()
        persist()
    }

    // MARK: - Undo

    /// One step of undo for the last combine, as specced for ⌘Z.
    private struct UndoEntry {
        let pair: PairKey
        let addedResult: ItemID?
        let boardBefore: [ItemID: CGPoint]
    }
    private var undoStack: [UndoEntry] = []

    var canUndo: Bool { !undoStack.isEmpty }

    func recordUndoPoint(pair: PairKey, addedResult: ItemID?) {
        undoStack.append(UndoEntry(pair: pair, addedResult: addedResult, boardBefore: boardItems))
        if undoStack.count > 20 { undoStack.removeFirst() }
    }

    func undo() {
        guard let entry = undoStack.popLast() else { return }
        tried.remove(entry.pair)
        if let added = entry.addedResult, let index = collection.lastIndex(of: added) {
            collection.remove(at: index)
            collectionSet.remove(added)
        }
        boardItems = entry.boardBefore
        invalidateDerived()
        dismiss()
        persist()
    }

    // MARK: - Derived values (never stored)

    /// Memoization, deliberately outside `@Observable` tracking. See `DerivedCache`.
    @ObservationIgnored private let cache = DerivedCache()

    private func invalidateDerived() {
        cache.reset()
    }

    var collectedCount: Int { collection.count }

    /// Newest first, as every browse surface shows it.
    var collectionNewestFirst: [ItemID] { collection.reversed() }

    /// Tray order: the base four in their canonical order, then discoveries
    /// newest-first behind them, so the starting items don't shuffle.
    var trayOrder: [ItemID] {
        let base = engine.baseItems
        let rest = collection.filter { !base.contains($0) }.reversed()
        return base + rest
    }

    /// Resolves display data from the starting elements first, then from the
    /// locally retained discovery catalog.
    func name(of id: ItemID) -> String {
        engine.element(id)?.name ?? aiElements[id]?.name ?? id.key
    }

    func emoji(of id: ItemID) -> String {
        engine.element(id)?.emoji ?? aiElements[id]?.emoji ?? "◇"
    }

    func result(_ a: ItemID, _ b: ItemID) -> ItemID? {
        aiCombos[PairKey(a, b)]
    }

    func owns(_ id: ItemID) -> Bool { collectionSet.contains(id) }

    /// Recipes involving this item whose other input is owned and which haven't
    /// been attempted. The game's only score, and its whole hint system: it says
    /// where something remains without saying what.
    func untriedLeadCount(for id: ItemID) -> Int {
        if let cached = cache.leads[id] { return cached }
        let count = collection.reduce(into: 0) { total, other in
            if !tried.contains(PairKey(id, other)) { total += 1 }
        }
        cache.leads[id] = count
        return count
    }

    /// Total untried leads across the collection. Each pair counted once.
    var totalUntriedLeads: Int {
        if let cached = cache.totalLeads { return cached }
        var count = 0
        for (index, id) in collection.enumerated() {
            for other in collection[index...] where !tried.contains(PairKey(id, other)) {
                count += 1
            }
        }
        cache.totalLeads = count
        return count
    }

    /// An owned item with no untried pair left in the current collection.
    func isDeadEnd(_ id: ItemID) -> Bool {
        untriedLeadCount(for: id) == 0
    }

    var deadEnds: [ItemID] { collection.filter(isDeadEnd) }

    func depth(of id: ItemID) -> Int? {
        func resolve(_ current: ItemID, visiting: Set<ItemID>) -> Int? {
            if let cached = cache.depths[current] { return cached }
            if engine.element(current)?.isBase == true {
                cache.depths[current] = 0
                return 0
            }
            guard !visiting.contains(current), let (a, b) = recipe(for: current),
                  let depthA = resolve(a, visiting: visiting.union([current])),
                  let depthB = resolve(b, visiting: visiting.union([current])) else {
                return nil
            }
            let resolved = max(depthA, depthB) + 1
            cache.depths[current] = resolved
            return resolved
        }
        return resolve(id, visiting: [])
    }

    /// The two items that first produced this one, when known.
    func recipe(for id: ItemID) -> (ItemID, ItemID)? {
        guard let pair = aiCombos.first(where: { $0.value == id })?.key else { return nil }
        let inputs = ComboEngine.parseInputs(of: pair)
        guard inputs.count == 2 else { return nil }
        return (inputs[0], inputs[1])
    }

    // MARK: - Chains

    /// Chains are the `discovered_from` ancestry, so this is a walk, not a search.
    var chains: [Chain] {
        if let cached = cache.chains { return cached }
        let built = buildChains()
        cache.chains = built
        return built
    }

    private func buildChains() -> [Chain] {
        // Terminals: owned, non-base, with no owned descendant.
        var hasOwnedDescendant: Set<ItemID> = []
        for id in collection {
            if let (a, b) = recipe(for: id) {
                hasOwnedDescendant.insert(a)
                hasOwnedDescendant.insert(b)
            }
        }
        let terminals = collection.filter {
            engine.element($0)?.isBase != true && !hasOwnedDescendant.contains($0)
        }

        return terminals.compactMap { terminal in
            let steps = walkAncestry(from: terminal)
            guard !steps.isEmpty else { return nil }
            return Chain(id: terminal, terminal: terminal, steps: steps)
        }
        .sorted { $0.combineCount > $1.combineCount }
    }

    /// Walks parents back to the base four, one step per combine, ordered by
    /// depth ascending — the numbered rail in the design.
    private func walkAncestry(from terminal: ItemID) -> [ChainStep] {
        var steps: [ItemID: ChainStep] = [:]
        var queue: [ItemID] = [terminal]
        var visited: Set<ItemID> = [terminal]
        /// Items reached more than once are the dim branch steps.
        var reachCount: [ItemID: Int] = [:]

        while let current = queue.popLast() {
            guard let (a, b) = recipe(for: current) else { continue }
            steps[current] = ChainStep(
                a: a, b: b, result: current,
                depth: depth(of: current) ?? 0
            )
            for parent in [a, b] {
                reachCount[parent, default: 0] += 1
                if visited.insert(parent).inserted { queue.append(parent) }
            }
        }

        return steps.values
            .map { step in
                var copy = step
                // The main line is the terminal's own path; anything reached
                // twice came in via a second route.
                copy.isBranch = step.result != terminal && (reachCount[step.result] ?? 0) > 1
                return copy
            }
            .sorted { ($0.depth, $0.result.key) < ($1.depth, $1.result.key) }
    }

    /// Owned items belonging to no chain — the "Loose ends" card.
    var looseEndCount: Int {
        if let cached = cache.looseEnds { return cached }
        var inChain: Set<ItemID> = []
        for chain in chains {
            inChain.insert(chain.terminal)
            for step in chain.steps {
                inChain.insert(step.result); inChain.insert(step.a); inChain.insert(step.b)
            }
        }
        let count = collection.count { !inChain.contains($0) }
        cache.looseEnds = count
        return count
    }
}
