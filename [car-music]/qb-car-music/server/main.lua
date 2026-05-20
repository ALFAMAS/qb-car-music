-- Framework bridge ----------------------------------------------------------

local function GetFrameworkCore()
    if Config.Framework == "esx" then
        return exports["es_extended"]:getSharedObject()
    elseif Config.Framework == "ox_core" then
        return nil
    end
    return exports["qb-core"]:GetCoreObject()
end

local function GetPlayerJob(playerId)
    if Config.Framework == "esx" then
        local ESX = GetFrameworkCore()
        if not ESX then return nil end
        local xPlayer = ESX.GetPlayerFromId(playerId)
        return xPlayer and xPlayer.getJob() or nil
    elseif Config.Framework == "ox_core" then
        local player = exports.ox_core:GetPlayer(playerId)
        return player and player.metadata and player.metadata.job or nil
    end
    local QBCore = GetFrameworkCore()
    if not QBCore then return nil end
    local player = QBCore.Functions.GetPlayer(playerId)
    return player and player.PlayerData.job or nil
end

-- URL validation (basic pattern check) --------------------------------------

local function isValidUrl(url)
    if type(url) ~= "string" or #url == 0 or #url > 2000 then return false end
    return url:match("^https?://[%S]+$") ~= nil
end

-- Rate limiting: per-source, per-action cooldown (ms) -----------------------

local rateLimits  = {}
local RATE_LIMIT  = 500  -- ms between allowed events from the same source

local function IsRateLimited(source, action)
    local key = tostring(source) .. ":" .. action
    local now = GetGameTimer()
    if rateLimits[key] and (now - rateLimits[key]) < RATE_LIMIT then
        return true
    end
    rateLimits[key] = now
    return false
end

-- Auth check: verify the player is actually inside the claimed vehicle -------

local function PlayerIsInVehicle(playerId, vehicleNetId)
    if not vehicleNetId then return true end
    local ped = GetPlayerPed(playerId)
    if not DoesEntityExist(ped) then return false end
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not DoesEntityExist(vehicle) then return false end
    return GetVehiclePedIsIn(ped, false) == vehicle
end

-- Per-zone job whitelist check (mirrors client helper) ----------------------

local function PlayerCanAccessZone(playerId, zone)
    if zone.job == nil then return true end
    local job = GetPlayerJob(playerId)
    if not job then return false end
    local name = (type(job) == "table" and (job.name or job)) or job
    if type(zone.job) == "table" then
        for _, j in ipairs(zone.job) do
            if name == j then return true end
        end
        return false
    end
    return name == zone.job
end

-- Database persistence (oxmysql, optional) ----------------------------------

local function DbSaveZone(zone)
    if not Config.EnableDatabase then return end
    exports.oxmysql:execute(
        "INSERT INTO car_music_zones (name, deflink, volume, loop) VALUES (?, ?, ?, ?) "
        .. "ON DUPLICATE KEY UPDATE deflink=VALUES(deflink), volume=VALUES(volume), loop=VALUES(loop)",
        { zone.name, zone.deflink or "", zone.volume, zone.loop and 1 or 0 }
    )
end

if Config.EnableDatabase then
    CreateThread(function()
        Wait(1000)  -- give oxmysql time to connect
        exports.oxmysql:execute("CREATE TABLE IF NOT EXISTS car_music_zones ("
            .. "name VARCHAR(255) PRIMARY KEY, "
            .. "deflink TEXT, "
            .. "volume FLOAT DEFAULT 0.1, "
            .. "loop TINYINT(1) DEFAULT 0"
            .. ")", {})
        exports.oxmysql:query("SELECT * FROM car_music_zones", {}, function(rows)
            if not rows then return end
            for _, row in ipairs(rows) do
                for _, zone in ipairs(Config.Zones) do
                    if zone.name == row.name then
                        if row.deflink ~= "" then zone.deflink = row.deflink end
                        zone.volume = row.volume
                        zone.loop   = row.loop == 1
                    end
                end
            end
        end)
    end)
end

-- Playlist queues: name → {url, url, ...} -----------------------------------

local Queues = {}

-- Server-side time tracking --------------------------------------------------

