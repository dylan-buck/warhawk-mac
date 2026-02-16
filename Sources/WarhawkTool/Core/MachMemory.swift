import Foundation
import CMachHelpers

/// Low-level memory read/write via Mach VM APIs.
/// All PS3 values are big-endian; this layer handles byte-swapping.
struct MachMemory {
    let task: mach_port_t

    // MARK: - Read

    func readUInt32(at address: UInt64) throws -> UInt32 {
        var value: UInt32 = 0
        let kr = mach_read_memory(task, address, 4, &value)
        guard kr == KERN_SUCCESS else {
            throw MemoryError.readFailed(address: address, code: kr)
        }
        return value.bigEndian
    }

    func readInt32(at address: UInt64) throws -> Int32 {
        let raw = try readUInt32(at: address)
        return Int32(bitPattern: raw)
    }

    func readUInt64(at address: UInt64) throws -> UInt64 {
        var value: UInt64 = 0
        let kr = mach_read_memory(task, address, 8, &value)
        guard kr == KERN_SUCCESS else {
            throw MemoryError.readFailed(address: address, code: kr)
        }
        return value.bigEndian
    }

    func readFloat(at address: UInt64) throws -> Float {
        let bits = try readUInt32(at: address)
        return Float(bitPattern: bits)
    }

    func readUInt16(at address: UInt64) throws -> UInt16 {
        var value: UInt16 = 0
        let kr = mach_read_memory(task, address, 2, &value)
        guard kr == KERN_SUCCESS else {
            throw MemoryError.readFailed(address: address, code: kr)
        }
        return value.bigEndian
    }

    func readInt16(at address: UInt64) throws -> Int16 {
        let raw = try readUInt16(at: address)
        return Int16(bitPattern: raw)
    }

    func readByte(at address: UInt64) throws -> UInt8 {
        var value: UInt8 = 0
        let kr = mach_read_memory(task, address, 1, &value)
        guard kr == KERN_SUCCESS else {
            throw MemoryError.readFailed(address: address, code: kr)
        }
        return value
    }

    func readBytes(at address: UInt64, count: Int) throws -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: count)
        let kr = mach_read_memory(task, address, mach_vm_size_t(count), &buffer)
        guard kr == KERN_SUCCESS else {
            throw MemoryError.readFailed(address: address, code: kr)
        }
        return buffer
    }

    func readString(at address: UInt64, maxLength: Int = 64) throws -> String {
        let bytes = try readBytes(at: address, count: maxLength)
        if let nullIdx = bytes.firstIndex(of: 0) {
            return String(bytes: bytes[..<nullIdx], encoding: .utf8) ?? ""
        }
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }

    // MARK: - Write

    func writeUInt32(at address: UInt64, value: UInt32) throws {
        var be = value.bigEndian
        let kr = mach_write_memory(task, address, 4, &be)
        guard kr == KERN_SUCCESS else {
            throw MemoryError.writeFailed(address: address, code: kr)
        }
    }

    func writeInt32(at address: UInt64, value: Int32) throws {
        try writeUInt32(at: address, value: UInt32(bitPattern: value))
    }

    func writeUInt64(at address: UInt64, value: UInt64) throws {
        var be = value.bigEndian
        let kr = mach_write_memory(task, address, 8, &be)
        guard kr == KERN_SUCCESS else {
            throw MemoryError.writeFailed(address: address, code: kr)
        }
    }

    func writeFloat(at address: UInt64, value: Float) throws {
        try writeUInt32(at: address, value: value.bitPattern)
    }

    func writeInt16(at address: UInt64, value: Int16) throws {
        var be = value.bigEndian
        let kr = mach_write_memory(task, address, 2, &be)
        guard kr == KERN_SUCCESS else {
            throw MemoryError.writeFailed(address: address, code: kr)
        }
    }

    func writeByte(at address: UInt64, value: UInt8) throws {
        var v = value
        let kr = mach_write_memory(task, address, 1, &v)
        guard kr == KERN_SUCCESS else {
            throw MemoryError.writeFailed(address: address, code: kr)
        }
    }

    func writeBytes(at address: UInt64, value: [UInt8]) throws {
        var buf = value
        let kr = mach_write_memory(task, address, mach_vm_size_t(value.count), &buf)
        guard kr == KERN_SUCCESS else {
            throw MemoryError.writeFailed(address: address, code: kr)
        }
    }

    func writeString(at address: UInt64, value: String) throws {
        var bytes = Array(value.utf8)
        bytes.append(0) // null terminator
        try writeBytes(at: address, value: bytes)
    }
}

enum MemoryError: Error, CustomStringConvertible {
    case readFailed(address: UInt64, code: kern_return_t)
    case writeFailed(address: UInt64, code: kern_return_t)
    case attachFailed(pid: pid_t, code: kern_return_t)
    case processNotFound(name: String)
    case baseAddressNotFound

    var description: String {
        switch self {
        case .readFailed(let addr, let code):
            return "Failed to read memory at 0x\(String(addr, radix: 16)) (error \(code))"
        case .writeFailed(let addr, let code):
            return "Failed to write memory at 0x\(String(addr, radix: 16)) (error \(code))"
        case .attachFailed(let pid, let code):
            return "Failed to attach to process \(pid) (error \(code)). Make sure you're running with sudo and the binary is signed with debugger entitlement."
        case .processNotFound(let name):
            return "Process '\(name)' not found. Is RPCS3 running?"
        case .baseAddressNotFound:
            return "Could not find RPCS3 memory base address. Is a game loaded?"
        }
    }
}
