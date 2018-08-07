-- Setup work thread
-- ==========================================================
function OnMsg.GameTimeStart()
    AutoScanMapInstallThread()
end

function OnMsg.LoadGame()
    AutoScanMapInstallThread()
end

function AutoScanMapInstallThread()
    CreateGameTimeThread(function()
        while true do
            Sleep(5000)
            AutoScanMap() 
        end
    end)
end

-- Automation logic
-- ==========================================================

function AutoScanMap()
    -- scan mode
    local mode = AutoScanMapConfigMode()

    if mode == "off" then
        return
    end

    -- game is not yet initialized
    if not mapdata.GameLogic then
        return
    end

    -- check the global queue for ongoing exploration
    if g_ExplorationQueue and #g_ExplorationQueue == 0 then

        local scanCandidates = { }

        -- g_MapSectors is a column [1..10] and row [1..10] matrix of sector information
        -- 1, 1 is J0; 1, 10 is J9

        for x = 1, const.SectorCount do
            for y = 1, const.SectorCount do
                local sector = g_MapSectors[x][y];
                if sector:CanBeScanned() then
                    -- full scanning is enabled
                    if mode == "all"
                            -- do scanning only if deep scanning is not available
                            or (mode == "normal" and g_Consts.DeepScanAvailable == 0)
                            -- do scanning only if deep scanning becomes available
                            or (mode == "deep" and g_Consts.DeepScanAvailable ~= 0) then
                        scanCandidates[#scanCandidates + 1] = sector
                    end
                end
            end
        end

        -- if there are sectors to scan
        if #scanCandidates ~= 0 then
            -- find the closest one to existing units and buildings

            local closest = nil
            local closestDistance = nil

            ForEach { classes = "Building,Unit", exec = function(obj)
                local pos = obj:GetPos()

                -- find closest candidate
                for k, sector in ipairs(scanCandidates) do
                    local sectorPos = sector:GetPos()

                    -- Eucleidian distance
                    local dist = (sectorPos:x() - pos:x())^2 + (sectorPos:y() - pos:y())^2

                    -- if this is the first sector or it is closer than something else before
                    if not closest or closestDistance > dist then
                        closest = sector
                        closestDistance = dist
                    end
                end
            end }

            -- queue it up for exploration
            if not closest then
                -- pick a random sector from the candidates
                closest = scanCandidates[ AsyncRand (#scanCandidates)]
            end
            closest:QueueForExploration()
            -- prevent the scan animation from being deployed on the main map view
            if GetInGameInterfaceMode() ~= "overview" then
                closest:SetScanFx(false)
            end
            OverviewModeDialog:UpdateSectorRollover(closest)
        end

    end
end

-- ModConfig setup
-- ==========================================================

-- See if ModConfig is installed and that notifications are enabled
function AutoScanMapConfigMode()
    local g_ModConfigLoaded = table.find_value(ModsLoaded, "steam_id", "1340775972") or false
    if g_ModConfigLoaded then
        return ModConfig:Get("AutoScanMap", "Mode")
    end
    return "all"
end

-- ModConfig signals "ModConfigReady" when it can be manipulated
function OnMsg.ModConfigReady()

    ModConfig:RegisterMod("AutoScanMap",
        T{"AutoScanMap"},
        T{"Automatically scan and rescan sectors"}
    ) 

    ModConfig:RegisterOption("AutoScanMap", "Mode", {
        name = T{"Scan mode"},
        desc = T{"Specify how to scan the sectors automatically or turn it off completely.<newline>Normal only performs scanning while only basic scanning is available.<newline>Deep only performs scanning only if the research has been acquired."},
        type = "enum",
        values = {
            {value = "all", label = T{"Normal & Deep"}},
            {value = "normal", label = T{"Normal only"}},
            {value = "deep", label = T{"Deep only"}},
            {value = "off", label = T{"Off"}}
        },
        default = "all" 
    })
   
end