
-- Mod's global
AutoGatherTransport = { }
-- Base ID for translatable text
AutoGatherTransport.StringIdBase = 20182401

-- install handler threads upon newgame
function OnMsg.GameTimeStart()
    AutoGatherInstallThread()
end

-- install handler thread upon loading a saved game
function OnMsg.LoadGame()
    AutoGatherInstallThread()
end

-- prevent the mod to run on the new game screen
function OnMsg.ChangeMapDone(map)
    if map == "PreGame" then
        return 
    end
    AutoGatherPathFinding.ingameMap = true
end

function AutoGatherInstallThread()
    if AutoGatherPathFinding.ingameMap then
        AutoGatherPathFinding:BuildZones()
        AutoGatherPathFinding.zonesBuilt = true;
    end

    -- make sure the handler thread is installed at most once
    if UICity and not IsValidThread(UICity.AutoGatherTransportThread_GameTime) then
        UICity.AutoGatherTransportThread_GameTime = CreateGameTimeThread(function()
            while true do
                -- detect script reload and rebuild the zones
                if AutoGatherPathFinding.ingameMap and not AutoGatherPathFinding.zonesBuilt 
                    and ActiveGameMap and ActiveGameMap.object_hex_grid
                then
                    AutoGatherPathFinding:BuildZones()
                    AutoGatherPathFinding.zonesBuilt = true;
                end

                AutoGatherHandleTransports()
                local period = AutoGatherConfigUpdatePeriod()
                Sleep(tonumber(period))
            end
        end)
    end
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

-- enumerate objects of a given City label
function AutoGatherForEachLabel(label, func)
    for _, obj in ipairs(UICity.labels[label] or empty_table) do
        if func(obj) == "break" then
            return
        end
    end
end


