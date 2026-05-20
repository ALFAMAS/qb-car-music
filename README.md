# qb-car-music

A QBCore FiveM resource that brings a fully interactive in-car stereo and location-based radio zone system to your server. Players can stream any YouTube/URL audio directly from their vehicle or from configured world-space zones, with real-time sync across all clients.

[![Preview](https://img.shields.io/badge/Preview-YouTube-red?logo=youtube)](https://youtu.be/0efPWbqq8Go)
[![Discord](https://img.shields.io/badge/Support-Discord-5865F2?logo=discord)](https://discord.gg/jSDMuNjpuw)
[![Version](https://img.shields.io/badge/Version-1.3.0-blue)]()
[![Framework](https://img.shields.io/badge/Framework-QBCore-orange)]()

---

## Table of Contents

- [Features](#features)
- [Dependencies](#dependencies)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [File Structure](#file-structure)
- [TODO / Roadmap](#todo--roadmap)
- [Credits](#credits)
- [License](#license)

---

## Features

- **In-vehicle stereo** — play any streamable URL (YouTube, direct audio, etc.) from inside any vehicle, identified by license plate
- **World-space radio zones** — configure named locations where music plays positionally; only players in range hear it
- **Job-restricted zones** — lock zone music control to specific QBCore jobs
- **Real-time client sync** — all volume, loop, state, position, and URL changes are broadcast to every connected client instantly
- **Proximity audio** — dynamic 3-D positional audio via xsound; volume scales with distance from the source vehicle/zone
- **Passenger-only mode** — optionally restrict audio to only occupants of the playing vehicle (`Config.PlayToEveryone = false`)
- **Loop toggle** — per-source looping, persisted on the server and synced to late-joining clients
- **Seek controls** — skip forward/back 10 seconds; server-side timestamp tracking keeps everyone in sync
- **Volume controls** — smooth ±5% steps; range scales proportionally with volume
- **NUI stereo UI** — retro car-radio overlay with clock, marquee track name, time progress bar, and all playback controls
- **Item or command** — expose the radio UI via a QBCore inventory item or a chat command (configurable)
- **Auto-resume on join** — new clients receive the current server state and begin playback at the correct timestamp

---

## Dependencies

| Dependency | Required | Notes |
|---|---|---|
| [qb-core](https://github.com/qbcore-framework/qb-core) | Yes | Core framework |
| [xsound](https://github.com/Xogy/xsound) | Yes | 3-D positional audio engine |

---

## Installation

1. **Download xsound** from [github.com/Xogy/xsound](https://github.com/Xogy/xsound) and place it in your `resources` folder.
2. **Download qb-car-music** and place the `[car-music]` folder (or just `qb-car-music`) in your `resources` folder.
3. **Add the following lines** to your `server.cfg` (or `resources.cfg`), in this order:

```
ensure xsound
ensure qb-car-music
```

4. **Restart your server** or use `refresh` + `start qb-car-music` in the server console.

---

## Configuration

All options live in `[car-music]/qb-car-music/config.lua`.

### Global Options

| Option | Type | Default | Description |
|---|---|---|---|
| `Config.DistanceToVolume` | `float` | `30.0` | The distance (in game units) at which full volume is heard. Scales linearly — a volume of `0.5` produces a range of `15.0` |
| `Config.PlayToEveryone` | `bool` | `true` | When `false`, in-vehicle audio is only heard by passengers of that specific vehicle |
| `Config.ItemInVehicle` | `string\|false` | `false` | Set to an item name string (e.g. `"radio"`) to require players to use an inventory item to open the stereo. Set to `false` to use the chat command instead |
| `Config.CommandVehicle` | `string` | `"music"` | The chat command that opens the stereo UI. Only active when `Config.ItemInVehicle` is `false` |

### Zone Configuration

Each entry in `Config.Zones` defines a static world-space radio zone:

```lua
Config.Zones = {
    {
        name            = "My Zone",          -- Unique identifier for this zone
        coords          = vector3(x, y, z),   -- World position of the audio source
        job             = "police",           -- QBCore job name allowed to change music; nil = anyone
        range           = 30.0,              -- Max audible radius (game units)
        volume          = 0.1,               -- Default volume (0.0 – 1.0)
        deflink         = "https://...",     -- Default stream URL; nil = silent on start
        isplaying       = false,             -- Start playing when the server starts
        loop            = false,             -- Loop the track when it ends
        deftime         = 0,                 -- Starting timestamp in seconds
        changemusicblip = vector3(x, y, z),  -- Interact point where players can change the music
    },
}
```

> **Tip:** `changemusicblip` can be identical to `coords`. The player must stand within 3 game units of this point and press **E** to open the stereo UI for that zone.

---

## Usage

### In-Vehicle Stereo

1. Enter any vehicle.
2. Open the stereo UI:
   - **Command mode:** type `/music` in chat (or your configured command)
   - **Item mode:** use the configured inventory item
3. Paste a stream URL into the input field and press **PLAY**.
4. Use the on-screen controls to pause, resume, seek, adjust volume, or toggle loop.
5. Press **ESC** or click the close button to dismiss the UI.

### World-Space Zones

- Walk within 3 units of a `changemusicblip` coordinate for an authorized zone.
- A `[E] - Change Music` prompt appears above the blip.
- Press **E** to open the stereo UI for that zone.
- Changes apply to all players within range immediately.

### Controls Summary

| Control | Action |
|---|---|
| **PLAY** button | Resume paused audio |
| **PAUSE** button | Pause audio |
| **LOOP** button | Toggle looping |
| **⏮ / ⏭** buttons | Seek −10 / +10 seconds |
| **VOL+ / VOL−** buttons | Adjust volume ±5% |
| **ESC** | Close the stereo UI |

---

## File Structure

```
[car-music]/
└── qb-car-music/
    ├── config.lua          # All server-side and shared configuration
    ├── fxmanifest.lua      # Resource manifest (version 1.3.0)
    ├── client/
    │   └── main.lua        # NUI callbacks, xsound playback, zone proximity loop, music sync events
    ├── server/
    │   └── main.lua        # Authoritative state, event routing, timestamp tracking
    └── html/
        ├── index.html      # NUI stereo overlay
        ├── main.css        # Stereo UI styles
        ├── script.js       # NUI event handlers, time display, track name resolution
        ├── radio.png       # Background image
        ├── play.svg
        ├── pause.svg
        ├── loop.svg
        ├── forward.svg
        └── back.svg
```

---

## TODO / Roadmap

The following improvements are planned or recommended to optimize and harden the script:

### Performance
- [ ] **Debounce the music-loop thread** — `StartMusicLoop` currently spins a dedicated coroutine per active sound; replace with a single shared scheduler thread to reduce CPU overhead
- [ ] **Cache `PlayerPedId()` and `GetEntityCoords()` results** — the shared polling thread already does this for `coordsped` and `pploop`, but several event handlers still call these natives inline; consolidate to one place
- [ ] **Increase sleep when far from any zone** — the zone-proximity loop drops to 500 ms at 10 units and 5 ms at 3 units; add a third tier (e.g. 5000 ms) for distances over 100 units to spare cycles on large maps
- [ ] **Remove the `countTime` dual-tracking** — both client and server independently approximate playback time via `SetTimeout`; the client-side counter drifts and only exists to support UI polling. Rely solely on `xSound:getTimeStamp()` and remove the client `countTime` function
- [ ] **Lazy-load the zone proximity thread** — delay starting the proximity loop until `myjob` is known and at least one matching zone exists

### Code Quality
- [ ] **Rename Portuguese variables** — `nomidaberto`, `nuiaberto`, `avancartodos`, `esperar`, `encontrad`, `carroe`, `crds`, `iss`, `zena`, `popo` should be given descriptive English names for maintainability
- [ ] **Remove redundant `_source = source` in NUICallback** — `source` is always `nil` in NUI callbacks; this line is misleading
- [ ] **Validate URLs server-side** — the `qb-car-music:AddVehicle` and `qb-car-music:ModifyURL` events accept any client-provided URL string with no sanitisation; add a basic pattern check on the server to prevent misuse
- [ ] **Replace magic numbers** — values like `0.005`, `0.001`, `0.1+1`, `350.0`, `0.0`, `-150.0` are scattered across both files; extract them into named `Config` constants
- [ ] **Consolidate duplicate loop logic** — the job-check block and the `job == nil` block in the zone proximity thread share identical distance/draw/input logic; extract to a helper function

### Features
- [ ] **Keyboard shortcut support** — add a configurable key binding (e.g. `F5`) as an alternative to the chat command/item
- [ ] **Volume slider in NUI** — replace discrete +/− buttons with a drag slider for finer control
- [ ] **Playlist / queue support** — allow players to queue multiple URLs; auto-advance on track end
- [ ] **Persistent zone state (database)** — save zone links and volumes to oxmysql/mysql-async so they survive server restarts
- [ ] **Admin override command** — allow configured ace-permission holders to change or stop any zone's music remotely
- [ ] **Zone blips on the map** — optionally render a map blip at each `changemusicblip` coordinate so players can discover zones
- [ ] **Per-zone access whitelist** — extend `job` to accept a table of job names, not just a single string
- [ ] **ESX / ox_core compatibility layer** — abstract the framework bridge so the resource can run on non-QBCore servers with minimal config changes

### Security
- [ ] **Rate-limit net events** — add per-source cooldowns on `qb-car-music:AddVehicle`, `qb-car-music:ChangeVolume`, `qb-car-music:ChangePosition`, and `qb-car-music:ChangeState` to prevent spam/exploitation
- [ ] **Authorisation check on vehicle events** — verify that the triggering player is actually inside the target vehicle before accepting `AddVehicle` or `ModifyURL` events

### UI / UX
- [ ] **Replace `<marquee>` tag** — `<marquee>` is deprecated HTML; implement CSS `animation: marquee` instead
- [ ] **Migrate from jQuery `$.post` to `fetch`** — remove the jQuery CDN dependency to improve load time and avoid reliance on an external CDN in NUI
- [ ] **Add visual feedback when no URL is entered** — the PLAY button currently silently no-ops if the input is empty; show a brief validation message
- [ ] **Responsive scaling** — the fixed-pixel layout breaks on non-standard resolutions; convert to viewport-relative units

---

## Credits

- **xsound** by [Xogy](https://github.com/Xogy/xsound) — 3-D positional audio engine powering all playback

---

## License

Reselling or redistributing this script, in whole or in part, is **strictly forbidden**. Legal action will be pursued against any party found reselling this resource.

For support, questions, or bug reports join the [Discord server](https://discord.gg/jSDMuNjpuw).
