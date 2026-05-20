import Foundation

enum Formatters {
    static func bytes(_ bytes: UInt64, style: ByteCountFormatter.CountStyle = .memory) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = style
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.includesUnit = true
        formatter.includesCount = true
        return formatter.string(fromByteCount: Int64(bytes))
    }

    static func bytes(_ bytes: Int64, style: ByteCountFormatter.CountStyle = .memory) -> String {
        bytes > 0 ? self.bytes(UInt64(bytes), style: style) : "0 B"
    }

    static func networkSpeed(_ bytesPerSecond: Double, useBits: Bool = false) -> String {
        if useBits {
            let bps = Int64(bytesPerSecond * 8)
            return ByteCountFormatter.string(fromByteCount: bps, countStyle: .binary).replacingOccurrences(of: "B", with: "b") + "/s"
        }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        return formatter.string(fromByteCount: Int64(bytesPerSecond)) + "/s"
    }

    static func temperature(_ celsius: Double, useFahrenheit: Bool = false) -> String {
        if useFahrenheit {
            let f = (celsius * 9.0 / 5.0) + 32.0
            return String(format: "%.0f°F", f)
        }
        return String(format: "%.0f°C", celsius)
    }

    static func percentage(_ value: Double) -> String {
        String(format: "%.0f%%", min(max(value, 0), 100))
    }

    static func uptime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let days = hours / 24
        let remHours = hours % 24

        if days > 0 {
            return String(format: "%d d %d h", days, remHours)
        } else if hours > 0 {
            return String(format: "%d h %d m", hours, minutes)
        } else {
            return String(format: "%d m", minutes)
        }
    }

    static func timeRemaining(_ minutes: Int) -> String {
        if minutes < 0 { return "Calculating…" }
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 {
            return String(format: "%d:%02d remaining", h, m)
        }
        return String(format: "%d min remaining", m)
    }
}
