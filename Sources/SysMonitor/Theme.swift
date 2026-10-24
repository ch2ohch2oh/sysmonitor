import SwiftUI

enum WeatherTheme {
    static let background = Color(nsColor: .controlBackgroundColor)
    static let backgroundHighlight = Color(nsColor: .windowBackgroundColor)
    static let border = Color.primary.opacity(0.08)
    static let separator = Color.primary.opacity(0.12)
    
    static let labelPrimary = Color.primary
    static let labelSecondary = Color.secondary
    static let labelTertiary = Color.secondary.opacity(0.8)
    
    // Muted semantic colors let the four resource types remain distinguishable
    // while preserving the calm, monochrome-forward visual language.
    static let cpuColor = Color(red: 0.23, green: 0.42, blue: 0.72)
    static let gpuColor = Color(red: 0.50, green: 0.34, blue: 0.68)
    static let memColor = Color(red: 0.18, green: 0.52, blue: 0.43)
    static let diskColor = Color(red: 0.74, green: 0.47, blue: 0.20)
    static let downloadColor = Color(red: 0.18, green: 0.52, blue: 0.72)
    static let uploadColor = Color(red: 0.58, green: 0.38, blue: 0.68)
    
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
