--[[
    FishingKit - TBC Anniversary Edition
    Core Module - Main addon framework and initialization

    This module handles:
    - Addon initialization and event registration
    - Global state management
    - Slash command handling
    - Module coordination
]]

local ADDON_NAME, FK = ...

-- Global addon namespace
FishingKit = FK

-- Container API compatibility: TBC Anniversary uses C_Container namespace,
-- Classic Era uses legacy globals. Map legacy names to C_Container if needed.
if not GetContainerNumSlots and C_Container then
    GetContainerNumSlots = C_Container.GetContainerNumSlots
    GetContainerItemLink = C_Container.GetContainerItemLink
    PickupContainerItem = C_Container.PickupContainerItem
    GetContainerNumFreeSlots = C_Container.GetContainerNumFreeSlots
    UseContainerItem = C_Container.UseContainerItem
    -- C_Container.GetContainerItemInfo returns a table, legacy returns multiple values.
    -- Wrap it to return legacy-style: texture, itemCount, locked, quality, readable, lootable, itemLink, ...
    GetContainerItemInfo = function(bag, slot)
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if not info then return nil end
        return info.iconFileID, info.stackCount, info.isLocked, info.quality,
               info.isReadable, info.hasLoot, info.hyperlink, info.isFiltered,
               info.hasNoValue, info.itemID, info.isBound
    end
end

-- Version info
FK.VERSION = "1.2.0"
FK.BUILD = "TBC-Anniversary"

-- Addon state
FK.initialized = false
FK.debugMode = false

-- Fishing state tracking
FK.State = {
    isFishing = false,
    castStartTime = nil,  -- nil when not fishing, GetTime() when cast starts
    castGen = 0,           -- increments on each new cast, used to ignore stale events
    waitingForLoot = false,  -- true between channel stop and loot window
    bobberGUID = nil,
    currentZone = "",
    currentSubZone = "",
    hasLure = false,
    lureExpireTime = 0,
    fishingSkill = 0,
    fishingSkillModifier = 0,
    sessionStartTime = 0,
    sessionActive = false,
    combatSwapQueued = false,
}

-- Color codes for chat messages
FK.Colors = {
    addon = "|cFF00D1FF",      -- Cyan for addon name
    success = "|cFF00FF00",     -- Green
    warning = "|cFFFFFF00",     -- Yellow
    error = "|cFFFF0000",       -- Red
    info = "|cFFAAAAAA",        -- Gray
    highlight = "|cFFFFD700",   -- Gold
    fish = "|cFF1EFF00",        -- Fish green
    rare = "|cFF0070DD",        -- Rare blue
    epic = "|cFFA335EE",        -- Epic purple
    legendary = "|cFFFF8000",   -- Legendary orange
}

-- Fishing spell IDs and names
FK.FishingSpellID = 7620
FK.FishingSpellName = "Fishing"

-- Default saved variables structure
local defaultDB = {
    -- Global settings
    settings = {
        enabled = true,
        showUI = true,
        locked = false,
        scale = 1.0,
        showMinimap = true,
        collapsed = false,

        -- Alert settings
        soundEnabled = true,
        soundVolume = 1.0,
        visualAlert = true,
        screenFlash = false,

        -- Pool settings
        trackPools = true,
        poolSound = true,
        showPoolPins = true,
        showCommunityPools = true,
        autoFindFish = true,

        -- Equipment settings
        autoEquip = false,
        autoLure = false,
        autoLureReapply = false,
        autoCombatSwap = true,
        autoOpenContainers = true,

        -- v1.0.5 features
        enhancedSound = true,
        enhanceSoundScale = 1.0,
        missingLureWarning = true,
        missingLureInterval = 60,
        milestones = true,

        -- Casting settings
        doubleClickCast = true,

        -- Navigation settings
        poolNavEnabled = true,
        poolNavArrow = true,
        poolNavWorldMapRoute = true,
        poolNavArrivalDistance = 20,
        poolNavSound = true,
        arrowPosition = nil,

        -- Cycle fish alerts
        cycleFishAlerts = true,

        -- Daily quest tracker
        dailyQuestReminder = true,

        -- Statistics settings
        trackStats = true,
        trackLoot = true,

        -- UI position
        position = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 200,
        },
    },

    -- Discovered pool locations (account-wide, keyed by uiMapID)
    poolLocations = {},

    -- Cached AH prices (account-wide, keyed by itemID, value in copper)
    ahPrices = {},
    -- Unix timestamps of last successful scan per itemID (used to skip stale-safe items)
    ahPriceTimes = {},

    -- Global statistics (all characters)
    globalStats = {
        totalCasts = 0,
        totalCatches = 0,
        totalJunk = 0,
        fishCaught = {},
        zoneStats = {},
    },

    -- Auto-backup
    lastBackupTime = 0,
    backup = nil,
}

local defaultCharDB = {
    -- Per-character statistics
    stats = {
        totalCasts = 0,
        totalCatches = 0,
        totalJunk = 0,
        totalGotAway = 0,
        sessionCasts = 0,
        sessionCatches = 0,
        fishCaught = {},
        rareCatches = {},
        zoneStats = {},
        skillUps = 0,
        lastSkillUp = 0,
    },

    -- Loot history
    lootHistory = {},

    -- Equipment sets
    fishingGear = {
        mainHand = nil,
        head = nil,
        hands = nil,
        feet = nil,
        offHand = nil,
    },
    normalGear = {
        mainHand = nil,
        head = nil,
        hands = nil,
        feet = nil,
        offHand = nil,
    },

    -- Weapons-only subset of normalGear for in-combat equip.
    -- Populated automatically by SaveNormalGear so it always reflects the
    -- weapons the player had before equipping fishing gear.
    combatWeapons = {
        mainHand = nil,
        offHand = nil,
    },

    -- Session data
    sessions = {},

    -- Previous tracking type (for Find Fish restore)
    previousTracking = nil,

    -- Fishing goals (session targets)
    goals = {},

    -- Catch & release list (auto-delete junk fish on catch)
    releaseList = {},

    -- Bite timings per zone (for confidence band on cast bar)
    biteTimings = {},

    -- Auto-backup
    backup = nil,
}

-- ============================================================================
-- Utility Functions
-- ============================================================================

function FK:Print(msg, color)
    color = color or FK.Colors.info
    print(FK.Colors.addon .. "FishingKit|r: " .. color .. msg .. "|r")
end

function FK:Debug(msg)
    if FK.debugMode then
        print(FK.Colors.addon .. "FishingKit|r [DEBUG]: |cFFAAAAAA" .. msg .. "|r")
    end
end

function FK:FormatTime(seconds)
    if seconds < 60 then
        return string.format("%ds", seconds)
    elseif seconds < 3600 then
        return string.format("%dm %ds", math.floor(seconds / 60), seconds % 60)
    else
        local hours = math.floor(seconds / 3600)
        local mins = math.floor((seconds % 3600) / 60)
        return string.format("%dh %dm", hours, mins)
    end
end

function FK:FormatNumber(num)
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    else
        return tostring(num)
    end
end

function FK:TableCopy(t)
    local copy = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            copy[k] = FK:TableCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

-- ============================================================================
-- SavedVariable Backup System
-- ============================================================================

