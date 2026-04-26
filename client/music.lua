local xSound = exports.xsound
local playing = false
local volume = Config.DEFAULT_VOLUME
local meloraUrl = nil
local myMusicId = "phone_meloraemusic_id_" .. GetPlayerServerId(PlayerId())

local playlist = {}
local currentPlaylistIndex = 0
local isPaused = false

local function loadPlaylist()
    local savedPlaylist = GetResourceKvpString("melora_playlist")
    if savedPlaylist then
        playlist = json.decode(savedPlaylist) or {}
    else
        playlist = {}
    end
end

local function savePlaylist()
    SetResourceKvp("melora_playlist", json.encode(playlist))
end

loadPlaylist()

-- NUI Callbacks
RegisterNUICallback("playSound", function(data, cb)
    local coords = GetEntityCoords(PlayerPedId())
    meloraUrl = data.url
    playing = true

    TriggerServerEvent("phone:melora:soundStatus", "play", {
        position = coords,
        link = meloraUrl,
        volume = volume
    })

    CreateThread(function()
        Wait(500)
        local pos = GetEntityCoords(PlayerPedId())
        TriggerServerEvent("phone:melora:soundStatus", "position", {
            position = pos
        })

        Wait(1000)
        local pos2 = GetEntityCoords(PlayerPedId())
        TriggerServerEvent("phone:melora:soundStatus", "position", {
            position = pos2
        })
    end)

    cb({})
end)

RegisterNUICallback("stopSound", function(_, cb)
    playing = false
    isPaused = false
    currentPlaylistIndex = 0
    TriggerServerEvent("phone:melora:soundStatus", "stop", {})
    cb({})
end)

RegisterNUICallback("changeVolume", function(data, cb)
    volume = data.volume
    TriggerServerEvent("phone:melora:soundStatus", "volume", {
        volume = volume
    })
    cb({})
end)

RegisterNUICallback("getData", function(_, cb)
    cb({
        isPlay = playing,
        volume = volume,
        meloraUrl = meloraUrl,
        playlist = playlist,
        currentPlaylistIndex = currentPlaylistIndex
    })
end)

RegisterNUICallback("addToPlaylist", function(data, cb)
    table.insert(playlist, {
        url = data.url,
        title = data.title,
        thumbnail = data.thumbnail
    })
    savePlaylist()
    cb({ success = true, playlist = playlist })
end)

RegisterNUICallback("removeFromPlaylist", function(data, cb)
    table.remove(playlist, data.index)
    savePlaylist()
    cb({ success = true, playlist = playlist })
end)

RegisterNUICallback("playFromPlaylist", function(data, cb)
    if playlist[data.index] then
        currentPlaylistIndex = data.index
        local song = playlist[data.index]
        local coords = GetEntityCoords(PlayerPedId())
        meloraUrl = song.url
        playing = true

        TriggerServerEvent("phone:melora:soundStatus", "play", {
            position = coords,
            link = meloraUrl,
            volume = volume
        })

        Core.SendNuiMessage("songChanged", {
            url = song.url,
            index = currentPlaylistIndex
        })

        CreateThread(function()
            Wait(500)
            local pos = GetEntityCoords(PlayerPedId())
            TriggerServerEvent("phone:melora:soundStatus", "position", {
                position = pos
            })

            Wait(1000)
            local pos2 = GetEntityCoords(PlayerPedId())
            TriggerServerEvent("phone:melora:soundStatus", "position", {
                position = pos2
            })
        end)
    end
    cb({})
end)

RegisterNUICallback("getPlaylist", function(_, cb)
    cb({ playlist = playlist })
end)

RegisterNUICallback("getLocale", function(_, cb)
    cb({ locale = Config.Locale or 'en' })
end)

RegisterNUICallback("playNext", function(_, cb)
    if #playlist > 0 then
        currentPlaylistIndex = currentPlaylistIndex + 1
        if currentPlaylistIndex > #playlist then
            currentPlaylistIndex = 1
        end

        local song = playlist[currentPlaylistIndex]
        if song then
            local coords = GetEntityCoords(PlayerPedId())
            meloraUrl = song.url
            playing = true

            TriggerServerEvent("phone:melora:soundStatus", "play", {
                position = coords,
                link = meloraUrl,
                volume = volume
            })

            Core.SendNuiMessage("songChanged", {
                url = song.url,
                index = currentPlaylistIndex
            })
        end
    end
    cb({})
end)

