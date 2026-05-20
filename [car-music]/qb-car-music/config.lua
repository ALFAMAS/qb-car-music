Config = {}

-- Distance (game units) at which full volume (1.0) is heard.
-- Scales linearly: volume 0.5 → range 15.0 (with the default 30.0).
Config.DistanceToVolume = 30.0

-- When false, in-vehicle audio is only heard by occupants of that specific vehicle.
Config.PlayToEveryone = true

-- Set to an item name (e.g. "radio") to require an inventory item to open the stereo.
-- Set to false to use the chat command instead.
Config.ItemInVehicle = false

-- Chat command to open the stereo UI. Only active when ItemInVehicle is false.
Config.CommandVehicle = "music"

-- Optional keyboard shortcut to open the stereo UI. Set to false to disable.
Config.KeyBinding = "F5"

-- Render a map blip at each zone's changemusicblip coordinate so players can find zones.
Config.ZoneBlips = true

-- Admin override command name. Requires the ace permission below.
-- Usage: /musicadmin <zone-name> stop   or   /musicadmin <zone-name> <url>
Config.AdminCommand = "musicadmin"
Config.AdminPermission = "admin"

-- Volume below this threshold is snapped to 0 (mute).
Config.MinVolumeThreshold = 0.005

-- Epsilon for floating-point volume comparisons to avoid micro-updates.
Config.VolumeEpsilon = 0.001

-- World position where out-of-range sounds are relocated to silence them.
Config.OffscreenPosition = vector3(350.0, 0.0, -150.0)

-- Framework bridge: "qb-core", "esx", or "ox_core"
Config.Framework = "qb-core"

-- Persist zone URLs and volumes to oxmysql so they survive server restarts.
-- Requires oxmysql and the car_music_zones table (see README for SQL schema).
Config.EnableDatabase = false

Config.Zones = {
    {
        name            = "Mechanic Zone",
        coords          = vector3(-212.52, -1341.59, 34.89),
        -- job accepts a single string OR a table of job names:
        --   job = "police"
        --   job = {"police", "mechanic"}
        -- Set to nil to allow anyone.
        job             = "police",
        range           = 30.0,
        volume          = 0.1,
        deflink         = "https://www.youtube.com/watch?v=Emap7LU6hYk&t",
        isplaying       = false,
        loop            = false,
        deftime         = 0,
        changemusicblip = vector3(-212.53, -1341.61, 34.89),
    },
    {
        name            = "Vanilla Zone",
        coords          = vector3(105.111, -1303.221, 27.788),
        job             = "police",
        range           = 30.0,
        volume          = 0.1,
        deflink         = "https://www.youtube.com/watch?v=W9iUh23Xrsg",
        isplaying       = false,
        loop            = false,
        deftime         = 0,
        changemusicblip = vector3(-212.53, -1341.61, 34.89),
    },
}