function FK:TableCopyExcluding(t, excludeKeys)
    local copy = {}
    for k, v in pairs(t) do
        if not excludeKeys[k] then
            if type(v) == "table" then
                copy[k] = FK:TableCopyExcluding(v, {})
            else
                copy[k] = v
            end
        end
    end
    return copy
end

function FK:CreateBackup()
    if not FK.db or not FK.chardb then return end

    -- Exclude large re-buildable arrays so the backup doesn't double SavedVariables size.
    -- Backed up: settings, globalStats counters/fishCaught, gear sets, goals, releaseList.
    -- NOT backed up: lootHistory (500 items), sessions (50), biteTimings, poolLocations,
    --                ahPrices/ahPriceTimes — all can be rebuilt by playing or rescanning.
    local dbCopy = FK:TableCopyExcluding(FK.db, {
        backup        = true,
        poolLocations = true,
        ahPrices      = true,
        ahPriceTimes  = true,
    })
    local charCopy = FK:TableCopyExcluding(FK.chardb, {
        backup       = true,
        lootHistory  = true,
        sessions     = true,
        biteTimings  = true,
    })

    FK.db.backup = dbCopy
    FK.chardb.backup = charCopy
    FK.db.lastBackupTime = time()

    FK:Print("Backup saved (settings + stats; history arrays excluded).", FK.Colors.success)
end

function FK:RestoreBackup()
    if not FK.db or not FK.db.backup then
        FK:Print("No backup found!", FK.Colors.error)
        return
    end

    -- Restore global DB
    local savedBackup = FK.db.backup
    local savedCharBackup = FK.chardb and FK.chardb.backup or nil
    local savedBackupTime = FK.db.lastBackupTime

    for k, v in pairs(savedBackup) do
        FK.db[k] = v
    end
    FK.db.backup = savedBackup
    FK.db.lastBackupTime = savedBackupTime

    -- Restore char DB
    if savedCharBackup then
        for k, v in pairs(savedCharBackup) do
            FK.chardb[k] = v
        end
        FK.chardb.backup = savedCharBackup
    end

    FK:Print("Backup restored. Type /reload to apply changes.", FK.Colors.warning)
end

function FK:GetBackupInfo()
    if not FK.db or FK.db.lastBackupTime == 0 then
        FK:Print("No backup exists yet.")
        return
    end

    local age = time() - FK.db.lastBackupTime
    local ageStr
    if age < 3600 then
        ageStr = math.floor(age / 60) .. " minutes ago"
    elseif age < 86400 then
        ageStr = string.format("%.1f hours ago", age / 3600)
    else
        ageStr = string.format("%.1f days ago", age / 86400)
    end

    FK:Print("Last backup: " .. date("%Y-%m-%d %H:%M", FK.db.lastBackupTime) .. " (" .. ageStr .. ") — covers settings and stats counters; lootHistory/sessions not included.")
end

function FK:CheckAutoBackup()
    if not FK.db then return end
    if time() - (FK.db.lastBackupTime or 0) > 86400 then
        FK:CreateBackup()
        FK:Print("Auto-backup complete (24h interval).")
    end
end

-- ============================================================================
-- Cycle Fish Time Helpers
-- ============================================================================

function FK:GetServerHour()
    local calendarTime = C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime and C_DateAndTime.GetCurrentCalendarTime()
    return calendarTime and calendarTime.hour or tonumber(date("%H"))
end

function FK:GetServerMonth()
    local calendarTime = C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime and C_DateAndTime.GetCurrentCalendarTime()
    return calendarTime and calendarTime.month or tonumber(date("%m"))
end

function FK:IsFishAvailable(itemID)
    local info = FK.Database and FK.Database.Fish and FK.Database.Fish[itemID]
    if not info then return true end

    -- Check time-of-day window
    if info.timeWindow then
        local hour = FK:GetServerHour()
        if info.timeWindow == "night" then
            if hour >= 6 and hour < 18 then return false end
        elseif info.timeWindow == "day" then
            if hour < 6 or hour >= 18 then return false end
        end
    end

    -- Check seasonal window
    if info.seasonal then
        local month = FK:GetServerMonth()
        if info.seasonal == "winter" then
            if month >= 4 and month <= 8 then return false end
        elseif info.seasonal == "summer" then
            if month < 3 or month > 9 then return false end
        end
    end

    return true
end

-- ============================================================================
-- Initialization
-- ============================================================================

local function InitializeSavedVariables()
    -- Initialize global database
    if not FishingKitDB then
        FishingKitDB = FK:TableCopy(defaultDB)
    else
        -- Merge defaults for any missing keys
        for k, v in pairs(defaultDB) do
            if FishingKitDB[k] == nil then
                FishingKitDB[k] = type(v) == "table" and FK:TableCopy(v) or v
            elseif type(v) == "table" then
                for k2, v2 in pairs(v) do
                    if FishingKitDB[k][k2] == nil then
                        FishingKitDB[k][k2] = type(v2) == "table" and FK:TableCopy(v2) or v2
                    end
                end
            end
        end
    end

    -- Initialize per-character database
    if not FishingKitCharDB then
        FishingKitCharDB = FK:TableCopy(defaultCharDB)
    else
        -- Merge defaults for any missing keys
        for k, v in pairs(defaultCharDB) do
            if FishingKitCharDB[k] == nil then
                FishingKitCharDB[k] = FK:TableCopy(v)
            elseif type(v) == "table" then
                for k2, v2 in pairs(v) do
                    if FishingKitCharDB[k][k2] == nil then
                        FishingKitCharDB[k][k2] = type(v2) == "table" and FK:TableCopy(v2) or v2
                    end
                end
            end
        end
    end

    -- Create shortcuts
    FK.db = FishingKitDB
    FK.chardb = FishingKitCharDB
end

local function UpdateZoneInfo()
    FK.State.currentZone = GetRealZoneText() or "Unknown"
    FK.State.currentSubZone = GetSubZoneText() or ""
end

local function UpdateFishingSkill()
    -- Get fishing skill from professions
    local skillName, skillRank, skillMaxRank

    -- TBC API for professions
    for i = 1, GetNumSkillLines() do
        local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
        if not isHeader and name == FK.FishingSpellName then
            FK.State.fishingSkill = rank or 0
            FK.State.fishingSkillMax = maxRank or 375
            FK:Debug("Fishing skill: " .. FK.State.fishingSkill .. "/" .. FK.State.fishingSkillMax)
            return
        end
    end

    FK.State.fishingSkill = 0
    FK.State.fishingSkillMax = 0
end

local function UpdateLureStatus()
    -- Check for fishing lure buffs on the main hand weapon
    local hasLure = false
    local lureExpireTime = 0

    -- Check for weapon enchant (temporary enchant = lure)
    local hasMainHandEnchant, mainHandExpiration = GetWeaponEnchantInfo()

    if hasMainHandEnchant then
        -- Check if the weapon is a fishing pole
        local mainHandLink = GetInventoryItemLink("player", 16) -- Main hand slot
        if mainHandLink then
            local _, _, _, _, _, itemType, itemSubType = GetItemInfo(mainHandLink)
            if itemSubType and (itemSubType == "Fishing Poles" or itemSubType == "Fishing Pole") then
                hasLure = true
                lureExpireTime = GetTime() + (mainHandExpiration / 1000)
            end
        end
    end

    FK.State.hasLure = hasLure
    FK.State.lureExpireTime = lureExpireTime
end

