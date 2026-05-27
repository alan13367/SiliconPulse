import SwiftUI
import Charts
import AppKit

struct MenuBarView: View {
    @Environment(SystemMonitor.self) var systemMonitor
    @Environment(GPUMonitor.self) var gpuMonitor
    @Environment(NetworkMonitor.self) var networkMonitor
    @Environment(ThermalMonitor.self) var thermalMonitor
    @Environment(BatteryMonitor.self) var batteryMonitor
    @Environment(DiskMonitor.self) var diskMonitor
    @Environment(FanController.self) var fanController
    @Environment(SettingsManager.self) var settings
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                LazyVStack(spacing: DesignTokens.sectionSpacing) {
                    cpuSection
                    if gpuMonitor.gpuAvailable { gpuSection }
                    memorySection
                    if settings.showNetworkDetails { networkSection }
                    if settings.showDiskInfo { diskSection }
                    if settings.showBatteryInfo && batteryMonitor.batteryInfo.isPresent { batterySection }
                    if settings.showFanControl { fanSection }
                    if settings.showThermalInfo { thermalSection }
                }
                .padding(DesignTokens.panelPadding)
            }
            .frame(minHeight: DesignTokens.scrollMinHeight, maxHeight: DesignTokens.scrollMaxHeight)
            Divider()
            footer
        }
        .frame(width: DesignTokens.panelWidth)
        .nativePanelBackground()
        .onReceive(NotificationCenter.default.publisher(for: .siliconPulseOpenSettings)) { _ in
            openSettingsShortcut()
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach([1.0, 2.0, 5.0], id: \.self) { interval in
                    Button("\(Int(interval)) seconds") {
                        applyUpdateInterval(interval)
                    }
                }
            } label: {
                ControlPillLabel(
                    title: "Every \(Int(settings.updateInterval))s",
                    systemImage: "clock",
                    tint: .accentColor
                )
            }
            .menuStyle(.borderlessButton)
            .help("Refresh rate")

            Spacer()

            Button {
                openProcesses()
            } label: {
                Image(systemName: "list.bullet.rectangle")
            }
            .buttonStyle(PanelIconButtonStyle(tint: .cyan))
            .help("Open Top Processes")

            Button {
                openSettingsShortcut()
            } label: {
                Image(systemName: "gear")
            }
            .buttonStyle(PanelIconButtonStyle(tint: .accentColor))
            .help("Settings")

            Button(action: quit) {
                Image(systemName: "power")
            }
            .buttonStyle(PanelIconButtonStyle(tint: .secondary))
            .help("Quit SiliconPulse")
        }
        .padding(.horizontal, DesignTokens.panelPadding)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SiliconPulse")
                    .font(.title2.weight(.semibold))
                Text(systemMonitor.systemInfo.chipName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "cpu")
                .font(.title2)
                .foregroundStyle(.cyan)
                .symbolRenderingMode(.hierarchical)
                .padding(8)
                .background(.cyan.opacity(0.16), in: Circle())
                .overlay {
                    Circle()
                        .stroke(.cyan.opacity(0.28), lineWidth: 1)
                }
        }
        .padding(DesignTokens.panelPadding)
    }

    // MARK: - CPU

    private var cpuSection: some View {
        SettingsSection(title: "Processor", icon: "cpu") {
            VStack(alignment: .leading, spacing: DesignTokens.rowSpacing) {
                HStack(alignment: .firstTextBaseline) {
                    MetricRow(value: Formatters.percentage(systemMonitor.cpuUsage))
                    Spacer()
                    if systemMonitor.temperatureAvailable {
                        TemperatureBadge(
                            temperature: systemMonitor.currentTemperature,
                            useFahrenheit: settings.useFahrenheit
                        )
                    }
                }
                UsageGauge(value: systemMonitor.cpuUsage, showLabel: false)
                MetricTrendChart(
                    data: systemMonitor.cpuHistory,
                    yDomain: 0...100,
                    tint: DesignTokens.usageTint(systemMonitor.cpuUsage)
                )
                if settings.showCoreDetails && !systemMonitor.coreUsages.isEmpty {
                    coreBars
                }
            }
        }
    }

    @ViewBuilder
    private var gpuSection: some View {
        SettingsSection(title: "Graphics", icon: "bolt.fill") {
            VStack(alignment: .leading, spacing: DesignTokens.rowSpacing) {
                MetricRow(value: Formatters.percentage(gpuMonitor.gpuUsage))
                UsageGauge(value: gpuMonitor.gpuUsage, showLabel: false)
                MetricTrendChart(
                    data: gpuMonitor.gpuHistory,
                    yDomain: 0...100,
                    tint: DesignTokens.usageTint(gpuMonitor.gpuUsage)
                )
            }
        }
    }

    private var memorySection: some View {
        SettingsSection(title: "Memory", icon: "memorychip") {
            VStack(alignment: .leading, spacing: DesignTokens.rowSpacing) {
                LabeledContent("Used") {
                    Text(systemMonitor.memoryDetails.formattedString)
                        .monospacedDigit()
                }
                LabeledContent("Pressure") {
                    Text(Formatters.percentage(systemMonitor.memoryUsage))
                        .monospacedDigit()
                        .foregroundStyle(DesignTokens.usageTint(systemMonitor.memoryUsage))
                }
                UsageGauge(value: systemMonitor.memoryUsage, showLabel: false)
                MetricTrendChart(
                    data: systemMonitor.memoryHistory,
                    yDomain: 0...100,
                    tint: DesignTokens.usageTint(systemMonitor.memoryUsage)
                )
                if settings.showMemoryDetails {
                    memoryBreakdown
                }
            }
        }
    }

    private var memoryBreakdown: some View {
        VStack(spacing: 4) {
            LabeledContent("App") {
                Text(Formatters.bytes(systemMonitor.memoryDetails.appMemory))
                    .monospacedDigit()
            }
            LabeledContent("Wired") {
                Text(Formatters.bytes(systemMonitor.memoryDetails.wiredMemory))
                    .monospacedDigit()
            }
            LabeledContent("Compressed") {
                Text(Formatters.bytes(systemMonitor.memoryDetails.compressedMemory))
                    .monospacedDigit()
            }
            LabeledContent("Free") {
                Text(Formatters.bytes(systemMonitor.memoryDetails.free))
                    .monospacedDigit()
            }
        }
        .font(.caption)
    }

    private var networkSection: some View {
        SettingsSection(title: "Network", icon: "network") {
            VStack(alignment: .leading, spacing: DesignTokens.rowSpacing) {
                LabeledContent {
                    Text(Formatters.networkSpeed(networkMonitor.networkDownloadSpeed, useBits: settings.useBitsPerSecond))
                        .monospacedDigit()
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                }
                LabeledContent {
                    Text(Formatters.networkSpeed(networkMonitor.networkUploadSpeed, useBits: settings.useBitsPerSecond))
                        .monospacedDigit()
                } label: {
                    Label("Upload", systemImage: "arrow.up.circle")
                }
                MetricTrendChart(
                    data: networkMonitor.networkHistory.map(\.download),
                    secondaryData: networkMonitor.networkHistory.map(\.upload),
                    tint: DesignTokens.networkDownloadTint,
                    secondaryTint: DesignTokens.networkUploadTint,
                    valueFormatter: { Formatters.networkSpeed($0, useBits: settings.useBitsPerSecond) }
                )
                LabeledContent("Session") {
                    Text("\(Formatters.bytes(UInt64(networkMonitor.totalDownloadSession))) ↓ · \(Formatters.bytes(UInt64(networkMonitor.totalUploadSession))) ↑")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }

    private var diskSection: some View {
        SettingsSection(title: "Storage", icon: "internaldrive") {
            VStack(alignment: .leading, spacing: DesignTokens.rowSpacing) {
                ForEach(Array(diskMonitor.volumes.enumerated()), id: \.element.id) { index, volume in
                    VStack(alignment: .leading, spacing: 4) {
                        LabeledContent(volume.name) {
                            Text(Formatters.percentage(volume.usagePercent))
                                .monospacedDigit()
                        }
                        Text("\(Formatters.storage(volume.availableBytes)) available of \(Formatters.storage(volume.totalBytes))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        UsageGauge(value: volume.usagePercent, showLabel: false)
                    }
                    if index < diskMonitor.volumes.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    private var batterySection: some View {
        SettingsSection(title: "Power", icon: "battery.100") {
            VStack(alignment: .leading, spacing: DesignTokens.rowSpacing) {
                LabeledContent {
                    HStack(spacing: 6) {
                        Image(systemName: batteryIcon)
                            .foregroundStyle(batteryTint)
                        Text(Formatters.percentage(batteryMonitor.batteryInfo.chargeLevel * 100))
                            .monospacedDigit()
                    }
                } label: {
                    Text("Charge")
                }
                if batteryMonitor.batteryInfo.timeRemaining >= 0 {
                    LabeledContent("Time Remaining") {
                        Text(Formatters.timeRemaining(batteryMonitor.batteryInfo.timeRemaining))
                    }
                }
                Gauge(value: batteryMonitor.batteryInfo.chargeLevel * 100, in: 0...100) {
                    EmptyView()
                }
                .gaugeStyle(.linearCapacity)
                .tint(batteryTint)
                LabeledContent("Cycles") {
                    Text("\(batteryMonitor.batteryInfo.cycleCount)")
                        .monospacedDigit()
                }
                LabeledContent("Health") {
                    Text(Formatters.percentage(batteryMonitor.batteryInfo.healthPercent))
                        .monospacedDigit()
                }
            }
            .font(.subheadline)
        }
    }

    private var fanSection: some View {
        SettingsSection(title: "Fans", icon: "fan") {
            VStack(alignment: .leading, spacing: DesignTokens.rowSpacing) {
                if !fanController.isAvailable {
                    Text("Fan control is not available on this Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if fanController.fanCount == 0 {
                    Text("No fans detected.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(0..<fanController.fanCount, id: \.self) { i in
                        LabeledContent(fanController.fanNames[safe: i] ?? "Fan \(i + 1)") {
                            Text("\(fanController.fanSpeeds[safe: i] ?? 0) RPM")
                                .monospacedDigit()
                        }
                    }
                    #if arch(arm64)
                    if !fanController.helperInstalled {
                        Button("Install Fan Helper…") {
                            _ = fanController.installHelperIfNeeded()
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    } else {
                        fanControlsView
                    }
                    #else
                    fanControlsView
                    #endif
                }
            }
        }
    }

    private var fanControlsView: some View {
        VStack(alignment: .leading, spacing: DesignTokens.rowSpacing) {
            Picker("Mode", selection: Binding(
                get: { fanController.mode },
                set: { fanController.setMode($0) }
            )) {
                ForEach(FanController.FanMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if fanController.mode == .manual {
                let minRPM = Double(fanController.fanMinRPM)
                let maxRPM = Double(max(fanController.fanMaxRPM, fanController.fanMinRPM))
                LabeledContent("Target speed") {
                    Text("\(fanController.targetFanSpeed) RPM")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: Binding(
                    get: { Double(fanController.targetFanSpeed) },
                    set: { fanController.setManualSpeed(Int($0)) }
                ), in: minRPM...maxRPM, step: 50)
                HStack {
                    Text("\(fanController.fanMinRPM)")
                    Spacer()
                    Text("\(fanController.fanMaxRPM)")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
    }

    private var thermalSection: some View {
        SettingsSection(title: "Thermal", icon: "thermometer.medium") {
            LabeledContent {
                Text(thermalMonitor.thermalPressureLevel.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            } label: {
                Label(thermalMonitor.thermalPressureLevel.rawValue, systemImage: thermalMonitor.thermalPressureLevel.icon)
                    .foregroundStyle(thermalMonitor.thermalPressureLevel.color)
            }
        }
    }

    private var coreBars: some View {
        HStack(spacing: 2) {
            ForEach(systemMonitor.coreUsages) { core in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(core.isEfficiencyCore ? Color.secondary.opacity(0.7) : Color.accentColor.opacity(0.8))
                    .frame(width: 4)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .frame(height: 20)
                    .overlay {
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 1, style: .continuous)
                                .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.35))
                                .frame(height: geo.size.height * (1 - CGFloat(core.usage / 100.0)), alignment: .top)
                        }
                    }
            }
        }
        .frame(height: 20)
    }

    private var batteryIcon: String {
        let level = batteryMonitor.batteryInfo.chargeLevel
        if batteryMonitor.batteryInfo.isCharging { return "battery.100.bolt" }
        if level > 0.8 { return "battery.100" }
        if level > 0.5 { return "battery.50" }
        if level > 0.2 { return "battery.25" }
        return "battery.0"
    }

    private var batteryTint: Color {
        let level = batteryMonitor.batteryInfo.chargeLevel
        if level < 0.2 { return .red }
        if level < 0.5 { return .orange }
        return .green
    }

    private func applyUpdateInterval(_ interval: Double) {
        settings.updateInterval = interval
        SystemMonitor.shared.startMonitoring(interval: interval)
        ProcessMonitor.shared.startMonitoring(interval: interval)
        settings.save()
    }

    private func openSettingsShortcut() {
        openSettings()
        AppWindows.presentSettings()
    }

    private func openProcesses() {
        AppWindows.openProcesses(using: openWindow)
    }

    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
