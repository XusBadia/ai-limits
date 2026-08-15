import AILimitsCore
import AILimitsSync
import Foundation
import XCTest

final class SnapshotStoreTests: XCTestCase {
    func testMissingSnapshotReturnsNil() async throws {
        let store = AtomicSnapshotFileStore(fileURL: temporaryURL())
        let value = try await store.load()
        XCTAssertNil(value)
    }

    func testRoundTrip() async throws {
        let store = AtomicSnapshotFileStore(fileURL: temporaryURL())
        let expected = SnapshotEnvelope.sample(now: Date(timeIntervalSince1970: 1_700_000_000))
        try await store.save(expected)
        let loaded = try await store.load()
        XCTAssertEqual(loaded, expected)
    }

    func testInvalidFileIsRejected() async throws {
        let url = temporaryURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: url)
        let store = AtomicSnapshotFileStore(fileURL: url)
        do {
            _ = try await store.load()
            XCTFail("Expected invalid data")
        } catch {
            XCTAssertEqual(error as? SnapshotStoreError, .invalidData)
        }
    }

    func testDeleteIsIdempotent() async throws {
        let store = AtomicSnapshotFileStore(fileURL: temporaryURL())
        try await store.delete()
        try await store.save(.sample())
        try await store.delete()
        try await store.delete()
        let value = try await store.load()
        XCTAssertNil(value)
    }

    func testMemoryStoreReplacesValue() async throws {
        let store = MemorySnapshotStore()
        let first = SnapshotEnvelope.sample(now: Date(timeIntervalSince1970: 1))
        let second = SnapshotEnvelope.sample(now: Date(timeIntervalSince1970: 2))
        try await store.save(first)
        try await store.save(second)
        let value = try await store.load()
        XCTAssertEqual(value, second)
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ai-limits-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("snapshot.json")
    }
}

