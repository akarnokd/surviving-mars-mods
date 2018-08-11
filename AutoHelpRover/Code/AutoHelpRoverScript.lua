function OnMsg.GameTimeStart()
    AutoHelpInstallThread()
end

function OnMsg.LoadGame()
    AutoHelpInstallThread()
end

-- Install the game time thread that periodically evaluates rovers
function AutoHelpInstallThread()
    CreateGameTimeThread(function()
        while true do
            AutoHelpHandleRovers() 
            local period = AutoHelpConfigUpdatePeriod()
            Sleep(tonumber(period))
        end
    end)
end

-- Mod's global
AutoHelpRover = { }
-- Base ID for translatable text
AutoHelpRover.StringIdBase = 20183402

-- enumerate objects of a given City label
function AutoHelpForEachLabel(label, func)
    for _, obj in ipairs(UICity.labels[label] or empty_table) do
        if func(obj) == "break" then
            return
        end
    end
end

-- find the nearest object to the target based on additional filtering
function AutoHelpFindNearest(objects, filter, target)
    local targetPos = target:GetPos()
    local nearestObj = nil
    local nearestDist = 0

    for i, o in ipairs(objects) do
        if filter(o) then
            local p = o:GetPos()
            local dist = (targetPos:x() - p:x())^2 + (targetPos:y() - p:y())^2

            if nearestObj == nil then
                nearestObj = o
                nearestDist = dist
            else
                if nearestDist > dist then
                    nearestObj = o
                    nearestDist = dist
                end
            end
        end
    end

    return nearestObj, nearestDist
end

-- Evaluates all rovers and issues commands to idle and marked ones
function AutoHelpHandleRovers()
    -- game is not yet initialized
    if not mapdata.GameLogic then
        return
    end

    local showNotifications = AutoHelpConfigShowNotification()

    local batteryThreshold = tonumber(AutoHelpBatteryThreshold())

    local allRovers = UICity.labels.Rover

    AutoHelpForEachLabel("RCRover", function(rover)
        -- Enabled via the InfoPanel UI section "Auto Help"
        if rover.auto_help then
            -- If the rover is currently idle
            -- Or is in "Commanding Drones" state
            if rover.command == "Idle" then
                -- find nearest rover with a malfunction
                local obj, distance = AutoHelpFindNearest( 
                    allRovers,
                    -- which is not the rover being evaluated
                    -- and has the state malfunction
                    function(o)
                        return o ~= rover and o.command == "Malfunction"
                    end
                , rover)

                -- there is a malfunctioning other rover
                if obj then
                    -- if it is within the work radius, do nothing
                    -- otherwise make sure there is plenty of charge
                    if rover.work_radius < HexAxialDistance(rover, obj) then
                        -- when its further away, make sure there is plenty of power
                        if rover.battery_current > rover.battery_max * batteryThreshold / 100.0 then
                            if showNotifications == "all" then
                                -- display the notification
                                AddCustomOnScreenNotification(
                                    "AutoHelpRoverFix", 
                                    T{ rover.name }, 
                                    T{ AutoHelpRover.StringIdBase, "Going to fix: " .. obj.name }, 
                                    "UI/Icons/Notifications/research_2.tga",
                                    false,
                                    {
                                        expiration = 15000
                                    }
                                )
                            end
                            -- go next to the malfunctioning other rover
                            rover:GoToPos(obj:GetPos())
                        else
                            -- otherwise go recharge first
                            AutoHelpGoRecharge(rover)
                        end
                    else
                        -- when it is in range but we have less than 60% battery, go recharge instead
                        if rover.battery_current < rover.battery_max * 0.6 then
                            AutoHelpGoRecharge(rover)
                        end
                    end

                    return
                end

                -- find nearest rover with out of battery
                local obj2, distance2 = AutoHelpFindNearest( 
                    allRovers,
                    -- which is not the rover being evaluated
                    -- and has the state no battery
                    function(o)
                        return o ~= rover and o.command == "NoBattery"
                    end
                , rover)

                if obj2 then
                    -- always make sure the rover is fully charged before
                    -- recharging somebody else
                    if rover.battery_current > rover.battery_max * batteryThreshold / 100.0 then
                        if showNotifications == "all" then
                            -- display the notification
                            AddCustomOnScreenNotification(
                                "AutoHelpRoverRechargeOther", 
                                T{ rover.name }, 
                                T{ AutoHelpRover.StringIdBase + 1, "Going to recharge: " .. obj2.name }, 
                                "UI/Icons/Notifications/research_2.tga",
                                false,
                                {
                                    expiration = 15000
                                }
                            )
                        end
                        -- this will go to the target rover and equalize power
                        --(BaseRover.InteractWithObject)(rover, obj2, "recharge")
                        rover:InteractWithObject(obj2, "recharge")
                    else
                        -- recharge the rover itself first
                        AutoHelpGoRecharge(rover)
                    end
                    -- either way, the situation can be considered handled
                    return
                end

                -- if there are nobody to service, just keep it recharged
                -- which also brings it back from the field
                if rover.battery_current <= rover.battery_max * 0.99 then
                    AutoHelpGoRecharge(rover)
                else
                    -- otherwise, the RoverCommandAI keeps the rover fully charged and would stay
                    -- in the field indefinitely
                    if g_RoverCommandResearched then
                        -- locate the nearest recharge point
                        local obj, distance = AutoHelpFindRechargeLocation(rover)
                        -- if outside the current work radius, move next to it
                        -- otherwise don't try to move there all the time
                        if obj and rover.work_radius < HexAxialDistance(rover, obj) then
                            if showNotifications == "all" then
                                AddCustomOnScreenNotification(
                                    "AutoHelpRoverReturnToBase", 
                                    T{ rover.name }, 
                                    T{ AutoHelpRover.StringIdBase + 2, "Returning from the field" }, 
                                    "UI/Icons/Notifications/research_2.tga",
                                    false,
                                    {
                                        expiration = 15000
                                    }
                                )
                            end
                            rover:GoToPos(obj:GetPos())
                        end
                    end
                end
            end
        end
    end)
