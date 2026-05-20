-- Framework bridge ----------------------------------------------------------

local function GetFrameworkCore()
    if Config.Framework == "esx" then
        return exports["es_extended"]:getSharedObject()
    elseif Config.Framework == "ox_core" then
        return nil -- ox_core accessed directly via exports
    end
    return exports["qb-core"]:GetCoreObject()
end

local function GetPlayerJob()
    if Config.Framework == "esx" then
        local ESX = GetFrameworkCore()
        return ESX and ESX.GetPlayerData().job or nil
    elseif Config.Framework == "ox_core" then
        local data = exports.ox_core:GetPlayerData()
        return data and data.metadata and data.metadata.job or nil
    end
    local QBCore = GetFrameworkCore()
    return QBCore and QBCore.Functions.GetPlayerData().job or nil
end

local function Notify(msg)
    if Config.Framework == "esx" then
        local ESX = GetFrameworkCore()
        if ESX then ESX.ShowNotification(msg) end
    elseif Config.Framework == "ox_core" then
        lib.notify({ description = msg, type = "error" })
    else
        local QBCore = GetFrameworkCore()
        if QBCore then QBCore.Functions.Notify(msg) end
    end
end

-- State ----------------------------------------------------------------------

xSound = exports.xsound

local Zones         = {}
local soundInfo     = {}
local isNuiOpen     = false
local activeZoneName = nil
local isShown       = false
local myJob         = nil
local SoundsPlaying = {}

-- Per-zone music-loop deduplication guard (replaces per-sound coroutines)
local scheduledLoops = {}

-- Shared native-call cache updated by a single 500 ms polling thread
local cachedPed     = 0
local cachedVehicle = 0
local cachedCoords  = vector3(0, 0, 0)

-- Helpers --------------------------------------------------------------------

local function firstToUpper(str)
    return (str:gsub("^%l", string.upper))
end

local function volumeDisplayPct(vol)
    return math.floor(vol * 100 + 0.9)
end

-- Returns true if the player's current job grants access to the zone.
-- zone.job may be nil (open), a string, or a table of strings.
local function PlayerCanAccessZone(zone)
    if zone.job == nil then return true end
    if not myJob then return false end
    local name = myJob.name or myJob
    if type(zone.job) == "table" then
        for _, j in ipairs(zone.job) do
            if name == j then return true end
        end
        return false
    end
    return name == zone.job
end

-- Shared position-cache thread -----------------------------------------------

Citizen.CreateThread(function()
    while true do
        Wait(500)
        cachedPed     = PlayerPedId()
        cachedVehicle = GetVehiclePedIsIn(cachedPed, false)
        cachedCoords  = GetEntityCoords(cachedPed)
    end
end)

-- Job init and server-state request ------------------------------------------

Citizen.CreateThread(function()
    Wait(500)
    while GetPlayerJob() == nil do Wait(10) end
    myJob = GetPlayerJob()
    TriggerServerEvent("qb-car-music:GetDate")
end)

-- QBCore job update
RegisterNetEvent("QBCore:Client:OnJobUpdate")
AddEventHandler("QBCore:Client:OnJobUpdate", function(job)
    myJob = job
end)

-- ESX job update
if Config.Framework == "esx" then
    RegisterNetEvent("esx:setJob")
    AddEventHandler("esx:setJob", function(job)
        myJob = job
    end)
end

-- ox_core job update
if Config.Framework == "ox_core" then
    RegisterNetEvent("ox_core:setPlayerData")
    AddEventHandler("ox_core:setPlayerData", function(key, value)
        if key == "job" then myJob = value end
    end)
end

-- NUI callback ---------------------------------------------------------------

