import SwiftUI

@main
struct SiliconPulseApp: App {
    // We create a single instance of our monitor to share across the app
    @StateObject var monitor = SystemMonitor()

    var body: some Scene {
        // "isInserted" keeps it visible in the menu bar
        MenuBarExtra(isInserted: .constant(true)) {
            DashboardView(monitor: monitor)
        } label: {
            HStack(spacing: 4) {
                Text("CPU")
                Text("\(Int(monitor.cpuUsage))%")
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.window) // This creates the "popover" style dropdown
    }
}
