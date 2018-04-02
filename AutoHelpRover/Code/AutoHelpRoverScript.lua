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
            Sleep(1500)
            AutoHelpHandleRovers() 
        end
    end)
end

-- Mod's global
AutoHelpRover = { }
-- Base ID for translatable text
AutoHelpRover.StringIdBase = 20183402


-- Evaluates all rovers and issues commands to idle and marked ones
function AutoHelpHandleRovers()

    local showNotifications = AutoHelpConfigShowNotification()

    ForEach { class = "RCRover", exec = function(rover)
        -- Enabled via the InfoPanel UI section "Auto Help"
        if rover.auto_help then
            -- If the rover is currently idle
            -- Or is in "Commanding Drones" state
            if rover.command == "Idle" then
                -- find nearest rover with a malfunction
                local obj, distance = FindNearest({ 
                    class = "BaseRover",
                    -- which is not the rover being evaluated
                    -- and has the state malfunction
                    filter = function(o, r)
                        return o ~= r and o.command == "Malfunction"
                    end
                }, rover, rover)

                -- there is a malfunctioning other rover
                if obj then
                    -- if it is within the work radius, do nothing
                    -- otherwise make sure there is plenty of charge
                    if rover.work_radius < HexAxialDistance(rover, obj) then
                        -- when its further away, make sure there is plenty of power
                        if rover.battery_current > rover.battery_max * 0.9 then
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
                local obj2, distance2 = FindNearest({ 
                    class = "BaseRover",
                    -- which is not the rover being evaluated
                    -- and has the state no battery
                    filter = function(o, r)
                        return o ~= r and o.command == "NoBattery"
                    end
                }, rover, rover)

                if obj2 then
                    -- always make sure the rover is fully charged before
                    -- recharging somebody else
                    if rover.battery_current > rover.battery_max * 0.9 then
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
    end }
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
    if rawget(_G, "ModConfig") then
        return ModConfig:Get("AutoHelpRover", "Notifications")
    end
    return "all"
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
    
end