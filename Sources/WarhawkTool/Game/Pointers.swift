import Foundation

/// Pointer chain resolution for Warhawk's memory structures.
///
/// The game uses multi-level pointer chains:
/// `getPointer(address, offset1, offset2, ...)` means:
///   1. Read UInt32 at `address`
///   2. Add `offset1` to get next address
///   3. Read UInt32 at that address
///   4. Add `offset2`, etc.
///   5. Return final address (NOT dereferenced)
struct Pointers {
    let bridge: RPCS3Bridge

    /// Resolve a PS3 pointer chain.
    /// Each offset is added to the dereferenced value of the previous address.
    /// Returns the final PS3 address (not dereferenced).
    func resolve(_ base: UInt32, _ offsets: Int32...) throws -> UInt32 {
        return try resolve(base, offsets: offsets)
    }

    func resolve(_ base: UInt32, offsets: [Int32]) throws -> UInt32 {
        var address = base
        for offset in offsets {
            let value = try bridge.readUInt32(address)
            address = UInt32(Int64(value) + Int64(offset))
        }
        return address
    }

    /// Get the player struct pointer: getPointer(gameState, 4)
    func playerPointer() throws -> UInt32 {
        try resolve(Addr.gameState, Addr.playerPtrOffset)
    }

    /// Get the vehicle struct pointer: getPointer(playerPtr, 2004)
    func vehiclePointer() throws -> UInt32 {
        let player = try playerPointer()
        return try resolve(player, Addr.vehicleOffset)
    }

    /// Resolve the air vehicle pointer, accounting for Hawk vs other aircraft.
    /// The original uses different offsets for Warhawk (hawk) vs other vehicles.
    ///
    /// For hawk (identifier == 0xBDC4B1BD): airPointer = getPointer(vehiclePtr, offset + 6336)
    /// For others: airPointer = getPointer(vehiclePtr, offset)
    func airPointer(offset: Int) throws -> UInt32 {
        let player = try playerPointer()
        let vehicle = try resolve(player, Addr.vehicleOffset)

        // Check if vehicle is alive
        let alive = try bridge.readInt32(try resolve(vehicle, Addr.vehicleAliveCheck))
        guard alive == 0 else { return 0 }

        // Check if it's a Warhawk (hawk)
        let typeCheck = try bridge.readUInt32(try resolve(vehicle, Addr.hawkCheckOffset))
        if typeCheck == Addr.hawkIdentifier {
            return try resolve(vehicle, Int32(offset + Addr.hawkOffsetDelta))
        } else {
            return try resolve(vehicle, Int32(offset))
        }
    }

    /// Check if the player is on foot (vehicle value == 0)
    func isOnFoot() throws -> Bool {
        let player = try playerPointer()
        let vehicleAddr = try resolve(player, Addr.vehicleOffset)
        let value = try bridge.readUInt32(vehicleAddr)
        return value == 0
    }

    /// Check if in a vehicle and the vehicle is alive
    func isInVehicle() throws -> Bool {
        let player = try playerPointer()
        let vehicleAddr = try resolve(player, Addr.vehicleOffset)
        let vehicleValue = try bridge.readUInt32(vehicleAddr)
        if vehicleValue == 0 { return false }

        let alive = try bridge.readInt32(try resolve(vehicleAddr, Addr.vehicleAliveCheck))
        return alive == 0
    }

    /// FOV pointer: getPointer(fovPtrBase, 912)
    func fovPointer() throws -> UInt32 {
        try resolve(Addr.fovPtrBase, Addr.fovOffset)
    }
}
