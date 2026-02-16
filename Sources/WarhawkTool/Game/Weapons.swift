import Foundation

/// Ground and air weapon management.
struct Weapons {
    let bridge: RPCS3Bridge
    let pointers: Pointers

    // MARK: - Ground Weapons

    /// Give all ground weapons to the player. Call in a loop.
    func giveGroundWeaponsLoop(giveWrench: Bool) throws {
        let player = try pointers.playerPointer()

        // Check if on foot
        let vehicleCheck = try bridge.readUInt32(try pointers.resolve(player, Addr.vehicleOffset))
        guard vehicleCheck == 0 else { return }

        // Current weapon ID
        let currentWeapon = try bridge.readInt32(try pointers.resolve(player, Addr.currentWeaponOffset))

        for weapon in groundWeapons {
            if weapon.weaponID != currentWeapon {
                // Write ammo
                try bridge.writeInt32(
                    try pointers.resolve(player, weapon.ammoOffset),
                    value: weapon.ammoValue
                )
                // Equip weapon if slot is empty or has knife
                let slotAddr = try pointers.resolve(player, Addr.weaponSlotBase + Int32(weapon.slot))
                let current = try bridge.readByte(slotAddr)
                if current == 0xFF || (giveWrench && current == 9) {
                    try bridge.writeByte(slotAddr, value: weapon.weaponID)
                }
            }
        }

        // Write fire indicator
        try bridge.writeInt32(try pointers.resolve(player, Addr.weaponFireIndicator), value: 6)
    }

    /// Give a specific weapon to a slot.
    func giveWeapon(weaponID: UInt8, slot: Int) throws {
        let player = try pointers.playerPointer()
        let slotAddr = try pointers.resolve(player, Addr.weaponSlotBase + Int32(slot))
        try bridge.writeByte(slotAddr, value: weaponID)
    }

    // MARK: - Wrench

    /// Give wrench weapon. Call in a loop.
    func giveWrenchLoop() throws {
        let player = try pointers.playerPointer()
        let currentWeapon = try bridge.readInt32(try pointers.resolve(player, Addr.currentWeaponOffset))

        // Check if on foot
        let vehicleCheck = try bridge.readUInt32(try pointers.resolve(player, Addr.vehicleOffset))
        guard vehicleCheck == 0 else { return }

        if currentWeapon != 10 {
            try bridge.writeInt32(try pointers.resolve(player, Addr.wrenchHealth), value: 400)
            try giveWeapon(weaponID: 10, slot: 1)
        }
    }

    // MARK: - Air Weapons

    /// Give all air weapons. Call in a loop.
    func giveAirWeaponsLoop() throws {
        let player = try pointers.playerPointer()
        let vehicleAddr = try pointers.resolve(player, Addr.vehicleOffset)

        // Must be in a vehicle
        let vehicleValue = try bridge.readUInt32(vehicleAddr)
        guard vehicleValue != 0 else { return }

        // Vehicle must be alive
        let alive = try bridge.readInt32(try pointers.resolve(vehicleAddr, Addr.vehicleAliveCheck))

        if alive == 0 {
            // Check weapon state
            let weaponCheck = try bridge.readUInt64(try pointers.resolve(vehicleAddr, Addr.airWeaponCheck))
            // Skip if already fully armed or in certain states
            if weaponCheck == 18_446_744_073_709_551_369 || weaponCheck == 864_691_128_455_135_231 {
                return
            }
            guard weaponCheck != 0 else { return }

            // Write weapon loadout
            try bridge.writeUInt64(try pointers.resolve(vehicleAddr, Addr.airWeaponData),
                                   value: 505_532_382_493_935_621)

            // Set ammo for each air weapon slot
            let slots: [(offset: Int, value: Int16)] = [
                (Addr.airSlot_10368, 15),
                (Addr.airSlot_10064, 3),
                (Addr.airSlot_11536, 2),
                (Addr.airSlot_11024, 3),
                (Addr.airSlot_11328, 10),
                (Addr.airSlot_11776, 200),
                (Addr.airSlot_11184, 2),
                (Addr.airSlot_11936, 1),
            ]
            for slot in slots {
                let addr = try pointers.airPointer(offset: slot.offset)
                guard addr != 0 else { continue }
                try bridge.writeInt16(addr, value: slot.value)
            }
        }
    }

    // MARK: - Rapid Fire

    /// Enable/disable rapid fire for all weapons.
    func setRapidFire(enabled: Bool) throws {
        let player = try pointers.playerPointer()

        // Ground weapon fire rates
        let groundRapid: [(offset: Int32, enableVal: UInt32, disableVal: UInt32)] = [
            (Addr.rapidFire_18388, 0, Addr.rapidDefault_18388),
            (Addr.rapidFire_18580, 0, Addr.rapidDefault_18580),
            (Addr.rapidFire_18300, 0, Addr.rapidDefault_18300),
            (Addr.rapidFire_17116, 0, Addr.rapidDefault_17116),
            (Addr.rapidFire_17488, 0, Addr.rapidDefault_17488),
            (Addr.rapidFire_20900, 0, Addr.rapidDefault_20900),
            (Addr.rapidFire_18860, 0, Addr.rapidDefault_18860),
        ]

        for entry in groundRapid {
            let addr = try pointers.resolve(player, entry.offset)
            try bridge.writeUInt32(addr, value: enabled ? entry.enableVal : entry.disableVal)
        }

        // Air weapon fire rates
        let airRapid: [(offset: Int, enableVal: UInt32, disableVal: UInt32)] = [
            (Addr.airRapid_10232, 0, Addr.airRapidDefault_10232),
            (Addr.airRapid_11662, 0, Addr.airRapidDefault_11662),
            (Addr.airRapid_12046, 0, Addr.airRapidDefault_12046),
            (Addr.airRapid_10946, 0, Addr.airRapidDefault_10946),
            (Addr.airRapid_11132, 0, Addr.airRapidDefault_11132),
            (Addr.airRapid_11464, 0, Addr.airRapidDefault_11464),
        ]

        for entry in airRapid {
            let addr = try pointers.airPointer(offset: entry.offset)
            guard addr != 0 else { continue }
            try bridge.writeUInt32(addr, value: enabled ? entry.enableVal : entry.disableVal)
        }
    }

    /// Rapid fire loop - forces re-fire for current weapon. Call in a loop.
    func rapidWeaponsLoop() throws {
        let player = try pointers.playerPointer()

        // Check weapon state (2048 = zoomed/aiming, 1024 = on foot normal)
        let weaponState = try bridge.readUInt32(Addr.weaponState)

        if weaponState == 2048 {
            // Check which weapon is equipped in aiming slot
            let equipped = try bridge.readByte(try pointers.resolve(player, Addr.weaponSlotBase + 17))
            switch equipped {
            case 2:
                try bridge.writeByte(try pointers.resolve(player, Addr.rapidWeapon2Byte), value: 2)
            case 5:
                try bridge.writeByte(try pointers.resolve(player, Addr.rapidWeapon5Byte), value: 2)
            case 7:
                try bridge.writeByte(try pointers.resolve(player, Addr.rapidWeapon7Byte), value: 2)
            default:
                break
            }
        }

        if weaponState == 1024 {
            let vehicleCheck = try bridge.readUInt32(try pointers.resolve(player, Addr.vehicleOffset))
            if vehicleCheck == 0 {
                try bridge.writeByte(try pointers.resolve(player, Addr.rapidGroundByte), value: 2)
            }
        }
    }
}
