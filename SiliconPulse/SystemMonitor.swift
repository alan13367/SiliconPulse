import Foundation
import Combine
import SwiftUI
import IOKit

struct CoreUsage: Identifiable {
    let id: Int
    let usage: Double
    let isEfficiencyCore: Bool

    var color: Color {
        switch usage {
        case 0..<50: return .green
        case 50..<80: return .yellow
        default: return .red
        }
    }
}

struct ProcessInfoData: Identifiable {
    let id: Int32
    let name: String
    let cpuUsage: Double
    let memoryUsage: UInt64
}

struct MemoryDetails {
    var used: UInt64 = 0
    var total: UInt64 = 0
    var appMemory: UInt64 = 0
    var wiredMemory: UInt64 = 0
    var compressedMemory: UInt64 = 0

    var usedGB: Double {
        Double(used) / 1_073_741_824.0
    }

    var totalGB: Double {
        Double(total) / 1_073_741_824.0
    }

    var formattedString: String {
        String(format: "%.1f/%.1f GB", usedGB, totalGB)
    }
}

class SystemMonitor: ObservableObject {
    static let shared = SystemMonitor()

    @Published var cpuUsage: Double = 0.0
    @Published var gpuUsage: Double = 0.0
    @Published var memoryUsage: Double = 0.0
    @Published var memoryDetails: MemoryDetails = MemoryDetails()
    @Published var coreUsages: [CoreUsage] = []
    @Published var efficiencyCoreUsages: [Double] = []
    @Published var performanceCoreUsages: [Double] = []
    @Published var topProcesses: [ProcessInfoData] = []
    @Published var processCount: Int = 0
    @Published var currentTemperature: Double = 0.0

    @Published var threadCount: Int = 0
    @Published var uptime: TimeInterval = 0

    @Published var cpuHistory: [Double] = Array(repeating: 0, count: 60)
    @Published var gpuHistory: [Double] = Array(repeating: 0, count: 60)
    @Published var memoryHistory: [Double] = Array(repeating: 0, count: 60)

    private var timer: Timer?
    private var updateInterval: TimeInterval = 2.0
    private var host: mach_port_t
    private var processorInfo: processor_info_array_t?
    private var processorInfoCount: mach_msg_type_number_t = 0
    private var previousProcessorInfo: [Int32] = []
    private var previousLoad: host_cpu_load_info?
    
    private var previousProcessTimes: [Int32: UInt64] = [:]
    private var lastUpdateTimestamp: Date = Date()

