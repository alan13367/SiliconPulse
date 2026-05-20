import Foundation
import Observation
import SystemConfiguration

@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    var networkUploadSpeed: Double = 0
    var networkDownloadSpeed: Double = 0
    var networkHistory: [NetworkSpeed] = []
    var totalDownloadSession: Int64 = 0
    var totalUploadSession: Int64 = 0
    var currentInterface: String = ""
    var isVPN: Bool = false

    private var timer: Timer?
    private var previousNetworkStats: (upload: Int64, download: Int64, timestamp: Date)?
    private var dynamicStore: SCDynamicStore?

    private init() {
        self.currentInterface = getPrimaryInterface()
        detectVPN()
        setupNetworkObserver()
        startMonitoring()
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

    private func getPrimaryInterface() -> String {
        if let global = SCDynamicStoreCopyValue(nil, "State:/Network/Global/IPv4" as CFString),
           let name = global["PrimaryInterface"] as? String {
            return name
        }
        return ""
    }

    private func detectVPN() {
        if let prefs = SCDynamicStoreCopyValue(nil, "State:/Network/Global/IPv4" as CFString),
           let service = prefs["PrimaryService"] as? String {
            let key = "State:/Network/Service/\(service)/Interface" as CFString
            if let iface = SCDynamicStoreCopyValue(nil, key),
               let name = iface["InterfaceName"] as? String {
                isVPN = name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp")
            }
        }
    }

    private func setupNetworkObserver() {
        var context = SCDynamicStoreContext(version: 0, info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), retain: nil, release: nil, copyDescription: nil)
        dynamicStore = SCDynamicStoreCreate(nil, "SiliconPulse" as CFString, { _, _, info in
            guard let info = info else { return }
            let monitor = Unmanaged<NetworkMonitor>.fromOpaque(info).takeUnretainedValue()
            let newInterface = monitor.getPrimaryInterface()
            if newInterface != monitor.currentInterface {
                monitor.currentInterface = newInterface
                monitor.detectVPN()
                monitor.previousNetworkStats = nil
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

    private func updateNetworkStats() {
        let interfaceID = self.currentInterface
        guard !interfaceID.isEmpty else { return }

        var interfaceAddresses: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&interfaceAddresses) == 0, let firstAddr = interfaceAddresses else { return }
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
                let uploadDiff = diffWithRollover(current: totalUpload, previous: previous.upload)
                let downloadDiff = diffWithRollover(current: totalDownload, previous: previous.download)

                let uploadSpeed = Double(uploadDiff) / timeDelta
                let downloadSpeed = Double(downloadDiff) / timeDelta

                let smoothedUpload = smoothed(networkUploadSpeed, newValue: uploadSpeed)
                let smoothedDownload = smoothed(networkDownloadSpeed, newValue: downloadSpeed)

                networkUploadSpeed = smoothedUpload
                networkDownloadSpeed = smoothedDownload
                totalUploadSession += uploadDiff
                totalDownloadSession += downloadDiff

                let entry = NetworkSpeed(upload: smoothedUpload, download: smoothedDownload, timestamp: now)
                networkHistory.append(entry)
                let limit = SettingsManager.shared.networkHistoryPoints
                if networkHistory.count > limit { networkHistory.removeFirst() }
            }
        }
        previousNetworkStats = (totalUpload, totalDownload, now)
    }

    private func diffWithRollover(current: Int64, previous: Int64) -> Int64 {
        if current >= previous { return current - previous }
        // 32-bit rollover at ~4GB
        return current + (Int64(UInt32.max) - previous)
    }

    private func smoothed(_ current: Double, newValue: Double, factor: Double = 0.3) -> Double {
        current + (newValue - current) * factor
    }

    deinit { stopMonitoring() }
}
