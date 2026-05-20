import SwiftUI
import Charts

struct MenuBarView: View {
    @Environment(SystemMonitor.self) var systemMonitor
    @Environment(GPUMonitor.self) var gpuMonitor
    @Environment(NetworkMonitor.self) var networkMonitor
    @Environment(ThermalMonitor.self) var thermalMonitor
    @Environment(BatteryMonitor.self) var batteryMonitor
    @Environment(DiskMonitor.self) var diskMonitor
    @Environment(FanController.self) var fanController
    @Environment(SettingsManager.self) var settings

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 12) {
                    cpuSection
                    if gpuMonitor.gpuAvailable { gpuSection }
                    memorySection
                    if settings.showNetworkDetails { networkSection }
                    if settings.showDiskInfo { diskSection }
                    if settings.showBatteryInfo && batteryMonitor.batteryInfo.isPresent { batterySection }
                    if settings.showFanControl { fanSection }
                    if settings.showThermalInfo { thermalSection }
                }
                .padding()
            }
            .frame(height: 520)
            Divider()
            footer
        }
        .frame(width: 400)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "cpu.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("SiliconPulse")
                .font(.headline)
            Spacer()
            Text(systemMonitor.systemInfo.chipName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - CPU Section

    private var cpuSection: some View {
        DashboardCard(title: "CPU", icon: "cpu", color: .accentColor) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    MetricValue(value: systemMonitor.cpuUsage, unit: "%")
                    Spacer()
                    if systemMonitor.temperatureAvailable {
                        TemperatureBadge(temperature: systemMonitor.currentTemperature, useFahrenheit: settings.useFahrenheit)
                    }
                }
                ProgressView(value: systemMonitor.cpuUsage, total: 100)
                    .tint(usageColor(systemMonitor.cpuUsage))

                if !systemMonitor.cpuHistory.isEmpty {
                    SparklineChart(data: systemMonitor.cpuHistory, color: .accentColor, yDomain: 0...100)
                }

                if settings.showCoreDetails && !systemMonitor.coreUsages.isEmpty {
                    coreBars
                }
            }
        }
    }

    @ViewBuilder
    private var gpuSection: some View {
        DashboardCard(title: "GPU", icon: "bolt.fill", color: .green) {
            VStack(alignment: .leading, spacing: 8) {
                MetricValue(value: gpuMonitor.gpuUsage, unit: "%")
                ProgressView(value: gpuMonitor.gpuUsage, total: 100)
                    .tint(usageColor(gpuMonitor.gpuUsage))
                if !gpuMonitor.gpuHistory.isEmpty {
                    SparklineChart(data: gpuMonitor.gpuHistory, color: .green, yDomain: 0...100)
                }
            }
        }
    }

    private var memorySection: some View {
        DashboardCard(title: "Memory", icon: "memorychip", color: .purple) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(systemMonitor.memoryDetails.formattedString)
                        .font(.headline.monospacedDigit())
                    Spacer()
                    Text(Formatters.percentage(systemMonitor.memoryUsage))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.purple)
                }
                ProgressView(value: systemMonitor.memoryUsage, total: 100)
                    .tint(usageColor(systemMonitor.memoryUsage))
                if !systemMonitor.memoryHistory.isEmpty {
                    SparklineChart(data: systemMonitor.memoryHistory, color: .purple, yDomain: 0...100)
                }
                if settings.showMemoryDetails {
                    memoryBreakdown
                }
            }
        }
    }

    private var memoryBreakdown: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 4) {
            GridRow {
                detailPill("App", Formatters.bytes(systemMonitor.memoryDetails.appMemory), .blue)
                detailPill("Wired", Formatters.bytes(systemMonitor.memoryDetails.wiredMemory), .orange)
            }
            GridRow {
                detailPill("Compressed", Formatters.bytes(systemMonitor.memoryDetails.compressedMemory), .pink)
                detailPill("Free", Formatters.bytes(systemMonitor.memoryDetails.free), .green)
            }
        }
        .font(.caption)
    }

    private var networkSection: some View {
        DashboardCard(title: "Network", icon: "network", color: .teal) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    networkLabel("arrow.down.circle.fill", "Download", networkMonitor.networkDownloadSpeed, .green)
                    Spacer()
                    networkLabel("arrow.up.circle.fill", "Upload", networkMonitor.networkUploadSpeed, .blue)
                }
                if !networkMonitor.networkHistory.isEmpty {
                    SparklineChart(data: networkMonitor.networkHistory.map { $0.download }, color: .green)
                }
                HStack {
                    Text("Session: \(Formatters.bytes(UInt64(networkMonitor.totalDownloadSession))) ↓")
                        .font(.caption2)
                    Spacer()
                    Text("\(Formatters.bytes(UInt64(networkMonitor.totalUploadSession))) ↑")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    private var diskSection: some View {
        DashboardCard(title: "Storage", icon: "internaldrive", color: .orange) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(diskMonitor.volumes) { volume in
                    HStack {
                        Image(systemName: volume.isBootVolume ? "internaldrive" : "externaldrive")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(volume.name)
                                .font(.subheadline)
                            Text("\(Formatters.bytes(volume.availableBytes)) free / \(Formatters.bytes(volume.totalBytes))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Formatters.percentage(volume.usagePercent))
                            .font(.caption.monospacedDigit())
                    }
                    ProgressView(value: volume.usagePercent, total: 100)
                        .tint(usageColor(volume.usagePercent))
                }
            }
        }
    }

    private var batterySection: some View {
        DashboardCard(title: "Power", icon: "battery.100", color: .yellow) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: batteryIcon)
                        .foregroundStyle(batteryColor)
                    Text("\(Int(batteryMonitor.batteryInfo.chargeLevel * 100))%")
                        .font(.headline.monospacedDigit())
                    Spacer()
                    if batteryMonitor.batteryInfo.timeRemaining >= 0 {
                        Text(Formatters.timeRemaining(batteryMonitor.batteryInfo.timeRemaining))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                ProgressView(value: batteryMonitor.batteryInfo.chargeLevel * 100, total: 100)
                    .tint(batteryColor)
                HStack {
                    Text("Cycles: \(batteryMonitor.batteryInfo.cycleCount)")
                    Spacer()
                    Text("Health: \(Formatters.percentage(batteryMonitor.batteryInfo.healthPercent))")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var fanSection: some View {
        DashboardCard(title: "Fans", icon: "fan", color: .cyan) {
            VStack(alignment: .leading, spacing: 8) {
                if !fanController.isAvailable {
                    Text("Fan control not available on this Mac")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if fanController.fanCount == 0 {
                    Text("No fans detected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(0..<fanController.fanCount, id: \.self) { i in
                        HStack {
                            Text(fanController.fanNames[safe: i] ?? "Fan #\(i + 1)")
                                .font(.subheadline)
                            Spacer()
                            Text("\(fanController.fanSpeeds[safe: i] ?? 0) RPM")
                                .font(.subheadline.monospacedDigit())
                        }
                    }
                    #if arch(arm64)
                    if !fanController.helperInstalled {
                        Button("Install Fan Helper (requires password)") {
                            _ = fanController.installHelperIfNeeded()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
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
        Group {
            HStack(spacing: 8) {
                ForEach(FanController.FanMode.allCases, id: \.self) { mode in
                    Button(mode.rawValue) {
                        fanController.setMode(mode)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .tint(fanController.mode == mode ? .accentColor : .secondary)
                }
            }
            if fanController.mode == .manual {
                let minRPM = Double(fanController.fanMinRPM)
                let maxRPM = Double(max(fanController.fanMaxRPM, fanController.fanMinRPM))
                HStack(spacing: 8) {
                    Text("\(fanController.fanMinRPM)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                    Slider(value: .init(
                        get: { Double(fanController.targetFanSpeed) },
                        set: { fanController.setManualSpeed(Int($0)) }
                    ), in: minRPM...maxRPM, step: 50)
                    .controlSize(.small)
                    Text("\(fanController.fanMaxRPM)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .leading)
                }
                Text("\(fanController.targetFanSpeed) RPM target")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var thermalSection: some View {
        DashboardCard(title: "Thermal", icon: "thermometer", color: .red) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: thermalMonitor.thermalPressureLevel.icon)
                        .foregroundStyle(thermalMonitor.thermalPressureLevel.color)
                    Text(thermalMonitor.thermalPressureLevel.rawValue)
                        .font(.subheadline)
                }
                Spacer()
                Text(thermalMonitor.thermalPressureLevel.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var footer: some View {
        HStack {
            Menu {
                ForEach([1.0, 2.0, 5.0], id: \.self) { interval in
                    Button("\(Int(interval)) s") {
                        settings.updateInterval = interval
                        SystemMonitor.shared.startMonitoring(interval: interval)
                        ProcessMonitor.shared.startMonitoring(interval: interval)
                        settings.save()
                    }
                }
            } label: {
                Text("Rate: \(Int(settings.updateInterval))s")
                    .font(.caption)
            }
            .menuStyle(.borderedButton)
            .controlSize(.small)

            Spacer()

            Button(action: openProcessesWindow) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 14))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Open Top Processes")

            SettingsLink {
                Image(systemName: "gear")
                    .font(.system(size: 14))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(action: quit) {
                Image(systemName: "power")
                    .font(.system(size: 14))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(.ultraThinMaterial)
    }

    private var coreBars: some View {
        HStack(spacing: 2) {
            ForEach(systemMonitor.coreUsages) { core in
                RoundedRectangle(cornerRadius: 1)
                    .fill(core.isEfficiencyCore ? Color.green.opacity(0.8) : Color.accentColor.opacity(0.8))
                    .frame(width: 4)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .frame(height: 20)
                    .overlay(
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .frame(height: geo.size.height * (1 - CGFloat(core.usage / 100.0)), alignment: .top)
                        }
                    )
            }
        }
        .frame(height: 20)
    }

    private func detailPill(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption.monospacedDigit())
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func networkLabel(_ icon: String, _ title: String, _ speed: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon).foregroundStyle(color)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Text(Formatters.networkSpeed(speed, useBits: settings.useBitsPerSecond))
                .font(.subheadline.monospacedDigit())
        }
    }

    private var batteryIcon: String {
        let level = batteryMonitor.batteryInfo.chargeLevel
        if batteryMonitor.batteryInfo.isCharging { return "battery.100.bolt" }
        if level > 0.8 { return "battery.100" }
        if level > 0.5 { return "battery.50" }
        if level > 0.2 { return "battery.25" }
        return "battery.0"
    }

    private var batteryColor: Color {
        let level = batteryMonitor.batteryInfo.chargeLevel
        if level < 0.2 { return .red }
        if level < 0.5 { return .yellow }
        return .green
    }

    private func usageColor(_ value: Double) -> Color {
        if value < 50 { return .green }
        if value < 80 { return .orange }
        return .red
    }

    private func openProcessesWindow() {
        NSApp.sendAction(#selector(NSWindow.makeKeyAndOrderFront(_:)), to: nil, from: nil)
        if let window = NSApp.windows.first(where: { $0.title == "Top Processes" }) {
            window.makeKeyAndOrderFront(nil)
        }
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
