import ArgumentParser
import Foundation

struct WarhawkTool: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "warhawk-tool",
        abstract: "Warhawk modding tool for RPCS3 on macOS",
        discussion: "Requires sudo and RPCS3 to be running with Warhawk loaded.",
        subcommands: [
            Attach.self,
            Status.self,
            FOVCommand.self,
            ModsCommand.self,
            WeaponsCommand.self,
            UnlockCommand.self,
            TeleportCommand.self,
            NameCommand.self,
            ClanCommand.self,
            BladeCommand.self,
            ScoreCommand.self,
            Interactive.self,
        ]
    )
}

// MARK: - Attach

struct Attach: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Connect to RPCS3 and verify memory access"
    )

    func run() throws {
        print("Searching for RPCS3 process...")
        let bridge = try RPCS3Bridge.connect()
        print("Connected to RPCS3 (PID: \(bridge.pid))")
        print("Base address: 0x\(String(bridge.gBaseAddr, radix: 16))")
        print("Sudo mirror:  0x\(String(bridge.gSudoAddr, radix: 16))")

        // Verify we can read game state
        let gameState = try bridge.readUInt32(Addr.gameState)
        print("Game state pointer: 0x\(String(gameState, radix: 16))")

        if gameState == 0 {
            print("Warning: Game state is null. Is Warhawk loaded and in a match?")
        } else {
            print("Game state OK - ready to mod!")
            // Try reading player name
            let name = try? bridge.readString(Addr.playerName)
            if let name = name, !name.isEmpty {
                print("Player: \(name)")
            }
        }
    }
}

// MARK: - Status

struct Status: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show current game state and active mods"
    )

    func run() throws {
        let bridge = try RPCS3Bridge.connect()
        let ptrs = Pointers(bridge: bridge)
        let fov = FOV(bridge: bridge, pointers: ptrs)

        print("=== Warhawk Status ===")
        print("RPCS3 PID: \(bridge.pid)")
        print("Base: 0x\(String(bridge.gBaseAddr, radix: 16))")

        let gameState = try bridge.readUInt32(Addr.gameState)
        print("\nGame State: 0x\(String(gameState, radix: 16))")

        guard gameState != 0 else {
            print("Game not loaded or not in match")
            return
        }

        // Player name
        if let name = try? bridge.readString(Addr.playerName), !name.isEmpty {
            print("Player: \(name)")
        }

        // On foot or in vehicle
        if let onFoot = try? ptrs.isOnFoot() {
            print("State: \(onFoot ? "On Foot" : "In Vehicle")")
        }

        // FOV
        if let currentFOV = try? fov.getCurrentFOV() {
            print("FOV: \(String(format: "%.1f", currentFOV))")
        }

        // Current weapon
        if let player = try? ptrs.playerPointer(),
           let weaponID = try? bridge.readInt32(try ptrs.resolve(player, Addr.currentWeaponOffset)) {
            let name = weaponNames[UInt8(weaponID)] ?? "Unknown (\(weaponID))"
            print("Weapon: \(name)")
        }
    }
}

// MARK: - FOV

struct FOVCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "fov",
        abstract: "Get or set field of view"
    )

    @Argument(help: "FOV value to set (e.g., 90.0), or 'reset' to restore default")
    var value: String?

    func run() throws {
        let bridge = try RPCS3Bridge.connect()
        let ptrs = Pointers(bridge: bridge)
        let fovMod = FOV(bridge: bridge, pointers: ptrs)

        if let val = value {
            if val == "reset" {
                try fovMod.resetFOV()
                print("FOV reset to default")
            } else if let fovFloat = Float(val) {
                try fovMod.setFOV(fovFloat)
                print("FOV set to \(fovFloat)")

                // Continuous write loop
                print("Holding FOV at \(fovFloat) (Ctrl+C to stop)...")
                let runLoop = true
                signal(SIGINT) { _ in
                    print("\nStopping FOV loop")
                    Darwin.exit(0)
                }
                while runLoop {
                    try? fovMod.fovLoop(value: fovFloat)
                    Thread.sleep(forTimeInterval: 0.01)
                }
            } else {
                print("Invalid FOV value: \(val)")
            }
        } else {
            let current = try fovMod.getCurrentFOV()
            let base = try fovMod.getBaseFOV()
            print("Current FOV: \(String(format: "%.2f", current))")
            print("Base FOV: \(String(format: "%.2f", base))")
        }
    }
}

// MARK: - Mods

struct ModsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mods",
        abstract: "Enable or disable gameplay mods",
        subcommands: [EnableMod.self, DisableMod.self, ListMods.self]
    )
}

