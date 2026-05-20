import Foundation
import Observation
import IOKit
#if arch(arm64)
import ServiceManagement
#endif

// MARK: - SMC Types (for reading)

private enum SMCDataType: String {
    case UI8 = "ui8 "
    case UI16 = "ui16"
    case UI32 = "ui32"
    case FLT = "flt "
    case FPE2 = "fpe2"
}

private enum SMCKeys: UInt8 {
    case kernelIndex = 2
    case readBytes = 5
    case writeBytes = 6
    case readKeyInfo = 9
}

private struct SMCKeyData_t {
    typealias SMCBytes_t = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                            UInt8, UInt8, UInt8, UInt8)

    struct vers_t {
        var major: CUnsignedChar = 0
        var minor: CUnsignedChar = 0
        var build: CUnsignedChar = 0
        var reserved: CUnsignedChar = 0
        var release: CUnsignedShort = 0
    }

    struct LimitData_t {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    struct keyInfo_t {
        var dataSize: IOByteCount32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    var key: UInt32 = 0
    var vers = vers_t()
    var pLimitData = LimitData_t()
    var keyInfo = keyInfo_t()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes_t = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
}

private struct SMCVal_t {
    var key: String
    var dataSize: UInt32 = 0
    var dataType: String = ""
    var bytes: [UInt8] = Array(repeating: 0, count: 32)

    init(_ key: String) {
        self.key = key
    }
}

private extension FourCharCode {
    init(fromString str: String) {
        precondition(str.count == 4)
        self = str.utf8.reduce(0) { sum, character in
            return sum << 8 | UInt32(character)
        }
    }

    func toString() -> String {
        return String(describing: UnicodeScalar(self >> 24 & 0xff)!) +
               String(describing: UnicodeScalar(self >> 16 & 0xff)!) +
               String(describing: UnicodeScalar(self >> 8  & 0xff)!) +
               String(describing: UnicodeScalar(self       & 0xff)!)
    }
}

private extension Int {
    init(fromFPE2 bytes: (UInt8, UInt8)) {
        self = (Int(bytes.0) << 6) + (Int(bytes.1) >> 2)
    }
}

private extension Float {
    var bytes: [UInt8] {
        withUnsafeBytes(of: self, Array.init)
    }

    init?(_ bytes: [UInt8]) {
        self = bytes.withUnsafeBytes {
            $0.load(fromByteOffset: 0, as: Self.self)
        }
    }
}

// MARK: - XPC Protocol (mirrors FanHelperProtocol in the helper binary)

#if arch(arm64)
@objc private protocol FanHelperProtocol {
    func setFanMode(_ id: Int, mode: Int, withReply reply: @escaping (Bool) -> Void)
    func setFanSpeed(_ id: Int, speed: Int, withReply reply: @escaping (Bool) -> Void)
    func resetFanControl(withReply reply: @escaping (Bool) -> Void)
}

private class FanHelperBridge {
    static let shared = FanHelperBridge()
    private var connection: NSXPCConnection?
    private let helperLabel = "com.alan13367.SiliconPulse.FanHelper"
    private var installAttempted = false

    private func proxy() -> FanHelperProtocol? {
        if let conn = connection {
            if let proxy = conn.remoteObjectProxy as? FanHelperProtocol {
                return proxy
            }
        }

        if !isInstalled() {
            if !installAttempted {
                installAttempted = true
                _ = install()
            }
            return nil
        }

        let conn = NSXPCConnection(machServiceName: helperLabel, options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: FanHelperProtocol.self)
        conn.invalidationHandler = { [weak self] in
            self?.connection = nil
        }
        conn.resume()
        connection = conn
        return conn.remoteObjectProxy as? FanHelperProtocol
    }

    func isInstalled() -> Bool {
        FileManager.default.fileExists(atPath: "/Library/PrivilegedHelperTools/\(helperLabel)")
    }

    func install() -> Bool {
        var authRef: AuthorizationRef?
        guard AuthorizationCreate(nil, nil, .interactionAllowed, &authRef) == errAuthorizationSuccess,
              let authRef else {
            return false
        }
        defer { AuthorizationFree(authRef, []) }

        var blessItem = AuthorizationItem(
            name: kSMRightBlessPrivilegedHelper,
            valueLength: 0,
            value: nil,
            flags: 0
        )
        var blessRights = AuthorizationRights(count: 1, items: &blessItem)
        let authFlags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]
        guard AuthorizationCopyRights(
            authRef,
            &blessRights,
            nil,
            authFlags,
            nil
        ) == errAuthorizationSuccess else {
            return false
        }

        var error: Unmanaged<CFError>?
        let result = SMJobBless(
            kSMDomainSystemLaunchd,
            helperLabel as CFString,
            authRef,
            &error
        )
        if !result {
            if let error = error?.takeRetainedValue() {
                print("SMJobBless error: \(error.localizedDescription)")
            }
            return false
        }
        return true
    }

    func setFanMode(_ id: Int, mode: Int) {
        proxy()?.setFanMode(id, mode: mode) { _ in }
    }

    func setFanSpeed(_ id: Int, speed: Int) {
        proxy()?.setFanSpeed(id, speed: speed) { _ in }
    }

    func resetFanControl() {
        proxy()?.resetFanControl { _ in }
    }
}
#endif

