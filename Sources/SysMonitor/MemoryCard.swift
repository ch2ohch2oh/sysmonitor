import SwiftUI

struct MemoryCard: View {
    let reading: Reading<MemoryUsage>
    let history: [HistoryPoint]
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Memory", systemImage: "memorychip")
                    .font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
                Spacer()
                Text(reading.value.map { String(format: "%.1f / %.0f GiB", $0.usedGB, $0.totalGB) } ?? reading.statusText)
                    .font(.system(size: 12, weight: .medium)).monospacedDigit()
            }
            HistoryView(history: history, color: .primary.opacity(0.6), referenceDate: date).frame(height: 26)
            HStack {
                if let pressure = reading.value?.pressure {
                    HStack(spacing: 4) {
                        Circle().fill(pressureColor(pressure)).frame(width: 3, height: 3)
                        Text("\(pressure.rawValue) pressure")
                    }
                    .help("Memory pressure reflects how efficiently memory is serving your workloads.")
                }
                Spacer()
                if let value = reading.value { Text("\(MetricFormatting.percent(value.percentUsed)) used").monospacedDigit() }
            }
            .font(.system(size: 9)).foregroundColor(.secondary)
        }
        .modifier(MetricSurface())
        .help(reading.value == nil ? reading.explanation : "Estimated active, wired, and compressed memory. High usage alone does not mean high pressure. History: last 60 seconds, 0–100%.")
        .accessibilityElement(children: .combine)
    }

    private func pressureColor(_ pressure: MemoryPressure) -> Color {
        switch pressure {
        case .normal: return .secondary.opacity(0.6)
        case .warning: return .orange
        case .critical: return .red
        }
    }
}
