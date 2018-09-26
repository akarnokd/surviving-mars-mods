function OnMsg.GameTimeStart()
    AutoExploreInstallThread()
end

function OnMsg.LoadGame()
    AutoExploreInstallThread()
end

function OnMsg.ChangeMapDone(map)
    if map == "PreGame" then
        return 
    end
    AutoExplorePathFinding.ingameMap = true
end

function AutoExploreInstallThread()
    if AutoExplorePathFinding.ingameMap then
        -- PostNewMapLoaded seems to be too early?
        AutoExplorePathFinding:BuildZones()
        AutoExplorePathFinding.zonesBuilt = true;
    end

    CreateGameTimeThread(function()
        while true do
            -- detect script reload and rebuild the zones
            if AutoExplorePathFinding.ingameMap and not AutoExplorePathFinding.zonesBuilt then
                AutoExplorePathFinding:BuildZones()
                AutoExplorePathFinding.zonesBuilt = true;
            end

            AutoExploreHandleRovers() 
            local period = AutoExploreConfigUpdatePeriod()
            Sleep(tonumber(period))
        end
    end)
end

-- Mod's global
AutoExplore = { }
-- Base ID for translatable text
AutoExplore.StringIdBase = 20187413

-- determine if a rover is allowed to scan a specific anomaly type
function AutoExploreCanScanAnomaly(anomaly, rover)
    if IsKindOf(anomaly, "SubsurfaceAnomaly_breakthrough") then
        return rover.auto_scan_breakthrough
    end
    if IsKindOf(anomaly, "SubsurfaceAnomaly_unlock") then
        return rover.auto_scan_unlock
    end
    if IsKindOf(anomaly, "SubsurfaceAnomaly_complete") then
        return rover.auto_scan_complete
    end
    if (IsKindOf(anomaly, "SubsurfaceAnomaly_aliens") 
                or anomaly.tech_action == "resources"
                or not anomaly.tech_action) then
        return rover.auto_scan_aliens
    end

    return rover.auto_scan_custom
end

-- initialize rover scan settings
function AutoExploreInitRover(rover)
    if rover["auto_scan_breakthrough"] == nil then
        rover.auto_scan_breakthrough = true
        rover.auto_scan_unlock = true
        rover.auto_scan_complete = true
        rover.auto_scan_aliens = true
        rover.auto_scan_custom = true
    end
end

-- find the nearest object to the target based on additional filtering
function AutoExploreFindNearest(objects, filter, target)
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

