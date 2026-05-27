import Foundation
import Observation

@Observable
final class ProcessMonitor {
    static let shared = ProcessMonitor()

    var topProcesses: [ProcessInfo] = []
    var processCount: Int = 0
    var threadCount: Int = 0

    private var timer: Timer?
    private var updateInterval: TimeInterval = 2.0
    private var previousProcessTimes: [Int32: (totalTime: UInt64, timestamp: Date)] = [:]
    private var previousHostTotalTime: UInt64 = 0
    private var previousHostTimestamp: Date = Date()

    private init() {
        startMonitoring()
    }

    func startMonitoring(interval: TimeInterval = 2.0) {
        updateInterval = interval
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateProcesses()
        }
        timer?.fire()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func updateProcesses() {
        let PROC_ALL_PIDS: UInt32 = 1
        let PROC_PIDTASKINFO: Int32 = 4
        let MAX_PATH: UInt32 = 2048

        let count = proc_listpids(PROC_ALL_PIDS, 0, nil, 0)
        guard count > 0 else { return }

        let pidsCapacity = Int(count)
        var pids = [Int32](repeating: 0, count: pidsCapacity)
        let bytesReturned = proc_listpids(PROC_ALL_PIDS, 0, &pids, Int32(pidsCapacity * MemoryLayout<Int32>.size))
        let actualPidsCount = Int(bytesReturned) / MemoryLayout<Int32>.size

        let now = Date()
        var hostTotalTime: UInt64 = 0
        var processData: [(pid: Int32, name: String, totalTime: UInt64, memory: UInt64, isSystem: Bool)] = []

        for i in 0..<actualPidsCount {
            let pid = pids[i]
            if pid <= 0 { continue }

            var taskInfo = proc_taskinfo(
                pti_virtual_size: 0, pti_resident_size: 0, pti_total_user: 0, pti_total_system: 0,
                pti_threads_user: 0, pti_threads_system: 0, pti_policy: 0, pti_faults: 0, pti_pageins: 0,
                pti_cow_faults: 0, pti_messages_sent: 0, pti_messages_received: 0, pti_syscalls_mach: 0,
                pti_syscalls_unix: 0, pti_csw: 0, pti_threadnum: 0, pti_numrunning: 0, pti_priority: 0
            )
            let taskSize = Int32(MemoryLayout<proc_taskinfo>.size)
            let taskResult = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, taskSize)
            guard taskResult > 0 else { continue }

            let totalCPUTime = taskInfo.pti_total_user + taskInfo.pti_total_system
            hostTotalTime += totalCPUTime

            let nameBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: Int(MAX_PATH))
            nameBuffer.initialize(to: 0)
            defer { nameBuffer.deallocate() }
            let nameResult = proc_name(pid, nameBuffer, MAX_PATH)
            let processName = nameResult > 0 ? String(cString: nameBuffer) : ""
            if processName.isEmpty || processName == "kernel_task" || processName == "SiliconPulse" { continue }

            let isSystem = isSystemProcess(pid: pid)
            processData.append((pid: pid, name: processName, totalTime: totalCPUTime, memory: taskInfo.pti_resident_size, isSystem: isSystem))
        }

        // Calculate CPU % against host total time
        var processes: [ProcessInfo] = []
        if previousHostTotalTime > 0 && hostTotalTime >= previousHostTotalTime && previousHostTimestamp != now {
            let hostDelta = Double(hostTotalTime - previousHostTotalTime)
            let timeDelta = now.timeIntervalSince(previousHostTimestamp)

            if hostDelta > 0 && timeDelta > 0 {
                let numCores = Double(Foundation.ProcessInfo.processInfo.processorCount)
                let scale = 100.0 / hostDelta

                processes = processData.map { data in
                    var cpu: Double = 0
                    if let prev = previousProcessTimes[data.pid], data.totalTime >= prev.totalTime {
                        let procDelta = Double(data.totalTime - prev.totalTime)
                        cpu = procDelta * scale
                        cpu = min(max(cpu, 0), 100 * numCores)
                    }
                    return ProcessInfo(
                        id: data.pid,
                        name: data.name,
                        cpuUsage: cpu,
                        memoryUsage: data.memory,
                        isSystemProcess: data.isSystem
                    )
                }
            } else {
                processes = processData.map { data in
                    ProcessInfo(id: data.pid, name: data.name, cpuUsage: 0, memoryUsage: data.memory, isSystemProcess: data.isSystem)
                }
            }
        } else {
            processes = processData.map { data in
                ProcessInfo(id: data.pid, name: data.name, cpuUsage: 0, memoryUsage: data.memory, isSystemProcess: data.isSystem)
            }
        }

        previousProcessTimes = processData.reduce(into: [:]) { dict, data in
            dict[data.pid] = (totalTime: data.totalTime, timestamp: now)
        }

        previousHostTotalTime = hostTotalTime
        previousHostTimestamp = now

        let top = Array(processes.sorted { $0.cpuUsage > $1.cpuUsage }.prefix(10))
        topProcesses = top
        processCount = actualPidsCount

        var tCount: UInt32 = 0
        var tSize = MemoryLayout<UInt32>.size
        if sysctlbyname("hw.nthreads", &tCount, &tSize, nil, 0) == 0 {
            threadCount = Int(tCount)
        }
    }

    private func isSystemProcess(pid: Int32) -> Bool {
        var bsdInfo = proc_bsdinfo(
            pbi_flags: 0, pbi_status: 0, pbi_xstatus: 0, pbi_pid: 0, pbi_ppid: 0,
            pbi_uid: 0, pbi_gid: 0, pbi_ruid: 0, pbi_rgid: 0, pbi_svuid: 0, pbi_svgid: 0,
            rfu_1: 0, pbi_comm: (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
            pbi_name: (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
            pbi_namelen: 0, pbi_pgshd: 0
        )
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        let result = proc_pidinfo(pid, 3, 0, &bsdInfo, size)
        guard result > 0 else { return false }
        return bsdInfo.pbi_uid == 0
    }

    deinit { stopMonitoring() }
}

struct proc_bsdinfo {
    var pbi_flags: UInt32
    var pbi_status: UInt32
    var pbi_xstatus: UInt32
    var pbi_pid: UInt32
    var pbi_ppid: UInt32
    var pbi_uid: UInt32
    var pbi_gid: UInt32
    var pbi_ruid: UInt32
    var pbi_rgid: UInt32
    var pbi_svuid: UInt32
    var pbi_svgid: UInt32
    var rfu_1: UInt32
    var pbi_comm: (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar)
    var pbi_name: (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar)
    var pbi_namelen: UInt32
    var pbi_pgshd: UInt32
}

@_silgen_name("proc_listpids")
func proc_listpids(_ type: UInt32, _ typeinfo: UInt32, _ buffer: UnsafeMutableRawPointer?, _ buffersize: Int32) -> Int32

@_silgen_name("proc_name")
func proc_name(_ pid: Int32, _ buffer: UnsafeMutablePointer<CChar>, _ buffersize: UInt32) -> Int32

@_silgen_name("proc_pidinfo")
func proc_pidinfo(_ pid: Int32, _ flavor: Int32, _ arg: UInt64, _ buffer: UnsafeMutableRawPointer?, _ buffersize: Int32) -> Int32