RegisterNUICallback("action", function(data, cb)
    local nameId = activeZoneName
    if IsPedInAnyVehicle(cachedPed, false) then
        nameId = GetVehicleNumberPlateText(cachedVehicle)
    end

    if data.action == "seturl" then
        if not data.link or data.link == "" then
            SendNUIMessage({ action = "validationError", text = "Please enter a URL." })
            if cb then cb({}) end
            return
        end
        SetUrl(data.link, nameId)

    elseif data.action == "play" then
        if xSound:soundExists(nameId) and xSound:isPaused(nameId) then
            TriggerServerEvent("qb-car-music:ChangeState", true, nameId)
            local waitCount = 0
            while isNuiOpen do
                Wait(1000)
                if xSound:isPlaying(nameId) then
                    SendNUIMessage({
                        action = "TimeVid",
                        total  = xSound:getMaxDuration(nameId),
                        played = xSound:getTimeStamp(nameId),
                    })
                else
                    waitCount = waitCount + 1
                end
                if waitCount >= 5 then break end
            end
        end

    elseif data.action == "pause" then
        if xSound:soundExists(nameId) and xSound:isPlaying(nameId) then
            TriggerServerEvent("qb-car-music:ChangeState", false, nameId)
        end

    elseif data.action == "exit" then
        showStereo()

    elseif data.action == "volumeup" then
        ApplySound(0.05, nameId)

    elseif data.action == "volumedown" then
        ApplySound(-0.05, nameId)

    elseif data.action == "setvol" then
        -- Volume slider: data.value is 0.0 – 1.0
        local target = tonumber(data.value) or 0.0
        local current = (xSound:soundExists(nameId) and xSound:isPlaying(nameId))
            and xSound:getVolume(nameId) or soundInfo.volume or 0.2
        ApplySound(target - current, nameId)

    elseif data.action == "loop" then
        if xSound:soundExists(nameId) then
            soundInfo.loop = not xSound:isLooped(nameId)
            TriggerServerEvent("qb-car-music:ChangeLoop", nameId, soundInfo.loop)
        else
            soundInfo.loop = not soundInfo.loop
        end
        if type(soundInfo.loop) ~= "table" then
            SendNUIMessage({
                action = "changetextl",
                text   = "<b>Looping:</b> " .. firstToUpper(tostring(soundInfo.loop)),
            })
        end

    elseif data.action == "forward" then
        if xSound:soundExists(nameId) then
            TriggerServerEvent("qb-car-music:ChangePosition", 10, nameId)
        end

    elseif data.action == "back" then
        if xSound:soundExists(nameId) then
            TriggerServerEvent("qb-car-music:ChangePosition", -10, nameId)
        end

    elseif data.action == "playNext" then
        TriggerServerEvent("qb-car-music:PlayNext", nameId)

    elseif data.action == "addToQueue" then
        if data.link and data.link ~= "" then
            TriggerServerEvent("qb-car-music:AddToQueue", nameId, data.link)
        end
    end

    if cb then cb({}) end
end)

-- Volume helper --------------------------------------------------------------

function ApplySound(delta, plate)
    local exists = false
    local current = soundInfo.volume or 0.2
    if xSound:soundExists(plate) and xSound:isPlaying(plate) then
        exists  = true
        current = xSound:getVolume(plate)
        soundInfo.volume = current
    end
    local newVol = current + delta
    if newVol <= 1.01 and newVol >= -Config.VolumeEpsilon and exists then
        if newVol < Config.MinVolumeThreshold then newVol = 0.0 end
        soundInfo.volume = newVol
        SendNUIMessage({
            action = "changetextv",
            text   = "<b>Volume:</b> " .. volumeDisplayPct(newVol) .. "%",
            volume = newVol,
        })
        TriggerServerEvent("qb-car-music:ChangeVolume", delta, plate)
    end
end

-- SetUrl ---------------------------------------------------------------------

function SetUrl(url, nameId)
    local zoneFound = false
    for i = 1, #Zones do
        if Zones[i].name == nameId then
            zoneFound = true
            break
        end
    end

    if zoneFound then
        local vehicleNetId = nil
        if IsPedInAnyVehicle(cachedPed, false) then
            vehicleNetId = NetworkGetNetworkIdFromEntity(cachedVehicle)
        end
        TriggerServerEvent("qb-car-music:ModifyURL", {
            name         = nameId,
            link         = url,
            loop         = soundInfo.loop,
            vehicleNetId = vehicleNetId,
        })
    else
        if IsPedInAnyVehicle(cachedPed, false) then
            TriggerServerEvent("qb-car-music:AddVehicle", {
                plate        = nameId,
                coords       = GetEntityCoords(cachedVehicle),
                link         = url,
                vehicleNetId = NetworkGetNetworkIdFromEntity(cachedVehicle),
                volume       = soundInfo.volume,
                loop         = soundInfo.loop,
            })
        end
    end

    SendNUIMessage({ action = "TimeVid" })
    if xSound:soundExists(nameId) then
        SendNUIMessage({
            action = "TimeVid",
            total  = xSound:getMaxDuration(nameId),
            played = xSound:getTimeStamp(nameId),
        })
    end

    local waitCount = 0
    while isNuiOpen do
        Wait(1000)
        if xSound:soundExists(nameId) then
            if xSound:isPlaying(nameId) then
                SendNUIMessage({
                    action = "TimeVid",
                    total  = xSound:getMaxDuration(nameId),
                    played = xSound:getTimeStamp(nameId),
                })
                -- Auto-advance queue if track just ended (not paused)
            else
                waitCount = waitCount + 1
            end
        else
            waitCount = waitCount + 1
        end
        if waitCount >= 4 then break end
    end
