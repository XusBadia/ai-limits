import AILimitsCollectors
import AILimitsCore
import Foundation
import XCTest

final class MapperTests: XCTestCase {
    func testCodexMapsMultipleLimits() throws {
        let json = #"{"rateLimits":{"limitId":"codex","primary":{"usedPercent":28,"windowDurationMins":300,"resetsAt":1800000000},"secondary":{"usedPercent":59,"windowDurationMins":10080,"resetsAt":1800500000},"credits":{"hasCredits":true,"unlimited":false,"balance":"12.5"},"planType":"pro"},"rateLimitsByLimitId":{"codex":{"limitId":"codex","primary":{"usedPercent":28,"windowDurationMins":300,"resetsAt":1800000000},"secondary":{"usedPercent":59,"windowDurationMins":10080,"resetsAt":1800500000},"credits":{"hasCredits":true,"unlimited":false,"balance":"12.5"},"planType":"pro"},"spark":{"limitId":"spark","limitName":"Spark","primary":{"usedPercent":5,"windowDurationMins":10080,"resetsAt":1800600000},"planType":"pro"}},"rateLimitResetCredits":{"availableCount":2}}"#
        let snapshot = try CodexRateLimitMapper.map(data: Data(json.utf8), now: Date(timeIntervalSince1970: 10))
        XCTAssertEqual(snapshot.windows.count, 3)
        XCTAssertEqual(snapshot.windows[0].kind, .session)
        XCTAssertEqual(snapshot.windows[1].kind, .weekly)
        XCTAssertEqual(snapshot.windows[2].kind, .model)
        XCTAssertEqual(snapshot.balances.map(\.value), [12.5, 2])
        XCTAssertEqual(snapshot.plan, "Pro")
    }

    func testCodexRejectsEmptyPayload() {
        XCTAssertThrowsError(try CodexRateLimitMapper.map(data: Data(#"{"rateLimits":{}}"#.utf8)))
    }

    func testClaudeMapsUsage() throws {
        let json = #"{"five_hour":{"utilization":72,"resets_at":"2026-08-15T14:00:00Z"},"seven_day":{"utilization":41,"resets_at":1800000000},"seven_day_sonnet":null,"extra_usage":{"is_enabled":true,"used_credits":725,"monthly_limit":2000}}"#
        let snapshot = try ClaudeUsageMapper.map(data: Data(json.utf8), plan: "max", now: Date(timeIntervalSince1970: 10))
        XCTAssertEqual(snapshot.windows.map(\.used), [72, 41])
        XCTAssertEqual(snapshot.balances.first?.value, 7.25)
        XCTAssertEqual(snapshot.plan, "Max")
    }

    func testClaudeRejectsUnknownPayload() {
        XCTAssertThrowsError(try ClaudeUsageMapper.map(data: Data(#"{"message":"no usage"}"#.utf8)))
    }
}

