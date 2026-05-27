import Foundation
import Observation
import IOKit
import IOKit.ps

@Observable
final class SystemMonitor {
    static let shared = SystemMonitor()

    var cpuUsage: Double = 0.0
    var gpuUsage: Double = 0.0
    var memoryUsage: Double = 0.0
    var memoryDetails = MemoryDetails()
    var coreUsages: [CoreUsage] = []
    var efficiencyCoreUsages: [Double] = []
    var performanceCoreUsages: [Double] = []
    var currentTemperature: Double = 0.0
    var temperatureAvailable: Bool = false
    var systemInfo: SystemInfo = SystemInfo(modelName: "", chipName: "", osVersion: "", coreCount: 0, efficiencyCoreCount: 0, performanceCoreCount: 0)
    var uptime: TimeInterval = 0

    var cpuHistory: [Double] = Array(repeating: 0, count: 60)
    var gpuHistory: [Double] = Array(repeating: 0, count: 60)
    var memoryHistory: [Double] = Array(repeating: 0, count: 60)

    private var timer: Timer?
    private var updateInterval: TimeInterval = 2.0
    private let host = mach_host_self()
    private var previousLoad: host_cpu_load_info?
    private var previousProcessorInfo: [Int32] = []
    private var previousCPUTime: UInt64 = 0

    private init() {
        setupCoreCounts()
        setupSystemInfo()
        startMonitoring()
    }

    func startMonitoring(interval: TimeInterval = 2.0) {
        updateInterval = interval
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer?.fire()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        updateCPUUsage()
        updateMemoryUsage()
        updateTemperature()
        updateUptime()
    }

    private func setupSystemInfo() {
        let info = Foundation.ProcessInfo.processInfo
        var model = "Mac"
        var chip = "Apple Silicon"
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        if size > 0 {
            var buf = [CChar](repeating: 0, count: size)
            sysctlbyname("hw.model", &buf, &size, nil, 0)
            model = String(cString: buf)
        }

        var brandSize = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &brandSize, nil, 0)
        if brandSize > 0 {
            var brandBuf = [CChar](repeating: 0, count: brandSize)
            sysctlbyname("machdep.cpu.brand_string", &brandBuf, &brandSize, nil, 0)
            chip = String(cString: brandBuf)
        } else {
            #if arch(arm64)
            let cores = info.processorCount
            switch cores {
            case 8: chip = "M1"
            case 10: chip = (info.physicalMemory >= 32_000_000_000) ? "M4 Pro" : "M1 Pro/Max or M3 Pro"
            case 12: chip = "M2 Pro/Max or M4 Pro"
            case 14, 16, 20, 24: chip = "M1 Max/Ultra or M2 Max/Ultra or M3 Max/Ultra"
            default: chip = "Apple Silicon"
            }
            #else
            chip = "Intel"
            #endif
        }

        let osv = info.operatingSystemVersion
        let osString = "\(osv.majorVersion).\(osv.minorVersion).\(osv.patchVersion)"

