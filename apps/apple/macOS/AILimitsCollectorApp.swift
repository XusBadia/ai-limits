import AILimitsCollectors
import AILimitsCore
import AILimitsSync
import AppKit
import SwiftUI

@main
struct AILimitsCollectorApp: App {
    @StateObject private var model = MacCollectorModel()

    var body: some Scene {
        MenuBarExtra("AI Limits", systemImage: "gauge.with.dots.needle.67percent") {
            MacCollectorView(model: model)
                .frame(width: 390, height: 520)
                .task { await model.start() }
        }
        .menuBarExtraStyle(.window)

        Settings {
            Form {
                LabeledContent("Refresh interval", value: "5 minutes")
                LabeledContent("iCloud", value: model.syncMessage)
                Text("Provider credentials stay on this Mac.")
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(width: 420)
        }
    }
}

@MainActor
final class MacCollectorModel: ObservableObject {
    @Published var envelope: SnapshotEnvelope?
    @Published var isRefreshing = false
    @Published var syncMessage = "Waiting"

    private let coordinator = CollectorCoordinator(collectors: [CodexCollector(), ClaudeCollector()])
    private let local = SnapshotStoreFactory.local()
    private let cloud = CloudKitSnapshotTransport(containerIdentifier: SnapshotStoreFactory.cloudContainer)
    private var loop: Task<Void, Never>?

    func start() async {
        guard loop == nil else { return }
        envelope = try? await local.load()
        await refresh()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                await self?.refresh()
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let providers = await coordinator.refreshAll()
        let snapshot = SnapshotEnvelope(
            collectorDeviceID: Host.current().localizedName ?? "Mac",
            collectorVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev",
            providers: providers
        )
        do {
            try await local.save(snapshot)
            envelope = snapshot
            try await cloud.prepare()
            try await cloud.upload(snapshot)
            syncMessage = "Synced just now"
        } catch {
            envelope = snapshot
            syncMessage = "Saved locally · iCloud unavailable"
        }
    }
}

struct MacCollectorView: View {
    @ObservedObject var model: MacCollectorModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("AI Limits").font(.title2.bold())
                    Text(model.syncMessage).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { Task { await model.refresh() } } label: {
                    if model.isRefreshing { ProgressView().controlSize(.small) }
                    else { Image(systemName: "arrow.clockwise") }
                }
                .buttonStyle(.borderless)
                .disabled(model.isRefreshing)
                .help("Refresh all providers")
            }
            .padding(18)

            Divider()

            if let envelope = model.envelope {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(envelope.providers) { ProviderCard(provider: $0) }
                    }
                    .padding(14)
                }
            } else {
                ContentUnavailableView("Collecting usage", systemImage: "gauge.with.dots.needle.67percent")
            }

            Divider()
            HStack {
                SettingsLink { Label("Settings", systemImage: "gear") }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .buttonStyle(.borderless)
            .padding(14)
        }
    }
}
