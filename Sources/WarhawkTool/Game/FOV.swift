import Foundation

/// FOV (Field of View) management.
struct FOV {
    let bridge: RPCS3Bridge
    let pointers: Pointers

    /// Get the base FOV value depending on the current state (on foot, hawk, other vehicle).
    func getBaseFOV() throws -> Float {
        let player = try pointers.playerPointer()
        let vehicleAddr = try pointers.resolve(player, Addr.vehicleOffset)
        let vehicleValue = try bridge.readInt32(UInt32(vehicleAddr))

        if vehicleValue == 0 {
            // On foot
            return 50.73
        }

        let alive = try bridge.readInt32(try pointers.resolve(vehicleAddr, Addr.vehicleAliveCheck))
        if alive == 0 {
            // In vehicle, check if warhawk by reading offset 1856
            let check = try bridge.readUInt32(try pointers.resolve(vehicleAddr, 1856))
            if check == 256 {
                return 64.0  // Warhawk
            }
        }
        return 54.43267  // Other vehicle
    }

    /// Get current FOV value from memory.
    func getCurrentFOV() throws -> Float {
        let fovAddr = try pointers.fovPointer()
        return try bridge.readFloat(fovAddr)
    }

    /// Set FOV to an absolute value.
    func setFOV(_ value: Float) throws {
        let fovAddr = try pointers.fovPointer()
        try bridge.writeFloat(fovAddr, value: value)
    }

    /// Set FOV as an offset from the base FOV.
    func setFOVOffset(_ offset: Float) throws {
        let base = try getBaseFOV()
        try setFOV(base + offset)
    }

    /// Reset FOV to default.
    func resetFOV() throws {
        let base = try getBaseFOV()
        try setFOV(base)
    }

    /// Continuously write FOV value. Call from a loop thread.
    func fovLoop(value: Float) throws {
        let fovAddr = try pointers.fovPointer()
        try bridge.writeFloat(fovAddr, value: value)
    }
}
