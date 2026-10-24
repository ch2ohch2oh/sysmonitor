import SwiftUI

struct NetworkCard: View {
    let reading: Reading<NetworkRates>
    let downloadHistory: [HistoryPoint]
    let uploadHistory: [HistoryPoint]
    let date: Date

    private var maximum: Double {
        let peak = max(downloadHistory.compactMap(\.value).max() ?? 0,
                       uploadHistory.compactMap(\.value).max() ?? 0, 1_024)
        let unit: Double = peak >= 1_073_741_824 ? 1_073_741_824 : peak >= 1_048_576 ? 1_048_576 : 1_024
        let magnitude = pow(10, floor(log10(peak / unit)))
        let step = peak / unit / magnitude
        let rounded: Double = step <= 1 ? 1 : step <= 2 ? 2 : step <= 5 ? 5 : 10
        return rounded * magnitude * unit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Network", systemImage: "network")
                    .font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
                Spacer()
                Text("Wi-Fi & Ethernet").font(.system(size: 9)).foregroundColor(.secondary.opacity(0.8))
            }
            HStack(spacing: 16) {
                rate("Download", icon: "arrow.down", value: reading.value?.download, color: .primary.opacity(0.65))
                rate("Upload", icon: "arrow.up", value: reading.value?.upload, color: .secondary.opacity(0.65))
            }
            HistoryView(history: downloadHistory, color: .primary.opacity(0.65), referenceDate: date,
                        maximum: maximum, secondaryHistory: uploadHistory, secondaryColor: .secondary.opacity(0.65),
                        scaleLabel: MetricFormatting.rate(maximum))
                .frame(height: 30)
        }
        .modifier(MetricSurface())
        .help(reading.value == nil ? reading.explanation : "Download: solid line. Upload: dashed line. Shared scale adjusts to the last 60 seconds. VPN tunnel counters are excluded to avoid double counting.")
    }

    private func rate(_ title: String, icon: String, value: Double?, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).foregroundColor(color).font(.system(size: 10, weight: .medium))
            Text(value.map(MetricFormatting.rate) ?? reading.statusText)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value.map(MetricFormatting.rate) ?? reading.statusText)")
        .help(title)
    }
}