local function countTime()
    SetTimeout(1000, countTime)
    for i = 1, #Config.Zones do
        local v = Config.Zones[i]
        if v.isplaying then
            v.deftime = v.deftime + 1
        end
    end
end

SetTimeout(1000, countTime)

-- Item usage (if ItemInVehicle is set) ---------------------------------------

local QBCoreForItem = Config.Framework == "qb-core" and GetFrameworkCore() or nil
if QBCoreForItem and Config.ItemInVehicle then
    QBCoreForItem.Functions.CreateUseableItem(Config.ItemInVehicle, function(playerId)
        TriggerClientEvent("qb-car-music:ShowNui", playerId)
    end)
end

local xSound = exports.xsound

-- Net event: ChangeVolume ----------------------------------------------------

RegisterNetEvent("qb-car-music:ChangeVolume")
AddEventHandler("qb-car-music:ChangeVolume", function(vol, name)
    local src = source
    if IsRateLimited(src, "ChangeVolume") then return end

    local newVolume, newRange
    for i = 1, #Config.Zones do
        local v = Config.Zones[i]
        if name == v.name then
            local vadi = v.volume + vol
            if vadi <= 1.01 and vadi >= -Config.VolumeEpsilon then
                if vadi < Config.MinVolumeThreshold then vadi = 0.0 end
                if v.vehicleNetId then
                    v.range = vadi * Config.DistanceToVolume
                else
                    if vadi >= 0.05 then
                        v.range = (vadi * v.range) / v.volume
                    end
                end
                v.volume = vadi
                newVolume = v.volume
                newRange  = v.range
                DbSaveZone(v)
            end
        end
    end
    if newVolume and newRange then
        TriggerClientEvent("qb-car-music:ChangeVolume", -1, newVolume, newRange, name)
    end
end)

-- Net event: ChangeLoop ------------------------------------------------------

RegisterNetEvent("qb-car-music:ChangeLoop")
AddEventHandler("qb-car-music:ChangeLoop", function(name, state)
    local src = source
    if IsRateLimited(src, "ChangeLoop") then return end

    local loopState
    for i = 1, #Config.Zones do
        local v = Config.Zones[i]
        if name == v.name then
            v.loop    = state
            loopState = v.loop
            DbSaveZone(v)
        end
    end
    if loopState ~= nil then
        TriggerClientEvent("qb-car-music:ChangeLoop", -1, loopState, name)
    end
end)

-- Net event: ChangeState -----------------------------------------------------

RegisterNetEvent("qb-car-music:ChangeState")
AddEventHandler("qb-car-music:ChangeState", function(state, name)
    local src = source
    if IsRateLimited(src, "ChangeState") then return end

    for i = 1, #Config.Zones do
        if name == Config.Zones[i].name then
            Config.Zones[i].isplaying = state
        end
    end
    TriggerClientEvent("qb-car-music:ChangeState", -1, state, name)
end)

-- Net event: ChangePosition --------------------------------------------------

RegisterNetEvent("qb-car-music:ChangePosition")
AddEventHandler("qb-car-music:ChangePosition", function(delta, name)
    local src = source
    if IsRateLimited(src, "ChangePosition") then return end

    for i = 1, #Config.Zones do
        local v = Config.Zones[i]
        if name == v.name then
            v.deftime = math.max(0, v.deftime + delta)
        end
    end
    TriggerClientEvent("qb-car-music:ChangePosition", -1, delta, name)
end)

-- Net event: ModifyURL -------------------------------------------------------

RegisterNetEvent("qb-car-music:ModifyURL")
AddEventHandler("qb-car-music:ModifyURL", function(data)
    local src = source
    if IsRateLimited(src, "ModifyURL") then return end
    if not isValidUrl(data.link) then return end

    local matchedZone
    for i = 1, #Config.Zones do
        local v = Config.Zones[i]
        if data.name == v.name then
            -- Auth: if this zone is a vehicle zone, caller must be in that vehicle
            if v.vehicleNetId and not PlayerIsInVehicle(src, v.vehicleNetId) then return end
            v.deflink    = data.link
            if data.vehicleNetId then v.vehicleNetId = data.vehicleNetId end
            v.deftime    = 0
            v.isplaying  = true
            v.loop       = data.loop
            matchedZone  = v
            DbSaveZone(v)
        end
    end
    if matchedZone then
        TriggerClientEvent("qb-car-music:ModifyURL", -1, matchedZone)
    end
end)

