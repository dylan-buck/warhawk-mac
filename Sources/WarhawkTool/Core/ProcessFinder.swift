import Foundation

/// Find a running process by name using sysctl.
struct ProcessFinder {
    static func findPID(named name: String) throws -> pid_t {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size: Int = 0

        // Get buffer size
        guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0 else {
            throw MemoryError.processNotFound(name: name)
        }

        let count = size / MemoryLayout<kinfo_proc>.stride
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)

        guard sysctl(&mib, UInt32(mib.count), &procs, &size, nil, 0) == 0 else {
            throw MemoryError.processNotFound(name: name)
        }

        let actualCount = size / MemoryLayout<kinfo_proc>.stride

        for i in 0..<actualCount {
            let proc = procs[i]
            let procName = withUnsafePointer(to: proc.kp_proc.p_comm) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN)) { cstr in
                    String(cString: cstr)
                }
            }
            if procName.lowercased().contains(name.lowercased()) {
                return proc.kp_proc.p_pid
            }
        }

        throw MemoryError.processNotFound(name: name)
    }
}
