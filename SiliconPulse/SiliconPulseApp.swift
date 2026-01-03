import SwiftUI

@main
struct SiliconPulseApp: App {
    @StateObject private var systemMonitor = SystemMonitor.shared
    @StateObject private var thermalMonitor = ThermalMonitor.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    @State private var isSettingsWindowPresented = false
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(systemMonitor)
                .environmentObject(thermalMonitor)
                .environmentObject(settingsManager)
                .environmentObject(networkMonitor)
        } label: {
            MenuBarIconView()
                .environmentObject(systemMonitor)
                .environmentObject(thermalMonitor)
        }
        .menuBarExtraStyle(.window)
        
        Settings {
            SettingsView()
                .environmentObject(systemMonitor)
                .environmentObject(thermalMonitor)
                .environmentObject(settingsManager)
                .environmentObject(networkMonitor)
        }
    }
}

struct MenuBarIconView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    @EnvironmentObject var thermalMonitor: ThermalMonitor
    
    var body: some View {
        HStack(spacing: 8) {
            // CPU
            HStack(spacing: 2) {
                Image(systemName: "cpu")
                    .imageScale(.medium)
                Text("\(Int(systemMonitor.cpuUsage))%")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.bold)
            }
            .foregroundColor(cpuColor)
            
            // Memory
            HStack(spacing: 2) {
                Image(systemName: "memorychip")
                    .imageScale(.medium)
                Text("\(Int(systemMonitor.memoryUsage))%")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.bold)
            }
            .foregroundColor(memoryColor)
            
            // Thermal Warning (only if not nominal)
            if thermalMonitor.thermalPressureLevel != .nominal {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(thermalMonitor.thermalPressureLevel.color)
                    .imageScale(.medium)
            }
        }
        .padding(.horizontal, 4)
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
