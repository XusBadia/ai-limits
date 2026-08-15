import AILimitsCore
import Foundation

public struct ClaudeCollector: UsageCollecting {
    public let providerID: ProviderID = .claude
    private let credentialsURL: URL
    private let session: URLSession

    public init(
        credentialsURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/.credentials.json"),
        session: URLSession = .shared
    ) {
        self.credentialsURL = credentialsURL
        self.session = session
    }

    public func isAvailable() async -> Bool { FileManager.default.fileExists(atPath: credentialsURL.path) }

    public func collect() async throws -> ProviderSnapshot {
        let data = try Data(contentsOf: credentialsURL)
        let file = try JSONDecoder().decode(ClaudeCredentialFile.self, from: data)
        var accessToken = file.claudeAiOauth.accessToken
        if let expiry = file.claudeAiOauth.expiresAt, Double(expiry) / 1000 < Date().timeIntervalSince1970 + 300 {
            accessToken = try await refresh(file.claudeAiOauth.refreshToken)
        }
        do {
            return try await fetchUsage(accessToken: accessToken, credential: file.claudeAiOauth)
        } catch CollectorError.requestFailed(401) {
            let refreshed = try await refresh(file.claudeAiOauth.refreshToken)
            return try await fetchUsage(accessToken: refreshed, credential: file.claudeAiOauth)
        }
    }

    private func refresh(_ refreshToken: String) async throws -> String {
        let url = URL(string: "https://platform.claude.com/v1/oauth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": "9d1c250a-e61b-44d9-88ed-5944d1962f5e",
            "scope": "user:profile user:inference user:sessions:claude_code user:mcp_servers user:file_upload",
        ])
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CollectorError.invalidResponse("Claude") }
        if http.statusCode == 400 || http.statusCode == 401 { throw CollectorError.notAuthenticated("Claude") }
        if http.statusCode == 429 { throw CollectorError.rateLimited(retryAfter: Self.retryAfter(http)) }
        guard (200..<300).contains(http.statusCode) else { throw CollectorError.requestFailed(http.statusCode) }
        guard let token = try? JSONDecoder().decode(ClaudeRefreshResponse.self, from: data).accessToken, !token.isEmpty else {
            throw CollectorError.invalidResponse("Claude")
        }
        return token
    }

    private func fetchUsage(accessToken: String, credential: ClaudeOAuthCredential) async throws -> ProviderSnapshot {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("claude-code/2.1.233", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CollectorError.invalidResponse("Claude") }
        if http.statusCode == 401 { throw CollectorError.requestFailed(401) }
        if http.statusCode == 403 { throw CollectorError.permissionDenied("Claude") }
        if http.statusCode == 429 { throw CollectorError.rateLimited(retryAfter: Self.retryAfter(http)) }
        guard (200..<300).contains(http.statusCode) else { throw CollectorError.requestFailed(http.statusCode) }
        return try ClaudeUsageMapper.map(data: data, credential: credential, now: Date())
    }

    private static func retryAfter(_ response: HTTPURLResponse) -> Int? {
        response.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
    }
}

struct ClaudeCredentialFile: Decodable {
    var claudeAiOauth: ClaudeOAuthCredential
}

struct ClaudeOAuthCredential: Decodable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Int?
    var subscriptionType: String?
    var rateLimitTier: String?
}

struct ClaudeRefreshResponse: Decodable {
    var accessToken: String
    enum CodingKeys: String, CodingKey { case accessToken = "access_token" }
}

public enum ClaudeUsageMapper {
    public static func map(data: Data, plan: String? = nil, now: Date = Date()) throws -> ProviderSnapshot {
        try map(data: data, credential: ClaudeOAuthCredential(accessToken: "", refreshToken: "", subscriptionType: plan), now: now)
    }

    static func map(data: Data, credential: ClaudeOAuthCredential, now: Date) throws -> ProviderSnapshot {
        guard let body = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CollectorError.invalidResponse("Claude")
        }
        var windows: [UsageWindow] = []
        append(body["five_hour"], id: "session", kind: .session, label: "Session", periodSeconds: 5 * 3600, to: &windows)
        append(body["seven_day"], id: "weekly", kind: .weekly, label: "Weekly", periodSeconds: 7 * 86400, to: &windows)
        append(body["seven_day_sonnet"], id: "sonnet", kind: .model, label: "Sonnet", periodSeconds: 7 * 86400, to: &windows)

        var balances: [BalanceMetric] = []
        if let extra = body["extra_usage"] as? [String: Any], extra["is_enabled"] as? Bool == true,
           let usedCents = number(extra["used_credits"]) {
            balances.append(BalanceMetric(id: "extra-usage", label: "Extra usage spent", value: usedCents / 100, unit: .dollars))
        }
        guard !windows.isEmpty || !balances.isEmpty else { throw CollectorError.invalidResponse("Claude") }
        let plan = formatPlan(credential.subscriptionType, tier: credential.rateLimitTier)
        return ProviderSnapshot(
            providerID: .claude,
            displayName: "Claude",
            plan: plan,
            source: "claude-oauth",
            windows: windows,
            balances: balances,
            updatedAt: now
        )
    }

    private static func append(
        _ raw: Any?, id: String, kind: UsageWindowKind, label: String, periodSeconds: TimeInterval,
        to output: inout [UsageWindow]
    ) {
        guard let object = raw as? [String: Any], let used = number(object["utilization"]) else { return }
        output.append(UsageWindow(
            id: id,
            kind: kind,
            label: label,
            used: used,
            resetsAt: date(object["resets_at"]),
            periodSeconds: periodSeconds
        ))
    }

    private static func number(_ raw: Any?) -> Double? {
        if let number = raw as? NSNumber { return number.doubleValue }
        if let text = raw as? String { return Double(text) }
        return nil
    }

    private static func date(_ raw: Any?) -> Date? {
        if let seconds = number(raw) {
            return Date(timeIntervalSince1970: abs(seconds) > 10_000_000_000 ? seconds / 1000 : seconds)
        }
        guard let text = raw as? String else { return nil }
        return ISO8601DateFormatter().date(from: text)
    }

    private static func formatPlan(_ subscription: String?, tier: String?) -> String? {
        guard let subscription, !subscription.isEmpty else { return nil }
        let base = subscription.replacingOccurrences(of: "_", with: " ").capitalized
        guard let tier, let range = tier.range(of: #"\d+x"#, options: .regularExpression) else { return base }
        return "\(base) \(tier[range])"
    }
}