end

-- Locate a power cable
function AutoHelpFindRechargeLocation(rover)
    return FindNearest ({ class = "ElectricityGridElement",
        filter = function(obj, ...)
            return not IsKindOf(obj, "ConstructionSite")
        end
    }, rover)
end

-- Find the nearest power cable to recharge
function AutoHelpGoRecharge(rover)

    local showNotifications = AutoHelpConfigShowNotification()

    local obj, distance = AutoHelpFindRechargeLocation(rover)

    if obj then
        if showNotifications == "all" then
            AddCustomOnScreenNotification(
                "AutoHelpRoverRecharge", 
                T{rover.name}, 
                T{AutoHelpRover.StringIdBase + 3, "Going to recharge self"}, 
                "UI/Icons/Notifications/research_2.tga",
                false,
                {
                    expiration = 15000
                }
            )
        end
        rover:InteractWithObject(obj, "recharge")
    else
        if showNotifications == "all" or showNotifications == "problems" then
            AddCustomOnScreenNotification(
                "AutoHelpRoverNoRecharge", 
                T{rover.name}, 
                T{AutoHelpRover.StringIdBase + 4, "Unable to find a recharge spot"}, 
                "UI/Icons/Notifications/research_2.tga",
                false,
                {
                    expiration = 15000
                }
            )
        end
    end
end

function OnMsg.ClassesBuilt()
    AutoHelpAddInfoSection()
end

function AutoHelpAddInfoSection()
    -- if the templates have been added, don't add them again
    -- I don't know how to remove them as it breaks the UI with just nil-ing them out
    if table.find(XTemplates.ipRover[1], "UniqueId", "AutoHelpRover-1") then
        return
    end

    table.insert(XTemplates.ipRover[1], 
        PlaceObj("XTemplateTemplate", {
            "__context_of_kind", "RCRover",
            "__template", "InfopanelActiveSection",
            "Icon", "UI/Icons/Upgrades/factory_ai_02.tga",
            "Title", T{AutoHelpRover.StringIdBase + 5, "Auto Help"},
            "RolloverText", T{AutoHelpRover.StringIdBase + 6, "Enable/Disable automatic repair/recharge of malfunctioning or out of battery rovers.<newline><newline>(AutoHelpRover mod)"},
            "RolloverTitle", T{AutoHelpRover.StringIdBase + 7, "Auto Help"},
            "RolloverHint",  T{AutoHelpRover.StringIdBase + 8, "<left_click> Toggle setting"},
            "OnContextUpdate",
                function(self, context)
                    if context.auto_help then
                        self:SetTitle(T{AutoHelpRover.StringIdBase + 9, "Auto Help (ON)"})
                        self:SetIcon("UI/Icons/Upgrades/factory_ai_02.tga")
                    else
                        self:SetTitle(T{AutoHelpRover.StringIdBase + 10, "Auto Help (OFF)"})
                        self:SetIcon("UI/Icons/Upgrades/factory_ai_01.tga")
                    end
                end,
            "UniqueId", "AutoHelpRover-1"
        }, {
            PlaceObj("XTemplateFunc", {
                "name", "OnActivate(self, context)", 
                "parent", function(parent, context)
                        return parent.parent
                    end,
                "func", function(self, context)
                        context.auto_help = not context.auto_help
                        ObjModified(context)
                    end
            })
        })
    )