-- handle all the relevant rovers
function AutoExploreHandleRovers()
    -- game is not yet initialized
    if not mapdata.GameLogic then
        return
    end

    -- should the logic try and work out paths via tunnels?
    local tunnelHandling = AutoExploreTunnelHandling() == "on";

    -- cache all surface anomalies
    local anomalies = GetObjects { class = "SubsurfaceAnomaly" }

    -- first collect up all the zones which have tunnel entrances/exits
    local zonesReachable = AutoExplorePathFinding:GetZonesReachableViaTunnels()

    local showNotifications = AutoExploreConfigShowNotification()

    ForEach { class = "ExplorerRover", exec = function(rover)
        -- initialize scan filter to true if necessary
        AutoExploreInitRover(rover)

        -- Enabled via the InfoPanel UI section "Auto Explore"
        if rover.auto_explore then

            -- Idle explorers only
            if rover.command == "Idle" then

                local roverZone = AutoExplorePathFinding:GetObjectZone(rover) or 0

                local obj, distance = AutoExploreFindNearest(anomalies, 
                    function(o)
                        -- check if the specific anomaly type is enabled for scanning on this rover
                        if not AutoExploreCanScanAnomaly(o, rover) then
                            return false
                        end

                        -- exclude anomalies already targeted by a rover
                        local can_target = (not o.rover_assigned 
                            or o.rover_assigned == rover
                            or o.rover_assigned.command == "Malfunction"
                            or o.rover_assigned.command == "Dead"
                            or not o.rover_assigned.auto_explore);

                        -- use the pathfinding helper to see if the anomaly is reachable
                        return can_target and AutoExplorePathFinding:CanReachObject(zonesReachable, roverZone, o)
                    end
                , rover)

                if obj then
                    -- check if the anomaly is in the same zone
                    local objZone = AutoExplorePathFinding:GetObjectZone(obj)

                    if objZone == roverZone or not tunnelHandling then
                        if showNotifications == "all" then
                            AddCustomOnScreenNotification(
                                "AutoExploreAnomaly", 
                                T{rover.name}, 
                                T{AutoExplore.StringIdBase, "Started exploring an anomaly"}, 
                                "UI/Icons/Notifications/research_2.tga",
                                false,
                                {
                                    expiration = 15000
                                }
                            )
                        end
                        obj.rover_assigned = rover
                        -- rover:Analyze(obj) doesn't work properly
                        rover:InteractWithObject(obj, "analyze")
                    else
                        -- It is not in the same zone. Unfortunately, the "move" command behind "analyze" may
                        -- not use a tunnel if available, we have to manually travel
                        -- the chain of tunnels to get to the same zone
                        local next = AutoExplorePathFinding:GetNextTunnelTowards(zonesReachable, roverZone, objZone)

                        -- we found it, let's move towards it
                        if next then
                            if showNotifications == "all" then
                                -- notify about it
                                AddCustomOnScreenNotification(
                                    "AutoExploreAnomaly", 
                                    T{rover.name}, 
                                    T{AutoExplore.StringIdBase + 1, "Started exploring an anomaly (via Tunnel)"}, 
                                    "UI/Icons/Notifications/research_2.tga",
                                    false,
                                    {
                                        expiration = 15000
                                    }
                                )
                            end
                            -- this will use the tunnel, after that, the idle state will trigger again
                            rover:InteractWithObject(next, "move")
                        else
                            -- there is no path to destination at the moment, report it as an error
                            if showNotifications == "all" or showNotifications == "problems" then
                                AddCustomOnScreenNotification(
                                    "AutoExploreNoTunnel", 
                                    T{rover.name}, 
                                    T{AutoExplore.StringIdBase + 2, "Unable to find a working tunnel leading to the anomaly"}, 
                                    "UI/Icons/Notifications/research_2.tga",
                                    false,
                                    {
                                        expiration = 15000
                                    }
                                )
                            end
                        end
                    end
                end                    
            end
        end
    end }
end

function OnMsg.ClassesBuilt()
    AutoExploreAddInfoSection()
end

