local isTargeting = false
local hasFocus = false

-- ══════════════════════════════════════════════════════════
--  Registry: store targets by entity model, type, or zone
-- ══════════════════════════════════════════════════════════

local modelTargets = {}
local entityTargets = {}
local zones = {}
local globalPedOptions = {}
local globalVehicleOptions = {}
local globalObjectOptions = {}

-- ══════════════════════════════════════════════════════════
--  Exports: Add/Remove targets
-- ══════════════════════════════════════════════════════════

local function addModel(models, options)
    if type(models) ~= 'table' then models = { models } end
    for _, model in ipairs(models) do
        local hash = type(model) == 'string' and GetHashKey(model) or model
        if not modelTargets[hash] then modelTargets[hash] = {} end
        for _, opt in ipairs(options) do
            table.insert(modelTargets[hash], opt)
        end
    end
end

local function removeModel(models)
    if type(models) ~= 'table' then models = { models } end
    for _, model in ipairs(models) do
        local hash = type(model) == 'string' and GetHashKey(model) or model
        modelTargets[hash] = nil
    end
end

local function addEntity(netIds, options)
    if type(netIds) ~= 'table' then netIds = { netIds } end
    for _, netId in ipairs(netIds) do
        local handle = NetworkGetEntityFromNetworkId(netId)
        if not entityTargets[netId] then
            entityTargets[netId] = { entityHandle = handle, options = {} }
        end
        for _, opt in ipairs(options) do
            table.insert(entityTargets[netId].options, opt)
        end
    end
end

local function removeEntity(netIds)
    if type(netIds) ~= 'table' then netIds = { netIds } end
    for _, netId in ipairs(netIds) do
        entityTargets[netId] = nil
    end
end

local function addGlobalPed(options)
    for _, opt in ipairs(options) do table.insert(globalPedOptions, opt) end
end

local function addGlobalVehicle(options)
    for _, opt in ipairs(options) do table.insert(globalVehicleOptions, opt) end
end

local function addGlobalObject(options)
    for _, opt in ipairs(options) do table.insert(globalObjectOptions, opt) end
end

local function addZone(name, data)
    zones[name] = {
        coords = data.coords,
        radius = data.radius or Config.DefaultZoneDistance,
        options = data.options or {},
        debugColour = data.debugColour,
    }
end

local function removeZone(name)
    zones[name] = nil
end

exports('addModel', addModel)
exports('removeModel', removeModel)
exports('addEntity', addEntity)
exports('removeEntity', removeEntity)
exports('addGlobalPed', addGlobalPed)
exports('addGlobalVehicle', addGlobalVehicle)
exports('addGlobalObject', addGlobalObject)
exports('addZone', addZone)
exports('removeZone', removeZone)

