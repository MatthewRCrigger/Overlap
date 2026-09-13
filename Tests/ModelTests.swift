import XCTest
@testable import Overlap

final class ModelTests: XCTestCase {
    func testPairIdentityAndContext() {
        XCTAssertEqual(PairKey(ItemID("Fire"), ItemID("Water")), PairKey(ItemID("Water"), ItemID("Fire")))
        XCTAssertNotEqual(PairKey(ItemID("A+B"), ItemID("C")), PairKey(ItemID("A"), ItemID("B+C")))
        XCTAssertEqual(ComboEngine.parseInputs(of: PairKey(ItemID("Fire"), ItemID("Fire"))).count, 2)
        XCTAssertEqual(CraftContext(text: " NONE "), .none)
        XCTAssertEqual(CraftContext(text: " Minecraft ").key, "v1:minecraft")
        XCTAssertFalse(CraftContext(text: "line\nbreak").isValid)
    }

    @MainActor
    func testLegacyMigrationRunIsolationAndReload() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let runStore = RunStore(url: directory.appendingPathComponent("runs.json"))
        let legacy = SaveStore(url: directory.appendingPathComponent("progress.json"))
        var save = SaveFile()
        save.collection = ["Fire", "Volcano"]
        save.aiElements = ["volcano": SaveFile.AIElement(name: "Volcano", emoji: "🌋")]
        save.aiCombos = ["fire+fire": "volcano"]
        legacy.save(save)
        let game = GameState(engine: ComboEngine(), store: legacy, fallbackClient: ComboFallbackClient(endpoint: nil), runStore: runStore)
        let oldID = game.activeRunID
        XCTAssertEqual(game.discoveries.count, 1)
        XCTAssertNil(game.discoveries.first?.discoveredAt)
        XCTAssertEqual(game.recipe(for: ItemID("Volcano"))?.0, ItemID("Fire"))
        XCTAssertEqual(game.depth(of: ItemID("Volcano")), 1)
        XCTAssertTrue(game.createRun(name: "Dragons", context: "How To Train Your Dragon"))
        XCTAssertEqual(game.collection.count, 4)
        XCTAssertNil(game.result(ItemID("Fire"), ItemID("Fire")))
        XCTAssertTrue(game.discoveries.isEmpty)
        game.selectRun(oldID)
        XCTAssertEqual(game.result(ItemID("Fire"), ItemID("Fire")), ItemID("Volcano"))
        let reload = GameState(engine: ComboEngine(), store: legacy, runStore: runStore)
        XCTAssertEqual(reload.runs.count, 2)
        XCTAssertEqual(reload.activeRunID, oldID)
        XCTAssertEqual(reload.discoveries.count, 1)
    }

    @MainActor
    func testUnavailableDoesNotConsumePairAndCanRetry() async throws {
        let runStore = RunStore(url: FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)/runs.json"))
        let game = GameState(engine: ComboEngine(), store: SaveStore(url: runStore.url.deletingLastPathComponent().appendingPathComponent("progress.json")), fallbackClient: ComboFallbackClient(endpoint: nil), runStore: runStore)
        game.combine(ItemID("Fire"), ItemID("Water"))
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(game.combinationFailure, .notConfigured)
        XCTAssertTrue(game.tried.isEmpty)
        XCTAssertTrue(game.discoveries.isEmpty)
        XCTAssertTrue(game.acceptsInput)
        game.retryCombination()
        if case .working = game.phase {} else { XCTFail("Retry should start a request") }
        game.dismiss()
    }

    func testConcurrentMergeIsIdempotentAndPreservesBothDiscoveries() {
        let id = UUID()
        let recipe = CraftRecipe(left: CraftItem(name: "Fire", emoji: "🔥"), right: CraftItem(name: "Fire", emoji: "🔥"), result: CraftItem(name: "Volcano", emoji: "🌋"), context: .none, source: "ai", promptVersion: "v1", generatedAt: nil)
        let a = Discovery(id: UUID(), runID: id, recipe: recipe, discoveredAt: Date(timeIntervalSince1970: 1))
        let b = Discovery(id: UUID(), runID: id, recipe: recipe, discoveredAt: Date(timeIntervalSince1970: 2))
        var first = CraftRun(id: id, name: "Run", context: .none, createdAt: Date(), save: SaveFile())
        var second = first
        first.discoveries = [a]; second.discoveries = [b]
        let merged = RunMerge.merge(first, second)
        XCTAssertEqual(merged.discoveries.map(\.id), [a.id, b.id])
        XCTAssertEqual(RunMerge.merge(merged, second).discoveries.count, 2)
        XCTAssertEqual(merged.save.collection, ["Volcano"])
        XCTAssertEqual(RunMerge.merge(second, first).discoveries.map(\.id), [a.id, b.id])
    }

    @MainActor
    func testSuccessfulHistoryRepeatsAndSurvivesUndoAndReload() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let runStore = RunStore(url: directory.appendingPathComponent("runs.json"))
        let legacy = SaveStore(url: directory.appendingPathComponent("progress.json"))
        var save = SaveFile()
        save.collection = ["Fire", "Volcano"]
        save.aiElements = ["volcano": SaveFile.AIElement(name: "Volcano", emoji: "🌋")]
        save.aiCombos = ["fire+fire": "volcano"]
        legacy.save(save)
        let game = GameState(engine: ComboEngine(), store: legacy, runStore: runStore)
        game.combine(ItemID("Fire"), ItemID("Fire"))
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(game.discoveries.count, 2)
        XCTAssertNotNil(game.discoveries.last?.discoveredAt)
        game.undo()
        XCTAssertEqual(game.discoveries.count, 2)
        XCTAssertTrue(game.owns(ItemID("Volcano")))
        let reloaded = GameState(engine: ComboEngine(), store: legacy, runStore: runStore)
        XCTAssertEqual(reloaded.discoveries.map(\.id), game.discoveries.map(\.id))
    }

    @MainActor
    func testSwitchRunCancelsPendingResolution() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let game = GameState(engine: ComboEngine(), store: SaveStore(url: directory.appendingPathComponent("progress.json")), fallbackClient: ComboFallbackClient(endpoint: nil), runStore: RunStore(url: directory.appendingPathComponent("runs.json")))
        game.combine(ItemID("Fire"), ItemID("Fire"))
        XCTAssertTrue(game.createRun(name: "Minecraft", context: "Minecraft"))
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(game.phase, .idle)
        XCTAssertNil(game.combinationFailure)
        XCTAssertEqual(game.context.text, "Minecraft")
        XCTAssertTrue(game.discoveries.isEmpty)
    }
}
