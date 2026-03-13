import SwiftUI

struct HistoryView: View {
    let history: [Double]
    let color: Color
    
    private let maxVal: Double = 100.0
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            if history.isEmpty {
                EmptyView()
            } else {
                ZStack {
                    chartFillPath(width: width, height: height)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.35), color.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    chartLinePath(width: width, height: height)
                        .stroke(
                            color,
                            style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
                        )
                }
            }
        }
        .background(Color.black.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(WeatherTheme.border, lineWidth: 1)
        )
    }
    
    private func chartLinePath(width: CGFloat, height: CGFloat) -> Path {
        Path { path in
            let stepX = width / CGFloat(max(history.count - 1, 1))
            
            if let first = history.first {
                let y = height * (1.0 - CGFloat(min(first, maxVal) / maxVal))
                path.move(to: CGPoint(x: 0, y: y))
            }
            
            for (index, value) in history.enumerated() {
                let x = CGFloat(index) * stepX
                let y = height * (1.0 - CGFloat(min(value, maxVal) / maxVal))
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
    }
    
    private func chartFillPath(width: CGFloat, height: CGFloat) -> Path {
        Path { path in
            let stepX = width / CGFloat(max(history.count - 1, 1))
            path.move(to: CGPoint(x: 0, y: height))
            
            for (index, value) in history.enumerated() {
                let x = CGFloat(index) * stepX
                let y = height * (1.0 - CGFloat(min(value, maxVal) / maxVal))
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            path.addLine(to: CGPoint(x: width, y: height))
            path.closeSubpath()
        }
    }
}
