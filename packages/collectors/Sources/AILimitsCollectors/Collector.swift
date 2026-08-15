import AILimitsCore
import Foundation

public protocol UsageCollecting: Sendable {
    var providerID: ProviderID { get }
    func isAvailable() async -> Bool
    func collect() async throws -> ProviderSnapshot
}

public enum CollectorError: Error, LocalizedError, Equatable {
    case executableMissing(String)
    case notAuthenticated(String)
    case permissionDenied(String)
    case rateLimited(retryAfter: Int?)
    case invalidResponse(String)
    case timedOut
    case requestFailed(Int)
    case processFailed(String)

    public var errorDescription: String? {
        switch self {
        case .executableMissing(let name): "\(name) is not installed."
        case .notAuthenticated(let provider): "Sign in to \(provider) on this Mac."
        case .permissionDenied(let provider): "\(provider) did not grant access to usage limits."
        case .rateLimited(let seconds): seconds.map { "Rate limited. Retry in about \($0) seconds." } ?? "Rate limited. Try again later."
        case .invalidResponse(let provider): "\(provider) returned an unsupported response."
        case .timedOut: "The provider did not respond in time."
        case .requestFailed(let status): "The provider request failed (HTTP \(status))."
        case .processFailed(let message): message
        }
    }

    public var category: ProviderErrorCategory {
        switch self {
        case .executableMissing: .unavailable
        case .notAuthenticated: .authRequired
        case .permissionDenied: .permissionDenied
        case .rateLimited: .rateLimited
        case .invalidResponse: .parse
        case .timedOut, .processFailed: .unavailable
        case .requestFailed: .network
        }
    }
}

public actor CollectorCoordinator {
    private let collectors: [any UsageCollecting]
    private var lastGood: [ProviderID: ProviderSnapshot] = [:]

    public init(collectors: [any UsageCollecting]) {
        self.collectors = collectors
    }

    public func refreshAll() async -> [ProviderSnapshot] {
        await withTaskGroup(of: ProviderSnapshot?.self) { group in
            for collector in collectors {
                group.addTask { [collector] in
                    guard await collector.isAvailable() else { return nil }
                    do {
                        return try await collector.collect()
                    } catch {
                        let known = error as? CollectorError
                        return ProviderSnapshot(
                            providerID: collector.providerID,
                            displayName: collector.providerID.rawValue.capitalized,
                            source: "collector",
                            error: ProviderErrorInfo(
                                category: known?.category ?? .unknown,
                                message: error.localizedDescription
                            )
                        )
                    }
                }
            }

            var output: [ProviderSnapshot] = []
            for await result in group {
                guard var snapshot = result else { continue }
                if snapshot.error == nil {
                    lastGood[snapshot.providerID] = snapshot
                } else if let cached = lastGood[snapshot.providerID] {
                    let failure = snapshot.error
                    snapshot = cached
                    snapshot.error = ProviderErrorInfo(
                        category: failure?.category ?? .unknown,
                        message: failure?.message ?? "Refresh failed.",
                        lastSuccessfulAt: cached.updatedAt
                    )
                }
                output.append(snapshot)
            }
            return output.sorted { $0.displayName < $1.displayName }
        }
    }
}

