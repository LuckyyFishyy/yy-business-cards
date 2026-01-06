local Config = Config or {}

local printers = {}
local printersLoaded = false
local loadPrinters
local backEnabled = not (Config.CardSides and Config.CardSides.EnableBack == false)

local function notify(src, message, nType)
    TriggerClientEvent('yy-bcards:client:Notify', src, message, nType)
end

local function sanitizeUrl(url)
    url = tostring(url or ''):gsub('%s+', '')
    if url == '' then return nil end
    if Config.ImageRules and Config.ImageRules.RequireHttps and not url:match('^https://') then
        return nil
    end
    return url
end

local function hostAllowed(url)
    local rules = Config.ImageRules or {}
    if not rules.RestrictHosts then return true end
    local host = url:match('^https?://([^/]+)') or ''
    host = host:lower()
    for _, allowed in ipairs(rules.AllowedHosts or {}) do
        if host == tostring(allowed):lower() then
            return true
        end
    end
    return false
end

local function sanitizePhotoState(state)
    if type(state) ~= 'table' then return nil end
    local scale = tonumber(state.scale)
    local offsetX = tonumber(state.offsetX)
    local offsetY = tonumber(state.offsetY)
    local offsetXRatio = tonumber(state.offsetXRatio)
    local offsetYRatio = tonumber(state.offsetYRatio)
    if not scale then
        return nil
    end
    if scale < 0.2 then scale = 0.2 end
    if scale > 5.0 then scale = 5.0 end
    if offsetX then
        if offsetX < -5000 then offsetX = -5000 end
        if offsetX > 5000 then offsetX = 5000 end
    end
    if offsetY then
        if offsetY < -5000 then offsetY = -5000 end
        if offsetY > 5000 then offsetY = 5000 end
    end
    if offsetXRatio then
        if offsetXRatio < -5.0 then offsetXRatio = -5.0 end
        if offsetXRatio > 5.0 then offsetXRatio = 5.0 end
    end
    if offsetYRatio then
        if offsetYRatio < -5.0 then offsetYRatio = -5.0 end
        if offsetYRatio > 5.0 then offsetYRatio = 5.0 end
    end
    return {
        scale = scale,
        offsetX = offsetX,
        offsetY = offsetY,
        offsetXRatio = offsetXRatio,
        offsetYRatio = offsetYRatio
    }
end

local function buildPrinters(rows)
    local result = {}
    for _, row in ipairs(rows or {}) do
        local coords = json.decode(row.coords)
        local heading = tonumber(row.heading) or 0.0
        local photoState = nil
        local backPhotoState = nil
        if row.photo_state then
            local ok, decoded = pcall(json.decode, row.photo_state)
            if ok and type(decoded) == 'table' then
                photoState = decoded
            end
        end
        if row.back_photo_state then
            local ok, decoded = pcall(json.decode, row.back_photo_state)
            if ok and type(decoded) == 'table' then
                backPhotoState = decoded
            end
        end
        if coords and coords.h then
            local coordHeading = tonumber(coords.h)
            if coordHeading then
                heading = coordHeading
            end
        end
        result[row.id] = {
            owner = row.owner,
            coords = coords,
            heading = heading,
            imageUrl = row.image_url,
            photoState = photoState,
            backImageUrl = row.back_image_url,
            backPhotoState = backPhotoState
        }
    end
    return result
end

loadPrinters = function(targetSrc)
    MySQL.query('SELECT * FROM business_printers', {}, function(rows)
        printers = buildPrinters(rows)
        printersLoaded = true
        if targetSrc then
            TriggerClientEvent('yy-bcards:client:SyncPrinters', targetSrc, printers)
        else
            TriggerClientEvent('yy-bcards:client:SyncPrinters', -1, printers)
        end
    end)
end

