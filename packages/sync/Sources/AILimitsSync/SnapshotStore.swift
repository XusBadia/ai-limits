import AILimitsCore
import Foundation

public protocol SnapshotStoring: Sendable {
    func load() async throws -> SnapshotEnvelope?
    func save(_ envelope: SnapshotEnvelope) async throws
    func delete() async throws
}

public enum SnapshotStoreError: Error, Equatable {
    case invalidData
    case containerUnavailable
}

public actor AtomicSnapshotFileStore: SnapshotStoring {
    public let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public static func appGroup(identifier: String, filename: String = "snapshot-v1.json") throws -> Self {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            throw SnapshotStoreError.containerUnavailable
        }
        return Self(fileURL: container.appendingPathComponent(filename))
    }

    public func load() async throws -> SnapshotEnvelope? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(SnapshotEnvelope.self, from: data).validated()
        } catch let error as SnapshotValidationError {
            throw error
        } catch {
            throw SnapshotStoreError.invalidData
        }
    }

    public func save(_ envelope: SnapshotEnvelope) async throws {
        let valid = try envelope.validated()
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encoder.encode(valid).write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    public func delete() async throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}

public actor MemorySnapshotStore: SnapshotStoring {
    private var value: SnapshotEnvelope?

    public init(value: SnapshotEnvelope? = nil) { self.value = value }
    public func load() async throws -> SnapshotEnvelope? { value }
    public func save(_ envelope: SnapshotEnvelope) async throws { value = try envelope.validated() }
    public func delete() async throws { value = nil }
}

