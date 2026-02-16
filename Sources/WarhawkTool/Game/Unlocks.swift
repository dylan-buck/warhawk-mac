import Foundation

/// One-shot unlock operations: medals, badges, ribbons, customs.
struct Unlocks {
    let bridge: RPCS3Bridge
    let pointers: Pointers

    /// Unlock all 23 medals.
    func unlockMedals() throws {
        let value = [UInt8](repeating: 1, count: 23)
        try bridge.writeBytes(Addr.medals, value: value)
    }

    /// Unlock all 81 badges.
    func unlockBadges() throws {
        let value = [UInt8](repeating: 1, count: 81)
        try bridge.writeBytes(Addr.badges, value: value)
    }

    /// Unlock all 30 ribbons.
    func unlockRibbons() throws {
        let value = [UInt8](repeating: 1, count: 30)
        try bridge.writeBytes(Addr.ribbons, value: value)
    }

    /// Unlock all custom character skins.
    func unlockCustoms() throws {
        try enableCustomsUI()

        let pointer = try pointers.resolve(Addr.customsPtrBase, Addr.customsOffset)
        // Head counts: blue=13, red=13
        try bridge.writeInt32(pointer, value: 13)
        try bridge.writeInt32(pointer + 4, value: 13)
        // Upper counts: blue=14, red=14
        try bridge.writeInt32(pointer + 8, value: 14)
        try bridge.writeInt32(pointer + 12, value: 14)
        // Lower counts: blue=10, red=10
        try bridge.writeInt32(pointer + 16, value: 10)
        try bridge.writeInt32(pointer + 20, value: 10)

        // Unlock all skin items (28 bytes of 1s)
        let dataPointer = try pointers.resolve(Addr.customsUIPtrBase, Addr.customsDataOffset)
        let unlockData = [UInt8](repeating: 1, count: 28)
        try bridge.writeBytes(dataPointer, value: unlockData)
    }

    /// Enable customs UI components.
    private func enableCustomsUI() throws {
        let pointer = try pointers.resolve(Addr.customsUIPtrBase, Addr.customsUIOffset)

        // Enable all body part sections
        try bridge.writeUInt32(pointer, value: Addr.customsEnableValue)          // head enable
        try bridge.writeUInt32(pointer + 700, value: Addr.customsEnableValue)    // upper enable
        try bridge.writeUInt32(pointer + 1404, value: Addr.customsEnableValue)   // lower enable

        // Left buttons
        try bridge.writeUInt32(pointer + 552, value: Addr.customsButtonValue)    // head left
        try bridge.writeUInt32(pointer + 1256, value: Addr.customsButtonValue)   // upper left
        try bridge.writeUInt32(pointer + 1960, value: Addr.customsButtonValue)   // lower left

        // Highlights
        try bridge.writeUInt32(pointer + 596, value: Addr.customsButtonValue)    // head highlight
        try bridge.writeUInt32(pointer + 1300, value: Addr.customsButtonValue)   // upper highlight
        try bridge.writeUInt32(pointer + 2004, value: Addr.customsButtonValue)   // lower highlight

        // Right buttons
        try bridge.writeUInt32(pointer + 640, value: Addr.customsButtonValue)    // head right
        try bridge.writeUInt32(pointer + 1344, value: Addr.customsButtonValue)   // upper right
        try bridge.writeUInt32(pointer + 2048, value: Addr.customsButtonValue)   // lower right
    }

    /// Unlock everything.
    func unlockAll() throws {
        try unlockMedals()
        try unlockBadges()
        try unlockRibbons()
        try unlockCustoms()
    }

    // MARK: - Score

    /// Set team score.
    func setTeamScore(_ value: Int32) throws {
        try bridge.writeInt32(Addr.teamScore, value: value)
        try recalculateTotal()
    }

    /// Set combat score.
    func setCombatScore(_ value: Int32) throws {
        try bridge.writeInt32(Addr.combatScore, value: value)
        try recalculateTotal()
    }

    /// Set bonus score.
    func setBonusScore(_ value: Int32) throws {
        try bridge.writeInt32(Addr.bonusScore, value: value)
        try recalculateTotal()
    }

    /// Recalculate total score from components.
    private func recalculateTotal() throws {
        let team = try bridge.readInt32(Addr.teamScore)
        let combat = try bridge.readInt32(Addr.combatScore)
        let bonus = try bridge.readInt32(Addr.bonusScore)
        let subtract = try bridge.readInt32(Addr.scoreSubtract)
        try bridge.writeInt32(Addr.totalScore, value: team + combat + bonus - subtract)
    }

    // MARK: - Name/Clan

    /// Set player display name.
    func setPlayerName(_ name: String) throws {
        try bridge.writeString(Addr.playerName, value: name)
        let namePtr = try pointers.resolve(Addr.gameState, Addr.nameOffset)
        try bridge.writeString(namePtr, value: name)
    }

    /// Set clan tag.
    func setClanTag(_ clan: String) throws {
        try bridge.writeString(Addr.clanName, value: clan)
    }

    /// Set blade/knife model (0-based index).
    func setBlade(_ index: UInt8) throws {
        try bridge.writeByte(Addr.bladeAddress, value: index)
        let addr1 = try pointers.resolve(Addr.gameState, Addr.bladeSelectOffset)
        try bridge.writeByte(addr1, value: index)
        let player = try pointers.playerPointer()
        let addr2 = try pointers.resolve(player, Addr.bladeSelectAlt)
        try bridge.writeByte(addr2, value: index)
    }
}
