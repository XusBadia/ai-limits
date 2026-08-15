import AILimitsSync
import Foundation

enum SnapshotStoreFactory {
    static let appGroup = "group.me.badia.ailimits"
    static let cloudContainer = "iCloud.me.badia.ailimits"

    static func local() -> AtomicSnapshotFileStore {
        if let store = try? AtomicSnapshotFileStore.appGroup(identifier: appGroup) { return store }
        return applicationSupport()
    }

    static func applicationSupport() -> AtomicSnapshotFileStore {
        let fallback = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AI Limits", isDirectory: true)
            .appendingPathComponent("snapshot-v1.json")
        return AtomicSnapshotFileStore(fileURL: fallback)
    }
}
