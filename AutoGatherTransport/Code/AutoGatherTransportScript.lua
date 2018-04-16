function OnMsg.GameTimeStart()
    AutoGatherInstallThread()
end

function OnMsg.LoadGame()
    AutoGatherInstallThread()
end

function AutoGatherInstallThread()
    AutoGatherPathFinding:BuildZones()

    CreateGameTimeThread(function()
        while true do
            AutoGatherHandleTransports()
            local period = AutoGatherConfigUpdatePeriod()
            Sleep(tonumber(period))
        end
    end)
end

-- find the nearest object to the target based on additional filtering
function AutoGatherFindNearest(objects, filter, target)
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

function AutoGatherHandleTransports()
    -- first collect up all the zones which have tunnel entrances/exits
    local zonesReachable = AutoGatherPathFinding:GetZonesReachableViaTunnels()
    -- percentage of remaining battery to trigger recharge
    local threshold = tonumber(AutoGatherBatteryThreshold())

    local deposits = GetObjects { classes = "SurfaceDepositMetals,SurfaceDepositConcrete,SurfaceDepositPolymers,SurfaceDepositGroup" }

    ForEach { class = "RCTransport", exec = function(rover)
        -- Enabled via the InfoPanel UI section "Auto Gather"
        if rover.auto_gather then

            local roverZone = AutoGatherPathFinding:GetObjectZone(rover) or 0

            -- Idle transporters only
            if rover.command == "Idle" then
                if rover.battery_current > rover.battery_max * threshold / 100.0 then

                    -- if inventory is empty, search for a resource
                    if rover:GetStoredAmount() == 0 then
                        AutoGatherFindDeposit(rover, zonesReachable, roverZone, deposits)
                    else
                        AutoGatherUnloadContent(rover, zonesReachable, roverZone)
                    end
                else
                    AutoGatherGoRecharge(rover, zonesReachable, roverZone)
                end
            end

            if rover.command == "LoadingComplete" then
                if rover.battery_current > rover.battery_max * 0.2 then
                    AutoGatherUnloadContent(rover, zonesReachable, roverZone)
                else
                    AutoGatherGoRecharge(rover, zonesReachable, roverZone)
                end
            end
        end
    end }
end

-- Mod's global
AutoGatherTransport = { }
-- Base ID for translatable text
AutoGatherTransport.StringIdBase = 20182401

-- Dedicated actions

