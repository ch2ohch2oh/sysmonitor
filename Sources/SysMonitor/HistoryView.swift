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
                .stroke(color, lineWidth: 1.5)
                .background(
                    Path { path in
                        let stepX = width / CGFloat(max(history.count - 1, 1))
                        
                        path.move(to: CGPoint(x: 0, y: height))
                        
                        for (index, value) in history.enumerated() {
                            let x = CGFloat(index) * stepX
                            let y = height * (1.0 - CGFloat(min(value, maxVal) / maxVal))
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.addLine(to: CGPoint(x: 0, y: height))
                        path.closeSubpath()
                    }
                    .fill(color.opacity(0.2))
                )
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }
}