function AutoExploreAddInfoSection()
    -- if the templates have been added, don't add them again
    -- I don't know how to remove them as it breaks the UI with just nil-ing them out
    if table.find(XTemplates.ipRover[1], "UniqueId", "AutoExplore-1") then
        return
    end

    -- enable/disable auto explore
    table.insert(XTemplates.ipRover[1], 
        PlaceObj("XTemplateTemplate", {
            "__context_of_kind", "ExplorerRover",
            "__template", "InfopanelActiveSection",
            "Icon", "UI/Icons/Upgrades/factory_ai_02.tga",
            "Title", T{AutoExplore.StringIdBase + 7, "Auto Explore"},
            "RolloverText", T{AutoExplore.StringIdBase + 8, "Enable/Disable automatic exploration by this rover.<newline><newline>(AutoExplore mod)"},
            "RolloverTitle", T{AutoExplore.StringIdBase + 7, "Auto Explore"},
            "RolloverHint",  T{AutoExplore.StringIdBase + 9, "<left_click> Toggle setting"},
            "OnContextUpdate",
                function(self, context)
                    if context.auto_explore then
                        self:SetTitle(T{AutoExplore.StringIdBase + 10, "Auto Explore (ON)"})
                        self:SetIcon("UI/Icons/Upgrades/factory_ai_02.tga")
                    else
                        self:SetTitle(T{AutoExplore.StringIdBase + 11, "Auto Explore (OFF)"})
                        self:SetIcon("UI/Icons/Upgrades/factory_ai_01.tga")
                    end
                end,
            "UniqueId", "AutoExplore-1"
        }, {
            PlaceObj("XTemplateFunc", {
                "name", "OnActivate(self, context)", 
                "parent", function(parent, context)
                        return parent.parent
                    end,
                "func", function(self, context)
                        context.auto_explore = not context.auto_explore
                        ObjModified(context)
                    end
            }),
        })
    )

    -- current mod location, strip off the Code/AutoExploreScript.lua from the end
    --local this_mod_dir = debug.getinfo(2, "S").source:sub(2, -27)
    local this_mod_dir = Mods["Gfsiaes"].path

    -- enable/disable breakthrough anomalies
    table.insert(XTemplates.ipRover[1], 
        PlaceObj("XTemplateTemplate", {
            "__context_of_kind", "ExplorerRover",
            "__template", "InfopanelActiveSection",
            "Icon", "UI/Icons/Anomaly_Breakthrough.tga",
            "Title", T{AutoExplore.StringIdBase + 19, "Scan Breakthroughs"},
            "RolloverText", T{AutoExplore.StringIdBase + 20, "Enable/Disable automatic scanning of breakthrough type anomalies by this rover.<newline><newline>(AutoExplore mod)"},
            "RolloverTitle", T{AutoExplore.StringIdBase + 21, "Scan Breakthroughs"},
            "RolloverHint",  T{AutoExplore.StringIdBase + 9, "<left_click> Toggle setting"},
            "OnContextUpdate",
                function(self, context)
                    if context.auto_scan_breakthrough then
                        self:SetTitle(T{AutoExplore.StringIdBase + 22, "Scan Breakthroughs (ON)"})
                        self:SetIcon("UI/Icons/Anomaly_Breakthrough.tga")
                    else
                        self:SetTitle(T{AutoExplore.StringIdBase + 23, "Scan Breakthroughs (OFF)"})
                        self:SetIcon(this_mod_dir.."UI/Anomaly_Breakthrough_Off.tga")
                    end
                end,
            "UniqueId", "AutoExplore-2"
        }, {
            PlaceObj("XTemplateFunc", {
                "name", "OnActivate(self, context)", 
                "parent", function(parent, context)
                        return parent.parent
                    end,
                "func", function(self, context)
                        context.auto_scan_breakthrough = not context.auto_scan_breakthrough
                        ObjModified(context)
                    end
            }),
        })
    )

    -- enable/disable technology anomalies
    table.insert(XTemplates.ipRover[1], 
        PlaceObj("XTemplateTemplate", {
            "__context_of_kind", "ExplorerRover",
            "__template", "InfopanelActiveSection",
            "Icon", "UI/Icons/Anomaly_Tech.tga",
            "Title", T{AutoExplore.StringIdBase + 24, "Scan Technologies"},
            "RolloverText", T{AutoExplore.StringIdBase + 25, "Enable/Disable automatic scanning of technology type anomalies by this rover.<newline><newline>(AutoExplore mod)"},
            "RolloverTitle", T{AutoExplore.StringIdBase + 26, "Scan Technologies"},
            "RolloverHint",  T{AutoExplore.StringIdBase + 9, "<left_click> Toggle setting"},
            "OnContextUpdate",
                function(self, context)
                    if context.auto_scan_unlock then
                        self:SetTitle(T{AutoExplore.StringIdBase + 27, "Scan Technologies (ON)"})
                        self:SetIcon("UI/Icons/Anomaly_Tech.tga")
                    else
                        self:SetTitle(T{AutoExplore.StringIdBase + 28, "Scan Technologies (OFF)"})
                        self:SetIcon(this_mod_dir.."UI/Anomaly_Tech_Off.tga")
                    end
                end,
            "UniqueId", "AutoExplore-3"
        }, {
            PlaceObj("XTemplateFunc", {
                "name", "OnActivate(self, context)", 
                "parent", function(parent, context)
                        return parent.parent
                    end,
                "func", function(self, context)
                        context.auto_scan_unlock = not context.auto_scan_unlock
                        ObjModified(context)
                    end
            }),
        })
    )

    -- enable/disable research anomalies
    table.insert(XTemplates.ipRover[1], 
        PlaceObj("XTemplateTemplate", {
            "__context_of_kind", "ExplorerRover",
            "__template", "InfopanelActiveSection",
            "Icon", "UI/Icons/Anomaly_Research.tga",
            "Title", T{AutoExplore.StringIdBase + 29, "Scan Researches"},
            "RolloverText", T{AutoExplore.StringIdBase + 30, "Enable/Disable automatic scanning of research type anomalies by this rover.<newline><newline>(AutoExplore mod)"},
            "RolloverTitle", T{AutoExplore.StringIdBase + 31, "Scan Researches"},
            "RolloverHint",  T{AutoExplore.StringIdBase + 9, "<left_click> Toggle setting"},
            "OnContextUpdate",
                function(self, context)
                    if context.auto_scan_complete then
                        self:SetTitle(T{AutoExplore.StringIdBase + 32, "Scan Researches (ON)"})
                        self:SetIcon("UI/Icons/Anomaly_Research.tga")
                    else
                        self:SetTitle(T{AutoExplore.StringIdBase + 33, "Scan Researches (OFF)"})
                        self:SetIcon(this_mod_dir.."UI/Anomaly_Research_Off.tga")
                    end
                end,
            "UniqueId", "AutoExplore-4"
        }, {
            PlaceObj("XTemplateFunc", {
                "name", "OnActivate(self, context)", 
                "parent", function(parent, context)
                        return parent.parent
                    end,
                "func", function(self, context)
                        context.auto_scan_complete = not context.auto_scan_complete
                        ObjModified(context)
                    end
            }),
        })
    )

    -- enable/disable event anomalies
    table.insert(XTemplates.ipRover[1], 
        PlaceObj("XTemplateTemplate", {
            "__context_of_kind", "ExplorerRover",
            "__template", "InfopanelActiveSection",
            "Icon", "UI/Icons/Anomaly_Event.tga",
            "Title", T{AutoExplore.StringIdBase + 34, "Scan Events"},
            "RolloverText", T{AutoExplore.StringIdBase + 35, "Enable/Disable automatic scanning of event type anomalies by this rover.<newline><newline>(AutoExplore mod)"},
            "RolloverTitle", T{AutoExplore.StringIdBase + 36, "Scan Events"},
            "RolloverHint",  T{AutoExplore.StringIdBase + 9, "<left_click> Toggle setting"},
            "OnContextUpdate",
                function(self, context)
                    if context.auto_scan_aliens then
                        self:SetTitle(T{AutoExplore.StringIdBase + 37, "Scan Events (ON)"})
                        self:SetIcon("UI/Icons/Anomaly_Event.tga")
                    else
                        self:SetTitle(T{AutoExplore.StringIdBase + 38, "Scan Events (OFF)"})
                        self:SetIcon(this_mod_dir.."UI/Anomaly_Event_Off.tga")
                    end
                end,
            "UniqueId", "AutoExplore-5"
        }, {
            PlaceObj("XTemplateFunc", {
                "name", "OnActivate(self, context)", 
                "parent", function(parent, context)
                        return parent.parent
                    end,
                "func", function(self, context)
                        context.auto_scan_aliens = not context.auto_scan_aliens
                        ObjModified(context)
                    end
            }),
        })
    )

    -- enable/disable custom anomalies
    table.insert(XTemplates.ipRover[1], 
        PlaceObj("XTemplateTemplate", {
            "__context_of_kind", "ExplorerRover",
            "__template", "InfopanelActiveSection",
            "Icon", "UI/Icons/Anomaly_Event.tga",
            "Title", T{AutoExplore.StringIdBase + 43, "Scan Custom Anomalies"},
            "RolloverText", T{AutoExplore.StringIdBase + 44, "Enable/Disable automatic scanning of custom anomalies by this rover.<newline><newline>(AutoExplore mod)"},
            "RolloverTitle", T{AutoExplore.StringIdBase + 45, "Scan Custom Anomalies"},
            "RolloverHint",  T{AutoExplore.StringIdBase + 9, "<left_click> Toggle setting"},
            "OnContextUpdate",
                function(self, context)
                    if context.auto_scan_custom then
                        self:SetTitle(T{AutoExplore.StringIdBase + 46, "Scan Custom Anomalies (ON)"})
                        self:SetIcon("UI/Icons/Anomaly_Custom.tga")
                    else
                        self:SetTitle(T{AutoExplore.StringIdBase + 47, "Scan Custom Anomalies (OFF)"})
                        self:SetIcon(this_mod_dir.."UI/Anomaly_Custom_Off.tga")
                    end
                end,
            "UniqueId", "AutoExplore-1"
        }, {
            PlaceObj("XTemplateFunc", {
                "name", "OnActivate(self, context)", 
                "parent", function(parent, context)
                        return parent.parent
                    end,
                "func", function(self, context)
                        context.auto_scan_custom = not context.auto_scan_custom
                        ObjModified(context)
                    end
            }),
        })
    )

