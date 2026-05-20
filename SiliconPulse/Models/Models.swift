import SwiftUI

struct CoreUsage: Identifiable, Sendable {
    let id: Int
    let usage: Double
    let isEfficiencyCore: Bool
}

struct ProcessInfo: Identifiable, Sendable {
    let id: Int32
    let name: String
    let cpuUsage: Double
    let memoryUsage: UInt64
    let isSystemProcess: Bool
}

struct MemoryDetails: Sendable {
    var used: UInt64 = 0
    var total: UInt64 = 0
    var appMemory: UInt64 = 0
    var wiredMemory: UInt64 = 0
    var compressedMemory: UInt64 = 0
    var cached: UInt64 = 0
    var free: UInt64 = 0

    var usedGB: Double { Double(used) / 1_073_741_824.0 }
    var totalGB: Double { Double(total) / 1_073_741_824.0 }

    var formattedString: String {
        String(format: "%.1f / %.1f GB", usedGB, totalGB)
    }
}

struct NetworkSpeed: Identifiable, Sendable {
    let id = UUID()
    let upload: Double
    let download: Double
    let timestamp: Date
}

struct SystemInfo: Sendable {
    let modelName: String
    let chipName: String
    let osVersion: String
    let coreCount: Int
    let efficiencyCoreCount: Int
    let performanceCoreCount: Int
}

struct VolumeInfo: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let path: String
    let totalBytes: UInt64
    let availableBytes: UInt64
    var isBootVolume: Bool = false

    var usedBytes: UInt64 { totalBytes - availableBytes }
    var usagePercent: Double {
        totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) * 100.0 : 0
    }
}

struct BatteryInfo: Sendable {
    let isPresent: Bool
    let chargeLevel: Double // 0.0 - 1.0
    let isCharging: Bool
    let isPlugged: Bool
    let timeRemaining: Int // minutes, -1 if unknown
    let cycleCount: Int
    let healthPercent: Double
}
