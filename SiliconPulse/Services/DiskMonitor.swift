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
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeNameKey, .volumeIsLocalKey], options: .skipHiddenVolumes) ?? []
        let bootURL = URL(fileURLWithPath: "/")

        var newVolumes: [VolumeInfo] = []
        for url in urls {
            var stat = statfs()
            guard statfs(url.path, &stat) == 0 else { continue }

            let total = UInt64(stat.f_blocks) * UInt64(stat.f_bsize)
            let available = UInt64(stat.f_bavail) * UInt64(stat.f_bsize)
            let name = (try? url.resourceValues(forKeys: [.volumeNameKey]).volumeName) ?? url.path

            let isBoot = url.path == bootURL.path
            newVolumes.append(VolumeInfo(name: name, path: url.path, totalBytes: total, availableBytes: available, isBootVolume: isBoot))
        }

        volumes = newVolumes.sorted { $0.isBootVolume && !$1.isBootVolume }
    }

    deinit { stopMonitoring() }
}
