import SwiftUI

struct NetworkCard: View {
    let reading: Reading<NetworkRates>
    let downloadHistory: [HistoryPoint]
    let uploadHistory: [HistoryPoint]
    let date: Date

    private func maximum(for history: [HistoryPoint]) -> Double {
        let peak = max(history.compactMap(\.value).max() ?? 0, 1_024)
        let unit: Double = peak >= 1_073_741_824 ? 1_073_741_824 : peak >= 1_048_576 ? 1_048_576 : 1_024
        let magnitude = pow(10, floor(log10(peak / unit)))
        let step = peak / unit / magnitude
        let rounded: Double = step <= 1 ? 1 : step <= 2 ? 2 : step <= 5 ? 5 : 10
        return rounded * magnitude * unit
    }

    var body: some View {
        HStack(spacing: 12) {
            column("Download", label: "Down", icon: "arrow.down", value: reading.value?.download, history: downloadHistory)
            Rectangle().fill(Color.primary.opacity(0.07)).frame(width: 0.5, height: 38)
            column("Upload", label: "Up", icon: "arrow.up", value: reading.value?.upload, history: uploadHistory)
        }
        .modifier(MetricSurface())
    }

    private func column(_ title: String, label: String, icon: String, value: Double?, history: [HistoryPoint]) -> some View {
        let maximum = maximum(for: history)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Label(label, systemImage: icon)
                    .font(DetailTypography.label).foregroundColor(.secondary)
                Spacer(minLength: 4)
                Text(value.map(MetricFormatting.rate) ?? "—")
                    .font(DetailTypography.value).monospacedDigit().lineLimit(1).layoutPriority(1)
            }
            if value != nil || history.contains(where: { $0.value != nil }) {
                HistoryView(history: history, color: .primary.opacity(0.6), referenceDate: date, maximum: maximum)
                    .frame(height: 26)
            } else {
                Text(reading.statusText).font(DetailTypography.caption).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
            }
            Text(history.contains(where: { $0.value != nil }) ? "0–\(MetricFormatting.rate(maximum))" : " ")
                .font(DetailTypography.caption).foregroundColor(.secondary).monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value.map(MetricFormatting.rate) ?? reading.statusText)")
        .help(value == nil ? reading.explanation : "\(title) over Wi-Fi and Ethernet. History: last 60 seconds, 0–\(MetricFormatting.rate(maximum)). Each direction has its own scale. VPN tunnel counters are excluded to avoid double counting.")
    }
}
