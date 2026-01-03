import Foundation
import Combine
import SwiftUI
import SystemConfiguration

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published var networkUploadSpeed: Double = 0
    @Published var networkDownloadSpeed: Double = 0
    @Published var networkHistory: [NetworkSpeed] = []
    @Published var totalDownloadSession: Int64 = 0
    @Published var totalUploadSession: Int64 = 0

    private var timer: Timer?
    private var previousNetworkStats: (upload: Int64, download: Int64, timestamp: Date)?
    private var dynamicStore: SCDynamicStore?
    private var currentInterface: String = ""

    private func getPrimaryInterface() -> String {
        if let global = SCDynamicStoreCopyValue(nil, "State:/Network/Global/IPv4" as CFString),
           let name = global["PrimaryInterface"] as? String {
            return name
        }
        return ""
    }

    private init() {
        self.currentInterface = getPrimaryInterface()
        setupNetworkObserver()
        startMonitoring()
    }

    private func setupNetworkObserver() {
        var context = SCDynamicStoreContext(version: 0, info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), retain: nil, release: nil, copyDescription: nil)
        
        dynamicStore = SCDynamicStoreCreate(nil, "SiliconPulse" as CFString, { _, _, info in
            guard let info = info else { return }
            let monitor = Unmanaged<NetworkMonitor>.fromOpaque(info).takeUnretainedValue()
            let newInterface = monitor.getPrimaryInterface()
            if newInterface != monitor.currentInterface {
                DispatchQueue.main.async {
                    monitor.currentInterface = newInterface
                    // Reset previous stats to avoid huge spikes on switch
                    monitor.previousNetworkStats = nil
                }
            }
        }, &context)

        if let store = dynamicStore {
            let keys = ["State:/Network/Global/IPv4"] as CFArray
            SCDynamicStoreSetNotificationKeys(store, keys, nil)
            if let source = SCDynamicStoreCreateRunLoopSource(nil, store, 0) {
                CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
    }

    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateNetworkStats()
        }
        timer?.fire()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func updateNetworkStats() {
        let interfaceID = self.currentInterface
        guard !interfaceID.isEmpty else { return }

        var interfaceAddresses: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&interfaceAddresses) == 0, let firstAddr = interfaceAddresses else {
            return
        }
        defer { freeifaddrs(interfaceAddresses) }

        var totalUpload: Int64 = 0
        var totalDownload: Int64 = 0
        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr

        while let currentPtr = ptr {
            let interface = currentPtr.pointee
            let name = String(cString: interface.ifa_name)

            if name == interfaceID {
                if interface.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                    if let data = interface.ifa_data {
                        let ifData = data.assumingMemoryBound(to: if_data.self).pointee
                        totalUpload += Int64(ifData.ifi_obytes)
                        totalDownload += Int64(ifData.ifi_ibytes)
                    }
                }
            }
            ptr = interface.ifa_next
        }

        let now = Date()
        if let previous = previousNetworkStats {
            let timeDelta = now.timeIntervalSince(previous.timestamp)
            if timeDelta > 0 {
                let uploadDiff = totalUpload >= previous.upload ? totalUpload - previous.upload : 0
                let downloadDiff = totalDownload >= previous.download ? totalDownload - previous.download : 0

                let uploadSpeed = Double(uploadDiff) / timeDelta
                let downloadSpeed = Double(downloadDiff) / timeDelta

                DispatchQueue.main.async {
                    self.networkUploadSpeed = uploadSpeed
                    self.networkDownloadSpeed = downloadSpeed
                    self.totalUploadSession += uploadDiff
                    self.totalDownloadSession += downloadDiff

                    let speedEntry = NetworkSpeed(
                        upload: uploadSpeed,
                        download: downloadSpeed,
                        timestamp: now
                    )
                    self.networkHistory.append(speedEntry)
                    let limit = SettingsManager.shared.networkHistoryPoints
                    if self.networkHistory.count > limit {
                        self.networkHistory.removeFirst()
                    }
                }
            }
        }

        previousNetworkStats = (totalUpload, totalDownload, now)
    }

    deinit {
        stopMonitoring()
    }
}

struct NetworkSpeed: Identifiable {
    let id = UUID()
    let upload: Double
    let download: Double
    let timestamp: Date

    var formattedUpload: String {
        ByteCountFormatter.string(fromByteCount: Int64(upload), countStyle: .binary)
    }

    var formattedDownload: String {
        ByteCountFormatter.string(fromByteCount: Int64(download), countStyle: .binary)
    }
}
