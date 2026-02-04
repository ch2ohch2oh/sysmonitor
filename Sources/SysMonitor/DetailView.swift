import SwiftUI

struct DetailView: View {
    @ObservedObject var viewModel: SystemUsageViewModel
    @State private var showPerCore = false
    
    var body: some View {
        VStack(spacing: 12) {
            
            // CPU
            HStack {
                Image(systemName: "cpu")
                    .frame(width: 18)
                Text("CPU")
                    .frame(width: 36, alignment: .leading)
                Text(String(format: "%.0f%%", viewModel.metrics.cpuUsage))
                    .frame(alignment: .leading)
                Spacer()
            }
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .contextMenu {
                Button(action: {
                    showPerCore = false
                }) {
                    Text("Overall Usage")
                    if !showPerCore { Image(systemName: "checkmark") }
                }
                
                Button(action: {
                    showPerCore = true
                }) {
                    Text("Per-Core Usage")
                    if showPerCore { Image(systemName: "checkmark") }
                }
            }
            
            if showPerCore {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                    ForEach(0..<viewModel.perCoreHistory.count, id: \.self) { index in
                        // Assumption: E-Cores are first, then P-Cores
                        let isECore = index < viewModel.metrics.eCoreCount
                        let color: Color = isECore ? .green : .blue
                        
                        HistoryView(history: viewModel.perCoreHistory[index], color: color)
                            .frame(height: 25)
                    }
                }
            } else {
                HistoryView(history: viewModel.cpuHistory, color: .blue)
                    .frame(height: 40)
            }
            
            // GPU
            HStack {
                Image(systemName: "cpu.fill")
                    .frame(width: 18)
                Text("GPU")
                    .frame(width: 36, alignment: .leading)
                Text(String(format: "%.0f%%", viewModel.metrics.gpuUsage))
                    .frame(alignment: .leading)
                Spacer()
            }
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            
            HistoryView(history: viewModel.gpuHistory, color: .purple)
                .frame(height: 40)
            
            // RAM
            HStack {
                Image(systemName: "memorychip")
                    .frame(width: 18)
                Text("RAM")
                    .frame(width: 36, alignment: .leading)
                Text(String(format: "%.1f/%.1f GB", viewModel.metrics.memoryUsedGB, viewModel.metrics.memoryTotalGB))
                    .frame(alignment: .leading)
                Spacer()
            }
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            
            HistoryView(history: viewModel.memoryHistory, color: .green)
                .frame(height: 40)
            
            // Disk
            HStack {
                Image(systemName: "internaldrive")
                    .frame(width: 18)
                Text("Disk")
                    .frame(width: 36, alignment: .leading)
                Text(String(format: "%.0f/%.0f GB", viewModel.metrics.diskUsedGB, viewModel.metrics.diskTotalGB))
                    .frame(alignment: .leading)
                Spacer()
            }
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            
            // Custom Disk Indicator to avoid ProgressView animation
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .frame(width: geometry.size.width, height: 6)
                        .opacity(0.3)
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    
                    RoundedRectangle(cornerRadius: 3)
                        .frame(width: min(CGFloat(self.viewModel.metrics.diskUsedGB / max(self.viewModel.metrics.diskTotalGB, 1.0)) * geometry.size.width, geometry.size.width), height: 6)
                        .foregroundColor(Color(NSColor.controlAccentColor))
                        .animation(nil, value: viewModel.metrics.diskUsedGB) // Ensure no animation here either
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .frame(width: 220)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
