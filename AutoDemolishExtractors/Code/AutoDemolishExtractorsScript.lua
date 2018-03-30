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
    CreateGameTimeThread(function()
        while true do
            Sleep(1000)
            AutoDemolishExtractorsHandler() 
        end
    end)
end

-- Automation logic
-- ===========================================================

function AutoDemolishExtractorsHandler()
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

                -- water extractors don't have GetAmount for remaining water
                if buildingClass == "WaterExtractor" then
                    amount = (extractor:GetDeposit()):GetAmount()
                else
                    amount = extractor:GetAmount()
                end
                -- Check if the available amount is zero
                if amount == 0 then
                    -- extractor.demolishing gets nil'd when the demolish action completes
                    -- enabledAction can be "salvage" or "all" at this point
                    if (not extractor.destroyed) and (not extractor.demolishing) and (not extractor:IsDemolishing()) then
                        -- display the salvage notification if allowed
                        if showNotifications == "all" then
                            AddCustomOnScreenNotification("AutoDemolishExtractorSalvage", 
                                T{name}, 
                                T{"Salvaging depleted " .. name}, 
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
                                    T{"Clearing depleted " .. name}, 
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

-- See if ModConfig is installed and that notifications are enabled
function AutoDemolishExtractorsShowNotification()
    if rawget(_G, "ModConfig") then
        return ModConfig:Get("AutoDemolishExtractors", "Notifications")
    end
    return "all"
end

-- See if ModConfig is installed and operations are enabled for a particular building class
function AutoDemolishExtractorsEnabledAction(buildingClass)
    if rawget(_G, "ModConfig") then
        return ModConfig:Get("AutoDemolishExtractors", "Action" .. buildingClass)
    end
    return "all"
end

-- Mod config setup
-- ===========================================================

-- ModConfig signals "ModConfigReady" when it can be manipulated
function OnMsg.ModConfigReady()

    -- Register the mod
    ModConfig:RegisterMod("AutoDemolishExtractors",
        T{"Auto Demolish Extractors"},
        T{"Automatically salvage and clear (i.e., demolish) depleted Extractors"}
    ) 

    -- Register the notification settings
    ModConfig:RegisterOption("AutoDemolishExtractors", "Notifications", {
        name = T{"Notifications"},
        desc = T{"Enable/Disable notifications of automatic demolition of Extractors."},
        type = "enum",
        values = {
            {value = "all", label = T{"All"}},
            -- Not applicable here
            -- {value = "problems", label = T{"Problems only"}},
            {value = "off", label = T{"Off"}}
        },
        default = "all" 
    })

    AutoDemolishExtractorsRegisterOptionFor("RegolithExtractor", "Concrete Extractor")
    AutoDemolishExtractorsRegisterOptionFor("MetalsExtractor", "Metal Extractor")
    AutoDemolishExtractorsRegisterOptionFor("PreciousMetalsExtractor", "Rare metal Extractor")
    AutoDemolishExtractorsRegisterOptionFor("WaterExtractor", "Water Extractor")
end

function AutoDemolishExtractorsRegisterOptionFor(buildingClass, name)
    
    -- Register the action to take
    ModConfig:RegisterOption("AutoDemolishExtractors", "Action" .. buildingClass, {
        name = T{"Action for " .. name},
        desc = T{"Action to take when a " .. name .. " gets depleted.<newline>Clearing requires the Decomission Protocol research."},
        type = "enum",
        values = {
            {value = "all", label = T{"Salvage & Clear"}},
            {value = "salvage", label = T{"Salvage only"}},
            {value = "off", label = T{"Do nothing"}}
        },
        default = "all" 
    })
end