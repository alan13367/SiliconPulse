import SwiftUI

struct ProcessWindowView: View {
    @Environment(ProcessMonitor.self) var processMonitor
    @State var settings = SettingsManager.shared
    @State private var searchText: String = ""
    @State private var selectedProcess: ProcessInfo.ID? = nil
    @State private var showKillConfirmation: Bool = false
    @State private var processToKill: ProcessInfo? = nil

    private var filteredProcesses: [ProcessInfo] {
        let sorted: [ProcessInfo]
        switch settings.processSortBy {
        case .cpu:
            sorted = processMonitor.topProcesses.sorted { $0.cpuUsage > $1.cpuUsage }
        case .memory:
            sorted = processMonitor.topProcesses.sorted { $0.memoryUsage > $1.memoryUsage }
        case .name:
            sorted = processMonitor.topProcesses.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        if searchText.isEmpty { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedProcess) {
                Section {
                    ForEach(filteredProcesses) { process in
                        ProcessRow(process: process)
                            .tag(process.id)
                    }
                } header: {
                    Text("\(processMonitor.processCount) processes, \(processMonitor.threadCount) threads")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.sidebar)
            .searchable(text: $searchText, placement: .sidebar)
        } detail: {
            if let pid = selectedProcess,
               let process = processMonitor.topProcesses.first(where: { $0.id == pid }) {
                ProcessDetailView(process: process)
                    .toolbar {
                        ToolbarItem {
                            Button(role: .destructive) {
                                processToKill = process
                                showKillConfirmation = true
                            } label: {
                                Label("Kill", systemImage: "xmark.shield.fill")
                            }
                            .disabled(process.id == 0)
                        }
                    }
            } else {
                ContentUnavailableView("Select a process", systemImage: "list.bullet.rectangle")
            }
        }
        .navigationTitle("Top Processes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Sort", selection: $settings.processSortBy) {
                    ForEach(SettingsManager.ProcessSort.allCases, id: \.self) { sort in
                        Text(sort.rawValue).tag(sort)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            ToolbarItem {
                Button {
                    ProcessMonitor.shared.updateProcesses()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .confirmationDialog("Kill process?", isPresented: $showKillConfirmation, titleVisibility: .visible) {
            Button("Kill \(processToKill?.name ?? "")", role: .destructive) {
                if let proc = processToKill {
                    killProcess(pid: proc.id)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will forcefully terminate the selected process. Unsaved data may be lost.")
        }
    }

    private func killProcess(pid: Int32) {
        let result = kill(pid, SIGTERM)
        if result != 0 {
            // Fallback to SIGKILL
            kill(pid, SIGKILL)
        }
        selectedProcess = nil
    }
}

struct ProcessRow: View {
    let process: ProcessInfo

    var body: some View {
        HStack {
            Image(systemName: process.isSystemProcess ? "gearshape.fill" : "app")
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(process.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Text("PID: \(process.id)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(String(format: "%.1f%%", process.cpuUsage))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.accentColor)
                Text(Formatters.bytes(process.memoryUsage))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct ProcessDetailView: View {
    let process: ProcessInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "app.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(process.name)
                        .font(.title2)
                    Text("PID: \(process.id)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
                GridRow {
                    DetailItem(label: "CPU Usage", value: String(format: "%.1f%%", process.cpuUsage))
                    DetailItem(label: "Memory", value: Formatters.bytes(process.memoryUsage))
                }
                GridRow {
                    DetailItem(label: "Kind", value: process.isSystemProcess ? "System" : "User")
                    DetailItem(label: "PID", value: "\(process.id)")
                }
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 300)
    }
}

struct DetailItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospacedDigit())
        }
    }
}
