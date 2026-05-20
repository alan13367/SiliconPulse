import SwiftUI

struct SettingsView: View {
    @State var settings = SettingsManager.shared

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
        .padding(20)
        .frame(width: 520, height: 380)
    }
}

struct GeneralSettingsView: View {
    @State var settings = SettingsManager.shared

    var body: some View {
        Form {
            Section(header: Text("Update Preferences").font(.caption)) {
                Picker("Update Interval", selection: $settings.updateInterval) {
                    Text("1 second").tag(1.0)
                    Text("2 seconds").tag(2.0)
                    Text("5 seconds").tag(5.0)
                }
                .pickerStyle(.segmented)
                .onChange(of: settings.updateInterval) { settings.save() }

                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { settings.save() }
            }

            Section(header: Text("Alerts").font(.caption)) {
                Toggle("Enable Notifications", isOn: $settings.showNotifications)
                    .onChange(of: settings.showNotifications) { settings.save() }
            }
        }
        .formStyle(.grouped)
    }
}

struct DisplaySettingsView: View {
    @State var settings = SettingsManager.shared

    var body: some View {
        Form {
            Section(header: Text("Dashboard").font(.caption)) {
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
            }

            Section(header: Text("Units").font(.caption)) {
                Picker("Temperature", selection: $settings.useFahrenheit) {
                    Text("Celsius (°C)").tag(false)
                    Text("Fahrenheit (°F)").tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: settings.useFahrenheit) { settings.save() }
            }
        }
        .formStyle(.grouped)
    }
}

struct NetworkSettingsView: View {
    @State var settings = SettingsManager.shared

    var body: some View {
        Form {
            Section(header: Text("Network").font(.caption)) {
                Toggle("Show in Bits per second", isOn: $settings.useBitsPerSecond)
                    .onChange(of: settings.useBitsPerSecond) { settings.save() }

                Stepper("History Points: \(settings.networkHistoryPoints)", value: $settings.networkHistoryPoints, in: 10...120, step: 10)
                    .onChange(of: settings.networkHistoryPoints) { settings.save() }
            }
        }
        .formStyle(.grouped)
    }
}

struct ProcessSettingsView: View {
    @State var settings = SettingsManager.shared

    var body: some View {
        Form {
            Section(header: Text("Process Window").font(.caption)) {
                Picker("Default Sort", selection: $settings.processSortBy) {
                    ForEach(SettingsManager.ProcessSort.allCases, id: \.self) { sort in
                        Text(sort.rawValue).tag(sort)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: settings.processSortBy) { settings.save() }
            }

            Section {
                Button("Reset All Settings to Default") {
                    settings.resetToDefaults()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                Text("This will restore all preferences to their original values.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct AboutView: View {
    @Environment(SystemMonitor.self) var systemMonitor

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cpu.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)

            Text("SiliconPulse")
                .font(.title2.bold())

            Text("Version 1.1.0")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow {
                    Text("Model:").foregroundStyle(.secondary)
                    Text(systemMonitor.systemInfo.modelName)
                }
                GridRow {
                    Text("Chip:").foregroundStyle(.secondary)
                    Text(systemMonitor.systemInfo.chipName)
                }
                GridRow {
                    Text("macOS:").foregroundStyle(.secondary)
                    Text(systemMonitor.systemInfo.osVersion)
                }
                GridRow {
                    Text("Cores:").foregroundStyle(.secondary)
                    Text("\(systemMonitor.systemInfo.coreCount) (\(systemMonitor.systemInfo.efficiencyCoreCount)E + \(systemMonitor.systemInfo.performanceCoreCount)P)")
                }
                GridRow {
                    Text("Uptime:").foregroundStyle(.secondary)
                    Text(Formatters.uptime(systemMonitor.uptime))
                }
            }
            .font(.callout)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
