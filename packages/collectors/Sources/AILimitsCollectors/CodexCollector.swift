import AILimitsCore
import Foundation

public struct CodexCollector: UsageCollecting {
    public let providerID: ProviderID = .codex
    private let executableURL: URL?
    private let timeout: TimeInterval

    public init(executableURL: URL? = ExecutableLocator.codex(), timeout: TimeInterval = 15) {
        self.executableURL = executableURL
        self.timeout = timeout
    }

    public func isAvailable() async -> Bool { executableURL != nil }

    public func collect() async throws -> ProviderSnapshot {
        guard let executableURL else { throw CollectorError.executableMissing("Codex") }
        let data = try await Task.detached(priority: .utility) {
            let session = CodexRPCSession(executableURL: executableURL, timeout: timeout)
            return try session.readRateLimits()
        }.value
        return try CodexRateLimitMapper.map(data: data, now: Date())
    }
}

public enum ExecutableLocator {
    public static func codex(fileManager: FileManager = .default) -> URL? {
        let home = fileManager.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent(".local/bin/codex"),
            URL(fileURLWithPath: "/opt/homebrew/bin/codex"),
            URL(fileURLWithPath: "/usr/local/bin/codex"),
            URL(fileURLWithPath: "/usr/bin/codex"),
        ]
        return candidates.first { fileManager.isExecutableFile(atPath: $0.path) }
    }
}

private final class CodexRPCSession: @unchecked Sendable {
    private let executableURL: URL
    private let timeout: TimeInterval
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private let errorOutput = Pipe()
    private let lock = NSLock()
    private let finished = DispatchSemaphore(value: 0)
    private var buffer = Data()
    private var response: Data?
    private var failure: Error?
    private var sentRateLimitRequest = false

    init(executableURL: URL, timeout: TimeInterval) {
        self.executableURL = executableURL
        self.timeout = timeout
    }

    func readRateLimits() throws -> Data {
        process.executableURL = executableURL
        process.arguments = ["app-server", "--listen", "stdio://"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errorOutput
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            self?.consume(handle.availableData)
        }
        process.terminationHandler = { [weak self] process in
            guard let self, process.terminationStatus != 0 else { return }
            let stderr = String(data: self.errorOutput.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            self.complete(error: CollectorError.processFailed(stderr.isEmpty ? "Codex app-server stopped." : stderr))
        }

        try process.run()
        try write([
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": [
                "clientInfo": ["name": "ai-limits", "version": "0.1.0"],
                "capabilities": ["experimentalApi": true],
            ],
        ])

        guard finished.wait(timeout: .now() + timeout) == .success else {
            cleanup()
            throw CollectorError.timedOut
        }
        cleanup()
        if let failure { throw failure }
        guard let response else { throw CollectorError.invalidResponse("Codex") }
        return response
    }

    private func consume(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = Data(buffer[..<newline])
            buffer.removeSubrange(...newline)
            guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let id = object["id"] as? Int
            else { continue }
            if id == 1, !sentRateLimitRequest {
                sentRateLimitRequest = true
                do {
                    try write(["jsonrpc": "2.0", "method": "initialized", "params": [:]])
                    try write(["jsonrpc": "2.0", "id": 2, "method": "account/rateLimits/read", "params": [:]])
                } catch {
                    completeLocked(error: error)
                }
            } else if id == 2 {
                if let error = object["error"] as? [String: Any] {
                    completeLocked(error: CollectorError.processFailed(error["message"] as? String ?? "Codex request failed."))
                } else if let result = object["result"] {
                    do {
                        response = try JSONSerialization.data(withJSONObject: result)
                        finished.signal()
                    } catch {
                        completeLocked(error: error)
                    }
                }
            }
        }
    }

    private func write(_ object: [String: Any]) throws {
        var data = try JSONSerialization.data(withJSONObject: object)
        data.append(0x0A)
        try input.fileHandleForWriting.write(contentsOf: data)
    }

    private func complete(error: Error) {
        lock.lock()
        defer { lock.unlock() }
        completeLocked(error: error)
    }

    private func completeLocked(error: Error) {
        guard failure == nil, response == nil else { return }
        failure = error
        finished.signal()
    }

    private func cleanup() {
        output.fileHandleForReading.readabilityHandler = nil
        try? input.fileHandleForWriting.close()
        if process.isRunning { process.terminate() }
    }
}