struct ListMods: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List available mods"
    )

    func run() {
        print("Available mods:")
        print("  insta-binoc      - Instant binocular zoom")
        print("  extended-range   - Maximum weapon range and render distance")
        print("  radar            - Show all players on radar")
        print("  ground-weapons   - Give all ground weapons with ammo")
        print("  wrench           - Give repair wrench")
        print("  air-weapons      - Give all air vehicle weapons")
        print("  rapid-fire       - Zero fire rate cooldown")
        print("  infinite-air     - Infinite vehicle mods (boost/cooldowns)")
        print("  instant-lock     - Instant missile lock-on (modes: all/air-lock/air-reload/ground)")
    }
}

struct EnableMod: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "enable",
        abstract: "Enable a mod (runs continuously until Ctrl+C)"
    )

    @Argument(help: "Mod name (see 'mods list')")
    var modName: String

    @Option(help: "Instant lock mode: all, air-lock, air-reload, ground")
    var lockMode: String = "all"

    func run() throws {
        let bridge = try RPCS3Bridge.connect()
        let ptrs = Pointers(bridge: bridge)

        print("Enabling \(modName)... (Ctrl+C to stop)")
        signal(SIGINT) { _ in
            print("\nMod disabled")
            Darwin.exit(0)
        }

        switch modName {
        case "insta-binoc":
            let mods = Mods(bridge: bridge, pointers: ptrs)
            while true {
                try? mods.instaBinocLoop()
                Thread.sleep(forTimeInterval: 0.01)
            }

        case "extended-range":
            let mods = Mods(bridge: bridge, pointers: ptrs)
            while true {
                try? mods.extendedRangeLoop()
                Thread.sleep(forTimeInterval: 0.01)
            }

        case "radar":
            let mods = Mods(bridge: bridge, pointers: ptrs)
            while true {
                try? mods.radarLoop()
                Thread.sleep(forTimeInterval: 0.01)
            }

        case "ground-weapons":
            let weapons = Weapons(bridge: bridge, pointers: ptrs)
            while true {
                try? weapons.giveGroundWeaponsLoop(giveWrench: false)
                Thread.sleep(forTimeInterval: 0.01)
            }

        case "wrench":
            let weapons = Weapons(bridge: bridge, pointers: ptrs)
            while true {
                try? weapons.giveWrenchLoop()
                Thread.sleep(forTimeInterval: 0.01)
            }

        case "air-weapons":
            let weapons = Weapons(bridge: bridge, pointers: ptrs)
            while true {
                try? weapons.giveAirWeaponsLoop()
                Thread.sleep(forTimeInterval: 0.01)
            }

        case "rapid-fire":
            let weapons = Weapons(bridge: bridge, pointers: ptrs)
            try weapons.setRapidFire(enabled: true)
            print("Rapid fire enabled (fire rates zeroed)")
            while true {
                try? weapons.rapidWeaponsLoop()
                Thread.sleep(forTimeInterval: 0.01)
            }

        case "infinite-air":
            let airMods = AirMods(bridge: bridge, pointers: ptrs)
            while true {
                try? airMods.infiniteAirModsLoop()
                Thread.sleep(forTimeInterval: 0.01)
            }

        case "instant-lock":
            let mode: AirMods.LockMode
            switch lockMode {
            case "all": mode = .all
            case "air-lock": mode = .airLock
            case "air-reload": mode = .airReload
            case "ground": mode = .ground
            default:
                print("Unknown lock mode: \(lockMode). Use: all, air-lock, air-reload, ground")
                return
            }
            let airMods = AirMods(bridge: bridge, pointers: ptrs)
            print("Lock mode: \(mode.label)")
            while true {
                try? airMods.instantLockLoop(mode: mode)
                Thread.sleep(forTimeInterval: 0.01)
            }

        default:
            print("Unknown mod: \(modName). Use 'mods list' to see available mods.")
        }
    }
}

struct DisableMod: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "disable",
        abstract: "Disable a mod (restore defaults)"
    )

    @Argument(help: "Mod name")
    var modName: String

    func run() throws {
        let bridge = try RPCS3Bridge.connect()
        let ptrs = Pointers(bridge: bridge)

        switch modName {
        case "extended-range":
            let mods = Mods(bridge: bridge, pointers: ptrs)
            try mods.disableExtendedRange()
            print("Extended range disabled")

        case "rapid-fire":
            let weapons = Weapons(bridge: bridge, pointers: ptrs)
            try weapons.setRapidFire(enabled: false)
            print("Rapid fire disabled")

        case "instant-lock":
            let airMods = AirMods(bridge: bridge, pointers: ptrs)
            try airMods.disableInstantLock()
            print("Instant lock disabled")

        default:
            print("Mod '\(modName)' doesn't have a disable action (loop mods stop when you Ctrl+C)")
        }
    }
}

// MARK: - Weapons

struct WeaponsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "weapons",
        abstract: "Give weapons",
        subcommands: [GiveWeapon.self, ListWeapons.self]
    )
}

struct ListWeapons: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List weapon IDs"
    )

    func run() {
        print("Weapon IDs:")
        for (id, name) in weaponNames.sorted(by: { $0.key < $1.key }) {
            print("  \(id): \(name)")
        }
    }
}