local function initializeDatabase()
    MySQL.execute([[
        CREATE TABLE IF NOT EXISTS business_printers (
            id VARCHAR(64) PRIMARY KEY,
            owner VARCHAR(50) NOT NULL,
            coords JSON NOT NULL,
            heading FLOAT NOT NULL DEFAULT 0,
            image_url TEXT NULL,
            back_image_url TEXT NULL,
            photo_state TEXT NULL,
            back_photo_state TEXT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]], {}, function()
        MySQL.execute('ALTER TABLE business_printers ADD COLUMN IF NOT EXISTS photo_state TEXT NULL', {}, function() end)
        MySQL.execute('ALTER TABLE business_printers ADD COLUMN IF NOT EXISTS back_image_url TEXT NULL', {}, function() end)
        MySQL.execute('ALTER TABLE business_printers ADD COLUMN IF NOT EXISTS back_photo_state TEXT NULL', {}, function()
            if loadPrinters then
                loadPrinters()
            end
        end)
        return
    end)
end

local function waitForMySQL()
    CreateThread(function()
        while GetResourceState('oxmysql') ~= 'started' do
            Wait(250)
        end
        initializeDatabase()
    end)
end

waitForMySQL()

RegisterNetEvent('yy-bcards:server:RequestPrinters', function()
    local src = source
    if not printersLoaded then
        loadPrinters(src)
        return
    end
    TriggerClientEvent('yy-bcards:client:SyncPrinters', src, printers)
end)

AddEventHandler('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    if not printersLoaded then
        loadPrinters(src)
        return
    end
    TriggerClientEvent('yy-bcards:client:SyncPrinters', src, printers)
end)

RegisterNetEvent('yy-bcards:server:PlacePrinter', function(coords, heading)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    if not coords or type(coords) ~= 'table' then return end
    local owner = player.PlayerData.citizenid
    local id = ('printer_%s_%d'):format(owner, os.time())

    local count = exports.ox_inventory:Search(src, 'count', Config.PrinterItem)
    if not count or count < 1 then
        notify(src, 'You need a printer item to place one.', 'error')
        return
    end

    exports.ox_inventory:RemoveItem(src, Config.PrinterItem, 1)

    local safeHeading = tonumber(heading) or 0.0
    local coordsData = coords or {}
    coordsData.h = safeHeading
    printers[id] = {
        owner = owner,
        coords = coordsData,
        heading = safeHeading,
        imageUrl = nil,
        photoState = nil,
        backImageUrl = nil,
        backPhotoState = nil
    }

    MySQL.insert('INSERT INTO business_printers (id, owner, coords, heading, image_url, back_image_url, photo_state, back_photo_state) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        id,
        owner,
        json.encode(coordsData),
        safeHeading,
        nil,
        nil,
        nil,
        nil
    })

    TriggerClientEvent('yy-bcards:client:PrinterPlaced', -1, id, printers[id])
    notify(src, 'Printer placed.', 'success')
end)

RegisterNetEvent('yy-bcards:server:PickupPrinter', function(printerId)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local printer = printers[printerId]
    if not printer then
        notify(src, 'Printer not found.', 'error')
        return
    end

    if printer.owner ~= player.PlayerData.citizenid then
        notify(src, 'This printer belongs to someone else.', 'error')
        return
    end

    printers[printerId] = nil
    MySQL.execute('DELETE FROM business_printers WHERE id = ?', { printerId })

    exports.ox_inventory:AddItem(src, Config.PrinterItem, 1)
    TriggerClientEvent('yy-bcards:client:PrinterRemoved', -1, printerId)
    notify(src, 'Printer picked up.', 'success')
end)

RegisterNetEvent('yy-bcards:server:OpenPrinter', function(printerId)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local printer = printers[printerId]
    if not printer then
        notify(src, 'Printer not found.', 'error')
        return
    end

    if printer.owner ~= player.PlayerData.citizenid then
        notify(src, 'This printer belongs to someone else.', 'error')
        return
    end

    TriggerClientEvent('yy-bcards:client:OpenUI', src, {
        id = printerId,
        imageUrl = printer.imageUrl or '',
        photoState = printer.photoState,
        backImageUrl = backEnabled and (printer.backImageUrl or '') or '',
        backPhotoState = backEnabled and printer.backPhotoState or nil
    })
end)