RegisterNUICallback("playPrevious", function(_, cb)
    if #playlist > 0 then
        currentPlaylistIndex = currentPlaylistIndex - 1
        if currentPlaylistIndex < 1 then
            currentPlaylistIndex = #playlist
        end

        local song = playlist[currentPlaylistIndex]
        if song then
            local coords = GetEntityCoords(PlayerPedId())
            meloraUrl = song.url
            playing = true

            TriggerServerEvent("phone:melora:soundStatus", "play", {
                position = coords,
                link = meloraUrl,
                volume = volume
            })

            Core.SendNuiMessage("songChanged", {
                url = song.url,
                index = currentPlaylistIndex
            })
        end
    end
    cb({})
end)

RegisterNUICallback("pauseSound", function(_, cb)
    isPaused = true
    TriggerServerEvent("phone:melora:soundStatus", "pause", {})
    cb({})
end)

RegisterNUICallback("resumeSound", function(_, cb)
    isPaused = false
    TriggerServerEvent("phone:melora:soundStatus", "resume", {})
    cb({})
end)

-- Position update logic
local function getSpeed(ped)
    local vel = GetEntityVelocity(ped)
    return #(vector3(vel.x, vel.y, vel.z)) * 2.23694
end

local lastTier = 0
local tierExpireTime = 0
local lastPosition = vector3(0, 0, 0)
local tiers = Config.UPDATE_TIERS

CreateThread(function()
    Wait(1000)
    while true do
        if playing then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local speed = getSpeed(ped)
            local currentTime = GetGameTimer()
            local selectedWait = 1000
            local selectedTier = 0

            for _, tier in ipairs(tiers) do
                if speed >= tier.speed then
                    selectedWait = tier.wait
                    selectedTier = tier.level
                    break
                end
            end

            if selectedTier > lastTier then
                lastTier = selectedTier
                tierExpireTime = currentTime + Config.TIER_STICKY_TIME
            elseif currentTime < tierExpireTime then
                for _, tier in ipairs(tiers) do
                    if tier.level == lastTier then
                        selectedWait = tier.wait
                        break
                    end
                end
            else
                lastTier = selectedTier
            end

            local distanceMoved = #(coords - lastPosition)
            local shouldUpdate = false

            if selectedTier >= 3 then
                shouldUpdate = true
            elseif distanceMoved > Config.MIN_DISTANCE_THRESHOLD then
                shouldUpdate = true
            elseif selectedWait >= 1000 and distanceMoved > 0.5 then
                shouldUpdate = true
            end

            if shouldUpdate then
                TriggerServerEvent("phone:melora:soundStatus", "position", {
                    position = coords
                })
                lastPosition = coords
            end

            Wait(selectedWait)
        else
            Wait(1000)
        end
    end
end)

-- Receive sound events from server
RegisterNetEvent("phone:melora:soundStatus", function(type, musicId, data)
    if type == "position" and data.position then
        local myPed = PlayerPedId()
        local myCoords = GetEntityCoords(myPed)
        local distance = #(myCoords - vector3(data.position.x, data.position.y, data.position.z))

        if distance > Config.MUSIC_RANGE then
            if xSound:soundExists(musicId) then
                xSound:Destroy(musicId)
            end
            return
        end

        if not xSound:soundExists(musicId) then
            local playerId = tonumber(string.match(musicId, "(%d+)$"))
            if playerId then
                TriggerServerEvent("phone:melora:requestSync", playerId)
            end
        end
    end

    if type == "play" then
        if data.position then
            local myPed = PlayerPedId()
            local myCoords = GetEntityCoords(myPed)
            local distance = #(myCoords - vector3(data.position.x, data.position.y, data.position.z))

            if distance > Config.MUSIC_RANGE then
                return
            end
        end

        xSound:PlayUrlPos(musicId, data.link, 1.0, data.position)
        xSound:setSoundDynamic(musicId, true)
        xSound:Distance(musicId, Config.XSOUND_DISTANCE)
        xSound:destroyOnFinish(musicId, true)

        local vol = data.volume or volume or Config.DEFAULT_VOLUME
        xSound:setVolumeMax(musicId, vol / 100)

        if data.elapsedTime and data.elapsedTime > 0 then
            CreateThread(function()
                Wait(1500)
                local attempts = 0
                while attempts < 3 do
                    if xSound:soundExists(musicId) then
                        local success = pcall(function()
                            xSound:setTimeStamp(musicId, data.elapsedTime)
                        end)
                        if success then
                            break
                        end
                    end
                    attempts = attempts + 1
                    Wait(500)
                end
            end)
        end

    elseif type == "stop" then
        if xSound:soundExists(musicId) then
            xSound:Destroy(musicId)
        end

    elseif type == "volume" then
        if xSound:soundExists(musicId) then
            xSound:setVolumeMax(musicId, data.volume / 100)
        end

    elseif type == "position" then
        if xSound:soundExists(musicId) then
            xSound:Position(musicId, data.position)
        end

    elseif type == "pause" then
        if xSound:soundExists(musicId) then
            xSound:Pause(musicId)
        end

    elseif type == "resume" then
        if xSound:soundExists(musicId) then
            xSound:Resume(musicId)
        end
    end
end)

