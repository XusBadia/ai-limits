import AILimitsCollectors
import AILimitsCore
import Foundation

let collectors: [any UsageCollecting] = [CodexCollector(), ClaudeCollector()]
let coordinator = CollectorCoordinator(collectors: collectors)
let providers = await coordinator.refreshAll()
let envelope = SnapshotEnvelope(
    collectorDeviceID: Host.current().localizedName ?? "mac",
    collectorVersion: "0.1.0",
    providers: providers
)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
encoder.dateEncodingStrategy = .iso8601
FileHandle.standardOutput.write(try encoder.encode(envelope))
FileHandle.standardOutput.write(Data("\n".utf8))

