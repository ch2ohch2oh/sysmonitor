import SwiftUI

enum DisplayMode: String, CaseIterable, Identifiable {
    case text = "Text"
    case miniChart = "Mini Chart"
    
    var id: String { self.rawValue }
}

struct SettingsView: View {
    @AppStorage("statusBarDisplayMode") private var displayMode: DisplayMode = .text
    
    @StateObject private var autostart = Autostart.shared
    
    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                Text("Status Bar Display")
                    .gridColumnAlignment(.trailing)
                
                Picker("", selection: $displayMode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .labelsHidden()
            }
            
            GridRow {
                Text("Start at Login")
                    .gridColumnAlignment(.trailing)
                
                Toggle("", isOn: Binding(
                    get: { autostart.isEnabled },
                    set: { autostart.toggle(enabled: $0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }
        }
        .padding(16)
        .frame(width: 320)
        .fixedSize()
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