function AutoGatherHandleTransports()
    -- game is not yet initialized
    if not ActiveMapData.GameLogic then
        return
    end
    -- should the logic try and work out paths via tunnels?
    local tunnelHandling = AutoGatherTunnelHandling() == "on";

    -- first collect up all the zones which have tunnel entrances/exits
    local zonesReachable = AutoGatherPathFinding:GetZonesReachableViaTunnels()

    local deposits = GetObjects { 
        classes = "SurfaceDepositMetals,SurfaceDepositConcrete,SurfaceDepositPolymers,SurfaceDepositGroup,WasteRockStockpileBase" 
    }

    --[[
    local deposits = { }

    for _, obj in pairs(UICity.labels.SurfaceDeposit) do
        deposits[#deposits + 1] = obj
    end

    for _, obj in pairs(SurfaceDepositGroups) do
        if obj.holder then
            deposits[#deposits + 1] = obj.holder
        end
    end
    --]]

    AutoGatherForEachLabel("RCTransport", function(rover)
        -- Enabled via the InfoPanel UI section "Auto Gather"
        if rover.auto_gather then

            local roverZone = AutoGatherPathFinding:GetObjectZone(rover) or 0

            -- Idle transporters only
            if rover.command == "Idle" then
                    -- if inventory is empty, search for a resource
                    if rover:GetStoredAmount() == 0 then
                        AutoGatherFindDeposit(rover, zonesReachable, roverZone, deposits, tunnelHandling)
                    else
                        AutoGatherUnloadContent(rover, zonesReachable, roverZone, tunnelHandling)
                    end
            end

            if rover.command == "LoadingComplete" then
                AutoGatherUnloadContent(rover, zonesReachable, roverZone, tunnelHandling)
            end
        end
    end)
end

-- Dedicated actions

function AutoGatherFindDeposit(rover, zonesReachable, roverZone, deposits, tunnelHandling)
    local showNotifications = AutoGatherConfigShowNotification()

    -- default enable gather filters
    if rover.gather_metal == nil then
        rover.gather_metal = true
        rover.gather_polymer = true
        rover.gather_wasterock = true
    end

    local obj, distance = AutoGatherFindNearest(deposits,
        function(o, rz)
            -- use the pathfinding helper to see if the deposit is reachable
            if AutoGatherPathFinding:CanReachObject(zonesReachable, roverZone, o) then
                -- consider filtering based on settings
                local targetObject = o
                -- surface deposit group type is one of its component's type
                if IsKindOf(o, "SurfaceDepositGroup") then
                    -- must target its components
                    targetObject = o.group[1]
                end
                if IsKindOf(targetObject, "SurfaceDepositMetals") then
                    return rover.gather_metal
                end
                if IsKindOf(targetObject, "SurfaceDepositPolymers") then
                    return rover.gather_polymer
                end
                if IsKindOf(targetObject, "WasteRockStockpileBase") 
                        and targetObject.resource ~= "BlackCube" 
                        and not IsKindOf(targetObject, "Unit")
                        and not targetObject:GetParent()        -- dump sites have raw waste rocks apparently as objects
                then
                    if rover.gather_wasterock and rover.auto_unload_at then
                        -- exclusion zone around auto_unload_at
                        local p = targetObject:GetPos()
                        local dist = (rover.auto_unload_at:x() - p:x())^2 + (rover.auto_unload_at:y() - p:y())^2
                        local limit = 3000 ^ 2
                        return dist > limit
                    end
                end
            end
            return false
        end,
        rover)

    if obj then
        -- check if the resource is in the same zone
        local objZone = AutoGatherPathFinding:GetObjectZone(obj)

        if objZone == roverZone or not tunnelHandling then
            if showNotifications == "all" then
                AddCustomOnScreenNotification(
                    "AutoGatherTransportGather", 
                    T{rover.name}, 
                    --T{AutoGatherTransport.StringIdBase, "Started gathering resource(s) at "}..(obj:GetPos():x())..", "..(obj:GetPos():y()).." <> "..distance, 
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

function AutoGatherUnloadContent(rover, zonesReachable, roverZone, tunnelHandling)
    local showNotifications = AutoGatherConfigShowNotification()

    -- if unload target set, dump there
    if rover.auto_unload_at then
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
        if objZone == roverZone or not tunnelHandling then
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


-- Setup UI

function OnMsg.ClassesBuilt()
    AutoGatherAddInfoSection()
end

function AutoGatherAddInfoSection()
    -- if the templates have been added, don't add them again
    -- I don't know how to remove them as it breaks the UI with just nil-ing them out
    if table.find(XTemplates.ipRover[1], "UniqueId", "AutoGatherTransport-1") then
        return
    end

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
                "UniqueId", "AutoGatherTransport-1"
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

    --local this_mod_dir = debug.getinfo(2, "S").source:sub(2, -35)
    local this_mod_dir = CurrentModPath -- Mods["Zq7BVyy"].path

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
                    self:SetTitle(T{AutoGatherTransport.StringIdBase + 32, "Auto unload at: " }..(coord:x())..", "..(coord:y()))
                    self:SetIcon(this_mod_dir.."UI/unload_at.tga")
                else
                    self:SetTitle(T{AutoGatherTransport.StringIdBase + 33, "Auto unload at: nearest"})
                    self:SetIcon(this_mod_dir.."UI/unload_at_nearest.tga")
                end
            end,
            "UniqueId","AutoGatherTransport-2" -- Mod's steamid + "2"
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

    -- Filter for metal deposits
    table.insert(XTemplates.ipRover[1], 
        PlaceObj("XTemplateTemplate", {
            "__context_of_kind", "RCTransport",
            "__template", "InfopanelActiveSection",
            "Icon", "UI/Icons/Upgrades/factory_ai_02.tga",
            "Title", T{AutoGatherTransport.StringIdBase + 40, "Gather Metal"},
            "RolloverText", T{AutoGatherTransport.StringIdBase + 41, "Enable/Disable the automatic gathering of metal deposits by this rover.<newline><newline>(AutoGatherTransport mod)"},
            "RolloverTitle", T{AutoGatherTransport.StringIdBase + 42, "Gather Metal"},
            "RolloverHint",  T{AutoGatherTransport.StringIdBase + 43, "<left_click> Toggle setting"},
            "OnContextUpdate",
                function(self, context)
                    -- setup default
                    if context.gather_metal == nil then
                        context.gather_metal = true
                    end
                    if context.gather_metal then
                        self:SetTitle(T{AutoGatherTransport.StringIdBase + 44, "Gather Metal (ON)"})
                        self:SetIcon(this_mod_dir.."UI/res_metal_on.tga")
                    else
                        self:SetTitle(T{AutoGatherTransport.StringIdBase + 45, "Gather Metal (OFF)"})
                        self:SetIcon(this_mod_dir.."UI/res_metal_off.tga")
                    end
                end,
                "UniqueId", "AutoGatherTransport-3"
        }, {
            PlaceObj("XTemplateFunc", {
                "name", "OnActivate(self, context)", 
                "parent", function(parent, context)
                        return parent.parent
                    end,
                "func", function(self, context)
                        context.gather_metal = not context.gather_metal
                        ObjModified(context)
                    end
            })
        })
    )
    -- Filter for polymer deposits
    table.insert(XTemplates.ipRover[1], 
        PlaceObj("XTemplateTemplate", {
            "__context_of_kind", "RCTransport",
            "__template", "InfopanelActiveSection",
            "Icon", "UI/Icons/Upgrades/factory_ai_02.tga",
            "Title", T{AutoGatherTransport.StringIdBase + 50, "Gather Polymer"},
            "RolloverText", T{AutoGatherTransport.StringIdBase + 51, "Enable/Disable the automatic gathering of polymer deposits by this rover.<newline><newline>(AutoGatherTransport mod)"},
            "RolloverTitle", T{AutoGatherTransport.StringIdBase + 52, "Gather Polymer"},
            "RolloverHint",  T{AutoGatherTransport.StringIdBase + 53, "<left_click> Toggle setting"},
            "OnContextUpdate",
                function(self, context)
                    -- setup default
                    if context.gather_polymer == nil then
                        context.gather_polymer = true
                    end
                    if context.gather_polymer then
                        self:SetTitle(T{AutoGatherTransport.StringIdBase + 54, "Gather Polymer (ON)"})
                        self:SetIcon(this_mod_dir.."UI/res_polymer_on.tga")
                    else
                        self:SetTitle(T{AutoGatherTransport.StringIdBase + 55, "Gather Polymer (OFF)"})
                        self:SetIcon(this_mod_dir.."UI/res_polymer_off.tga")
                    end
                end,
                "UniqueId", "AutoGatherTransport-4"
        }, {
            PlaceObj("XTemplateFunc", {
                "name", "OnActivate(self, context)", 
                "parent", function(parent, context)
                        return parent.parent
                    end,
                "func", function(self, context)
                        context.gather_polymer = not context.gather_polymer
                        ObjModified(context)
                    end
            })
        })
    )

    -- Filter for waste rock deposits
    table.insert(XTemplates.ipRover[1], 
        PlaceObj("XTemplateTemplate", {
            "__context_of_kind", "RCTransport",
            "__template", "InfopanelActiveSection",
            "Icon", "UI/Icons/Upgrades/factory_ai_02.tga",
            "Title", T{AutoGatherTransport.StringIdBase + 100, "Gather Waste Rock"},
            "RolloverText", T{AutoGatherTransport.StringIdBase + 101, "Enable/Disable the automatic gathering of waste rock deposits by this rover.<newline>Warning: it requires a custom drop location to be set!<newline><newline>(AutoGatherTransport mod)"},
            "RolloverTitle", T{AutoGatherTransport.StringIdBase + 102, "Gather Waste Rock"},
            "RolloverHint",  T{AutoGatherTransport.StringIdBase + 103, "<left_click> Toggle setting"},
            "OnContextUpdate",
                function(self, context)
                    -- setup default
                    if context.gather_wasterock == nil then
                        context.gather_wasterock = true
                    end
                    if context.gather_wasterock then
                        self:SetTitle(T{AutoGatherTransport.StringIdBase + 104, "Gather Waste Rock (ON)"})
                        self:SetIcon(this_mod_dir.."UI/res_wasterock_on.tga")
                    else
                        self:SetTitle(T{AutoGatherTransport.StringIdBase + 1055, "Gather Waste Rock (OFF)"})
                        self:SetIcon(this_mod_dir.."UI/res_wasterock_off.tga")
                    end
                end,
                "UniqueId", "AutoGatherTransport-4"
        }, {
            PlaceObj("XTemplateFunc", {
                "name", "OnActivate(self, context)", 
                "parent", function(parent, context)
                        return parent.parent
                    end,
                "func", function(self, context)
                        context.gather_wasterock = not context.gather_wasterock
                        ObjModified(context)
                    end
            })
        })
    )
end

-- Setup ModConfig UI

-- Check if any of the ModConfig mods are installed
function ModConfigAvailable()
    -- ModConfig old
    local found = table.find_value(ModsLoaded, "steam_id", "1340775972") or
    -- ModConfig reborn
                  table.find_value(ModsLoaded, "steam_id", "1542863522") or false
    return found    
end


-- Check if the ModConfig mod has been loaded and is ready -> returns true
function AutoGatherModConfigAvailable()
    if AutoGatherTransport["mod_config_check"] == nil then
        local g_ModConfigLoaded = ModConfigAvailable()
        AutoGatherTransport.mod_config_check = g_ModConfigLoaded
    end
    return AutoGatherTransport.mod_config_check and ModConfig:IsReady()
end

-- Read a specific configuration setting or return the default value
function AutoGatherGetConfig(configName, defaultValue)
    if AutoGatherModConfigAvailable() then
        local v = ModConfig:Get("AutoGatherTransport", configName)
        if v ~= nil then
            return v
        end
    end
    return defaultValue
end

-- See if ModConfig is installed and that notifications are enabled
function AutoGatherConfigShowNotification()
    return AutoGatherGetConfig("Notifications", "problems")
end

-- See if ModConfig is installed and that notifications are enabled
function AutoGatherConfigUpdatePeriod()
    return AutoGatherGetConfig("UpdatePeriod", "1000")
end

-- tunnel handling
function AutoGatherTunnelHandling()
    return AutoGatherGetConfig("TunnelHandling", "off")
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
        desc = T{AutoGatherTransport.StringIdBase + 25, "Time between trying to find and gather deposits with rovers<newline>Pick a larger value if your colony has become large and you get lag."},
        type = "enum",
        values = {
            {value = "1000", label = T{"1 s"}},
            {value = "1500", label = T{"1.5 s"}},
            {value = "2000", label = T{"2 s"}},
            {value = "2500", label = T{"2.5 s"}},
            {value = "3000", label = T{"3 s"}},
            {value = "5000", label = T{"5 s"}},
            {value = "10000", label = T{"10 s"}},
            {value = "15000", label = T{"15 s"}},
            {value = "20000", label = T{"20 s"}},
            {value = "30000", label = T{"30 s"}},
        },
        default = "1000" 
    })

    ModConfig:RegisterOption("AutoGatherTransport", "TunnelHandling", {
        name = T{AutoGatherTransport.StringIdBase + 34, "Tunnel handling"},
        desc = T{AutoGatherTransport.StringIdBase + 35, "Enable the custom tunnel handling logic."},
        type = "enum",
        values = {
            {value = "on", label = T{AutoGatherTransport.StringIdBase + 36, "On"}},
            {value = "off", label = T{AutoGatherTransport.StringIdBase + 23, "Off"}}
        },
        default = "off" 
    })

end