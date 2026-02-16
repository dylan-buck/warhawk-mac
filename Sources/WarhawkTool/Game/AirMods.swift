import Foundation

/// Air vehicle mods: infinite air mods, instant lock-on.
struct AirMods {
    let bridge: RPCS3Bridge
    let pointers: Pointers

    // MARK: - Infinite Air Mods

    /// Set vehicle mods to infinite (no cooldown/unlimited boost). Call in a loop.
    func infiniteAirModsLoop() throws {
        let player = try pointers.playerPointer()
        let vehicleAddr = try pointers.resolve(player, Addr.vehicleOffset)

        // Check vehicle is alive
        let alive = try bridge.readInt32(try pointers.resolve(vehicleAddr, Addr.vehicleAliveCheck))
        guard alive == 0 else { return }

        // Check if it's a Warhawk (hawk)
        let typeCheck = try bridge.readUInt32(try pointers.resolve(vehicleAddr, Addr.hawkCheckOffset))
        if typeCheck == Addr.hawkIdentifier {
            // Hawk-specific: zero out hawk cooldown
            try bridge.writeFloat(try pointers.resolve(vehicleAddr, Addr.hawkCooldown), value: 0.0)
            // Also energy
            try bridge.writeFloat(try pointers.resolve(vehicleAddr, Addr.vehicleEnergy), value: 100.0)
        } else {
            // Non-hawk aircraft: zero cooldown and max boost
            try bridge.writeFloat(try pointers.resolve(vehicleAddr, Addr.aircraftCooldown), value: 0.0)
            try bridge.writeFloat(try pointers.resolve(vehicleAddr, Addr.aircraftBoost), value: 100.0)
        }
    }

    // MARK: - Instant Lock-On

    enum LockMode: Int, CaseIterable {
        case off = 0
        case all = 1       // ground + air lock + air reload
        case airReload = 2 // air reload only
        case airLock = 3   // air lock only
        case ground = 4    // ground only

        var label: String {
            switch self {
            case .off: return "Off"
            case .all: return "All (Ground + Air)"
            case .airReload: return "Air Reload Only"
            case .airLock: return "Air Lock Only"
            case .ground: return "Ground Only"
            }
        }
    }

    /// Apply instant lock-on based on mode. Call in a loop for continuous effect.
    func instantLockLoop(mode: LockMode) throws {
        let player = try pointers.playerPointer()
        let vehicleAddr = try pointers.resolve(player, Addr.vehicleOffset)
        let vehicleValue = try bridge.readUInt32(vehicleAddr)

        if vehicleValue == 0 {
            // On foot
            if mode == .ground || mode == .all {
                try bridge.writeFloat(try pointers.resolve(player, Addr.groundMissileLock), value: 1.0)
            }
        } else {
            // In vehicle
            let alive = try bridge.readInt32(try pointers.resolve(vehicleAddr, Addr.vehicleAliveCheck))
            guard alive == 0 else { return }

            // Air lock
            if mode == .airLock || mode == .all {
                let addr = try pointers.airPointer(offset: Addr.airLockTime)
                if addr != 0 {
                    try bridge.writeInt32(addr, value: 0)
                }
            } else {
                let addr = try pointers.airPointer(offset: Addr.airLockTime)
                if addr != 0 {
                    try bridge.writeInt32(addr, value: Addr.airLockDefault)
                }
            }

            // Air reload
            if mode == .airReload || mode == .all {
                let addr = try pointers.airPointer(offset: Addr.airReloadTime)
                if addr != 0 {
                    try bridge.writeInt32(addr, value: 0)
                }
            } else {
                let addr = try pointers.airPointer(offset: Addr.airReloadTime)
                if addr != 0 {
                    try bridge.writeInt32(addr, value: Addr.airReloadDefault)
                }
            }
        }
    }

    /// Restore all lock-on values to defaults.
    func disableInstantLock() throws {
        let lockAddr = try pointers.airPointer(offset: Addr.airLockTime)
        if lockAddr != 0 {
            try bridge.writeInt32(lockAddr, value: Addr.airLockDefault)
        }
        let reloadAddr = try pointers.airPointer(offset: Addr.airReloadTime)
        if reloadAddr != 0 {
            try bridge.writeInt32(reloadAddr, value: Addr.airReloadDefault)
        }
    }
}
