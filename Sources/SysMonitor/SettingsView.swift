import SwiftUI

enum DisplayMode: String, CaseIterable, Identifiable {
    case text = "Text"
    case miniChart = "Mini Chart"
    
    var id: String { self.rawValue }
}

struct SettingsView: View {
    @AppStorage("statusBarDisplayMode") private var displayMode: DisplayMode = .text
    
    var body: some View {
        Form {
            Picker("Status bar style:", selection: $displayMode) {
                ForEach(DisplayMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding()
        .frame(width: 300, height: 80)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