-- Net event: AddVehicle ------------------------------------------------------

RegisterNetEvent("qb-car-music:AddVehicle")
AddEventHandler("qb-car-music:AddVehicle", function(vehdata)
    local src = source
    if IsRateLimited(src, "AddVehicle") then return end
    if not isValidUrl(vehdata.link) then return end
    if not PlayerIsInVehicle(src, vehdata.vehicleNetId) then return end

    local data = {
        name         = vehdata.plate,
        coords       = vehdata.coords,
        range        = vehdata.volume * Config.DistanceToVolume,
        volume       = vehdata.volume,
        deflink      = vehdata.link,
        isplaying    = true,
        loop         = vehdata.loop,
        deftime      = 0,
        vehicleNetId = vehdata.vehicleNetId,
    }
    table.insert(Config.Zones, data)
    TriggerClientEvent("qb-car-music:AddVehicle", -1, Config.Zones[#Config.Zones])
end)

-- Net event: GetDate (initial state sync) ------------------------------------

RegisterNetEvent("qb-car-music:GetDate")
AddEventHandler("qb-car-music:GetDate", function()
    TriggerClientEvent("qb-car-music:SendData", -1, Config.Zones)
end)

-- Net event: PlayNext (playlist queue advance) --------------------------------

RegisterNetEvent("qb-car-music:PlayNext")
AddEventHandler("qb-car-music:PlayNext", function(name)
    local src = source
    if IsRateLimited(src, "PlayNext") then return end

    if not Queues[name] or #Queues[name] == 0 then return end

    local nextUrl = table.remove(Queues[name], 1)
    for i = 1, #Config.Zones do
        local v = Config.Zones[i]
        if v.name == name then
            v.deflink   = nextUrl
            v.deftime   = 0
            v.isplaying = true
            TriggerClientEvent("qb-car-music:ModifyURL", -1, v)
            break
        end
    end
    TriggerClientEvent("qb-car-music:UpdateQueue", -1, name, Queues[name])
end)

-- Net event: AddToQueue (enqueue a URL) --------------------------------------

RegisterNetEvent("qb-car-music:AddToQueue")
AddEventHandler("qb-car-music:AddToQueue", function(name, url)
    local src = source
    if IsRateLimited(src, "AddToQueue") then return end
    if not isValidUrl(url) then return end

    if not Queues[name] then Queues[name] = {} end
    if #Queues[name] < 20 then  -- cap queue length
        table.insert(Queues[name], url)
        TriggerClientEvent("qb-car-music:UpdateQueue", -1, name, Queues[name])
    end
end)

-- Admin override command -----------------------------------------------------

RegisterCommand(Config.AdminCommand, function(src, args)
    if src > 0 and not IsPlayerAceAllowed(tostring(src), Config.AdminPermission) then
        TriggerClientEvent("chat:addMessage", src, {
            color = {255, 0, 0}, multiline = true,
            args  = {"System", "You do not have permission to use this command."},
        })
        return
    end
    local zoneName = args[1]
    local action   = args[2]
    if not zoneName or not action then
        if src == 0 then print("[qb-car-music] Usage: " .. Config.AdminCommand .. " <zone-name> stop|<url>") end
        return
    end
    for _, zone in ipairs(Config.Zones) do
        if zone.name == zoneName then
            if action == "stop" then
                zone.isplaying = false
                TriggerClientEvent("qb-car-music:ChangeState", -1, false, zoneName)
            else
                if not isValidUrl(action) then
                    if src == 0 then print("[qb-car-music] Invalid URL.") end
                    return
                end
                zone.deflink   = action
                zone.deftime   = 0
                zone.isplaying = true
                TriggerClientEvent("qb-car-music:ModifyURL", -1, zone)
                DbSaveZone(zone)
            end
            return
        end
    end
    if src == 0 then print("[qb-car-music] Zone '" .. zoneName .. "' not found.") end
end, true)