local function InitializeAddon()
    if FK.initialized then return end

    FK:Debug("Beginning initialization...")

    -- Initialize saved variables
    InitializeSavedVariables()

    -- Get initial state
    UpdateZoneInfo()
    UpdateFishingSkill()
    UpdateLureStatus()

    -- Initialize modules (they register themselves)
    if FK.Statistics and FK.Statistics.Initialize then
        FK.Statistics:Initialize()
    end

    if FK.Equipment and FK.Equipment.Initialize then
        FK.Equipment:Initialize()
    end

    if FK.Pools and FK.Pools.Initialize then
        FK.Pools:Initialize()
    end

    if FK.Navigation and FK.Navigation.Initialize then
        FK.Navigation:Initialize()
    end

    if FK.Alerts and FK.Alerts.Initialize then
        FK.Alerts:Initialize()
    end

    if FK.UI and FK.UI.Initialize then
        FK.UI:Initialize()
    end

    -- ZoneFish panel attaches to the main frame, so must init after UI
    if FK.ZoneFish and FK.ZoneFish.Initialize then
        FK.ZoneFish:Initialize()
    end

    if FK.Config and FK.Config.Initialize then
        FK.Config:Initialize()
    end

    if FK.DailyQuests and FK.DailyQuests.Initialize then
        FK.DailyQuests:Initialize()
    end

    if FK.AuctionHouse and FK.AuctionHouse.Initialize then
        FK.AuctionHouse:Initialize()
    end

    FK.initialized = true
    FK:Print("Loaded! Type " .. FK.Colors.highlight .. "/fk|r for options.", FK.Colors.success)

    -- Auto-backup check (10s delay to let everything settle)
    C_Timer.After(10, function()
        FK:CheckAutoBackup()
    end)
end

-- ============================================================================
-- Event Handling
-- ============================================================================

local eventFrame = CreateFrame("Frame", "FishingKitEventFrame")

-- Events to register
local events = {
    -- Addon lifecycle
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_LOGOUT",

    -- Fishing events
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP",

    -- Loot events
    "LOOT_READY",
    "LOOT_OPENED",
    "LOOT_CLOSED",

    -- Location events
    "ZONE_CHANGED",
    "ZONE_CHANGED_INDOORS",
    "ZONE_CHANGED_NEW_AREA",

    -- Skill events
    "CHAT_MSG_SKILL",
    "SKILL_LINES_CHANGED",

    -- Equipment events
    "PLAYER_EQUIPMENT_CHANGED",
    "UNIT_INVENTORY_CHANGED",

    -- Combat events (for gear swapping restrictions)
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",

    -- Cursor/targeting (for bobber detection)
    "CURSOR_CHANGED",
    "PLAYER_TARGET_CHANGED",

    -- Auction house (for price scanning)
    "AUCTION_HOUSE_SHOW",
    "AUCTION_HOUSE_CLOSED",
    "AUCTION_ITEM_LIST_UPDATE",

    -- Daily quest tracking
    "QUEST_TURNED_IN",
}

for _, event in ipairs(events) do
    eventFrame:RegisterEvent(event)
end

-- Event handlers table
local eventHandlers = {}

eventHandlers.ADDON_LOADED = function(addonName)
    if addonName == ADDON_NAME then
        InitializeAddon()
    end
end

eventHandlers.PLAYER_LOGIN = function()
    if not FK.initialized then
        InitializeAddon()
    end
    UpdateFishingSkill()
end

eventHandlers.PLAYER_ENTERING_WORLD = function()
    UpdateZoneInfo()
    UpdateFishingSkill()
    UpdateLureStatus()

    -- Start a new session if not already active
    if not FK.State.sessionActive and FK.db.settings.trackStats then
        FK.State.sessionStartTime = GetTime()
        FK.State.sessionActive = true
    end

    -- Remind player of active daily fishing quest (delayed so UI is ready)
    C_Timer.After(3, function()
        if FK.DailyQuests and FK.DailyQuests.CheckLoginReminder then
            FK.DailyQuests:CheckLoginReminder()
        end
    end)
end

eventHandlers.PLAYER_LOGOUT = function()
    -- Save session data
    if FK.Statistics and FK.Statistics.SaveSession then
        FK.Statistics:SaveSession()
    end
end

-- TBC Classic event signature: (unit, spell, rank, lineID, spellID)
-- Retail event signature: (unit, castGUID, spellID)
-- We handle both by checking the spell name from any argument
eventHandlers.UNIT_SPELLCAST_START = function(unit, arg2, arg3, arg4, arg5)
    if unit ~= "player" then return end

    -- In TBC, arg2 is spell name, arg5 is spellID
    -- In Retail, arg2 is castGUID, arg3 is spellID
    local spellName = arg2
    local spellID = arg5 or arg3

    -- Try to get spell name if we have an ID
    if spellID and type(spellID) == "number" then
        local name = GetSpellInfo(spellID)
        if name then spellName = name end
    end

    FK:Debug("SPELLCAST_START spell=" .. tostring(spellName) .. " id=" .. tostring(spellID))

    -- Check if this is a fishing cast
    local isFishing = (spellName == FK.FishingSpellName) or
                      (spellName == "Fishing") or
                      (spellID == FK.FishingSpellID) or
                      (spellID == 7620)

    FK:Debug("isFishing=" .. tostring(isFishing) .. " FishingSpellName=" .. tostring(FK.FishingSpellName) .. " FishingSpellID=" .. tostring(FK.FishingSpellID))

    if isFishing then
        FK.State.castGen = (FK.State.castGen or 0) + 1
        FK.State.isFishing = true
        FK.State.castStartTime = GetTime()
        FK.State.channelStarted = false  -- bobber not in water yet
        FK.State.waitingForLoot = false  -- Clear stale state from previous cast
        FK:Debug("Fishing cast started - spell: " .. tostring(spellName) .. " gen=" .. FK.State.castGen)

        -- Notify alerts module (sounds/visuals start immediately)
        if FK.Alerts and FK.Alerts.OnCastStart then
            FK.Alerts:OnCastStart()
        end

        -- Update UI (cast bar starts immediately)
        if FK.UI and FK.UI.OnFishingStart then
            FK.UI:OnFishingStart()
        end

        -- Clear double-click binding now that the cast fired
        if FK.UI and FK.UI.OnFishingCastStarted then
            FK.UI:OnFishingCastStarted()
        end
    end
end

-- Helper to check if spell is fishing (handles TBC and Retail signatures)
local function IsFishingSpell(arg2, arg3, arg4, arg5)
    local spellName = arg2
    local spellID = arg5 or arg3

    if spellID and type(spellID) == "number" then
        local name = GetSpellInfo(spellID)
        if name then spellName = name end
    end

    return (spellName == FK.FishingSpellName) or
           (spellName == "Fishing") or
           (spellID == FK.FishingSpellID) or
           (spellID == 7620)
end

eventHandlers.UNIT_SPELLCAST_STOP = function(unit, arg2, arg3, arg4, arg5)
    if unit ~= "player" then return end

    if IsFishingSpell(arg2, arg3, arg4, arg5) then
        -- Cast stopped (bobber is now in water or cast was cancelled)
        FK:Debug("Fishing cast stopped (bobber deployed or cancelled)")
    end
end