struct CodexRateLimitResponse: Decodable {
    var rateLimits: CodexRateLimitSnapshot
    var rateLimitsByLimitId: [String: CodexRateLimitSnapshot]?
    var rateLimitResetCredits: CodexResetCredits?
}

struct CodexRateLimitSnapshot: Decodable {
    var limitId: String?
    var limitName: String?
    var primary: CodexRateLimitWindow?
    var secondary: CodexRateLimitWindow?
    var credits: CodexCredits?
    var planType: String?
}

struct CodexRateLimitWindow: Decodable {
    var usedPercent: Int
    var windowDurationMins: Int?
    var resetsAt: Int?
}

struct CodexCredits: Decodable {
    var hasCredits: Bool?
    var unlimited: Bool?
    var balance: String?
}

struct CodexResetCredits: Decodable { var availableCount: Int }

public enum CodexRateLimitMapper {
    public static func map(data: Data, now: Date = Date()) throws -> ProviderSnapshot {
        let decoder = JSONDecoder()
        guard let response = try? decoder.decode(CodexRateLimitResponse.self, from: data) else {
            throw CollectorError.invalidResponse("Codex")
        }
        let snapshots = response.rateLimitsByLimitId ?? [response.rateLimits.limitId ?? "codex": response.rateLimits]
        let ordered = snapshots.sorted { lhs, rhs in
            if lhs.key == "codex" { return true }
            if rhs.key == "codex" { return false }
            return lhs.key < rhs.key
        }
        var windows: [UsageWindow] = []
        var balances: [BalanceMetric] = []
        var plan: String?

        for (limitID, snapshot) in ordered {
            plan = plan ?? snapshot.planType.map(formatPlan)
            append(snapshot.primary, position: "primary", limitID: limitID, limitName: snapshot.limitName, to: &windows)
            append(snapshot.secondary, position: "secondary", limitID: limitID, limitName: snapshot.limitName, to: &windows)
            if limitID == "codex", let credits = snapshot.credits,
               let value = Double(credits.balance ?? ""), credits.hasCredits == true || value > 0 {
                balances.append(BalanceMetric(id: "credits", label: "Credits", value: value, unit: .credits))
            }
        }
        if let resetCredits = response.rateLimitResetCredits, resetCredits.availableCount > 0 {
            balances.append(BalanceMetric(id: "reset-credits", label: "Limit resets", value: Double(resetCredits.availableCount), unit: .credits))
        }
        guard !windows.isEmpty || !balances.isEmpty else { throw CollectorError.invalidResponse("Codex") }
        return ProviderSnapshot(
            providerID: .codex,
            displayName: "Codex",
            plan: plan,
            source: "codex-app-server",
            windows: windows,
            balances: balances,
            updatedAt: now
        )
    }

    private static func append(
        _ window: CodexRateLimitWindow?,
        position: String,
        limitID: String,
        limitName: String?,
        to output: inout [UsageWindow]
    ) {
        guard let window else { return }
        let duration = window.windowDurationMins
        let kind: UsageWindowKind
        let baseLabel: String
        if let duration, duration <= 360 {
            kind = .session
            baseLabel = "Session"
        } else if let duration, duration >= 6 * 24 * 60 {
            kind = .weekly
            baseLabel = "Weekly"
        } else {
            kind = .custom
            baseLabel = position.capitalized
        }
        let label = limitID == "codex" ? baseLabel : "\(limitName ?? limitID) · \(baseLabel)"
        output.append(UsageWindow(
            id: "\(limitID).\(position)",
            kind: limitID == "codex" ? kind : .model,
            label: label,
            used: Double(window.usedPercent),
            resetsAt: window.resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            periodSeconds: duration.map { TimeInterval($0 * 60) }
        ))
    }

    private static func formatPlan(_ raw: String) -> String {
        if raw == "prolite" { return "Pro Lite" }
        return raw.split(separator: "_").map { $0.capitalized }.joined(separator: " ")
    }
}
