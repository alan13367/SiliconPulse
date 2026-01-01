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
    @State private var showingExportPanel = false
    @State private var showingImportPanel = false
    @State private var importError = false
    
    enum SettingsTab {
        case general, display, alerts, advanced, about
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Selection
            HStack(spacing: 0) {
                SettingsTabButton(title: "General", icon: "gear", tab: .general, selectedTab: $selectedTab)
                SettingsTabButton(title: "Display", icon: "eye", tab: .display, selectedTab: $selectedTab)
                SettingsTabButton(title: "Alerts", icon: "bell", tab: .alerts, selectedTab: $selectedTab)
                SettingsTabButton(title: "Advanced", icon: "wrench", tab: .advanced, selectedTab: $selectedTab)
                SettingsTabButton(title: "About", icon: "info.circle", tab: .about, selectedTab: $selectedTab)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Divider()
                .padding(.top, 12)
            
            // Tab Content
            ScrollView {
                Group {
                    switch selectedTab {
                    case .general:
                        GeneralSettingsView()
                    case .display:
                        DisplaySettingsView()
                    case .alerts:
                        AlertSettingsView()
                    case .advanced:
                        AdvancedSettingsView()
                    case .about:
                        AboutView()
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 450, height: 550)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Tab Button
struct SettingsTabButton: View {
    let title: String
    let icon: String
    let tab: SettingsView.SettingsTab
    @Binding var selectedTab: SettingsView.SettingsTab
    
    var body: some View {
        Button(action: {
            selectedTab = tab
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                
                Text(title)
                    .font(.system(.caption, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                selectedTab == tab ?
                Color.blue.opacity(0.1) :
                Color.clear
            )
            .foregroundColor(
                selectedTab == tab ?
                .blue :
                .secondary
            )
            .overlay(
                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(selectedTab == tab ? .blue : .clear),
                alignment: .bottom
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - General Settings
struct GeneralSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General Settings")
                .font(.title2.bold())
                .padding(.bottom, 4)
            
            // Update Frequency
            VStack(alignment: .leading, spacing: 8) {
                Text("Update Frequency")
                    .font(.headline)
                
                Picker("", selection: $settingsManager.updateInterval) {
                    Text("1 second").tag(1.0)
                    Text("2 seconds").tag(2.0)
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                    Text("30 seconds").tag(30.0)
                }
                .pickerStyle(.segmented)
                
                Text("How often SiliconPulse checks system stats")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Startup
            VStack(alignment: .leading, spacing: 8) {
                Text("Startup")
                    .font(.headline)
                
                Toggle("Launch SiliconPulse at login", isOn: $settingsManager.launchAtLogin)
                
                Text("Automatically start monitoring when you log in")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Display Settings
struct DisplaySettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Display Settings")
                .font(.title2.bold())
                .padding(.bottom, 4)
            
            // Menu Bar Display
            VStack(alignment: .leading, spacing: 12) {
                Text("Menu Bar Display")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Show CPU core details", isOn: $settingsManager.showCoreDetails)
                    Toggle("Show memory details", isOn: $settingsManager.showMemoryDetails)
                    Toggle("Show thermal pressure info", isOn: $settingsManager.showThermalInfo)
                }
            }
            
            Divider()
            
            // Visual Preferences
            VStack(alignment: .leading, spacing: 12) {
                Text("Visual Preferences")
                    .font(.headline)
                
                ColorPicker("Low usage color:", selection: .constant(.green))
                ColorPicker("Medium usage color:", selection: .constant(.yellow))
                ColorPicker("High usage color:", selection: .constant(.red))
                
                Text("Colors used for CPU and memory indicators")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Alert Settings
struct AlertSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var systemMonitor: SystemMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Alert Settings")
                .font(.title2.bold())
                .padding(.bottom, 4)
            
            // Alert Toggle
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Enable system alerts", isOn: $settingsManager.showNotifications)
                    .font(.headline)
                
                Text("Receive notifications when system resources are critically high")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Alert Thresholds
            VStack(alignment: .leading, spacing: 16) {
                Text("Alert Thresholds")
                    .font(.headline)
                
                // CPU Threshold
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("CPU Usage Alert:")
                        Spacer()
                        Text("\(Int(settingsManager.cpuAlertThreshold))%")
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    Slider(value: $settingsManager.cpuAlertThreshold, in: 50...100, step: 5) {
                        Text("CPU Alert Threshold")
                    }
                    
                    Text("Alert when CPU usage exceeds this percentage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Memory Threshold
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Memory Usage Alert:")
                        Spacer()
                        Text("\(Int(settingsManager.memoryAlertThreshold))%")
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    Slider(value: $settingsManager.memoryAlertThreshold, in: 50...100, step: 5) {
                        Text("Memory Alert Threshold")
                    }
                    
                    Text("Alert when memory usage exceeds this percentage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Thermal Threshold
                VStack(alignment: .leading, spacing: 6) {
                    Picker("Thermal Pressure Alert:", selection: $settingsManager.thermalAlertThreshold) {
                        ForEach(ThermalMonitor.ThermalPressureLevel.allCases.prefix(5), id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Text("Alert when thermal pressure reaches this level or higher")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Advanced Settings
struct AdvancedSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showingResetConfirmation = false
    @State private var showingExportConfirmation = false
    @State private var showingImportConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Advanced Settings")
                .font(.title2.bold())
                .padding(.bottom, 4)
            
            // Data & Privacy
            VStack(alignment: .leading, spacing: 12) {
                Text("Data & Privacy")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Enable anonymous usage statistics", isOn: .constant(false))
                    Toggle("Send crash reports automatically", isOn: .constant(false))
                }
                
                Text("Help improve SiliconPulse by sharing anonymous data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Configuration Management
            VStack(alignment: .leading, spacing: 12) {
                Text("Configuration Management")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Button("Export Settings") {
                        exportSettings()
                    }
                    
                    Button("Import Settings") {
                        importSettings()
                    }
                    
                    Spacer()
                }
                
                Text("Backup or transfer your SiliconPulse settings")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Reset
            VStack(alignment: .leading, spacing: 12) {
                Text("Reset Settings")
                    .font(.headline)
                
                Button("Reset to Default Settings") {
                    showingResetConfirmation = true
                }
                .foregroundColor(.red)
                .alert("Reset Settings?", isPresented: $showingResetConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Reset", role: .destructive) {
                        settingsManager.resetToDefaults()
                    }
                } message: {
                    Text("This will reset all settings to their default values. This action cannot be undone.")
                }
                
                Text("Restore all settings to their original defaults")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func exportSettings() {
        guard let settingsData = settingsManager.exportSettings() else { return }
        
        let panel = NSSavePanel()
        panel.title = "Export Settings"
        panel.nameFieldStringValue = "SiliconPulse-Settings.json"
        panel.allowedContentTypes = [.json]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try settingsData.write(to: url)
                } catch {
                    print("Failed to export settings: \(error)")
                }
            }
        }
    }
    
    private func importSettings() {
        let panel = NSOpenPanel()
        panel.title = "Import Settings"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let data = try Data(contentsOf: url)
                    let success = settingsManager.importSettings(from: data)
                    
                    if success {
                        // Show success message
                    } else {
                        // Show error message
                    }
                } catch {
                    print("Failed to import settings: \(error)")
                }
            }
        }
    }
}

// MARK: - About View
struct AboutView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    @EnvironmentObject var thermalMonitor: ThermalMonitor
    
    var body: some View {
        VStack(spacing: 24) {
            // App Icon and Name
            VStack(spacing: 12) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("SiliconPulse")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                
                Text("Apple Silicon System Monitor")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // System Info
            VStack(alignment: .leading, spacing: 12) {
                Text("System Information")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 6) {
                    InfoRow(label: "Architecture", value: "Apple Silicon (ARM64)")
                    InfoRow(label: "Active Cores", value: "\(systemMonitor.coreUsages.count)")
                    InfoRow(label: "Thermal Monitoring", value: thermalMonitor.thermalNotificationAvailable ? "Available" : "Not Available")
                    InfoRow(label: "Uptime", value: systemMonitor.getFormattedUptime())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            // Links
            VStack(alignment: .leading, spacing: 12) {
                Text("Links")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Link("GitHub Repository", destination: URL(string: "https://github.com/yourusername/SiliconPulse")!)
                    Link("Report an Issue", destination: URL(string: "https://github.com/yourusername/SiliconPulse/issues")!)
                    Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                }
                .font(.subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            // Copyright
            Text("© 2024 SiliconPulse. All rights reserved.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
        }
    }
}
