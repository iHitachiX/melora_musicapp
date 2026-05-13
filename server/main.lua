
-- ─── Hilfsfunktion: Spieler-Identifier holen ────────────────────────────────
-- Nutzt License-ID als stabilen Identifier (kein Framework nötig)
local function getIdentifier(src)
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id and id:find('license:') then
            return id
        end
    end
    -- Fallback: steam oder source-ID
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id and id:find('steam:') then
            return id
        end
    end
    return tostring(src)
end

-- ─── Playlist DB Callbacks ────────────────────────────────────────────────────

CreateThread(function()
    Wait(1000)
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `melora_music_playlist` (
            `id`         INT(11)       NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(100)  NOT NULL,
            `title`      VARCHAR(255)  NOT NULL,
            `url`        TEXT          NOT NULL,
            `thumbnail`  TEXT          NULL DEFAULT NULL,
            `sort_order` INT(11)       NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`) USING BTREE,
            INDEX `identifier` (`identifier`) USING BTREE
        )
    ]])
end)

local function dbGetPlaylist(identifier)
    local rows = MySQL.query.await(
        'SELECT id, title, url, thumbnail FROM `melora_music_playlist` WHERE `identifier` = ? ORDER BY `sort_order` ASC, `id` ASC',
        { identifier }
    )
    local result = {}
    for _, row in ipairs(rows or {}) do
        result[#result+1] = {
            id        = row.id,
            title     = row.title,
            url       = row.url,
            thumbnail = row.thumbnail or '',
        }
    end
    return result
end

lib.callback.register('melora_musicapp:server:getPlaylist', function(source)
    local cid = getIdentifier(source)
    if not cid then return {} end
    return dbGetPlaylist(cid)
end)

lib.callback.register('melora_musicapp:server:addToPlaylist', function(source, data)
    local cid = getIdentifier(source)
    if not cid or not data or not data.url then return nil end
    -- Sort order = aktuell höchster + 1
    local maxOrder = MySQL.scalar.await(
        'SELECT COALESCE(MAX(sort_order), 0) FROM `melora_music_playlist` WHERE `identifier` = ?',
        { cid }
    ) or 0
    MySQL.insert.await(
        'INSERT INTO `melora_music_playlist` (identifier, title, url, thumbnail, sort_order) VALUES (?, ?, ?, ?, ?)',
        { cid, tostring(data.title or 'Song'):sub(1, 255), data.url, data.thumbnail or '', maxOrder + 1 }
    )
    return dbGetPlaylist(cid)
end)

lib.callback.register('melora_musicapp:server:removeFromPlaylist', function(source, index)
    local cid = getIdentifier(source)
    if not cid or not index then return nil end
    -- Index ist 1-basiert, wir holen die sortierte Liste und löschen anhand der ID
    local rows = MySQL.query.await(
        'SELECT id FROM `melora_music_playlist` WHERE `identifier` = ? ORDER BY `sort_order` ASC, `id` ASC',
        { cid }
    )
    if rows and rows[index] then
        MySQL.update.await('DELETE FROM `melora_music_playlist` WHERE `id` = ?', { rows[index].id })
    end
    return dbGetPlaylist(cid)
end)

local activeSounds = {}

local function getPlayersInRange(position, range)
   local players = {}
   local allPlayers = GetPlayers()

   for _, playerId in ipairs(allPlayers) do
       local ped = GetPlayerPed(playerId)
       if ped and ped > 0 then
           local playerCoords = GetEntityCoords(ped)
           local distance = #(playerCoords - vector3(position.x, position.y, position.z))

           if distance <= range then
               table.insert(players, tonumber(playerId))
           end
       end
   end

   return players
end

RegisterNetEvent("phone:melora:soundStatus", function(type, data)
   local src = source
   local musicId = "phone_meloraemusic_id_" .. src

   if not type or not musicId then return end
   if not ({
       position = true, play = true, volume = true, stop = true,
       pause = true, resume = true
   })[type] then
       print("Invalid type for phone:melora:soundStatus: " .. type)
       return
   end

   if type == "play" then
       activeSounds[src] = {
           position = data.position,
           musicId = musicId,
           data = data,
           startTime = os.time(),
           pausedAt = nil,
           totalPausedTime = 0
       }

       data.startTime = os.time()

       local nearbyPlayers = getPlayersInRange(data.position, Config.MUSIC_RANGE)
       for _, playerId in ipairs(nearbyPlayers) do
           TriggerClientEvent("phone:melora:soundStatus", playerId, "play", musicId, data)
       end

   elseif type == "stop" then
       if activeSounds[src] then
           local lastPosition = activeSounds[src].position
           activeSounds[src] = nil

           local nearbyPlayers = getPlayersInRange(lastPosition, Config.MUSIC_RANGE)
           for _, playerId in ipairs(nearbyPlayers) do
               TriggerClientEvent("phone:melora:soundStatus", playerId, "stop", musicId)
           end
       end

   elseif type == "position" then
       if activeSounds[src] then
           activeSounds[src].position = data.position

           local nearbyPlayers = getPlayersInRange(data.position, Config.POSITION_UPDATE_RANGE)
           for _, playerId in ipairs(nearbyPlayers) do
               TriggerClientEvent("phone:melora:soundStatus", playerId, "position", musicId, data)
           end
       end

   elseif type == "volume" then
       if activeSounds[src] then
           if activeSounds[src].data then
               activeSounds[src].data.volume = data.volume
           end

           local nearbyPlayers = getPlayersInRange(activeSounds[src].position, Config.MUSIC_RANGE)
           for _, playerId in ipairs(nearbyPlayers) do
               TriggerClientEvent("phone:melora:soundStatus", playerId, "volume", musicId, data)
           end
       end

   elseif type == "pause" then
       if activeSounds[src] then
           activeSounds[src].pausedAt = os.time()

           local nearbyPlayers = getPlayersInRange(activeSounds[src].position, Config.MUSIC_RANGE)
           for _, playerId in ipairs(nearbyPlayers) do
               TriggerClientEvent("phone:melora:soundStatus", playerId, "pause", musicId, data)
           end
       end

   elseif type == "resume" then
       if activeSounds[src] then
           if activeSounds[src].pausedAt then
               local pauseDuration = os.time() - activeSounds[src].pausedAt
               activeSounds[src].totalPausedTime = activeSounds[src].totalPausedTime + pauseDuration
               activeSounds[src].pausedAt = nil
           end

           local nearbyPlayers = getPlayersInRange(activeSounds[src].position, Config.MUSIC_RANGE)
           for _, playerId in ipairs(nearbyPlayers) do
               TriggerClientEvent("phone:melora:soundStatus", playerId, "resume", musicId, data)
           end
       end
   end
end)

RegisterNetEvent("phone:melora:requestSync", function(targetPlayer)
    local src = source

    if activeSounds[targetPlayer] then
        local soundData = activeSounds[targetPlayer]
        local musicId = "phone_meloraemusic_id_" .. targetPlayer

        local currentTime = os.time()
        local elapsedTime = currentTime - soundData.startTime - soundData.totalPausedTime

        if soundData.pausedAt then
            elapsedTime = soundData.pausedAt - soundData.startTime - soundData.totalPausedTime
        end

        local syncData = {
            position = soundData.position,
            link = soundData.data.link,
            volume = soundData.data.volume,
            startTime = soundData.startTime,
            elapsedTime = elapsedTime,
            isPaused = soundData.pausedAt ~= nil
        }

        TriggerClientEvent("phone:melora:syncPlay", src, musicId, syncData)
    else

        local musicId = "phone_meloraemusic_id_" .. targetPlayer
        TriggerClientEvent("phone:melora:soundStatus", src, "stop", musicId, {})
    end
 end)

AddEventHandler("playerDropped", function()
   local src = source
   local musicId = "phone_meloraemusic_id_" .. src

   if activeSounds[src] then
       local lastPosition = activeSounds[src].position
       local nearbyPlayers = getPlayersInRange(lastPosition, Config.MUSIC_RANGE)

       activeSounds[src] = nil

       for _, playerId in ipairs(nearbyPlayers) do
           TriggerClientEvent("phone:melora:soundStatus", playerId, "stop", musicId)
       end
   end
end)
-- ─── YouPlay API (server-seitig, Key bleibt geheim) ───────────────────────────

local YT_BASE = 'https://www.googleapis.com/youtube/v3'

local function url_encode(str)
    if not str then return '' end
    str = tostring(str)
    str = str:gsub('\n', '\r\n')
    str = str:gsub('([^%w%-%.%_%~ ])', function(c)
        return ('%%%02X'):format(string.byte(c))
    end)
    str = str:gsub(' ', '+')
    return str
end

local function parseDuration(iso)
    if not iso then return 0 end
    local h = iso:match('(%d+)H') or 0
    local m = iso:match('(%d+)M') or 0
    local s = iso:match('(%d+)S') or 0
    return tonumber(h)*3600 + tonumber(m)*60 + tonumber(s)
end

local function extractVideoId(url)
    if not url then return nil end
    return url:match('[?&]v=([%w_%-]+)')
        or url:match('youtu%.be/([%w_%-]+)')
        or url:match('youtube%.com/embed/([%w_%-]+)')
        or url:match('youtube%.com/shorts/([%w_%-]+)')
end

local function extractPlaylistId(url)
    if not url then return nil end
    return url:match('[?&]list=([%w_%-]+)')
end

local function httpGet(url)
    local p = promise.new()
    PerformHttpRequest(url, function(status, body)
        if status == 200 and body then
            local ok, data = pcall(json.decode, body)
            p:resolve(ok and data or nil)
        else
            p:resolve(nil)
        end
    end, 'GET', '', {})
    return Citizen.Await(p)
end

local function getApiKey()
    return Config.YouTube and Config.YouTube.apiKey
end

local function isKeyValid(key)
    return key and key ~= '' and key ~= 'DEIN_YOUTUBE_API_KEY_HIER'
end

-- Suche
lib.callback.register('melora_musicapp:server:ytSearch', function(source, query)
    local key = getApiKey()
    if not isKeyValid(key) then return { error = 'NO_API_KEY' } end
    if not query or query == '' then return { error = 'empty' } end

    local max = Config.YouTube.maxSearchResults or 10
    local searchUrl = ('%s/search?part=snippet&type=video&q=%s&maxResults=%d&key=%s'):format(
        YT_BASE, url_encode(query), max, key)

    local searchData = httpGet(searchUrl)
    if not searchData or not searchData.items or #searchData.items == 0 then return {} end

    local ids = {}
    for _, item in ipairs(searchData.items) do
        if item.id and item.id.videoId then ids[#ids+1] = item.id.videoId end
    end
    if #ids == 0 then return {} end

    local videoUrl = ('%s/videos?part=snippet,contentDetails&id=%s&key=%s'):format(
        YT_BASE, table.concat(ids, ','), key)
    local videoData = httpGet(videoUrl)
    if not videoData or not videoData.items then return {} end

    local results = {}
    for _, item in ipairs(videoData.items) do
        local sn = item.snippet
        local cd = item.contentDetails
        results[#results+1] = {
            title     = sn.title,
            channel   = sn.channelTitle,
            duration  = parseDuration(cd.duration),
            thumbnail = sn.thumbnails and (
                (sn.thumbnails.medium  and sn.thumbnails.medium.url) or
                (sn.thumbnails.default and sn.thumbnails.default.url)
            ) or '',
            url = ('https://www.youtube.com/watch?v=%s'):format(item.id),
        }
    end
    return results
end)

-- Video-Info (Titel + Thumbnail für Auto-Fill)
lib.callback.register('melora_musicapp:server:ytGetVideoInfo', function(source, url)
    local key = getApiKey()
    if not isKeyValid(key) then return nil end
    local videoId = extractVideoId(url)
    if not videoId then return nil end

    local apiUrl = ('%s/videos?part=snippet,contentDetails&id=%s&key=%s'):format(YT_BASE, videoId, key)
    local data = httpGet(apiUrl)
    if not data or not data.items or #data.items == 0 then return nil end

    local item = data.items[1]
    local sn   = item.snippet
    local cd   = item.contentDetails
    return {
        title     = sn.title,
        channel   = sn.channelTitle,
        duration  = parseDuration(cd.duration),
        thumbnail = sn.thumbnails and (
            (sn.thumbnails.medium  and sn.thumbnails.medium.url) or
            (sn.thumbnails.default and sn.thumbnails.default.url)
        ) or '',
        url = ('https://www.youtube.com/watch?v=%s'):format(videoId),
    }
end)

-- Playlist importieren
lib.callback.register('melora_musicapp:server:ytImportPlaylist', function(source, playlistUrl)
    local key = getApiKey()
    if not isKeyValid(key) then return { ok = false, error = 'API Key fehlt in config.lua' } end

    local playlistId = extractPlaylistId(playlistUrl)
    if not playlistId then return { ok = false, error = 'Ungültige Playlist-URL' } end

    local maxImport = Config.YouTube.maxPlaylistImport or 200
    local songs     = {}
    local pageToken = nil

    repeat
        local pageParam = pageToken and ('&pageToken=%s'):format(pageToken) or ''
        local listUrl = ('%s/playlistItems?part=snippet&playlistId=%s&maxResults=50&key=%s%s'):format(
            YT_BASE, url_encode(playlistId), key, pageParam)

        local data = httpGet(listUrl)
        if not data then
            print('[melora_musicapp] YouPlay Playlist API: keine Antwort (Key ungültig oder kein Internet)')
            break
        end
        if data.error then
            print('[melora_musicapp] YouPlay Playlist API Fehler: ' .. tostring(data.error.message or data.error.code or 'unbekannt'))
            return { ok = false, error = 'API Fehler: ' .. tostring(data.error.message or data.error.code) }
        end
        if not data.items then
            print('[melora_musicapp] YouPlay Playlist API: keine Items (Playlist leer oder privat)')
            break
        end

        local ids = {}
        for _, item in ipairs(data.items) do
            local vid = item.snippet and item.snippet.resourceId and item.snippet.resourceId.videoId
            if vid and vid ~= '' then ids[#ids+1] = vid end
        end

        if #ids > 0 then
            local videoUrl = ('%s/videos?part=snippet,contentDetails&id=%s&key=%s'):format(
                YT_BASE, table.concat(ids, ','), key)
            local videoData = httpGet(videoUrl)
            if videoData and videoData.items then
                for _, item in ipairs(videoData.items) do
                    local sn = item.snippet
                    songs[#songs+1] = {
                        title     = sn.title,
                        label     = sn.title,
                        url       = ('https://www.youtube.com/watch?v=%s'):format(item.id),
                        thumbnail = sn.thumbnails and (
                            (sn.thumbnails.medium  and sn.thumbnails.medium.url) or
                            (sn.thumbnails.default and sn.thumbnails.default.url)
                        ) or '',
                    }
                    if #songs >= maxImport then break end
                end
            end
        end

        pageToken = data.nextPageToken
        if #songs >= maxImport then break end
    until not pageToken

    if #songs == 0 then return { ok = false, error = 'Keine Songs gefunden oder Playlist privat' } end

    -- Alle Songs in DB speichern
    local cid = getIdentifier(source)
    if cid then
        local maxOrder = MySQL.scalar.await(
            'SELECT COALESCE(MAX(sort_order), 0) FROM `melora_music_playlist` WHERE `identifier` = ?',
            { cid }
        ) or 0
        for i, song in ipairs(songs) do
            MySQL.insert.await(
                'INSERT INTO `melora_music_playlist` (identifier, title, url, thumbnail, sort_order) VALUES (?, ?, ?, ?, ?)',
                { cid, tostring(song.title or 'Song'):sub(1, 255), song.url, song.thumbnail or '', maxOrder + i }
            )
        end
        local playlist = dbGetPlaylist(cid)
        return { ok = true, count = #songs, playlist = playlist }
    end
    return { ok = true, count = #songs, playlist = songs }
end)