function AutoGatherFindDeposit(rover, zonesReachable, roverZone, deposits)
    local showNotifications = AutoGatherConfigShowNotification()

    local obj, distance = AutoGatherFindNearest(deposits,
        function(o, rz)
            -- use the pathfinding helper to see if the anomaly is reachable
            return AutoGatherPathFinding:CanReachObject(zonesReachable, roverZone, o)
        end,
        rover)

    if obj then
        -- check if the resource is in the same zone
        local objZone = AutoGatherPathFinding:GetObjectZone(obj)

        if objZone == roverZone then
            if showNotifications == "all" then
                AddCustomOnScreenNotification(
                    "AutoGatherTransportGather", 
                    T{rover.name}, 
                    T{AutoGatherTransport.StringIdBase, "Started gathering resource(s)"}, 
                    "UI/Icons/Notifications/research_2.tga",
                    false,
                    {
                        expiration = 15000
                    }
                )
            end

            -- surface groups can't be targeted en-masse
            if IsKindOf(obj, "SurfaceDepositGroup") then
                -- must target its components
                local subDeposit = obj.group[1]
                rover:InteractWithObject(subDeposit, "load")
            else
                rover:InteractWithObject(obj, "load")
            end
        else
            -- It is not in the same zone. Unfortunately, the "move" command behind "analyze" may
            -- not use a tunnel if available, we have to manually travel
            -- the chain of tunnels to get to the same zone
            local next = AutoGatherPathFinding:GetNextTunnelTowards(zonesReachable, roverZone, objZone)

            -- we found it, let's move towards it
            if next then
                if showNotifications == "all" then
                    -- notify about it
                    AddCustomOnScreenNotification(
                        "AutoGatherTransport", 
                        T{rover.name}, 
                        T{AutoGatherTransport.StringIdBase + 1, "Started gathering resource(s) (via Tunnel)"}, 
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
                        "AutoGatherTransportNoTunnel", 
                        T{rover.name}, 
                        T{AutoGatherTransport.StringIdBase + 2, "Unable to find a working tunnel leading to the resource(s)"}, 
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

function AutoGatherUnloadContent(rover, zonesReachable, roverZone)
    local showNotifications = AutoGatherConfigShowNotification()

    -- if unload target set, dump there
    if rover.auto_unload_at then
        rover:SetCommand("DumpCargo", rover.auto_unload_at, "all")
        return
    end

    -- otherwise, find the nearest depot
    local obj, distance = FindNearest({ 
        class = "UniversalStorageDepot",
        filter = function(o, rz)
            if not IsKindOf(o, "SupplyRocket") then
                return AutoGatherPathFinding:CanReachObject(zonesReachable, rz, o)
            end
            return false
        end
    }, rover, roverZone)

    if obj then
        -- check if the cable is in the same zone
        local objZone = AutoGatherPathFinding:GetObjectZone(obj)
        -- yes, we can move there directly
        if objZone == roverZone then
            if showNotifications == "all" then
                AddCustomOnScreenNotification(
                    "AutoGatherTransportDump", 
                    T{rover.name}, 
                    T{AutoGatherTransport.StringIdBase + 3, "Started dumping resource(s)"}, 
                    "UI/Icons/Notifications/research_2.tga",
                    false,
                    {
                        expiration = 15000
                    }
                )
            end
            -- This brings up the select resource dialog and needs user interaction
            -- rover:InteractWithObject(obj, "unload")
            rover:SetCommand("DumpCargo", obj:GetPos(), "all")
        else
            -- no, it is in another zone which is known to be reachable
            -- unfortunately, the GoTo is likely unable to find a
            -- route to it directly and will end up driving against the cliff
            -- therefore, let's find a path to its zone through the
            -- tunnel network and go one zone at a time
            local next = AutoGatherPathFinding:GetNextTunnelTowards(zonesReachable, roverZone, objZone)

            -- we found it, let's move towards
            if next then
                if showNotifications == "all" then
                    -- notify about it
                    AddCustomOnScreenNotification(
                        "AutoGatherTransportDump", 
                        T{rover.name}, 
                        T{AutoGatherTransport.StringIdBase + 4, "Started dumping resource(s) (via Tunnel)"}, 
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
                        "AutoGatherTransportNoTunnel", 
                        T{rover.name}, 
                        T{AutoGatherTransport.StringIdBase + 5, "Unable to find a working tunnel to dump resource(s)"}, 
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
                "AutoGatherTransportDumpError", 
                T{rover.name}, 
                T{AutoGatherTransport.StringIdBase + 6, "Unable to find a Universal Storage Depot"}, 
                "UI/Icons/Notifications/research_2.tga",
                false,
                {
                    expiration = 15000
                }
            )
        end
    end
end

function AutoGatherGoRecharge(rover, zonesReachable, roverZone)
    local showNotifications = AutoGatherConfigShowNotification()

    -- otherwise find the nearest power cable to recharge
    local obj, distance = FindNearest ({ class = "ElectricityGridElement",
        filter = function(o, rz)
            -- if not under construction
            if not IsKindOf(o, "ConstructionSite") then
                return AutoGatherPathFinding:CanReachObject(zonesReachable, rz, o)                            
            end
            return false
        end
    }, rover, roverZone)

    if obj then
        -- check if the cable is in the same zone
        local objZone = AutoGatherPathFinding:GetObjectZone(obj)
        -- yes, we can move there directly
        if objZone == roverZone then
            if showNotifications == "all" then
                AddCustomOnScreenNotification(
                    "AutoGatherTransportRecharge", 
                    T{rover.name}, 
                    T{AutoGatherTransport.StringIdBase + 7, "Going to recharge"}, 
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
            local next = AutoGatherPathFinding:GetNextTunnelTowards(zonesReachable, roverZone, objZone)

            -- we found it, let's move towards
            if next then
                if showNotifications == "all" then
                    -- notify about it
                    AddCustomOnScreenNotification(
                        "GatherTransportRecharge", 
                        T{rover.name}, 
                        T{AutoGatherTransport.StringIdBase + 8, "Going to recharge (via Tunnel)"}, 
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
                        "GatherTransportNoTunnel", 
                        T{rover.name}, 
                        T{AutoGatherTransport.StringIdBase + 9, "Unable to find a working tunnel to the recharge spot"}, 
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
                "GatherTransportNoRecharge", 
                T{rover.name}, 
                T{AutoGatherTransport.StringIdBase + 10, "Unable to find a recharge spot"}, 
                "UI/Icons/Notifications/research_2.tga",
                false,
                {
                    expiration = 15000
                }
            )
        end
    end
end

-- Setup UI

function OnMsg.ClassesBuilt()
    AutoGatherAddInfoSection()
end

function AutoGatherAddInfoSection()
    table.insert(XTemplates.ipRover[1], 
        PlaceObj("XTemplateTemplate", {
            "__context_of_kind", "RCTransport",
            "__template", "InfopanelActiveSection",
            "Icon", "UI/Icons/Upgrades/factory_ai_02.tga",
            "Title", T{AutoGatherTransport.StringIdBase + 11, "Auto Gather"},
            "RolloverText", T{AutoGatherTransport.StringIdBase + 12, "Enable/Disable automatic gathering of surface deposits by this rover.<newline><newline>(AutoGatherTransport mod)"},
            "RolloverTitle", T{AutoGatherTransport.StringIdBase + 13, "Auto Gather"},
            "RolloverHint",  T{AutoGatherTransport.StringIdBase + 14, "<left_click> Toggle setting"},
            "OnContextUpdate",
                function(self, context)
                    if context.auto_gather then
                        self:SetTitle(T{AutoGatherTransport.StringIdBase + 15, "Auto Gather (ON)"})
                        self:SetIcon("UI/Icons/Upgrades/factory_ai_02.tga")
                    else
                        self:SetTitle(T{AutoGatherTransport.StringIdBase + 16, "Auto Gather (OFF)"})
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
                        context.auto_gather = not context.auto_gather
                        ObjModified(context)
                    end
            })
        })
    )

        -- current mod location, strip off the Code/AutoGatherTransportScript.lua from the end
    local this_mod_dir = debug.getinfo(2, "S").source:sub(2, -35)

    table.insert(XTemplates.ipRover[1], 
    PlaceObj("XTemplateTemplate", {
        "__context_of_kind", "RCTransport",
        "__template", "InfopanelActiveSection",
        "Icon", this_mod_dir.."UI/unload_at_nearest.tga",
        "Title", T{AutoGatherTransport.StringIdBase + 28, "Auto unload at"},
        "RolloverText", T{AutoGatherTransport.StringIdBase + 29, "Click and select the screen center location to unload to, click again to clear the unload location"},
        "RolloverTitle", T{AutoGatherTransport.StringIdBase + 30, "Auto unload at"},
        "RolloverHint",  T{AutoGatherTransport.StringIdBase + 31, "<left_click> Select screen center as the unload location or clear previous location"},
        "OnContextUpdate",
            function(self, context)
                local coord = context.auto_unload_at
                if coord then
                    self:SetTitle(T{AutoGatherTransport.StringIdBase + 32, "Auto unload at: "..(coord:x())..", "..(coord:y()) })
                    self:SetIcon(this_mod_dir.."UI/unload_at.tga")
                else
                    self:SetTitle(T{AutoGatherTransport.StringIdBase + 33, "Auto unload at: nearest"})
                    self:SetIcon(this_mod_dir.."UI/unload_at_nearest.tga")
                end
            end,
    }, {
        PlaceObj("XTemplateFunc", {
            "name", "OnActivate(self, context)", 
            "parent", function(parent, context)
                    return parent.parent
                end,
            "func", function(self, context)
                    if context.auto_unload_at then
                        context["auto_unload_at"] = nil
                    else
                        context.auto_unload_at = GetTerrainCursorXY(UIL.GetScreenSize()/2)
                    end
                    ObjModified(context)
                end
        })
    })
)

