import SwiftUI

struct HistoryView: View {
    let history: [HistoryPoint]
    let color: Color
    let referenceDate: Date
    var maximum: Double = 100
    var secondaryHistory: [HistoryPoint] = []
    var secondaryColor: Color = .secondary.opacity(0.5)
    var scaleLabel: String?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                grid(size: geometry.size)
                    .stroke(Color.primary.opacity(0.055), lineWidth: 0.5)
                area(history, size: geometry.size)
                    .fill(LinearGradient(colors: [color.opacity(0.12), color.opacity(0)],
                                         startPoint: .top, endPoint: .bottom))
                line(history, size: geometry.size)
                    .stroke(color, style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round))
                line(secondaryHistory, size: geometry.size)
                    .stroke(secondaryColor, style: StrokeStyle(lineWidth: 1.1, lineCap: .round,
                                                              lineJoin: .round, dash: [3, 2]))
                endpoint(history, color: color, size: geometry.size)
                endpoint(secondaryHistory, color: secondaryColor, size: geometry.size)
                if let scaleLabel {
                    Text(scaleLabel).font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.65))
                        .padding(.trailing, 2)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func point(_ sample: HistoryPoint, value: Double, size: CGSize) -> CGPoint {
        let fraction = min(max(1 + sample.date.timeIntervalSince(referenceDate) / 60, 0), 1)
        let ratio = min(max(value / max(maximum, 1), 0), 1)
        return CGPoint(x: 3 + fraction * max(size.width - 6, 0),
                       y: plotTop + (1 - ratio) * max(size.height - plotTop - 4, 0))
    }

    private var plotTop: CGFloat { scaleLabel == nil ? 3 : 10 }

    private func grid(size: CGSize) -> Path {
        Path { path in
            for ratio: CGFloat in [0.5, 1] {
                let y = plotTop + ratio * max(size.height - plotTop - 4, 0)
                path.move(to: CGPoint(x: 3, y: y))
                path.addLine(to: CGPoint(x: size.width - 3, y: y))
            }
        }
    }

    private func segments(_ samples: [HistoryPoint], size: CGSize) -> [[CGPoint]] {
        var result: [[CGPoint]] = []
        var segment: [CGPoint] = []
        var previousDate: Date?
        for sample in samples {
            if sample.value == nil || previousDate.map({ sample.date.timeIntervalSince($0) > 2.5 }) == true {
                if !segment.isEmpty { result.append(segment); segment = [] }
            }
            if let value = sample.value { segment.append(point(sample, value: value, size: size)) }
            previousDate = sample.value == nil ? nil : sample.date
        }
        if !segment.isEmpty { result.append(segment) }
        return result
    }

    private func line(_ samples: [HistoryPoint], size: CGSize) -> Path {
        Path { path in
            for segment in segments(samples, size: size) {
                guard let first = segment.first else { continue }
                path.move(to: first)
                for point in segment.dropFirst() { path.addLine(to: point) }
            }
        }
    }

    private func area(_ samples: [HistoryPoint], size: CGSize) -> Path {
        Path { path in
            for segment in segments(samples, size: size) {
                guard segment.count > 1, let first = segment.first, let last = segment.last else { continue }
                path.move(to: CGPoint(x: first.x, y: size.height - 4))
                for point in segment { path.addLine(to: point) }
                path.addLine(to: CGPoint(x: last.x, y: size.height - 4))
                path.closeSubpath()
            }
        }
    }

    @ViewBuilder private func endpoint(_ samples: [HistoryPoint], color: Color, size: CGSize) -> some View {
        if let last = samples.last, let value = last.value {
            Circle().fill(color).frame(width: 3, height: 3)
                .overlay(Circle().stroke(WeatherTheme.backgroundHighlight, lineWidth: 1))
                .position(point(last, value: value, size: size))
        }
    }
}