    private init() {
        self.host = mach_host_self()
        setupCoreCounts()
        startMonitoring()
    }

    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updateSystemStats()
        }
        timer?.fire()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func updateInterval(_ interval: TimeInterval) {
        updateInterval = interval
        startMonitoring()
    }

    private func setupCoreCounts() {
        let processInfo = ProcessInfo.processInfo
        let activeCores = processInfo.activeProcessorCount

        var efficiencyCores = 0
        var performanceCores = 0

        #if arch(arm64)
        switch activeCores {
        case 8: efficiencyCores = 4; performanceCores = 4
        case 10: efficiencyCores = 2; performanceCores = 8
        case 12: efficiencyCores = 2; performanceCores = 10
        case 14, 16, 20, 24:
             efficiencyCores = 4; performanceCores = activeCores - 4
        default: efficiencyCores = activeCores / 2; performanceCores = activeCores / 2
        }
        #else
        efficiencyCores = 0
        performanceCores = activeCores
        #endif

        efficiencyCoreUsages = Array(repeating: 0.0, count: efficiencyCores)
        performanceCoreUsages = Array(repeating: 0.0, count: performanceCores)

        var cores: [CoreUsage] = []
        for i in 0..<efficiencyCores {
            cores.append(CoreUsage(id: i, usage: 0.0, isEfficiencyCore: true))
        }
        for i in 0..<performanceCores {
            cores.append(CoreUsage(id: i + efficiencyCores, usage: 0.0, isEfficiencyCore: false))
        }
        coreUsages = cores
    }

    private func updateSystemStats() {
        updateCPUUsage()
        updateGPUUsage()
        updateMemoryUsage()
        updateProcessInfo()
        updateTopProcesses()
        updateUptime()
        updateTemperature()
    }

    private func updateTemperature() {
        let kIOHIDEventTypeThermal: Int32 = 15
        let kIOHIDEventFieldThermalTemperature: Int32 = 15 << 16
        
        guard let client = IOHIDEventSystemClientCreate(kCFAllocatorDefault) else { return }
        
        let matching: [String: Any] = [
            "PrimaryUsagePage": 0xff00 as NSNumber,
            "PrimaryUsage": 0x0005 as NSNumber
        ]
        
        IOHIDEventSystemClientSetMatching(client, matching as CFDictionary)
        
        guard let services = IOHIDEventSystemClientCopyServices(client) else { return }
        
        let servicesArray = services as NSArray
        var temps: [Double] = []
        
        for i in 0..<servicesArray.count {
            let service = servicesArray[i] as AnyObject
            let servicePtr = Unmanaged.passUnretained(service).toOpaque()
            
            if let productRef = IOHIDServiceClientCopyProperty(servicePtr, "Product" as CFString) {
                let product = productRef as? String ?? ""
                if product.contains("tdie") || product.contains("temp") || product.contains("tcal") {
                    if let eventPtr = IOHIDServiceClientCopyEvent(servicePtr, kIOHIDEventTypeThermal, 0, 0) {
                        let temp = IOHIDEventGetFloatValue(eventPtr, kIOHIDEventFieldThermalTemperature)
                        if temp > 0 && temp < 150 {
                            temps.append(temp)
                        }
                    }
                }
            }
        }
        
        if !temps.isEmpty {
            let maxTemp = temps.max() ?? 0.0
            DispatchQueue.main.async {
                self.currentTemperature = maxTemp
            }
        }
    }

    private func updateTopProcesses() {
        let PROC_ALL_PIDS: UInt32 = 1
        let PROC_PIDTASKINFO: Int32 = 4
        let MAX_PATH: UInt32 = 1024
        
        let count = proc_listpids(PROC_ALL_PIDS, 0, nil, 0)
        guard count > 0 else { return }
        
        let pidsCapacity = Int(count)
        var pids = [Int32](repeating: 0, count: pidsCapacity)
        let bytesReturned = proc_listpids(PROC_ALL_PIDS, 0, &pids, Int32(pidsCapacity * MemoryLayout<Int32>.size))
        
        var processes: [ProcessInfoData] = []
        let actualPidsCount = Int(bytesReturned) / MemoryLayout<Int32>.size
        
        let now = Date()
        let timeDelta = now.timeIntervalSince(lastUpdateTimestamp)
        lastUpdateTimestamp = now
        
        for i in 0..<actualPidsCount {
            let pid = pids[i]
            if pid <= 0 { continue }
            
            let nameBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: Int(MAX_PATH))
            nameBuffer.initialize(to: 0)
            defer { nameBuffer.deallocate() }
            
            let nameResult = proc_name(pid, nameBuffer, MAX_PATH)
            let processName = nameResult > 0 ? String(cString: nameBuffer) : ""
            
            if processName.isEmpty || processName == "kernel_task" || processName == "SiliconPulse" { continue }

            var taskInfo = proc_taskinfo(pti_virtual_size: 0, pti_resident_size: 0, pti_total_user: 0, pti_total_system: 0, pti_threads_user: 0, pti_threads_system: 0, pti_policy: 0, pti_faults: 0, pti_pageins: 0, pti_cow_faults: 0, pti_messages_sent: 0, pti_messages_received: 0, pti_syscalls_mach: 0, pti_syscalls_unix: 0, pti_csw: 0, pti_threadnum: 0, pti_numrunning: 0, pti_priority: 0)
            let taskSize = Int32(MemoryLayout<proc_taskinfo>.size)
            let taskResult = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, taskSize)
            
            if taskResult > 0 {
                let totalCPUTime = taskInfo.pti_total_user + taskInfo.pti_total_system
                var cpuPercentage: Double = 0
                
                if let previousTime = previousProcessTimes[pid], timeDelta > 0 {
                    let cpuTimeDelta = totalCPUTime - previousTime
                    cpuPercentage = (Double(cpuTimeDelta) / 1_000_000_000.0) / timeDelta * 100.0
                }
                
                previousProcessTimes[pid] = totalCPUTime
                
                processes.append(ProcessInfoData(
                    id: pid,
                    name: processName,
                    cpuUsage: cpuPercentage,
                    memoryUsage: taskInfo.pti_resident_size
                ))
            }
        }
        
        let currentPids = Set(pids.prefix(actualPidsCount))
        previousProcessTimes = previousProcessTimes.filter { currentPids.contains($0.key) }
        
        let top5 = Array(processes.sorted { $0.cpuUsage > $1.cpuUsage }.prefix(5))
        
        DispatchQueue.main.async {
            self.topProcesses = top5
        }
    }

    private func updateGPUUsage() {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator)
        
        if result == KERN_SUCCESS {
            var service = IOIteratorNext(iterator)
            while service != 0 {
                if let props = getIOProperties(service: service) {
                    if let perfStats = props["PerformanceStatistics"] as? [String: Any],
                       let deviceUtil = perfStats["Device Utilization %"] as? Int {
                        DispatchQueue.main.async {
                            self.gpuUsage = Double(deviceUtil)
                            self.addToHistory(array: &self.gpuHistory, value: Double(deviceUtil))
                        }
                        IOObjectRelease(service)
                        break
                    }
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)
        }
    }

    private func getIOProperties(service: io_service_t) -> [String: Any]? {
        var properties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0)
        
        if result == KERN_SUCCESS, let properties = properties {
            return properties.takeRetainedValue() as? [String: Any]
        }
        return nil
    }

    private func updateCPUUsage() {
        var load = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &load) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            if let previous = previousLoad {
                let userTicks = Double(load.cpu_ticks.0 - previous.cpu_ticks.0)
                let systemTicks = Double(load.cpu_ticks.1 - previous.cpu_ticks.1)
                let idleTicks = Double(load.cpu_ticks.2 - previous.cpu_ticks.2)
                let niceTicks = Double(load.cpu_ticks.3 - previous.cpu_ticks.3)

                let totalTicks = userTicks + systemTicks + idleTicks + niceTicks
                let usedTicks = totalTicks - idleTicks
                let usage = totalTicks > 0 ? (usedTicks / totalTicks) * 100.0 : 0.0

                DispatchQueue.main.async {
                    self.cpuUsage = usage
                    self.addToHistory(array: &self.cpuHistory, value: usage)
                }
            }
            previousLoad = load
        }
        updateRealCoreUsages()
    }

    private func updateRealCoreUsages() {
        var numProcessors: mach_msg_type_number_t = 0
        var processorInfo: processor_info_array_t?
        var processorMsgCount: mach_msg_type_number_t = 0

        let result = host_processor_info(host,
                                         PROCESSOR_CPU_LOAD_INFO,
                                         &numProcessors,
                                         &processorInfo,
                                         &processorMsgCount)

        guard result == KERN_SUCCESS, let info = processorInfo else { return }

        let infoArray = Array(UnsafeBufferPointer(start: info, count: Int(processorMsgCount)))

        let vmSize = Int(processorMsgCount) * MemoryLayout<integer_t>.stride
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(vmSize))

        if !previousProcessorInfo.isEmpty && previousProcessorInfo.count == infoArray.count {
            var updatedCores: [CoreUsage] = []
            var newEffUsages: [Double] = []
            var newPerfUsages: [Double] = []

            let cpuLoadInfoCount = Int(CPU_STATE_MAX)

            for i in 0..<Int(numProcessors) {
                let baseIndex = i * cpuLoadInfoCount

                let user   = Double(infoArray[baseIndex + Int(CPU_STATE_USER)] - previousProcessorInfo[baseIndex + Int(CPU_STATE_USER)])
                let system = Double(infoArray[baseIndex + Int(CPU_STATE_SYSTEM)] - previousProcessorInfo[baseIndex + Int(CPU_STATE_SYSTEM)])
                let idle   = Double(infoArray[baseIndex + Int(CPU_STATE_IDLE)] - previousProcessorInfo[baseIndex + Int(CPU_STATE_IDLE)])
                let nice   = Double(infoArray[baseIndex + Int(CPU_STATE_NICE)] - previousProcessorInfo[baseIndex + Int(CPU_STATE_NICE)])

                let total = user + system + idle + nice
                let used = user + system + nice
                let usage = total > 0 ? (used / total) * 100.0 : 0.0

                if i < coreUsages.count {
                    let existingCore = coreUsages[i]
                    updatedCores.append(CoreUsage(id: existingCore.id, usage: usage, isEfficiencyCore: existingCore.isEfficiencyCore))

                    if existingCore.isEfficiencyCore {
                        newEffUsages.append(usage)
                    } else {
                        newPerfUsages.append(usage)
                    }
                }
            }

            DispatchQueue.main.async {
                self.coreUsages = updatedCores
                self.efficiencyCoreUsages = newEffUsages
                self.performanceCoreUsages = newPerfUsages
            }
        }
        previousProcessorInfo = infoArray
    }

    private func addToHistory(array: inout [Double], value: Double) {
        array.append(value)
        if array.count > 60 {
            array.removeFirst()
        }
    }

    private func updateMemoryUsage() {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return }

        let pageSize = UInt64(vm_page_size)
        let free = UInt64(vmStats.free_count) * pageSize
        let active = UInt64(vmStats.active_count) * pageSize
        let inactive = UInt64(vmStats.inactive_count) * pageSize
        let wired = UInt64(vmStats.wire_count) * pageSize
        let compressed = UInt64(vmStats.compressor_page_count) * pageSize

        let internalPages = UInt64(vmStats.internal_page_count)
        let purgeablePages = UInt64(vmStats.purgeable_count)
        let appMemory = (internalPages - purgeablePages) * pageSize
        let used = appMemory + wired + compressed

        var physicalMemory: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        if sysctlbyname("hw.memsize", &physicalMemory, &size, nil, 0) != 0 {
             physicalMemory = used + free + inactive
        }

        let usagePercentage = Double(used) / Double(physicalMemory) * 100.0

        DispatchQueue.main.async {
            self.memoryUsage = usagePercentage
            self.addToHistory(array: &self.memoryHistory, value: usagePercentage)
            self.memoryDetails = MemoryDetails(
                used: used,
                total: physicalMemory,
                appMemory: appMemory,
                wiredMemory: wired,
                compressedMemory: compressed
            )
        }
    }

    private func updateProcessInfo() {
        let count = proc_listpids(1, 0, nil, 0)
        if count > 0 {
             let processCount = Int(count) / MemoryLayout<Int32>.size
             DispatchQueue.main.async {
                 self.processCount = processCount
             }
        }

        var threadCount: UInt32 = 0
        var threadCountSize = MemoryLayout<UInt32>.size
        if sysctlbyname("hw.nthreads", &threadCount, &threadCountSize, nil, 0) == 0 {
            DispatchQueue.main.async {
                self.threadCount = Int(threadCount)
            }
        }
    }

    private func updateUptime() {
        let uptime = ProcessInfo.processInfo.systemUptime
        DispatchQueue.main.async {
            self.uptime = uptime
        }
    }

    func getFormattedUptime() -> String {
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        let seconds = Int(uptime) % 60

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }

    deinit {
        stopMonitoring()
    }
}