end

-- Setup ModConfig UI

-- See if ModConfig is installed and that notifications are enabled
function AutoGatherConfigShowNotification()
    if rawget(_G, "ModConfig") then
        return ModConfig:Get("AutoGatherTransport", "Notifications")
    end
    return "all"
end


-- See if ModConfig is installed and that notifications are enabled
function AutoGatherConfigUpdatePeriod()
    if rawget(_G, "ModConfig") then
        return ModConfig:Get("AutoGatherTransport", "UpdatePeriod")
    end
    return "1000"
end

-- Battery threshold
function AutoGatherBatteryThreshold()
    if rawget(_G, "ModConfig") then
        return ModConfig:Get("AutoGatherTransport", "BatteryThreshold")
    end
    return "60"
end

-- ModConfig signals "ModConfigReady" when it can be manipulated
function OnMsg.ModConfigReady()

    ModConfig:RegisterMod("AutoGatherTransport", -- ID
        T{AutoGatherTransport.StringIdBase + 17, "AutoGatherTransport"}, -- Optional display name, defaults to ID
        T{AutoGatherTransport.StringIdBase + 18, "Transports automatically gather surface deposits and bring them next to a Universal Depot, keep themselves charged"} -- Optional description
    ) 

    ModConfig:RegisterOption("AutoGatherTransport", "Notifications", {
        name = T{AutoGatherTransport.StringIdBase + 19, "Notifications"},
        desc = T{AutoGatherTransport.StringIdBase + 20, "Enable/Disable notifications of the rovers in Auto mode."},
        type = "enum",
        values = {
            {value = "all", label = T{AutoGatherTransport.StringIdBase + 21, "All"}},
            {value = "problems", label = T{AutoGatherTransport.StringIdBase + 22, "Problems only"}},
            {value = "off", label = T{AutoGatherTransport.StringIdBase + 23, "Off"}}
        },
        default = "all" 
    })
    
    ModConfig:RegisterOption("AutoGatherTransport", "UpdatePeriod", {
        name = T{AutoGatherTransport.StringIdBase + 24, "Update period"},
        desc = T{AutoGatherTransport.StringIdBase + 25, "Time between trying to find and explore anomalies with rovers<newline>Pick a larger value if your colony has become large and you get lag."},
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
        default = "100" 
    })

    ModConfig:RegisterOption("AutoGatherTransport", "BatteryThreshold", {
        name = T{AutoGatherTransport.StringIdBase + 26, "Battery threshold"},
        desc = T{AutoGatherTransport.StringIdBase + 27, "Percentage of battery charge below which the rover will go recharge itself."},
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
        default = "60" 
    })

end