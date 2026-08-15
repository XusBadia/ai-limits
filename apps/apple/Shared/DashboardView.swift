import AILimitsCore
import SwiftUI

struct DashboardView: View {
    let envelope: SnapshotEnvelope?
    let isRefreshing: Bool
    let message: String?
    let refresh: () async -> Void

    var body: some View {
        NavigationStack {
            Group {
                if let envelope, !envelope.providers.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            freshnessHeader(envelope)
                            ForEach(sorted(envelope.providers)) { provider in
                                NavigationLink(value: provider) {
                                    ProviderCard(provider: provider)
                                }
                                .buttonStyle(.plain)
                            }
                            privacyFooter
                        }
                        .padding(16)
                    }
                    .refreshable { await refresh() }
                } else {
                    ContentUnavailableView {
                        Label("Connect your Mac", systemImage: "laptopcomputer.and.iphone")
                    } description: {
                        Text(message ?? "Open AI Limits Collector on your Mac. Your usage will appear here through your private iCloud account.")
                    } actions: {
                        Button("Check again") { Task { await refresh() } }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .background(Color.primary.opacity(0.035))
            .navigationTitle("AI Limits")
            .navigationDestination(for: ProviderSnapshot.self) { ProviderDetailView(provider: $0) }
            .toolbar {
                if isRefreshing { ToolbarItem(placement: .automatic) { ProgressView() } }
            }
        }
    }

    private func freshnessHeader(_ envelope: SnapshotEnvelope) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Your AI capacity")
                    .font(.title2.bold())
                Text("Before it runs out")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(envelope.generatedAt, style: .relative)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityLabel("Updated \(envelope.generatedAt.formatted(.relative(presentation: .named)))")
        }
        .padding(.vertical, 8)
    }

    private var privacyFooter: some View {
        Label("Credentials stay on your Mac", systemImage: "lock.shield")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.vertical, 16)
    }

    private func sorted(_ providers: [ProviderSnapshot]) -> [ProviderSnapshot] {
        providers.sorted { lhs, rhs in
            urgency(lhs) > urgency(rhs)
        }
    }

    private func urgency(_ provider: ProviderSnapshot) -> Double {
        provider.windows.map(\.usedFraction).max() ?? (provider.error == nil ? 0 : -1)
    }
}

struct ProviderCard: View {
    let provider: ProviderSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Circle()
                    .fill(Brand.accent(for: provider.providerID))
                    .frame(width: 10, height: 10)
                Text(provider.displayName)
                    .font(.headline)
                if let plan = provider.plan {
                    Text(plan.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }

            if let error = provider.error {
                Label(error.message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            ForEach(provider.windows.prefix(3)) { window in
                UsageRow(window: window, accent: Brand.accent(for: provider.providerID))
            }

            if provider.windows.isEmpty, provider.error == nil {
                Text("No quota data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

struct UsageRow: View {
    let window: UsageWindow
    let accent: Color

    var body: some View {
        VStack(spacing: 7) {
            HStack {
                Text(window.label)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(Int(window.usedFraction * 100))% used")
                    .font(.subheadline.monospacedDigit())
            }
            ProgressView(value: window.usedFraction)
                .tint(accent)
                .accessibilityLabel(window.label)
                .accessibilityValue("\(Int(window.usedFraction * 100)) percent used")
            if let reset = window.resetsAt {
                HStack {
                    Spacer()
                    Text("Resets \(reset, style: .relative)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ProviderDetailView: View {
    let provider: ProviderSnapshot

    var body: some View {
        List {
            Section("Limits") {
                ForEach(provider.windows) { window in
                    UsageRow(window: window, accent: Brand.accent(for: provider.providerID))
                        .padding(.vertical, 6)
                }
            }
            if !provider.balances.isEmpty {
                Section("Balances") {
                    ForEach(provider.balances) { balance in
                        LabeledContent(balance.label, value: formatted(balance))
                    }
                }
            }
            Section("Freshness") {
                LabeledContent("Updated", value: provider.updatedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Source", value: provider.source)
                LabeledContent("Status", value: Freshness.evaluate(updatedAt: provider.updatedAt).rawValue.capitalized)
            }
        }
        .navigationTitle(provider.displayName)
    }

    private func formatted(_ metric: BalanceMetric) -> String {
        switch metric.unit {
        case .dollars: metric.value.formatted(.currency(code: "USD"))
        default: metric.value.formatted(.number.precision(.fractionLength(0...2)))
        }
    }
}
