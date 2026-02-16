import Foundation

/// All PS3 memory addresses for Warhawk, extracted from the decompiled Windows tool.
/// These are PS3 virtual addresses (not host addresses).
enum Addr {
    // MARK: - Core Pointers
    /// Main game state pointer (dereference + offset to get player struct)
    static let gameState: UInt32 = 8_970_496       // 0x88F700

    // MARK: - Player Offsets (from dereferenced gameState + 4)
    /// Player struct pointer offset
    static let playerPtrOffset: Int32 = 4
    /// Vehicle/air struct offset from player
    static let vehicleOffset: Int32 = 2004
    /// Position pointer offset (deref again + 64 for xyz)
    static let positionPtrOffset: Int32 = 12
    static let positionXYZOffset: Int32 = 64
    /// Currently held weapon ID
    static let currentWeaponOffset: Int32 = 4084
    /// Equipped weapon slot base
    static let weaponSlotBase: Int32 = 4104
    /// Blade/knife model select
    static let bladeSelectOffset: Int32 = 52
    static let bladeSelectAlt: Int32 = 26688
    /// Player name pointer offset
    static let nameOffset: Int32 = 2108

    // MARK: - Mod Offsets (from player pointer)
    /// Insta-binoc zoom speed
    static let instaBinoc: Int32 = 18920
    /// Extended range: render distance
    static let extRangeRenderDist: Int32 = 16968
    static let extRangeViewDist: Int32 = 16648
    /// Extended range: damage dropoff
    static let extRangeDmg1: Int32 = 17312
    static let extRangeDmg2: Int32 = 17316
    static let extRangeDmg3: Int32 = 17320
    /// Wrench health offset
    static let wrenchHealth: Int32 = 20324
    /// Ground weapon fire indicator
    static let weaponFireIndicator: Int32 = 18052
    /// Instant lock - ground missile
    static let groundMissileLock: Int32 = 17500

    // MARK: - Rapid Fire Offsets (from player pointer) - ground
    static let rapidFire_18388: Int32 = 18388
    static let rapidFire_18580: Int32 = 18580
    static let rapidFire_18300: Int32 = 18300
    static let rapidFire_17116: Int32 = 17116
    static let rapidFire_17488: Int32 = 17488
    static let rapidFire_20900: Int32 = 20900
    static let rapidFire_18860: Int32 = 18860

    // MARK: - Rapid Fire Loop Weapon Byte Offsets (from player pointer)
    static let rapidWeapon2Byte: Int32 = 19888
    static let rapidWeapon5Byte: Int32 = 17463
    static let rapidWeapon7Byte: Int32 = 16834
    static let rapidGroundByte: Int32 = 18295

    // MARK: - Air Offsets (via getAirPointer)
    static let airLockTime: Int = 10190
    static let airReloadTime: Int = 10960
    /// Hawk vehicle type identifier
    static let hawkIdentifier: UInt32 = 3_183_328_701 // 0xBDC4B1BD
    /// Offset in vehicle struct to check hawk type
    static let hawkCheckOffset: Int32 = 10368
    /// Hawk-specific offset addition
    static let hawkOffsetDelta: Int = 6336
    /// Vehicle alive check
    static let vehicleAliveCheck: Int32 = 32

    // MARK: - Air Weapon Slots (via getAirPointer)
    static let airWeaponData: Int32 = 764        // UInt64 write
    static let airWeaponCheck: Int32 = 772       // UInt64 read
    static let airSlot_10368: Int = 10368        // Int16
    static let airSlot_10064: Int = 10064
    static let airSlot_11536: Int = 11536
    static let airSlot_11024: Int = 11024
    static let airSlot_11328: Int = 11328
    static let airSlot_11776: Int = 11776
    static let airSlot_11184: Int = 11184
    static let airSlot_11936: Int = 11936

    // MARK: - Rapid Fire Offsets - Air (via getAirPointer)
    static let airRapid_10232: Int = 10232
    static let airRapid_11662: Int = 11662
    static let airRapid_12046: Int = 12046
    static let airRapid_10946: Int = 10946
    static let airRapid_11132: Int = 11132
    static let airRapid_11464: Int = 11464

    // MARK: - Infinite Air Mod Offsets (from vehicle pointer)
    /// Hawk-specific cooldown
    static let hawkCooldown: Int32 = 16060
    /// Non-hawk cooldown
    static let aircraftCooldown: Int32 = 9724
    /// Non-hawk boost
    static let aircraftBoost: Int32 = 8032
    /// Vehicle general energy
    static let vehicleEnergy: Int32 = 11872

