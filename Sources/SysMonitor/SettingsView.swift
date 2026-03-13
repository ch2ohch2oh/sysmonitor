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
        ZStack {
            WeatherTheme.panelBackground(cornerRadius: 12)
            VStack(alignment: .leading, spacing: 12) {
                Text("Settings")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(WeatherTheme.labelPrimary)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Status Bar Display")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(WeatherTheme.labelPrimary)
                    Picker("", selection: $displayMode) {
                        ForEach(DisplayMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Divider().background(WeatherTheme.separator)
                
                HStack {
                    Text("Start at Login")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(WeatherTheme.labelPrimary)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { autostart.isEnabled },
                        set: { autostart.toggle(enabled: $0) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
            }
            .padding(12)
        }
        .frame(width: 360)
        .fixedSize()
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
