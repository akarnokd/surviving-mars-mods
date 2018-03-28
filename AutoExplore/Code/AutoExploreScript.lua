function OnMsg.GameTimeStart()
    AutoExploreInstallThread()
end

function OnMsg.LoadGame()
    -- NewMapLoaded doesn't trigger for for loaded games?
    AutoExplorePathFinding:BuildZones()

    AutoExploreInstallThread()
end

-- create the zone mapping when the map has finished loading
function OnMsg.PostNewMapLoaded()
    AutoExplorePathFinding:BuildZones()
end

function AutoExploreInstallThread()
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

-- Object to hold the zone mapping and functions to help evaluate
-- the reachability of objects in zones.
-- To avoid conflicts when this is needed in different mods
-- Rename the class to your mod's name such as MyModPathFinding
-- I don't know if it is possible to have such utility mods globally
-- and imported once, also specified as dependency in the mod setup
AutoExplorePathFinding = { 
    -- the map width in hexes (the height is irrelevant)
    mapWidth = 0,
    -- the zone numbers for a point hash
    locations = { },

    -- how many zones were found
    zoneCount = 0,

    -- returns the zone index of a world location point()
    -- or nil if it is not a passable location
    GetPointZone = function(self, worldPoint)
        -- convert to hex coordinates
        local hx, hy = WorldToHex(worldPoint:x(), worldPoint:y())

        -- calculate composite hash index
        local hhash = self:HashCoordinates(hx, hy, self.mapWidth)

        -- see what the table holds
        return self.locations[hhash]
    end,

    -- returns the zone index of a hex grid location point()
    -- or nil if it is not a passable location
    GetGridZone = function(self, hexPoint)
        -- calculate composite hash index
        local hhash = self:HashCoordinates(hexPoint:x(), hexPoint:y(), self.mapWidth)

        -- see what the table holds
        return self.locations[hhash]
    end,

    -- returns the zone index of a game entity that has a position
    -- or nil if it is not a passable location
    GetObjectZone = function(self, obj)
        return self:GetPointZone(obj:GetPos())
    end,

    -- Searches for (currently) usable tunnels and returns a zone-graph of them.
    -- @returns an array where the index is a zone id and the
    --          content is an array of zone ids reachable from that source zone, i.e.,
    --          { 1 = { 2, 3}, 2 = {1}, 3 = {1} }
    --          which means zone 1 is connected to zone 2 and 3
    --          zones 2 and 3 are only connected with zone 1
    GetZonesReachableViaTunnels = function(self)
        -- existing indexes indicate there is a tunnel in that zone
        local reachableZones = { }

        ForEach { class = "Tunnel", 
            filter = function(tunnel)
                -- ignore tunnels under construction or inoperable
                return not IsKindOf(tunnel, "ConstructionSite") and not tunnel.demolished
            end,
            exec = function(tunnel)
                
                -- get the entrances of the tunnel
                local entrance, start_point = tunnel:GetEntrance(nil, "tunnel_entrance")
                local exit, exit_point = (tunnel.linked_obj):GetEntrance(nil, "tunnel_entrance")
                
                -- get the zone indexes
                -- we have to link them in both directions in the resulting structure
                local startZone = self:GetPointZone(start_point)
                local endZone = self:GetPointZone(exit_point)
                
                -- prepare the source zone index
                if not reachableZones[startZone] then
                    -- entries are list of end zones
                    reachableZones[startZone] = { }
                end
                -- append the reachable zone
                table.insert(reachableZones[startZone], endZone)

                -- prepare the end zone index
                if not reachableZones[endZone] then
                    -- entries are list of end zones
                    reachableZones[endZone] = { }
                end
                -- append the reachable zone
                table.insert(reachableZones[endZone], startZone)
            end 
        }

        return reachableZones
    end,

    -- Check if given a zone connectivity table, there is a path from the
    -- source zone to the destination zone of the destination object.
    -- @param zonesReachable should come from GetZonesReachableViaTunnels
    --                       (no need to recalculate it for every CanReachZone check)
    -- @returns true if so
    CanReachObject = function(self, zonesReachable, sourceZone, destinationObject)
        -- get the zone of the object
        local destinationZone = self:GetObjectZone(destinationObject)
        -- if the source zone and the destination zone are in the same
        -- we consider the object to be reachable
        if destinationZone == sourceZone then
            return true
        end

        -- if not, check if both the object's zone and the source is
        -- reachable via the network of tunnels
        return self:CanReachZone(zonesReachable, sourceZone, destinationZone, sourceZone)
    end,

    -- Check if given a zone connectivity table, there is a path from the
    -- source zone to the destination zone.
    -- @param zonesReachable should come from GetZonesReachableViaTunnels
    --                       (no need to recalculate it for every CanReachZone check)
    -- @returns true if so
    CanReachZone = function(self, zonesReachable, sourceZone, destinationZone, alreadyVisited)

        -- zones already checked, includes the start zone to avoid backtracking
        local visited = { }

        visited[sourceZone] = true
        visited[alreadyVisited] = true

        -- start with the source zone
        local queue = { sourceZone }

        -- while there are zones to check
        while #queue ~= 0 do
            -- take the next zone
            local z = table.remove(queue)

            -- is it the target zone
            if z == destinationZone then
                -- yep, we are done
                return true
            end

            -- get the zones reachable from the current zone
            local endpoints = zonesReachable[z]

            if endpoints then
                -- check and add each endpoint to the queue
                for i, e in ipairs(endpoints) do
                    -- is it the target zone
                    if e == destinationZone then
                        -- yep, we are done
                        return true
                    end

                    -- did we already check this zone
                    if not visited[e] then
                        -- not, let's mare sure w don't evaluate it over again
                        -- as it would lead to an infinte loop
                        visited[e] = true
                        -- add it to the queue
                        table.insert(queue, e)
                    end
                end
            end
        end

        -- the destination was not reachable via zone hopping
        return false
    end,

    -- Returns the next Tunnel object in the source zone which brings one step closer
    -- to the destination zone or nil if it can't be reached
    -- 
    GetNextTunnelTowards = function(self, zonesReachable, sourceZone, destinationZone)
        
        local candidates = { }
        
        -- find tunnels
        ForEach { class = "Tunnel", 
            filter = function(tunnel)
                -- ignore tunnels under construction or inoperable
                return not IsKindOf(tunnel, "ConstructionSite") and not tunnel.demolished
            end,
            exec = function(tunnel)
                
                -- get the entrances of the tunnel
                local entrance, start_point = tunnel:GetEntrance(nil, "tunnel_entrance")
                local exit, exit_point = (tunnel.linked_obj):GetEntrance(nil, "tunnel_entrance")
                
                -- get the zone indexes
                -- we have to link them in both directions in the resulting structure
                local startZone = self:GetPointZone(start_point)
                local endZone = self:GetPointZone(exit_point)

                -- if this object is in the same zone as the source
                if startZone == sourceZone then
                    -- and the target can be reached from the other side
                    if self:CanReachZone(zonesReachable, endZone, destinationZone, sourceZone) then
                        -- target the near side tunnel
                        table.insert(candidates, tunnel)
                        -- for now, we don't try to find an optimal path
                        return "break"
                    end
                end
                if endZone == sourceZone then
                    -- and the target can be reached from the other side
                    if self:CanReachZone(zonesReachable, startZone, destinationZone, sourceZone) then
                        -- target the far side tunnel
                        table.insert(candidates, tunnel.linked_obj)
                        -- for now, we don't try to find an optimal path
                        return "break"
                    end
                end
            end
        }

        -- if there is a candidate return it
        if #candidates ~= 0 then
            return table.remove(candidates)
        end
        return nil
    end,

    -- Given the grid coordinates X and Y, and the scan width
    -- Create an unique hash of that position by considering
    -- That negative GridX coordinates could mess it up
    HashCoordinates = function(self, gridX, gridY, scanWidth)
        if gridX < 0 then
            -- pretend the coordinate is backwards from the next line
            return (gridY + 1) * scanWidth + gridX
        end
        return gridY * scanWidth + gridX
    end,

    -- builds (or updates) the cell-zone mapping
    BuildZones = function(self)
         -- map size in hex cells
        local mapWidth = HexMapWidth
        local mapHeight = HexMapHeight

        -- clear and reset AutoExplorePathFinding
        self.mapWidth = mapWidth
        self.locations = { }
        self.zoneCount = 0

         -- cell diameter for adjacency testing
        local nearbyRadius = const.GridSpacing / 2
        
        -- the keys are combined coordinates that are passable
        local accessibilityTable = { }

        -- rovers have this value in game
        local pfclass = 1

        local grid = ObjectGrid

        -- for each cell on the map
        for y = 1, mapHeight do
            for xRect = 1, mapWidth do
                local px = nil

                -- the hex grid is tilted, so to cover the map's rectangular
                -- surface, the start X coordinate depends on the Y coordinate
                -- i.e., every second line up should shift the line to the right by 1
                local x = xRect - (y / 2)

                -- is there anything?
                if HexGridGetObject(grid, x, y) then
                    -- if so, ignore it and consider the location to be passable
                    -- in case the building gets removed later on
                    -- or is already there to begin with
                    px = x
                else
                    -- convert to world coordinates for GetPassablePointNearby
                    local xi, yi = HexToWorld(x, y)

                    -- find the nearest point that is passable, practically exactly at xi, yi
                    px = GetPassablePointNearby(xi, yi, pfclass, nearbyRadius)
                end
                
                -- a non-nil means candidateX, candidateY is passable
                if px then
                    -- create a composite number to serve as a hash 
                    local hash = self:HashCoordinates(x, y, mapWidth)

                    -- indicate a passable coordinate with zone 0
                    -- the entry value will indicate the zone index if > 0
                    -- 0 means that location was not yet visited
                    accessibilityTable[hash] = { cellX = x, cellY = y, zone = 0, queued = false }
                end
            end
        end

        -- start indexing the zones from 1
        local currentZone = 1

        -- loop through each entry in the accessibility table
        for hash, cell in pairs(accessibilityTable) do

            -- unless the cell has already a positive zone
            if cell.zone == 0 then
                -- perform a flood fill around this cell

                -- set up a queue to visit nearby cells
                -- start with the current cell
                local queue = { cell }

                -- loop until there are coordinates in the queue
                while #queue ~= 0 do
                    -- get the next set of coordinates from the queue
                    local ccell = table.remove(queue)

                    -- assign it the current zone index
                    ccell.zone = currentZone

                    local cx = ccell.cellX
                    local cy = ccell.cellY

                    -- build up neighboring coordinates
                    local neighbors = {
                        -- top
                        cx - 1, cy - 1,
                        cx    , cy - 1,
                        cx + 1, cy - 1,

                        -- middle
                        cx - 1, cy,
                        -- cx, cy, already there
                        cx + 1, cy,

                        -- bottom
                        cx - 1, cy + 1,
                        cx    , cy + 1,
                        cx + 1, cy + 1
                    }

                    -- loop through those coordinates
                    for i = 1, #neighbors, 2 do
                        local nx = neighbors[i]
                        local ny = neighbors[i + 1]

                        -- create a composite number to serve as a hash 
                        local nhash = self:HashCoordinates(nx, ny, mapWidth)

                        local ncell = accessibilityTable[nhash]

                        -- is it in the accessibility table at all?
                        if ncell then 
                            -- if it was not visited yet
                            if ncell.zone == 0 and not ncell.queued then
                                -- prevents queueing this cell again from
                                -- neighboring locations again
                                ncell.queued = true
                                -- add it to the queue
                                table.insert(queue, ncell)
                            end
                        end
                    end
                end

                -- no more connected cells to visit, increase the zone number
                currentZone = currentZone + 1
            end
        end

        self.zoneCount = currentZone - 1

        -- loop through the table again and 
        for hash, cell in pairs(accessibilityTable) do
            self.locations[hash] = cell.zone
        end
    end
}

