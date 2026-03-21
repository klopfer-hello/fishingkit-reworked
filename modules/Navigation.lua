--[[
    FishingKit - TBC Anniversary Edition
    Navigation Module - Pool route navigation with arrow

    This module handles:
    - TomTom-style navigation arrow pointing to next pool
    - Nearest-neighbor route building between discovered pools
    - Dynamic re-routing when new pools discovered
    - GatherMate2 data import
    - World map route line overlay
    - Arrival detection and waypoint advancement
]]

local ADDON_NAME, FK = ...

FK.Navigation = {}
local Navigation = FK.Navigation

-- Navigation state
local navState = {
    active = false,         -- route actively running
    route = {},             -- ordered array of pool indices
    routePools = {},        -- the pools array used to build route
    currentWaypoint = 0,    -- index into route[]
    currentMapID = nil,     -- uiMapID for current route
    arrowFrame = nil,       -- the arrow UI frame
    lastPlayerX = 0,
    lastPlayerY = 0,
    lastSpeed = 0,
    lastSpeedUpdate = 0,
    inCombat = false,
}

-- Arrow spritesheet config (matches TomTom Arrow-1024.tga)
-- 1024x1024 texture, 9 columns x 12 rows, each cell 112x84, 108 frames
local ARROW_TEX_W = 1024
local ARROW_TEX_H = 1024
local ARROW_CELL_W = 112
local ARROW_CELL_H = 84
local ARROW_COLS = 9
local ARROW_ROWS = 12
local ARROW_FRAMES = ARROW_COLS * ARROW_ROWS  -- 108

local TWO_PI = math.pi * 2
local floor = math.floor
local sqrt = math.sqrt
local abs = math.abs
local atan2 = math.atan2
local sin = math.sin
local cos = math.cos

-- GatherMate2 node ID to pool name mapping
local GM2_NODE_NAMES = {
    [101] = "Floating Wreckage",
    [103] = "Floating Debris",
    [105] = "Firefin Snapper School",
    [106] = "Greater Sagefish School",
    [107] = "Oily Blackmouth School",
    [108] = "Sagefish School",
    [109] = "School of Deviate Fish",
    [110] = "Stonescale Eel Swarm",
    [112] = "Highland Mixed School",
    [113] = "Pure Water",
    [114] = "Bluefish School",
    [115] = "Feltail School",
    [116] = "Mudfish School",
    [117] = "School of Darter",
    [118] = "Sporefish School",
    [119] = "Steam Pump Flotsam",
    [120] = "School of Tastyfish",
    [125] = "Floating Wreckage Pool",
    [133] = "Schooner Wreckage",
    [134] = "Waterlogged Wreckage Pool",
    [135] = "Bloodsail Wreckage Pool",
    [136] = "Mixed Ocean School",
}

-- World map route state
local connectionPool = nil

-- ============================================================================
-- Arrow Texture Coordinate Resolver
-- ============================================================================

local function GetArrowTexCoords(angle)
    -- Normalize angle to 0..2pi
    angle = angle % TWO_PI
    if angle < 0 then angle = angle + TWO_PI end

    local cell = floor(angle / TWO_PI * ARROW_FRAMES + 0.5) % ARROW_FRAMES
    local column = cell % ARROW_COLS
    local row = floor(cell / ARROW_COLS)

    local left = (column * ARROW_CELL_W) / ARROW_TEX_W
    local right = ((column + 1) * ARROW_CELL_W) / ARROW_TEX_W
    local top = (row * ARROW_CELL_H) / ARROW_TEX_H
    local bottom = ((row + 1) * ARROW_CELL_H) / ARROW_TEX_H

    return left, right, top, bottom
end

-- ============================================================================
-- Arrow Frame Creation
-- ============================================================================