RegisterNetEvent("phone:melora:syncPlay", function(musicId, syncData)
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local distance = #(myCoords - vector3(syncData.position.x, syncData.position.y, syncData.position.z))

    if distance > Config.MUSIC_RANGE then
        return
    end

    if xSound:soundExists(musicId) then
        xSound:Destroy(musicId)
    end

    xSound:PlayUrlPos(musicId, syncData.link, 1.0, syncData.position)
    xSound:setSoundDynamic(musicId, true)
    xSound:Distance(musicId, Config.XSOUND_DISTANCE)
    xSound:destroyOnFinish(musicId, true)

    local vol = syncData.volume or Config.DEFAULT_VOLUME
    xSound:setVolumeMax(musicId, vol / 100)

    CreateThread(function()
        Wait(1500)
        local attempts = 0
        while attempts < 3 do
            if xSound:soundExists(musicId) then
                local success = pcall(function()
                    xSound:setTimeStamp(musicId, syncData.elapsedTime)
                end)
                if success then
                    if syncData.isPaused then
                        xSound:Pause(musicId)
                    end
                    break
                end
            end
            attempts = attempts + 1
            Wait(500)
        end
    end)
end)

-- Sync with nearby players
local syncAttempts = {}

CreateThread(function()
    while true do
        Wait(5000)

        local myPed = PlayerPedId()
        local myCoords = GetEntityCoords(myPed)

        local players = GetActivePlayers()
        for _, player in ipairs(players) do
            if player ~= PlayerId() then
                local ped = GetPlayerPed(player)
                local coords = GetEntityCoords(ped)
                local distance = #(myCoords - coords)

                if distance <= Config.MUSIC_RANGE then
                    local serverId = GetPlayerServerId(player)
                    if serverId then
                        local musicId = "phone_meloraemusic_id_" .. serverId

                        if not xSound:soundExists(musicId) then
                            syncAttempts[serverId] = syncAttempts[serverId] or 0

                            if syncAttempts[serverId] < 3 then
                                TriggerServerEvent("phone:melora:requestSync", serverId)
                                syncAttempts[serverId] = syncAttempts[serverId] + 1
                            end
                        else
                            syncAttempts[serverId] = 0
                        end
                    end
                else
                    local serverId = GetPlayerServerId(player)
                    if serverId then
                        syncAttempts[serverId] = nil
                    end
                end
            end
        end

        for serverId in pairs(syncAttempts) do
            if serverId then
                local found = false
                for _, player in ipairs(players) do
                    if GetPlayerServerId(player) == serverId then
                        found = true
                        break
                    end
                end
                if not found then
                    syncAttempts[serverId] = nil
                end
            end
        end
    end
end)

-- Auto-play next song when current ends
CreateThread(function()
    while true do
        Wait(1000)
        if playing and currentPlaylistIndex > 0 and not isPaused then
            local musicId = "phone_meloraemusic_id_" .. GetPlayerServerId(PlayerId())

            if not xSound:soundExists(musicId) then
                if currentPlaylistIndex < #playlist then
                    currentPlaylistIndex = currentPlaylistIndex + 1
                    local song = playlist[currentPlaylistIndex]
                    if song then
                        Wait(500)
                        local coords = GetEntityCoords(PlayerPedId())
                        meloraUrl = song.url

                        TriggerServerEvent("phone:melora:soundStatus", "play", {
                            position = coords,
                            link = meloraUrl,
                            volume = volume
                        })

                        Core.SendNuiMessage("songChanged", {
                            url = song.url,
                            index = currentPlaylistIndex
                        })
                    end
                else
                    playing = false
                    currentPlaylistIndex = 0
                    Core.SendNuiMessage("playlistEnded", {})
                end
            end
        end
    end
end)