end

-- Command / item / key-binding -----------------------------------------------

if not Config.ItemInVehicle then
    RegisterCommand(Config.CommandVehicle, function()
        showStereo()
    end, false)
    if Config.KeyBinding then
        RegisterKeyMapping(Config.CommandVehicle, "Open Car Stereo", "keyboard", Config.KeyBinding)
    end
end

if Config.ItemInVehicle then
    RegisterNetEvent("qb-car-music:ShowNui")
    AddEventHandler("qb-car-music:ShowNui", function()
        showStereo()
    end)
end

-- NUI show/hide --------------------------------------------------------------

function showStereo(zoneName)
    isShown = not isShown
    local name = zoneName
    if IsPedInAnyVehicle(cachedPed, false) then
        name = GetVehicleNumberPlateText(cachedVehicle)
    end

    if isShown and name then
        isNuiOpen = true
        soundInfo = { volume = 0.2, loop = false }
        local linkUrl
        if xSound:soundExists(name) then
            soundInfo.volume = xSound:getVolume(name)
            soundInfo.loop   = xSound:isLooped(name)
            if xSound:isPlaying(name) then
                linkUrl = xSound:getLink(name)
            end
        end
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = "changetextv",
            text   = "<b>Volume:</b> " .. volumeDisplayPct(soundInfo.volume) .. "%",
            volume = soundInfo.volume,
        })
        if type(soundInfo.loop) ~= "table" then
            SendNUIMessage({
                action = "changetextl",
                text   = "<b>Looping:</b> " .. firstToUpper(tostring(soundInfo.loop)),
            })
        end
        SendNUIMessage({ action = "changevidname", text = linkUrl })
        SendNUIMessage({ action = "showRadio" })
        SendNUIMessage({ action = "TimeVid" })
        if xSound:soundExists(name) then
            SendNUIMessage({
                action = "TimeVid",
                total  = xSound:getMaxDuration(name),
                played = xSound:getTimeStamp(name),
            })
        end

        local waitCount = 0
        while isNuiOpen do
            Wait(1000)
            if xSound:soundExists(name) then
                if xSound:isPlaying(name) then
                    SendNUIMessage({
                        action = "TimeVid",
                        total  = xSound:getMaxDuration(name),
                        played = xSound:getTimeStamp(name),
                    })
                else
                    waitCount = waitCount + 1
                end
            else
                waitCount = waitCount + 1
            end
            if waitCount >= 4 then break end
        end

    elseif isNuiOpen then
        activeZoneName = nil
        isNuiOpen      = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = "hideRadio", data = soundInfo })
    else
        Notify("~r~You can't do this right now")
    end
end

-- Net event: AddVehicle ------------------------------------------------------

RegisterNetEvent("qb-car-music:AddVehicle")
AddEventHandler("qb-car-music:AddVehicle", function(data)
    table.insert(Zones, data)
    if xSound:soundExists(data.name) then xSound:Destroy(data.name) end

    local effectiveVolume = data.volume
    if not Config.PlayToEveryone and data.vehicleNetId then
        effectiveVolume = 0.0
        if GetVehicleNumberPlateText(cachedVehicle) == data.name then
            effectiveVolume = data.volume
        end
    end

    xSound:PlayUrlPos(data.name, data.deflink, effectiveVolume, data.coords, data.loop, {
        onPlayStart = function()
            xSound:setTimeStamp(data.name, data.deftime)
            xSound:Distance(data.name, data.range)
        end,
    })

    local idx = #Zones
    table.insert(SoundsPlaying, idx)
    ScheduleMusicLoop(idx)
end)

