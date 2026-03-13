import SwiftUI

enum WeatherTheme {
    static let background = Color(red: 0.93, green: 0.93, blue: 0.93)
    static let backgroundHighlight = Color.white.opacity(0.9)
    static let border = Color.black.opacity(0.08)
    static let separator = Color.black.opacity(0.12)
    
    static let labelPrimary = Color.black.opacity(0.88)
    static let labelSecondary = Color.black.opacity(0.65)
    static let labelTertiary = Color.black.opacity(0.45)
    
    static let cpuColor = Color.black.opacity(0.75)
    static let gpuColor = Color.black.opacity(0.75)
    static let memColor = Color.black.opacity(0.75)
    static let diskColor = Color.black.opacity(0.75)
    
    static func panelBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [backgroundHighlight, background],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
    }
    
    static func stripBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.black.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
    }
}
