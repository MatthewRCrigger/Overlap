import Foundation
import CoreGraphics

/// The entire save file. Names and keys only — everything else is recomputed at
/// launch (DATA-MODEL.md §6). Per-device local progress, no sync.
struct SaveFile: Codable {
    var collection: [String] = []      // element names, insertion-ordered
    var tried: [String] = []           // combo keys
    var board: [String: BoardPoint] = [:]  // iPad/Mac parked positions
    var dataVersion: String = ""
    /// Locally retained metadata for recipes already returned by the shared
    /// service. This keeps a player's past discoveries readable offline.
    var aiElements: [String: AIElement]?
    var aiCombos: [String: String]?

    struct AIElement: Codable {
        var name: String
        var emoji: String
    }

    struct BoardPoint: Codable {
        var x: Double
        var y: Double
        init(_ point: CGPoint) { x = point.x; y = point.y }
        var cgPoint: CGPoint { CGPoint(x: x, y: y) }
    }
}

/// Reads and writes the save file as a JSON blob in Application Support.
/// A file rather than UserDefaults, because the collection grows into the
/// thousands and this keeps it out of the defaults plist.
struct SaveStore {
    private let url: URL

    init(filename: String = "progress.json") {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = base.appendingPathComponent("Overlap", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        url = folder.appendingPathComponent(filename)
    }

    func load() -> SaveFile? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(SaveFile.self, from: data)
        } catch {
            print("[SaveStore] unreadable save, starting fresh: \(error)")
            return nil
        }
    }

    func save(_ file: SaveFile) {
        do {
            let data = try JSONEncoder().encode(file)
            try data.write(to: url, options: .atomic)
        } catch {
            print("[SaveStore] could not write save: \(error)")
        }
    }

    /// Encode and write away from the caller's actor. The save is small but the
    /// disk write blocks, and it happens after every combine.
    func saveInBackground(_ file: SaveFile) {
        let target = url
        Task.detached(priority: .utility) {
            do {
                let data = try JSONEncoder().encode(file)
                try data.write(to: target, options: .atomic)
            } catch {
                print("[SaveStore] could not write save: \(error)")
            }
        }
    }
}
