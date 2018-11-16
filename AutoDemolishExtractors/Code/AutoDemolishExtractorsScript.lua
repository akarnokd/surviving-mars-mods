-- Setup automation threads
-- ===========================================================

function OnMsg.GameTimeStart()
    AutoDemolishExtractorsInstallThread()
end

function OnMsg.LoadGame()
    AutoDemolishExtractorsInstallThread()
end

-- Install the game time thread that periodically evaluates objects
function AutoDemolishExtractorsInstallThread()
    -- make sure the handler thread is installed at most once
    if UICity and not IsValidThread(UICity.AutoDemolishExtractorsThread_GameTime) then
        UICity.AutoDemolishExtractorsThread_GameTime = CreateGameTimeThread(function()
            while true do
                Sleep(1000)
                AutoDemolishExtractorsHandler() 
            end
        end)
    end
end

-- Mod's global
AutoDemolishExtractors = { }
-- Base ID for translatable text
AutoDemolishExtractors.StringIdBase = 20184406

-- Automation logic
-- ===========================================================

function AutoDemolishExtractorsHandler()
    -- game is not yet initialized
    if not mapdata.GameLogic then
        return
    end

    local showNotifications = AutoDemolishExtractorsShowNotification()


    AutoDemolishExtractorsOf(
        "RegolithExtractor", showNotifications, "Concrete Extractor"
    )

    AutoDemolishExtractorsOf(
        "MetalsExtractor", showNotifications, "Metal Extractor"
    )

    AutoDemolishExtractorsOf(
        "PreciousMetalsExtractor", showNotifications, "Rare metal Extractor"
    )

    AutoDemolishExtractorsOf(
        "WaterExtractor", showNotifications, "Water Extractor"
    )
end

function AutoDemolishExtractorsOf(buildingClass, showNotifications, name)
    -- get the settings for this building class
    local enabledAction = AutoDemolishExtractorsEnabledAction(buildingClass)

    -- if this feature is not turned off via mod
    if enabledAction ~= "off" then
        -- It's called regolith extractor
        ForEach { class = buildingClass, 
            -- execute for each fund extractor
            exec = function(extractor)
                -- ignore those that are being constructed
                if IsKindOf(extractor, "ConstructionSite") then
                    return
                end
                local amount = 0

                -- some extractors have direct value
                if extractor:IsKindOf("TerrainDepositExtractor") then
                    amount = extractor:GetAmount()
                end
                -- others have to be gathered from nearby deposit info
                if extractor.nearby_deposits then
                    for i = 1, #extractor.nearby_deposits do
                        if IsValid((extractor.nearby_deposits)[i]) then
                            amount = amount + ((extractor.nearby_deposits)[i]).amount
                        end
                    end
                end

                -- Check if the available amount is zero
                if amount == 0 then
                    -- skip a round to work around the case when amount is 0
                    -- but the extraction hasn't even begun yet
                    if not extractor.auto_demolish_visited then
                        extractor.auto_demolish_visited = true
                        return
                    end
                    -- extractor.demolishing gets nil'd when the demolish action completes
                    -- enabledAction can be "salvage" or "all" at this point
                    if (not extractor.destroyed) and (not extractor.demolishing) and (not extractor:IsDemolishing()) then
                        -- display the salvage notification if allowed
                        if showNotifications == "all" then
                            AddCustomOnScreenNotification("AutoDemolishExtractorSalvage", 
                                T{name}, 
                                T{AutoDemolishExtractors.StringIdBase, "Salvaging depleted " .. name}, 
                                "UI/Icons/Notifications/deposit_depleted.tga",
                                false, { expiration = 15000 }
                            )
                        end
                        -- enable
                        extractor:ToggleDemolish()
                    end

                    if enabledAction == "all" then
                        -- if destroyed but not yet bulldozed and the research is there
                        if (extractor.destroyed) and (not extractor.bulldozed) 
                                and UICity:IsTechResearched("DecommissionProtocol") then
                            -- display the salvage notification if allowed
                            if showNotifications == "all" then
                                AddCustomOnScreenNotification("AutoDemolishExtractorDecomission", 
                                    T{name}, 
                                    T{AutoDemolishExtractors.StringIdBase + 1, "Clearing depleted " .. name}, 
                                    "UI/Icons/Notifications/deposit_depleted.tga",
                                    false, { expiration = 15000 }
                                )
                            end
                            -- DestroyedClear(true) would be clearing all that have state destoyed,
                            -- even damaged but not depleted ones
                            extractor:DestroyedClear(false)
                        end
                    end
                end
        end }
    end
