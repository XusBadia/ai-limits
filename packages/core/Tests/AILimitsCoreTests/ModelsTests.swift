import Foundation
import XCTest
@testable import AILimitsCore

final class ModelsTests: XCTestCase {
    func testPercentageIsClamped() {
        XCTAssertEqual(UsageWindow(id: "x", kind: .custom, label: "X", used: 120).usedFraction, 1)
        XCTAssertEqual(UsageWindow(id: "x", kind: .custom, label: "X", used: -4).usedFraction, 0)
    }

    func testZeroLimitIsSafe() {
        XCTAssertEqual(UsageWindow(id: "x", kind: .custom, label: "X", used: 1, limit: 0).usedFraction, 0)
    }

    func testRemainingPercentIsDerived() {
        XCTAssertEqual(UsageWindow(id: "x", kind: .weekly, label: "Weekly", used: 25).remainingPercent, 75)
    }

    func testFreshnessTransitions() {
        let now = Date(timeIntervalSince1970: 10_000)
        XCTAssertEqual(Freshness.evaluate(updatedAt: now.addingTimeInterval(-60), now: now, freshFor: 100), .fresh)
        XCTAssertEqual(Freshness.evaluate(updatedAt: now.addingTimeInterval(-150), now: now, freshFor: 100), .aging)
        XCTAssertEqual(Freshness.evaluate(updatedAt: now.addingTimeInterval(-400), now: now, freshFor: 100), .stale)
    }

    func testFutureTimestampIsFresh() {
        let now = Date(timeIntervalSince1970: 10_000)
        XCTAssertEqual(Freshness.evaluate(updatedAt: now.addingTimeInterval(10), now: now), .fresh)
    }

    func testEnvelopeRoundTrips() throws {
        let value = SnapshotEnvelope.sample(now: Date(timeIntervalSince1970: 1_700_000_000))
        let data = try JSONEncoder().encode(value)
        XCTAssertEqual(try JSONDecoder().decode(SnapshotEnvelope.self, from: data), value)
    }

    func testFutureSchemaIsRejected() {
        let value = SnapshotEnvelope(schemaVersion: 99, collectorDeviceID: "mac", collectorVersion: "1", providers: [])
        XCTAssertThrowsError(try value.validated()) { XCTAssertEqual($0 as? SnapshotValidationError, .unsupportedSchema) }
    }

    func testEmptyDeviceIsRejected() {
        let value = SnapshotEnvelope(collectorDeviceID: "  ", collectorVersion: "1", providers: [])
        XCTAssertThrowsError(try value.validated()) { XCTAssertEqual($0 as? SnapshotValidationError, .invalidDevice) }
    }

    func testInvalidMetricsAreRejected() {
        let provider = ProviderSnapshot(
            providerID: .codex,
            displayName: "Codex",
            source: "test",
            windows: [UsageWindow(id: "bad", kind: .custom, label: "Bad", used: .infinity)]
        )
        let value = SnapshotEnvelope(collectorDeviceID: "mac", collectorVersion: "1", providers: [provider])
        XCTAssertThrowsError(try value.validated()) { XCTAssertEqual($0 as? SnapshotValidationError, .invalidMetric) }
    }

    func testProviderIdentityIsStable() {
        let provider = ProviderSnapshot(providerID: .claude, accountID: "abc", displayName: "Claude", source: "test")
        XCTAssertEqual(provider.id, "claude:abc")
    }
}

