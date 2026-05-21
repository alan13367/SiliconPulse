import AppKit
import SwiftUI

extension Notification.Name {
    static let siliconPulseOpenSettings = Notification.Name("SiliconPulseOpenSettings")
}

enum AppWindows {
    static let settingsTitle = "Settings"
    static let processesTitle = "Top Processes"

    /// Call before `openSettings()` or after `SettingsLink` — activates app, dismisses menu popup, focuses Settings.
    @MainActor
    static func presentSettings() {
        NSApp.activate(ignoringOtherApps: true)
        dismissMenuBarPanelIfNeeded()
        focusSettingsWindow(retries: 6)
    }

    /// Opens Top Processes using SwiftUI `openWindow`, then reliably brings it to the front.
    @MainActor
    static func openProcesses(using openWindow: OpenWindowAction) {
        NSApp.activate(ignoringOtherApps: true)
        dismissMenuBarPanelIfNeeded()
        openWindow(id: "processes")
        focusWindow(title: processesTitle, retries: 6)
    }

    @MainActor
    private static func dismissMenuBarPanelIfNeeded() {
        guard let keyWindow = NSApp.keyWindow else { return }
        let className = String(describing: type(of: keyWindow))
        if keyWindow.level == .popUpMenu
            || keyWindow.level == .statusBar
            || className.contains("StatusBar")
            || className.contains("Popup")
            || (keyWindow is NSPanel && keyWindow.isFloatingPanel) {
            keyWindow.orderOut(nil)
        }
    }

    @MainActor
    private static func focusSettingsWindow(retries: Int, attempt: Int = 0) {
        guard attempt < retries else { return }
        let delay = attempt == 0 ? 0.05 : 0.1

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if let window = locateSettingsWindow() {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                return
            }
            focusSettingsWindow(retries: retries, attempt: attempt + 1)
        }
    }

    @MainActor
    private static func focusWindow(title: String, retries: Int, attempt: Int = 0) {
        guard attempt < retries else { return }
        let delay = attempt == 0 ? 0.05 : 0.1

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if let window = locateWindow(matchingTitle: title) {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                return
            }
            focusWindow(title: title, retries: retries, attempt: attempt + 1)
        }
    }

    @MainActor
    private static func locateSettingsWindow() -> NSWindow? {
        for w in NSApp.windows {
            guard w.canBecomeKey, !w.isSheet else { continue }
            let title = w.title
            if title.localizedCaseInsensitiveContains("settings") { return w }
            if NSStringFromClass(type(of: w)).localizedCaseInsensitiveContains("Settings") { return w }
        }
        return nil
    }

    @MainActor
    private static func locateWindow(matchingTitle title: String) -> NSWindow? {
        for w in NSApp.windows {
            guard w.canBecomeKey, !w.isSheet else { continue }
            if w.title == title { return w }
            if w.title.localizedCaseInsensitiveContains(title) { return w }
            if w.identifier?.rawValue == title { return w }
        }
        return nil
    }
}