eventHandlers.UNIT_SPELLCAST_SUCCEEDED = function(unit, arg2, arg3, arg4, arg5)
    if unit ~= "player" then return end

    if IsFishingSpell(arg2, arg3, arg4, arg5) then
        FK:Debug("Fishing cast succeeded (bobber deployed)")
        -- Sound boost and watch setup happen at CHANNEL_START (when bobber hits
        -- the water), matching BetterFishing's timing exactly.
    end
end

eventHandlers.UNIT_SPELLCAST_FAILED = function(unit, arg2, arg3, arg4, arg5)
    if unit ~= "player" then return end

    FK:Debug("SPELLCAST_FAILED spell=" .. tostring(arg2) .. " isFishingCheck=" .. tostring(IsFishingSpell(arg2, arg3, arg4, arg5)))

    if IsFishingSpell(arg2, arg3, arg4, arg5) then
        -- Only reset if a new cast hasn't already started (castGen unchanged)
        local savedGen = FK.State.castGen
        C_Timer.After(0, function()
            if FK.State.castGen == savedGen then
                FK.State.isFishing = false
                FK:Debug("Fishing cast failed")
                FK:Debug("SPELLCAST_FAILED reset isFishing=false (gen=" .. savedGen .. ")")

                -- Update statistics (got away counter)
                if FK.Statistics and FK.Statistics.OnCastFailed then
                    FK.Statistics:OnCastFailed()
                end

                -- Update UI
                if FK.UI and FK.UI.OnFishingEnd then
                    FK.UI:OnFishingEnd()
                end

            else
                FK:Debug("SPELLCAST_FAILED ignored (gen changed " .. savedGen .. " -> " .. FK.State.castGen .. ")")
            end
        end)
    end
end

eventHandlers.UNIT_SPELLCAST_INTERRUPTED = function(unit, arg2, arg3, arg4, arg5)
    if unit ~= "player" then return end

    FK:Debug("SPELLCAST_INTERRUPTED spell=" .. tostring(arg2))

    if IsFishingSpell(arg2, arg3, arg4, arg5) then
        -- Only reset if a new cast hasn't already started (castGen unchanged)
        local savedGen = FK.State.castGen
        C_Timer.After(0, function()
            if FK.State.castGen == savedGen then
                local wasChanneling = FK.State.channelStarted
                FK.State.isFishing = false
                FK.State.channelStarted = false

                if wasChanneling then
                    -- Bobber was in water, this is "fish got away"
                    FK:Debug("INTERRUPTED fish got away (gen=" .. savedGen .. ")")
                    if FK.Statistics and FK.Statistics.OnCastFailed then
                        FK.Statistics:OnCastFailed()
                    end
                else
                    -- Bobber never deployed, user cancelled during cast animation
                    FK:Debug("INTERRUPTED user cancelled (gen=" .. savedGen .. ")")
                end

                -- Update UI
                if FK.UI and FK.UI.OnFishingEnd then
                    FK.UI:OnFishingEnd()
                end
            else
                FK:Debug("INTERRUPTED ignored (gen changed " .. savedGen .. " -> " .. FK.State.castGen .. ")")
            end
        end)
    end
end

eventHandlers.UNIT_SPELLCAST_CHANNEL_START = function(unit, arg2, arg3, arg4, arg5)
    if unit ~= "player" then return end

    FK:Debug("CHANNEL_START spell=" .. tostring(arg2) .. " isFishingCheck=" .. tostring(IsFishingSpell(arg2, arg3, arg4, arg5)))

    -- Fishing in TBC is a channel spell (bobber has landed in the water)
    if IsFishingSpell(arg2, arg3, arg4, arg5) then
        FK.State.isFishing = true
        FK.State.channelStarted = true  -- bobber is in the water
        FK.State.channelCastGen = FK.State.castGen  -- snapshot gen for this bobber
        -- Reset cast start time when bobber lands (handles re-cast where SPELLCAST_START may not fire)
        FK.State.castStartTime = GetTime()
        FK:Debug("CHANNEL_START set isFishing=true castStartTime=" .. tostring(FK.State.castStartTime))
        FK:Debug("Fishing channel started (bobber in water)")

        -- Boost sounds and start event watching now that the bobber is in the water.
        -- Mirrors BetterFishing: enhance at CHANNEL_START, restore at CHANNEL_STOP.
        if FK.Alerts and FK.Alerts.OnBobberLanded then
            FK.Alerts:OnBobberLanded()
        end
        -- Cast is counted at resolution (catch via OnLootReady, miss via 1s timeout)
        -- so we do NOT call OnCastStart here. Re-casts are simply never counted.
    end
end

eventHandlers.UNIT_SPELLCAST_CHANNEL_STOP = function(unit, arg2, arg3, arg4, arg5)
    if unit ~= "player" then return end

    if IsFishingSpell(arg2, arg3, arg4, arg5) then
        -- On a re-cast, SPELLCAST_START bumps castGen before CHANNEL_STOP fires
        -- for the old bobber (Scenario A).  channelCastGen (set at CHANNEL_START)
        -- still holds the old gen, so if they differ this is a stale CHANNEL_STOP
        -- from the cancelled cast — skip everything to avoid spurious timers.
        if FK.State.channelCastGen ~= FK.State.castGen then
            FK:Debug("CHANNEL_STOP ignored (stale re-cast, channelGen=" ..
                tostring(FK.State.channelCastGen) .. " castGen=" .. FK.State.castGen .. ")")
            return
        end

        -- DON'T set isFishing = false here!
        -- LOOT_OPENED needs isFishing to still be true
        -- We'll set it false in LOOT_CLOSED instead
        FK:Debug("Fishing channel stopped (waiting for loot)")

        if FK.Alerts and FK.Alerts.OnFishingEnd then
            FK.Alerts:OnFishingEnd()
        end

        -- Set a flag to know we're waiting for loot
        FK.State.waitingForLoot = true
        FK.State.lootCastGen = FK.State.castGen  -- save which cast's loot we're waiting for

        -- Timeout: if no loot window opens in 1 second, the fish got away.
        local savedGen = FK.State.castGen
        C_Timer.After(1, function()
            if FK.State.waitingForLoot and FK.State.castGen == savedGen then
                -- Extra re-cast safety: if a new fishing channel is already running,
                -- this CHANNEL_STOP belonged to an old bobber that was cancelled by
                -- a re-cast. TBC Classic UnitChannelInfo returns only 6 values (no
                -- spellID), so we check for any active channel instead of by ID.
                local isRecast = UnitChannelInfo("player") ~= nil
                if isRecast then
                    FK.State.waitingForLoot = false
                    FK:Debug("Timeout: re-cast detected via UnitChannelInfo, not counting miss")
                    return
                end

                FK.State.isFishing = false
                FK.State.castStartTime = nil
                FK.State.waitingForLoot = false
                FK:Debug("Fishing timeout - no loot (fish got away)")

                -- Count this as a completed (missed) cast
                if FK.Statistics and FK.Statistics.OnCastStart then
                    FK.Statistics:OnCastStart()
                end

                if FK.Alerts and FK.Alerts.OnFishingComplete then
                    FK.Alerts:OnFishingComplete()
                end
                if FK.UI and FK.UI.OnFishingEnd then
                    FK.UI:OnFishingEnd()
                end
            else
                FK:Debug("Timeout skipped (gen changed " .. savedGen .. " -> " .. FK.State.castGen .. ")")
            end
        end)
    end
end

