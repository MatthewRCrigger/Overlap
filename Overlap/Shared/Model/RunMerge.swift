import Foundation

enum RunMerge {
    /// Discovery UUIDs make retries idempotent. Metadata and contexts are immutable.
    static func merge(_ local: CraftRun, _ remote: CraftRun) -> CraftRun {
        guard local.id == remote.id, local.context == remote.context else { return local }
        var merged = local
        var events = Dictionary(local.discoveries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for event in remote.discoveries where event.runID == local.id && event.recipe.context == local.context {
            if events[event.id] == nil { events[event.id] = event }
        }
        merged.discoveries = events.values.sorted {
            let a = $0.discoveredAt ?? .distantPast, b = $1.discoveredAt ?? .distantPast
            return a == b ? $0.id.uuidString < $1.id.uuidString : a < b
        }
        var owned = Set(merged.save.collection.map(ItemID.init))
        for name in remote.save.collection where owned.insert(ItemID(name)).inserted { merged.save.collection.append(name) }
        var elements = merged.save.aiElements ?? [:]
        for (key, value) in remote.save.aiElements ?? [:] where elements[key] == nil { elements[key] = value }
        var combos = merged.save.aiCombos ?? [:]
        for (key, value) in remote.save.aiCombos ?? [:] where combos[key] == nil { combos[key] = value }
        for event in merged.discoveries {
            let recipe = event.recipe
            if owned.insert(recipe.result.id).inserted { merged.save.collection.append(recipe.result.name) }
            elements[recipe.result.id.key] = SaveFile.AIElement(name: recipe.result.name, emoji: recipe.result.emoji)
            if combos[recipe.pair.key] == nil { combos[recipe.pair.key] = recipe.result.id.key }
        }
        merged.save.aiElements = elements
        merged.save.aiCombos = combos
        merged.save.tried = combos.keys.sorted()
        // Board placement and the selected run are device-local preferences.
        return merged
    }
}
