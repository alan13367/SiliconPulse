//
//  SettingsManager.swift
//  SiliconPulse
//
//  Created by Alan on 31/12/25.
//


import Foundation
import Combine
import ServiceManagement

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // User Preferences
    @Published var updateInterval: TimeInterval = 2.0 {
        didSet {
            UserDefaults.standard.set(updateInterval, forKey: "updateInterval")
        }
    }
    
    @Published var showCoreDetails: Bool = true {
        didSet {
            UserDefaults.standard.set(showCoreDetails, forKey: "showCoreDetails")
        }
    }
    
    @Published var showMemoryDetails: Bool = true {
        didSet {
            UserDefaults.standard.set(showMemoryDetails, forKey: "showMemoryDetails")
        }
    }
    
    @Published var showThermalInfo: Bool = true {
        didSet {
            UserDefaults.standard.set(showThermalInfo, forKey: "showThermalInfo")
        }
    }
    
    @Published var launchAtLogin: Bool = false {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            updateLoginItem()
        }
    }
    
    @Published var showNotifications: Bool = false {
        didSet {
            UserDefaults.standard.set(showNotifications, forKey: "showNotifications")
        }
    }
    
    @Published var cpuAlertThreshold: Double = 90.0 {
        didSet {
            UserDefaults.standard.set(cpuAlertThreshold, forKey: "cpuAlertThreshold")
        }
    }
    
    @Published var memoryAlertThreshold: Double = 85.0 {
        didSet {
            UserDefaults.standard.set(memoryAlertThreshold, forKey: "memoryAlertThreshold")
        }
    }
    
    @Published var thermalAlertThreshold: ThermalMonitor.ThermalPressureLevel = .heavy {
        didSet {
            UserDefaults.standard.set(thermalAlertThreshold.rawValue, forKey: "thermalAlertThreshold")
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadSettings()
        setupBindings()
    }
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        
        updateInterval = defaults.double(forKey: "updateInterval")
        if updateInterval == 0 {
            updateInterval = 2.0
        }
        
        showCoreDetails = defaults.bool(forKey: "showCoreDetails")
        showMemoryDetails = defaults.bool(forKey: "showMemoryDetails")
        showThermalInfo = defaults.bool(forKey: "showThermalInfo")
        launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        showNotifications = defaults.bool(forKey: "showNotifications")
        
        cpuAlertThreshold = defaults.double(forKey: "cpuAlertThreshold")
        if cpuAlertThreshold == 0 {
            cpuAlertThreshold = 90.0
        }
        
        memoryAlertThreshold = defaults.double(forKey: "memoryAlertThreshold")
        if memoryAlertThreshold == 0 {
            memoryAlertThreshold = 85.0
        }
        
        if let thermalThresholdString = defaults.string(forKey: "thermalAlertThreshold"),
           let threshold = ThermalMonitor.ThermalPressureLevel(rawValue: thermalThresholdString) {
            thermalAlertThreshold = threshold
        }
    }
    
    private func setupBindings() {
        // Monitor for changes and save
        $updateInterval
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { _ in
                self.saveSettings()
            }
            .store(in: &cancellables)
    }
    
    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(updateInterval, forKey: "updateInterval")
        defaults.set(showCoreDetails, forKey: "showCoreDetails")
        defaults.set(showMemoryDetails, forKey: "showMemoryDetails")
        defaults.set(showThermalInfo, forKey: "showThermalInfo")
        defaults.set(launchAtLogin, forKey: "launchAtLogin")
        defaults.set(showNotifications, forKey: "showNotifications")
        defaults.set(cpuAlertThreshold, forKey: "cpuAlertThreshold")
        defaults.set(memoryAlertThreshold, forKey: "memoryAlertThreshold")
        defaults.set(thermalAlertThreshold.rawValue, forKey: "thermalAlertThreshold")
    }
    
    private func updateLoginItem() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                #if DEBUG
                print("Note: Login item registration failed (common in debug builds): \(error)")
                #else
                print("Failed to update login item: \(error)")
                #endif
            }
        } else {
            // Fallback for older macOS versions
            // You would use SMLoginItemSetEnabled here
        }
    }
    
    func resetToDefaults() {
        updateInterval = 2.0
        showCoreDetails = true
        showMemoryDetails = true
        showThermalInfo = true
        launchAtLogin = false
        showNotifications = false
        cpuAlertThreshold = 90.0
        memoryAlertThreshold = 85.0
        thermalAlertThreshold = .heavy
        saveSettings()
    }
    
    func exportSettings() -> Data? {
        let settings: [String: Any] = [
            "updateInterval": updateInterval,
            "showCoreDetails": showCoreDetails,
            "showMemoryDetails": showMemoryDetails,
            "showThermalInfo": showThermalInfo,
            "launchAtLogin": launchAtLogin,
            "showNotifications": showNotifications,
            "cpuAlertThreshold": cpuAlertThreshold,
            "memoryAlertThreshold": memoryAlertThreshold,
            "thermalAlertThreshold": thermalAlertThreshold.rawValue
        ]
        
        return try? JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)
    }
    
    func importSettings(from data: Data) -> Bool {
        guard let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        
        if let interval = settings["updateInterval"] as? TimeInterval {
            updateInterval = interval
        }
        if let coreDetails = settings["showCoreDetails"] as? Bool {
            showCoreDetails = coreDetails
        }
        if let memoryDetails = settings["showMemoryDetails"] as? Bool {
            showMemoryDetails = memoryDetails
        }
        if let thermalInfo = settings["showThermalInfo"] as? Bool {
            showThermalInfo = thermalInfo
        }
        if let login = settings["launchAtLogin"] as? Bool {
            launchAtLogin = login
        }
        if let notifications = settings["showNotifications"] as? Bool {
            showNotifications = notifications
        }
        if let cpuThreshold = settings["cpuAlertThreshold"] as? Double {
            cpuAlertThreshold = cpuThreshold
        }
        if let memoryThreshold = settings["memoryAlertThreshold"] as? Double {
            memoryAlertThreshold = memoryThreshold
        }
        if let thermalThreshold = settings["thermalAlertThreshold"] as? String,
           let threshold = ThermalMonitor.ThermalPressureLevel(rawValue: thermalThreshold) {
            thermalAlertThreshold = threshold
        }
        
        saveSettings()
        return true
    }
}