end


-- See if ModConfig is installed and that notifications are enabled
function AutoHelpConfigShowNotification()
    local g_ModConfigLoaded = table.find_value(ModsLoaded, "steam_id", "1340775972") or false
    if g_ModConfigLoaded then
        return ModConfig:Get("AutoHelpRover", "Notifications")
    end
    return "all"
end

-- See if ModConfig is installed and that notifications are enabled
function AutoHelpConfigUpdatePeriod()
    local g_ModConfigLoaded = table.find_value(ModsLoaded, "steam_id", "1340775972") or false
    if g_ModConfigLoaded then
        return ModConfig:Get("AutoHelpRover", "UpdatePeriod")
    end
    return "1500"
end

-- Battery threshold
function AutoHelpBatteryThreshold()
    local g_ModConfigLoaded = table.find_value(ModsLoaded, "steam_id", "1340775972") or false
    if g_ModConfigLoaded then
        return ModConfig:Get("AutoHelpRover", "BatteryThreshold")
    end
    return "90"
end


-- ModConfig signals "ModConfigReady" when it can be manipulated
function OnMsg.ModConfigReady()

    ModConfig:RegisterMod("AutoHelpRover", -- ID
        T{AutoHelpRover.StringIdBase + 11, "AutoHelpRover"}, -- Optional display name, defaults to ID
        T{AutoHelpRover.StringIdBase + 12, "Rovers automatically fix and/or recharge other rovers, keep themselves charged"} -- Optional description
    ) 

    ModConfig:RegisterOption("AutoHelpRover", "Notifications", {
        name = T{AutoHelpRover.StringIdBase + 13, "Notifications"},
        desc = T{AutoHelpRover.StringIdBase + 14, "Enable/Disable notifications of the rovers in Auto mode."},
        type = "enum",
        values = {
            {value = "all", label = T{AutoHelpRover.StringIdBase + 15, "All"}},
            {value = "problems", label = T{AutoHelpRover.StringIdBase + 16, "Problems only"}},
            {value = "off", label = T{AutoHelpRover.StringIdBase + 17, "Off"}}
        },
        default = "all" 
    })

        
    ModConfig:RegisterOption("AutoHelpRover", "UpdatePeriod", {
        name = T{AutoHelpRover.StringIdBase + 18, "Update period"},
        desc = T{AutoHelpRover.StringIdBase + 19, "Time between trying to fix or recharge other rovers<newline>Pick a larger value if your colony has become large and you get lag."},
        type = "enum",
        values = {
            {value = "1000", label = T{"1 s"}},
            {value = "1500", label = T{"1.5 s"}},
            {value = "2000", label = T{"2 s"}},
            {value = "2500", label = T{"2.5 s"}},
            {value = "3000", label = T{"3 s"}},
            {value = "5000", label = T{"5 s"}},
            {value = "10000", label = T{"10 s"}},
        },
        default = "1500" 
    })

    
    ModConfig:RegisterOption("AutoHelpRover", "BatteryThreshold", {
        name = T{AutoHelpRover.StringIdBase + 20, "Battery threshold"},
        desc = T{AutoHelpRover.StringIdBase + 21, "Percentage of battery charge below which the rover will go recharge itself."},
        type = "enum",
        values = {
            {value = "10", label = T{"10%"}},
            {value = "20", label = T{"20%"}},
            {value = "30", label = T{"30%"}},
            {value = "40", label = T{"40%"}},
            {value = "50", label = T{"50%"}},
            {value = "60", label = T{"60%"}},
            {value = "70", label = T{"70%"}},
            {value = "80", label = T{"80%"}},
            {value = "90", label = T{"90%"}},
            {value = "95", label = T{"95%"}},
        },
        default = "90" 
    })

end