local function CreateArrowFrame()
    if navState.arrowFrame then return navState.arrowFrame end

    local frame = CreateFrame("Button", "FishingKitNavArrow", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(140, 175)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    -- Backdrop - subtle dark background
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        frame:SetBackdropColor(0, 0, 0, 0.7)
        frame:SetBackdropBorderColor(0, 0.82, 1, 0.6)
    end

    -- Arrow texture (spritesheet)
    local arrow = frame:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(56, 42)
    arrow:SetPoint("TOP", frame, "TOP", 0, -8)
    arrow:SetTexture("Interface\\AddOns\\FishingKit\\media\\arrow")
    frame.arrow = arrow

    -- Pool name text
    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleText:SetPoint("TOP", arrow, "BOTTOM", 0, -4)
    titleText:SetWidth(130)
    titleText:SetTextColor(0, 0.82, 1)
    titleText:SetText("")
    frame.titleText = titleText

    -- Pool type tag (e.g. "Oily Blackmouth" or pool category)
    local typeText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    typeText:SetPoint("TOP", titleText, "BOTTOM", 0, -1)
    typeText:SetWidth(130)
    typeText:SetTextColor(0.7, 0.7, 0.7)
    typeText:SetText("")
    frame.typeText = typeText

    -- Source tag: "Community" or "Discovered (3x)"
    local sourceText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sourceText:SetPoint("TOP", typeText, "BOTTOM", 0, -1)
    sourceText:SetWidth(130)
    sourceText:SetText("")
    frame.sourceText = sourceText

    -- Distance text
    local distText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    distText:SetPoint("TOP", sourceText, "BOTTOM", 0, -2)
    distText:SetText("0 yards")
    frame.distText = distText

    -- ETA text
    local etaText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    etaText:SetPoint("TOP", distText, "BOTTOM", 0, -1)
    etaText:SetTextColor(0.7, 0.7, 0.7)
    etaText:SetText("")
    frame.etaText = etaText

    -- Waypoint counter
    local wpText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    wpText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 4)
    wpText:SetTextColor(0.5, 0.5, 0.5)
    wpText:SetText("0/0")
    frame.wpText = wpText

    -- Coords text
    local coordText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    coordText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 4)
    coordText:SetTextColor(0.5, 0.5, 0.5)
    coordText:SetText("")
    frame.coordText = coordText

    -- Close button (X)
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetSize(18, 18)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    closeBtn:SetScript("OnClick", function()
        Navigation:StopRoute()
    end)

    -- Dragging
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        Navigation:SaveArrowPosition()
    end)

    -- Right-click to skip waypoint
    frame:RegisterForClicks("RightButtonUp")
    frame:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            Navigation:SkipWaypoint()
        end
    end)

    -- Tooltip
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("|cFF00D1FFPool Navigation|r", 1, 1, 1)
        GameTooltip:AddLine("Right-click: Skip waypoint", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Drag: Move arrow", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("X: Stop navigation", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- OnUpdate for arrow rotation and distance
    local elapsed = 0
    local etaElapsed = 0
    frame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        etaElapsed = etaElapsed + dt
        -- Arrow updates every frame for smooth rotation
        Navigation:UpdateArrow(dt, etaElapsed)
        if etaElapsed >= 1.0 then
            etaElapsed = 0
        end
    end)

    frame:Hide()
    navState.arrowFrame = frame
    return frame
end

-- ============================================================================
-- Arrow Position Save/Load
-- ============================================================================

function Navigation:SaveArrowPosition()
    if not navState.arrowFrame or not FK.db then return end
    local point, _, relativePoint, x, y = navState.arrowFrame:GetPoint()
    FK.db.settings.arrowPosition = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end

function Navigation:LoadArrowPosition()
    if not navState.arrowFrame or not FK.db or not FK.db.settings.arrowPosition then return end
    local pos = FK.db.settings.arrowPosition
    navState.arrowFrame:ClearAllPoints()
    navState.arrowFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
end

-- ============================================================================
-- Arrow Update (called every frame when visible)
-- ============================================================================

