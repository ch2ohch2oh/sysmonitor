import SwiftUI

struct MetricSurface: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(.vertical, 6)
    }
}

struct MetricCard: View {
    let title: String
    let icon: String
    let reading: Reading<Double>
    let history: [HistoryPoint]
    let color: Color
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Label(title, systemImage: icon)
                    .font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
                Spacer(minLength: 4)
                Text(reading.value.map { MetricFormatting.percent($0) } ?? "—")
                    .font(.system(size: 15, weight: .medium)).monospacedDigit()
            }
            if reading.value != nil || history.contains(where: { $0.value != nil }) {
                HistoryView(history: history, color: color, referenceDate: date).frame(height: 26)
            } else {
                Text(reading.statusText).font(.system(size: 9))
                .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
                .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(MetricSurface())
        .help(reading.value == nil ? reading.explanation : "\(title) utilization · 0–100% · last 60 seconds")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(reading.value.map { MetricFormatting.percent($0) } ?? reading.statusText)")
    }
}