end

-- See if ModConfig is installed and that notifications are enabled
function AutoExploreConfigShowNotification()
    if AutoExplore["mod_config_check"] == nil then
        local g_ModConfigLoaded = table.find_value(ModsLoaded, "steam_id", "1340775972") or false
        AutoExplore.mod_config_check = g_ModConfigLoaded
    end
    if AutoExplore.mod_config_check then
        return ModConfig:Get("AutoExplore", "Notifications")
    end
    return "all"
end

-- See if ModConfig is installed and that notifications are enabled
function AutoExploreConfigUpdatePeriod()
    if AutoExplore["mod_config_check"] == nil then
        local g_ModConfigLoaded = table.find_value(ModsLoaded, "steam_id", "1340775972") or false
        AutoExplore.mod_config_check = g_ModConfigLoaded
    end
    if AutoExplore.mod_config_check then
        return ModConfig:Get("AutoExplore", "UpdatePeriod")
    end
    return "1000"
end

-- tunnel handling
function AutoExploreTunnelHandling()
    if AutoExplore["mod_config_check"] == nil then
        local g_ModConfigLoaded = table.find_value(ModsLoaded, "steam_id", "1340775972") or false
        AutoExplore.mod_config_check = g_ModConfigLoaded
    end
    if AutoExplore.mod_config_check then
        return ModConfig:Get("AutoExplore", "TunnelHandling")
    end
    return "off"
