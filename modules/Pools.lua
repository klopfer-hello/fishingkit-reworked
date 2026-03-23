--[[
    FishingKit - TBC Anniversary Edition
    Pools Module - Fishing pool detection, tracking, map pins, and Find Fish

    This module handles:
    - Detecting fishing pools via tooltip scanning
    - Persistent pool location storage (survives logout/reload)
    - Minimap pool pins with world coordinate math
    - World map pool pins via MapCanvasDataProviderMixin
    - Find Fish tracking auto-toggle on gear swap
    - Tracking pool respawn timers
    - Zone-based pool information
]]

local ADDON_NAME, FK = ...

FK.Pools = {}
local Pools = FK.Pools

-- Pool tracking state
local poolState = {
    nearbyPools = {},
    lastScan = 0,
    scanInterval = 1.0,
    hasFindFish = false,
    lastPoolFished = nil,
    poolsFished = {},
}

-- Pool names for tooltip detection
-- Complete list of all fishing pool names for Classic + TBC
local poolPatterns = {
    -- Classic
    "Floating Wreckage",
    "Patch of Elemental Water",
    "Floating Debris",
    "Oil Spill",
    "Firefin Snapper School",
    "Greater Sagefish School",
    "Oily Blackmouth School",
    "Sagefish School",
    "School of Deviate Fish",
    "Stonescale Eel Swarm",
    "School of Tastyfish",
    "Floating Wreckage Pool",
    "Waterlogged Wreckage Pool",
    "Bloodsail Wreckage Pool",
    "Schooner Wreckage",
    "Mixed Ocean School",
    -- TBC
    "Highland Mixed School",
    "Pure Water",
    "Bluefish School",
    "Feltail School",
    "Brackish Mixed School",
    "Mudfish School",
    "School of Darter",
    "Sporefish School",
    "Steam Pump Flotsam",
    "Spotted Feltail School",
}

-- ============================================================================
-- Minimap Pin Constants
-- ============================================================================

local DEDUP_DISTANCE = 0.005  -- ~0.5% map distance for deduplication
local MINIMAP_UPDATE_THROTTLE = 0.1

-- Forward declarations (also exposed on FK.Pools for Navigation module)
local GetMapData, ZoneToWorld, UpdateIndoors

-- Minimap size in yards by indoor/outdoor and zoom level
-- Minimap yard radius by indoor/outdoor and zoom level
local minimapSize = {
    indoor = {
        [0] = 300,
        [1] = 240,
        [2] = 180,
        [3] = 120,
        [4] = 80,
        [5] = 50,
    },
    outdoor = {
        [0] = 466 + 2/3,
        [1] = 400,
        [2] = 333 + 1/3,
        [3] = 266 + 2/6,
        [4] = 200,
        [5] = 133 + 1/3,
    },
}

-- Cached map data: { width, height, left, top } per uiMapID
-- Precomputed from C_Map.GetWorldPosFromMapPos at zone change
local mapDataCache = {}

-- Minimap pin pool
local MAX_MINIMAP_PINS = 30
local minimapPins = {}
local minimapPinIndex = 0
local minimapUpdateFrame = nil
local indoors = "outdoor"

-- World map pin state
local worldMapProvider = nil

-- ============================================================================
-- Static Pool Data Merge
-- ============================================================================

function Pools:MergePoolData()
    if not FK.PoolData then return end

    local merged = 0
    for mapID, pools in pairs(FK.PoolData) do
        if not FK.db.poolLocations[mapID] then
            FK.db.poolLocations[mapID] = {}
        end

        local existing = FK.db.poolLocations[mapID]
        for _, staticPool in ipairs(pools) do
            -- Check if a matching pool already exists within dedup range
            local isDuplicate = false
            for _, saved in ipairs(existing) do
                local dx = math.abs(saved.x - staticPool.x)
                local dy = math.abs(saved.y - staticPool.y)
                if dx < DEDUP_DISTANCE and dy < DEDUP_DISTANCE then
                    isDuplicate = true
                    break
                end
            end

            if not isDuplicate then
                table.insert(existing, {
                    name = staticPool.name,
                    x = staticPool.x,
                    y = staticPool.y,
                    timesSeen = 0,
                    lastSeen = 0,
                })
                merged = merged + 1
            end
        end
    end

    if merged > 0 then
        FK:Debug("Merged " .. merged .. " static pool locations from PoolData")
    end
end

-- ============================================================================
-- Initialization
-- ============================================================================

