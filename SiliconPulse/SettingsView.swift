//
//  SettingsView.swift
//  SiliconPulse
//
//  Created by Alan on 31/12/25.
//


import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var systemMonitor: SystemMonitor
    @EnvironmentObject var thermalMonitor: ThermalMonitor
    
    @State private var selectedTab: SettingsTab = .general
    
    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case display = "Display"
        case network = "Network"
        case alerts = "Alerts"
        case advanced = "Advanced"
        case about = "About"
        
        var icon: String {
            switch self {
            case .general: return "gear"
            case .display: return "eye"
            case .network: return "network"
            case .alerts: return "bell"
            case .advanced: return "wrench.and.screwdriver"
            case .about: return "info.circle"
            }
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label(SettingsTab.general.rawValue, systemImage: SettingsTab.general.icon)
                }
                .tag(SettingsTab.general)
            
            DisplaySettingsView()
                .tabItem {
                    Label(SettingsTab.display.rawValue, systemImage: SettingsTab.display.icon)
                }
                .tag(SettingsTab.display)

            NetworkSettingsView()
                .tabItem {
                    Label(SettingsTab.network.rawValue, systemImage: SettingsTab.network.icon)
                }
                .tag(SettingsTab.network)
            
            AlertSettingsView()
                .tabItem {
                    Label(SettingsTab.alerts.rawValue, systemImage: SettingsTab.alerts.icon)
                }
                .tag(SettingsTab.alerts)
            
            AdvancedSettingsView()
                .tabItem {
                    Label(SettingsTab.advanced.rawValue, systemImage: SettingsTab.advanced.icon)
                }
                .tag(SettingsTab.advanced)
            
            AboutView()
                .tabItem {
                    Label(SettingsTab.about.rawValue, systemImage: SettingsTab.about.icon)
                }
                .tag(SettingsTab.about)
        }
        .padding(20)
        .frame(width: 500, height: 450)
    }
}

// MARK: - General Settings
struct GeneralSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        Form {
            Section(header: Text("Update Preferences")) {
                Picker("Update Interval", selection: $settingsManager.updateInterval) {
                    Text("1 second").tag(1.0)
                    Text("2 seconds").tag(2.0)
                    Text("5 seconds").tag(5.0)
                }
                .pickerStyle(.menu)
                
                Toggle("Launch at Login", isOn: $settingsManager.launchAtLogin)
            }
        }
    }
}

// MARK: - Display Settings
struct DisplaySettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        Form {
            Section(header: Text("Dashboard Options")) {
                Toggle("Show CPU Core Details", isOn: $settingsManager.showCoreDetails)
                Toggle("Show Memory Breakdown", isOn: $settingsManager.showMemoryDetails)
                Toggle("Show Thermal Info", isOn: $settingsManager.showThermalInfo)
            }
            
            Section(header: Text("Units")) {
                Picker("Temperature Unit", selection: $settingsManager.useFahrenheit) {
                    Text("Celsius (°C)").tag(false)
                    Text("Fahrenheit (°F)").tag(true)
                }
                .pickerStyle(.radioGroup)
            }
            
            Section(header: Text("Colors")) {
                ColorPicker("Normal Usage", selection: $settingsManager.lowUsageColor)
                ColorPicker("Medium Usage", selection: $settingsManager.mediumUsageColor)
                ColorPicker("High Usage", selection: $settingsManager.highUsageColor)
            }
        }
    }
}

// MARK: - Network Settings
struct NetworkSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        Form {
            Section(header: Text("Network Monitoring")) {
                Toggle("Show Network Details", isOn: $settingsManager.showNetworkDetails)
                Toggle("Show in Bits per second (bps)", isOn: $settingsManager.useBitsPerSecond)
                
                Stepper("History Points: \(settingsManager.networkHistoryPoints)", value: $settingsManager.networkHistoryPoints, in: 10...100, step: 5)
            }
        }
    }
}

// MARK: - Alert Settings
struct AlertSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        Form {
            Section(header: Text("Notifications")) {
                Toggle("Enable Resource Alerts", isOn: $settingsManager.showNotifications)
            }
            
            Section(header: Text("Thresholds")) {
                VStack(alignment: .leading) {
                    Text("CPU Alert: \(Int(settingsManager.cpuAlertThreshold))%")
                    Slider(value: $settingsManager.cpuAlertThreshold, in: 50...100, step: 5)
                }
                
                VStack(alignment: .leading) {
                    Text("Memory Alert: \(Int(settingsManager.memoryAlertThreshold))%")
                    Slider(value: $settingsManager.memoryAlertThreshold, in: 50...100, step: 5)
                }
                
                Picker("Thermal Alert Level", selection: $settingsManager.thermalAlertThreshold) {
                    Text("Moderate").tag("moderate")
                    Text("Heavy").tag("heavy")
                    Text("Critical").tag("trapping")
                }
            }
        }
    }
}

// MARK: - Advanced Settings
struct AdvancedSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        VStack(spacing: 20) {
            Button("Reset All Settings to Default") {
                settingsManager.resetToDefaults()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            
            Text("This will restore all preferences, colors, and thresholds to their original factory values.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

// MARK: - About View
struct AboutView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cpu.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue.gradient)
            
            Text("SiliconPulse")
                .font(.title.bold())
            
            Text("Version 1.1.0")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("System Uptime:")
                    Spacer()
                    Text(systemMonitor.getFormattedUptime())
                }
                HStack {
                    Text("Cores Detected:")
                    Spacer()
                    Text("\(systemMonitor.coreUsages.count)")
                }
            }
            .font(.callout)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
}
