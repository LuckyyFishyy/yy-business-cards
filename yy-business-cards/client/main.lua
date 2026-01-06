local Config = Config or {}

local printers = {}
local printerEntities = {}
local placing = false
local previewPrinter = nil
local currentPrinterId = nil
local nuiOpen = false
local cardTimer = nil
local lastHitCoords = nil
local lastPlaceCoords = nil
local lastPlaceHeading = nil

local function notify(message, nType)
    if lib and lib.notify then
        lib.notify({
            title = 'Business Cards',
            description = message or '',
            type = nType or 'inform'
        })
    end
end

local function getCitizenId()
    if exports.qbx_core and exports.qbx_core.GetPlayerData then
        local data = exports.qbx_core:GetPlayerData()
        if data and data.citizenid then
            return data.citizenid
        end
    end
    return nil
end

local function loadModel(model)
    if not model then return false end
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        Wait(10)
    end
    return HasModelLoaded(hash)
end

local function rotationToDirection(rot)
    local rotZ = math.rad(rot.z)
    local rotX = math.rad(rot.x)
    local cosX = math.cos(rotX)
    return vector3(-math.sin(rotZ) * cosX, math.cos(rotZ) * cosX, math.sin(rotX))
end

local function raycastFromCamera(maxDistance, ignore)
    local camCoord = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local direction = rotationToDirection(camRot)
    local dest = vector3(
        camCoord.x + direction.x * maxDistance,
        camCoord.y + direction.y * maxDistance,
        camCoord.z + direction.z * maxDistance
    )
    local ray = StartShapeTestRay(camCoord.x, camCoord.y, camCoord.z, dest.x, dest.y, dest.z, -1, ignore or PlayerPedId(), 0)
    local _, hit, endCoords = GetShapeTestResult(ray)
    if hit == 1 then
        return true, endCoords
    end
    return false, dest
end

local function getCameraRight()
    local camRot = GetGameplayCamRot(2)
    local z = math.rad(camRot.z)
    return vector3(math.cos(z), math.sin(z), 0.0)
end

local function openUI(printerId, imageUrl, photoState)
    if nuiOpen then return end
    currentPrinterId = printerId
    nuiOpen = true
    SendNUIMessage({
        action = 'open',
        printerId = printerId,
        imageUrl = imageUrl or '',
        photoState = photoState,
        maxAmount = (Config.Printing and Config.Printing.MaxAmount) or 50
    })
    SetNuiFocus(true, true)
end

local function closeUI()
    if not nuiOpen then return end
    nuiOpen = false
    currentPrinterId = nil
    SendNUIMessage({ action = 'close' })
    SetNuiFocus(false, false)
end

local function spawnPrinter(id, data)
    if printerEntities[id] and DoesEntityExist(printerEntities[id]) then return end
    local model = Config.PrinterModel
    if not loadModel(model) then return end
    local minDim, _ = GetModelDimensions(joaat(model))
    local zOffset = -minDim.z + ((Config.Placement and Config.Placement.ZOffset) or 0.0)
    local coords = data.coords
    local heading = tonumber(data.heading) or 0.0
    local obj = CreateObject(joaat(model), coords.x, coords.y, coords.z, false, false, false)
    SetEntityCoordsNoOffset(obj, coords.x, coords.y, coords.z + zOffset, false, false, false)
    SetEntityHeading(obj, heading)
    SetEntityRotation(obj, 0.0, 0.0, heading, 2, true)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, true, true)
    printerEntities[id] = obj

    if exports.ox_target then
        exports.ox_target:addLocalEntity(obj, {
            {
                name = ('bc_printer_%s'):format(id),
                icon = 'fa-solid fa-id-card',
                label = 'Printer',
                canInteract = function()
                    return data.owner == getCitizenId()
                end,
                onSelect = function()
                    TriggerServerEvent('yy-bcards:server:OpenPrinter', id)
                end
            },
            {
                name = ('bc_printer_pickup_%s'):format(id),
                icon = 'fa-solid fa-hand',
                label = 'Pick Up Printer',
                canInteract = function()
                    return data.owner == getCitizenId()
                end,
                onSelect = function()
                    TriggerServerEvent('yy-bcards:server:PickupPrinter', id)
                end
            }
        })
    end
end

local function clearPreview()
    if previewPrinter and DoesEntityExist(previewPrinter) then
        DeleteEntity(previewPrinter)
    end
    previewPrinter = nil
end