function Pools:Initialize()
    -- Merge static PoolData into saved pool locations
    self:MergePoolData()

    -- Check if player has Find Fish ability
    self:CheckFindFish()

    -- Create tooltip for scanning
    self:CreateScanTooltip()

    -- Hook GameTooltip for pool detection on mouseover
    self:HookTooltip()

    -- Initialize minimap pins
    self:InitMinimapPins()

    -- Initialize world map pins
    self:InitWorldMapPins()

    -- Register static popup for clearing pool data
    StaticPopupDialogs["FISHINGKIT_CLEAR_POOLS"] = {
        text = "Clear ALL discovered pool locations? This cannot be undone.",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            Pools:ClearPoolData()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    -- Subscribe to fishing events
    FK.Events:On("FISHING_LOOT_OPENED", function() Pools:RecordPoolFromCatch() end)
    FK.Events:On("ZONE_CHANGED",        function() Pools:OnZoneChanged() end)

    FK:Debug("Pools module initialized")
end

function Pools:CreateScanTooltip()
    if not FishingKitScanTooltip then
        local tooltip = CreateFrame("GameTooltip", "FishingKitScanTooltip", UIParent, "GameTooltipTemplate")
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
end

function Pools:CheckFindFish()
    local findFishSpellID = 43308
    local name = GetSpellInfo(findFishSpellID)

    if name and IsSpellKnown(findFishSpellID) then
        poolState.hasFindFish = true
        FK:Debug("Find Fish ability detected")
    else
        poolState.hasFindFish = false
    end

    -- Also check for Weather-Beaten Fishing Hat (which grants Find Fish)
    local headLink = GetInventoryItemLink("player", 1)
    if headLink then
        local itemID = string.match(headLink, "item:(%d+)")
        if itemID and tonumber(itemID) == 33820 then
            poolState.hasFindFish = true
        end
    end

    return poolState.hasFindFish
end

-- ============================================================================
-- Pool Detection via Mouseover
-- ============================================================================

function Pools:ScanMouseover()
    if not FK.db.settings.trackPools then return nil end

    local name = GameTooltip:GetUnit()
    if name then return nil end

    local tooltipText = GameTooltipTextLeft1:GetText()

    if tooltipText then
        if self:IsPoolName(tooltipText) then
            return tooltipText
        end
    end

    return nil
end

function Pools:IsPoolName(name)
    if not name then return false end

    local lowerName = string.lower(name)

    for _, pattern in ipairs(poolPatterns) do
        if string.find(lowerName, string.lower(pattern)) then
            return true
        end
    end

    -- Check against database pool names
    for poolName, _ in pairs(FK.Database.Pools) do
        if string.find(lowerName, string.lower(poolName)) then
            return true
        end
    end

    return false
end

-- ============================================================================
-- Tooltip Hook - Detect pools on mouseover (no fishing required)
-- ============================================================================

function Pools:HookTooltip()
    -- Hook GameTooltip to detect pools on mouseover
    -- Tracks last seen pool name for use when we catch a fish
    GameTooltip:HookScript("OnShow", function(tip)
        if not FK.db or not FK.db.settings.trackPools then return end

        local text = GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()
        if text and self:IsPoolName(text) then
            -- Remember the pool name for when we catch from it
            poolState.lastSeenPoolName = text
            poolState.lastSeenPoolTime = GetTime()

            if FK.db.settings.poolSound then
                PlaySound(SOUNDKIT.TELL_MESSAGE or 3081)
            end
            FK:Debug("Pool spotted: " .. text)
        end
    end)
end

function Pools:OnCursorChanged()
    -- CURSOR_CHANGED fires at close range (~10-15 yards).
    -- Record with 15-yard facing offset for accuracy.
    if not FK.db or not FK.db.settings.trackPools then return end

    C_Timer.After(0.05, function()
        local poolName = self:ScanMouseover()
        if poolName then
            poolState.lastSeenPoolName = poolName
            poolState.lastSeenPoolTime = GetTime()
            self:RecordPoolLocation(poolName)
        end
    end)
end

function Pools:RecordPoolFromCatch()
    -- Called on LOOT_OPENED while fishing.
    -- The bobber is AT the pool, so the 15-yard facing offset is the
    -- most accurate position we can get. Always update existing entries.
    if not FK.db or not FK.db.settings.trackPools then return end

    -- Use the last seen pool name (from tooltip or cursor change)
    -- Only if it was seen recently (within 60 seconds)
    local poolName = poolState.lastSeenPoolName
    if not poolName or not poolState.lastSeenPoolTime then return end
    if GetTime() - poolState.lastSeenPoolTime > 60 then return end

    self:RecordPoolLocation(poolName)
    FK:Debug("Pool location updated from catch: " .. poolName)
end

-- ============================================================================
-- Persistent Pool Storage
-- ============================================================================

function Pools:RecordPoolLocation(poolName)
    if not poolName or not FK.db then return end

    local uiMapID = C_Map.GetBestMapForUnit("player")
    if not uiMapID then return end

    local position = C_Map.GetPlayerMapPosition(uiMapID, "player")
    if not position then return end

    local x, y = position:GetXY()
    if x == 0 and y == 0 then return end

    -- Offset 15 yards in the direction the player is facing
    -- The pool is in front of the player, not at the player's feet
    local facing = GetPlayerFacing()
    if facing then
        local mapData = GetMapData(uiMapID)
        if mapData and mapData.width > 0 and mapData.height > 0 then
            local rad = facing + math.pi
            x = x + math.sin(rad) * 15 / mapData.width
            y = y + math.cos(rad) * 15 / mapData.height
        end
    end

    -- Ensure storage exists
    if not FK.db.poolLocations then
        FK.db.poolLocations = {}
    end
    if not FK.db.poolLocations[uiMapID] then
        FK.db.poolLocations[uiMapID] = {}
    end

    -- Deduplicate: only merge if same pool name AND very close (a few steps apart)
    -- 0.005 = 0.5% of map width, roughly 5 yards on a typical zone map
    local DEDUP_RANGE = 0.005
    local pools = FK.db.poolLocations[uiMapID]
    local now = time()
    for _, existing in ipairs(pools) do
        if existing.name == poolName then
            local dx = math.abs(existing.x - x)
            local dy = math.abs(existing.y - y)
            if dx < DEDUP_RANGE and dy < DEDUP_RANGE then
                -- Same pool, same spot - just update timestamp
                local elapsed = now - (existing.lastSeen or 0)
                if elapsed >= 300 then
                    existing.timesSeen = (existing.timesSeen or 1) + 1
                    FK:Debug("Pool re-sighted: " .. poolName .. " (seen " .. existing.timesSeen .. "x)")
                end
                existing.lastSeen = now
                self:RefreshAllPins()
                return
            end
        end
    end

    -- New pool location
    table.insert(pools, {
        name = poolName,
        x = x,
        y = y,
        lastSeen = time(),
        timesSeen = 1,
    })

    FK:Debug("Pool location recorded: " .. poolName .. " at " .. string.format("%.1f, %.1f", x * 100, y * 100))

    -- Refresh pins
    self:RefreshAllPins()

    -- Notify Navigation module of new pool discovery
    if FK.Navigation and FK.Navigation:IsActive() and FK.Navigation.OnPoolDiscovered then
        FK.Navigation:OnPoolDiscovered(pools[#pools])
    end
end

function Pools:GetPoolLocationsForMap(uiMapID)
    if not FK.db or not FK.db.poolLocations then return {} end
    return FK.db.poolLocations[uiMapID] or {}
end

function Pools:ClearPoolData()
    if FK.db then
        FK.db.poolLocations = {}
        FK:Print("All pool location data cleared.", FK.Colors.success)
        self:RefreshAllPins()
    end
end

function Pools:ClearZonePoolData()
    if not FK.db then return end

    local uiMapID = C_Map.GetBestMapForUnit("player")
    if not uiMapID then
        FK:Print("Could not determine current zone.", FK.Colors.warning)
        return
    end

    if FK.db.poolLocations and FK.db.poolLocations[uiMapID] then
        local count = #FK.db.poolLocations[uiMapID]
        FK.db.poolLocations[uiMapID] = {}
        FK:Print("Cleared " .. count .. " pool locations for current zone.", FK.Colors.success)
        self:RefreshAllPins()
    else
        FK:Print("No pool data for current zone.", FK.Colors.info)
    end
end

-- ============================================================================
-- Pool Tracking (in-memory, same as before)
-- ============================================================================

function Pools:OnPoolDetected(poolName, x, y)
    if not poolName then return end

    local zone = FK.State.currentZone
    local timestamp = GetTime()

    local key = zone .. "_" .. (x or 0) .. "_" .. (y or 0)

    if not poolState.nearbyPools[key] then
        poolState.nearbyPools[key] = {
            name = poolName,
            zone = zone,
            x = x,
            y = y,
            firstSeen = timestamp,
            lastSeen = timestamp,
            timesFished = 0,
        }

        if FK.db.settings.poolSound then
            PlaySound(SOUNDKIT.TELL_MESSAGE or 3081)
        end

        FK:Debug("Pool detected: " .. poolName)
    else
        poolState.nearbyPools[key].lastSeen = timestamp
    end

    -- Also record to persistent storage
    self:RecordPoolLocation(poolName)
end

function Pools:OnPoolFished(poolName)
    local zone = FK.State.currentZone

    for key, pool in pairs(poolState.nearbyPools) do
        if pool.name == poolName and pool.zone == zone then
            pool.timesFished = pool.timesFished + 1
            pool.lastFished = GetTime()
            poolState.lastPoolFished = pool
            break
        end
    end

    if not poolState.poolsFished[poolName] then
        poolState.poolsFished[poolName] = 0
    end
    poolState.poolsFished[poolName] = poolState.poolsFished[poolName] + 1
end

function Pools:CleanupOldPools()
    local now = GetTime()
    local expireTime = 600

    for key, pool in pairs(poolState.nearbyPools) do
        if now - pool.lastSeen > expireTime then
            poolState.nearbyPools[key] = nil
        end
    end
end

-- ============================================================================
-- Zone Change Handler
-- ============================================================================

function Pools:OnZoneChanged()
    poolState.nearbyPools = {}
    poolState.lastPoolFished = nil

    -- Update indoor/outdoor detection for minimap radius
    UpdateIndoors()

    self:CheckFindFish()

    -- Refresh pins for new zone
    self:RefreshAllPins()

    -- Notify Navigation module of zone change
    if FK.Navigation and FK.Navigation.OnZoneChanged then
        FK.Navigation:OnZoneChanged()
    end
end

-- ============================================================================
-- Pin Appearance Helpers
-- ============================================================================

-- Pool pin colors: cyan for discovered, muted purple for community (static) data
local PIN_COLOR = { r = 0, g = 0.8, b = 1, a = 0.9 }
local PIN_BORDER_COLOR = { r = 0, g = 0.5, b = 0.7, a = 1 }
local PIN_COMMUNITY_COLOR = { r = 0.7, g = 1.0, b = 0.0, a = 0.9 }
local PIN_COMMUNITY_BORDER = { r = 0.5, g = 0.8, b = 0.0, a = 1.0 }

local function IsStaticPool(poolData)
    return poolData and (poolData.timesSeen or 0) == 0 and (poolData.lastSeen or 0) == 0
end

-- Expose for Navigation module
function Pools:IsStaticPool(poolData)
    return IsStaticPool(poolData)
end

local function FormatTimeAgo(timestamp)
    if not timestamp or timestamp == 0 then return nil end
    local ago = time() - timestamp
    if ago < 60 then
        return "Just now"
    elseif ago < 3600 then
        return math.floor(ago / 60) .. "m ago"
    elseif ago < 86400 then
        return math.floor(ago / 3600) .. "h ago"
    else
        return math.floor(ago / 86400) .. "d ago"
    end
end

local function AddPoolTooltipInfo(poolData)
    if IsStaticPool(poolData) then
        GameTooltip:AddLine("Community Pool Data", 0.7, 1.0, 0.0)
        GameTooltip:AddLine("Fish here to confirm this location", 0.5, 0.5, 0.5)
    else
        GameTooltip:AddLine("Seen: " .. (poolData.timesSeen or 1) .. " time(s)", 1, 1, 1)
        local agoStr = FormatTimeAgo(poolData.lastSeen)
        if agoStr then
            GameTooltip:AddLine("Last seen: " .. agoStr, 0.7, 0.7, 0.7)
        end
    end
    GameTooltip:AddLine(string.format("%.1f, %.1f", poolData.x * 100, poolData.y * 100), 0.5, 0.5, 0.5)
end

local function ColorPinForPool(pin, poolData)
    if IsStaticPool(poolData) then
        pin.dot:SetVertexColor(PIN_COMMUNITY_COLOR.r, PIN_COMMUNITY_COLOR.g, PIN_COMMUNITY_COLOR.b, PIN_COMMUNITY_COLOR.a)
        pin.border:SetVertexColor(PIN_COMMUNITY_BORDER.r, PIN_COMMUNITY_BORDER.g, PIN_COMMUNITY_BORDER.b, PIN_COMMUNITY_BORDER.a)
    else
        pin.dot:SetVertexColor(PIN_COLOR.r, PIN_COLOR.g, PIN_COLOR.b, PIN_COLOR.a)
        pin.border:SetVertexColor(PIN_BORDER_COLOR.r, PIN_BORDER_COLOR.g, PIN_BORDER_COLOR.b, PIN_BORDER_COLOR.a)
    end
end

local function SetupPoolPinTooltip(pin)
    pin:SetScript("OnEnter", function(self)
        if self.poolData then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:SetText(self.poolData.name, 0, 0.82, 1)
            AddPoolTooltipInfo(self.poolData)
            GameTooltip:Show()
        end
    end)
    pin:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function CreatePoolPin(name, parent, size)
    local pin = CreateFrame("Button", name, parent)
    pin:SetSize(size, size)
    pin:EnableMouse(true)

    -- Outer ring (border)
    local border = pin:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetTexture("Interface\\AddOns\\FishingKit\\media\\track_circle")
    border:SetVertexColor(PIN_BORDER_COLOR.r, PIN_BORDER_COLOR.g, PIN_BORDER_COLOR.b, PIN_BORDER_COLOR.a)
    pin.border = border

    -- Inner filled circle
    local dot = pin:CreateTexture(nil, "ARTWORK")
    dot:SetPoint("TOPLEFT", 2, -2)
    dot:SetPoint("BOTTOMRIGHT", -2, 2)
    dot:SetTexture("Interface\\AddOns\\FishingKit\\media\\track_circle")
    dot:SetVertexColor(PIN_COLOR.r, PIN_COLOR.g, PIN_COLOR.b, PIN_COLOR.a)
    pin.dot = dot

    -- Highlight on hover - slightly brighter
    local highlight = pin:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture("Interface\\AddOns\\FishingKit\\media\\track_circle")
    highlight:SetVertexColor(1, 1, 1, 0.3)
    highlight:SetBlendMode("ADD")

    SetupPoolPinTooltip(pin)
    return pin
end

-- ============================================================================
-- Map Data Cache (precompute map dimensions at zone change)
-- ============================================================================

-- Get or compute map data for a zone
GetMapData = function(uiMapID)
    if mapDataCache[uiMapID] then return mapDataCache[uiMapID] end

    -- Use two points: (0,0) and (0.5,0.5) to compute map dimensions
    -- Use two reference points to compute world dimensions
    local vector00 = CreateVector2D(0, 0)
    local vector05 = CreateVector2D(0.5, 0.5)

    local _, topleft = C_Map.GetWorldPosFromMapPos(uiMapID, vector00)
    local _, center = C_Map.GetWorldPosFromMapPos(uiMapID, vector05)

    if not topleft or not center then return nil end

    -- NOTE: WoW world coords from GetWorldPosFromMapPos have SWAPPED axes
    -- GetXY() returns (north/south, east/west) not (east/west, north/south)
    local top, left = topleft:GetXY()
    local bottom, right = center:GetXY()

    local width = (left - right) * 2
    local height = (top - bottom) * 2

    if width == 0 or height == 0 then return nil end

    mapDataCache[uiMapID] = { width = width, height = height, left = left, top = top }
    return mapDataCache[uiMapID]
end

-- Convert normalized zone coords (0-1) to world coords
ZoneToWorld = function(x, y, mapData)
    return mapData.left - mapData.width * x, mapData.top - mapData.height * y
end

-- Expose GetMapData and ZoneToWorld on FK.Pools for Navigation module
function Pools:GetMapData(uiMapID)
    return GetMapData(uiMapID)
end

function Pools:ZoneToWorld(x, y, mapData)
    return ZoneToWorld(x, y, mapData)
end

-- Detect indoor/outdoor for minimap radius
UpdateIndoors = function()
    local zoom = Minimap:GetZoom()
    if GetCVar("minimapZoom") == GetCVar("minimapInsideZoom") then
        Minimap:SetZoom(zoom < 2 and zoom + 1 or zoom - 1)
    end
    indoors = GetCVar("minimapZoom") + 0 == Minimap:GetZoom() and "outdoor" or "indoor"
    Minimap:SetZoom(zoom)
end

-- ============================================================================
-- Minimap Pins
-- ============================================================================

function Pools:InitMinimapPins()
    -- Detect indoor/outdoor
    UpdateIndoors()

    -- Create pin frames
    for i = 1, MAX_MINIMAP_PINS do
        local pin = CreatePoolPin("FishingKitMinimapPin" .. i, Minimap, 10)
        pin:SetFrameStrata("MEDIUM")
        pin:SetFrameLevel(Minimap:GetFrameLevel() + 5)
        pin:Hide()
        minimapPins[i] = pin
    end

    -- Create OnUpdate frame for minimap pin positioning
    minimapUpdateFrame = CreateFrame("Frame")
    local elapsed = 0
    minimapUpdateFrame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= MINIMAP_UPDATE_THROTTLE then
            elapsed = 0
            Pools:UpdateMinimapPins()
        end
    end)

    FK:Debug("Minimap pins initialized (" .. MAX_MINIMAP_PINS .. " pool)")
end

function Pools:UpdateMinimapPins()
    local hideAll = function()
        for i = 1, MAX_MINIMAP_PINS do
            minimapPins[i]:Hide()
        end
    end

    if not FK.db or not FK.db.settings.showPoolPins then
        hideAll()
        return
    end

    local uiMapID = C_Map.GetBestMapForUnit("player")
    if not uiMapID then hideAll(); return end

    -- Get precomputed map data for this zone
    local mapData = GetMapData(uiMapID)
    if not mapData then hideAll(); return end

    -- Get player world position via UnitPosition
    -- UnitPosition returns posY, posX, posZ, instanceID (note: Y before X!)
    local py, px = UnitPosition("player")
    if not px or not py then hideAll(); return end

    -- Minimap radius in yards
    local zoom = Minimap:GetZoom()
    local mapRadius = minimapSize[indoors][zoom] / 2

    -- Half-dimensions for pixel placement
    local minimapHalfW = Minimap:GetWidth() / 2
    local minimapHalfH = Minimap:GetHeight() / 2

    -- Rotation support
    local rotateMinimap = GetCVar("rotateMinimap") == "1"
    local sinFacing, cosFacing
    if rotateMinimap then
        local facing = GetPlayerFacing() or 0
        sinFacing = math.sin(facing)
        cosFacing = math.cos(facing)
    end

    -- Get pool locations for current map
    local pools = self:GetPoolLocationsForMap(uiMapID)

    -- Reset pin index
    minimapPinIndex = 0

    local hideCommunity = FK.db and FK.db.settings and not FK.db.settings.showCommunityPools

    for _, poolData in ipairs(pools) do
        if minimapPinIndex >= MAX_MINIMAP_PINS then break end

        -- Skip community pools when setting is off
        if not (hideCommunity and IsStaticPool(poolData)) then

            -- Convert pool's normalized zone coords to world coords
            local poolWX, poolWY = ZoneToWorld(poolData.x, poolData.y, mapData)

            -- Distance in yards: player minus pool
            local xDist = px - poolWX
            local yDist = py - poolWY

            -- Apply rotation if minimap rotates
            if rotateMinimap then
                local dx, dy = xDist, yDist
                xDist = dx * cosFacing - dy * sinFacing
                yDist = dx * sinFacing + dy * cosFacing
            end

            -- Normalize to minimap radius
            local diffX = xDist / mapRadius
            local diffY = yDist / mapRadius

            -- Check if within minimap circle (0.9 margin for edge clipping)
            local dist = (diffX * diffX + diffY * diffY) / 0.9^2
            if dist <= 1.0 then
                minimapPinIndex = minimapPinIndex + 1
                local pin = minimapPins[minimapPinIndex]
                pin.poolData = poolData
                ColorPinForPool(pin, poolData)
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", Minimap, "CENTER", diffX * minimapHalfW, -diffY * minimapHalfH)
                pin:Show()
            end
        end
    end

    -- Hide unused pins
    for i = minimapPinIndex + 1, MAX_MINIMAP_PINS do
        minimapPins[i]:Hide()
    end
end

-- ============================================================================
-- World Map Pins (MapCanvasDataProviderMixin + AcquirePin pattern)
-- ============================================================================

-- Global mixin for the XML template (FishingKitWorldMapPinTemplate)
FishingKitWorldMapPinMixin = CreateFromMixins(MapCanvasPinMixin)

function FishingKitWorldMapPinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    self:SetScalingLimits(1, 1.0, 1.2)
end

function FishingKitWorldMapPinMixin:OnAcquired(poolData)
    self:SetPosition(poolData.x, poolData.y)

    self.poolData = poolData

    -- Size
    self:SetSize(12, 12)

    -- Border and dot textures — colored by source (community vs discovered)
    self.border:SetTexture("Interface\\AddOns\\FishingKit\\media\\track_circle")
    self.dot:SetTexture("Interface\\AddOns\\FishingKit\\media\\track_circle")
    ColorPinForPool(self, poolData)
end

function FishingKitWorldMapPinMixin:OnMouseEnter()
    if self.poolData then
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText(self.poolData.name, 0, 0.82, 1)
        AddPoolTooltipInfo(self.poolData)
        GameTooltip:Show()
    end
end

function FishingKitWorldMapPinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

function Pools:InitWorldMapPins()
    if not WorldMapFrame or not WorldMapFrame.AddDataProvider then
        FK:Debug("WorldMapFrame.AddDataProvider not available, world map pins disabled")
        return
    end

    if not CreateFromMixins or not MapCanvasDataProviderMixin then
        FK:Debug("MapCanvasDataProviderMixin not available, world map pins disabled")
        return
    end

    local provider = CreateFromMixins(MapCanvasDataProviderMixin)

    function provider:RemoveAllData()
        self:GetMap():RemoveAllPinsByTemplate("FishingKitWorldMapPinTemplate")
    end

    function provider:RefreshAllData(fromOnShow)
        self:RemoveAllData()

        if not FK.db or not FK.db.settings.showPoolPins then return end

        local map = self:GetMap()
        if not map then return end

        local uiMapID = map:GetMapID()
        if not uiMapID then return end

        local pools = Pools:GetPoolLocationsForMap(uiMapID)

        local hideCommunity = FK.db and FK.db.settings and not FK.db.settings.showCommunityPools

        for _, poolData in ipairs(pools) do
            if not (hideCommunity and IsStaticPool(poolData)) then
                map:AcquirePin("FishingKitWorldMapPinTemplate", poolData)
            end
        end
    end

    worldMapProvider = provider
    WorldMapFrame:AddDataProvider(provider)

    FK:Debug("World map pins initialized (DataProvider)")
end

-- ============================================================================
-- Refresh All Pins
-- ============================================================================

function Pools:RefreshAllPins()
    -- Minimap pins are refreshed automatically via OnUpdate
    -- Force a world map refresh if it's open
    if worldMapProvider and WorldMapFrame and WorldMapFrame:IsShown() then
        worldMapProvider:RefreshAllData()
    end
end

-- ============================================================================
-- Find Fish Tracking
-- ============================================================================

function Pools:GetFindFishTrackingIndex()
    local numTypes = C_Minimap.GetNumTrackingTypes()
    for i = 1, numTypes do
        local info = C_Minimap.GetTrackingInfo(i)
        if info and info.name and (info.name == "Find Fish" or string.find(info.name, "Find Fish")) then
            return i, info.active
        end
    end
    return nil, false
end

function Pools:GetActiveTrackingIndex()
    local numTypes = C_Minimap.GetNumTrackingTypes()
    for i = 1, numTypes do
        local info = C_Minimap.GetTrackingInfo(i)
        if info and info.active then
            return i, info.name
        end
    end
    return nil, nil
end

function Pools:EnableFindFishTracking()
    if not FK.db or not FK.db.settings.autoFindFish then return end

    local findFishIdx, isActive = self:GetFindFishTrackingIndex()
    if not findFishIdx then
        FK:Debug("Find Fish tracking not available")
        return
    end

    if isActive then
        FK:Debug("Find Fish already active")
        return
    end

    -- Save current tracking
    local currentIdx, currentName = self:GetActiveTrackingIndex()
    if FK.chardb then
        FK.chardb.previousTracking = currentIdx
        FK:Debug("Saved previous tracking: " .. (currentName or "none") .. " (index " .. tostring(currentIdx) .. ")")
    end

    -- Enable Find Fish
    C_Minimap.SetTracking(findFishIdx, true)
    FK:Print("Find Fish tracking enabled.", FK.Colors.success)
end

function Pools:RestorePreviousTracking()
    if not FK.db or not FK.db.settings.autoFindFish then return end

    -- Disable Find Fish
    local findFishIdx = self:GetFindFishTrackingIndex()
    if findFishIdx then
        C_Minimap.SetTracking(findFishIdx, false)
    end

    -- Restore previous tracking
    if FK.chardb and FK.chardb.previousTracking then
        local prevIdx = FK.chardb.previousTracking
        local numTypes = C_Minimap.GetNumTrackingTypes()
        if prevIdx and prevIdx >= 1 and prevIdx <= numTypes then
            local info = C_Minimap.GetTrackingInfo(prevIdx)
            local name = info and info.name
            C_Minimap.SetTracking(prevIdx, true)
            FK:Print("Tracking restored to " .. (name or "previous") .. ".", FK.Colors.success)
        end
        FK.chardb.previousTracking = nil
    else
        FK:Print("Find Fish tracking disabled.", FK.Colors.info)
    end
end

-- ============================================================================
-- Pool Information
-- ============================================================================

function Pools:GetPoolInfo(poolName)
    return FK.Database:GetPoolInfo(poolName)
end

function Pools:GetPoolsForCurrentZone()
    local zone = FK.State.currentZone
    return FK.Database:GetPoolsForZone(zone)
end

function Pools:ShowNearbyPools()
    local zone = FK.State.currentZone

    FK:Print("=== Fishing Pools in " .. zone .. " ===", FK.Colors.highlight)

    local zonePools = self:GetPoolsForCurrentZone()

    if #zonePools == 0 then
        print(FK.Colors.info .. "No known fishing pools in this zone.|r")
    else
        for _, pool in ipairs(zonePools) do
            local poolInfo = pool.info
            local color = FK.Colors.fish

            if poolInfo.treasure then
                color = FK.Colors.highlight
            elseif poolInfo.reagent then
                color = FK.Colors.rare
            elseif poolInfo.special then
                color = FK.Colors.epic
            end

            print("  " .. color .. pool.name .. "|r")

            if poolInfo.fish and #poolInfo.fish > 0 then
                local fishNames = {}
                for _, fishID in ipairs(poolInfo.fish) do
                    local fishData = FK.Database:GetFishInfo(fishID)
                    if fishData then
                        table.insert(fishNames, fishData.name)
                    end
                end
                if #fishNames > 0 then
                    print("    Fish: " .. table.concat(fishNames, ", "))
                end
            end

            if poolInfo.minSkill then
                print("    Min Skill: " .. poolInfo.minSkill)
            end
        end
    end

    -- Show detected nearby pools (in-memory)
    local nearbyCount = 0
    for _, _ in pairs(poolState.nearbyPools) do
        nearbyCount = nearbyCount + 1
    end

    if nearbyCount > 0 then
        print(FK.Colors.info .. "\nDetected nearby: " .. nearbyCount .. " pool(s)|r")
    end

    -- Show persistent pool data for current zone
    local uiMapID = C_Map.GetBestMapForUnit("player")
    if uiMapID then
        local savedPools = self:GetPoolLocationsForMap(uiMapID)
        if #savedPools > 0 then
            print(FK.Colors.highlight .. "\nDiscovered pool locations: " .. #savedPools .. "|r")
            for _, p in ipairs(savedPools) do
                print("  " .. FK.Colors.fish .. p.name .. "|r - " ..
                      string.format("%.1f, %.1f", p.x * 100, p.y * 100) ..
                      " (seen " .. (p.timesSeen or 1) .. "x)")
            end
        end
    end

    -- Show Find Fish status
    if poolState.hasFindFish then
        print(FK.Colors.success .. "Find Fish: Active|r")
    else
        print(FK.Colors.warning .. "Find Fish: Not learned (Weather-Beaten Journal)|r")
    end
end

-- ============================================================================
-- Pool Recommendations
-- ============================================================================

function Pools:GetRecommendedPools()
    local skill = FK.Equipment:GetEffectiveSkill()
    local recommendations = {}

    for poolName, poolData in pairs(FK.Database.Pools) do
        if skill >= (poolData.minSkill or 1) then
            local value = "low"

            if poolData.treasure then
                value = "high"
            elseif poolData.reagent then
                value = "medium"
            elseif poolData.special then
                value = "high"
            elseif poolData.crawdad then
                value = "very high"
            end

            table.insert(recommendations, {
                name = poolName,
                minSkill = poolData.minSkill or 1,
                value = value,
                zone = poolData.zone,
                tbc = poolData.tbc,
            })
        end
    end

    table.sort(recommendations, function(a, b)
        return a.minSkill > b.minSkill
    end)

    return recommendations
end

function Pools:GetBestPoolForSkill()
    local skill = FK.Equipment:GetEffectiveSkill()
    local zone = FK.State.currentZone

    local zonePools = self:GetPoolsForCurrentZone()

    local bestPool = nil
    local bestSkill = 0

    for _, pool in ipairs(zonePools) do
        local poolInfo = pool.info
        local minSkill = poolInfo.minSkill or 1

        if skill >= minSkill and minSkill > bestSkill then
            bestPool = pool
            bestSkill = minSkill
        end
    end

    return bestPool
end

-- ============================================================================
-- TBC Highland Mixed School (Crawdad) Helper
-- ============================================================================

function Pools:GetCrawdadLocations()
    return {
        {
            name = "Lake Jorune",
            zone = "Terokkar Forest",
            coords = { x = 0.48, y = 0.56 },
            flying = true,
        },
        {
            name = "Lake Ere'Noru",
            zone = "Terokkar Forest",
            coords = { x = 0.57, y = 0.52 },
            flying = true,
        },
        {
            name = "Blackwind Lake",
            zone = "Terokkar Forest",
            coords = { x = 0.65, y = 0.76 },
            flying = true,
        },
        {
            name = "Silmyr Lake",
            zone = "Terokkar Forest",
            coords = { x = 0.55, y = 0.81 },
            flying = true,
        },
    }
end

function Pools:ShowCrawdadHelp()
    FK:Print("=== Furious Crawdad Fishing Guide ===", FK.Colors.highlight)
    print(FK.Colors.info .. "Requires: Flying mount, 400+ fishing skill|r")
    print("")
    print("Highland Mixed Schools spawn at elevated lakes in Terokkar:")

    for _, location in ipairs(self:GetCrawdadLocations()) do
        print("  " .. FK.Colors.highlight .. location.name .. "|r")
        print("    Coords: " .. string.format("%.0f%%, %.0f%%", location.coords.x * 100, location.coords.y * 100))
    end

    print("")
    print("Tips:")
    print("  - Pools spawn every 3-5 minutes")
    print("  - Circle between lakes for maximum efficiency")
    print("  - Mr. Pinchy grants 3 wishes (rare drop!)")
end

-- ============================================================================
-- Session Statistics
-- ============================================================================

function Pools:GetSessionPoolStats()
    return poolState.poolsFished
end

function Pools:HasFindFish()
    return poolState.hasFindFish
end

function Pools:GetNearbyPoolCount()
    local count = 0
    for _, _ in pairs(poolState.nearbyPools) do
        count = count + 1
    end
    return count
end

FK:Debug("Pools module loaded")