@_silgen_name("proc_listpids")
func proc_listpids(_ type: UInt32, _ typeinfo: UInt32, _ buffer: UnsafeMutableRawPointer?, _ buffersize: Int32) -> Int32

@_silgen_name("proc_name")
func proc_name(_ pid: Int32, _ buffer: UnsafeMutablePointer<CChar>, _ buffersize: UInt32) -> Int32

@_silgen_name("proc_pidinfo")
func proc_pidinfo(_ pid: Int32, _ flavor: Int32, _ arg: UInt64, _ buffer: UnsafeMutableRawPointer?, _ buffersize: Int32) -> Int32

@_silgen_name("IOHIDEventSystemClientCreate")
func IOHIDEventSystemClientCreate(_ allocator: CFAllocator?) -> UnsafeMutableRawPointer?

@_silgen_name("IOHIDEventSystemClientSetMatching")
func IOHIDEventSystemClientSetMatching(_ client: UnsafeMutableRawPointer, _ matching: CFDictionary) -> Int32

@_silgen_name("IOHIDEventSystemClientCopyServices")
func IOHIDEventSystemClientCopyServices(_ client: UnsafeMutableRawPointer) -> CFArray?

@_silgen_name("IOHIDServiceClientCopyProperty")
func IOHIDServiceClientCopyProperty(_ service: UnsafeMutableRawPointer, _ property: CFString) -> CFTypeRef?

@_silgen_name("IOHIDServiceClientCopyEvent")
func IOHIDServiceClientCopyEvent(_ service: UnsafeMutableRawPointer, _ type: Int32, _ options: Int32, _ flags: Int32) -> UnsafeMutableRawPointer?

@_silgen_name("IOHIDEventGetFloatValue")
func IOHIDEventGetFloatValue(_ event: UnsafeMutableRawPointer, _ field: Int32) -> Double

struct proc_taskinfo {
    var pti_virtual_size: UInt64
    var pti_resident_size: UInt64
    var pti_total_user: UInt64
    var pti_total_system: UInt64
    var pti_threads_user: UInt64
    var pti_threads_system: UInt64
    var pti_policy: Int32
    var pti_faults: Int32
    var pti_pageins: Int32
    var pti_cow_faults: Int32
    var pti_messages_sent: Int32
    var pti_messages_received: Int32
    var pti_syscalls_mach: Int32
    var pti_syscalls_unix: Int32
    var pti_csw: Int32
    var pti_threadnum: Int32
    var pti_numrunning: Int32
    var pti_priority: Int32
}
