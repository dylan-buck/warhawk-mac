import Foundation
import CMachHelpers

/// Manages connection to RPCS3 and translates PS3 addresses to host addresses.
///
/// RPCS3 maps PS3 memory at `g_base_addr` and creates an unprotected "sudo" mirror
/// at `g_base_addr + 0x100000000`. We discover these addresses by parsing RPCS3's
/// log file, which prints them on startup.
final class RPCS3Bridge {
    let pid: pid_t
    let task: mach_port_t
    let memory: MachMemory

    /// The base address of RPCS3's PS3 memory mapping in host address space
    let gBaseAddr: UInt64

    /// The sudo (unprotected) mirror address: gBaseAddr + 0x100000000
    var gSudoAddr: UInt64 { gBaseAddr + 0x1_0000_0000 }

    private init(pid: pid_t, task: mach_port_t, gBaseAddr: UInt64) {
        self.pid = pid
        self.task = task
        self.memory = MachMemory(task: task)
        self.gBaseAddr = gBaseAddr
    }

    /// Connect to RPCS3 process and discover memory layout.
    static func connect() throws -> RPCS3Bridge {
        // Find RPCS3 process
        let pid = try ProcessFinder.findPID(named: "rpcs3")

        // Attach via task_for_pid
        var task: mach_port_t = 0
        let kr = mach_attach(pid, &task)
        guard kr == KERN_SUCCESS else {
            throw MemoryError.attachFailed(pid: pid, code: kr)
        }

        // Discover g_base_addr from RPCS3's log file
        let gBaseAddr = try discoverBaseAddress(task: task)

        return RPCS3Bridge(pid: pid, task: task, gBaseAddr: gBaseAddr)
    }

    /// Translate a PS3 address to host address using the sudo mirror.
    func translate(_ ps3Address: UInt32) -> UInt64 {
        return gSudoAddr + UInt64(ps3Address)
    }

    // MARK: - Convenience read/write using PS3 addresses

    func readUInt32(_ ps3Address: UInt32) throws -> UInt32 {
        try memory.readUInt32(at: translate(ps3Address))
    }

    func readInt32(_ ps3Address: UInt32) throws -> Int32 {
        try memory.readInt32(at: translate(ps3Address))
    }

    func readUInt64(_ ps3Address: UInt32) throws -> UInt64 {
        try memory.readUInt64(at: translate(ps3Address))
    }

    func readFloat(_ ps3Address: UInt32) throws -> Float {
        try memory.readFloat(at: translate(ps3Address))
    }

    func readInt16(_ ps3Address: UInt32) throws -> Int16 {
        try memory.readInt16(at: translate(ps3Address))
    }

    func readByte(_ ps3Address: UInt32) throws -> UInt8 {
        try memory.readByte(at: translate(ps3Address))
    }

    func readBytes(_ ps3Address: UInt32, count: Int) throws -> [UInt8] {
        try memory.readBytes(at: translate(ps3Address), count: count)
    }

    func readString(_ ps3Address: UInt32, maxLength: Int = 64) throws -> String {
        try memory.readString(at: translate(ps3Address), maxLength: maxLength)
    }

    func writeUInt32(_ ps3Address: UInt32, value: UInt32) throws {
        try memory.writeUInt32(at: translate(ps3Address), value: value)
    }

    func writeInt32(_ ps3Address: UInt32, value: Int32) throws {
        try memory.writeInt32(at: translate(ps3Address), value: value)
    }

    func writeUInt64(_ ps3Address: UInt32, value: UInt64) throws {
        try memory.writeUInt64(at: translate(ps3Address), value: value)
    }

    func writeFloat(_ ps3Address: UInt32, value: Float) throws {
        try memory.writeFloat(at: translate(ps3Address), value: value)
    }

    func writeInt16(_ ps3Address: UInt32, value: Int16) throws {
        try memory.writeInt16(at: translate(ps3Address), value: value)
    }

    func writeByte(_ ps3Address: UInt32, value: UInt8) throws {
        try memory.writeByte(at: translate(ps3Address), value: value)
    }

