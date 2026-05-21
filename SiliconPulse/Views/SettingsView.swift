import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }
            DisplaySettingsView()
                .tabItem { Label("Display", systemImage: "eye") }
            NetworkSettingsView()
                .tabItem { Label("Network", systemImage: "network") }
            ProcessSettingsView()
                .tabItem { Label("Processes", systemImage: "list.bullet") }
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(minWidth: 500, minHeight: 380)
    }
}

struct GeneralSettingsView: View {
    @State var settings = SettingsManager.shared

    var body: some View {
        Form {
            Section {
                Picker("Update Interval", selection: $settings.updateInterval) {
                    Text("1 second").tag(1.0)
                    Text("2 seconds").tag(2.0)
                    Text("5 seconds").tag(5.0)
                }
                .pickerStyle(.segmented)
                .onChange(of: settings.updateInterval) { settings.save() }

                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { settings.save() }
            } header: {
                Text("Update Preferences")
            }

            Section {
                Toggle("Enable Notifications", isOn: $settings.showNotifications)
                    .onChange(of: settings.showNotifications) { settings.save() }
            } header: {
                Text("Alerts")
            }
        }
        .formStyle(.grouped)
    }
}

struct DisplaySettingsView: View {
    @State var settings = SettingsManager.shared

    var body: some View {
        Form {
            Section {
                Toggle("Show CPU Core Details", isOn: $settings.showCoreDetails)
                    .onChange(of: settings.showCoreDetails) { settings.save() }
                Toggle("Show Memory Breakdown", isOn: $settings.showMemoryDetails)
                    .onChange(of: settings.showMemoryDetails) { settings.save() }
                Toggle("Show Thermal Info", isOn: $settings.showThermalInfo)
                    .onChange(of: settings.showThermalInfo) { settings.save() }
                Toggle("Show Network Details", isOn: $settings.showNetworkDetails)
                    .onChange(of: settings.showNetworkDetails) { settings.save() }
                Toggle("Show Battery Info", isOn: $settings.showBatteryInfo)
                    .onChange(of: settings.showBatteryInfo) { settings.save() }
                Toggle("Show Disk Info", isOn: $settings.showDiskInfo)
                    .onChange(of: settings.showDiskInfo) { settings.save() }
                Toggle("Show Fan Control", isOn: $settings.showFanControl)
                    .onChange(of: settings.showFanControl) { settings.save() }
            } header: {
                Text("Dashboard")
            } footer: {
                #if arch(arm64)
                Text("Fan control on Apple Silicon requires installing the privileged helper from the Fans section.")
                #endif
            }

            Section {
                Picker("Temperature", selection: $settings.useFahrenheit) {
                    Text("Celsius (°C)").tag(false)
                    Text("Fahrenheit (°F)").tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: settings.useFahrenheit) { settings.save() }
            } header: {
                Text("Units")
            }
        }
        .formStyle(.grouped)
    }
}

struct NetworkSettingsView: View {
    @State var settings = SettingsManager.shared

    var body: some View {
        Form {
            Section {
                Toggle("Show in Bits per second", isOn: $settings.useBitsPerSecond)
                    .onChange(of: settings.useBitsPerSecond) { settings.save() }

                Stepper("History Points: \(settings.networkHistoryPoints)", value: $settings.networkHistoryPoints, in: 10...120, step: 10)
                    .onChange(of: settings.networkHistoryPoints) { settings.save() }
            } header: {
                Text("Network")
            }
        }
        .formStyle(.grouped)
    }
}

struct ProcessSettingsView: View {
    @State var settings = SettingsManager.shared

    var body: some View {
        Form {
            Section {
                Picker("Default Sort", selection: $settings.processSortBy) {
                    ForEach(SettingsManager.ProcessSort.allCases, id: \.self) { sort in
                        Text(sort.rawValue).tag(sort)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: settings.processSortBy) { settings.save() }
            } header: {
                Text("Process Window")
            }

            Section {
                Button("Reset All Settings to Default") {
                    settings.resetToDefaults()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } footer: {
                Text("This will restore all preferences to their original values.")
            }
        }
        .formStyle(.grouped)
    }
}

struct AboutView: View {
    @Environment(SystemMonitor.self) var systemMonitor

    var body: some View {
        VStack(spacing: DesignTokens.sectionSpacing) {
            Image(systemName: "cpu")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)

            Text("SiliconPulse")
                .font(.title2.weight(.semibold))

            Text("Version 1.1.0")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                aboutRow("Model", systemMonitor.systemInfo.modelName)
                aboutRow("Chip", systemMonitor.systemInfo.chipName)
                aboutRow("macOS", systemMonitor.systemInfo.osVersion)
                aboutRow("Cores", "\(systemMonitor.systemInfo.coreCount) (\(systemMonitor.systemInfo.efficiencyCoreCount)E + \(systemMonitor.systemInfo.performanceCoreCount)P)")
                aboutRow("Uptime", Formatters.uptime(systemMonitor.uptime))
            }
            .font(.callout)

            Spacer()
        }
        .padding(DesignTokens.panelPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func aboutRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
        }
    }
}
