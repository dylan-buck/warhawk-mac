import Foundation

/// Ground-based mods: insta-binoc, extended range, radar.
struct Mods {
    let bridge: RPCS3Bridge
    let pointers: Pointers

    // MARK: - Insta-Binoc

    /// Set binocular zoom to instant. Call in a loop.
    func instaBinocLoop() throws {
        let player = try pointers.playerPointer()
        try bridge.writeFloat(try pointers.resolve(player, Addr.instaBinoc), value: 1.0)
    }

    // MARK: - Extended Range

    /// Enable extended weapon range. Call in a loop.
    func extendedRangeLoop() throws {
        let player = try pointers.playerPointer()
        try bridge.writeFloat(try pointers.resolve(player, Addr.extRangeRenderDist), value: .greatestFiniteMagnitude)
        try bridge.writeFloat(try pointers.resolve(player, Addr.extRangeViewDist), value: .greatestFiniteMagnitude)
        try bridge.writeFloat(try pointers.resolve(player, Addr.extRangeDmg1), value: 1.0)
        try bridge.writeFloat(try pointers.resolve(player, Addr.extRangeDmg2), value: 1.3)
        try bridge.writeFloat(try pointers.resolve(player, Addr.extRangeDmg3), value: .greatestFiniteMagnitude)
    }

    /// Disable extended range (restore defaults).
    func disableExtendedRange() throws {
        let player = try pointers.playerPointer()
        try bridge.writeFloat(try pointers.resolve(player, Addr.extRangeRenderDist), value: Addr.extRangeDefaultRender)
        try bridge.writeFloat(try pointers.resolve(player, Addr.extRangeViewDist), value: Addr.extRangeDefaultView)
        try bridge.writeFloat(try pointers.resolve(player, Addr.extRangeDmg1), value: Addr.extRangeDefaultDmg1)
        try bridge.writeFloat(try pointers.resolve(player, Addr.extRangeDmg2), value: Addr.extRangeDefaultDmg2)
        try bridge.writeFloat(try pointers.resolve(player, Addr.extRangeDmg3), value: Addr.extRangeDefaultDmg3)
    }

    // MARK: - Radar

    /// Light up all radar blips. Call in a loop.
    func radarLoop() throws {
        let base = Addr.radarBase
        for i in 0..<32 {
            try bridge.writeFloat(base + UInt32(i * 4), value: 255.0)
        }
    }
}
