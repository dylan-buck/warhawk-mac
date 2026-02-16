import ArgumentParser
import Foundation

/// Interactive REPL mode for toggling mods in real-time.
struct Interactive: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "interactive",
        abstract: "Interactive mode for toggling mods in real-time"
    )

    func run() throws {
        let bridge = try RPCS3Bridge.connect()
        let ptrs = Pointers(bridge: bridge)
        let mods = Mods(bridge: bridge, pointers: ptrs)
        let weapons = Weapons(bridge: bridge, pointers: ptrs)
        let airMods = AirMods(bridge: bridge, pointers: ptrs)
        let fovMod = FOV(bridge: bridge, pointers: ptrs)
        let unlocks = Unlocks(bridge: bridge, pointers: ptrs)
        let teleport = Teleport(bridge: bridge, pointers: ptrs)

        print("=== Warhawk Interactive Mode ===")
        print("Connected to RPCS3 (PID: \(bridge.pid))")
        print("Type 'help' for commands, 'quit' to exit\n")

        // Track active mod loops
        var activeLoops: [String: Bool] = [:]

        func startLoop(name: String, action: @escaping () throws -> Void) {
            if activeLoops[name] == true {
                print("\(name) is already running")
                return
            }
            activeLoops[name] = true
            Thread.detachNewThread {
                while activeLoops[name] == true {
                    try? action()
                    Thread.sleep(forTimeInterval: 0.01)
                }
            }
            print("\(name) enabled")
        }

        func stopLoop(name: String) {
            if activeLoops[name] == true {
                activeLoops[name] = false
                print("\(name) disabled")
            } else {
                print("\(name) is not running")
            }
        }

        while true {
            print("> ", terminator: "")
            guard let line = readLine()?.trimmingCharacters(in: .whitespaces) else {
                break
            }
            let parts = line.split(separator: " ").map(String.init)
            guard let command = parts.first else { continue }

            do {
                switch command {
                case "help":
                    printHelp()

                case "status":
                    let gameState = try bridge.readUInt32(Addr.gameState)
                    print("Game state: 0x\(String(gameState, radix: 16))")
                    if let name = try? bridge.readString(Addr.playerName), !name.isEmpty {
                        print("Player: \(name)")
                    }
                    if let onFoot = try? ptrs.isOnFoot() {
                        print("State: \(onFoot ? "On Foot" : "In Vehicle")")
                    }
                    if let f = try? fovMod.getCurrentFOV() {
                        print("FOV: \(String(format: "%.1f", f))")
                    }
                    print("Active mods: \(activeLoops.filter { $0.value }.map { $0.key }.joined(separator: ", "))")

                case "fov":
                    if parts.count > 1 {
                        if parts[1] == "reset" {
                            stopLoop(name: "fov")
                            try fovMod.resetFOV()
                        } else if let val = Float(parts[1]) {
                            startLoop(name: "fov") { try fovMod.fovLoop(value: val) }
                        }
                    } else {
                        let current = try fovMod.getCurrentFOV()
                        print("FOV: \(String(format: "%.2f", current))")
                    }

                case "binoc", "insta-binoc":
                    toggleLoop(name: "insta-binoc", loops: &activeLoops,
                               start: { startLoop(name: "insta-binoc") { try mods.instaBinocLoop() } },
                               stop: { stopLoop(name: "insta-binoc") })

                case "range", "extended-range":
                    if activeLoops["extended-range"] == true {
                        stopLoop(name: "extended-range")
                        try mods.disableExtendedRange()
                    } else {
                        startLoop(name: "extended-range") { try mods.extendedRangeLoop() }
                    }

                case "radar":
                    toggleLoop(name: "radar", loops: &activeLoops,
                               start: { startLoop(name: "radar") { try mods.radarLoop() } },
                               stop: { stopLoop(name: "radar") })

                case "gw", "ground-weapons":
                    toggleLoop(name: "ground-weapons", loops: &activeLoops,
                               start: { startLoop(name: "ground-weapons") { try weapons.giveGroundWeaponsLoop(giveWrench: activeLoops["wrench"] == true) } },
                               stop: { stopLoop(name: "ground-weapons") })

                case "wrench":
                    toggleLoop(name: "wrench", loops: &activeLoops,
                               start: { startLoop(name: "wrench") { try weapons.giveWrenchLoop() } },
                               stop: { stopLoop(name: "wrench") })

                case "aw", "air-weapons":
                    toggleLoop(name: "air-weapons", loops: &activeLoops,
                               start: { startLoop(name: "air-weapons") { try weapons.giveAirWeaponsLoop() } },
                               stop: { stopLoop(name: "air-weapons") })

                case "rapid", "rapid-fire":
                    if activeLoops["rapid-fire"] == true {
                        stopLoop(name: "rapid-fire")
                        try weapons.setRapidFire(enabled: false)
                    } else {
                        try weapons.setRapidFire(enabled: true)
                        startLoop(name: "rapid-fire") { try weapons.rapidWeaponsLoop() }
                    }

                case "air", "infinite-air":
                    toggleLoop(name: "infinite-air", loops: &activeLoops,
                               start: { startLoop(name: "infinite-air") { try airMods.infiniteAirModsLoop() } },
                               stop: { stopLoop(name: "infinite-air") })

                case "lock", "instant-lock":
                    let mode: AirMods.LockMode
                    if parts.count > 1 {
                        switch parts[1] {
                        case "all": mode = .all
                        case "air-lock": mode = .airLock
                        case "air-reload": mode = .airReload
                        case "ground": mode = .ground
                        case "off":
                            stopLoop(name: "instant-lock")
                            try airMods.disableInstantLock()
                            continue
                        default:
                            print("Modes: all, air-lock, air-reload, ground, off")
                            continue
                        }
                    } else {
                        mode = .all
                    }
                    if activeLoops["instant-lock"] == true {
                        stopLoop(name: "instant-lock")
                        try airMods.disableInstantLock()
                    }
                    startLoop(name: "instant-lock") { try airMods.instantLockLoop(mode: mode) }

                case "medals":
                    try unlocks.unlockMedals()
                    print("All medals unlocked")
                case "badges":
                    try unlocks.unlockBadges()
                    print("All badges unlocked")
                case "ribbons":
                    try unlocks.unlockRibbons()
                    print("All ribbons unlocked")
                case "customs":
                    try unlocks.unlockCustoms()
                    print("All customs unlocked")
                case "unlock-all":
                    try unlocks.unlockAll()
                    print("Everything unlocked")

                case "tp", "teleport":
                    if parts.count == 4, let x = Float(parts[1]), let y = Float(parts[2]), let z = Float(parts[3]) {
                        try teleport.teleportTo(x: x, y: y, z: z)
                        print("Teleported to (\(x), \(y), \(z))")
                    } else {
                        try teleport.teleportToFlag()
                        print("Teleported to flag")
                    }

                case "name":
                    if parts.count > 1 {
                        let name = parts.dropFirst().joined(separator: " ")
                        try unlocks.setPlayerName(name)
                        print("Name set to: \(name)")
                    }

                case "clan":
                    if parts.count > 1 {
                        try unlocks.setClanTag(parts[1])
                        print("Clan set to: \(parts[1])")
                    }

                case "alloff":
                    for key in activeLoops.keys {
                        activeLoops[key] = false
                    }
                    try? weapons.setRapidFire(enabled: false)
                    try? airMods.disableInstantLock()
                    try? mods.disableExtendedRange()
                    print("All mods disabled")

                case "quit", "exit", "q":
                    for key in activeLoops.keys {
                        activeLoops[key] = false
                    }
                    print("Bye!")
                    return

                default:
                    print("Unknown command: \(command). Type 'help' for commands.")
                }
            } catch {
                print("Error: \(error)")
            }
        }
    }

    private func toggleLoop(name: String, loops: inout [String: Bool],
                            start: () -> Void, stop: () -> Void) {
        if loops[name] == true {
            stop()
        } else {
            start()
        }
    }

    private func printHelp() {
        print("""
        === Commands ===
        status              Show game state and active mods
        fov [value|reset]   Get/set/reset FOV
        binoc               Toggle insta-binoc
        range               Toggle extended range
        radar               Toggle radar
        gw                  Toggle ground weapons
        wrench              Toggle wrench
        aw                  Toggle air weapons
        rapid               Toggle rapid fire
        air                 Toggle infinite air mods
        lock [mode|off]     Toggle instant lock (all/air-lock/air-reload/ground/off)
        medals              Unlock all medals
        badges              Unlock all badges
        ribbons             Unlock all ribbons
        customs             Unlock all customs
        unlock-all          Unlock everything
        tp [x y z]          Teleport to coords or flag
        name <name>         Set player name
        clan <tag>          Set clan tag
        alloff              Disable all mods
        quit                Exit
        """)
    }
}
