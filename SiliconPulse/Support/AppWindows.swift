import AppKit
import SwiftUI

extension Notification.Name {
    static let siliconPulseOpenSettings = Notification.Name("SiliconPulseOpenSettings")
}

enum AppWindows {
    static let settingsTitle = "Settings"
    static let processesTitle = "Top Processes"
    static let onboardingTitle = "Welcome to SiliconPulse"

    /// Call after `openSettings()` — activates app, dismisses menu popup, focuses Settings.
    @MainActor
    static func presentSettings() {
        activateApp()
        dismissMenuBarPanelIfNeeded()
        focusSettingsWindow(retries: 12)
    }

    /// Opens Top Processes using SwiftUI `openWindow`, then reliably brings it to the front.
    @MainActor
    static func openProcesses(using openWindow: OpenWindowAction) {
        activateApp()
        dismissMenuBarPanelIfNeeded()
        openWindow(id: "processes")
        focusWindow(title: processesTitle, retries: 12)
    }

    @MainActor
    static func presentOnboarding() {
        activateApp()
        focusWindow(title: onboardingTitle, retries: 12)
    }

    @MainActor
    private static func activateApp() {
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)
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
                bringToFront(window)
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
                bringToFront(window)
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

    @MainActor
    private static func bringToFront(_ window: NSWindow) {
        window.deminiaturize(nil)
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        let previousLevel = window.level
        window.level = .floating
        window.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if window.isVisible {
                window.level = previousLevel
            }
        }
    }
}
