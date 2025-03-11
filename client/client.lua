local HOSTAGE_STATE = { IDLE = 1, SCARED = 2, SURRENDERED = 3, RELEASED = 4 }
local hostages = {} --- Table to keep track of the hostages
local hostageCount = 0 --- Counter to keep track of the hostages
local pedToHostageMap = {}  --- Map to keep track of the peds and their hostage index
local animDicts = { surrender = "random@arrests@busted", handsUp = "missminuteman_1ig_2" }

-- Preprocess weapon validation once on startup
local validWeapons = {}

--- Check if a weapon is valid
---@param weaponHash table|string|number Weapon table or hash
---@return boolean
local function isValidWeapon(weaponHash)
    if not weaponHash then return false end  --- If the weapon is nil, return false immediately
    local weaponName, hash
    if type(weaponHash) == "table" then
        weaponName, hash = weaponHash.name, weaponHash.hash
    else
        hash = weaponHash
    end
    return validWeapons[weaponName] or validWeapons[hash] or false
end

-- Function to handle hostage taking
local function handleHostageTaking(hostageIndex)
    local hostage = hostages[hostageIndex]
    if not hostage or hostage.state ~= HOSTAGE_STATE.IDLE then return end
    
    local currentWeapon = exports.ox_inventory:getCurrentWeapon()
    if not currentWeapon or not isValidWeapon(currentWeapon) then
        lib.notify({ title = 'Hostage', description = 'The hostage is not scared of you with that weapon', type = 'error' })
        return
    end
    
    hostage.state = HOSTAGE_STATE.SCARED
    hostage.takenBy = GetPlayerServerId(PlayerId())
    
    if not HasAnimDictLoaded(animDicts.handsUp) then
        lib.requestAnimDict(animDicts.handsUp)
    end
    
    TaskHandsUp(hostage.ped, -1, PlayerPedId(), -1, true)
    hostage.releaseTimer = Config.HostageReleaseTime * 60 * 1000
end

-- surrender function
local function handleHostageSurrender(hostageIndex)
    local hostage = hostages[hostageIndex]
    if not hostage or hostage.state ~= HOSTAGE_STATE.SCARED then return end
    
    hostage.state = HOSTAGE_STATE.SURRENDERED
    
    local location = Config.HostageLocations[hostage.locationIndex]
    if not location then return end
    
    -- Make hostage immune to physics and collisions while surrendering and moving to surrender position
    -- This is to prevent the hostage from being pushed around or killed by other players and when he is in the surrender animation even if he is pushed he will not move.
    SetEntityInvincible(hostage.ped, true) --- you can remove this if you would like prd to dies when shot.
    SetBlockingOfNonTemporaryEvents(hostage.ped, true)
    SetPedCanRagdoll(hostage.ped, false)

    -- IMPORTANT: We Dont clear tasks, instead continue with hands up animation while moving to surrender position.
    TaskPlayAnim(hostage.ped, animDicts.handsUp, "handsup_base", 8.0, -8.0, -1, 49, 0, false, false, false)
    SetPedKeepTask(hostage.ped, true)
    --- we get the surrender coords from the config file. Heading will be set later
    local surrenderCoords = vector3(
        location.SurrunderCoords.x, 
        location.SurrunderCoords.y, 
        location.SurrunderCoords.z
    )
    
    --- We can use TaskGoToCoordAnyMeans to make the ped walk to the surrender coords or we can use TaskFollowNavMeshToCoord to make the ped walk to the surrender coords 
    --- Ithink will use TaskFollowNavMeshToCoord because i feel like it will be more accurate and will not get stuck in the walls. (based on what i read on the fivem docs)
    TaskFollowNavMeshToCoord(
        hostage.ped,
        surrenderCoords.x,
        surrenderCoords.y,
        surrenderCoords.z,
        1.0, -- Speed
        -1, -- Timeout (-1 means infinite)
        0.25, -- Stopping range
        49152, -- Flags (Walk + scared flags) How i know this? i read the fivem docs. (Read bellow) idk if this is the best flag to use but it works for what we need. MAYBE?
        0.0 -- Heading adjustment (0.0 means no adjustment needed i guess because we will set the heading later) how ever we can use location.SurrunderCoords.w to set the heading here. 
    )

    --- how i did the Flags ?
    --- // Prevents the path-search from finding paths outside of this search distance.
    --- // This can be used to prevent peds from finding long undesired routes.
    --- ENAV_ADVANCED_USE_CLAMP_MAX_SEARCH_DISTANCE = 16384,
    --- // Pulls out the paths from edges at corners for a longer distance, to prevent peds walking into stuff.
    --- ENAV_PULL_FROM_EDGE_EXTRA = 32768
    --- This are the 2 flags i got from the docs and i just added them together to get the flag i used. https://docs.fivem.net/natives/?_0x15D3A79D4E44B913
    
    --- in case you want to use TaskGoToCoordAnyMeans here is the code for it. thanks to chatGPT for making the TaskGoToCoordAnyMeans Version For me. 
    --[[ TaskGoToCoordAnyMeans(
        hostage.ped,
        surrenderCoords.x, 
        surrenderCoords.y, 
        surrenderCoords.z,
        1.0,         -- Speed
        0,           -- No specific flags
        false,       -- Don't use pathfinding
        49152,      -- Flags
        0.0          -- No extra Z offset
    ) ]]
    
    -- Set check for arrival
    hostage.nextCheck = GetGameTimer() + 1000
    hostage.pathTo = surrenderCoords
    hostage.targetHeading = location.SurrunderCoords.w
