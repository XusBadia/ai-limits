import Foundation

public extension SnapshotEnvelope {
    static func sample(now: Date = Date()) -> SnapshotEnvelope {
        SnapshotEnvelope(
            generatedAt: now,
            collectorDeviceID: "sample-mac",
            collectorVersion: "0.1.0",
            providers: [
                ProviderSnapshot(
                    providerID: .codex,
                    displayName: "Codex",
                    plan: "Pro",
                    source: "codex-app-server",
                    windows: [
                        UsageWindow(id: "session", kind: .session, label: "Session", used: 38, resetsAt: now.addingTimeInterval(2.2 * 3600), periodSeconds: 5 * 3600),
                        UsageWindow(id: "weekly", kind: .weekly, label: "Weekly", used: 64, resetsAt: now.addingTimeInterval(3.4 * 86400), periodSeconds: 7 * 86400),
                    ],
                    balances: [BalanceMetric(id: "credits", label: "Credits", value: 12, unit: .credits)],
                    updatedAt: now.addingTimeInterval(-90)
                ),
                ProviderSnapshot(
                    providerID: .claude,
                    displayName: "Claude",
                    plan: "Max",
                    source: "claude-oauth",
                    windows: [
                        UsageWindow(id: "session", kind: .session, label: "Session", used: 72, resetsAt: now.addingTimeInterval(55 * 60), periodSeconds: 5 * 3600),
                        UsageWindow(id: "weekly", kind: .weekly, label: "Weekly", used: 41, resetsAt: now.addingTimeInterval(4.8 * 86400), periodSeconds: 7 * 86400),
                    ],
                    updatedAt: now.addingTimeInterval(-130)
                ),
            ]
        )
    }
}