-- Net event: ModifyURL -------------------------------------------------------

RegisterNetEvent("qb-car-music:ModifyURL")
AddEventHandler("qb-car-music:ModifyURL", function(data)
    local effectiveVolume = data.volume
    if not Config.PlayToEveryone and data.vehicleNetId then
        effectiveVolume = 0.0
        if GetVehicleNumberPlateText(cachedVehicle) == data.name then
            effectiveVolume = data.volume
        end
    end

    if xSound:soundExists(data.name) then
        if not xSound:isDynamic(data.name) then xSound:setSoundDynamic(data.name, true) end
        Wait(100)
        xSound:setVolumeMax(data.name, 0.0)
        xSound:setSoundURL(data.name, data.deflink)
        Wait(100)
        xSound:Position(data.name, data.coords)
        xSound:setSoundLoop(data.name, data.loop)
        Wait(200)
        xSound:setTimeStamp(data.name, 0)
        xSound:setVolumeMax(data.name, effectiveVolume)
    else
        xSound:PlayUrlPos(data.name, data.deflink, effectiveVolume, data.coords, data.loop, {
            onPlayStart = function()
                xSound:setTimeStamp(data.name, data.deftime)
                xSound:Distance(data.name, data.range)
            end,
        })
    end

    local zoneIdx = nil
    for i = 1, #Zones do
        local z = Zones[i]
        if data.name == z.name then
            if z.vehicleNetId then zoneIdx = i end
            z.deflink    = data.deflink
            z.deftime    = 0
            z.isplaying  = data.isplaying
            z.loop       = data.loop
            if data.vehicleNetId then z.vehicleNetId = data.vehicleNetId end
        end
    end

    local loopExists = false
    for _, v in ipairs(SoundsPlaying) do
        if v == zoneIdx then loopExists = true; break end
    end

    local waitCount = 0
    while isNuiOpen do
        Wait(1000)
        if xSound:soundExists(data.name) then
            local dist = #(cachedCoords - xSound:getPosition(data.name))
            if xSound:isPlaying(data.name) and (dist <= 3 or not data.vehicleNetId) then
                SendNUIMessage({
                    action = "TimeVid",
                    total  = xSound:getMaxDuration(data.name),
                    played = xSound:getTimeStamp(data.name),
                })
            else
                waitCount = waitCount + 1
            end
        else
            waitCount = waitCount + 1
        end
        if waitCount >= 4 then break end
    end

    if not loopExists and zoneIdx then
        table.insert(SoundsPlaying, zoneIdx)
        ScheduleMusicLoop(zoneIdx)
    end
end)

-- Net event: ChangeState -----------------------------------------------------

RegisterNetEvent("qb-car-music:ChangeState")
AddEventHandler("qb-car-music:ChangeState", function(state, name)
    if state and xSound:soundExists(name) then
        xSound:Resume(name)
    elseif xSound:soundExists(name) then
        xSound:Pause(name)
    end

    local zoneIdx = nil
    for i = 1, #Zones do
        if Zones[i].name == name then
            if Zones[i].vehicleNetId then zoneIdx = i end
            Zones[i].isplaying = state
        end
    end

    if state and zoneIdx then
        table.insert(SoundsPlaying, zoneIdx)
        ScheduleMusicLoop(zoneIdx)
    elseif zoneIdx then
        for i = #SoundsPlaying, 1, -1 do
            if SoundsPlaying[i] == zoneIdx then table.remove(SoundsPlaying, i) end
        end
    end
end)

-- Net event: ChangePosition --------------------------------------------------

RegisterNetEvent("qb-car-music:ChangePosition")
AddEventHandler("qb-car-music:ChangePosition", function(delta, name)
    local newTime
    for i = 1, #Zones do
        if Zones[i].name == name then
            Zones[i].deftime = math.max(0, Zones[i].deftime + delta)
            newTime = Zones[i].deftime
        end
    end
    if xSound:soundExists(name) then
        xSound:setTimeStamp(name, newTime)
    end
end)

-- Net event: ChangeLoop ------------------------------------------------------

RegisterNetEvent("qb-car-music:ChangeLoop")
AddEventHandler("qb-car-music:ChangeLoop", function(state, name)
    if xSound:soundExists(name) then xSound:setSoundLoop(name, state) end
    for i = 1, #Zones do
        if Zones[i].name == name then Zones[i].loop = state end
    end
end)

