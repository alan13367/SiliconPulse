import Foundation
import IOKit

// MARK: - Protocol

@objc protocol FanHelperProtocol {
    func setFanMode(_ id: Int, mode: Int, withReply reply: @escaping (Bool) -> Void)
    func setFanSpeed(_ id: Int, speed: Int, withReply reply: @escaping (Bool) -> Void)
    func resetFanControl(withReply reply: @escaping (Bool) -> Void)
}

// MARK: - SMC Types

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
}

// MARK: - SMCHelper

private class SMCHelper {
    private var conn: io_connect_t = 0
    private var _fanModeKeyIsLower: Bool?

    init() {
        openSMC()
    }

    deinit {
        if conn != 0 { IOServiceClose(conn) }
    }

    var isOpen: Bool { conn != 0 }

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

    func getValue(_ key: String) -> Double? {
        var val = SMCVal_t(key)
        guard read(&val) == kIOReturnSuccess else { return nil }

        if val.dataSize > 0 {
            if val.bytes.first(where: { $0 != 0 }) == nil {
                if key != "FS! " && key != "F0Md" && key != "F1Md" && key != "F0md" && key != "F1md" {
                    return nil
                }
            }

            switch val.dataType {
            case "ui8 ": return Double(val.bytes[0])
            case "ui16": return Double(UInt16(val.bytes[0]) << 8 | UInt16(val.bytes[1]))
            case "ui32": return Double(UInt32(val.bytes[0]) << 24 | UInt32(val.bytes[1]) << 16 | UInt32(val.bytes[2]) << 8 | UInt32(val.bytes[3]))
            case "flt ":
                let value = val.bytes.withUnsafeBytes { $0.load(fromByteOffset: 0, as: Float.self) }
                return Double(value)
            case "fpe2": return Double(Int(fromFPE2: (val.bytes[0], val.bytes[1])))
            default: return nil
            }
        }
        return nil
    }

    func fanModeKey(_ id: Int) -> String {
        #if arch(arm64)
        if _fanModeKeyIsLower == nil {
            var probe = SMCVal_t("F0md")
            _fanModeKeyIsLower = read(&probe) == kIOReturnSuccess && probe.dataSize > 0
        }
        return _fanModeKeyIsLower! ? "F\(id)md" : "F\(id)Md"
        #else
        return "F\(id)Md"
        #endif
    }

