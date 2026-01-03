//
//  MenuBarView.swift
//  SiliconPulse
//
//  Created by Alan on 31/12/25.
//

import SwiftUI
import Charts

struct MenuBarView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    @EnvironmentObject var thermalMonitor: ThermalMonitor
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView()
                .padding()
                .background(Material.ultraThin)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 16) {
                    // CPU Section with Chart
                    DashboardSection(title: "CPU & GPU", icon: "cpu", color: .blue) {
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("CPU")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(Int(systemMonitor.cpuUsage))%")
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text("GPU")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(Int(systemMonitor.gpuUsage))%")
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                }
                            }
                            
                            // Combined History Chart
                            if !systemMonitor.cpuHistory.isEmpty {
                                Chart {
                                    ForEach(Array(systemMonitor.cpuHistory.enumerated()), id: \.offset) { index, value in
                                        LineMark(
                                            x: .value("Time", index),
                                            y: .value("Usage", value)
                                        )
                                        .foregroundStyle(.blue)
                                        .interpolationMethod(.catmullRom)
                                    }
                                    
                                    ForEach(Array(systemMonitor.gpuHistory.enumerated()), id: \.offset) { index, value in
                                        LineMark(
                                            x: .value("Time", index),
                                            y: .value("Usage", value)
                                        )
                                        .foregroundStyle(.green)
                                        .interpolationMethod(.catmullRom)
                                    }
                                }
                                .chartYScale(domain: 0...100)
                                .chartXAxis(.hidden)
                                .chartYAxis(.hidden)
                                .frame(height: 60)
                            }
                        }
                    }
                    
                    // Cores Grid
                    if settingsManager.showCoreDetails {
                        DashboardSection(title: "Cores", icon: "square.grid.3x3.fill", color: .indigo) {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 8) {
                                ForEach(systemMonitor.coreUsages) { core in
                                    VStack(spacing: 2) {
                                        Text("C\(core.id)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        
                                        ZStack(alignment: .bottom) {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.secondary.opacity(0.2))
                                                .frame(height: 30)
                                            
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(core.isEfficiencyCore ? Color.green : Color.orange)
                                                .frame(height: 30 * (core.usage / 100.0))
                                        }
                                        .frame(width: 12)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                    
                    // Memory Section
                    DashboardSection(title: "Memory", icon: "memorychip", color: .purple) {
                        VStack(spacing: 12) {
                            HStack {
                                Text(systemMonitor.memoryDetails.formattedString)
                                    .font(.headline)
                                Spacer()
                                Text("\(Int(systemMonitor.memoryUsage))%")
                                    .font(.headline)
                                    .foregroundColor(.purple)
                            }
                            
                            Gauge(value: systemMonitor.memoryUsage, in: 0...100) {
                            } currentValueLabel: {
                            }
                            .tint(.purple)
                            
                            if !systemMonitor.memoryHistory.isEmpty {
                                Chart(Array(systemMonitor.memoryHistory.enumerated()), id: \.offset) { index, value in
                                    LineMark(
                                        x: .value("Time", index),
                                        y: .value("Usage", value)
                                    )
                                    .foregroundStyle(.purple)
                                    .interpolationMethod(.stepCenter)
                                }
                                .chartYScale(domain: 0...100)
                                .chartXAxis(.hidden)
                                .chartYAxis(.hidden)
                                .frame(height: 30)
                            }
                            
                            // Memory Breakdown
                            if settingsManager.showMemoryDetails {
                                Grid(horizontalSpacing: 12, verticalSpacing: 6) {
                                    GridRow {
                                        DetailPill(label: "App", value: formatBytes(systemMonitor.memoryDetails.appMemory), color: .blue)
                                        DetailPill(label: "Wired", value: formatBytes(systemMonitor.memoryDetails.wiredMemory), color: .orange)
                                    }
                                    GridRow {
                                        DetailPill(label: "Comp", value: formatBytes(systemMonitor.memoryDetails.compressedMemory), color: .pink)
                                        DetailPill(label: "Free", value: formatBytes(systemMonitor.memoryDetails.total - systemMonitor.memoryDetails.used), color: .green)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Thermal
                    if settingsManager.showThermalInfo {
                        DashboardSection(title: "Thermal", icon: "thermometer", color: .red) {
                            HStack {
                                Image(systemName: thermalMonitor.thermalPressureLevel.icon)
                                    .font(.title2)
                                    .foregroundColor(thermalMonitor.thermalPressureLevel.color)

                                VStack(alignment: .leading) {
                                    Text(thermalMonitor.thermalPressureLevel.rawValue)
                                        .font(.headline)
                                    Text(thermalMonitor.thermalPressureLevel.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }

                    // Network Section
                    DashboardSection(title: "Network", icon: "network", color: .teal) {
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .foregroundColor(.green)
                                        Text("Download")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Text(formatNetworkSpeed(networkMonitor.networkDownloadSpeed))
                                        .font(.headline.monospacedDigit())
                                }

                                Spacer()

                                VStack(alignment: .trailing) {
                                    HStack(spacing: 4) {
                                        Text("Upload")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Image(systemName: "arrow.up.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                    Text(formatNetworkSpeed(networkMonitor.networkUploadSpeed))
                                        .font(.headline.monospacedDigit())
                                }
                            }

                            if !networkMonitor.networkHistory.isEmpty {
                                Chart(Array(networkMonitor.networkHistory.enumerated()), id: \.offset) { index, speed in
                                    AreaMark(
                                        x: .value("Time", index),
                                        y: .value("Download", speed.download / 1_000_000)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.green.opacity(0.4), .green.opacity(0.05)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .interpolationMethod(.catmullRom)

                                    LineMark(
                                        x: .value("Time", index),
                                        y: .value("Download", speed.download / 1_000_000)
                                    )
                                    .foregroundStyle(.green)
                                    .interpolationMethod(.catmullRom)

                                    LineMark(
                                        x: .value("Time", index),
                                        y: .value("Upload", speed.upload / 1_000_000)
                                    )
                                    .foregroundStyle(.blue)
                                    .interpolationMethod(.catmullRom)
                                }
                                .chartYAxis(.hidden)
                                .chartXAxis(.hidden)
                                .frame(height: 50)
                            }
                            
                            // Session Data
                            HStack {
                                Label("Session: \(formatBytes(UInt64(networkMonitor.totalDownloadSession))) ↓", systemImage: "arrow.down.circle")
                                Spacer()
                                Label("\(formatBytes(UInt64(networkMonitor.totalUploadSession))) ↑", systemImage: "arrow.up.circle")
                            }
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                    }

                    // Quick Actions
                    DashboardSection(title: "Top Processes", icon: "list.bullet", color: .secondary) {
                        VStack(spacing: 8) {
                            ForEach(systemMonitor.topProcesses) { process in
                                HStack {
                                    Text(process.name)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(formatBytes(process.memoryUsage))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundColor(.secondary)
                                }
                            }
                            if systemMonitor.topProcesses.isEmpty {
                                Text("No data available")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Top Processes
                    DashboardSection(title: "Top Processes", icon: "list.bullet", color: .secondary) {
                        VStack(spacing: 8) {
                            ForEach(systemMonitor.topProcesses) { process in
                                HStack {
                                    Text(process.name)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(formatBytes(process.memoryUsage))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundColor(.secondary)
                                }
                            }
                            if systemMonitor.topProcesses.isEmpty {
                                Text("No data available")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Quick Actions
                    QuickActionsSection()
                }
                .padding()
            }
            .frame(height: 600)
            
            Divider()
            
            FooterView()
                .padding(10)
                .background(Material.ultraThin)
        }
        .frame(width: 440) // Wider window
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowedUnits = [.useGB, .useMB]
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func formatNetworkSpeed(_ bytesPerSecond: Double) -> String {
        let formatter = ByteCountFormatter()
        if settingsManager.useBitsPerSecond {
            let bitsPerSecond = Int64(bytesPerSecond * 8)
            return "\(ByteCountFormatter.string(fromByteCount: bitsPerSecond, countStyle: .binary).replacingOccurrences(of: "B", with: "b"))ps"
        }
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        return "\(formatter.string(fromByteCount: Int64(bytesPerSecond)))/s"
    }
}

struct HeaderView: View {
    var body: some View {
        HStack {
            Image(systemName: "cpu.fill")
                .font(.title2)
                .foregroundColor(.blue)
            Text("SiliconPulse")
                .font(.title3)
                .fontWeight(.bold)
                .fontDesign(.rounded)
            Spacer()
        }
    }
}

// MARK: - Components

struct DashboardSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                } icon: {
                    Image(systemName: icon)
                        .foregroundColor(color)
                }
                Spacer()
            }
            
            content
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}

struct DetailPill: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
}

struct FooterView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        HStack {
            Menu {
                ForEach([1.0, 2.0, 5.0], id: \.self) { interval in
                    Button("\(Int(interval))s Update") {
                        settingsManager.updateInterval = interval
                        SystemMonitor.shared.updateInterval(interval)
                    }
                }
            } label: {
                Text("Rate: \(Int(settingsManager.updateInterval))s")
                    .font(.caption)
            }
            .menuStyle(.borderedButton)
            .controlSize(.small)
            
            Spacer()
            
            SettingsLink {
                Image(systemName: "gear")
                    .font(.system(size: 14))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

struct QuickActionsSection: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: { SystemMonitor.shared.startMonitoring() }) {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            
            Button(action: { NSApplication.shared.terminate(nil) }) {
                Label("Quit", systemImage: "power")
                    .frame(maxWidth: .infinity)
            }
        }
        .controlSize(.large)
    }
}
