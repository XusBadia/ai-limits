import Foundation

public struct ProviderID: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }

    public static let codex: Self = "codex"
    public static let claude: Self = "claude"
    public static let cursor: Self = "cursor"
    public static let copilot: Self = "copilot"
    public static let openRouter: Self = "openrouter"
}

public enum UsageWindowKind: String, Codable, Hashable, Sendable {
    case session
    case weekly
    case monthly
    case model
    case custom
}

public enum MetricUnit: String, Codable, Hashable, Sendable {
    case percent
    case credits
    case dollars
    case requests
    case tokens
}

public struct UsageWindow: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var kind: UsageWindowKind
    public var label: String
    public var used: Double
    public var limit: Double
    public var unit: MetricUnit
    public var resetsAt: Date?
    public var periodSeconds: TimeInterval?

    public init(
        id: String,
        kind: UsageWindowKind,
        label: String,
        used: Double,
        limit: Double = 100,
        unit: MetricUnit = .percent,
        resetsAt: Date? = nil,
        periodSeconds: TimeInterval? = nil
    ) {
        self.id = id
        self.kind = kind
        self.label = label
        self.used = used
        self.limit = limit
        self.unit = unit
        self.resetsAt = resetsAt
        self.periodSeconds = periodSeconds
    }

    public var usedFraction: Double {
        guard limit > 0, used.isFinite, limit.isFinite else { return 0 }
        return min(max(used / limit, 0), 1)
    }

    public var remainingPercent: Double { (1 - usedFraction) * 100 }
}

public struct BalanceMetric: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var label: String
    public var value: Double
    public var unit: MetricUnit

    public init(id: String, label: String, value: Double, unit: MetricUnit) {
        self.id = id
        self.label = label
        self.value = value
        self.unit = unit
    }
}

public struct DailyUsagePoint: Codable, Hashable, Sendable, Identifiable {
    public var date: Date
    public var tokens: Int
    public var costUSD: Double?
    public var id: Date { date }

    public init(date: Date, tokens: Int, costUSD: Double? = nil) {
        self.date = date
        self.tokens = tokens
        self.costUSD = costUSD
    }
}

public enum ProviderErrorCategory: String, Codable, Hashable, Sendable {
    case authRequired
    case permissionDenied
    case rateLimited
    case network
    case parse
    case unavailable
    case unknown
}

public struct ProviderErrorInfo: Codable, Hashable, Sendable {
    public var category: ProviderErrorCategory
    public var message: String
    public var lastSuccessfulAt: Date?

    public init(category: ProviderErrorCategory, message: String, lastSuccessfulAt: Date? = nil) {
        self.category = category
        self.message = message
        self.lastSuccessfulAt = lastSuccessfulAt
    }
}

public struct ProviderSnapshot: Codable, Hashable, Sendable, Identifiable {
    public var id: String { "\(providerID.rawValue):\(accountID)" }
    public var providerID: ProviderID
    public var accountID: String
    public var displayName: String
    public var plan: String?
    public var source: String
    public var windows: [UsageWindow]
    public var balances: [BalanceMetric]
    public var history: [DailyUsagePoint]
    public var updatedAt: Date
    public var error: ProviderErrorInfo?

    public init(
        providerID: ProviderID,
        accountID: String = "default",
        displayName: String,
        plan: String? = nil,
        source: String,
        windows: [UsageWindow] = [],
        balances: [BalanceMetric] = [],
        history: [DailyUsagePoint] = [],
        updatedAt: Date = Date(),
        error: ProviderErrorInfo? = nil
    ) {
        self.providerID = providerID
        self.accountID = accountID
        self.displayName = displayName
        self.plan = plan
        self.source = source
        self.windows = windows
        self.balances = balances
        self.history = history
        self.updatedAt = updatedAt
        self.error = error
    }
}

public struct SnapshotEnvelope: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var generatedAt: Date
    public var collectorDeviceID: String
    public var collectorVersion: String
    public var providers: [ProviderSnapshot]

    public init(
        schemaVersion: Int = currentSchemaVersion,
        generatedAt: Date = Date(),
        collectorDeviceID: String,
        collectorVersion: String,
        providers: [ProviderSnapshot]
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.collectorDeviceID = collectorDeviceID
        self.collectorVersion = collectorVersion
        self.providers = providers
    }

    public func validated() throws -> Self {
        guard schemaVersion <= Self.currentSchemaVersion else { throw SnapshotValidationError.unsupportedSchema }
        guard !collectorDeviceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SnapshotValidationError.invalidDevice
        }
        for provider in providers {
            guard provider.windows.allSatisfy({ $0.used.isFinite && $0.limit.isFinite && $0.used >= 0 && $0.limit >= 0 }) else {
                throw SnapshotValidationError.invalidMetric
            }
        }
        return self
    }
}

public enum SnapshotValidationError: Error, Equatable {
    case unsupportedSchema
    case invalidDevice
    case invalidMetric
}

public enum Freshness: String, Codable, Hashable, Sendable {
    case fresh
    case aging
    case stale

    public static func evaluate(updatedAt: Date, now: Date = Date(), freshFor: TimeInterval = 10 * 60) -> Self {
        let age = max(0, now.timeIntervalSince(updatedAt))
        if age <= freshFor { return .fresh }
        if age <= freshFor * 3 { return .aging }
        return .stale
    }
}

