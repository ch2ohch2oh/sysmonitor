import Cocoa

class EventMonitor {
    private var monitor: Any?
    private var localMonitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void

    public init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    deinit {
        stop()
    }

    public func start() {
        stop()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask.subtracting(.keyDown), handler: handler)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [handler] event in
            handler(event)
            return event.type == .keyDown && event.keyCode == 53 ? nil : event
        }
    }

    public func stop() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