end

-- Functio to Release hostage
local function handleHostageRelease(hostageIndex)
    local hostage = hostages[hostageIndex]
    if not hostage or (hostage.state ~= HOSTAGE_STATE.SCARED and hostage.state ~= HOSTAGE_STATE.SURRENDERED) then return end
    
    hostage.state = HOSTAGE_STATE.RELEASED
    hostage.nextCheck = nil
    hostage.releaseTimer = nil
    hostage.pathTo = nil
    
    -- Remove immunity
    SetEntityInvincible(hostage.ped, false)
    SetBlockingOfNonTemporaryEvents(hostage.ped, false)
    SetPedCanRagdoll(hostage.ped, false)
    
    ClearPedTasks(hostage.ped)
    SetEntityAsNoLongerNeeded(hostage.ped)
    TaskWanderStandard(hostage.ped, 10.0, 10)

    if HasAnimDictLoaded(animDicts.surrender) then
        RemoveAnimDict(animDicts.surrender)
    end
    --- DeleteEntity so the ped will be removed after we done with it because peds logic is cooked in gta so they just keep walking around in the store. 
    --- 15 seconds is enough time for the ped to walk away from the player and then be deleted. 
    SetTimeout(15000, function()
        if DoesEntityExist(hostage.ped) then
            DeleteEntity(hostage.ped)
        end
    end)
