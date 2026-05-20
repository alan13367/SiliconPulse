import Foundation
import Observation
import IOKit.ps

@Observable
final class BatteryMonitor {
    static let shared = BatteryMonitor()

    var batteryInfo = BatteryInfo(isPresent: false, chargeLevel: 0, isCharging: false, isPlugged: false, timeRemaining: -1, cycleCount: 0, healthPercent: 100)

    private var timer: Timer?
    private let updateInterval: TimeInterval = 10.0

    private init() {
        updateBatteryInfo()
        startMonitoring()
    }

    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updateBatteryInfo()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func updateBatteryInfo() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let firstSource = sources.first else {
            batteryInfo = BatteryInfo(isPresent: false, chargeLevel: 0, isCharging: false, isPlugged: false, timeRemaining: -1, cycleCount: 0, healthPercent: 100)
            return
        }

        guard let info = IOPSGetPowerSourceDescription(snapshot, firstSource)?.takeUnretainedValue() as? [String: Any] else {
            batteryInfo = BatteryInfo(isPresent: false, chargeLevel: 0, isCharging: false, isPlugged: false, timeRemaining: -1, cycleCount: 0, healthPercent: 100)
            return
        }

        let isPresent = info[kIOPSIsPresentKey] as? Bool ?? false
        let chargeLevel = info[kIOPSCurrentCapacityKey] as? Double ?? (info[kIOPSCurrentCapacityKey] as? Int).map(Double.init) ?? 0
        let maxCapacity = info[kIOPSMaxCapacityKey] as? Double ?? (info[kIOPSMaxCapacityKey] as? Int).map(Double.init) ?? 100
        let isCharging = info[kIOPSIsChargingKey] as? Bool ?? false
        let isPlugged = info[kIOPSIsChargingKey] as? Bool ?? false || info[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
        let timeRemaining = info[kIOPSTimeToEmptyKey] as? Int ?? (info[kIOPSTimeToFullChargeKey] as? Int ?? -1)
        let cycleCount = info["Cycle Count"] as? Int ?? 0
        let designCapacity = info[kIOPSDesignCapacityKey] as? Double ?? maxCapacity

        let health = designCapacity > 0 ? (maxCapacity / designCapacity) * 100.0 : 100.0

        batteryInfo = BatteryInfo(
            isPresent: isPresent,
            chargeLevel: chargeLevel / 100.0,
            isCharging: isCharging,
            isPlugged: isPlugged,
            timeRemaining: timeRemaining,
            cycleCount: cycleCount,
            healthPercent: min(max(health, 0), 100)
        )
    }

    deinit { stopMonitoring() }
}
