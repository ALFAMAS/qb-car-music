# qb-car-music 2.0.0

A QBCore FiveM resource that brings a fully interactive in-car stereo and location-based radio zone system to your server. Players can stream any YouTube/URL audio directly from their vehicle or from configured world-space zones, with real-time sync across all clients.

[![Preview](https://img.shields.io/badge/Preview-YouTube-red?logo=youtube)](https://youtu.be/0efPWbqq8Go)
[![Discord](https://img.shields.io/badge/Support-Discord-5865F2?logo=discord)](https://discord.gg/jSDMuNjpuw)
[![Version](https://img.shields.io/badge/Version-2.0.0-blue)]()
[![Framework](https://img.shields.io/badge/Framework-QBCore%20%7C%20ESX%20%7C%20ox__core-orange)]()

---

## Table of Contents

- [Features](#features)
- [Dependencies](#dependencies)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [File Structure](#file-structure)
- [Database Setup](#database-setup)
- [Changelog](#changelog)
- [Credits](#credits)
- [License](#license)

---

## Features

- **In-vehicle stereo** — play any streamable URL (YouTube, direct audio, etc.) from inside any vehicle, identified by license plate
- **World-space radio zones** — configure named locations where music plays positionally; only players in range hear it
- **Job-restricted zones** — lock zone music control to a single job name or a whitelist of jobs (`job = {"police", "mechanic"}`)
- **Real-time client sync** — all volume, loop, state, position, and URL changes are broadcast to every connected client instantly
- **Proximity audio** — dynamic 3-D positional audio via xsound; volume scales with distance from the source vehicle/zone
- **Passenger-only mode** — optionally restrict audio to only occupants of the playing vehicle (`Config.PlayToEveryone = false`)
- **Loop toggle** — per-source looping, persisted on the server and synced to late-joining clients
- **Seek controls** — skip forward/back 10 seconds; server-side timestamp tracking keeps everyone in sync
- **Volume slider** — smooth drag slider in the NUI (replaces discrete ±5% buttons); also accessible via the on-radio knob overlays
- **NUI stereo UI** — retro car-radio overlay with clock, animated scrolling track name, time progress bar, and all playback controls
- **Item or command** — expose the radio UI via a QBCore inventory item or a chat command (configurable)
- **Keyboard shortcut** — configurable key binding (default `F5`) as an alternative to the chat command
- **Auto-resume on join** — new clients receive the current server state and begin playback at the correct timestamp
- **Playlist / queue** — queue multiple URLs per zone or vehicle; auto-advances to the next track; Shift+Enter to enqueue without playing immediately
- **Admin override command** — ace-permission holders can remotely change or stop any zone's music from chat or server console
- **Map blips** — optional map blips at each zone's interact point so players can discover zones
- **Multi-framework** — built-in bridge for QBCore, ESX, and ox_core; select with `Config.Framework`
- **Persistent zone state** — optional oxmysql integration saves zone URLs and volumes across server restarts (`Config.EnableDatabase = true`)
- **Rate limiting** — server-side per-source cooldowns on all net events to prevent spam and exploitation
- **Auth checks** — server verifies the triggering player is inside the claimed vehicle before accepting vehicle music events
- **URL validation** — server-side pattern check rejects malformed or empty URLs before processing

---

## Dependencies

| Dependency | Required | Notes |
|---|---|---|
| [qb-core](https://github.com/qbcore-framework/qb-core) | Yes (default) | Core framework; swap with ESX or ox_core via `Config.Framework` |
| [xsound](https://github.com/Xogy/xsound) | Yes | 3-D positional audio engine |
| [oxmysql](https://github.com/overextended/oxmysql) | No | Only required when `Config.EnableDatabase = true` |

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

> **Optional:** If you want persistent zone state, follow the [Database Setup](#database-setup) section.

---

## Configuration

All options live in `[car-music]/qb-car-music/config.lua`.

### Global Options

| Option | Type | Default | Description |
|---|---|---|---|
| `Config.DistanceToVolume` | `float` | `30.0` | Distance (game units) at which full volume (1.0) is heard. Scales linearly — volume 0.5 → range 15.0 |
| `Config.PlayToEveryone` | `bool` | `true` | When `false`, in-vehicle audio is only heard by occupants of that specific vehicle |
| `Config.ItemInVehicle` | `string\|false` | `false` | Item name (e.g. `"radio"`) to require for opening the stereo. `false` = use command |
| `Config.CommandVehicle` | `string` | `"music"` | Chat command to open the stereo UI (active when `ItemInVehicle` is `false`) |
| `Config.KeyBinding` | `string\|false` | `"F5"` | Default key binding for the stereo command. `false` = no binding |
| `Config.ZoneBlips` | `bool` | `true` | Render a map blip at each zone's `changemusicblip` coordinate |
| `Config.AdminCommand` | `string` | `"musicadmin"` | Command name for the admin override |
| `Config.AdminPermission` | `string` | `"admin"` | Ace permission node required to use `AdminCommand` |
| `Config.MinVolumeThreshold` | `float` | `0.005` | Volume values below this are snapped to `0.0` (mute) |
| `Config.VolumeEpsilon` | `float` | `0.001` | Floating-point tolerance for volume comparisons |
| `Config.OffscreenPosition` | `vector3` | `vector3(350, 0, -150)` | Position where out-of-range sounds are relocated to silence them |
| `Config.Framework` | `string` | `"qb-core"` | Framework bridge: `"qb-core"`, `"esx"`, or `"ox_core"` |
| `Config.EnableDatabase` | `bool` | `false` | Persist zone state to oxmysql across restarts |

### Zone Configuration

Each entry in `Config.Zones` defines a static world-space radio zone:

```lua
Config.Zones = {
    {
        name            = "My Zone",           -- Unique identifier for this zone
        coords          = vector3(x, y, z),    -- World position of the audio source
        job             = "police",            -- String, table of strings, or nil (open to all)
                                               -- e.g. job = {"police", "mechanic"}
        range           = 30.0,               -- Max audible radius (game units)
        volume          = 0.1,                -- Default volume (0.0 – 1.0)
        deflink         = "https://...",      -- Default stream URL; nil = silent on start
        isplaying       = false,              -- Start playing on server start
        loop            = false,              -- Loop the track on end
        deftime         = 0,                  -- Starting timestamp in seconds
        changemusicblip = vector3(x, y, z),   -- Interact point where players open the UI
    },
}
```

> **Tip:** `changemusicblip` can be identical to `coords`. The player must stand within 3 game units of this point and press **E** to open the zone's stereo UI.

---

## Usage

### In-Vehicle Stereo

1. Enter any vehicle.
2. Open the stereo UI:
   - **Key binding:** press `F5` (or your configured key)
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

### Playlist / Queue

- With the stereo UI open, enter a URL and press **Shift+Enter** to add it to the queue instead of playing immediately.
- The queue is displayed in the UI. Click **PLAY NEXT** to advance to the next queued track.
- The queue is stored server-side and shared across all clients.

### Admin Override

```
/musicadmin <zone-name> stop           -- stop a zone's music
/musicadmin <zone-name> <url>          -- change a zone's music to a URL
```

Requires the `admin` ace permission (or whatever `Config.AdminPermission` is set to). Works from the server console (source 0) with no permission check.

### Controls Summary

| Control | Action |
|---|---|
| **F5** (configurable) | Open / close the stereo UI |
| **PLAY** button | Resume paused audio |
| **PAUSE** button | Pause audio |
| **LOOP** button | Toggle looping |
| **⏮ / ⏭** buttons | Seek −10 / +10 seconds |
| **Volume slider** | Drag to set volume (0 – 100%) |
| **PLAY** (URL field) | Play the entered URL immediately |
| **Shift+Enter** (URL field) | Add URL to the playlist queue |
| **PLAY NEXT** | Advance to the next queued track |
| **ESC** | Close the stereo UI |

---

## File Structure

```
[car-music]/
└── qb-car-music/
    ├── config.lua          # All server-side and shared configuration
    ├── fxmanifest.lua      # Resource manifest (version 2.0.0)
    ├── client/
    │   └── main.lua        # NUI callbacks, xsound playback, zone proximity, music sync events
    ├── server/
    │   └── main.lua        # Authoritative state, event routing, rate limiting, auth checks
    └── html/
        ├── index.html      # NUI stereo overlay (no jQuery)
        ├── main.css        # Stereo UI styles (responsive, CSS marquee animation)
        ├── script.js       # NUI event handlers (fetch API), time display, queue, track name
        ├── radio.png       # Background image
        ├── play.svg
        ├── pause.svg
        ├── loop.svg
        ├── forward.svg
        └── back.svg
```

---

## Database Setup

To persist zone URLs and volumes across server restarts, set `Config.EnableDatabase = true` in `config.lua`. This requires [oxmysql](https://github.com/overextended/oxmysql).

The resource will auto-create the required table on first run. If you prefer to create it manually:

```sql
CREATE TABLE IF NOT EXISTS `car_music_zones` (
  `name`    VARCHAR(255) NOT NULL,
  `deflink` TEXT,
  `volume`  FLOAT        NOT NULL DEFAULT 0.1,
  `loop`    TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (`name`)
);
```

---

## Changelog

### 2.0.0
- **Performance:** Replaced per-sound coroutines with a single shared scheduler per zone (`ScheduleMusicLoop`)
- **Performance:** Removed client-side `countTime` dual-tracking; playback time now relies solely on `xSound:getTimeStamp()`
- **Performance:** Added third-tier sleep (5 000 ms) in zone proximity loop for players > 100 units from any zone
- **Performance:** Zone proximity thread is now lazy-loaded — starts only after job data is available and at least one accessible zone exists
- **Code quality:** All Portuguese variable names renamed to descriptive English equivalents
- **Code quality:** Removed misleading `_source = source` line from NUI callback (always `nil` in NUI context)
- **Code quality:** Extracted magic numbers (`0.005`, `0.001`, `350.0`, `0.0`, `-150.0`) into named `Config` constants
- **Code quality:** Consolidated duplicate zone proximity logic into a single `CheckZoneProximity` helper
- **Code quality:** `job` field on zones now accepts a table of job names for per-zone whitelists
- **Feature:** Keyboard shortcut support via `RegisterKeyMapping` (default `F5`, configurable)
- **Feature:** Volume drag-slider in NUI replaces discrete ±5% buttons
- **Feature:** Playlist / queue system — queue multiple URLs per source, auto-advance, Shift+Enter to enqueue
- **Feature:** Persistent zone state via optional oxmysql integration (`Config.EnableDatabase`)
- **Feature:** Admin override command (`/musicadmin`) for ace-permitted players and the server console
- **Feature:** Map blips at zone interact points (`Config.ZoneBlips`)
- **Feature:** Per-zone `job` whitelist accepts a table of job names, not just a single string
- **Feature:** Multi-framework bridge — `Config.Framework` switches between `"qb-core"`, `"esx"`, and `"ox_core"`
- **Security:** Server-side rate limiting on all net events (500 ms cooldown per source per action)
- **Security:** Server-side auth check verifies triggering player is inside the claimed vehicle before accepting vehicle music events
- **Security:** Server-side URL validation on `AddVehicle`, `ModifyURL`, and queue events
- **UI/UX:** Replaced deprecated `<marquee>` tag with CSS `animation: marquee-scroll`
- **UI/UX:** Removed jQuery CDN dependency; all NUI communication now uses the native `fetch` API
- **UI/UX:** Empty-URL validation message shown for 3 seconds when PLAY is clicked with no URL
- **UI/UX:** Responsive scaling via CSS `--ui-scale` variable set by JavaScript on load and resize

---

## Credits

- **xsound** by [Xogy](https://github.com/Xogy/xsound) — 3-D positional audio engine powering all playback

---

## License

Reselling or redistributing this script, in whole or in part, is **strictly forbidden**. Legal action will be pursued against any party found reselling this resource.

For support, questions, or bug reports join the [Discord server](https://discord.gg/jSDMuNjpuw).