    // MARK: - Direct Addresses (no pointer chain)
    /// Player name string
    static let playerName: UInt32 = 10_021_820     // 0x98FFBC
    /// Clan name
    static let clanName: UInt32 = 9_936_532        // 0x979E94
    /// Blade/knife model address
    static let bladeAddress: UInt32 = 10_873_392   // 0xA5F630
    /// Radar base (32 floats starting here)
    static let radarBase: UInt32 = 11_471_984      // 0xAF1A70
    /// Weapon state indicator
    static let weaponState: UInt32 = 11_592_272    // 0xB0F450
    /// FOV pointer base
    static let fovPtrBase: UInt32 = 11_596_276     // 0xB10374
    static let fovOffset: Int32 = 912

    // MARK: - Unlock/Stats Addresses
    /// Medals (23 bytes)
    static let medals: UInt32 = 11_401_516         // 0xADFD0C
    /// Ribbons (30 bytes)
    static let ribbons: UInt32 = 11_401_544        // 0xADFD28
    /// Badges (81 bytes)
    static let badges: UInt32 = 11_401_578         // 0xADFD4A
    /// Score components
    static let teamScore: UInt32 = 11_401_052      // 0xADFB4C
    static let combatScore: UInt32 = 11_401_048    // 0xADFB48
    static let bonusScore: UInt32 = 11_401_056     // 0xADFB50
    static let scoreSubtract: UInt32 = 11_401_060  // 0xADFB54
    static let totalScore: UInt32 = 11_401_676     // 0xADFDBC

    // MARK: - Customs/Appearance
    static let customsPtrBase: UInt32 = 12_074_500 // 0xB84A04
    static let customsOffset: Int32 = 80
    static let customsUIPtrBase: UInt32 = 8_757_312 // 0x85A440
    static let customsUIOffset: Int32 = 12412
    static let customsDataOffset: Int32 = 3696

    // MARK: - Teleport/Flag Data
    static let flagDataPtr: UInt32 = 11_472_424    // 0xAF1DA8
    static let flagDataPtrOffset: Int32 = 480
    static let teamData1: UInt32 = 11_433_648      // 0xAE8A30
    static let teamData2: UInt32 = 11_433_676      // 0xAE8A4C
    static let flag1X: UInt32 = 12_306_720         // 0xBBB520
    static let flag1Y: UInt32 = 12_306_724
    static let flag1Z: UInt32 = 12_306_728
    static let flag2X: UInt32 = 12_306_688         // 0xBBB500
    static let flag2Y: UInt32 = 12_306_692
    static let flag2Z: UInt32 = 12_306_696
    /// Game mode offset from gameState
    static let gameModeOffset: Int32 = 2264

    // MARK: - Air Weapon Default Restore Values
    static let airLockDefault: Int32 = 95_027_200
    static let airReloadDefault: Int32 = 400

    // MARK: - Rapid Fire Default (disable) Values - Ground
    static let rapidDefault_18388: UInt32 = 1600
    static let rapidDefault_18580: UInt32 = 1750
    static let rapidDefault_18300: UInt32 = 1000
    static let rapidDefault_17116: UInt32 = 1200
    static let rapidDefault_17488: UInt32 = 1800
    static let rapidDefault_20900: UInt32 = 10000
    static let rapidDefault_18860: UInt32 = 30000

    // MARK: - Rapid Fire Default (disable) Values - Air
    static let airRapidDefault_10232: UInt32 = 196_608_000
    static let airRapidDefault_11662: UInt32 = 6000
    static let airRapidDefault_12046: UInt32 = 4000
    static let airRapidDefault_10946: UInt32 = 328_430
    static let airRapidDefault_11132: UInt32 = 1000
    static let airRapidDefault_11464: UInt32 = 5000

    // MARK: - Extended Range Default (disable) Values
    static let extRangeDefaultRender: Float = 200.0
    static let extRangeDefaultView: Float = 75.0
    static let extRangeDefaultDmg1: Float = 0.0
    static let extRangeDefaultDmg2: Float = 0.0
    static let extRangeDefaultDmg3: Float = 1750.0

    // MARK: - Customs UI Magic Values
    static let customsEnableValue: UInt32 = 717_029_376   // 0x2ABE0000
    static let customsButtonValue: UInt32 = 45_940_872     // 0x02BD4488
}

/// Ground weapon definitions: (slot, weaponID, ammoOffset, ammoValue)
let groundWeapons: [(slot: Int, weaponID: UInt8, ammoOffset: Int32, ammoValue: Int32)] = [
    (0, 6, 18612, 3),
    (2, 8, 19588, 14),
    (3, 2, 16868, 280),
    (4, 11, 20660, 2),
    (4, 5, 18340, 4),
    (5, 3, 17220, 6),
    (6, 7, 18996, 120),
    (7, 1, 16552, 20),
]

/// Weapon ID to name mapping (best-effort from context)
let weaponNames: [UInt8: String] = [
    1: "Rifle",
    2: "Sniper",
    3: "Rocket Launcher",
    5: "Grenades",
    6: "Flamethrower",
    7: "Mines",
    8: "Binoculars",
    9: "Knife",
    10: "Wrench",
    11: "TOW Missile",
]
