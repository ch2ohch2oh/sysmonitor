import SwiftUI

enum DisplayMode: String, CaseIterable, Identifiable {
    case text = "Text"
    case miniChart = "Mini Chart"
    
    var id: String { self.rawValue }
}

struct SettingsView: View {
    @AppStorage("statusBarDisplayMode") private var displayMode: DisplayMode = .miniChart
    
    @StateObject private var autostart = Autostart.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(WeatherTheme.labelSecondary)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status Bar Display")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(WeatherTheme.labelPrimary)
                }
                Spacer()
                Picker("", selection: $displayMode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.small)
                .font(.system(size: 11, weight: .regular))
                .frame(width: 160, alignment: .trailing)
            }
            
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "power")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(WeatherTheme.labelSecondary)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start at Login")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(WeatherTheme.labelPrimary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { autostart.isEnabled },
                    set: { autostart.toggle(enabled: $0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .frame(width: 160, alignment: .trailing)
            }
        }
        .padding(14)
        .frame(width: 360)
        .fixedSize()
    }
}


struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