function Navigation:UpdateArrow(dt, etaElapsed)
    if not navState.active or navState.inCombat then return end
    if not FK.db or not FK.db.settings.poolNavArrow then return end

    local target = self:GetCurrentTarget()
    if not target then return end

    local frame = navState.arrowFrame
    if not frame then return end

    -- Get player world position (UnitPosition returns y, x in TBC)
    local py, px = UnitPosition("player")
    if not px or not py then return end

    -- Get map data for coordinate conversion
    local mapData = FK.Pools:GetMapData(navState.currentMapID)
    if not mapData then return end

    -- Convert pool normalized coords to world coords
    local poolWX, poolWY = FK.Pools:ZoneToWorld(target.x, target.y, mapData)

    -- Distance in yards
    local dx = px - poolWX
    local dy = py - poolWY
    local distance = sqrt(dx * dx + dy * dy)

    -- Update distance text
    frame.distText:SetText(floor(distance) .. " yards")

    -- Color distance based on proximity
    if distance < (FK.db.settings.poolNavArrivalDistance or 20) * 1.5 then
        frame.distText:SetTextColor(0.2, 1, 0.2)  -- Green when close
    elseif distance < 100 then
        frame.distText:SetTextColor(1, 1, 0.2)     -- Yellow medium
    else
        frame.distText:SetTextColor(1, 1, 1)        -- White far
    end

    -- ETA calculation (throttled to 1s)
    if etaElapsed >= 1.0 then
        local now = GetTime()
        local timeDelta = now - navState.lastSpeedUpdate
        if timeDelta > 0.5 then
            local moveDist = sqrt((px - navState.lastPlayerX)^2 + (py - navState.lastPlayerY)^2)
            navState.lastSpeed = moveDist / timeDelta
            navState.lastPlayerX = px
            navState.lastPlayerY = py
            navState.lastSpeedUpdate = now
        end

        if navState.lastSpeed > 1 then
            local eta = distance / navState.lastSpeed
            if eta < 60 then
                frame.etaText:SetText(string.format("0:%02d", floor(eta)))
            elseif eta < 3600 then
                frame.etaText:SetText(string.format("%d:%02d", floor(eta / 60), floor(eta % 60)))
            else
                frame.etaText:SetText("")
            end
        else
            frame.etaText:SetText("")
        end
    end

    -- Bearing: angle from player to pool
    local bearing = atan2(poolWX - px, poolWY - py)

    -- Relative angle: bearing minus player facing
    local facing = GetPlayerFacing() or 0
    local relAngle = bearing - facing

    -- Set arrow texture coords based on relative angle
    local left, right, top, bottom = GetArrowTexCoords(relAngle)
    frame.arrow:SetTexCoord(left, right, top, bottom)

    -- Color arrow based on direction accuracy
    local perc = abs((math.pi - abs(relAngle % TWO_PI - math.pi)) / math.pi)
    if perc > 0.95 then
        frame.arrow:SetVertexColor(0, 0.9, 1, 1)      -- Bright cyan - on target
    elseif perc > 0.7 then
        frame.arrow:SetVertexColor(0, 0.7, 0.85, 1)   -- Medium cyan
    else
        frame.arrow:SetVertexColor(0.3, 0.5, 0.65, 1)  -- Dim - wrong direction
    end

    -- Arrival check
    local arrivalDist = FK.db.settings.poolNavArrivalDistance or 20
    if distance < arrivalDist then
        self:AdvanceWaypoint()
    end
end

-- ============================================================================
-- Route Building (Nearest-Neighbor Greedy TSP)
-- ============================================================================