    func setFanMode(_ id: Int, mode: Int) -> Bool {
        #if arch(arm64)
        if mode == 1 {
            guard unlockFanControl(fanId: id) else { return false }
        } else {
            let modeKey = fanModeKey(id)

            if getValue(modeKey) != nil {
                var modeVal = SMCVal_t(modeKey)
                guard read(&modeVal) == kIOReturnSuccess else { return false }
                if modeVal.bytes[0] != 0 {
                    modeVal.bytes[0] = 0
                    guard writeWithRetry(modeVal) else { return false }
                }
            }

            var targetValue = SMCVal_t("F\(id)Tg")
            guard read(&targetValue) == kIOReturnSuccess else { return false }
            let bytes = Float(0).bytes
            targetValue.bytes[0] = bytes[0]
            targetValue.bytes[1] = bytes[1]
            targetValue.bytes[2] = bytes[2]
            targetValue.bytes[3] = bytes[3]
            _ = writeWithRetry(targetValue)
        }
        return true
        #else
        if getValue("F\(id)Md") != nil {
            var value = SMCVal_t("F\(id)Md")
            guard read(&value) == kIOReturnSuccess else { return false }
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
        return true
        #endif
    }

    func setFanSpeed(_ id: Int, speed: Int) -> Bool {
        if let maxSpeed = getValue("F\(id)Mx"), speed > Int(maxSpeed) {
            return setFanSpeed(id, speed: Int(maxSpeed))
        }

        #if arch(arm64)
        var modeVal = SMCVal_t(fanModeKey(id))
        guard read(&modeVal) == kIOReturnSuccess else { return false }
        if modeVal.bytes[0] != 1 {
            guard unlockFanControl(fanId: id) else { return false }
        }
        #endif

        var value = SMCVal_t("F\(id)Tg")
        guard read(&value) == kIOReturnSuccess else { return false }

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

        #if arch(arm64)
        return writeWithRetry(value)
        #else
        return write(value) == kIOReturnSuccess
        #endif
    }

    #if arch(arm64)
    private func writeWithRetry(_ value: SMCVal_t, maxAttempts: Int = 10, delayMicros: UInt32 = 50_000) -> Bool {
        let mutableValue = value
        for attempt in 0..<maxAttempts {
            if write(mutableValue) == kIOReturnSuccess {
                return true
            }
            if attempt < maxAttempts - 1 {
                usleep(delayMicros)
            }
        }
        return false
    }

    private func unlockFanControl(fanId: Int) -> Bool {
        let modeKey = fanModeKey(fanId)
        var modeVal = SMCVal_t(modeKey)
        guard read(&modeVal) == kIOReturnSuccess else { return false }
        modeVal.bytes[0] = 1
        if write(modeVal) == kIOReturnSuccess {
            return true
        }

        var ftstVal = SMCVal_t("Ftst")
        guard read(&ftstVal) == kIOReturnSuccess, ftstVal.dataSize > 0 else { return false }

        if ftstVal.bytes[0] == 1 {
            return retryModeWrite(fanId: fanId, maxAttempts: 20)
        }

        ftstVal.bytes[0] = 1
        if !writeWithRetry(ftstVal, maxAttempts: 100) {
            return false
        }

        usleep(3_000_000)

        return retryModeWrite(fanId: fanId, maxAttempts: 300)
    }

    private func retryModeWrite(fanId: Int, maxAttempts: Int) -> Bool {
        let modeKey = fanModeKey(fanId)
        var modeVal = SMCVal_t(modeKey)
        guard read(&modeVal) == kIOReturnSuccess else { return false }
        modeVal.bytes[0] = 1
        return writeWithRetry(modeVal, maxAttempts: maxAttempts, delayMicros: 100_000)
    }

    func resetFanControl() -> Bool {
        var value = SMCVal_t("Ftst")
        if read(&value) == kIOReturnSuccess, value.dataSize > 0 {
            if value.bytes[0] == 0 { return true }
            value.bytes[0] = 0
            return writeWithRetry(value)
        }

        guard let count = getValue("FNum") else { return false }
        var success = true
        for i in 0..<Int(count) {
            let modeKey = fanModeKey(i)
            var modeVal = SMCVal_t(modeKey)
            guard read(&modeVal) == kIOReturnSuccess else { continue }
            if modeVal.bytes[0] == 0 { continue }
            modeVal.bytes[0] = 0
            if !writeWithRetry(modeVal) { success = false }
        }
        return success
    }
    #endif

    private func read(_ value: UnsafeMutablePointer<SMCVal_t>) -> kern_return_t {
        var input = SMCKeyData_t()
        var output = SMCKeyData_t()

        input.key = FourCharCode(fromString: value.pointee.key)
        input.data8 = SMCKeys.readKeyInfo.rawValue

        var result = call(SMCKeys.kernelIndex.rawValue, input: &input, output: &output)
        if result != kIOReturnSuccess { return result }

        value.pointee.dataSize = UInt32(output.keyInfo.dataSize)
        value.pointee.dataType = output.keyInfo.dataType.toString()
        input.keyInfo.dataSize = output.keyInfo.dataSize
        input.data8 = SMCKeys.readBytes.rawValue

        result = call(SMCKeys.kernelIndex.rawValue, input: &input, output: &output)
        if result != kIOReturnSuccess { return result }

        memcpy(&value.pointee.bytes, &output.bytes, Int(value.pointee.dataSize))
        return kIOReturnSuccess
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

        let result = call(SMCKeys.kernelIndex.rawValue, input: &input, output: &output)
        if result != kIOReturnSuccess { return result }
        if output.result != 0x00 { return kIOReturnError }
        return kIOReturnSuccess
    }

    private func call(_ index: UInt8, input: inout SMCKeyData_t, output: inout SMCKeyData_t) -> kern_return_t {
        let inputSize = MemoryLayout<SMCKeyData_t>.stride
        var outputSize = MemoryLayout<SMCKeyData_t>.stride
        return IOConnectCallStructMethod(conn, UInt32(index), &input, inputSize, &output, &outputSize)
    }
}

// MARK: - Helper Service

@objc(FanHelperService)
class FanHelperService: NSObject, NSXPCListenerDelegate, FanHelperProtocol {
    private let listener: NSXPCListener
    private let smc: SMCHelper

    override init() {
        self.smc = SMCHelper()
        self.listener = NSXPCListener(machServiceName: "com.alan13367.SiliconPulse.FanHelper")
        super.init()
        self.listener.delegate = self
    }

    func run() {
        listener.resume()
        RunLoop.current.run()
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: FanHelperProtocol.self)
        newConnection.exportedObject = self
        newConnection.invalidationHandler = { exit(0) }
        newConnection.resume()
        return true
    }

    func setFanMode(_ id: Int, mode: Int, withReply reply: @escaping (Bool) -> Void) {
        guard smc.isOpen else { reply(false); return }
        reply(smc.setFanMode(id, mode: mode))
    }

    func setFanSpeed(_ id: Int, speed: Int, withReply reply: @escaping (Bool) -> Void) {
        guard smc.isOpen else { reply(false); return }
        reply(smc.setFanSpeed(id, speed: speed))
    }

    func resetFanControl(withReply reply: @escaping (Bool) -> Void) {
        guard smc.isOpen else { reply(false); return }
        #if arch(arm64)
        reply(smc.resetFanControl())
        #else
        reply(true)
        #endif
    }
}

// MARK: - Entry Point

let service = FanHelperService()
service.run()
