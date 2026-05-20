import Foundation
import Observation
import IOKit

@Observable
final class GPUMonitor {
    static let shared = GPUMonitor()

    var gpuUsage: Double = 0.0
    var gpuAvailable: Bool = false
    var gpuHistory: [Double] = Array(repeating: 0, count: 60)

    private var timer: Timer?
    private let updateInterval: TimeInterval = 2.0

    private init() {
        startMonitoring()
    }

    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updateGPUUsage()
        }
        timer?.fire()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func updateGPUUsage() {
        var util = readIOAcceleratorUtilization()
        if util == 0 {
            util = readIOReportGPUResidency()
        }
        if util > 0 {
            gpuAvailable = true
            gpuUsage = smoothed(gpuUsage, newValue: min(max(util, 0), 100))
            addToHistory(array: &gpuHistory, value: gpuUsage)
        } else {
            gpuAvailable = false
            gpuUsage = 0
        }
    }

    private func readIOAcceleratorUtilization() -> Double {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator)
        guard result == KERN_SUCCESS else { return 0 }
        var service = IOIteratorNext(iterator)
        defer { IOObjectRelease(iterator) }

        while service != 0 {
            var properties: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = properties?.takeRetainedValue() as? [String: Any],
               let perfStats = dict["PerformanceStatistics"] as? [String: Any],
               let deviceUtil = perfStats["Device Utilization %"] as? Int {
                IOObjectRelease(service)
                return Double(deviceUtil)
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return 0
    }

    private func readIOReportGPUResidency() -> Double {
        // IOReport is a private framework that requires C function pointer callbacks,
        // which cannot capture Swift context. This makes it impractical to use via dlopen.
        // Falling back to IOAccelerator metrics which provide some GPU data on Intel Macs.
        return 0
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
