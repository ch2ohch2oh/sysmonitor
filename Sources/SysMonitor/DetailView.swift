import SwiftUI

struct DetailView: View {
    static let popupSize = CGSize(width: 300, height: 368)
    @ObservedObject var viewModel: SystemUsageViewModel
    // A nil height exposes the natural content size for the panel's sizing pass.
    var popupHeight: CGFloat? = popupSize.height
    var onSettings: () -> Void = {}
    var onAbout: () -> Void = {}
    var onActivityMonitor: () -> Void = {}
    var onQuit: () -> Void = {}

    private var snapshot: UsageSnapshot { viewModel.snapshot }
    private var metrics: UsageMetrics { snapshot.metrics }
    private var referenceDate: Date { metrics.sampledAt ?? Date() }

    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 4)
            if popupHeight == nil {
                sections
            } else {
                ScrollView { sections }
            }
            footer
        }
        .frame(width: Self.popupSize.width, height: popupHeight)
        .fixedSize(horizontal: false, vertical: popupHeight == nil)
        .background(WeatherTheme.panelBackground(cornerRadius: 12))
    }

    private var sections: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                MetricCard(title: "CPU", icon: "cpu", reading: metrics.cpu, history: snapshot.cpuHistory,
                           color: .primary.opacity(0.65), date: referenceDate)
                MetricColumnDivider()
                MetricCard(title: "GPU", icon: "square.3.layers.3d", reading: metrics.gpu, history: snapshot.gpuHistory,
                           color: .primary.opacity(0.65), date: referenceDate)
            }
            .modifier(MetricSurface())
            sectionDivider
            MemoryCard(reading: metrics.memory, swapReading: metrics.swap,
                       history: snapshot.memoryHistory, swapHistory: snapshot.swapHistory, date: referenceDate)
            sectionDivider
            NetworkCard(reading: metrics.network, downloadHistory: snapshot.downloadHistory,
                        uploadHistory: snapshot.uploadHistory, date: referenceDate)
            sectionDivider
            StorageSection(reading: metrics.disks)
        }
        .padding(.horizontal, 12)
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("System").font(DetailTypography.title)
                Text(snapshot.isStale ? "Updates paused" : "60s history")
                    .font(DetailTypography.caption).foregroundColor(snapshot.isStale ? .orange : .secondary)
                .help(metrics.sampledAt.map { "Last sample: \($0.formatted(date: .omitted, time: .standard))" } ?? "Waiting for the first sample.")
            }
            Spacer()
            Menu {
                Button("Settings…", action: onSettings).keyboardShortcut(",")
                Button("About SysMonitor", action: onAbout)
                Divider()
                Button("Quit SysMonitor", action: onQuit).keyboardShortcut("q")
            } label: {
                Image(systemName: "ellipsis.circle").font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary).accessibilityLabel("App menu")
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .help("Settings, About, and Quit")
        }
    }

    private var sectionDivider: some View {
        Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 0.5)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 0.5)
            HStack {
                Button(action: onActivityMonitor) {
                    HStack(spacing: 4) {
                        Text("Activity Monitor")
                        Image(systemName: "arrow.up.right").font(.system(size: 8, weight: .semibold))
                    }
                    .font(DetailTypography.label).foregroundColor(.secondary)
                }
                .buttonStyle(.plain).help("Open Activity Monitor to investigate resource use")
                Spacer()
                Text("Up \(MetricFormatting.uptime(metrics.uptimeSeconds))")
                    .font(DetailTypography.caption).foregroundColor(.secondary.opacity(0.8)).monospacedDigit()
                    .accessibilityLabel("Uptime \(MetricFormatting.uptime(metrics.uptimeSeconds))")
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
    }
}
