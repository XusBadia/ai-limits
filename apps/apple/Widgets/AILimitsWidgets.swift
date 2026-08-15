import AILimitsCore
import AILimitsSync
import SwiftUI
import WidgetKit

struct LimitsEntry: TimelineEntry {
    let date: Date
    let provider: ProviderSnapshot?
}

struct LimitsProvider: TimelineProvider {
    func placeholder(in context: Context) -> LimitsEntry {
        LimitsEntry(date: Date(), provider: SnapshotEnvelope.sample().providers.first)
    }

    func getSnapshot(in context: Context, completion: @escaping (LimitsEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping @Sendable (Timeline<LimitsEntry>) -> Void
    ) {
        Task {
            let store = try? AtomicSnapshotFileStore.appGroup(identifier: "group.me.badia.ailimits")
            let envelope: SnapshotEnvelope?
            if let store { envelope = try? await store.load() } else { envelope = nil }
            let provider = envelope?.providers.max { lhs, rhs in
                (lhs.windows.map(\.usedFraction).max() ?? 0) < (rhs.windows.map(\.usedFraction).max() ?? 0)
            }
            let next = Date().addingTimeInterval(30 * 60)
            completion(Timeline(entries: [LimitsEntry(date: Date(), provider: provider)], policy: .after(next)))
        }
    }
}

struct LimitsWidgetView: View {
    let entry: LimitsEntry

    var body: some View {
        if let provider = entry.provider, let window = provider.windows.max(by: { $0.usedFraction < $1.usedFraction }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(provider.displayName).font(.headline)
                    Spacer()
                    Text("\(Int(window.usedFraction * 100))%")
                        .font(.title2.bold().monospacedDigit())
                }
                Text(window.label).font(.caption).foregroundStyle(.secondary)
                ProgressView(value: window.usedFraction)
                    .tint(.teal)
                if let reset = window.resetsAt {
                    Text("Resets \(reset, style: .relative)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .containerBackground(.background, for: .widget)
        } else {
            ContentUnavailableView("Open AI Limits", systemImage: "laptopcomputer.and.iphone")
                .containerBackground(.background, for: .widget)
        }
    }
}

struct AILimitsWidget: Widget {
    let kind = "AILimitsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LimitsProvider()) { entry in
            LimitsWidgetView(entry: entry)
        }
        .configurationDisplayName("AI Limits")
        .description("See the AI quota that needs your attention.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct AILimitsWidgets: WidgetBundle {
    var body: some Widget { AILimitsWidget() }
}