function Navigation:BuildRoute()
    local uiMapID = C_Map.GetBestMapForUnit("player")
    if not uiMapID then return false end

    local allPools = FK.Pools:GetPoolLocationsForMap(uiMapID)
    if not allPools or #allPools < 1 then
        FK:Print("No discovered pools in this zone to route.", FK.Colors.warning)
        return false
    end

    -- Filter out community pools if setting is off
    local pools = {}
    local hideCommunity = FK.db and FK.db.settings and not FK.db.settings.showCommunityPools
    for _, p in ipairs(allPools) do
        if not (hideCommunity and FK.Pools and FK.Pools.IsStaticPool and FK.Pools:IsStaticPool(p)) then
            pools[#pools + 1] = p
        end
    end

    if #pools < 1 then
        FK:Print("No pools available for routing (community pools hidden).", FK.Colors.warning)
        return false
    end

    -- Get player position for starting point
    local playerX, playerY
    local position = C_Map.GetPlayerMapPosition(uiMapID, "player")
    if position then
        playerX, playerY = position:GetXY()
    end

    -- Fallback: if player position unavailable, start from first pool
    if not playerX or not playerY or (playerX == 0 and playerY == 0) then
        playerX = pools[1].x
        playerY = pools[1].y
        FK:Debug("Player position unavailable, starting route from first pool.")
    end

    -- Copy pool references for route
    navState.routePools = pools
    navState.currentMapID = uiMapID

    -- Nearest-neighbor path
    local visited = {}
    local route = {}
    local currentX, currentY = playerX, playerY

    for i = 1, #pools do
        local bestDist = math.huge
        local bestIdx = nil

        for j = 1, #pools do
            if not visited[j] then
                local dx = pools[j].x - currentX
                local dy = pools[j].y - currentY
                local dist = dx * dx + dy * dy  -- squared distance is fine for comparison
                if dist < bestDist then
                    bestDist = dist
                    bestIdx = j
                end
            end
        end

        if bestIdx then
            visited[bestIdx] = true
            table.insert(route, bestIdx)
            currentX = pools[bestIdx].x
            currentY = pools[bestIdx].y
        end
    end

    navState.route = route
    navState.currentWaypoint = 1

    FK:Debug("Route built: " .. #route .. " waypoints in zone " .. uiMapID)
    return true
end

-- ============================================================================
-- Cheapest-Insertion for New Pool Mid-Route
-- ============================================================================

function Navigation:InsertPoolIntoRoute(newPoolIndex)
    local route = navState.route
    local pools = navState.routePools
    if #route < 2 then
        -- Just append
        table.insert(route, newPoolIndex)
        return
    end

    local newPool = pools[newPoolIndex]
    if not newPool then return end

    local bestCost = math.huge
    local bestPos = #route + 1  -- default: append

    for i = 1, #route do
        local nextI = (i % #route) + 1
        local a = pools[route[i]]
        local b = pools[route[nextI]]

        if a and b then
            local distANew = sqrt((a.x - newPool.x)^2 + (a.y - newPool.y)^2)
            local distNewB = sqrt((newPool.x - b.x)^2 + (newPool.y - b.y)^2)
            local distAB = sqrt((a.x - b.x)^2 + (a.y - b.y)^2)
            local cost = distANew + distNewB - distAB

            if cost < bestCost then
                bestCost = cost
                bestPos = i + 1
            end
        end
    end

    table.insert(route, bestPos, newPoolIndex)

    -- Adjust current waypoint index if insertion was before it
    if bestPos <= navState.currentWaypoint then
        navState.currentWaypoint = navState.currentWaypoint + 1
    end

    FK:Debug("Pool inserted into route at position " .. bestPos)
end

-- ============================================================================
-- Waypoint Management
-- ============================================================================

function Navigation:AdvanceWaypoint()
    if #navState.route == 0 then return end

    -- Play arrival sound
    if FK.db and FK.db.settings.poolNavSound then
        PlaySound(SOUNDKIT.TELL_MESSAGE or 3081)
    end

    -- Advance
    navState.currentWaypoint = navState.currentWaypoint + 1
    if navState.currentWaypoint > #navState.route then
        navState.currentWaypoint = 1  -- wrap around
    end

    self:UpdateArrowTexts()
    self:UpdateWorldMapRoute()

    FK:Debug("Advanced to waypoint " .. navState.currentWaypoint .. "/" .. #navState.route)
end

function Navigation:SkipWaypoint()
    if not navState.active or #navState.route == 0 then return end

    navState.currentWaypoint = navState.currentWaypoint + 1
    if navState.currentWaypoint > #navState.route then
        navState.currentWaypoint = 1
    end

    self:UpdateArrowTexts()
    self:UpdateWorldMapRoute()

    local target = self:GetCurrentTarget()
    if target then
        FK:Print("Skipped to: " .. target.name, FK.Colors.info)
    end
end

function Navigation:RecalculateFromNearest()
    if not navState.active then return end

    -- Rebuild route starting from player position
    if self:BuildRoute() then
        self:UpdateArrowTexts()
        self:UpdateWorldMapRoute()
        FK:Print("Route recalculated from nearest pool.", FK.Colors.success)
    end
end

function Navigation:GetCurrentTarget()
    if not navState.active or #navState.route == 0 then return nil end
    if navState.currentWaypoint < 1 or navState.currentWaypoint > #navState.route then return nil end

    local poolIndex = navState.route[navState.currentWaypoint]
    local pool = navState.routePools[poolIndex]
    return pool
end

function Navigation:UpdateArrowTexts()
    local frame = navState.arrowFrame
    if not frame then return end

    local target = self:GetCurrentTarget()
    if target then
        -- Pool name
        frame.titleText:SetText(target.name)

        -- Coordinates
        frame.coordText:SetText(string.format("%.1f, %.1f", (target.x or 0) * 100, (target.y or 0) * 100))

        -- Waypoint counter
        frame.wpText:SetText(navState.currentWaypoint .. "/" .. #navState.route)

        -- Source: Community or Discovered
        local isStatic = FK.Pools and FK.Pools.IsStaticPool and FK.Pools:IsStaticPool(target)
        if isStatic then
            frame.sourceText:SetText("|cFFB3FF00Community|r")
            frame.typeText:SetText("Unconfirmed location")
            frame.typeText:SetTextColor(0.6, 0.6, 0.6)
        else
            local seen = target.timesSeen or 1
            frame.sourceText:SetText("|cFF00FF00Discovered|r |cFFAAAAAA(" .. seen .. "x seen)|r")
            -- Last seen
            if target.lastSeen and target.lastSeen > 0 then
                local ago = time() - target.lastSeen
                local agoStr
                if ago < 60 then
                    agoStr = "Just now"
                elseif ago < 3600 then
                    agoStr = math.floor(ago / 60) .. "m ago"
                elseif ago < 86400 then
                    agoStr = math.floor(ago / 3600) .. "h ago"
                else
                    agoStr = math.floor(ago / 86400) .. "d ago"
                end
                frame.typeText:SetText("Last seen: " .. agoStr)
                frame.typeText:SetTextColor(0.7, 0.7, 0.7)
            else
                frame.typeText:SetText("")
            end
        end
    end
end

-- ============================================================================
-- Start / Stop Route
-- ============================================================================

function Navigation:StartRoute()
    if not FK.db or not FK.db.settings.poolNavEnabled then
        FK:Print("Pool navigation is disabled. Enable it in settings.", FK.Colors.warning)
        return
    end

    -- Build the route
    if not self:BuildRoute() then
        return
    end

    -- Create arrow if needed
    CreateArrowFrame()
    self:LoadArrowPosition()

    navState.active = true

    -- Initialize speed tracking
    local py, px = UnitPosition("player")
    navState.lastPlayerX = px or 0
    navState.lastPlayerY = py or 0
    navState.lastSpeedUpdate = GetTime()
    navState.lastSpeed = 0

    -- Show arrow
    if FK.db.settings.poolNavArrow and not navState.inCombat then
        navState.arrowFrame:Show()
    end

    self:UpdateArrowTexts()
    self:UpdateWorldMapRoute()

    local target = self:GetCurrentTarget()
    local targetName = target and target.name or "unknown"
    FK:Print("Route started! " .. #navState.route .. " pools. First: " .. targetName, FK.Colors.success)
end

function Navigation:StopRoute()
    navState.active = false
    navState.route = {}
    navState.routePools = {}
    navState.currentWaypoint = 0

    -- Hide arrow
    if navState.arrowFrame then
        navState.arrowFrame:Hide()
    end

    -- Clear world map route lines
    self:ClearWorldMapRoute()

    FK:Print("Route stopped.", FK.Colors.info)
end

function Navigation:ToggleRoute()
    if navState.active then
        self:StopRoute()
    else
        self:StartRoute()
    end
end

function Navigation:IsActive()
    return navState.active
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

function Navigation:OnPoolDiscovered(poolData)
    if not navState.active then return end
    if not navState.currentMapID then return end

    -- Check if pool is in current route zone
    local uiMapID = C_Map.GetBestMapForUnit("player")
    if uiMapID ~= navState.currentMapID then return end

    -- Refresh pool list reference (Pools.lua may have added to the array)
    local pools = FK.Pools:GetPoolLocationsForMap(uiMapID)
    navState.routePools = pools

    -- Find the new pool's index (it's the last one added)
    local newIdx = #pools

    -- Check if it's already in our route
    for _, idx in ipairs(navState.route) do
        if idx == newIdx then return end
    end

    -- Insert using cheapest-insertion
    self:InsertPoolIntoRoute(newIdx)
    self:UpdateArrowTexts()
    self:UpdateWorldMapRoute()

    FK:Debug("New pool added to route: " .. (poolData.name or "unknown"))
end

function Navigation:OnZoneChanged()
    if not navState.active then return end

    local uiMapID = C_Map.GetBestMapForUnit("player")
    if not uiMapID then
        -- Can't determine zone, hide arrow
        if navState.arrowFrame then navState.arrowFrame:Hide() end
        return
    end

    if uiMapID ~= navState.currentMapID then
        -- Zone changed - rebuild route for new zone
        local pools = FK.Pools:GetPoolLocationsForMap(uiMapID)
        if pools and #pools > 0 then
            self:BuildRoute()
            self:UpdateArrowTexts()
            self:UpdateWorldMapRoute()
            if FK.db.settings.poolNavArrow and not navState.inCombat then
                navState.arrowFrame:Show()
            end
            FK:Print("Route updated for new zone (" .. #navState.route .. " pools).", FK.Colors.info)
        else
            -- No pools in new zone, hide arrow but keep active
            if navState.arrowFrame then navState.arrowFrame:Hide() end
            self:ClearWorldMapRoute()
            FK:Print("No discovered pools in this zone. Arrow hidden.", FK.Colors.info)
        end
    end
end

function Navigation:OnCombatStart()
    navState.inCombat = true
    if navState.arrowFrame and navState.active then
        navState.arrowFrame:Hide()
    end
end

function Navigation:OnCombatEnd()
    navState.inCombat = false
    if navState.arrowFrame and navState.active and FK.db and FK.db.settings.poolNavArrow then
        -- Only show if we have a valid target
        if self:GetCurrentTarget() then
            navState.arrowFrame:Show()
        end
    end
end

-- ============================================================================
-- World Map Route Pin Mixins (referenced by FishingKit.xml templates)
-- ============================================================================

FishingKitRoutePinMixin = CreateFromMixins(MapCanvasPinMixin)

function FishingKitRoutePinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    self:SetMouseMotionEnabled(false)
    self:SetMouseClickEnabled(false)
end

FishingKitRoutePinMixin.SetPassThroughButtons = function() end

FishingKitRouteConnectionMixin = {}

function FishingKitRouteConnectionMixin:Connect(pin1, pin2)
    self:SetParent(pin1)
    self:SetPoint("BOTTOM", pin1, "CENTER")
    if not (pin1:GetCenter() and pin2:GetCenter()) then
        return
    end
    local length = RegionUtil.CalculateDistanceBetween(pin1, pin2) * pin1:GetEffectiveScale()
    self:SetHeight(length)
    local quarter = (math.pi / 2)
    local angle = RegionUtil.CalculateAngleBetween(pin1, pin2) - quarter
    self:RotateTextures(angle, 0.5, 0)
    self.Line:SetAtlas("_UI-Taxi-Line-horizontal")
    self.Line:SetStartPoint("CENTER", pin1)
    self.Line:SetEndPoint("CENTER", pin2)
    self.Line:SetThickness(20)
end

-- ============================================================================
-- World Map Route Lines
-- ============================================================================

function Navigation:DrawRouteOnWorldMap()
    self:ClearWorldMapRoute()

    if not navState.active then return end
    if not FK.db or not FK.db.settings.poolNavWorldMapRoute then return end
    if not WorldMapFrame or not WorldMapFrame:IsShown() then return end

    -- Lazy-hook the world map on first draw attempt
    self:HookWorldMap()

    local map = WorldMapFrame
    local mapID = map:GetMapID()
    if not mapID or mapID ~= navState.currentMapID then return end

    local pools = navState.routePools
    local route = navState.route
    if #route < 2 then return end

    -- Create connection pool on first use
    if not connectionPool then
        connectionPool = CreateFramePool("FRAME", map:GetCanvas(), "FishingKitRouteConnectionTemplate")
    end

    -- Acquire route pins at each waypoint position
    local routePins = {}
    for i = 1, #route do
        local pool = pools[route[i]]
        if pool then
            local pin = map:AcquirePin("FishingKitRoutePinTemplate")
            pin:SetPosition(pool.x, pool.y)

            -- Show waypoint number
            if i == navState.currentWaypoint then
                pin.Number:SetText("|cFF00FF00" .. i .. "|r")
            else
                pin.Number:SetText("|cFF00D1FF" .. i .. "|r")
            end
            pin.Number:Show()
            pin:Show()

            routePins[i] = pin
        end
    end

    -- Connect consecutive pins with lines
    for i = 1, #route do
        local nextI = (i % #route) + 1
        if routePins[i] and routePins[nextI] then
            local connection = connectionPool:Acquire()
            connection:Connect(routePins[i], routePins[nextI])

            -- Color: current segment green, others cyan
            if i == navState.currentWaypoint then
                self:SetConnectionColor(connection, 0.2, 1, 0.2, 0.8)
            else
                self:SetConnectionColor(connection, 0, 0.82, 1, 0.5)
            end
            connection:Show()
        end
    end

    FK:Debug("DrawRoute: drew " .. #route .. " waypoints on map " .. mapID)
end

function Navigation:SetConnectionColor(connection, r, g, b, a)
    connection.Line:SetVertexColor(r, g, b, a)
end

function Navigation:ClearWorldMapRoute()
    if WorldMapFrame then
        WorldMapFrame:RemoveAllPinsByTemplate("FishingKitRoutePinTemplate")
    end
    if connectionPool then
        connectionPool:ReleaseAll()
    end
end

function Navigation:UpdateWorldMapRoute()
    -- Lazy-hook the world map if not done yet
    self:HookWorldMap()

    -- Refresh route display if world map is open
    if WorldMapFrame and WorldMapFrame:IsShown() then
        self:DrawRouteOnWorldMap()
    end
end

-- Hook world map open/close to draw/clear route
local worldMapHooked = false
function Navigation:HookWorldMap()
    if worldMapHooked then return end
    if not WorldMapFrame then FK:Debug("HookWorldMap: WorldMapFrame not available yet"); return end

    FK:Debug("HookWorldMap: Hooking WorldMapFrame now")

    hooksecurefunc(WorldMapFrame, "Show", function()
        FK:Debug("HookWorldMap: Show hook fired, active=" .. tostring(navState.active))
        if navState.active then
            -- Slight delay to let map finish rendering
            C_Timer.After(0.1, function()
                Navigation:DrawRouteOnWorldMap()
            end)
        end
    end)

    -- Also hook map ID changes (when player clicks different zone on world map)
    if WorldMapFrame.AddDataProvider then
        -- Hook the existing refresh mechanism
        hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
            if navState.active then
                C_Timer.After(0.05, function()
                    Navigation:DrawRouteOnWorldMap()
                end)
            end
        end)
    end

    worldMapHooked = true
end

-- ============================================================================
-- GatherMate2 Import
-- ============================================================================

function Navigation:ImportFromGatherMate2()
    -- Check if GatherMate2 fish data exists
    if not GatherMate2FishDB then
        FK:Print("GatherMate2 fishing data not found. Make sure GatherMate2 is installed and you have collected fishing data.", FK.Colors.warning)
        return 0, 0
    end

    if not FK.db then return 0, 0 end
    if not FK.db.poolLocations then FK.db.poolLocations = {} end

    local totalImported = 0
    local totalZones = 0
    local DEDUP_RANGE = 0.005  -- 0.5% map distance (~5 yards), matching Pools.lua

    for uiMapID, coordTable in pairs(GatherMate2FishDB) do
        local zoneImported = 0

        if not FK.db.poolLocations[uiMapID] then
            FK.db.poolLocations[uiMapID] = {}
        end

        local existingPools = FK.db.poolLocations[uiMapID]

        for encodedCoord, nodeID in pairs(coordTable) do
            -- Decode GatherMate2 coordinate format
            local x = floor(encodedCoord / 1000000) / 10000
            local y = floor(encodedCoord % 1000000 / 100) / 10000

            -- Skip invalid coordinates
            if x > 0 and x < 1 and y > 0 and y < 1 then
                -- Map node ID to pool name
                local poolName = GM2_NODE_NAMES[nodeID]
                if not poolName then
                    poolName = "Fishing Pool #" .. nodeID
                end

                -- Dedup check against existing pools
                local isDuplicate = false
                for _, existing in ipairs(existingPools) do
                    local dx = abs(existing.x - x)
                    local dy = abs(existing.y - y)
                    if dx < DEDUP_RANGE and dy < DEDUP_RANGE then
                        isDuplicate = true
                        break
                    end
                end

                if not isDuplicate then
                    table.insert(existingPools, {
                        name = poolName,
                        x = x,
                        y = y,
                        lastSeen = time(),
                        timesSeen = 1,
                    })
                    zoneImported = zoneImported + 1
                end
            end
        end

        if zoneImported > 0 then
            totalZones = totalZones + 1
            totalImported = totalImported + zoneImported
        end
    end

    -- Refresh map pins
    if FK.Pools and FK.Pools.RefreshAllPins then
        FK.Pools:RefreshAllPins()
    end

    if totalImported > 0 then
        FK:Print("Imported " .. totalImported .. " pools from GatherMate2 across " .. totalZones .. " zone(s).", FK.Colors.success)
    else
        FK:Print("No new pools to import from GatherMate2 (all already known).", FK.Colors.info)
    end

    return totalImported, totalZones
end

-- ============================================================================
-- Initialization
-- ============================================================================

function Navigation:Initialize()
    -- Create arrow frame (hidden by default)
    CreateArrowFrame()
    self:LoadArrowPosition()

    -- Try to hook world map now (may not exist yet if load-on-demand)
    self:HookWorldMap()

    -- If WorldMapFrame doesn't exist yet, hook it when Blizzard_WorldMap loads
    if not worldMapHooked then
        local loader = CreateFrame("Frame")
        loader:RegisterEvent("ADDON_LOADED")
        loader:SetScript("OnEvent", function(self, event, addonName)
            if addonName == "Blizzard_WorldMap" then
                Navigation:HookWorldMap()
                self:UnregisterAllEvents()
            end
        end)
    end

    FK:Debug("Navigation module initialized")
end

FK:Debug("Navigation module loaded")
