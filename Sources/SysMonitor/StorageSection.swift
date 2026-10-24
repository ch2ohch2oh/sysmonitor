import SwiftUI

struct StorageSection: View {
    let reading: Reading<[DiskUsage]>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Storage", systemImage: "internaldrive")
                    .font(DetailTypography.label).foregroundColor(.secondary)
                Spacer()
                Text("Used / total").font(DetailTypography.caption).foregroundColor(.secondary.opacity(0.8))
            }
            if let disks = reading.value {
                ForEach(disks) { disk in
                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            Text(disk.name).lineLimit(1).truncationMode(.middle)
                            Spacer(minLength: 4)
                            Text(String(format: "%.0f / %.0f GiB", disk.usedGB, disk.totalGB))
                                .font(DetailTypography.value)
                                .foregroundColor(.secondary).monospacedDigit().layoutPriority(1)
                        }.font(DetailTypography.body)
                        GeometryReader { geometry in
                            Capsule().fill(Color.primary.opacity(0.06))
                                .overlay(alignment: .leading) {
                                    Capsule().fill(Color.primary.opacity(0.28))
                                        .frame(width: geometry.size.width * min(max(disk.percentUsed / 100, 0), 1))
                                }
                        }.frame(height: 3)
                    }
                    .help("\(disk.name): \(Int(disk.percentUsed))% used. Disk readings refresh every 15 seconds.")
                    .accessibilityElement(children: .combine)
                }
            } else {
                Text(reading.statusText).font(DetailTypography.caption).foregroundColor(.secondary).help(reading.explanation)
            }
        }
        .modifier(MetricSurface())
    }
}
