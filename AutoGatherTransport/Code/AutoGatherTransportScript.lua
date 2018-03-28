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
            Sleep(300)
            AutoGatherHandleTransports() 
        end
    end)
end

function AutoGatherHandleTransports()
    -- first collect up all the zones which have tunnel entrances/exits
    local zonesReachable = AutoGatherPathFinding:GetZonesReachableViaTunnels()

    ForEach { class = "RCTransport", exec = function(rover)
        -- Enabled via the InfoPanel UI section "Auto Gather"
        if rover.auto_gather then

            local roverZone = AutoGatherPathFinding:GetObjectZone(rover)

            -- Idle transporters only
            if rover.command == "Idle" then
                if rover.battery_current > rover.battery_max * 0.6 then

                    -- if inventory is empty, search for a resource
                    if rover:GetStoredAmount() == 0 then
                        AutoGatherFindDeposit(rover, zonesReachable, roverZone)
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

-- Dedicated actions

function AutoGatherFindDeposit(rover, zonesReachable, roverZone)
    local showNotifications = AutoGatherConfigShowNotification()

    local obj, distance = FindNearest({ 
        classes = "SurfaceDepositMetals,SurfaceDepositConcrete,SurfaceDepositPolymers",
        filter = function(o, rz)
            -- use the pathfinding helper to see if the anomaly is reachable
            return AutoGatherPathFinding:CanReachObject(zonesReachable, rz, o)
        end
    }, rover, roverZone)

    if obj then
        -- check if the resource is in the same zone
        local objZone = AutoGatherPathFinding:GetObjectZone(obj)

        if objZone == roverZone then
            if showNotifications == "all" then
                AddCustomOnScreenNotification(
                    "AutoGatherTransportGather", 
                    T{rover.name}, 
                    T{"Started gathering resource(s)"}, 
                    "UI/Icons/Notifications/research_2.tga",
                    false,
                    {
                        expiration = 15000
                    }
                )
            end

            rover:InteractWithObject(obj, "load")
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
                        T{"Started gathering resource(s) (via Tunnel)"}, 
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
                        T{"Unable to find a working tunnel leading to the resource(s)"}, 
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
                    T{"Started dumping resource(s)"}, 
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
                        T{"Started dumping resource(s) (via Tunnel)"}, 
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
                        T{"Unable to find a working tunnel to dump resource(s)"}, 
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
                T{"Unable to find a Universal Storage Depot"}, 
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
            local next = AutoGatherPathFinding:GetNextTunnelTowards(zonesReachable, roverZone, objZone)

            -- we found it, let's move towards
            if next then
                if showNotifications == "all" then
                    -- notify about it
                    AddCustomOnScreenNotification(
                        "GatherTransportRecharge", 
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
                        "GatherTransportNoTunnel", 
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
                "GatherTransportNoRecharge", 
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
            "Title", T{"Auto Gather"},
            "RolloverText", T{"Enable/Disable automatic gathering of surface deposits by this rover.<newline><newline>(AutoGatherTransport mod)"},
            "RolloverTitle", T{"Auto Gather"},
            "RolloverHint",  T{"<left_click> Toggle setting"},
            "OnContextUpdate",
                function(self, context)
                    if context.auto_gather then
                        self:SetTitle(T{"Auto Gather (ON)"})
                        self:SetIcon("UI/Icons/Upgrades/factory_ai_02.tga")
                    else
                        self:SetTitle(T{"Auto Gather (OFF)"})
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
end

-- Setup ModConfig UI

-- See if ModConfig is installed and that notifications are enabled
function AutoGatherConfigShowNotification()
    if rawget(_G, "ModConfig") then
        return ModConfig:Get("AutoGatherTransport", "Notifications")
    end
    return "all"
end

-- ModConfig signals "ModConfigReady" when it can be manipulated
function OnMsg.ModConfigReady()

    ModConfig:RegisterMod("AutoGatherTransport", -- ID
        T{"AutoGatherTransport"}, -- Optional display name, defaults to ID
        T{"Transports automatically gather surface deposits and bring them next to a Universal Depot, keep themselves charged"} -- Optional description
    ) 

    ModConfig:RegisterOption("AutoGatherTransport", "Notifications", {
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