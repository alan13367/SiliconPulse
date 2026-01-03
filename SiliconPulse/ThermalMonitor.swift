import Foundation
import Combine
import SwiftUI

class ThermalMonitor: ObservableObject {
    static let shared = ThermalMonitor()
    
    @Published var thermalPressureLevel: ThermalPressureLevel = .nominal
    @Published var thermalPressureRawValue: Int = 0
    @Published var thermalNotificationAvailable: Bool = false
    
    private var notifyPort: Int32 = 0
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    enum ThermalPressureLevel: String, CaseIterable {
        case nominal = "Nominal"
        case moderate = "Moderate"
        case heavy = "Heavy"
        case trapping = "Trapping"
        case sleeping = "Sleeping"
        case unknown = "Unknown"
        
        var color: Color {
            switch self {
            case .nominal: return .green
            case .moderate: return .yellow
            case .heavy: return .orange
            case .trapping: return .red
            case .sleeping: return .red
            case .unknown: return .gray
            }
        }
        
        var description: String {
            switch self {
            case .nominal: return "System is cool and operating normally"
            case .moderate: return "System is warm, minor performance adjustments"
            case .heavy: return "System is hot, performance may be throttled"
            case .trapping: return "Severe thermal throttling applied"
            case .sleeping: return "Critical - near thermal shutdown"
            case .unknown: return "Thermal state unknown"
            }
        }
        
        var icon: String {
            switch self {
            case .nominal: return "thermometer.snowflake"
            case .moderate: return "thermometer"
            case .heavy: return "thermometer.sun"
            case .trapping: return "thermometer.high"
            case .sleeping: return "exclamationmark.triangle"
            case .unknown: return "questionmark.circle"
            }
        }
    }
    
    private init() {
        setupThermalMonitoring()
    }
    
    private func setupThermalMonitoring() {
        thermalNotificationAvailable = true
        setupThermalNotification()
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.updateThermalState()
        }
    }
    
    private func setupThermalNotification() {
        let notificationName = "com.apple.system.thermalpressurelevel"
        
        let result = notificationName.withCString { namePtr in
            notify_register_check(namePtr, &notifyPort)
        }
        
        if result == NOTIFY_STATUS_OK {
            thermalNotificationAvailable = true
            updateThermalState()
        } else {
            thermalNotificationAvailable = false
            DispatchQueue.main.async {
                self.thermalPressureLevel = .unknown
            }
        }
    }
    
    private func updateThermalState() {
        guard thermalNotificationAvailable else {
            DispatchQueue.main.async {
                self.thermalPressureLevel = .unknown
            }
            return
        }
        
        var state: UInt64 = 0
        let result = notify_get_state(notifyPort, &state)
        
        if result == NOTIFY_STATUS_OK {
            DispatchQueue.main.async {
                self.thermalPressureRawValue = Int(state)
                self.thermalPressureLevel = self.levelForState(state)
            }
        }
    }

    private func levelForState(_ state: UInt64) -> ThermalPressureLevel {
        switch state {
        case 0: return .nominal
        case 1: return .moderate
        case 2: return .heavy
        case 3: return .trapping
        case 4: return .sleeping
        default: return .unknown
        }
    }
    
    func getThermalPressurePercentage() -> Double {
        switch thermalPressureLevel {
        case .nominal: return 0.0
        case .moderate: return 33.0
        case .heavy: return 66.0
        case .trapping: return 85.0
        case .sleeping: return 100.0
        case .unknown: return 0.0
        }
    }
    
    deinit {
        if notifyPort != 0 {
            notify_cancel(notifyPort)
        }
        updateTimer?.invalidate()
    }
}

@_silgen_name("notify_register_check")
private func notify_register_check(
    _ name: UnsafePointer<CChar>,
    _ token: UnsafeMutablePointer<Int32>
) -> UInt32

@_silgen_name("notify_get_state")
private func notify_get_state(
    _ token: Int32,
    _ state: UnsafeMutablePointer<UInt64>
) -> UInt32

@_silgen_name("notify_cancel")
private func notify_cancel(_ token: Int32) -> UInt32

private let NOTIFY_STATUS_OK: UInt32 = 0
