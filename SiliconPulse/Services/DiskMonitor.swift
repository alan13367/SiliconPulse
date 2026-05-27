import Foundation
import Observation

@Observable
final class DiskMonitor {
    static let shared = DiskMonitor()

    var volumes: [VolumeInfo] = []

    private var timer: Timer?
    private let updateInterval: TimeInterval = 5.0

    private init() {
        updateVolumes()
        startMonitoring()
    }

    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updateVolumes()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func updateVolumes() {
        let resourceKeys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: resourceKeys, options: .skipHiddenVolumes) ?? []
        let bootURL = URL(fileURLWithPath: "/")

        var newVolumes: [VolumeInfo] = []
        for url in urls {
            var stat = statfs()
            let hasStat = statfs(url.path, &stat) == 0

            let resourceValues = try? url.resourceValues(forKeys: Set(resourceKeys))
            let total = resourceValues?.volumeTotalCapacity.map(UInt64.init)
                ?? (hasStat ? UInt64(stat.f_blocks) * UInt64(stat.f_bsize) : 0)
            let available = resourceValues?.volumeAvailableCapacityForImportantUsage.map { UInt64(max($0, 0)) }
                ?? resourceValues?.volumeAvailableCapacity.map(UInt64.init)
                ?? (hasStat ? UInt64(stat.f_bavail) * UInt64(stat.f_bsize) : 0)
            let name = resourceValues?.volumeName ?? url.path

            guard total > 0 else { continue }

            let isBoot = url.path == bootURL.path
            newVolumes.append(VolumeInfo(name: name, path: url.path, totalBytes: total, availableBytes: available, isBootVolume: isBoot))
        }

        volumes = newVolumes.sorted { $0.isBootVolume && !$1.isBootVolume }
    }

    deinit { stopMonitoring() }
}
