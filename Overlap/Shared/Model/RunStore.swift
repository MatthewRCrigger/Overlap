import Foundation

/// Ordered, atomic writes prevent an older background save replacing newer progress.
struct RunStore: Sendable {
    let url: URL
    private static let queue = DispatchQueue(label: "com.crggr.overlap.runs")

    init(url: URL? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.url = url ?? base.appendingPathComponent("Overlap/runs.json")
    }

    func load() throws -> RunArchive? {
        try Self.queue.sync {
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let archive = try JSONDecoder().decode(RunArchive.self, from: Data(contentsOf: url))
            guard archive.version == 1, !archive.runs.isEmpty,
                  Set(archive.runs.map(\.id)).count == archive.runs.count else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return archive
        }
    }

    func save(_ archive: RunArchive) throws {
        try Self.queue.sync {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(archive)
            try data.write(to: url, options: .atomic)
        }
    }
}
