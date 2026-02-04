import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start the system usage monitor
        Task {
            await SystemUsage.shared.start()
        }
        
        // Initialize the status bar controller
        statusBarController = StatusBarController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup if needed
    }
}
