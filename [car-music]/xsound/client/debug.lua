local displayData = false
local txdDict = "xsound_dui_txd"
local txdName = "xsound_dui_txn"

function CreateDuiText(duiObject)
    if config.debug then
        local handle = GetDuiHandle(duiObject)
        CreateRuntimeTextureFromDuiHandle(CreateRuntimeTxd(txdDict), txdName, handle)
    end
end

if config.debug then
    RegisterCommand("showsounds", function()
        displayData = not displayData
        print("displayData", displayData)
    end)

    CreateThread(function()
        while true do
            Wait(0)
            if displayData and GlobalSoundDui then
                DrawSprite(txdDict, txdName, 0.5, 0.5, 1.0, 1.0, 0.0, 255, 255, 255, 255)
            else
                Wait(1000)
            end
        end
    end)

    local color = { r = 255, g = 255, b = 255, a = 255 }
    local scaleOption = 1.0

    local function draw3DText(pos, text)
        local camCoords = GetGameplayCamCoords()
        local dist = #(camCoords - pos)
        local scale = (scaleOption / dist) * 2
        local fov = (1 / GetGameplayCamFov()) * 100
        local scaleMultiplier = scale * fov
        SetDrawOrigin(pos.x, pos.y, pos.z, 0);
        SetTextProportional(0)
        SetTextScale(0.0 * scaleMultiplier, 0.55 * scaleMultiplier)
        SetTextColour(color.r, color.g, color.b, color.a)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(0.0, 0.0)
        ClearDrawOrigin()
    end

    local function GetCoordText(position)
        return string.format("X: %.2f | Y: %.2f | Z: %.2f)", position.x, position.y, position.z)
    end

    local function getCurrentVolume(currentDist, maxDist, maxVolume)
        if maxDist == 0 then
            return 0.0
        end

        local distanceRatio = currentDist / maxDist

        if distanceRatio < 1.0 then
            local vol = maxVolume * (1.0 - distanceRatio)
            return vol
        else
            return 0.0
        end
    end

    CreateThread(function()
        while true do
            Wait(0)
            if displayData then
                for k, v in pairs(soundInfo) do
                    if v.isDynamic and v.position then
                        local currentDistance = #(GetEntityCoords(PlayerPedId()) - v.position)
                        if #(GetEntityCoords(PlayerPedId()) - v.position) < (v.distance + config.distanceBeforeUpdatingPos) then
                            local currVolume = getCurrentVolume(currentDistance, v.distance, v.volume)
                            draw3DText(v.position, string.format("ID: %s\nDis: %s\nPlay | paused: %s-%s\nPos: %s", k, v.distance, v.playing, v.paused, GetCoordText(v.position)))
                            draw3DText(v.position - vector3(0, 0, 1), string.format("Time: %s/%s\nCurrent Volume: %s%%", v.timeStamp, math.floor(v.maxDuration), math.floor(100 * currVolume)))
                        end
                    end
                end
            else
                Wait(1000)
            end
        end
    end)
end