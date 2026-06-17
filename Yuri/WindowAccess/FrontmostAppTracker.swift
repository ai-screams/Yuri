import Cocoa

final class FrontmostAppTracker {
    private(set) var lastFocusedApp: NSRunningApplication?
    var onChange: ((NSRunningApplication) -> Void)?

    private let selfPID = ProcessInfo.processInfo.processIdentifier

    init() {
        if let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != selfPID {
            lastFocusedApp = app
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func appActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.processIdentifier != selfPID
        else {
            return
        }
        lastFocusedApp = app
        onChange?(app)
    }
}
