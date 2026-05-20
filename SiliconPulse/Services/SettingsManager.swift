import Foundation
import Observation
import Combine

@Observable
final class SettingsManager {
    static let shared = SettingsManager()

    var updateInterval: TimeInterval = 2.0
    var showCoreDetails: Bool = true
    var showMemoryDetails: Bool = true
    var showThermalInfo: Bool = true
    var showNetworkDetails: Bool = true
    var showBatteryInfo: Bool = true
    var showDiskInfo: Bool = true
    var showFanControl: Bool = true
    var launchAtLogin: Bool = false
    var showNotifications: Bool = false
    var cpuAlertThreshold: Double = 90.0
    var memoryAlertThreshold: Double = 85.0
    var thermalAlertThreshold: String = "heavy"
    var useBitsPerSecond: Bool = false
    var networkHistoryPoints: Int = 60
    var useFahrenheit: Bool = false
    var processSortBy: ProcessSort = .cpu

    enum ProcessSort: String, CaseIterable, Sendable {
        case cpu = "CPU"
        case memory = "Memory"
        case name = "Name"
    }

    private var cancellables = Set<AnyCancellable>()
    private let defaults = UserDefaults.standard

    private init() {
        loadSettings()
    }

    private func loadSettings() {
        updateInterval = defaults.double(forKey: "updateInterval")
        if updateInterval == 0 { updateInterval = 2.0 }

        showCoreDetails = defaults.object(forKey: "showCoreDetails") == nil ? true : defaults.bool(forKey: "showCoreDetails")
        showMemoryDetails = defaults.object(forKey: "showMemoryDetails") == nil ? true : defaults.bool(forKey: "showMemoryDetails")
        showThermalInfo = defaults.object(forKey: "showThermalInfo") == nil ? true : defaults.bool(forKey: "showThermalInfo")
        showNetworkDetails = defaults.object(forKey: "showNetworkDetails") == nil ? true : defaults.bool(forKey: "showNetworkDetails")
        showBatteryInfo = defaults.object(forKey: "showBatteryInfo") == nil ? true : defaults.bool(forKey: "showBatteryInfo")
        showDiskInfo = defaults.object(forKey: "showDiskInfo") == nil ? true : defaults.bool(forKey: "showDiskInfo")
        showFanControl = defaults.object(forKey: "showFanControl") == nil ? true : defaults.bool(forKey: "showFanControl")
        launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        showNotifications = defaults.bool(forKey: "showNotifications")
        cpuAlertThreshold = defaults.double(forKey: "cpuAlertThreshold")
        if cpuAlertThreshold == 0 { cpuAlertThreshold = 90.0 }
        memoryAlertThreshold = defaults.double(forKey: "memoryAlertThreshold")
        if memoryAlertThreshold == 0 { memoryAlertThreshold = 85.0 }
        thermalAlertThreshold = defaults.string(forKey: "thermalAlertThreshold") ?? "heavy"
        useBitsPerSecond = defaults.bool(forKey: "useBitsPerSecond")
        networkHistoryPoints = defaults.integer(forKey: "networkHistoryPoints")
        if networkHistoryPoints == 0 { networkHistoryPoints = 60 }
        useFahrenheit = defaults.bool(forKey: "useFahrenheit")

        if let sortRaw = defaults.string(forKey: "processSortBy"), let sort = ProcessSort(rawValue: sortRaw) {
            processSortBy = sort
        }
    }

    func save() {
        defaults.set(updateInterval, forKey: "updateInterval")
        defaults.set(showCoreDetails, forKey: "showCoreDetails")
        defaults.set(showMemoryDetails, forKey: "showMemoryDetails")
        defaults.set(showThermalInfo, forKey: "showThermalInfo")
        defaults.set(showNetworkDetails, forKey: "showNetworkDetails")
        defaults.set(showBatteryInfo, forKey: "showBatteryInfo")
        defaults.set(showDiskInfo, forKey: "showDiskInfo")
        defaults.set(showFanControl, forKey: "showFanControl")
        defaults.set(launchAtLogin, forKey: "launchAtLogin")
        defaults.set(showNotifications, forKey: "showNotifications")
        defaults.set(cpuAlertThreshold, forKey: "cpuAlertThreshold")
        defaults.set(memoryAlertThreshold, forKey: "memoryAlertThreshold")
        defaults.set(thermalAlertThreshold, forKey: "thermalAlertThreshold")
        defaults.set(useBitsPerSecond, forKey: "useBitsPerSecond")
        defaults.set(networkHistoryPoints, forKey: "networkHistoryPoints")
        defaults.set(useFahrenheit, forKey: "useFahrenheit")
        defaults.set(processSortBy.rawValue, forKey: "processSortBy")
    }

    func resetToDefaults() {
        updateInterval = 2.0
        showCoreDetails = true
        showMemoryDetails = true
        showThermalInfo = true
        showNetworkDetails = true
        showBatteryInfo = true
        showDiskInfo = true
        showFanControl = true
        launchAtLogin = false
        showNotifications = false
        cpuAlertThreshold = 90.0
        memoryAlertThreshold = 85.0
        thermalAlertThreshold = "heavy"
        useBitsPerSecond = false
        networkHistoryPoints = 60
        useFahrenheit = false
        processSortBy = .cpu
        save()
    }
}
