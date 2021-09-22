
-- Automation Logic initialization
-- ==========================================================================
function OnMsg.GameTimeStart()
    AutoShuttleConstructionInstallThread()
end

function OnMsg.LoadGame()
    AutoShuttleConstructionInstallThread()
end

local AutoShuttleConstructionModActive = true

function AutoShuttleConstructionInstallThread()
    -- make sure the handler thread is installed at most once
    if UICity and not IsValidThread(UICity.AutoShuttleConstructionThread_GameTime) then
        UICity.AutoShuttleConstructionThread_GameTime = CreateGameTimeThread(function()
            while AutoShuttleConstructionModActive do
                Sleep(1000)
                AutoShuttleConstructionManageHubs() 
            end
        end)
    end
end

-- Mod's global
AutoShuttleConstruction = { }
-- Base ID for translatable text
AutoShuttleConstruction.StringIdBase = 20185406


-- Automation Logic initialization
-- ==========================================================================
function AutoShuttleConstructionManageHubs()
    -- game is not yet initialized
    if not UICity then
        return
    end

    if not g_ResourceOverviewCity then
        -- not ready yet?
        return
    end

    -- multiplier
    local threshold = AutoShuttleConstructionConfigThreshold()

    if threshold == "off" then
        return
    end

    threshold = tonumber(threshold)

    -- notifications to show
    local showNotifications = AutoShuttleConstructionConfigShowNotification()

    -- shuttle construction costs are local info on ShuttleHub unfortunately
    -- numbers are offset by 1000 relative to the displayed amount
    local polymerCost = 5000
    local polymerName = "Polymers"
    local electronicsCost = 3000
    local electronicsName = "Electronics"

    -- total available resources
    local totalPolymers = g_ResourceOverviewCity[UICity.map_id].data[polymerName] or 0
    local totalElectronics = g_ResourceOverviewCity[UICity.map_id].data[electronicsName] or 0

    local queuedShuttles = 0

    -- first find out how many shuttles are queued at the moment
    ForEach { class = "ShuttleHub",
        exec = function(hub)
            if not IsKindOf(hub, "ConstructionSite") 
                    and not hub.demolishing 
                    and not hub.destroyed 
                    and not hub.bulldozed then
                queuedShuttles = queuedShuttles + (hub.queued_shuttles_for_construction or 0)
            end
        end
    }

    -- deduce assigned resources from queued suttles
    totalPolymers = totalPolymers - queuedShuttles * polymerCost
    totalElectronics = totalElectronics - queuedShuttles * electronicsCost

    -- deduce threshold costs
    totalPolymers = totalPolymers - threshold * polymerCost
    totalElectronics = totalElectronics - threshold * electronicsCost

    -- loop through the hubs again and queue up construction
    ForEach { class = "ShuttleHub",
        exec = function(hub)
            if IsKindOf(hub, "ConstructionSite")
                    or not hub:CanHaveMoreShuttles()
                    or hub.demolishing
                    or hub.destroyed
                    or hub.bulldozed then
                return
            end

            if totalPolymers > 0 and totalElectronics > 0 then
                if hub.queued_shuttles_for_construction == 0 then
                    if showNotifications == "all" then
                        AddCustomOnScreenNotification(
                            "AutoShuttleConstructionQueued", 
                            T{AutoShuttleConstruction.StringIdBase, "Shuttle hub"}, 
                            T{AutoShuttleConstruction.StringIdBase + 1, "Shuttle construction queued"}, 
                            "UI/Icons/Notifications/research_2.tga",
                            false,
                            {
                                expiration = 15000
                            }
                        )
                    end

                    hub:QueueConstructShuttle(1)

                    -- reduce the available amounts so that the next hub decides based on the remaining
                    -- free resources
                    totalPolymers = totalPolymers - polymerCost
                    totalElectronics = totalElectronics - electronicsCost
                end
            end
        end
    }
    
end

-- Mod configuration
-- ==========================================================================

-- Check if any of the ModConfig mods are installed
function ModConfigAvailable()
    -- ModConfig old
    local found = table.find_value(ModsLoaded, "steam_id", "1340775972") or
    -- ModConfig reborn
                  table.find_value(ModsLoaded, "steam_id", "1542863522") or false
    return found    
end


-- See if ModConfig is installed and that notifications are enabled
function AutoShuttleConstructionConfigShowNotification()
    local g_ModConfigLoaded = ModConfigAvailable()
    if g_ModConfigLoaded and ModConfig:IsReady() then
        return ModConfig:Get("AutoShuttleConstruction", "Notifications")
    end
    return "all"
end

-- See if ModConfig is installed and that notifications are enabled
function AutoShuttleConstructionConfigThreshold()
    local g_ModConfigLoaded = ModConfigAvailable()
    if g_ModConfigLoaded and ModConfig:IsReady() then
        return ModConfig:Get("AutoShuttleConstruction", "Threshold")
    end
    return "5"
end

-- ModConfig signals "ModConfigReady" when it can be manipulated
function OnMsg.ModConfigReady()

    ModConfig:RegisterMod("AutoShuttleConstruction",
        T{AutoShuttleConstruction.StringIdBase + 2, "AutoShuttleConstruction"},
        T{AutoShuttleConstruction.StringIdBase + 3, "Automatically construct Shuttles at Shuttle Hubs if there are plenty of resources and the hub is not full"}
    ) 

    ModConfig:RegisterOption("AutoShuttleConstruction", "Notifications", {
        name = T{AutoShuttleConstruction.StringIdBase + 4, "Notifications"},
        desc = T{AutoShuttleConstruction.StringIdBase + 5, "Enable/Disable notifications of the rovers in Auto mode."},
        type = "enum",
        values = {
            {value = "all", label = T{AutoShuttleConstruction.StringIdBase + 6, "All"}},
            {value = "problems", label = T{AutoShuttleConstruction.StringIdBase + 7, "Problems only"}},
            {value = "off", label = T{AutoShuttleConstruction.StringIdBase + 8, "Off"}}
        },
        default = "all" 
    })

    ModConfig:RegisterOption("AutoShuttleConstruction", "Threshold", {
        name = T{AutoShuttleConstruction.StringIdBase + 9, "Threshold"},
        desc = T{AutoShuttleConstruction.StringIdBase + 10, "How many times more resources are needed than the base cost of a Shuttle.<newline>Setting it to Always will ignore resource constraints."},
        type = "enum",
        values = {
            {value = "off", label = T{AutoShuttleConstruction.StringIdBase + 11, "Off"}},
            {value = "0", label = T{AutoShuttleConstruction.StringIdBase + 12, "Always"}},
            {value = "5", label = T{"5x"}},
            {value = "10", label = T{"10x"}},
            {value = "15", label = T{"15x"}},
            {value = "20", label = T{"20x"}},
            {value = "25", label = T{"25x"}},
            {value = "50", label = T{"50x"}},
            {value = "75", label = T{"75x"}},
        },
        default = "5" 
    })

end