struct GiveWeapon: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "give",
        abstract: "Give a weapon to a slot"
    )

    @Argument(help: "Weapon ID (see 'weapons list')")
    var weaponID: UInt8

    @Argument(help: "Weapon slot (0-7)")
    var slot: Int

    func run() throws {
        let bridge = try RPCS3Bridge.connect()
        let ptrs = Pointers(bridge: bridge)
        let weapons = Weapons(bridge: bridge, pointers: ptrs)
        try weapons.giveWeapon(weaponID: weaponID, slot: slot)
        let name = weaponNames[weaponID] ?? "Unknown"
        print("Gave \(name) (ID: \(weaponID)) to slot \(slot)")
    }
}

// MARK: - Unlock

struct UnlockCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "unlock",
        abstract: "Unlock medals, badges, ribbons, or customs"
    )

    @Argument(help: "What to unlock: medals, badges, ribbons, customs, all")
    var target: String

    func run() throws {
        let bridge = try RPCS3Bridge.connect()
        let ptrs = Pointers(bridge: bridge)
        let unlocks = Unlocks(bridge: bridge, pointers: ptrs)

        switch target {
        case "medals":
            try unlocks.unlockMedals()
            print("All 23 medals unlocked")
        case "badges":
            try unlocks.unlockBadges()
            print("All 81 badges unlocked")
        case "ribbons":
            try unlocks.unlockRibbons()
            print("All 30 ribbons unlocked")
        case "customs":
            try unlocks.unlockCustoms()
            print("All custom skins unlocked")
        case "all":
            try unlocks.unlockAll()
            print("Everything unlocked (medals, badges, ribbons, customs)")
        default:
            print("Unknown target: \(target). Use: medals, badges, ribbons, customs, all")
        }
    }
}

// MARK: - Teleport

struct TeleportCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "teleport",
        abstract: "Teleport to flag or coordinates"
    )

    @Option(name: .shortAndLong, help: "X coordinate")
    var x: Float?

    @Option(name: .shortAndLong, help: "Y coordinate")
    var y: Float?

    @Option(name: .shortAndLong, help: "Z coordinate")
    var z: Float?

    func run() throws {
        let bridge = try RPCS3Bridge.connect()
        let ptrs = Pointers(bridge: bridge)
        let teleport = Teleport(bridge: bridge, pointers: ptrs)

        if let x = x, let y = y, let z = z {
            try teleport.teleportTo(x: x, y: y, z: z)
            print("Teleported to (\(x), \(y), \(z))")
        } else {
            try teleport.teleportToFlag()
            print("Teleported to enemy flag")
        }
    }
}

// MARK: - Name/Clan/Blade

struct NameCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "name",
        abstract: "Set player display name"
    )

    @Argument(help: "New player name")
    var name: String

    func run() throws {
        let bridge = try RPCS3Bridge.connect()
        let ptrs = Pointers(bridge: bridge)
        let unlocks = Unlocks(bridge: bridge, pointers: ptrs)
        try unlocks.setPlayerName(name)
        print("Name set to: \(name)")
    }
}

struct ClanCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clan",
        abstract: "Set clan tag"
    )

    @Argument(help: "Clan tag")
    var tag: String

    func run() throws {
        let bridge = try RPCS3Bridge.connect()
        let ptrs = Pointers(bridge: bridge)
        let unlocks = Unlocks(bridge: bridge, pointers: ptrs)
        try unlocks.setClanTag(tag)
        print("Clan tag set to: \(tag)")
    }
}

struct BladeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "blade",
        abstract: "Set blade/knife model"
    )

    @Argument(help: "Blade index (0-based)")
    var index: UInt8

    func run() throws {
        let bridge = try RPCS3Bridge.connect()
        let ptrs = Pointers(bridge: bridge)
        let unlocks = Unlocks(bridge: bridge, pointers: ptrs)
        try unlocks.setBlade(index)
        print("Blade set to index \(index)")
    }
}

struct ScoreCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "score",
        abstract: "Set score values"
    )

    @Option(help: "Team score")
    var team: Int32?

    @Option(help: "Combat score")
    var combat: Int32?

    @Option(help: "Bonus score")
    var bonus: Int32?

    func run() throws {
        let bridge = try RPCS3Bridge.connect()
        let ptrs = Pointers(bridge: bridge)
        let unlocks = Unlocks(bridge: bridge, pointers: ptrs)

        if let team = team {
            try unlocks.setTeamScore(team)
            print("Team score set to \(team)")
        }
        if let combat = combat {
            try unlocks.setCombatScore(combat)
            print("Combat score set to \(combat)")
        }
        if let bonus = bonus {
            try unlocks.setBonusScore(bonus)
            print("Bonus score set to \(bonus)")
        }
        if team == nil && combat == nil && bonus == nil {
            print("Specify at least one: --team, --combat, --bonus")
        }
    }
}