-- ══════════════════════════════════════════════════════════
--  Event-based registration (for C# / JS interop)
-- ══════════════════════════════════════════════════════════

RegisterNetEvent('rezz-interaction:addModel')
AddEventHandler('rezz-interaction:addModel', function(models, options) addModel(models, options) end)

RegisterNetEvent('rezz-interaction:removeModel')
AddEventHandler('rezz-interaction:removeModel', function(models) removeModel(models) end)

RegisterNetEvent('rezz-interaction:addEntity')
AddEventHandler('rezz-interaction:addEntity', function(entities, options) addEntity(entities, options) end)

RegisterNetEvent('rezz-interaction:removeEntity')
AddEventHandler('rezz-interaction:removeEntity', function(entities) removeEntity(entities) end)

RegisterNetEvent('rezz-interaction:addGlobalPed')
AddEventHandler('rezz-interaction:addGlobalPed', function(options) addGlobalPed(options) end)

RegisterNetEvent('rezz-interaction:addGlobalVehicle')
AddEventHandler('rezz-interaction:addGlobalVehicle', function(options) addGlobalVehicle(options) end)

RegisterNetEvent('rezz-interaction:addGlobalObject')
AddEventHandler('rezz-interaction:addGlobalObject', function(options) addGlobalObject(options) end)

RegisterNetEvent('rezz-interaction:addZone')
AddEventHandler('rezz-interaction:addZone', function(name, data) addZone(name, data) end)

RegisterNetEvent('rezz-interaction:removeZone')
AddEventHandler('rezz-interaction:removeZone', function(name) removeZone(name) end)

-- ══════════════════════════════════════════════════════════
--  Get options for an entity
-- ══════════════════════════════════════════════════════════

local function getEntityOptions(entity)
    local options = {}

    local netId = 0
    if NetworkGetEntityIsNetworked(entity) then
        netId = NetworkGetNetworkIdFromEntity(entity)
    end

    if netId ~= 0 and entityTargets[netId] then
        local entry = entityTargets[netId]
        if entry.entityHandle == entity then
            for _, opt in ipairs(entry.options) do
                table.insert(options, opt)
            end
        else
            -- Entity was deleted and netId recycled, clean up stale entry
            entityTargets[netId] = nil
        end
    end

    local model = GetEntityModel(entity)
    if modelTargets[model] then
        for _, opt in ipairs(modelTargets[model]) do
            table.insert(options, opt)
        end
    end

    local entType = GetEntityType(entity)
    if entType == 1 and #globalPedOptions > 0 then
        for _, opt in ipairs(globalPedOptions) do table.insert(options, opt) end
    elseif entType == 2 and #globalVehicleOptions > 0 then
        for _, opt in ipairs(globalVehicleOptions) do table.insert(options, opt) end
    elseif entType == 3 and #globalObjectOptions > 0 then
        for _, opt in ipairs(globalObjectOptions) do table.insert(options, opt) end
    end

    local filtered = {}
    for _, opt in ipairs(options) do
        if not opt.canInteract or opt.canInteract(entity) then
            table.insert(filtered, opt)
        end
    end

    return filtered
end

-- ══════════════════════════════════════════════════════════
--  Scan nearby entities & zones (discovery only, no screen projection)
-- ══════════════════════════════════════════════════════════

local activeTargets = {}  -- populated by slow scan, read by fast position loop

local function scanNearbyTargets()
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local targets = {}

    local function tryAddEntity(entity, zOffset)
        if not DoesEntityExist(entity) then return end
        if entity == ped then return end

        local entCoords = GetEntityCoords(entity)
        local dist = #(playerCoords - entCoords)
        if dist > Config.MaxDistance then return end

        local options = getEntityOptions(entity)
        if #options == 0 then return end

        table.insert(targets, {
            id = 'ent_' .. entity,
            entity = entity,
            zOffset = zOffset,
            dist = dist,
            options = options,
        })
    end

    -- Scan nearby peds
    local pedHandle, pedId = FindFirstPed()
    if pedHandle ~= -1 then
        tryAddEntity(pedId, 1.0)
        local found = true
        while found do
            found, pedId = FindNextPed(pedHandle)
            if found then
                tryAddEntity(pedId, 1.0)
            end
        end
        EndFindPed(pedHandle)
    end

    -- Scan nearby vehicles
    local vehHandle, vehId = FindFirstVehicle()
    if vehHandle ~= -1 then
        tryAddEntity(vehId, 0.5)
        local found = true
        while found do
            found, vehId = FindNextVehicle(vehHandle)
            if found then
                tryAddEntity(vehId, 0.5)
            end
        end
        EndFindVehicle(vehHandle)
    end

    -- Scan nearby objects
    local objHandle, objId = FindFirstObject()
    if objHandle ~= -1 then
        tryAddEntity(objId, 0.5)
        local found = true
        while found do
            found, objId = FindNextObject(objHandle)
            if found then
                tryAddEntity(objId, 0.5)
            end
        end
        EndFindObject(objHandle)
    end

    -- Scan zones
    for name, zone in pairs(zones) do
        local dist = #(playerCoords - zone.coords)
        if dist <= zone.radius then
            local zoneOpts = {}
            for _, opt in ipairs(zone.options) do
                if not opt.canInteract or opt.canInteract() then
                    table.insert(zoneOpts, opt)
                end
            end

            if #zoneOpts > 0 then
                table.insert(targets, {
                    id = 'zone_' .. name,
                    entity = 0,
                    zoneName = name,
                    zoneCoords = zone.coords,
                    zOffset = 0.5,
                    dist = dist,
                    options = zoneOpts,
                })
            end
        end
    end

    return targets
end

-- Build serializable target data for NUI (with current screen positions)
local function buildNuiTargets(targets)
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local nuiTargets = {}

    for _, t in ipairs(targets) do
        -- Get fresh world position
        local wx, wy, wz
        if t.entity ~= 0 and DoesEntityExist(t.entity) then
            local coords = GetEntityCoords(t.entity)
            wx, wy, wz = coords.x, coords.y, coords.z + t.zOffset
        elseif t.zoneCoords then
            wx, wy, wz = t.zoneCoords.x, t.zoneCoords.y, t.zoneCoords.z + t.zOffset
        end

        if wx then
            local onScreen, sx, sy = GetScreenCoordFromWorldCoord(wx, wy, wz)
            if onScreen then
                local dist = #(playerCoords - vector3(wx, wy, wz - t.zOffset))

                local nuiOptions = {}
                for i, opt in ipairs(t.options) do
                    table.insert(nuiOptions, {
                        label = opt.label or 'Interact',
                        icon = opt.icon or 'fas fa-hand-pointer',
                        description = opt.description or '',
                        event = opt.event or '',
                        data = opt.data or {},
                        index = i,
                    })
                end

                table.insert(nuiTargets, {
                    id = t.id,
                    screenX = sx,
                    screenY = sy,
                    dist = dist,
                    options = nuiOptions,
                })
            end
        end
    end

    return nuiTargets
end

-- Track entity handles per target ID for NUI callbacks
local activeTargetEntities = {}

-- ══════════════════════════════════════════════════════════
--  Enable / Disable targeting mode
-- ══════════════════════════════════════════════════════════

local function enableTargeting()
    if isTargeting then return end
    isTargeting = true

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    SetCursorLocation(0.5, 0.5)
    hasFocus = true

    SendNUIMessage({ action = 'show' })

    -- Scan thread: discover entities/zones and update positions
    CreateThread(function()
        while isTargeting do
            local targets = scanNearbyTargets()
            activeTargets = targets

            activeTargetEntities = {}
            for _, t in ipairs(targets) do
                activeTargetEntities[t.id] = t.entity
            end

            local nuiTargets = buildNuiTargets(targets)
            SendNUIMessage({ action = 'updateTargets', targets = nuiTargets })

            Wait(50)
        end
    end)
end

local function disableTargeting()
    if not isTargeting then return end
    isTargeting = false
    activeTargets = {}
    activeTargetEntities = {}

    SendNUIMessage({ action = 'hide' })

    if hasFocus then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        hasFocus = false
    end
end

-- ══════════════════════════════════════════════════════════
--  NUI Callbacks
-- ══════════════════════════════════════════════════════════

RegisterNUICallback('optionSelected', function(data, cb)
    local targetId = data.targetId
    local entity = activeTargetEntities[targetId] or 0

    local event = data.event
    if event and event ~= '' then
        local netId = 0
        if entity ~= 0 and DoesEntityExist(entity) and NetworkGetEntityIsNetworked(entity) then
            netId = NetworkGetNetworkIdFromEntity(entity)
        end

        TriggerEvent(event, {
            entity = entity,
            netId = netId,
            data = data.data or {},
        })
    end

    disableTargeting()
    cb('ok')
end)

RegisterNUICallback('close', function(_, cb)
    disableTargeting()
    cb('ok')
end)

-- ══════════════════════════════════════════════════════════
--  Main input thread
-- ══════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(0)

        if IsControlPressed(0, Config.TargetKey) then
            if not isTargeting then
                enableTargeting()
            end
        else
            if isTargeting then
                disableTargeting()
            end
        end

        if isTargeting then
            -- Disable weapon/camera controls while targeting
            DisableControlAction(0, 24, true)   -- INPUT_ATTACK
            DisableControlAction(0, 25, true)   -- INPUT_AIM
            DisableControlAction(0, 257, true)  -- INPUT_ATTACK2
        end
    end
end)

-- ══════════════════════════════════════════════════════════
--  Background cleanup: prune stale entity targets
-- ══════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(5000)
        for netId, entry in pairs(entityTargets) do
            local handle = NetworkGetEntityFromNetworkId(netId)
            if handle == 0 or not DoesEntityExist(handle) or handle ~= entry.entityHandle then
                entityTargets[netId] = nil
            end
        end
    end
end)

-- ══════════════════════════════════════════════════════════
--  Cleanup on resource stop
-- ══════════════════════════════════════════════════════════

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        disableTargeting()
    end
end)