eventHandlers.LOOT_READY = function()
    -- LOOT_READY fires before auto-loot processes items, so GetNumLootItems() is reliable here.
    -- IsFishingLoot() is a Blizzard API that returns true when the loot source is a fishing bobber.
    if IsFishingLoot and IsFishingLoot() then
        FK:Debug("LOOT_READY: fishing loot detected")
        if FK.Statistics and FK.Statistics.OnLootReady then
            FK.Statistics:OnLootReady()
        end
    end
end

eventHandlers.LOOT_OPENED = function()
    -- Check if we were fishing (either still flagged or waiting for loot)
    if FK.State.isFishing or FK.State.waitingForLoot then
        FK:Debug("Loot window opened (fishing catch!)")
        FK.State.waitingForLoot = false  -- Clear the waiting flag

        -- Record bite timing for confidence band
        if FK.Statistics and FK.Statistics.RecordBiteTime then
            FK.Statistics:RecordBiteTime()
        end

        -- Record pool location from the last detected pool name
        -- This is the most accurate time: bobber is AT the pool
        if FK.Pools and FK.Pools.RecordPoolFromCatch then
            FK.Pools:RecordPoolFromCatch()
        end

        -- Update UI
        if FK.UI and FK.UI.OnLootOpened then
            FK.UI:OnLootOpened()
        end

        -- Extend double-click window through the loot process
        if FK.UI and FK.UI.ExtendDoubleClick then
            FK.UI:ExtendDoubleClick()
        end
    end
end

-- Process catch & release list (auto-delete junk fish from bags)
local function ProcessReleaseList()
    if not FK.chardb or not FK.chardb.releaseList then return end
    if not next(FK.chardb.releaseList) then return end

    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemLink = GetContainerItemLink(bag, slot)

            if itemLink then
                local itemID = tonumber(string.match(itemLink, "item:(%d+)"))
                if itemID and FK.chardb.releaseList[itemID] then
                    -- Only auto-delete gray (0) and white (1) quality items for safety
                    local _, _, quality = GetItemInfo(itemLink)
                    if quality and quality <= 1 then
                        PickupContainerItem(bag, slot)
                        DeleteCursorItem()
                        local name = GetItemInfo(itemID)
                        FK:Debug("Released: " .. (name or "item " .. itemID))
                    end
                end
            end
        end
    end
end