end

-- ModConfig signals "ModConfigReady" when it can be manipulated
function OnMsg.ModConfigReady()

    ModConfig:RegisterMod("AutoExplore", -- ID
        T{AutoExplore.StringIdBase + 12, "AutoExplore"}, -- Optional display name, defaults to ID
        T{AutoExplore.StringIdBase + 13, "Explorers automatically go to and research anomalies, keep themselves charged"} -- Optional description
    ) 

    ModConfig:RegisterOption("AutoExplore", "Notifications", {
        name = T{AutoExplore.StringIdBase + 14, "Notifications"},
        desc = T{AutoExplore.StringIdBase + 15, "Enable/Disable notifications of the rovers in Auto mode."},
        type = "enum",
        values = {
            {value = "all", label = T{AutoExplore.StringIdBase + 16, "All"}},
            {value = "problems", label = T{AutoExplore.StringIdBase + 17, "Problems only"}},
            {value = "off", label = T{AutoExplore.StringIdBase + 18, "Off"}}
        },
        default = "all" 
    })

    ModConfig:RegisterOption("AutoExplore", "UpdatePeriod", {
        name = T{AutoExplore.StringIdBase + 39, "Update period"},
        desc = T{AutoExplore.StringIdBase + 40, "Time between trying to find and explore anomalies with rovers<newline>Pick a larger value if your colony has become large and you get lag."},
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
        default = "1000" 
    })

    ModConfig:RegisterOption("AutoExplore", "TunnelHandling", {
        name = T{AutoExplore.StringIdBase + 48, "Tunnel handling"},
        desc = T{AutoExplore.StringIdBase + 49, "Enable the custom tunnel handling logic."},
        type = "enum",
        values = {
            {value = "on", label = T{AutoExplore.StringIdBase + 50, "On"}},
            {value = "off", label = T{AutoExplore.StringIdBase + 18, "Off"}}
        },
        default = "off" 
    })

end
