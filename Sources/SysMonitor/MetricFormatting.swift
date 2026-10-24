import Foundation

enum MetricFormatting {
    static func percent(_ value: Double?) -> String {
        value.map { String(format: "%.0f%%", $0) } ?? "—"
    }

    static func rate(_ value: Double) -> String {
        if value < 1_024 { return String(format: "%.0f B/s", value) }
        if value < 1_048_576 { return String(format: "%.0f KiB/s", value / 1_024) }
        if value < 1_073_741_824 { return String(format: "%.1f MiB/s", value / 1_048_576) }
        return String(format: "%.1f GiB/s", value / 1_073_741_824)
    }

    static func uptime(_ seconds: TimeInterval) -> String {
        let minutes = max(Int(seconds), 0) / 60
        if minutes >= 1_440 { return String(format: "%dd %02dh %02dm", minutes / 1_440, minutes / 60 % 24, minutes % 60) }
        return String(format: "%02dh %02dm", minutes / 60, minutes % 60)
    }
}