end
--- Function to spawn the hostage
local function spawnHostage(locationIndex)
    local location = Config.HostageLocations[locationIndex]
    if not location then return end
    
    local modelIndex = math.random(1, #Config.HostageModels) --- Get a random model from the config file
    local model = Config.HostageModels[modelIndex] --- Get the model from the config file based on the index we got from the math.random function
    local modelHash = joaat(model)
    
    lib.requestModel(modelHash)
    
    local ped = CreatePed(4, modelHash, 
        location.SpawnCoords.x, 
        location.SpawnCoords.y, 
        location.SpawnCoords.z, 
        location.SpawnCoords.w, 
        false, false)
    
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    
    hostageCount = hostageCount + 1
    hostages[hostageCount] = {
        ped = ped,
        locationIndex = locationIndex,
        state = HOSTAGE_STATE.IDLE
    }
    
    pedToHostageMap[ped] = hostageCount
    
    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'take_hostage_' .. hostageCount,
            label = 'Take Hostage',
            icon = 'fas fa-user-shield',
            canInteract = function(entity)
                local idx = pedToHostageMap[entity]
                return idx and hostages[idx] and hostages[idx].state == HOSTAGE_STATE.IDLE
            end,
            onSelect = function(data)
                handleHostageTaking(pedToHostageMap[data.entity])
            end
        },
        {
            name = 'make_surrender_' .. hostageCount,
            label = 'Make Hostage Surrender',
            icon = 'fas fa-hands',
            canInteract = function(entity)
                local idx = pedToHostageMap[entity]
                return idx and hostages[idx] and hostages[idx].state == HOSTAGE_STATE.SCARED
            end,
            onSelect = function(data)
                handleHostageSurrender(pedToHostageMap[data.entity])
            end
        },
        {
            name = ('release_hostage_%d'):format(hostageCount),
            label = 'Release Hostage',
            icon = 'fas fa-hand-holding',
            
            canInteract = function(entity)
                local playerJob = QBX.PlayerData?.job?.name  -- Uses optional chaining to avoid nil errors if the player data is not available 
                local isPolice = playerJob == 'police' or playerJob == 'leo'
        
                local idx = pedToHostageMap[entity]
                local hostage = hostages[idx]
        
                return isPolice and hostage and (hostage.state == HOSTAGE_STATE.SCARED or hostage.state == HOSTAGE_STATE.SURRENDERED)
            end,
        
            onSelect = function(data)
                local idx = pedToHostageMap[data.entity]
                if idx then
                    handleHostageRelease(idx)
                end
            end
        }        
    })
    
    SetModelAsNoLongerNeeded(modelHash)  --- Set the model as no longer needed because we dont need it anymore after we Hve spawned the ped 
    return hostageCount
end

-- Fix for surrender animation if disrupted
local function enforceAnimation(hostage)
    if not hostage or hostage.state ~= HOSTAGE_STATE.SURRENDERED then return end
    
    -- Check if animation is still playing
    if not IsEntityPlayingAnim(hostage.ped, animDicts.surrender, "idle_a", 3) then
        if hostage.pathTo then
            -- Still moving to position
            local pedCoords = GetEntityCoords(hostage.ped)
            local dist = #(pedCoords - hostage.pathTo)
            
            if dist < 1.0 then
                -- At target position, play surrender animation
                if not HasAnimDictLoaded(animDicts.surrender) then
                    lib.requestAnimDict(animDicts.surrender)
                end
                ClearPedTasksImmediately(hostage.ped)
                TaskPlayAnim(hostage.ped, animDicts.surrender, "idle_a", 8.0, -8.0, -1, 1, 0, false, false, false)
                SetEntityHeading(hostage.ped, hostage.targetHeading)
                SetPedKeepTask(hostage.ped, true)
                hostage.pathTo = nil
            else
                -- Restart pathfinding if interrupted
                TaskFollowNavMeshToCoord(
                    hostage.ped,
                    hostage.pathTo.x,
                    hostage.pathTo.y,
                    hostage.pathTo.z,
                    1.0, -1, 1.0, true, 0.0
                )
            end
        else
            -- At target position but animation stopped, restart it
            if not HasAnimDictLoaded(animDicts.surrender) then
                lib.requestAnimDict(animDicts.surrender)
            end
            ClearPedTasksImmediately(hostage.ped)
            TaskPlayAnim(hostage.ped, animDicts.surrender, "idle_a", 8.0, -8.0, -1, 1, 0, false, false, false)
            SetPedKeepTask(hostage.ped, true)
        end
    end
end