// MARK: - Fan Controller

@Observable
final class FanController {
    static let shared = FanController()

    var fanSpeeds: [Int] = []
    var fanNames: [String] = []
    var fanMinSpeeds: [Int] = []
    var fanMaxSpeeds: [Int] = []
    var fanCount: Int = 0
    var targetFanSpeed: Int = 0

    var fanMinRPM: Int {
        let mins = fanMinSpeeds.filter { $0 > 0 }
        return mins.max() ?? 0
    }

    var fanMaxRPM: Int {
        let maxes = fanMaxSpeeds.filter { $0 > 0 }
        return maxes.min() ?? 6000
    }
    var mode: FanMode = .automatic
    var isAvailable: Bool = false
    #if arch(arm64)
    var helperInstalled: Bool { FanHelperBridge.shared.isInstalled() }
    #endif

    private var conn: io_connect_t = 0
    private var timer: Timer?

    enum FanMode: String, CaseIterable, Sendable {
        case automatic = "Automatic"
        case manual = "Manual"
        case max = "Maximum"
        case off = "Off"
    }

    private init() {
        openSMC()
        if conn != 0 {
            isAvailable = true
            readFanInfo()
            startMonitoring()
        }
    }

    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.readFanInfo()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stopMonitoring()
        #if arch(arm64)
        FanHelperBridge.shared.resetFanControl()
        #endif
        if conn != 0 { IOServiceClose(conn) }
    }

    // MARK: - Public Interface

    func setMode(_ newMode: FanMode) {
        mode = newMode
        guard conn != 0 else { return }

        if newMode == .manual, targetFanSpeed == 0 {
            targetFanSpeed = currentManualBaselineRPM()
        }

        for i in 0..<fanCount {
            switch newMode {
            case .automatic:
                writeFanMode(i, mode: 0)
            case .max:
                writeFanMode(i, mode: 1)
                if let maxRPM = getValue("F\(i)Mx") {
                    writeFanSpeed(i, speed: Int(maxRPM))
                }
            case .off:
                writeFanMode(i, mode: 1)
                writeFanSpeed(i, speed: 0)
            case .manual:
                writeFanMode(i, mode: 1)
            }
        }
    }

    func setManualSpeed(_ rpm: Int) {
        guard mode == .manual, conn != 0 else { return }
        let clamped = clampRPM(rpm)
        targetFanSpeed = clamped
        for i in 0..<fanCount {
            writeFanSpeed(i, speed: clamped)
        }
    }

    private func currentManualBaselineRPM() -> Int {
        guard fanCount > 0 else { return fanMinRPM }

        var candidates: [Int] = []
        for i in 0..<fanCount {
            if let target = getValue("F\(i)Tg"), target > 0 {
                candidates.append(Int(target))
            } else if let actual = getValue("F\(i)Ac"), actual > 0 {
                candidates.append(Int(actual))
            } else if let current = fanSpeeds[safe: i], current > 0 {
                candidates.append(current)
            }
        }

        let baseline = candidates.max() ?? fanMinRPM
        return clampRPM(baseline)
    }

    private func clampRPM(_ rpm: Int) -> Int {
        let minRPM = fanMinRPM
        let maxRPM = max(fanMaxRPM, minRPM)
        return min(max(rpm, minRPM), maxRPM)
    }

    func installHelperIfNeeded() -> Bool {
        #if arch(arm64)
        if FanHelperBridge.shared.isInstalled() { return true }
        return FanHelperBridge.shared.install()
        #else
        return true
        #endif
    }

    // MARK: - Write dispatch (helper on arm64, direct on Intel)

    private func writeFanMode(_ id: Int, mode: Int) {
        #if arch(arm64)
        FanHelperBridge.shared.setFanMode(id, mode: mode)
        #else
        directSetFanMode(id, mode: mode)
        #endif
    }

    private func writeFanSpeed(_ id: Int, speed: Int) {
        #if arch(arm64)
        FanHelperBridge.shared.setFanSpeed(id, speed: speed)
        #else
        directSetFanSpeed(id, speed: speed)
        #endif
    }

    // MARK: - SMC Read

    private func openSMC() {
        var iterator: io_iterator_t = 0
        let matchingDictionary: CFMutableDictionary = IOServiceMatching("AppleSMC")
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDictionary, &iterator)
        if result != kIOReturnSuccess { return }

        let device = IOIteratorNext(iterator)
        IOObjectRelease(iterator)
        if device == 0 { return }

        let openResult = IOServiceOpen(device, mach_task_self_, 0, &conn)
        IOObjectRelease(device)
        if openResult != kIOReturnSuccess { conn = 0 }
    }

    private func readFanInfo() {
        guard conn != 0 else { return }
        guard let count = getValue("FNum") else {
            fanCount = 0
            return
        }

        fanCount = Int(count)
        var speeds: [Int] = []
        var names: [String] = []
        var mins: [Int] = []
        var maxes: [Int] = []

        for i in 0..<fanCount {
            let name = getStringValue("F\(i)ID") ?? "Fan #\(i + 1)"
            names.append(name)

            if let rpm = getValue("F\(i)Ac") {
                speeds.append(Int(rpm))
            } else {
                speeds.append(0)
            }

            mins.append(Int(getValue("F\(i)Mn") ?? 0))
            maxes.append(Int(getValue("F\(i)Mx") ?? 0))
        }

        fanSpeeds = speeds
        fanNames = names
        fanMinSpeeds = mins
        fanMaxSpeeds = maxes

        if mode == .manual, targetFanSpeed == 0 {
            targetFanSpeed = currentManualBaselineRPM()
        } else if mode == .manual {
            targetFanSpeed = clampRPM(targetFanSpeed)
        }
    }

    private func getValue(_ key: String) -> Double? {
        var val = SMCVal_t(key)
        let result = read(&val)
        guard result == kIOReturnSuccess else { return nil }

        if val.dataSize > 0 {
            if val.bytes.first(where: { $0 != 0 }) == nil {
                if key != "FS! " && key != "F0Md" && key != "F1Md" && key != "F0md" && key != "F1md" {
                    return nil
                }
            }

            switch val.dataType {
            case SMCDataType.UI8.rawValue:
                return Double(val.bytes[0])
            case SMCDataType.UI16.rawValue:
                return Double(UInt16(val.bytes[0]) << 8 | UInt16(val.bytes[1]))
            case SMCDataType.UI32.rawValue:
                return Double(UInt32(val.bytes[0]) << 24 | UInt32(val.bytes[1]) << 16 | UInt32(val.bytes[2]) << 8 | UInt32(val.bytes[3]))
            case SMCDataType.FLT.rawValue:
                let value: Float? = Float(val.bytes)
                return value != nil ? Double(value!) : nil
            case SMCDataType.FPE2.rawValue:
                return Double(Int(fromFPE2: (val.bytes[0], val.bytes[1])))
            default:
                return nil
            }
        }
        return nil
    }

    private func getStringValue(_ key: String) -> String? {
        var val = SMCVal_t(key)
        let result = read(&val)
        guard result == kIOReturnSuccess else { return nil }

        if val.dataSize > 0 {
            if val.bytes.first(where: { $0 != 0 }) == nil { return nil }
            if val.dataType == "{fds" {
                let c1 = String(UnicodeScalar(val.bytes[4]))
                let c2 = String(UnicodeScalar(val.bytes[5]))
                let c3 = String(UnicodeScalar(val.bytes[6]))
                let c4 = String(UnicodeScalar(val.bytes[7]))
                let c5 = String(UnicodeScalar(val.bytes[8]))
                let c6 = String(UnicodeScalar(val.bytes[9]))
                let c7 = String(UnicodeScalar(val.bytes[10]))
                let c8 = String(UnicodeScalar(val.bytes[11]))
                let c9 = String(UnicodeScalar(val.bytes[12]))
                let c10 = String(UnicodeScalar(val.bytes[13]))
                let c11 = String(UnicodeScalar(val.bytes[14]))
                let c12 = String(UnicodeScalar(val.bytes[15]))
                return (c1 + c2 + c3 + c4 + c5 + c6 + c7 + c8 + c9 + c10 + c11 + c12).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    // MARK: - Direct SMC Fan Control (Intel)

    #if !arch(arm64)
    private func directSetFanMode(_ id: Int, mode: Int) {
        if getValue("F\(id)Md") != nil {
            var value = SMCVal_t("F\(id)Md")
            guard read(&value) == kIOReturnSuccess else { return }
            value.bytes = Array(repeating: 0, count: 32)
            value.bytes[0] = UInt8(mode)
            _ = write(value)
        }

        let fansMode = Int(getValue("FS! ") ?? 0)
        var newMode: UInt8 = 0

        if fansMode == 0 && id == 0 && mode == 1 { newMode = 1 }
        else if fansMode == 0 && id == 1 && mode == 1 { newMode = 2 }
        else if fansMode == 1 && id == 0 && mode == 0 { newMode = 0 }
        else if fansMode == 1 && id == 1 && mode == 1 { newMode = 3 }
        else if fansMode == 2 && id == 1 && mode == 0 { newMode = 0 }
        else if fansMode == 2 && id == 0 && mode == 1 { newMode = 3 }
        else if fansMode == 3 && id == 0 && mode == 0 { newMode = 2 }
        else if fansMode == 3 && id == 1 && mode == 0 { newMode = 1 }

        if fansMode != Int(newMode) {
            var fsVal = SMCVal_t("FS! ")
            _ = read(&fsVal)
            fsVal.bytes = Array(repeating: 0, count: 32)
            fsVal.bytes[1] = newMode
            _ = write(fsVal)
        }
    }

    private func directSetFanSpeed(_ id: Int, speed: Int) {
        if let maxSpeed = getValue("F\(id)Mx"), speed > Int(maxSpeed) {
            return directSetFanSpeed(id, speed: Int(maxSpeed))
        }

        var value = SMCVal_t("F\(id)Tg")
        guard read(&value) == kIOReturnSuccess else { return }

        if value.dataType == "flt " {
            let bytes = Float(speed).bytes
            value.bytes[0] = bytes[0]
            value.bytes[1] = bytes[1]
            value.bytes[2] = bytes[2]
            value.bytes[3] = bytes[3]
        } else if value.dataType == "fpe2" {
            value.bytes[0] = UInt8(speed >> 6)
            value.bytes[1] = UInt8((speed << 2) ^ ((speed >> 6) << 8))
            value.bytes[2] = 0
            value.bytes[3] = 0
        }

        _ = write(value)
    }

    private func write(_ value: SMCVal_t) -> kern_return_t {
        var input = SMCKeyData_t()
        var output = SMCKeyData_t()

        input.key = FourCharCode(fromString: value.key)
        input.data8 = SMCKeys.writeBytes.rawValue
        input.keyInfo.dataSize = IOByteCount32(value.dataSize)
        input.bytes = (value.bytes[0], value.bytes[1], value.bytes[2], value.bytes[3], value.bytes[4], value.bytes[5],
                       value.bytes[6], value.bytes[7], value.bytes[8], value.bytes[9], value.bytes[10], value.bytes[11],
                       value.bytes[12], value.bytes[13], value.bytes[14], value.bytes[15], value.bytes[16], value.bytes[17],
                       value.bytes[18], value.bytes[19], value.bytes[20], value.bytes[21], value.bytes[22], value.bytes[23],
                       value.bytes[24], value.bytes[25], value.bytes[26], value.bytes[27], value.bytes[28], value.bytes[29],
                       value.bytes[30], value.bytes[31])

        let result = call(conn, SMCKeys.kernelIndex.rawValue, input: &input, output: &output)
        if result != kIOReturnSuccess { return result }
        if output.result != 0x00 { return kIOReturnError }
        return kIOReturnSuccess
    }
    #endif

    // MARK: - Low-level SMC (read only, used on all platforms)

    private func read(_ value: UnsafeMutablePointer<SMCVal_t>) -> kern_return_t {
        var input = SMCKeyData_t()
        var output = SMCKeyData_t()

        input.key = FourCharCode(fromString: value.pointee.key)
        input.data8 = SMCKeys.readKeyInfo.rawValue

        var result = call(conn, SMCKeys.kernelIndex.rawValue, input: &input, output: &output)
        if result != kIOReturnSuccess { return result }

        value.pointee.dataSize = UInt32(output.keyInfo.dataSize)
        value.pointee.dataType = output.keyInfo.dataType.toString()
        input.keyInfo.dataSize = output.keyInfo.dataSize
        input.data8 = SMCKeys.readBytes.rawValue

        result = call(conn, SMCKeys.kernelIndex.rawValue, input: &input, output: &output)
        if result != kIOReturnSuccess { return result }

        memcpy(&value.pointee.bytes, &output.bytes, Int(value.pointee.dataSize))
        return kIOReturnSuccess
    }

    private func call(_ conn: io_connect_t, _ index: UInt8, input: inout SMCKeyData_t, output: inout SMCKeyData_t) -> kern_return_t {
        let inputSize = MemoryLayout<SMCKeyData_t>.stride
        var outputSize = MemoryLayout<SMCKeyData_t>.stride
        return IOConnectCallStructMethod(conn, UInt32(index), &input, inputSize, &output, &outputSize)
    }
}
