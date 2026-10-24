import SwiftUI

struct MemoryCard: View {
    let reading: Reading<MemoryUsage>
    let swapReading: Reading<SwapUsage>
    let history: [HistoryPoint]
    let swapHistory: [HistoryPoint]
    let date: Date

    private var swapMaximum: Double {
        let peak = max(swapHistory.compactMap(\.value).max() ?? 0, 1)
        let magnitude = pow(10, floor(log10(peak)))
        let step = peak / magnitude
        let rounded: Double = step <= 1 ? 1 : step <= 2 ? 2 : step <= 5 ? 5 : 10
        return rounded * magnitude
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            column(title: "Memory", icon: "memorychip", value: reading.value.map { MetricFormatting.percent($0.percentUsed) },
                   status: reading.statusText, history: history, maximum: 100,
                   caption: reading.value.map { String(format: "%.1f / %.0f GiB", $0.usedGB, $0.totalGB) } ?? "",
                   help: reading.value == nil ? reading.explanation : "Estimated active, wired, and compressed memory. History: last 60 seconds, 0–100%.")
            MetricColumnDivider()
            column(title: "Swap", icon: "arrow.left.arrow.right", value: swapReading.value.map { String(format: "%.1f GiB", $0.usedGB) },
                   status: swapReading.statusText, history: swapHistory, maximum: swapMaximum,
                   caption: swapHistory.contains(where: { $0.value != nil }) ? String(format: "0–%.0f GiB", swapMaximum) : "",
                   help: swapReading.value == nil ? swapReading.explanation : "Disk space used for swap. History: last 60 seconds; scale adjusts independently of memory.")
        }
        .modifier(MetricSurface())
    }

    private func column(title: String, icon: String, value: String?, status: String,
                        history: [HistoryPoint], maximum: Double, caption: String, help: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Label(title, systemImage: icon)
                    .font(DetailTypography.label).foregroundColor(.secondary)
                Spacer(minLength: 4)
                Text(value ?? "—")
                    .font(DetailTypography.value).monospacedDigit()
                    .lineLimit(1).layoutPriority(1)
            }
            if value != nil || history.contains(where: { $0.value != nil }) {
                HistoryView(history: history, color: .primary.opacity(0.6), referenceDate: date, maximum: maximum)
                    .frame(height: 26)
            } else {
                Text(status).font(DetailTypography.caption).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
            }
            Text(caption.isEmpty ? " " : caption)
                .font(DetailTypography.caption).foregroundColor(.secondary).monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .help(help)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value ?? status)\(value == nil || caption.isEmpty ? "" : ", \(caption)")")
    }
}
