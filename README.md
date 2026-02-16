# warhawk-mac

A macOS CLI tool for modding [Warhawk](https://en.wikipedia.org/wiki/Warhawk_(2007_video_game)) running on the [RPCS3](https://rpcs3.net/) PS3 emulator. Port of the Windows "Warhawk Blade/Stat/Weapon Tool" to native Swift.

Attaches to the RPCS3 process via Mach VM APIs, discovers the PS3 memory layout from RPCS3's log file, and reads/writes game memory to enable mods.

## Requirements

- macOS 13+ (Apple Silicon or Intel)
- Swift 5.9+
- RPCS3 with Warhawk loaded
- Must run with `sudo` (required for `task_for_pid`)

## Build

```bash
./scripts/build.sh
```

Or manually:

```bash
swift build -c release
codesign -s - --entitlements entitlements.plist --force .build/release/WarhawkTool
```

The binary must be signed with the `com.apple.security.cs.debugger` entitlement for cross-process memory access.

## Usage

Start RPCS3, load Warhawk, and join a game. Then:

```bash
# Verify connection
sudo .build/release/WarhawkTool attach

# Show current game state
sudo .build/release/WarhawkTool status

# Interactive REPL mode (recommended)
sudo .build/release/WarhawkTool interactive
```

### Commands

| Command | Description |
|---------|-------------|
| `attach` | Connect to RPCS3 and verify memory access |
| `status` | Show current game state (player, FOV, weapon) |
| `interactive` | Interactive REPL for toggling mods in real-time |
| `fov <value>` | Set field of view (e.g. `fov 90`), or `fov reset` |
| `mods enable <mod>` | Enable a mod (runs until Ctrl+C) |
| `mods disable <mod>` | Disable a mod (restore defaults) |
| `mods list` | List available mods |
| `weapons list` | List weapon IDs |
| `weapons give <id> <slot>` | Give a weapon to a slot |
| `unlock <target>` | Unlock medals, badges, ribbons, customs, or all |
| `name <name>` | Set player display name |
| `clan <tag>` | Set clan tag |
| `blade <index>` | Set blade/knife model |
| `score --team/--combat/--bonus <value>` | Set score values |
| `teleport` | Teleport to enemy flag |
| `teleport -x <x> -y <y> -z <z>` | Teleport to coordinates |

### Available Mods

| Mod | Description |
|-----|-------------|
| `insta-binoc` | Instant binocular zoom |
| `extended-range` | Maximum weapon range and render distance |
| `radar` | Show all players on radar |
| `ground-weapons` | Give all ground weapons with ammo |
| `wrench` | Give repair wrench |
| `air-weapons` | Give all air vehicle weapons |
| `rapid-fire` | Zero fire rate cooldown |
| `infinite-air` | Infinite vehicle boost and cooldowns |
| `instant-lock` | Instant missile lock-on (modes: `all`, `air-lock`, `air-reload`, `ground`) |

### Interactive Mode

The `interactive` command provides a REPL where you can toggle mods on and off:

```
$ sudo .build/release/WarhawkTool interactive
Connected to RPCS3 (PID: 20589)

warhawk> fov 90
FOV set to 90.0

warhawk> radar on
Radar enabled

warhawk> weapons
All ground weapons given

warhawk> help
...

warhawk> quit
```

## How It Works

1. Finds the RPCS3 process via `sysctl` KERN_PROC
2. Attaches via `task_for_pid` (requires sudo + debugger entitlement)
3. Discovers `g_base_addr` by parsing `~/Library/Caches/rpcs3/RPCS3.log`
4. Translates PS3 addresses to host addresses: `host_addr = g_sudo_addr + ps3_addr`
   - `g_sudo_addr = g_base_addr + 0x100000000` (RPCS3's unprotected memory mirror)
5. Reads/writes game memory with big-endian byte swapping (PS3 is big-endian, macOS is little-endian)

## Project Structure

```
Sources/
├── CMachHelpers/           # C module wrapping Mach VM APIs
│   ├── include/mach_helpers.h
│   └── mach_helpers.c
└── WarhawkTool/
    ├── main.swift
    ├── CLI/
    │   ├── Commands.swift          # All CLI subcommands
    │   └── InteractiveCommand.swift # REPL mode
    ├── Core/
    │   ├── MachMemory.swift        # Typed memory read/write with endian swap
    │   ├── ProcessFinder.swift     # Find RPCS3 by process name
    │   └── RPCS3Bridge.swift       # Process attach + address translation
    └── Game/
        ├── Addresses.swift         # All PS3 memory addresses
        ├── Pointers.swift          # Pointer chain resolution
        ├── FOV.swift               # Field of view
        ├── Weapons.swift           # Ground/air weapons, rapid fire
        ├── Mods.swift              # Insta-binoc, extended range, radar
        ├── AirMods.swift           # Infinite air mods, instant lock-on
        ├── Unlocks.swift           # Medals, badges, ribbons, customs
        └── Teleport.swift          # Flag teleport
```