-- A big ass thread for all hostages
CreateThread(function()
    -- Preprocess weapon lists
    for _, weapon in ipairs(Config.WeaponList) do
        validWeapons[joaat(weapon)] = true
    end
    
    -- Spawn all hostages
    for i = 1, #Config.HostageLocations do
        spawnHostage(i)
    end
    
    -- Single thread for all hostage processing
    local nextResetTime = GetGameTimer() + (Config.ResetHostagesTime * 60 * 1000)
    
    while true do
        local sleep = 1000
        local currentTime = GetGameTimer()
        
        -- Check for global reset
        if currentTime > nextResetTime then
            -- Reset all hostages
            for i = 1, hostageCount do
                if hostages[i] and DoesEntityExist(hostages[i].ped) then
                    pedToHostageMap[hostages[i].ped] = nil
                    DeleteEntity(hostages[i].ped)
                    hostages[i] = nil
                end
            end
            
            -- Respawn all
            for i = 1, #Config.HostageLocations do
                spawnHostage(i)
            end
            
            nextResetTime = currentTime + (Config.ResetHostagesTime * 60 * 1000)
        end
        
        -- Process hostages close to a player only (performance) 
        local playerCoords = GetEntityCoords(PlayerPedId())
        for i = 1, hostageCount do
            local hostage = hostages[i]
            if hostage and #(GetEntityCoords(hostage.ped) - playerCoords) < 50.0 then
                -- Process surrendering hostages
                if hostage.state == HOSTAGE_STATE.SURRENDERED and hostage.nextCheck and currentTime > hostage.nextCheck then
                    if hostage.pathTo then
                        local pedCoords = GetEntityCoords(hostage.ped)
                        local dist = #(pedCoords - hostage.pathTo)
                        
                        if dist < 1.0 then
                            if not HasAnimDictLoaded(animDicts.surrender) then
                                lib.requestAnimDict(animDicts.surrender)
                            end
                            ClearPedTasksImmediately(hostage.ped)
                            TaskPlayAnim(hostage.ped, animDicts.surrender, "idle_a", 8.0, -8.0, -1, 1, 0, false, false, false)
                            SetEntityHeading(hostage.ped, hostage.targetHeading)
                            SetPedKeepTask(hostage.ped, true)
                            hostage.pathTo = nil
                        else
                            -- Continue checking position
                            hostage.nextCheck = currentTime + 1000
                            -- Ensure hands up animation continues
                            if not IsEntityPlayingAnim(hostage.ped, animDicts.handsUp, "handsup_base", 3) then
                                TaskPlayAnim(hostage.ped, animDicts.handsUp, "handsup_base", 8.0, -8.0, -1, 49, 0, false, false, false)
                            end
                        end
                    else
                        -- Check if animation is still playing when at position
                        enforceAnimation(hostage)
                        hostage.nextCheck = currentTime + 2000
                    end
                
                -- Auto-release timer
                elseif hostage.releaseTimer and (hostage.state == HOSTAGE_STATE.SCARED or hostage.state == HOSTAGE_STATE.SURRENDERED) then
                    if hostage.lastTimerCheck then
                        local deltaTime = currentTime - hostage.lastTimerCheck
                        hostage.releaseTimer = hostage.releaseTimer - deltaTime
                    end
                    hostage.lastTimerCheck = currentTime
                    
                    if hostage.releaseTimer <= 0 then
                        handleHostageRelease(i)
                    end
                end
            end
        end
        
        Wait(sleep)
    end
end)

-- Events
RegisterNetEvent('hostage:reset', function()
    for i = 1, hostageCount do
        if hostages[i] and DoesEntityExist(hostages[i].ped) then
            pedToHostageMap[hostages[i].ped] = nil
            DeleteEntity(hostages[i].ped)
            hostages[i] = nil
        end
    end

    if HasAnimDictLoaded(animDicts.surrender) then
        RemoveAnimDict(animDicts.surrender)
    end

    for i = 1, #Config.HostageLocations do
        spawnHostage(i)
    end
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    for _, dict in pairs(animDicts) do
        if HasAnimDictLoaded(dict) then
            RemoveAnimDict(dict)
        end
    end
    
    for i = 1, hostageCount do
        if hostages[i] and DoesEntityExist(hostages[i].ped) then
            DeleteEntity(hostages[i].ped)
        end
    end
end)