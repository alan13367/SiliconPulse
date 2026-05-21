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
                        ToolbarItem(placement: .primaryAction) {
                            Button(role: .destructive) {
                                processToKill = process
                                showKillConfirmation = true
                            } label: {
                                Label("Kill Process", systemImage: "xmark.shield.fill")
                            }
                            .buttonStyle(.borderedProminent)
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
                .onChange(of: settings.processSortBy) { settings.save() }
            }
            ToolbarItem {
                Button {
                    ProcessMonitor.shared.updateProcesses()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh process list")
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
            kill(pid, SIGKILL)
        }
        selectedProcess = nil
    }
}

struct ProcessRow: View {
    let process: ProcessInfo

    var body: some View {
        HStack {
            Label(process.name, systemImage: process.isSystemProcess ? "gearshape.fill" : "app")
                .labelStyle(.titleOnly)
                .lineLimit(1)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Formatters.percentage(process.cpuUsage))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DesignTokens.usageTint(process.cpuUsage))
                Text(Formatters.bytes(process.memoryUsage))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(process.name), CPU \(Formatters.percentage(process.cpuUsage)), memory \(Formatters.bytes(process.memoryUsage))")
    }
}

struct ProcessDetailView: View {
    let process: ProcessInfo

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.sectionSpacing) {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(process.name)
                        .font(.title2.weight(.semibold))
                    Text("Process ID \(process.id)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            } icon: {
                Image(systemName: "app.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .labelStyle(.titleAndIcon)

            Divider()

            VStack(alignment: .leading, spacing: DesignTokens.rowSpacing) {
                LabeledContent("CPU Usage") {
                    Text(Formatters.percentage(process.cpuUsage))
                        .monospacedDigit()
                        .foregroundStyle(DesignTokens.usageTint(process.cpuUsage))
                }
                UsageGauge(value: process.cpuUsage, showLabel: false)

                LabeledContent("Memory") {
                    Text(Formatters.bytes(process.memoryUsage))
                        .monospacedDigit()
                }
                LabeledContent("Kind") {
                    Text(process.isSystemProcess ? "System" : "User")
                }
            }
            .font(.body)

            Spacer()
        }
        .padding(DesignTokens.panelPadding)
        .frame(minWidth: 300)
    }
}
