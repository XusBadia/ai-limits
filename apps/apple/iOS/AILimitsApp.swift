import AILimitsCore
import AILimitsSync
import SwiftUI
import WidgetKit

@main
struct AILimitsApp: App {
    @StateObject private var model = IOSDashboardModel()

    var body: some Scene {
        WindowGroup {
            DashboardView(
                envelope: model.envelope,
                isRefreshing: model.isRefreshing,
                message: model.message,
                refresh: model.refresh
            )
            .task { await model.start() }
        }
    }
}

@MainActor
final class IOSDashboardModel: ObservableObject {
    @Published var envelope: SnapshotEnvelope?
    @Published var isRefreshing = false
    @Published var message: String?

    private let local = SnapshotStoreFactory.local()
    #if targetEnvironment(simulator)
    private let cloud: CloudKitSnapshotTransport? = nil
    #else
    private let cloud: CloudKitSnapshotTransport? = CloudKitSnapshotTransport(
        containerIdentifier: SnapshotStoreFactory.cloudContainer
    )
    #endif
    private var hasStarted = false

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        envelope = try? await local.load()
        #if targetEnvironment(simulator)
        if envelope == nil, !ProcessInfo.processInfo.arguments.contains("--empty-preview") {
            envelope = .sample()
        }
        #endif
        await refresh()
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        guard let cloud else {
            message = "Preview data — CloudKit sync runs on a signed device."
            return
        }
        do {
            try await cloud.prepare()
            if let latest = try await cloud.download() {
                envelope = latest
                try await local.save(latest)
                WidgetCenter.shared.reloadAllTimelines()
                message = nil
            } else if envelope == nil {
                message = "No Mac has published usage yet. Keep the collector open for its first refresh."
            }
        } catch {
            message = envelope == nil
                ? "iCloud is unavailable. Check that this iPhone uses the same Apple Account as your Mac."
                : "Showing the last saved data because iCloud could not refresh."
        }
    }
}
