function OnMsg.GameTimeStart()
    AutoDemolishConcreteExtractorInstallThread()
end

function OnMsg.LoadGame()
    AutoDemolishConcreteExtractorInstallThread()
end

-- Install the game time thread that periodically evaluates rovers
function AutoDemolishConcreteExtractorInstallThread()
    CreateGameTimeThread(function()
        while true do
            Sleep(300)
            AutoDemolishConcreteExtractorHandler() 
        end
    end)
end

-- Evaluates all Concrete Extractors, issues commands to dismantle them
function AutoDemolishConcreteExtractorHandler()
    -- notification settings
    local showNotifications = AutoDemolishConcreteExtractorShowNotification();

    -- behavior settings
    local enabledAction = AutoDemolishConcreteExtractorEnabledAction();

    -- if this feature is not turned off via mod
    if enabledAction ~= "off" then
        -- It's called regolith extractor
        ForEach { class = "RegolithExtractor", 
            -- execute for each fund extractor
            exec = function(extractor)
                -- ignore those that are being constructed
                if IsKindOf(extractor, "ConstructionSite")
                    return
                end
                -- Check if the available amount is zero
                if extractor:GetAmount() == 0 then
                    -- extractor.demolishing gets nil'd when the demolish action completes
                    -- enabledAction can be "salvage" or "all" at this point
                    if (not extractor.destroyed) and (not extractor.demolishing) and (not extractor:IsDemolishing()) then
                        -- display the salvage notification if allowed
                        if showNotifications == "all" then
                            AddCustomOnScreenNotification("AutoDemolishConcreteExtractorSalvage", 
                                T{"Concrete Extractor"}, 
                                T{"Salvaging depleted Concrete Extractor"}, 
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
                                AddCustomOnScreenNotification("AutoDemolishConcreteExtractorDecomission", 
                                    T{"Concrete Extractor"}, 
                                    T{"Clearing depleted Concrete Extractor"}, 
                                    "UI/Icons/Notifications/deposit_depleted.tga",
                                    false, { expiration = 15000 }
                                )
                            end
                            -- DestroyedClear(true) would be clearing all that have state destoyed, even damaged ones
                            extractor:DestroyedClear(false)
                        end
                    end
                end
        end }
    end
end

-- See if ModConfig is installed and that notifications are enabled
function AutoDemolishConcreteExtractorShowNotification()
    if rawget(_G, "ModConfig") then
        return ModConfig:Get("AutoDemolishConcreteExtractor", "Notifications")
    end
    return "all"
end

-- See if ModConfig is installed operations are enabled
function AutoDemolishConcreteExtractorEnabledAction()
    if rawget(_G, "ModConfig") then
        return ModConfig:Get("AutoDemolishConcreteExtractor", "Action")
    end
    return "all"
end

-- ModConfig signals "ModConfigReady" when it can be manipulated
function OnMsg.ModConfigReady()

    -- Register the mod
    ModConfig:RegisterMod("AutoDemolishConcreteExtractor",
        T{"Auto Demolish Concrete Extractors"},
        T{"Automatically salvage and clear (i.e., demolish) depleted Concrete Extractors"}
    ) 

    -- Register the notification settings
    ModConfig:RegisterOption("AutoDemolishConcreteExtractor", "Notifications", {
        name = T{"Notifications"},
        desc = T{"Enable/Disable notifications of automatic demolition of Concrete Extractors."},
        type = "enum",
        values = {
            {value = "all", label = T{"All"}},
            -- Not applicable here
            -- {value = "problems", label = T{"Problems only"}},
            {value = "off", label = T{"Off"}}
        },
        default = "all" 
    })

    -- Register the action to take
    ModConfig:RegisterOption("AutoDemolishConcreteExtractor", "Action", {
        name = T{"Action"},
        desc = T{"Action to take when a Concrete Extractor gets depleted.<newline>Clearing requires the Decomission Protocol research."},
        type = "enum",
        values = {
            {value = "all", label = T{"Salvage & Clear"}},
            {value = "salvage", label = T{"Salvage only"}},
            {value = "off", label = T{"Do nothing"}}
        },
        default = "all" 
    })

end