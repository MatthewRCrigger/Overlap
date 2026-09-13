import CloudKit
import Foundation

/// One snapshot per device/run prevents simultaneous devices overwriting one another.
/// Assets avoid CloudKit's record-field size limit as histories grow.
@MainActor
final class CloudRunSync {
    enum SyncError: LocalizedError {
        case notConfigured, noAccount, accountChanged, invalidRecord
        var errorDescription: String? {
            switch self {
            case .notConfigured: "iCloud sync requires the CloudKit build configuration and a signed app."
            case .noAccount: "Sign in to iCloud to sync runs."
            case .accountChanged: "The iCloud account changed. Local runs were kept and were not uploaded to the new account."
            case .invalidRecord: "An iCloud run could not be decoded. Local progress was preserved."
            }
        }
    }

    static var isConfigured: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "CloudSyncEnabled") as? String)?.uppercased() == "YES"
    }

    func synchronize(_ runs: [CraftRun]) async throws -> [CraftRun] {
        guard Self.isConfigured else { throw SyncError.notConfigured }
        let container = CKContainer(identifier: "iCloud.com.crggr.overlap")
        guard try await container.accountStatus() == .available else { throw SyncError.noAccount }
        let account = try await container.userRecordID().recordName
        let defaults = UserDefaults.standard
        if let previous = defaults.string(forKey: "cloudAccount"), previous != account { throw SyncError.accountChanged }
        defaults.set(account, forKey: "cloudAccount")
        let device = defaults.string(forKey: "syncDeviceID") ?? UUID().uuidString
        defaults.set(device, forKey: "syncDeviceID")
        let db = container.privateCloudDatabase
        let zone = CKRecordZone(zoneName: "OverlapRuns")
        _ = try await db.save(zone)

        for run in runs {
            let recordID = CKRecord.ID(recordName: "\(device)-\(run.id.uuidString)", zoneID: zone.zoneID)
            let record: CKRecord
            do { record = try await db.record(for: recordID) }
            catch let error as CKError where error.code == .unknownItem {
                record = CKRecord(recordType: "OverlapRunSnapshot", recordID: recordID)
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("overlap-sync-\(UUID().uuidString).json")
            defer { try? FileManager.default.removeItem(at: url) }
            try JSONEncoder().encode(run).write(to: url, options: .atomic)
            record["payload"] = CKAsset(fileURL: url)
            _ = try await db.save(record)
        }

        // Zone changes require no dashboard query indexes and include all pages.
        var page = try await db.recordZoneChanges(inZoneWith: zone.zoneID, since: nil, resultsLimit: 100)
        var merged = Dictionary(uniqueKeysWithValues: runs.map { ($0.id, $0) })
        while true {
            for (_, result) in page.modificationResultsByID {
                let record = try result.get().record
                guard let asset = record["payload"] as? CKAsset, let url = asset.fileURL,
                      let run = try? JSONDecoder().decode(CraftRun.self, from: Data(contentsOf: url)) else { throw SyncError.invalidRecord }
                if let local = merged[run.id] { merged[run.id] = RunMerge.merge(local, run) }
                else {
                    var incoming = run
                    incoming.save.board = [:]
                    merged[run.id] = incoming
                }
            }
            guard page.moreComing else { break }
            page = try await db.recordZoneChanges(inZoneWith: zone.zoneID, since: page.changeToken, resultsLimit: 100)
        }
        return merged.values.sorted { $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt }
    }
}
