import SwiftUI

struct DetailView: View {
    @ObservedObject var viewModel: SystemUsageViewModel
    
    var body: some View {
        ZStack {
            WeatherTheme.panelBackground(cornerRadius: 14)
            VStack(spacing: 14) {
                metricCharts
                uptimeSection
            }
            .padding(14)
        }
        .frame(width: 260)
    }
    
    private var uptimeSection: some View {
        VStack(spacing: 6) {
            Divider().background(WeatherTheme.separator)
            HStack {
                Text("Uptime")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(WeatherTheme.labelTertiary)
                Spacer()
                Text(formatUptime(viewModel.metrics.uptimeSeconds))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(WeatherTheme.labelSecondary)
                    .monospacedDigit()
            }
        }
    }
    
    private var metricCharts: some View {
        VStack(spacing: 12) {
            MetricChartRow(
                title: "CPU",
                icon: "cpu",
                value: String(format: "%.0f%%", viewModel.metrics.cpuUsage),
                history: viewModel.cpuHistory,
                color: WeatherTheme.cpuColor,
                usesBar: false,
                percentValue: viewModel.metrics.cpuUsage
            )
            MetricChartRow(
                title: "GPU",
                icon: "cpu.fill",
                value: String(format: "%.0f%%", viewModel.metrics.gpuUsage),
                history: viewModel.gpuHistory,
                color: WeatherTheme.gpuColor,
                usesBar: false,
                percentValue: viewModel.metrics.gpuUsage
            )
            MetricChartRow(
                title: "RAM",
                icon: "memorychip",
                value: String(format: "%.1f/%.1f GB", viewModel.metrics.memoryUsedGB, viewModel.metrics.memoryTotalGB),
                history: viewModel.memoryHistory,
                color: WeatherTheme.memColor,
                usesBar: false,
                percentValue: memPercent()
            )
            ForEach(viewModel.metrics.disks) { disk in
                DiskUsageRow(disk: disk)
            }
        }
        .padding(.top, 6)
    }
    
    private func memPercent() -> Double {
        if viewModel.metrics.memoryTotalGB == 0 { return 0 }
        return (viewModel.metrics.memoryUsedGB / viewModel.metrics.memoryTotalGB) * 100.0
    }
    
    
    private func formatUptime(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(Int(seconds), 0)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if days > 0 {
            return String(format: "%dd %02dh %02dm", days, hours, minutes)
        }
        return String(format: "%02dh %02dm", hours, minutes)
    }
}

private struct DiskUsageRow: View {
    let disk: DiskUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "internaldrive")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(WeatherTheme.labelSecondary)
                    .frame(width: 14)
                Text(disk.name)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(WeatherTheme.labelPrimary)
                    .lineLimit(1)
                Spacer()
                Text(String(format: "%.0f/%.0f GB", disk.usedGB, disk.totalGB))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(WeatherTheme.labelPrimary)
                    .monospacedDigit()
            }
            DiskBar(value: disk.percentUsed)
                .frame(height: 12)
        }
    }
}

private struct MetricChartRow: View {
    let title: String
    let icon: String
    let value: String
    let history: [Double]
    let color: Color
    let usesBar: Bool
    let percentValue: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(WeatherTheme.labelSecondary)
                    .frame(width: 14)
                Text(title)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(WeatherTheme.labelPrimary)
                Spacer()
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(WeatherTheme.labelPrimary)
                    .monospacedDigit()
            }
            if usesBar {
                DiskBar(value: percentValue ?? 0)
                    .frame(height: 12)
            } else {
                HistoryView(history: history, color: color)
                    .frame(height: 30)
            }
        }
    }
}

private struct DiskBar: View {
    let value: Double
    
    var body: some View {
        GeometryReader { geometry in
            let ratio = min(max(value / 100.0, 0), 1)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.black.opacity(0.08))
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(WeatherTheme.labelPrimary.opacity(0.7))
                    .frame(width: geometry.size.width * ratio, height: 6)
            }
        }
    }
}
