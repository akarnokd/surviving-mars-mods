function OnMsg.GameTimeStart()
    AutoGatherInstallThread()
end

function OnMsg.LoadGame()
    AutoGatherInstallThread()
end

function AutoGatherInstallThread()
    CreateGameTimeThread(function()
        while true do
            Sleep(300)
            AutoGatherHandleTransports() 
        end
    end)
end

function AutoGatherHandleTransports()
    ForEach { class = "RCTransport", exec = function(rover)
        -- Enabled via the InfoPanel UI section "Auto Gather"
        if rover.auto_gather then
            -- Idle transporters only
            if rover.command == "Idle" then
                if rover.battery_current > rover.battery_max * 0.6 then

                    -- if inventory is empty, search for a resource
                    if rover:GetStoredAmount() == 0 then
                        AutoGatherFindDeposit(rover)
                    else
                        AutoGatherUnloadContent(rover)
                    end
                else
                    AutoGatherGoRecharge(rover)
                end
            end

            if rover.command == "LoadingComplete" then
                if rover.battery_current > rover.battery_max * 0.2 then
                    AutoGatherUnloadContent(rover)
                else
                    AutoGatherGoRecharge(rover)
                end
            end
        end
    end }
end

function AutoGatherFindDeposit(rover)
    local showNotifications = AutoGatherConfigShowNotification()

    local obj, distance = FindNearest({ 
        classes = "SurfaceDepositMetals,SurfaceDepositConcrete,SurfaceDepositPolymers"
    }, rover)

    if obj then
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
    end
end

function AutoGatherUnloadContent(rover)
    local showNotifications = AutoGatherConfigShowNotification()

    local obj, distance = FindNearest({ 
        class = "UniversalStorageDepot",
        filter = function(o)
            return not IsKindOf(o, "SupplyRocket")
        end
    }, rover)

    if obj then
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

function AutoGatherGoRecharge(rover)
    local showNotifications = AutoGatherConfigShowNotification()

    -- otherwise find the nearest power cable to recharge
    local obj, distance = FindNearest ({ class = "ElectricityGridElement",
        filter = function(obj, ...)
            return not IsKindOf(obj, "ConstructionSite")
        end
    }, rover)

    if obj then
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
        if showNotifications == "all" or showNotifications == "problems" then
            AddCustomOnScreenNotification(
                "AutoGatherTransportNoRecharge", 
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