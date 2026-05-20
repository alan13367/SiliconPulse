import SwiftUI
import AppKit

@main
struct SiliconPulseApp: App {
    @State private var systemMonitor = SystemMonitor.shared
    @State private var gpuMonitor = GPUMonitor.shared
    @State private var networkMonitor = NetworkMonitor.shared
    @State private var thermalMonitor = ThermalMonitor.shared
    @State private var processMonitor = ProcessMonitor.shared
    @State private var batteryMonitor = BatteryMonitor.shared
    @State private var diskMonitor = DiskMonitor.shared
    @State private var fanController = FanController.shared
    @State private var settingsManager = SettingsManager.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(systemMonitor)
                .environment(gpuMonitor)
                .environment(networkMonitor)
                .environment(thermalMonitor)
                .environment(processMonitor)
                .environment(batteryMonitor)
                .environment(diskMonitor)
                .environment(fanController)
                .environment(settingsManager)
        } label: {
            MenuBarIconView()
                .environment(systemMonitor)
                .environment(thermalMonitor)
        }
        .menuBarExtraStyle(.window)

        Window("Top Processes", id: "processes") {
            ProcessWindowView()
                .environment(processMonitor)
                .environment(settingsManager)
        }

        Settings {
            SettingsView()
                .environment(systemMonitor)
                .environment(settingsManager)
        }
    }
}

struct MenuBarIconView: View {
    @Environment(SystemMonitor.self) var systemMonitor
    @Environment(ThermalMonitor.self) var thermalMonitor

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                Image(systemName: "cpu")
                    .imageScale(.small)
                Text("\(Int(systemMonitor.cpuUsage))%")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
            }
            .foregroundStyle(cpuColor)

            HStack(spacing: 2) {
                Image(systemName: "memorychip")
                    .imageScale(.small)
                Text("\(Int(systemMonitor.memoryUsage))%")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
            }
            .foregroundStyle(memoryColor)

            if thermalMonitor.thermalPressureLevel != .nominal {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(thermalMonitor.thermalPressureLevel.color)
                    .imageScale(.small)
            }
        }
        .padding(.horizontal, 2)
    }

    private var cpuColor: Color {
        switch systemMonitor.cpuUsage {
        case 0..<50: return .primary
        case 50..<80: return .orange
        default: return .red
        }
    }

    private var memoryColor: Color {
        switch systemMonitor.memoryUsage {
        case 0..<60: return .primary
        case 60..<85: return .orange
        default: return .red
        }
    }
}