RegisterNetEvent('yy-bcards:server:SavePhoto', function(printerId, payload, photoState)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    local printer = printers[printerId]
    if not printer then return end
    if printer.owner ~= player.PlayerData.citizenid then
        notify(src, 'This printer belongs to someone else.', 'error')
        return
    end

    local data = payload
    if type(payload) ~= 'table' then
        data = { side = 'front', url = payload, photoState = photoState }
    end

    if not data or not data.url then
        notify(src, 'Invalid image link.', 'error')
        return
    end

    local side = data.side == 'back' and 'back' or 'front'
    if not backEnabled then
        side = 'front'
    end
    local cleanUrl = sanitizeUrl(data.url)
    if not cleanUrl then
        notify(src, 'Invalid image link.', 'error')
        return
    end
    if not hostAllowed(cleanUrl) then
        notify(src, 'Image host not allowed.', 'error')
        return
    end

    local cleanState = sanitizePhotoState(data.photoState)
    if side == 'back' then
        printer.backImageUrl = cleanUrl
        printer.backPhotoState = cleanState
    else
        printer.imageUrl = cleanUrl
        printer.photoState = cleanState
    end

    MySQL.execute('UPDATE business_printers SET image_url = ?, back_image_url = ?, photo_state = ?, back_photo_state = ? WHERE id = ?', {
        printer.imageUrl,
        printer.backImageUrl,
        printer.photoState and json.encode(printer.photoState) or nil,
        printer.backPhotoState and json.encode(printer.backPhotoState) or nil,
        printerId
    })
    TriggerClientEvent('yy-bcards:client:PhotoSaved', src, cleanUrl, side)
    notify(src, 'Photo saved to printer.', 'success')
end)

RegisterNetEvent('yy-bcards:server:PrintCards', function(printerId, amount, photoState)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    local printer = printers[printerId]
    if not printer then return end
    if printer.owner ~= player.PlayerData.citizenid then
        notify(src, 'This printer belongs to someone else.', 'error')
        return
    end

    local imageUrl = printer.imageUrl or ''
    if imageUrl == '' then
        notify(src, 'Add a photo before printing.', 'error')
        return
    end

    local count = tonumber(amount) or 0
    local minAmount = (Config.Printing and Config.Printing.MinAmount) or 1
    local maxAmount = (Config.Printing and Config.Printing.MaxAmount) or 50
    if count < minAmount or count > maxAmount then
        notify(src, ('Print amount must be between %d and %d.'):format(minAmount, maxAmount), 'error')
        return
    end

    local blankCount = exports.ox_inventory:Search(src, 'count', Config.BlankCardItem)
    if not blankCount or blankCount < count then
        notify(src, 'Not enough blank business cards.', 'error')
        return
    end

    local frontState = nil
    local backState = nil
    if type(photoState) == 'table' and (photoState.front or photoState.back) then
        frontState = sanitizePhotoState(photoState.front)
        if backEnabled then
            backState = sanitizePhotoState(photoState.back)
        end
    else
        frontState = sanitizePhotoState(photoState)
    end
    frontState = frontState or printer.photoState
    if backEnabled then
        backState = backState or printer.backPhotoState
    else
        backState = nil
    end

    exports.ox_inventory:RemoveItem(src, Config.BlankCardItem, count)
    local charinfo = player.PlayerData.charinfo or {}
    local label = (charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')
    label = label:gsub('^%s+', ''):gsub('%s+$', '')
    if label == '' then
        label = player.PlayerData.citizenid
    end

    local metadata = {
        photoUrl = imageUrl,
        photoState = frontState,
        owner = label
    }
    if backEnabled and printer.backImageUrl and printer.backImageUrl ~= '' then
        metadata.backUrl = printer.backImageUrl
        metadata.backPhotoState = backState
    end
    exports.ox_inventory:AddItem(src, Config.BusinessCardItem, count, metadata)

    notify(src, ('Printed %d business cards.'):format(count), 'success')
end)