end

-- Check if any of the ModConfig mods are installed
function ModConfigAvailable()
    -- ModConfig old
    local found = table.find_value(ModsLoaded, "steam_id", "1340775972") or
    -- ModConfig reborn
                  table.find_value(ModsLoaded, "steam_id", "1542863522") or false
    return found    
end

-- See if ModConfig is installed and that notifications are enabled
function AutoDemolishExtractorsShowNotification()
    local g_ModConfigLoaded = ModConfigAvailable()
    if g_ModConfigLoaded and ModConfig:IsReady() then
        return ModConfig:Get("AutoDemolishExtractors", "Notifications")
    end
    return "all"
end

-- See if ModConfig is installed and operations are enabled for a particular building class
function AutoDemolishExtractorsEnabledAction(buildingClass)
    local g_ModConfigLoaded = ModConfigAvailable()
    if g_ModConfigLoaded  and ModConfig:IsReady() then
        local nano = ModConfig:Get("AutoDemolishExtractors", "NanoRefinement")
        local act = ModConfig:Get("AutoDemolishExtractors", "Action" .. buildingClass)

        if UICity:IsTechResearched("NanoRefinement") and nano == "off" then
            return "off"
        end
        return act
    end
    return "all"
end

-- Mod config setup
-- ===========================================================

-- ModConfig signals "ModConfigReady" when it can be manipulated
function OnMsg.ModConfigReady()

    -- Register the mod
    ModConfig:RegisterMod("AutoDemolishExtractors",
        T{AutoDemolishExtractors.StringIdBase + 2, "Auto Demolish Extractors"},
        T{AutoDemolishExtractors.StringIdBase + 3, "Automatically salvage and clear (i.e., demolish) depleted Extractors"}
    ) 

    -- Register the notification settings
    ModConfig:RegisterOption("AutoDemolishExtractors", "Notifications", {
        name = T{AutoDemolishExtractors.StringIdBase + 4, "Notifications"},
        desc = T{AutoDemolishExtractors.StringIdBase + 5, "Enable/Disable notifications of automatic demolition of Extractors."},
        type = "enum",
        values = {
            {value = "all", label = T{AutoDemolishExtractors.StringIdBase + 14, "All"}},
            -- Not applicable here
            -- {value = "problems", label = T{"Problems only"}},
            {value = "off", label = T{AutoDemolishExtractors.StringIdBase + 15, "Off"}}
        },
        default = "all" 
    })

    ModConfig:RegisterOption("AutoDemolishExtractors", "NanoRefinement", {
        name = T{AutoDemolishExtractors.StringIdBase + 11, "Nano refinement"},
        desc = T{AutoDemolishExtractors.StringIdBase + 12, "What to do when the Nano Refinement research has been acquired, which allows extractors to still mine depleted resources for small amounts of material."},
        type = "enum",
        values = {
            {value = "on", label = T{AutoDemolishExtractors.StringIdBase + 13, "Keep doing the action"}},
            {value = "off", label = T{AutoDemolishExtractors.StringIdBase + 14, "Do nothing"}}
        },
        default = "on" 
    })

    AutoDemolishExtractorsRegisterOptionFor("RegolithExtractor", "Concrete Extractor")
    AutoDemolishExtractorsRegisterOptionFor("MetalsExtractor", "Metal Extractor")
    AutoDemolishExtractorsRegisterOptionFor("PreciousMetalsExtractor", "Rare metal Extractor")
    AutoDemolishExtractorsRegisterOptionFor("WaterExtractor", "Water Extractor")
end

function AutoDemolishExtractorsRegisterOptionFor(buildingClass, name)
    
    -- Register the action to take
    ModConfig:RegisterOption("AutoDemolishExtractors", "Action" .. buildingClass, {
        name = T{AutoDemolishExtractors.StringIdBase + 6, "Action for " .. name},
        desc = T{AutoDemolishExtractors.StringIdBase + 7, "Action to take when a " .. name .. " gets depleted.<newline>Clearing requires the Decomission Protocol research."},
        type = "enum",
        values = {
            {value = "all", label = T{AutoDemolishExtractors.StringIdBase + 8, "Salvage & Clear"}},
            {value = "salvage", label = T{AutoDemolishExtractors.StringIdBase + 9, "Salvage only"}},
            {value = "off", label = T{AutoDemolishExtractors.StringIdBase + 10, "Do nothing"}}
        },
        default = "all" 
    })
end