-- Net event: ChangeVolume ----------------------------------------------------

RegisterNetEvent("qb-car-music:ChangeVolume")
AddEventHandler("qb-car-music:ChangeVolume", function(volume, range, name)
    local vehicleNetId, zoneCoords
    for i = 1, #Zones do
        if name == Zones[i].name then
            Zones[i].volume   = volume
            Zones[i].range    = range
            vehicleNetId      = Zones[i].vehicleNetId
            zoneCoords        = Zones[i].coords
        end
    end
    if xSound:soundExists(name) then
        xSound:Distance(name, range)
        if not vehicleNetId and zoneCoords then
            xSound:setVolumeMax(name, volume)
        end
    end
end)

-- Net event: SendData (initial state sync) -----------------------------------

RegisterNetEvent("qb-car-music:SendData")
AddEventHandler("qb-car-music:SendData", function(data)
    Zones = data
    for i, v in ipairs(Zones) do
        if v.isplaying then
            if xSound:soundExists(v.name) then xSound:Destroy(v.name) end

            local effectiveVolume = v.volume
            if not Config.PlayToEveryone and v.vehicleNetId then
                effectiveVolume = 0.0
                if GetVehicleNumberPlateText(cachedVehicle) == v.name then
                    effectiveVolume = v.volume
                end
            end

            xSound:PlayUrlPos(v.name, v.deflink, effectiveVolume, v.coords, v.loop, {
                onPlayStart = function()
                    xSound:setTimeStamp(v.name, v.deftime)
                    xSound:Distance(v.name, v.range)
                end,
            })

            if v.vehicleNetId then
                table.insert(SoundsPlaying, i)
                ScheduleMusicLoop(i)
            end
        end
    end
end)

-- Net event: UpdateQueue (receive new queue state from server) ---------------

RegisterNetEvent("qb-car-music:UpdateQueue")
AddEventHandler("qb-car-music:UpdateQueue", function(name, queue)
    SendNUIMessage({ action = "updateQueue", name = name, queue = queue })
end)

-- Shared music-position scheduler (single coroutine per zone) ---------------

