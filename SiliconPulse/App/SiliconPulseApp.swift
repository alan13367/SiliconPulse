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
                .environment(settingsManager)
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    NotificationCenter.default.post(name: .siliconPulseOpenSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        Window("Top Processes", id: "processes") {
            ProcessWindowView()
                .environment(processMonitor)
                .environment(settingsManager)
        }
        .defaultSize(width: 900, height: 560)

        Window("Welcome to SiliconPulse", id: "onboarding") {
            OnboardingView()
                .environment(settingsManager)
        }
        .defaultSize(width: 520, height: 420)

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
    @Environment(SettingsManager.self) var settings
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    @State private var didRequestOnboarding = false

    var body: some View {
        HStack(spacing: 5) {
            Label("\(Int(systemMonitor.cpuUsage))%", systemImage: "cpu")
            Label("\(Int(systemMonitor.memoryUsage))%", systemImage: "memorychip")

            if thermalMonitor.thermalPressureLevel != .nominal {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(thermalMonitor.thermalPressureLevel.color)
                    .imageScale(.small)
                    .accessibilityLabel("Thermal pressure: \(thermalMonitor.thermalPressureLevel.rawValue)")
            }
        }
        .labelStyle(.titleAndIcon)
        .font(.caption.weight(.medium))
        .monospacedDigit()
        .foregroundStyle(.primary)
        .padding(.horizontal, 2)
        .onReceive(NotificationCenter.default.publisher(for: .siliconPulseOpenSettings)) { _ in
            openSettings()
            AppWindows.presentSettings()
        }
        .task {
            openOnboardingIfNeeded()
        }
    }

    @MainActor
    private func openOnboardingIfNeeded() {
        guard !didRequestOnboarding, !settings.hasCompletedOnboarding else { return }
        didRequestOnboarding = true
        openWindow(id: "onboarding")
        AppWindows.presentOnboarding()
    }
}