        systemInfo = SystemInfo(
            modelName: model,
            chipName: chip,
            osVersion: osString,
            coreCount: info.processorCount,
            efficiencyCoreCount: efficiencyCoreUsages.count,
            performanceCoreCount: performanceCoreUsages.count
        )
    }

    private func setupCoreCounts() {
        let activeCores = Foundation.ProcessInfo.processInfo.activeProcessorCount
        var efficiencyCores = 0
        var performanceCores = 0

        #if arch(arm64)
        switch activeCores {
        case 8: efficiencyCores = 4; performanceCores = 4
        case 10: efficiencyCores = 2; performanceCores = 8
        case 12: efficiencyCores = 2; performanceCores = 10
        case 14, 16, 20, 24: efficiencyCores = 4; performanceCores = activeCores - 4
        default: efficiencyCores = activeCores / 2; performanceCores = activeCores / 2
        }
        #else
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
                let userTicks = Double(UInt32(load.cpu_ticks.0) &- UInt32(previous.cpu_ticks.0))
                let systemTicks = Double(UInt32(load.cpu_ticks.1) &- UInt32(previous.cpu_ticks.1))
                let idleTicks = Double(UInt32(load.cpu_ticks.2) &- UInt32(previous.cpu_ticks.2))
                let niceTicks = Double(UInt32(load.cpu_ticks.3) &- UInt32(previous.cpu_ticks.3))

                let totalTicks = userTicks + systemTicks + idleTicks + niceTicks
                let usedTicks = totalTicks - idleTicks
                let usage = totalTicks > 0 ? (usedTicks / totalTicks) * 100.0 : 0.0
                let clamped = min(max(usage, 0), 100)

                cpuUsage = smoothed(cpuUsage, newValue: clamped)
                addToHistory(array: &cpuHistory, value: cpuUsage)
            }
            previousLoad = load
        }
        updateRealCoreUsages()
    }

    private func updateRealCoreUsages() {
        var numProcessors: mach_msg_type_number_t = 0
        var processorInfo: processor_info_array_t?
        var processorMsgCount: mach_msg_type_number_t = 0

        let result = host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &numProcessors, &processorInfo, &processorMsgCount)
        guard result == KERN_SUCCESS, let info = processorInfo else { return }

        let infoArray = Array(UnsafeBufferPointer(start: info, count: Int(processorMsgCount)))
        let vmSize = Int(processorMsgCount) * MemoryLayout<integer_t>.stride
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(vmSize))

        if !previousProcessorInfo.isEmpty && previousProcessorInfo.count == infoArray.count {
            var updatedCores: [CoreUsage] = []
            var newEff: [Double] = []
            var newPerf: [Double] = []
            let cpuLoadInfoCount = Int(CPU_STATE_MAX)

            for i in 0..<Int(numProcessors) {
                let base = i * cpuLoadInfoCount
                let user = Double(UInt32(bitPattern: infoArray[base + Int(CPU_STATE_USER)]) &- UInt32(bitPattern: previousProcessorInfo[base + Int(CPU_STATE_USER)]))
                let system = Double(UInt32(bitPattern: infoArray[base + Int(CPU_STATE_SYSTEM)]) &- UInt32(bitPattern: previousProcessorInfo[base + Int(CPU_STATE_SYSTEM)]))
                let idle = Double(UInt32(bitPattern: infoArray[base + Int(CPU_STATE_IDLE)]) &- UInt32(bitPattern: previousProcessorInfo[base + Int(CPU_STATE_IDLE)]))
                let nice = Double(UInt32(bitPattern: infoArray[base + Int(CPU_STATE_NICE)]) &- UInt32(bitPattern: previousProcessorInfo[base + Int(CPU_STATE_NICE)]))
                let total = user + system + idle + nice
                let used = user + system + nice
                let usage = total > 0 ? (used / total) * 100.0 : 0.0

                if i < coreUsages.count {
                    let core = coreUsages[i]
                    updatedCores.append(CoreUsage(id: core.id, usage: usage, isEfficiencyCore: core.isEfficiencyCore))
                    if core.isEfficiencyCore { newEff.append(usage) } else { newPerf.append(usage) }
                }
            }
            coreUsages = updatedCores
            efficiencyCoreUsages = newEff
            performanceCoreUsages = newPerf
        }
        previousProcessorInfo = infoArray
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
        let appMemory = (internalPages >= purgeablePages ? internalPages - purgeablePages : 0) * pageSize
        let used = appMemory + wired + compressed
        let cached = active + inactive

        var physicalMemory: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        if sysctlbyname("hw.memsize", &physicalMemory, &size, nil, 0) != 0 {
            physicalMemory = used + free + inactive
        }

        let usage = Double(used) / Double(physicalMemory) * 100.0

        memoryUsage = min(max(usage, 0), 100)
        addToHistory(array: &memoryHistory, value: memoryUsage)
        memoryDetails = MemoryDetails(
            used: used,
            total: physicalMemory,
            appMemory: appMemory,
            wiredMemory: wired,
            compressedMemory: compressed,
            cached: cached,
            free: free
        )
    }

    private func updateTemperature() {
        var temp = readIOHIDTemperature()
        if temp == 0 {
            temp = readSMCTemperature()
        }
        if temp > 0 && temp < 150 {
            currentTemperature = temp
            temperatureAvailable = true
        } else {
            temperatureAvailable = false
            currentTemperature = 0
        }
    }

    private func readIOHIDTemperature() -> Double {
        let kIOHIDEventTypeThermal: Int32 = 15
        let kIOHIDEventFieldThermalTemperature: Int32 = 15 << 16

        guard let client = IOHIDEventSystemClientCreate(kCFAllocatorDefault) else { return 0 }
        let matching: [String: Any] = ["PrimaryUsagePage": 0xff00 as NSNumber, "PrimaryUsage": 0x0005 as NSNumber]
        _ = IOHIDEventSystemClientSetMatching(client, matching as CFDictionary)
        guard let services = IOHIDEventSystemClientCopyServices(client) else { return 0 }

        let servicesArray = services as NSArray
        var temps: [Double] = []
        for i in 0..<servicesArray.count {
            let service = servicesArray[i] as AnyObject
            let servicePtr = Unmanaged.passUnretained(service).toOpaque()
            if let productRef = IOHIDServiceClientCopyProperty(servicePtr, "Product" as CFString) {
                let product = productRef as? String ?? ""
                if product.lowercased().contains("tdie") || product.lowercased().contains("temp") || product.lowercased().contains("tcal") {
                    if let eventPtr = IOHIDServiceClientCopyEvent(servicePtr, kIOHIDEventTypeThermal, 0, 0) {
                        let temp = IOHIDEventGetFloatValue(eventPtr, kIOHIDEventFieldThermalTemperature)
                        if temp > 0 && temp < 150 { temps.append(temp) }
                    }
                }
            }
        }
        return temps.max() ?? 0
    }

    private func readSMCTemperature() -> Double {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleSMCC"), &iterator)
        guard result == KERN_SUCCESS else { return 0 }
        var service = IOIteratorNext(iterator)
        defer { IOObjectRelease(iterator) }

        while service != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any] {
                for (key, value) in dict {
                    let lower = key.lowercased()
                    if lower.contains("temp") || lower.contains("tdie") || lower.contains("tcal"),
                       let num = value as? Double, num > 0 && num < 150 {
                        IOObjectRelease(service)
                        return num
                    }
                    if lower.contains("temp") || lower.contains("tdie"),
                       let num = value as? NSNumber {
                        let d = num.doubleValue
                        if d > 0 && d < 150 {
                            IOObjectRelease(service)
                            return d
                        }
                    }
                }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return 0
    }

    private func updateUptime() {
        uptime = Foundation.ProcessInfo.processInfo.systemUptime
    }

    private func addToHistory(array: inout [Double], value: Double) {
        array.append(value)
        if array.count > 60 { array.removeFirst() }
    }

    private func smoothed(_ current: Double, newValue: Double, factor: Double = 0.3) -> Double {
        current + (newValue - current) * factor
    }

    deinit { stopMonitoring() }
}

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