function ScheduleMusicLoop(zoneIdx)
    if scheduledLoops[zoneIdx] then return end
    scheduledLoops[zoneIdx] = true

    Citizen.CreateThread(function()
        local v = Zones[zoneIdx]
        while v and not xSound:soundExists(v.name) do Wait(10) end

        local posChanged = true
        while true do
            v = Zones[zoneIdx]
            if not v then
                scheduledLoops[zoneIdx] = nil
                return
            end

            if not v.isplaying or not xSound:soundExists(v.name) then
                -- Sound stopped / track ended — clean up
                if xSound:soundExists(v.name) then
                    if not xSound:isDynamic(v.name) then xSound:setSoundDynamic(v.name, true) end
                    xSound:setVolumeMax(v.name, 0.0)
                    if not posChanged then
                        xSound:Position(v.name, Config.OffscreenPosition)
                        posChanged = true
                    end
                end
                v.isplaying = false
                for j = #SoundsPlaying, 1, -1 do
                    if SoundsPlaying[j] == zoneIdx then table.remove(SoundsPlaying, j) end
                end
                scheduledLoops[zoneIdx] = nil
                return
            end

            local sleepMs      = 100
            local vehicleFound = false

            if v.vehicleNetId and NetworkDoesEntityExistWithNetworkId(v.vehicleNetId) then
                local vehicle = NetworkGetEntityFromNetworkId(v.vehicleNetId)
                if GetEntityType(vehicle) == 2 and GetVehicleNumberPlateText(vehicle) == v.name then
                    vehicleFound = true
                    local vehicleCoords = GetEntityCoords(vehicle)
                    local distToPlayer  = #(vehicleCoords - cachedCoords)

                    if distToPlayer <= v.range + 50 then
                        local currentVol  = xSound:getVolume(v.name)
                        local isDynamic   = xSound:isDynamic(v.name)
                        local soundPosDrift = #(v.coords - vehicleCoords)

                        if currentVol <= Config.VolumeEpsilon then sleepMs = 1000 end

                        if cachedVehicle == vehicle then
                            -- Player is in the vehicle: non-dynamic, direct volume
                            if isDynamic then xSound:setSoundDynamic(v.name, false) end
                            if currentVol ~= v.volume then xSound:setVolume(v.name, v.volume) end
                            if soundPosDrift >= 5.0 or posChanged then
                                posChanged = false
                                v.coords = vehicleCoords
                                xSound:Position(v.name, vehicleCoords)
                            else
                                sleepMs = sleepMs + 150
                            end
                        else
                            -- Player is outside: dynamic positional audio
                            if not isDynamic then xSound:setSoundDynamic(v.name, true) end
                            if currentVol ~= v.volume then xSound:setVolumeMax(v.name, v.volume) end
                            if distToPlayer >= v.range + 20 then
                                sleepMs = math.min((distToPlayer * 100) / 3, 10000)
                            end
                            local speed = GetEntitySpeed(vehicle) * 3.6
                            if speed <= 2.0 then
                                sleepMs = sleepMs + 2500
                            elseif speed <= 5.0 then
                                sleepMs = sleepMs + 1000
                            elseif speed <= 10.0 then
                                sleepMs = sleepMs + 100
                            end
                            if soundPosDrift >= 1.0 or posChanged then
                                posChanged = false
                                v.coords = vehicleCoords
                                xSound:Position(v.name, vehicleCoords)
                            else
                                sleepMs = sleepMs + 150
                            end
                        end
                    else
                        -- Vehicle is out of audible range
                        if not xSound:isDynamic(v.name) then xSound:setSoundDynamic(v.name, true) end
                        xSound:setVolumeMax(v.name, 0.0)
                        if not posChanged then
                            xSound:Position(v.name, Config.OffscreenPosition)
                            posChanged = true
                        end
                        sleepMs = math.min((distToPlayer * 100) / 2, 10000)
                    end
                end
            end

            if not vehicleFound and v.vehicleNetId then
                if not xSound:isDynamic(v.name) then xSound:setSoundDynamic(v.name, true) end
                if not posChanged then
                    xSound:Position(v.name, Config.OffscreenPosition)
                    posChanged = true
                end
                sleepMs = 5000
            end

            if sleepMs > 10000 then sleepMs = 10000 end
            Wait(sleepMs)
        end
    end)
end

-- Zone proximity check (extracted helper, consolidates duplicate logic) ------

local function CheckZoneProximity(zone)
    local dist = #(cachedCoords - zone.changemusicblip)
    if dist <= 3 then
        DrawText3D(zone.changemusicblip.x, zone.changemusicblip.y, zone.changemusicblip.z, "~r~E~w~ - Change Music")
        if IsControlJustReleased(0, 38) then
            activeZoneName = zone.name
            showStereo(zone.name)
            Wait(1000)
        end
        return 5
    elseif dist <= 10 then
        return 500
    elseif dist <= 100 then
        return 2000
    else
        return 5000
    end
end

-- Zone proximity loop (lazy-loaded: starts only after job is known, and
-- skipped entirely when no zones are defined) --------------------------------

Citizen.CreateThread(function()
    if #Config.Zones == 0 then return end
    while myJob == nil do Wait(100) end

    while true do
        local sleepMs = 5000
        for _, zone in ipairs(Config.Zones) do
            if PlayerCanAccessZone(zone) then
                sleepMs = math.min(sleepMs, CheckZoneProximity(zone))
            end
        end
        Wait(sleepMs)
    end
end)

-- Map blips for zone interact points -----------------------------------------

if Config.ZoneBlips then
    Citizen.CreateThread(function()
        for _, zone in ipairs(Config.Zones) do
            local blip = AddBlipForCoord(zone.changemusicblip.x, zone.changemusicblip.y, zone.changemusicblip.z)
            SetBlipSprite(blip, 500)
            SetBlipScale(blip, 0.7)
            SetBlipColour(blip, 2)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(zone.name)
            EndTextCommandSetBlipName(blip)
        end
    end)
end

-- DrawText3D helper ----------------------------------------------------------

function DrawText3D(x, y, z, text, r, g, b, a)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    if r and g and b and a then
        SetTextColour(r, g, b, a)
    else
        SetTextColour(255, 255, 255, 215)
    end
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    local factor = string.len(text) / 370
    DrawRect(0.0, 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end