    func writeBytes(_ ps3Address: UInt32, value: [UInt8]) throws {
        try memory.writeBytes(at: translate(ps3Address), value: value)
    }

    func writeString(_ ps3Address: UInt32, value: String) throws {
        try memory.writeString(at: translate(ps3Address), value: value)
    }

    // MARK: - Base Address Discovery

    /// Discover g_base_addr by parsing RPCS3's log file.
    /// RPCS3 prints "vm::g_base_addr = XXXXXXXXXXXXXXXX" on startup.
    /// Falls back to memory region scanning if log parsing fails.
    private static func discoverBaseAddress(task: mach_port_t) throws -> UInt64 {
        // Strategy 1: Parse RPCS3 log file
        if let addr = parseLogForBaseAddress() {
            return addr
        }

        // Strategy 2: Scan memory regions for 8GB mapping
        if let addr = scanForLargeRegion(task: task) {
            return addr
        }

        throw MemoryError.baseAddressNotFound
    }

    /// Parse RPCS3's log file to find the printed g_base_addr.
    /// Uses line-by-line streaming to handle large log files (can be 300MB+).
    private static func parseLogForBaseAddress() -> UInt64? {
        // When running under sudo, homeDirectoryForCurrentUser returns /var/root.
        // Use SUDO_USER to find the real user's home directory.
        var homes: [URL] = []
        if let sudoUser = ProcessInfo.processInfo.environment["SUDO_USER"] {
            homes.append(URL(fileURLWithPath: "/Users/\(sudoUser)"))
        }
        homes.append(FileManager.default.homeDirectoryForCurrentUser)

        var logPaths: [URL] = []
        for home in homes {
            logPaths.append(home.appendingPathComponent("Library/Caches/rpcs3/RPCS3.log"))
            logPaths.append(home.appendingPathComponent(".config/rpcs3/RPCS3.log"))
        }

        let needle = "vm::g_base_addr = "

        for logPath in logPaths {
            guard let fh = try? FileHandle(forReadingFrom: logPath) else {
                continue
            }
            defer { fh.closeFile() }

            var lastMatch: UInt64?
            let bufSize = 1024 * 1024  // 1MB chunks
            var leftover = ""

            while true {
                guard let chunk = try? fh.read(upToCount: bufSize), !chunk.isEmpty else {
                    break
                }
                guard let str = String(data: chunk, encoding: .utf8) else { continue }

                let combined = leftover + str
                let lines = combined.split(separator: "\n", omittingEmptySubsequences: false)

                // Process all lines except possibly-incomplete last one
                for i in 0..<(lines.count - 1) {
                    let line = lines[i]
                    if let range = line.range(of: needle) {
                        let afterEq = line[range.upperBound...]
                        let hex = afterEq.prefix(while: { $0.isHexDigit })
                        if let addr = UInt64(hex, radix: 16) {
                            lastMatch = addr
                        }
                    }
                }

                leftover = String(lines.last ?? "")
            }

            // Check leftover
            if let range = leftover.range(of: needle) {
                let afterEq = leftover[range.upperBound...]
                let hex = afterEq.prefix(while: { $0.isHexDigit })
                if let addr = UInt64(hex, radix: 16) {
                    lastMatch = addr
                }
            }

            if let addr = lastMatch {
                return addr
            }
        }

        return nil
    }

    /// Scan RPCS3's memory regions to find a large (8GB) mapping using C helper.
    private static func scanForLargeRegion(task: mach_port_t) -> UInt64? {
        var outAddress: mach_vm_address_t = 0
        var outSize: mach_vm_size_t = 0

        // Try finding an 8GB region first (RPCS3's full reservation)
        let kr = mach_find_large_region(task, 0x2_0000_0000, 0x2_0000_0000,
                                        &outAddress, &outSize)
        if kr == KERN_SUCCESS {
            return outAddress
        }

        // Fall back to 4GB minimum
        let kr2 = mach_find_large_region(task, 0x2_0000_0000, 0x1_0000_0000,
                                         &outAddress, &outSize)
        if kr2 == KERN_SUCCESS {
            return outAddress
        }

        return nil
    }
}
