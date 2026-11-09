local spawned, blips, shops = {}, {}, {}
local textVisible = false

local function clearWorldEntities()
    for _, ped in pairs(spawned) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    for _, blip in pairs(blips) do RemoveBlip(blip) end
    spawned, blips = {}, {}
end

local function loadModel(model)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return false end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(50) end
    return HasModelLoaded(hash), hash
end

local function rebuild(data)
    shops = data or {}
    clearWorldEntities()
    for id, shop in pairs(shops) do
        local c = shop.coords
        if c and shop.npc then
            local ok, hash = loadModel(shop.npcModel)
            if ok then
                local ped = CreatePed(4, hash, c.x, c.y, c.z - 1.0, shop.heading or 0.0, false, true)
                SetEntityInvincible(ped, true)
                FreezeEntityPosition(ped, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                spawned[id] = ped
                SetModelAsNoLongerNeeded(hash)
            end
        end
        if c and shop.blip then
            local b = AddBlipForCoord(c.x, c.y, c.z)
            SetBlipSprite(b, shop.blipSprite or 52)
            SetBlipColour(b, shop.blipColour or 2)
            SetBlipScale(b, shop.blipScale or 0.75)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(shop.name or 'Shop')
            EndTextCommandSetBlipName(b)
            blips[id] = b
        end
    end
end

RegisterNetEvent('ed_shopcreator:shops', function(data)
    rebuild(data)
    SendNUIMessage({ action = 'shops', shops = data })
end)
RegisterNetEvent('ed_shopcreator:notify', function(message, kind)
    lib.notify({ description = message, type = kind or 'inform' })
end)
CreateThread(function()
    Wait(1500)
    TriggerServerEvent('ed_shopcreator:requestShops')
end)

local function isOpen(hours)
    if not hours or not hours.enabled then return true end
    local hour = GetClockHours()
    local open, close = tonumber(hours.open) or 0, tonumber(hours.close) or 24
    if open == close then return false end
    if open < close then return hour >= open and hour < close end
    return hour >= open or hour < close
end

CreateThread(function()
    while true do
        local wait, nearby = 1000, false
        local pos = GetEntityCoords(PlayerPedId())
        for _, shop in pairs(shops) do
            if shop.coords then
                local distance = #(pos - vec3(shop.coords.x, shop.coords.y, shop.coords.z))
                if distance < Config.InteractionDistance then
                    nearby, wait = true, 0
                    if isOpen(shop.hours) then
                        if not textVisible then
                            lib.showTextUI(('[E] %s'):format(shop.name))
                            textVisible = true
                        end
                        if IsControlJustReleased(0, 38) then
                            exports.ox_inventory:openInventory('shop', { type = shop.id })
                        end
                    else
                        if not textVisible then
                            lib.showTextUI(('Closed: %02d:00–%02d:00'):format(shop.hours.open, shop.hours.close))
                            textVisible = true
                        end
                    end
                    break
                end
            end
        end
        if not nearby and textVisible then
            lib.hideTextUI()
            textVisible = false
        end
        Wait(wait)
    end
end)

RegisterCommand(Config.Command, function()
    lib.callback('ed_shopcreator:admin', false, function(authorized)
        if authorized then
            SetNuiFocus(true, true)
            SendNUIMessage({ action = 'open' })
        else
            lib.notify({ description = 'You are not authorized.', type = 'error' })
        end
    end)
end)
RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    cb({ ok = true })
end)
RegisterNUICallback('save', function(data, cb)
    TriggerServerEvent('ed_shopcreator:saveShop', data)
    cb({ ok = true })
end)
RegisterNUICallback('delete', function(data, cb)
    TriggerServerEvent('ed_shopcreator:deleteShop', data.id)
    cb({ ok = true })
end)
RegisterNUICallback('stats', function(data, cb)
    lib.callback('ed_shopcreator:getStats', false, data.id, function(result)
        cb(result or {})
    end)
end)
RegisterNUICallback('position', function(_, cb)
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    cb({ x = c.x, y = c.y, z = c.z, heading = GetEntityHeading(ped) })
end)
RegisterNUICallback('shops', function(_, cb)
    cb(shops)
end)
RegisterNUICallback('focus', function(_, cb)
    SetNuiFocus(true, true)
    cb({ ok = true })
end)
RegisterNUICallback('releaseFocus', function(_, cb)
    SetNuiFocus(false, false)
    cb({ ok = true })
end)
RegisterNUICallback('noop', function(_, cb) cb({ ok = true }) end)
RegisterKeyMapping('shopcreator_close', 'Close shop creator', 'keyboard', 'ESCAPE')
RegisterCommand('shopcreator_close', function()
    if IsNuiFocused() then
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'close' })
    end
end)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        clearWorldEntities()
        if textVisible then lib.hideTextUI() end
        SetNuiFocus(false, false)
    end
end)
