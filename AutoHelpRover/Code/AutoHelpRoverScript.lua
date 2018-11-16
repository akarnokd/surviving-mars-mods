function OnMsg.GameTimeStart()
    AutoHelpInstallThread()
end

function OnMsg.LoadGame()
    AutoHelpInstallThread()
end

-- Install the game time thread that periodically evaluates rovers
function AutoHelpInstallThread()
    -- make sure the handler thread is installed at most once
    if UICity and not IsValidThread(UICity.AutoHelpRoverThread_GameTime) then
        UICity.AutoHelpRoverThread_GameTime = CreateGameTimeThread(function()
            while true do
                AutoHelpHandleRovers() 
                local period = AutoHelpConfigUpdatePeriod()
                Sleep(tonumber(period))
            end
        end)
    end
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
                    end

                    return
                end

                -- bring the rover back to a safe location
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
            "RolloverText", T{AutoHelpRover.StringIdBase + 6, "Enable/Disable automatic repair of malfunctioning rovers.<newline><newline>(AutoHelpRover mod)"},
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

-- Check if any of the ModConfig mods are installed
function ModConfigAvailable()
    -- ModConfig old
    local found = table.find_value(ModsLoaded, "steam_id", "1340775972") or
    -- ModConfig reborn
                  table.find_value(ModsLoaded, "steam_id", "1542863522") or false
    return found    
end

-- See if ModConfig is installed and that notifications are enabled
function AutoHelpConfigShowNotification()
    local g_ModConfigLoaded = ModConfigAvailable()
    if g_ModConfigLoaded and ModConfig:IsReady() then
        return ModConfig:Get("AutoHelpRover", "Notifications")
    end
    return "all"
end

-- See if ModConfig is installed and that notifications are enabled
function AutoHelpConfigUpdatePeriod()
    local g_ModConfigLoaded = ModConfigAvailable()
    if g_ModConfigLoaded and ModConfig:IsReady() then
        return ModConfig:Get("AutoHelpRover", "UpdatePeriod")
    end
    return "1500"
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
end