local function startPlacement()
    if placing then return end
    placing = true
    clearPreview()

    local model = Config.PrinterModel
    if not loadModel(model) then
        placing = false
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    previewPrinter = CreateObject(joaat(model), coords.x, coords.y, coords.z, false, false, false)
    if not previewPrinter or previewPrinter == 0 then
        placing = false
        return
    end

    SetEntityAlpha(previewPrinter, 200, false)
    FreezeEntityPosition(previewPrinter, true)
    SetEntityCollision(previewPrinter, false, false)
    SendNUIMessage({ action = 'showPlacementHelp' })

    local rotation = { x = 0.0, y = 0.0, z = GetEntityHeading(previewPrinter) }
    local minDim, _ = GetModelDimensions(joaat(model))
    local zOffset = -minDim.z + ((Config.Placement and Config.Placement.ZOffset) or 0.0)
    local rightOffset = (Config.Placement and Config.Placement.RightOffset) or 0.0
    lastPlaceHeading = rotation.z

    CreateThread(function()
        while placing do
            local maxDistance = (Config.Placement and Config.Placement.MaxDistance) or 6.0
            local _, hitCoords = raycastFromCamera(maxDistance, previewPrinter)
            lastHitCoords = hitCoords
            local rightVec = getCameraRight()
            local placeX = hitCoords.x + (rightVec.x * rightOffset)
            local placeY = hitCoords.y + (rightVec.y * rightOffset)
            SetEntityCoordsNoOffset(previewPrinter, placeX, placeY, hitCoords.z + zOffset, false, false, false)
            SetEntityRotation(previewPrinter, rotation.x, rotation.y, rotation.z, 2, true)
            lastPlaceCoords = { x = placeX, y = placeY, z = hitCoords.z }
            lastPlaceHeading = rotation.z

            local leftKey = (Config.Placement and Config.Placement.RotateLeftKey) or 174
            local rightKey = (Config.Placement and Config.Placement.RotateRightKey) or 175
            local step = (Config.Placement and Config.Placement.RotationStep) or 1.5

            if IsControlPressed(0, leftKey) then
                rotation.z = rotation.z - step
                SetEntityRotation(previewPrinter, rotation.x, rotation.y, rotation.z, 2, true)
            elseif IsControlPressed(0, rightKey) then
                rotation.z = rotation.z + step
                SetEntityRotation(previewPrinter, rotation.x, rotation.y, rotation.z, 2, true)
            end

            local confirmKey = (Config.Placement and Config.Placement.ConfirmKey) or 191
            local cancelKey = (Config.Placement and Config.Placement.CancelKey) or 194

            if IsControlJustPressed(0, confirmKey) then
                local placeCoords = lastPlaceCoords or lastHitCoords or GetEntityCoords(previewPrinter)
                local heading = lastPlaceHeading or GetEntityHeading(previewPrinter)
                TriggerServerEvent('yy-bcards:server:PlacePrinter', {
                    x = placeCoords.x,
                    y = placeCoords.y,
                    z = placeCoords.z
                }, heading)
                placing = false
                lastHitCoords = nil
                lastPlaceCoords = nil
                lastPlaceHeading = nil
                clearPreview()
                SendNUIMessage({ action = 'hidePlacementHelp' })
            elseif IsControlJustPressed(0, cancelKey) then
                placing = false
                lastHitCoords = nil
                lastPlaceCoords = nil
                lastPlaceHeading = nil
                clearPreview()
                SendNUIMessage({ action = 'hidePlacementHelp' })
            end

            Wait(0)
        end
    end)
end

RegisterNetEvent('yy-bcards:client:SyncPrinters', function(serverPrinters)
    printers = serverPrinters or {}
    for id, data in pairs(printers) do
        spawnPrinter(id, data)
    end
end)

RegisterNetEvent('yy-bcards:client:PrinterPlaced', function(id, data)
    printers[id] = data
    spawnPrinter(id, data)
end)

RegisterNetEvent('yy-bcards:client:PrinterRemoved', function(id)
    printers[id] = nil
    local entity = printerEntities[id]
    if entity and DoesEntityExist(entity) then
        if exports.ox_target and exports.ox_target.removeLocalEntity then
            exports.ox_target:removeLocalEntity(entity)
        end
        DeleteEntity(entity)
    end
    printerEntities[id] = nil
end)

RegisterNetEvent('yy-bcards:client:OpenUI', function(data)
    if not data then return end
    openUI(data.id, data.imageUrl, data.photoState)
end)

RegisterNetEvent('yy-bcards:client:PhotoSaved', function(url)
    SendNUIMessage({ action = 'photoSaved', imageUrl = url })
end)

RegisterNetEvent('yy-bcards:client:Notify', function(message, nType)
    notify(message, nType)
end)

RegisterNUICallback('bc_close', function(_, cb)
    closeUI()
    cb({})
end)

RegisterNUICallback('bc_save_photo', function(data, cb)
    if currentPrinterId and data and data.url then
        TriggerServerEvent('yy-bcards:server:SavePhoto', currentPrinterId, data.url, data.photoState)
    end
    cb({})
end)

RegisterNUICallback('bc_print_cards', function(data, cb)
    if currentPrinterId then
        TriggerServerEvent('yy-bcards:server:PrintCards', currentPrinterId, data.amount, data.photoState)
    end
    cb({})
end)

exports('usePrinter', function()
    startPlacement()
    return true
end)

exports('useBusinessCard', function(item, slot)
    local meta = (slot and slot.metadata) or (item and (item.metadata or item.meta)) or {}
    local url = meta.photoUrl or meta.imageurl or meta.imageUrl or meta.image or meta.url or ''
    if url ~= '' and not url:match('^https?://') then
        url = ''
    end
    if url == '' then
        notify('This card has no photo.', 'error')
        return false
    end
    if cardTimer then
        ClearTimeout(cardTimer)
        cardTimer = nil
    end
    SendNUIMessage({
        action = 'showCard',
        imageUrl = url,
        photoState = meta.photoState or meta.photo_state,
        width = (Config.CardPreview and Config.CardPreview.Width) or 200,
        height = (Config.CardPreview and Config.CardPreview.Height) or 120
    })
    cardTimer = SetTimeout(4000, function()
        SendNUIMessage({ action = 'hideCard' })
        cardTimer = nil
    end)
    return true
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    TriggerServerEvent('yy-bcards:server:RequestPrinters')
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(1000)
    TriggerServerEvent('yy-bcards:server:RequestPrinters')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    closeUI()
    for id, entity in pairs(printerEntities) do
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
        printerEntities[id] = nil
    end
    clearPreview()
end)
