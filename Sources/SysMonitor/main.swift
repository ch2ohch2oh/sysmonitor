import Cocoa

// Entry point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Prevent the app from showing in the Dock
app.setActivationPolicy(.accessory)

app.run()
