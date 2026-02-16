import Foundation

/// Flag teleport feature.
struct Teleport {
    let bridge: RPCS3Bridge
    let pointers: Pointers

    /// Teleport to a position.
    func teleportTo(x: Float, y: Float, z: Float) throws {
        let player = try pointers.playerPointer()

        // Must be on foot
        let vehicleCheck = try bridge.readUInt32(try pointers.resolve(player, Addr.vehicleOffset))
        guard vehicleCheck == 0 else {
            print("Cannot teleport while in a vehicle")
            return
        }

        // Get position pointer: getPointer(getPointer(player, 12), 64)
        let posAddr = try pointers.resolve(
            try pointers.resolve(player, Addr.positionPtrOffset),
            Addr.positionXYZOffset
        )

        try bridge.writeFloat(posAddr, value: x)
        try bridge.writeFloat(posAddr + 4, value: y)
        try bridge.writeFloat(posAddr + 8, value: z)
    }

    /// Teleport to the enemy flag (CTF mode).
    func teleportToFlag() throws {
        let player = try pointers.playerPointer()

        // Must be alive
        let playerValue = try bridge.readUInt32(UInt32(player))
        guard playerValue != 0 else {
            print("Player not spawned")
            return
        }

        // Check teams
        let team1 = try bridge.readUInt32(Addr.teamData1)
        let team2 = try bridge.readUInt32(Addr.teamData2)
        guard team1 != 10 && team2 != 10 else {
            print("Not in a team game")
            return
        }

        // Read flag positions
        let flag1X = try bridge.readFloat(Addr.flag1X)
        let flag1Y = try bridge.readFloat(Addr.flag1Y)
        let flag1Z = try bridge.readFloat(Addr.flag1Z) - 11.0
        let flag2X = try bridge.readFloat(Addr.flag2X)
        let flag2Y = try bridge.readFloat(Addr.flag2Y)
        let flag2Z = try bridge.readFloat(Addr.flag2Z) - 11.0

        // Read game mode
        let gameMode = try bridge.readUInt32(try pointers.resolve(Addr.gameState, Addr.gameModeOffset))

        // Read which team's flag data
        let flagData = try bridge.readUInt32(try bridge.readUInt32(Addr.flagDataPtr))
        let flagData2 = try bridge.readUInt32(try pointers.resolve(Addr.flagDataPtr, Addr.flagDataPtrOffset))

        if gameMode == 1 {
            // CTF mode
            if flagData == 0 {
                try teleportTo(x: flag1X, y: flag1Y, z: flag1Z)
            } else {
                try teleportTo(x: flag2X, y: flag2Y, z: flag2Z)
            }
        } else {
            // Other modes
            if flagData2 == 0 {
                try teleportTo(x: flag2X, y: flag2Y, z: flag2Z)
            } else {
                try teleportTo(x: flag1X, y: flag1Y, z: flag1Z)
            }
        }
    }
}