eventHandlers.LOOT_CLOSED = function()
    if FK.State.isFishing or FK.State.waitingForLoot then
        FK:Debug("Loot window closed - fishing complete")

        -- Only reset fishing state if a new cast hasn't already started
        -- (rapid recasting via double-click can start a new cast before loot window closes)
        -- Compare current castGen against the gen saved at CHANNEL_STOP time
        -- (lootCastGen was saved BEFORE any new cast could start, so it's reliable)
        local expectedGen = FK.State.lootCastGen or FK.State.castGen
        FK:Debug("LOOT_CLOSED expectedGen=" .. expectedGen .. " currentGen=" .. FK.State.castGen)
        if FK.State.castGen == expectedGen then
            FK.State.isFishing = false
            FK.State.castStartTime = nil
            FK.State.waitingForLoot = false
            FK:Debug("LOOT_CLOSED reset state (gen=" .. expectedGen .. ")")

            -- Restore sound levels now that fishing is truly done
            if FK.Alerts and FK.Alerts.OnFishingComplete then
                FK.Alerts:OnFishingComplete()
            end

            -- Update UI
            if FK.UI and FK.UI.OnFishingEnd then
                FK.UI:OnFishingEnd()
            end

            -- Double-click recast: if they double-clicked during the catch,
            -- set the binding now so the next right-click recasts
            if FK.UI and FK.UI.OnFishingLootClosed then
                FK.UI:OnFishingLootClosed()
            end

        else
            -- New cast started, just clear the waiting flag
            FK.State.waitingForLoot = false
            FK:Debug("LOOT_CLOSED skipped reset (gen changed " .. expectedGen .. " -> " .. FK.State.castGen .. ")")
        end

        -- Process catch & release auto-delete
        C_Timer.After(0.3, ProcessReleaseList)

        -- Auto-open fishing containers (crates, scroll cases) if enabled
        if FK.db and FK.db.settings.autoOpenContainers then
            C_Timer.After(0.5, function()
                if FK.UI and FK.UI.AutoOpenContainers then
                    FK.UI:AutoOpenContainers()
                end
            end)
        end

        -- Auto-reapply lure if enabled and lure is missing/expired
        C_Timer.After(0.6, function()
            if FK.Equipment and FK.Equipment.TryAutoReapplyLure then
                FK.Equipment:TryAutoReapplyLure()
            end
        end)
    end
end

eventHandlers.QUEST_TURNED_IN = function(questName, questID)
    if FK.DailyQuests and FK.DailyQuests.OnQuestTurnedIn then
        FK.DailyQuests:OnQuestTurnedIn(questID)
    end
end

eventHandlers.ZONE_CHANGED = function()
    UpdateZoneInfo()

    -- Notify UI of zone change
    if FK.UI and FK.UI.OnZoneChanged then
        FK.UI:OnZoneChanged()
    end

    -- Update pool tracking
    if FK.Pools and FK.Pools.OnZoneChanged then
        FK.Pools:OnZoneChanged()
    end

    -- Check cycle fish time windows
    if FK.Alerts and FK.Alerts.CheckCycleFishWindows then
        FK.Alerts:CheckCycleFishWindows()
    end
end

eventHandlers.ZONE_CHANGED_INDOORS = eventHandlers.ZONE_CHANGED
eventHandlers.ZONE_CHANGED_NEW_AREA = eventHandlers.ZONE_CHANGED

eventHandlers.CHAT_MSG_SKILL = function(msg)
    -- Check for fishing skill up message
    if msg and string.find(msg, FK.FishingSpellName) then
        FK:Debug("Skill message: " .. msg)
        UpdateFishingSkill()

        -- Track skill up
        if FK.Statistics and FK.Statistics.OnSkillUp then
            FK.Statistics:OnSkillUp()
        end

        -- Update UI
        if FK.UI and FK.UI.OnSkillUpdate then
            FK.UI:OnSkillUpdate()
        end
    end
end

eventHandlers.SKILL_LINES_CHANGED = function()
    UpdateFishingSkill()

    -- Update UI
    if FK.UI and FK.UI.OnSkillUpdate then
        FK.UI:OnSkillUpdate()
    end
end

eventHandlers.PLAYER_EQUIPMENT_CHANGED = function(slot)
    UpdateLureStatus()

    -- Notify equipment module
    if FK.Equipment and FK.Equipment.OnEquipmentChanged then
        FK.Equipment:OnEquipmentChanged(slot)
    end

    -- Update UI
    if FK.UI and FK.UI.OnEquipmentChanged then
        FK.UI:OnEquipmentChanged()
    end
end

eventHandlers.UNIT_INVENTORY_CHANGED = function(unit)
    if unit == "player" then
        UpdateLureStatus()
    end
end

eventHandlers.PLAYER_REGEN_DISABLED = function()
    -- Entered combat
    FK.State.inCombat = true
    FK:Debug("Entered combat")

    -- Hide navigation arrow during combat
    if FK.Navigation and FK.Navigation.OnCombatStart then
        FK.Navigation:OnCombatStart()
    end

    -- Cancel any pending swap retry from a previous combat cycle
    if FK.State._combatSwapRetry then
        FK.State._combatSwapRetry.cancelled = true
        FK.State._combatSwapRetry = nil
    end

    -- Auto-combat weapon swap: equip weapons immediately, restore pole after combat
    if FK.db and FK.db.settings.autoCombatSwap then
        if FK.Equipment and FK.Equipment:HasFishingPole() then
            -- Snapshot the fishing pole now so PLAYER_REGEN_ENABLED can restore just
            -- the pole without touching head/hands/feet or calling SaveNormalGear.
            FK.State.preCombatPole = GetInventoryItemLink("player", 16)  -- SLOT_MAINHAND
            FK.State.combatSwapQueued = true
            local swapped = FK.Equipment:EquipCombatWeapons()
            if swapped then
                FK:Print("Combat! Equipping weapons — fishing pole will restore after.", FK.Colors.warning)
            else
                FK:Print("Combat detected, but no normal weapons saved. Use /fk savegear normal first.", FK.Colors.warning)
            end
        end
    end
end

eventHandlers.PLAYER_REGEN_ENABLED = function()
    -- Left combat
    FK.State.inCombat = false
    FK:Debug("Left combat")

    -- Show navigation arrow after combat
    if FK.Navigation and FK.Navigation.OnCombatEnd then
        FK.Navigation:OnCombatEnd()
    end

    -- Resume fishing: restore only the fishing pole that was in mainhand before combat.
    -- We do NOT call EquipFishingGear here — that would re-invoke SaveNormalGear while
    -- head/hands/feet are still in the fishing-gear state, corrupting normalGear.
    if FK.State.combatSwapQueued then
        FK.State.combatSwapQueued = false

        if FK.State._combatSwapRetry then
            FK.State._combatSwapRetry.cancelled = true
        end

        local poleLink = FK.State.preCombatPole
        FK.State.preCombatPole = nil

        if poleLink and FK.Equipment then
            local poleID = FK.Equipment:GetItemIDFromLink(poleLink)
            if poleID then
                local attempt = { cancelled = false, count = 0 }
                FK.State._combatSwapRetry = attempt

                local function TryRestorePole()
                    if attempt.cancelled then return end
                    attempt.count = attempt.count + 1

                    if InCombatLockdown() then
                        if attempt.count < 10 then
                            C_Timer.After(1.0, TryRestorePole)
                        else
                            FK:Print("Combat lockdown persisted. Use /fk equip to restore fishing gear.", FK.Colors.warning)
                            FK.State._combatSwapRetry = nil
                        end
                        return
                    end

                    -- Guard: if the pole is already in slot 16 (weapons never swapped),
                    -- EquipItemByName would pick it up and leave the slot empty.
                    local currentMHLink = GetInventoryItemLink("player", 16)
                    local currentMHID = currentMHLink and FK.Equipment:GetItemIDFromLink(currentMHLink)
                    if currentMHID == poleID then
                        FK:Debug("Pole restore: pole already in slot 16, skipping")
                    else
                        EquipItemByName("item:" .. poleID, 16)  -- SLOT_MAINHAND
                    end
                    FK:Print("Fishing pole restored.", FK.Colors.success)
                    FK.State._combatSwapRetry = nil

                    -- Rescan so HasFishingPole() reflects reality again
                    C_Timer.After(0.5, function()
                        if FK.Equipment then FK.Equipment:ScanEquipment() end
                    end)
                end

                C_Timer.After(0.5, TryRestorePole)
            end
        end
    end
end

-- ============================================================================
-- Auction House events — delegated to modules/AuctionHouse.lua
-- ============================================================================

eventHandlers.AUCTION_HOUSE_SHOW = function()
    if FK.AuctionHouse then FK.AuctionHouse:OnAuctionHouseShow() end
end

eventHandlers.AUCTION_HOUSE_CLOSED = function()
    if FK.AuctionHouse then FK.AuctionHouse:OnAuctionHouseClosed() end
end

eventHandlers.AUCTION_ITEM_LIST_UPDATE = function()
    if FK.AuctionHouse then FK.AuctionHouse:OnAuctionItemListUpdate() end
end

function FK:FormatCopper(copper)
    if not copper or copper <= 0 then return "0c" end
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100
    if gold > 0 then
        return string.format("%dg %ds %dc", gold, silver, cop)
    elseif silver > 0 then
        return string.format("%ds %dc", silver, cop)
    else
        return string.format("%dc", cop)
    end
end

eventHandlers.CURSOR_CHANGED = function()
    if FK.Pools and FK.Pools.OnCursorChanged then
        FK.Pools:OnCursorChanged()
    end
end

-- Main event dispatcher
eventFrame:SetScript("OnEvent", function(self, event, ...)
    local handler = eventHandlers[event]
    if handler then
        handler(...)
    end
end)

-- ============================================================================
-- Slash Commands
-- ============================================================================

-- Command registry: cmd string → handler(args).
-- Any module can call FK:RegisterCommand() in its Initialize() to add
-- commands without touching this file (Open/Closed).
local cmdRegistry = {}

function FK:RegisterCommand(cmd, handler)
    cmdRegistry[cmd] = handler
end

SLASH_FISHINGKIT1 = "/fk"
SLASH_FISHINGKIT2 = "/fishingkit"
SLASH_FISHINGKIT3 = "/fishkit"

SlashCmdList["FISHINGKIT"] = function(msg)
    msg = string.lower(msg or "")
    local cmd, args = string.match(msg, "^(%S+)%s*(.*)$")
    cmd = cmd or msg
    args = args or ""

    -- Empty command → toggle main UI
    if cmd == "" then
        if FK.UI and FK.UI.Toggle then FK.UI:Toggle() end
        return
    end

    local handler = cmdRegistry[cmd]
    if handler then
        handler(args)
    else
        FK:Print("Unknown command '" .. cmd .. "'. Type /fk help for options.", FK.Colors.warning)
    end
end

-- ============================================================================
-- Command registrations
-- Modules can add their own in Initialize(); these cover core/cross-cutting.
-- ============================================================================

FK:RegisterCommand("show", function()
    if FK.UI and FK.UI.Toggle then FK.UI:Toggle() end
end)

FK:RegisterCommand("hide", function()
    if FK.UI and FK.UI.Hide then FK.UI:Hide() end
end)

local function cmdConfig()
    if FK.Config and FK.Config.Toggle then FK.Config:Toggle() end
end
FK:RegisterCommand("config",  cmdConfig)
FK:RegisterCommand("options", cmdConfig)
FK:RegisterCommand("opt",     cmdConfig)

FK:RegisterCommand("stats", function()
    if FK.Statistics and FK.Statistics.ToggleStatsPanel then
        FK.Statistics:ToggleStatsPanel()
    elseif FK.Statistics and FK.Statistics.ShowSummary then
        FK.Statistics:ShowSummary()
    end
end)

FK:RegisterCommand("reset", function(args)
    if args == "stats" then
        if FK.Statistics and FK.Statistics.ResetStats then
            FK.Statistics:ResetStats()
            FK:Print("Statistics reset!", FK.Colors.success)
        end
    elseif args == "position" or args == "pos" then
        if FK.UI and FK.UI.ResetPosition then
            FK.UI:ResetPosition()
            FK:Print("UI position reset!", FK.Colors.success)
        end
    else
        FK:Print("Usage: /fk reset [stats|position]", FK.Colors.warning)
    end
end)

FK:RegisterCommand("lock", function()
    if FK.db then
        FK.db.settings.locked = true
        FK:Print("UI locked.", FK.Colors.success)
    end
end)

FK:RegisterCommand("unlock", function()
    if FK.db then
        FK.db.settings.locked = false
        FK:Print("UI unlocked. Drag to move.", FK.Colors.success)
    end
end)

FK:RegisterCommand("scale", function(args)
    local scale = tonumber(args)
    if not scale then
        FK:Print("Invalid number: '" .. args .. "'. Usage: /fk scale [0.5-2.0]", FK.Colors.error)
    elseif scale < 0.5 or scale > 2.0 then
        FK:Print("Scale must be between 0.5 and 2.0. Got: " .. scale, FK.Colors.warning)
    else
        FK.db.settings.scale = scale
        if FK.UI and FK.UI.SetScale then FK.UI:SetScale(scale) end
        FK:Print("Scale set to " .. scale, FK.Colors.success)
    end
end)

FK:RegisterCommand("equip", function()
    if FK.Equipment and FK.Equipment.EquipFishingGear then FK.Equipment:EquipFishingGear() end
end)

FK:RegisterCommand("unequip", function()
    if FK.Equipment and FK.Equipment.EquipNormalGear then FK.Equipment:EquipNormalGear() end
end)

FK:RegisterCommand("savegear", function(args)
    if args == "fishing" then
        if FK.Equipment and FK.Equipment.SaveFishingGear then
            FK.Equipment:SaveFishingGear()
            FK:Print("Fishing gear saved!", FK.Colors.success)
        end
    elseif args == "normal" then
        if FK.Equipment and FK.Equipment.SaveNormalGear then
            FK.Equipment:SaveNormalGear()
            FK:Print("Normal gear saved!", FK.Colors.success)
        end
    else
        FK:Print("Usage: /fk savegear [fishing|normal]", FK.Colors.warning)
    end
end)

FK:RegisterCommand("sound", function(args)
    if args == "on" then
        FK.db.settings.soundEnabled = true
        FK:Print("Sound enabled.", FK.Colors.success)
    elseif args == "off" then
        FK.db.settings.soundEnabled = false
        FK:Print("Sound disabled.", FK.Colors.success)
    elseif args == "test" then
        if FK.Alerts and FK.Alerts.TestSound then FK.Alerts:TestSound() end
    else
        FK:Print("Usage: /fk sound [on|off|test]", FK.Colors.warning)
    end
end)

FK:RegisterCommand("pools", function(args)
    if args == "on" then
        FK.db.settings.trackPools = true
        FK:Print("Pool tracking enabled.", FK.Colors.success)
    elseif args == "off" then
        FK.db.settings.trackPools = false
        FK:Print("Pool tracking disabled.", FK.Colors.success)
    elseif args == "clear" then
        if FK.Pools and FK.Pools.ClearPoolData then
            StaticPopup_Show("FISHINGKIT_CLEAR_POOLS")
        end
    elseif args == "clearzone" then
        if FK.Pools and FK.Pools.ClearZonePoolData then FK.Pools:ClearZonePoolData() end
    else
        if FK.Pools and FK.Pools.ShowNearbyPools then FK.Pools:ShowNearbyPools() end
    end
end)

FK:RegisterCommand("goal", function(args)
    if args == "" then
        if FK.chardb and FK.chardb.goals and #FK.chardb.goals > 0 then
            FK:Print("Active Goals:", FK.Colors.highlight)
            for i, goal in ipairs(FK.chardb.goals) do
                local progress = 0
                if FK.Statistics and FK.Statistics.GetSessionFishCount then
                    progress = FK.Statistics:GetSessionFishCount(goal.itemID)
                end
                local color = progress >= goal.target and FK.Colors.success or FK.Colors.warning
                print("  " .. i .. ". " .. goal.name .. ": " .. color .. progress .. "/" .. goal.target .. "|r")
            end
        else
            FK:Print("No active goals. Use: /fk goal <fish name> <count>", FK.Colors.info)
        end
    elseif args == "clear" then
        if FK.chardb then
            FK.chardb.goals = {}
            FK:Print("All goals cleared.", FK.Colors.success)
        end
    else
        local count    = tonumber(string.match(args, "(%d+)%s*$"))
        local fishName = string.match(args, "^(.-)%s+%d+%s*$")
        if count and count > 0 and fishName and fishName ~= "" then
            local matchedID, matchedName = nil, fishName
            if FK.chardb and FK.chardb.stats and FK.chardb.stats.fishCaught then
                for itemID, data in pairs(FK.chardb.stats.fishCaught) do
                    if data.name and string.lower(data.name) == string.lower(fishName) then
                        matchedID, matchedName = itemID, data.name
                        break
                    end
                end
            end
            if not matchedID and FK.Database and FK.Database.GetFishIDByName then
                matchedID = FK.Database:GetFishIDByName(fishName)
                if matchedID then
                    local fd = FK.Database:GetFishInfo(matchedID)
                    if fd then matchedName = fd.name end
                end
            end
            if not FK.chardb.goals then FK.chardb.goals = {} end
            table.insert(FK.chardb.goals, { name = matchedName, itemID = matchedID, target = count })
            FK:Print("Goal set: " .. FK.Colors.highlight .. matchedName .. "|r x" .. count, FK.Colors.success)
            if not matchedID then
                FK:Print("Fish not found in history - goal will track by name.", FK.Colors.info)
            end
        else
            FK:Print("Usage: /fk goal <fish name> <count>", FK.Colors.warning)
            FK:Print("Example: /fk goal Stonescale Eel 50", FK.Colors.info)
        end
    end
end)

FK:RegisterCommand("release", function(args)
    if args == "" then
        if FK.chardb and FK.chardb.releaseList and next(FK.chardb.releaseList) then
            FK:Print("Catch & Release List:", FK.Colors.highlight)
            for itemID, name in pairs(FK.chardb.releaseList) do
                print("  " .. name .. " (ID: " .. itemID .. ")")
            end
        else
            FK:Print("Release list is empty. Use: /fk release <fish name>", FK.Colors.info)
        end
    elseif args == "clear" then
        if FK.chardb then
            FK.chardb.releaseList = {}
            FK:Print("Release list cleared.", FK.Colors.success)
        end
    else
        local matchedID, matchedName = nil, args
        if FK.chardb and FK.chardb.stats and FK.chardb.stats.fishCaught then
            for itemID, data in pairs(FK.chardb.stats.fishCaught) do
                if data.name and string.lower(data.name) == string.lower(args) then
                    matchedID, matchedName = itemID, data.name
                    break
                end
            end
        end
        if not matchedID and FK.Database and FK.Database.GetFishIDByName then
            matchedID = FK.Database:GetFishIDByName(args)
            if matchedID then
                local fd = FK.Database:GetFishInfo(matchedID)
                if fd then matchedName = fd.name end
            end
        end
        if matchedID then
            local _, _, quality = GetItemInfo(matchedID)
            if quality and quality > 1 then
                FK:Print("Cannot auto-release " .. matchedName .. " - only gray/white quality items allowed.", FK.Colors.error)
            else
                if not FK.chardb.releaseList then FK.chardb.releaseList = {} end
                FK.chardb.releaseList[matchedID] = matchedName
                FK:Print("Added to release list: " .. FK.Colors.highlight .. matchedName .. "|r (will auto-delete on catch)", FK.Colors.success)
            end
        else
            FK:Print("Fish not found: " .. args .. ". Catch it first, then add to release list.", FK.Colors.warning)
        end
    end
end)

local function cmdRoute(args)
    if not FK.Navigation then return end
    if args == "stop" then
        FK.Navigation:StopRoute()
    elseif args == "skip" then
        FK.Navigation:SkipWaypoint()
    elseif args == "nearest" or args == "recalc" then
        FK.Navigation:RecalculateFromNearest()
    else
        FK.Navigation:ToggleRoute()
    end
end
FK:RegisterCommand("route", cmdRoute)
FK:RegisterCommand("nav",   cmdRoute)

FK:RegisterCommand("import", function(args)
    if args == "gathermate" or args == "gathermate2" or args == "gm2" then
        if FK.Navigation then FK.Navigation:ImportFromGatherMate2() end
    else
        FK:Print("Usage: /fk import gathermate", FK.Colors.warning)
    end
end)

FK:RegisterCommand("backup", function(args)
    if args == "restore" then
        StaticPopupDialogs["FISHINGKIT_RESTORE_BACKUP"] = {
            text = "Restore from last backup? This will overwrite current data. You'll need to /reload after.",
            button1 = "Yes", button2 = "No",
            OnAccept = function() FK:RestoreBackup() end,
            timeout = 0, whileDead = true, hideOnEscape = true,
        }
        StaticPopup_Show("FISHINGKIT_RESTORE_BACKUP")
    elseif args == "info" then
        FK:GetBackupInfo()
    else
        FK:CreateBackup()
    end
end)

FK:RegisterCommand("daily", function(args)
    if not FK.DailyQuests then return end
    if args == "print" then
        FK.DailyQuests:PrintStatus()
    else
        FK.DailyQuests:Toggle()
    end
end)

FK:RegisterCommand("debug", function()
    FK.debugMode = not FK.debugMode
    FK:Print("Debug mode: " .. (FK.debugMode and "ON" or "OFF"), FK.Colors.info)
end)

local function cmdHelp()
    FK:Print("Commands:", FK.Colors.highlight)
    print("  /fk - Toggle main UI")
    print("  /fk config - Open options panel")
    print("  /fk stats - Show fishing statistics")
    print("  /fk reset [stats|position] - Reset data or UI position")
    print("  /fk lock/unlock - Lock/unlock UI position")
    print("  /fk scale [0.5-2.0] - Set UI scale")
    print("  /fk equip/unequip - Swap fishing/normal gear")
    print("  /fk savegear [fishing|normal] - Save current gear set")
    print("  /fk sound [on|off|test] - Sound settings")
    print("  /fk pools - Show nearby fishing pools")
    print("  /fk pools clear - Clear all pool location data")
    print("  /fk pools clearzone - Clear pool data for current zone")
    print("  /fk goal <fish> <count> - Set a fishing goal")
    print("  /fk goal clear - Clear all goals")
    print("  /fk release <fish> - Auto-delete junk fish on catch")
    print("  /fk release clear - Clear release list")
    print("  /fk route - Toggle pool route navigation")
    print("  /fk route stop - Stop navigation")
    print("  /fk route skip - Skip current waypoint")
    print("  /fk route nearest - Recalculate from nearest pool")
    print("  /fk import gathermate - Import GatherMate2 pool data")
    print("  /fk backup - Force a backup now")
    print("  /fk backup restore - Restore from last backup")
    print("  /fk backup info - Show backup timestamp")
    print("  /fk daily - Toggle fishing daily quest tracker")
    print("  /fk daily print - Print daily quest status to chat")
end
FK:RegisterCommand("help", cmdHelp)
FK:RegisterCommand("?",    cmdHelp)

-- ============================================================================
-- STV Fishing Extravaganza
-- ============================================================================

function FK:IsContestActive()
    -- Contest runs Sundays 2:00-4:00 PM server time
    local weekday, hour
    local serverTime = C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime and C_DateAndTime.GetCurrentCalendarTime()
    if serverTime then
        weekday = serverTime.weekday  -- 1=Sunday in WoW API
        hour = serverTime.hour
    else
        -- Fallback for clients without C_DateAndTime
        weekday = tonumber(date("%w"))  -- 0=Sunday in Lua
        if weekday == 0 then weekday = 1 else weekday = weekday + 1 end  -- Convert to WoW convention (1=Sunday)
        hour = tonumber(date("%H"))
    end
    if not weekday or not hour then return false end

    -- Sunday between 14:00 and 16:00 server time
    return weekday == 1 and hour >= 14 and hour < 16
end

function FK:IsInSTV()
    local zone = FK.State.currentZone or ""
    return zone == "Stranglethorn Vale" or zone == "Northern Stranglethorn" or zone == "The Cape of Stranglethorn"
end

function FK:GetTaskyfishCount()
    local count = 0
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                local itemID = tonumber(string.match(itemLink, "item:(%d+)"))
                if itemID == 19807 then
                    local _, itemCount = GetContainerItemInfo(bag, slot)
                    itemCount = itemCount or 1
                    count = count + (itemCount or 1)
                end
            end
        end
    end
    return count
end

function FK:GetContestTimeRemaining()
    local serverTime = C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime and C_DateAndTime.GetCurrentCalendarTime()
    if not serverTime then return 0 end
    -- End time is 16:00
    local minutesLeft = (16 - serverTime.hour) * 60 - serverTime.minute
    return math.max(0, minutesLeft)
end

-- ============================================================================
-- Public API
-- ============================================================================

-- Check if fishing is currently active
function FK:IsFishing()
    return FK.State.isFishing
end

-- Get current fishing skill
function FK:GetFishingSkill()
    return FK.State.fishingSkill, FK.State.fishingSkillMax
end

-- Get current zone info
function FK:GetZoneInfo()
    return FK.State.currentZone, FK.State.currentSubZone
end

-- Check if player has a lure active (live check)
function FK:HasLure()
    -- Use Equipment module's live check if available
    if FK.Equipment and FK.Equipment.GetLureInfo then
        local hasLure, expireTime = FK.Equipment:GetLureInfo()
        return hasLure, expireTime
    end
    -- Fallback to cached state
    return FK.State.hasLure, FK.State.lureExpireTime
end

-- Get session duration
function FK:GetSessionDuration()
    if FK.State.sessionActive then
        return GetTime() - FK.State.sessionStartTime
    end
    return 0
end

-- Force refresh all states
function FK:RefreshState()
    UpdateZoneInfo()
    UpdateFishingSkill()
    UpdateLureStatus()
end

-- ============================================================================
-- Key Binding Labels
-- ============================================================================

BINDING_HEADER_FISHINGKITHEADER = "FishingKit"
BINDING_NAME_FISHINGKIT_TOGGLE = "Toggle FishingKit Panel"
BINDING_NAME_FISHINGKIT_GEARSWAP = "Swap Fishing/Normal Gear"
BINDING_NAME_FISHINGKIT_LURE = "Apply Lure (Info)"
BINDING_NAME_FISHINGKIT_STATS = "Toggle Statistics"
BINDING_NAME_FISHINGKIT_CONFIG = "Toggle Settings"

FK:Debug("Core module loaded")
