function OnMsg.GameTimeStart()
    AutoExploreInstallThread()
end

function OnMsg.LoadGame()
    AutoExploreInstallThread()
end

function AutoExploreInstallThread()
    -- PostNewMapLoaded seems to be too early?
    AutoExplorePathFinding:BuildZones()

    CreateGameTimeThread(function()
        while true do
            Sleep(1000)
            AutoExploreHandleRovers() 
        end
    end)
end

function AutoExploreHandleRovers()

    -- first collect up all the zones which have tunnel entrances/exits
    local zonesReachable = AutoExplorePathFinding:GetZonesReachableViaTunnels()

    local showNotifications = AutoExploreConfigShowNotification()

    ForEach { class = "ExplorerRover", exec = function(rover)
        -- Enabled via the InfoPanel UI section "Auto Explore"
        if rover.auto_explore then
            -- Idle explorers only
            if rover.command == "Idle" then

                local roverZone = AutoExplorePathFinding:GetObjectZone(rover)

                -- make sure there is plenty of battery to start with
                if rover.battery_current > rover.battery_max * 0.6 then
                    local obj, distance = FindNearest({ 
                        class = "SubsurfaceAnomaly",
                        filter = function(o, rz)
                            -- use the pathfinding helper to see if the anomaly is reachable
                            return AutoExplorePathFinding:CanReachObject(zonesReachable, rz, o)
                        end
                    }, rover, roverZone)

                    if obj then
                        -- check if the anomaly is in the same zone
                        local objZone = AutoExplorePathFinding:GetObjectZone(obj)

                        if objZone == roverZone then
                            if showNotifications == "all" then
                                AddCustomOnScreenNotification(
                                    "AutoExploreAnomaly", 
                                    T{rover.name}, 
                                    T{"Started exploring an anomaly"}, 
                                    "UI/Icons/Notifications/research_2.tga",
                                    false,
                                    {
                                        expiration = 15000
                                    }
                                )
                            end
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
                                        T{"Started exploring an anomaly (via Tunnel)"}, 
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
                                        T{"Unable to find a working tunnel leading to the anomaly"}, 
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
                else
                    -- otherwise find the nearest power cable to recharge
                    local obj, distance = FindNearest ({ class = "ElectricityGridElement",
                        filter = function(o, rz)
                            -- if not under construction
                            if not IsKindOf(o, "ConstructionSite") then
                                return AutoExplorePathFinding:CanReachObject(zonesReachable, rz, o)                            
                            end
                            return false
                        end
                    }, rover, roverZone)

                    if obj then
                        -- check if the cable is in the same zone
                        local objZone = AutoExplorePathFinding:GetObjectZone(obj)
                        -- yes, we can move there directly
                        if objZone == roverZone then
                            if showNotifications == "all" then
                                AddCustomOnScreenNotification(
                                    "AutoExploreRecharge", 
                                    T{rover.name}, 
                                    T{"Going to recharge"}, 
                                    "UI/Icons/Notifications/research_2.tga",
                                    false,
                                    {
                                        expiration = 15000
                                    }
                                )
                            end
                            rover:InteractWithObject(obj, "recharge")
                        else
                            -- no, it is in another zone which is known to be reachable
                            -- unfortunately, the GoTo is likely unable to find a
                            -- route to it directly and will end up driving against the cliff
                            -- therefore, let's find a path to its zone through the
                            -- tunnel network and go one zone at a time
                            local next = AutoExplorePathFinding:GetNextTunnelTowards(zonesReachable, roverZone, objZone)

                            -- we found it, let's move towards
                            if next then
                                if showNotifications == "all" then
                                    -- notify about it
                                    AddCustomOnScreenNotification(
                                        "AutoExploreRecharge", 
                                        T{rover.name}, 
                                        T{"Going to recharge (via Tunnel)"}, 
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
                                        T{"Unable to find a working tunnel to the recharge spot"}, 
                                        "UI/Icons/Notifications/research_2.tga",
                                        false,
                                        {
                                            expiration = 15000
                                        }
                                    )
                                end
                            end
                        end
                    else
                        if showNotifications == "all" or showNotifications == "problems" then
                            AddCustomOnScreenNotification(
                                "AutoExploreNoRecharge", 
                                T{rover.name}, 
                                T{"Unable to find a recharge spot"}, 
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
    end }
end

function OnMsg.ClassesBuilt()
    AutoExploreAddInfoSection()
end

function AutoExploreAddInfoSection()
    table.insert(XTemplates.ipRover[1], 
        PlaceObj("XTemplateTemplate", {
            "__context_of_kind", "ExplorerRover",
            "__template", "InfopanelActiveSection",
            "Icon", "UI/Icons/Upgrades/factory_ai_02.tga",
            "Title", T{"Auto Explore"},
            "RolloverText", T{"Enable/Disable automatic exploration by this rover.<newline><newline>(AutoExplore mod)"},
            "RolloverTitle", T{"Auto Explore"},
            "RolloverHint",  T{"<left_click> Toggle setting"},
            "OnContextUpdate",
                function(self, context)
                    if context.auto_explore then
                        self:SetTitle(T{"Auto Explore (ON)"})
                        self:SetIcon("UI/Icons/Upgrades/factory_ai_02.tga")
                    else
                        self:SetTitle(T{"Auto Explore (OFF)"})
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
                        context.auto_explore = not context.auto_explore
                        ObjModified(context)
                    end
            })
        })
    )
end

-- See if ModConfig is installed and that notifications are enabled
function AutoExploreConfigShowNotification()
    if rawget(_G, "ModConfig") then
        return ModConfig:Get("AutoExplore", "Notifications")
    end
    return "all"
end

-- ModConfig signals "ModConfigReady" when it can be manipulated
function OnMsg.ModConfigReady()

    ModConfig:RegisterMod("AutoExplore", -- ID
        T{"AutoExplore"}, -- Optional display name, defaults to ID
        T{"Explorers automatically go to and research anomalies, keep themselves charged"} -- Optional description
    ) 

    ModConfig:RegisterOption("AutoExplore", "Notifications", {
        name = T{"Notifications"},
        desc = T{"Enable/Disable notifications of the rovers in Auto mode."},
        type = "enum",
        values = {
            {value = "all", label = T{"All"}},
            {value = "problems", label = T{"Problems only"}},
            {value = "off", label = T{"Off"}}
        },
        default = "all" 
    })
   
end
