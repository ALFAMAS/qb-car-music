local QBCore = exports['qb-core']:GetCoreObject()

local Music = {}
local datasoundinfo = {}
local nuiaberto = false
xSound = exports.xsound
local myjob = nil
local nomidaberto
local SoundsPlaying = {}


Citizen.CreateThread(function() 
	Wait(500)
	while QBCore.Functions.GetPlayerData().job == nil do
       	Citizen.Wait(10)
    end
	myjob = QBCore.Functions.GetPlayerData().job
	TriggerServerEvent("qb-car-music:GetDate")
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate')  
AddEventHandler('QBCore:Client:OnJobUpdate', function(job)
	myjob = job
end)

RegisterNUICallback("action", function(data)
	local _source = source
	local nameid = nomidaberto
	if IsPedInAnyVehicle(PlayerPedId(), false) then
		local veh = GetVehiclePedIsIn(PlayerPedId(),false)
		local plate = GetVehicleNumberPlateText(veh)
		nameid = plate
	end
	if data.action == "seturl" then
		SetUrl(data.link,nameid)
	elseif data.action == "play" then
		if xSound:soundExists(nameid) then
			if xSound:isPaused(nameid) then
				TriggerServerEvent("qb-car-music:ChangeState", true, nameid)
				local esperar = 0
				while nuiaberto do
					Wait(1000)
					if xSound:isPlaying(nameid) then
						SendNUIMessage({
							action = "TimeVid",
							total = xSound:getMaxDuration(nameid),
							played = xSound:getTimeStamp(nameid),
						})
					else
						esperar = esperar +1
					end
					if esperar >= 5 then
						break
					end
				end
			end
		end
	elseif data.action == "pause" then
		if xSound:soundExists(nameid) then
			if xSound:isPlaying(nameid) then
				TriggerServerEvent("qb-car-music:ChangeState", false, nameid)
			end
		end
	elseif data.action == "exit" then
		show()
	elseif data.action == "volumeup" then
		ApplySound(0.05,nameid)
	elseif data.action == "volumedown" then
		ApplySound(-0.05,nameid)
	elseif data.action == "loop" then
		if xSound:soundExists(nameid) then
			datasoundinfo.loop = not xSound:isLooped(nameid)
			TriggerServerEvent("qb-car-music:ChangeLoop",nameid,datasoundinfo.loop)
		else
			datasoundinfo.loop = not datasoundinfo.loop
		end
		if type(datasoundinfo.loop) ~= "table" then
			local loop = ('<b>Looping:</b> '.. firstToUpper(tostring(datasoundinfo.loop)))
			SendNUIMessage({
				action = "changetextl",
				text = loop,
			})
		end
	elseif data.action == "forward" then
		if xSound:soundExists(nameid) then
			TriggerServerEvent("qb-car-music:ChangePosition", 10, nameid)
		end
	elseif data.action == "back" then
		if xSound:soundExists(nameid) then
			TriggerServerEvent("qb-car-music:ChangePosition", -10, nameid)
		end
	end
end)

function ApplySound(quanti,plate)
	local exis = false
	local som = datasoundinfo.volume
	if xSound:soundExists(plate) and xSound:isPlaying(plate) then
		exis = true
		som = xSound:getVolume(plate)
		datasoundinfo.volume = som
	end
	local vadi = som + quanti
	if vadi <= 1.01 and vadi >= -0.001 and exis then
		if vadi < 0.005 then
			vadi = 0.0
		end
		datasoundinfo.volume = vadi
		local volume = (('<b>Volume:</b> '.. math.floor((vadi*100) - 0.1+1).."%"))
		SendNUIMessage({
            action = "changetextv",
            text = volume,
        })
		TriggerServerEvent("qb-car-music:ChangeVolume", quanti, plate)
	end
end

function firstToUpper(str)
    return (str:gsub("^%l", string.upper))
end

function SetUrl(url,nid)
	local nome = nid
	if url then
		local encontrad = false
		for i = 1, #Zones do
			local v = Zones[i]
			if v.name == nome then
				encontrad = true
			end
		end
		if encontrad then
			local vehdata = {}
			vehdata.name = nome
			vehdata.link = url
			vehdata.loop = datasoundinfo.loop
			if IsPedInAnyVehicle(PlayerPedId(), false) then
				vehdata.popo = NetworkGetNetworkIdFromEntity(GetVehiclePedIsIn(PlayerPedId(),false))
			end
			TriggerServerEvent("qb-car-music:ModifyURL",vehdata)
		else
			if IsPedInAnyVehicle(PlayerPedId(), false) then
				local veh = GetVehiclePedIsIn(PlayerPedId(),false)
				local cordsveh = GetEntityCoords(veh)
				local netid = NetworkGetNetworkIdFromEntity(veh)
				local vehdata = {}
				vehdata.plate = nome
				vehdata.coords = cordsveh
				vehdata.link = url
				vehdata.popo = netid
				vehdata.volume = datasoundinfo.volume
				vehdata.loop = datasoundinfo.loop
				TriggerServerEvent("qb-car-music:AddVehicle",vehdata)
			end
		end
	else
	
	end
	SendNUIMessage({
		action = "TimeVid",
	})
	if xSound:soundExists(nome) then
		SendNUIMessage({
			action = "TimeVid",
			total = xSound:getMaxDuration(nome),
			played = xSound:getTimeStamp(nome),
		})
	end
	local esperar = 0
	while nuiaberto do
		Wait(1000)
		if xSound:soundExists(nome) then
			if xSound:isPlaying(nome) then
				SendNUIMessage({
					action = "TimeVid",
					total = xSound:getMaxDuration(nome),
					played = xSound:getTimeStamp(nome),
				})
			else
				esperar = esperar +1
			end
		else
			esperar = esperar +1
		end
		if esperar >= 4 then
			break
		end
	end
end

if not Config.ItemInVehicle then
	RegisterCommand(Config.CommandVehicle, function(source, args, rawCommand)
		show()
	end, false)
end

if Config.ItemInVehicle then
	RegisterNetEvent("qb-car-music:ShowNui")
	AddEventHandler("qb-car-music:ShowNui", function()
		show()
	end)
end

local shown = false

function show(nomecenas)
	shown = not shown
	local nome = nomecenas
	if IsPedInAnyVehicle(PlayerPedId(), false) then
		local veh = GetVehiclePedIsIn(PlayerPedId(),false)
		local plate = GetVehicleNumberPlateText(veh)
		nome = plate
	end
    if shown and nome then
		nuiaberto = true
		datasoundinfo = {volume = 0.2, loop = false}
		local linkurl
		if xSound:soundExists(nome) then
			datasoundinfo.volume = xSound:getVolume(nome)
			datasoundinfo.loop = xSound:isLooped(nome)
			if xSound:isPlaying(nome) then
				linkurl = xSound:getLink(nome)
			end
		end
        SetNuiFocus(true, true)
		local volume = ('<b>Volume:</b> '.. math.floor((datasoundinfo.volume*100) - 0.1+1).."%")
		if type(datasoundinfo.loop) ~= "table" then
			local loop = ('<b>Looping:</b> '.. firstToUpper(tostring(datasoundinfo.loop)))
			SendNUIMessage({
				action = "changetextl",
				text = loop,
			})
		end
		SendNUIMessage({
            action = "changetextv",
            text = volume,
        })
		SendNUIMessage({
            action = "changevidname",
            text = linkurl,
        })
		SendNUIMessage({
            action = "showRadio",
        })
		SendNUIMessage({
			action = "TimeVid",
		})
		if xSound:soundExists(nome) then
			SendNUIMessage({
				action = "TimeVid",
				total = xSound:getMaxDuration(nome),
				played = xSound:getTimeStamp(nome),
			})
		end
		local esperar = 0
		while nuiaberto do
			Wait(1000)
			if xSound:soundExists(nome) then
				if xSound:isPlaying(nome) then
					SendNUIMessage({
						action = "TimeVid",
						total = xSound:getMaxDuration(nome),
						played = xSound:getTimeStamp(nome),
					})
				else
					esperar = esperar +1
				end
			else
				esperar = esperar +1
			end
			if esperar >= 4 then
				break
			end
		end
    elseif nuiaberto then
		nomidaberto = nil
		nuiaberto = false
        SetNuiFocus(false, false)
        SendNUIMessage({
            action = "hideRadio",
			data = datasoundinfo
        })
    else
		QBCore.Functions.Notify("~r~You can't do this right now")
	end
end

Zones = {}

RegisterNetEvent("qb-car-music:AddVehicle")
AddEventHandler("qb-car-music:AddVehicle", function(data)
	table.insert(Zones, data)
	local v = data
	if xSound:soundExists(v.name) then
		xSound:Destroy(v.name)
	end
	local avancartodos = v.volume
	if not Config.PlayToEveryone and v.popo then
		avancartodos = 0.0
		local popodentro = GetVehiclePedIsIn(PlayerPedId(),false)
		local plate = GetVehicleNumberPlateText(popodentro)
		if plate == v.name then
			avancartodos = v.volume
		end
	end
	xSound:PlayUrlPos(v.name, v.deflink, avancartodos, v.coords, v.loop,{
		onPlayStart = function(event)
			xSound:setTimeStamp(v.name, v.deftime)
			xSound:Distance(v.name,v.range)
		end,
	})
	table.insert(SoundsPlaying, #Zones)
	StartMusicLoop(#Zones)
end)

RegisterNetEvent("qb-car-music:ModifyURL")
AddEventHandler("qb-car-music:ModifyURL", function(data)
	local v = data
	local avancartodos = v.volume
	if not Config.PlayToEveryone and v.popo then
		avancartodos = 0.0
		local popodentro = GetVehiclePedIsIn(PlayerPedId(),false)
		local plate = GetVehicleNumberPlateText(popodentro)
		if plate == v.name then
			avancartodos = v.volume
		end
	end
	if xSound:soundExists(v.name) then
		if not xSound:isDynamic(v.name) then
			xSound:setSoundDynamic(v.name,true)
		end
		Wait(100)
		xSound:setVolumeMax(v.name,0.0)
		xSound:setSoundURL(v.name, v.deflink)
		Wait(100)
		xSound:Position(v.name, v.coords)
		xSound:setSoundLoop(v.name,v.loop)
		Wait(200)
		xSound:setTimeStamp(v.name,0)
		xSound:setVolumeMax(v.name,avancartodos)
									 
	else
		xSound:PlayUrlPos(v.name, v.deflink, avancartodos, v.coords, v.loop, {
			onPlayStart = function(event)
				xSound:setTimeStamp(v.name, v.deftime)
				xSound:Distance(v.name,v.range)
			end,
		})
	end
	local iss = nil
	for i = 1, #Zones do
		local b = Zones[i]
		if v.name == b.name then
			if b.popo then
				iss = i
			end
			b.deflink = v.deflink
			b.deftime = 0
			b.isplaying = v.isplaying
			b.loop = v.loop
			if v.popo then
				b.popo = v.popo
			end
		end
	end
	local encontrads = false
	for i = 1, #SoundsPlaying do
		local v = SoundsPlaying[i]
		if v == iss then
			encontrads = true
		end
	end
	local esperar = 0
	while nuiaberto do
		Wait(1000)
		if xSound:soundExists(v.name) then
			local pped = PlayerPedId()
			local coordss = GetEntityCoords(pped)
			local geraldist = #(coordss-xSound:getPosition(v.name))
			if xSound:isPlaying(v.name) and (geraldist <= 3 or not v.popo) then
				SendNUIMessage({
					action = "TimeVid",
					total = xSound:getMaxDuration(v.name),
					played = xSound:getTimeStamp(v.name),
				})
			else
				esperar = esperar +1
			end
		else
			esperar = esperar +1
		end
		if esperar >= 4 then
			break
		end
	end
	if not encontrads and iss then
		table.insert(SoundsPlaying, iss)
		StartMusicLoop(iss)
	end
end)

RegisterNetEvent("qb-car-music:ChangeState")
AddEventHandler("qb-car-music:ChangeState", function(tipo, nome)
	if tipo and xSound:soundExists(nome) then
		xSound:Resume(nome)
	elseif xSound:soundExists(nome) then
		xSound:Pause(nome)
	end
	local iss = nil
	for i = 1, #Zones do
		local v = Zones[i]
		if v.name == nome then
			if v.popo then
				iss = i
			end
			v.isplaying = tipo
		end
	end
	if tipo and iss then
		table.insert(SoundsPlaying, iss)
		StartMusicLoop(iss)
	elseif iss then
		for i = 1, #SoundsPlaying do
			local v = SoundsPlaying[i]
			if v == iss then
				table.remove(SoundsPlaying, i)
			end
		end
	end
end)

RegisterNetEvent("qb-car-music:ChangePosition")
AddEventHandler("qb-car-music:ChangePosition", function(quanti, nome)
	local tempapply
	for i = 1, #Zones do
		local v = Zones[i]
		if v.name == nome then
			v.deftime = v.deftime + quanti
			if v.deftime < 0 then
				v.deftime = 0
			end
			tempapply = v.deftime
		end
	end
	if xSound:soundExists(nome) then
		xSound:setTimeStamp(nome,tempapply)
	end
end)

RegisterNetEvent("qb-car-music:ChangeLoop")
AddEventHandler("qb-car-music:ChangeLoop", function(tipo, nome)
	if xSound:soundExists(nome) then
		xSound:setSoundLoop(nome,tipo)
	end
	for i = 1, #Zones do
		local v = Zones[i]
		if v.name == nome then
			v.loop = tipo
		end
	end
end)

RegisterNetEvent("qb-car-music:ChangeVolume")
AddEventHandler("qb-car-music:ChangeVolume", function(som, range, nome)
	local carroe
	local crds
    for i = 1, #Zones do
        local v = Zones[i]
        if nome == v.name then
            v.volume = som
            v.range = range
			carroe = v.popo
			crds = v.coords
        end
    end
	if xSound:soundExists(nome) then
		xSound:Distance(nome,range)
		if not carroe and crds then
			xSound:setVolumeMax(nome,som)
		end
	end
end)

function countTime()
    SetTimeout(2000, countTime)
    for i = 1, #Zones do
		local v = Zones[i]
		if v.isplaying then
			v.deftime = v.deftime + 2
		end
    end
end

SetTimeout(2000, countTime)

RegisterNetEvent("qb-car-music:SendData")
AddEventHandler("qb-car-music:SendData", function(data)
    Zones = data
    for i = 1, #Zones do
		local v = Zones[i]
		if v.isplaying then
			if xSound:soundExists(v.name) then
				xSound:Destroy(v.name)
			end
			local avancartodos = v.volume
			if not Config.PlayToEveryone and v.popo then
				avancartodos = 0.0
				local popodentro = GetVehiclePedIsIn(PlayerPedId(),false)
				local plate = GetVehicleNumberPlateText(popodentro)
				if plate == v.name then
					avancartodos = v.volume
				end
			end
			xSound:PlayUrlPos(v.name, v.deflink, avancartodos, v.coords, v.loop,
			{
				onPlayStart = function(event)
					xSound:setTimeStamp(v.name, v.deftime)
					xSound:Distance(v.name,v.range)
				end,
			})
			if v.popo then
				table.insert(SoundsPlaying, i)
				StartMusicLoop(i)
			end
		end
    end
end)

local plpedloop
local pploop
local coordsped

Citizen.CreateThread(function()
	local poschanged = true
	while true do
		Wait(500)
		plpedloop = PlayerPedId()
		pploop = GetVehiclePedIsIn(plpedloop,false)
		coordsped = GetEntityCoords(plpedloop)
	end
end)

function StartMusicLoop(i)
	while not xSound:soundExists(Zones[i].name) do
		Wait(10)
	end
	Citizen.CreateThread(function()
		local poschanged = true
		while true do
			local sleep = 100
			local v = Zones[i]
			if v == nil then
				return
			end
			if v.isplaying and xSound:soundExists(v.name) then
				local carrofound = false
				if NetworkDoesEntityExistWithNetworkId(v.popo)then
					local carro = NetworkGetEntityFromNetworkId(v.popo)
					if GetEntityType(carro) == 2 then
						if GetVehicleNumberPlateText(carro) == v.name then
							carrofound = true
							local cordsveh = GetEntityCoords(carro)
							local geraldist = #(cordsveh-coordsped)
							if geraldist <= v.range+50 then
								local avolume = xSound:getVolume(v.name)
								local dina = xSound:isDynamic(v.name)
								local getpos = v.coords
								local getposdif = #(getpos-cordsveh)
								if avolume <= 0.001 then
									sleep = 1000
								end
								if pploop == carro then
									if dina then
										xSound:setSoundDynamic(v.name,false)
									end
									if avolume ~= v.volume then
										xSound:setVolume(v.name,v.volume)
									end
									if getposdif >= 5.0 or poschanged then
										poschanged = false
										v.coords = cordsveh
										xSound:Position(v.name, cordsveh)
									else
										sleep = sleep+150
									end
								else	
									if not dina then
										xSound:setSoundDynamic(v.name,true)
									end
									if avolume ~= v.volume then
										xSound:setVolumeMax(v.name,v.volume)
									end
									if geraldist >= v.range+20 then
										sleep = (geraldist*100)/3
									end
									if sleep <= 10000 then
										local speedcar = GetEntitySpeed(carro)*3.6
										if speedcar <= 2.0 then
											sleep = sleep+2500
										elseif speedcar <= 5.0 then
											sleep = sleep+1000
										elseif speedcar <= 10.0 then
											sleep = sleep+100
										end
									end
									if getposdif >= 1.0 or poschanged then
										poschanged = false
										v.coords = cordsveh
										xSound:Position(v.name, cordsveh)
									else
										sleep = sleep+150
									end
								end
							else
								if not xSound:isDynamic(v.name) then
									xSound:setSoundDynamic(v.name,true)
								end
								xSound:setVolumeMax(v.name,0.0)
								if not poschanged then
									xSound:Position(v.name, vector3(350.0,0.0,-150.0))
									poschanged = true
								end
								sleep = (geraldist*100)/2
							end
						end
					end
				end
				if not carrofound then
					if not xSound:isDynamic(v.name) then
						xSound:setSoundDynamic(v.name,true)
					end
					--xSound:setVolumeMax(v.name,0.0)
					if not poschanged then
						xSound:Position(v.name, vector3(350.0,0.0,-150.0))
						poschanged = true
					end
					Wait(5000)
				end
			else
				if xSound:soundExists(v.name) then
					if not xSound:isDynamic(v.name) then
						xSound:setSoundDynamic(v.name,true)
					end
					xSound:setVolumeMax(v.name,0.0)
					if not poschanged then
						xSound:Position(v.name, vector3(350.0,0.0,-150.0))
						poschanged = true
					end
				end
				v.isplaying = false
				for j = 1, #SoundsPlaying do
					local k = SoundsPlaying[j]
					if k == i then
						table.remove(SoundsPlaying, j)
					end
				end
				break
			end
			if sleep > 10000 then
				sleep = 10000
			end
			Wait(sleep)
		end
	end)
end

Citizen.CreateThread(function()
	while myjob == nil do
		Wait(100)
	end
	local jobnil = false
	for i = 1, #Config.Zones do
		local v = Config.Zones[i]
		if v.job == nil then
			jobnil = true
		end
	end
	while true do
		local dormir = 2000
		local coords = GetEntityCoords(GetPlayerPed(-1))
		for i = 1, #Config.Zones do
			local v = Config.Zones[i]
			if myjob.name == v.job then
				local distance = #(coords - v.changemusicblip)
				if distance <= 10 then
					dormir = 500
					if distance <= 3 then
						dormir = 5
						DrawText3D(v.changemusicblip.x, v.changemusicblip.y, v.changemusicblip.z, "~r~E~w~ - Change Music")
						if IsControlJustReleased(0, 38) then
							nomidaberto = v.name
							show(v.name)
							Wait(1000)
						end
					end
				end
			end
			if jobnil then
				if v.job == nil then
					local distance = #(coords - v.changemusicblip)
					if distance <= 10 then
						dormir = 500
						if distance <= 3 then
							dormir = 5
							DrawText3D(v.changemusicblip.x, v.changemusicblip.y, v.changemusicblip.z, "~r~E~w~ - Change Music")
							if IsControlJustReleased(0, 38) then
								nomidaberto = v.name
								show(v.name)
								Wait(1000)
							end
						end
					end
				end
			end
		end
		Wait(dormir)
	end
end)


function DrawText3D(x, y, z, text,r,g,b,a)
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
    SetDrawOrigin(x,y,z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0+0.0125, 0.017+ factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end