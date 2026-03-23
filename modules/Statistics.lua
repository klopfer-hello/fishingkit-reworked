--[[
    FishingKit - TBC Anniversary Edition
    Statistics Module - Comprehensive fishing statistics tracking

    This module handles:
    - Cast tracking and success rates
    - Fish caught by type, zone, and quality
    - Session statistics with timing
    - Loot history and rare catch tracking
    - Skill progression tracking
    - Gold earned calculations
]]

local ADDON_NAME, FK = ...

FK.Statistics = {}
local Stats = FK.Statistics

-- Current session tracking
local sessionData = {
    startTime = 0,
    casts = 0,
    catches = 0,
    gotAway = 0,
    junk = 0,
    skillUps = 0,
    fishCaught = {},
    zones = {},
    vendorCopper = 0,
    ahCopper = 0,
    blendedCopper = 0,
    -- Efficiency tracking (catches per 5-min bucket)
    efficiencyBuckets = {},
    lastBucketTime = 0,
    -- Fishing-time tracking: only counts seconds while pole is equipped
    fishingTime = 0,          -- accumulated seconds with pole equipped
    fishingPoleEquipTime = nil,  -- GetTime() when pole was last equipped, nil when unequipped
}

-- Milestone thresholds for celebration
local MILESTONES = { 100, 250, 500, 1000, 2500, 5000, 10000 }

-- Cache for GetBiteConfidence per zone — invalidated whenever RecordBiteTime adds a new entry.
-- Avoids allocating+sorting a copy of biteTimings on every UI update (10×/s while fishing).
local biteConfidenceCache = {}

-- ============================================================================
-- Initialization
-- ============================================================================

function Stats:Initialize()
    -- Initialize session
    sessionData.startTime = GetTime()

    -- Ensure per-character stats structure exists
    if FK.chardb and FK.chardb.stats then
        -- Reset session counters in saved vars
        FK.chardb.stats.sessionCasts = 0
        FK.chardb.stats.sessionCatches = 0
    end

    -- Subscribe to fishing events
    FK.Events:On("FISHING_LOOT_READY",  function() Stats:OnLootReady() end)
    FK.Events:On("FISHING_LOOT_OPENED", function() Stats:RecordBiteTime() end)
    FK.Events:On("FISHING_MISSED",      function() Stats:OnCastStart() end)
    FK.Events:On("FISHING_FAILED",      function() Stats:OnCastFailed() end)
    FK.Events:On("FISHING_SKILL_UP",    function() Stats:OnSkillUp() end)
    FK.Events:On("SESSION_ENDING",      function() Stats:SaveSession() end)

    FK:Debug("Statistics module initialized")
end

-- ============================================================================
-- Cast Tracking
-- ============================================================================

function Stats:OnCastStart()
    if not FK.db.settings.trackStats then return end

    -- Increment cast counters
    sessionData.casts = sessionData.casts + 1

    if FK.chardb and FK.chardb.stats then
        FK.chardb.stats.totalCasts = (FK.chardb.stats.totalCasts or 0) + 1
        FK.chardb.stats.sessionCasts = (FK.chardb.stats.sessionCasts or 0) + 1
    end

    if FK.db and FK.db.globalStats then
        FK.db.globalStats.totalCasts = (FK.db.globalStats.totalCasts or 0) + 1
    end

    -- Track zone
    local zone = FK:GetZone()
    if zone and zone ~= "" then
        if not sessionData.zones[zone] then
            sessionData.zones[zone] = { casts = 0, catches = 0 }
        end
        sessionData.zones[zone].casts = sessionData.zones[zone].casts + 1

        if FK.chardb and FK.chardb.stats then
            if not FK.chardb.stats.zoneStats then
                FK.chardb.stats.zoneStats = {}
            end
            if not FK.chardb.stats.zoneStats[zone] then
                FK.chardb.stats.zoneStats[zone] = { casts = 0, catches = 0, fish = {} }
            end
            FK.chardb.stats.zoneStats[zone].casts = FK.chardb.stats.zoneStats[zone].casts + 1
        end
    end

    FK:Debug("Cast recorded. Session casts: " .. sessionData.casts)
end

function Stats:UndoCastCount()
    -- Undo a cast count (user cancelled/interrupted to reposition bobber)
    if not FK.db.settings.trackStats then return end

    sessionData.casts = math.max(0, sessionData.casts - 1)

    if FK.chardb and FK.chardb.stats then
        FK.chardb.stats.totalCasts = math.max(0, (FK.chardb.stats.totalCasts or 0) - 1)
        FK.chardb.stats.sessionCasts = math.max(0, (FK.chardb.stats.sessionCasts or 0) - 1)
    end

    if FK.db and FK.db.globalStats then
        FK.db.globalStats.totalCasts = math.max(0, (FK.db.globalStats.totalCasts or 0) - 1)
    end

    local zone = FK:GetZone()
    if zone and zone ~= "" then
        if sessionData.zones[zone] then
            sessionData.zones[zone].casts = math.max(0, sessionData.zones[zone].casts - 1)
        end
        if FK.chardb and FK.chardb.stats and FK.chardb.stats.zoneStats and FK.chardb.stats.zoneStats[zone] then
            FK.chardb.stats.zoneStats[zone].casts = math.max(0, FK.chardb.stats.zoneStats[zone].casts - 1)
        end
    end

    FK:Debug("Cast undone (interrupted). Session casts: " .. sessionData.casts)
end

function Stats:OnCastFailed()
    -- Fish got away or cast failed
    sessionData.gotAway = sessionData.gotAway + 1

    if FK.chardb and FK.chardb.stats then
        FK.chardb.stats.totalGotAway = (FK.chardb.stats.totalGotAway or 0) + 1
    end

    FK:Debug("Cast failed/fish got away")
end

-- ============================================================================
-- Loot Tracking
-- ============================================================================

-- Take a snapshot of all bag contents before loot is picked up.
-- Called from CHANNEL_STOP so the baseline is always captured before auto-loot runs.
function Stats:OnLootReady()
    -- LOOT_READY fires before auto-loot processes items, so GetNumLootItems() is reliable.
    -- Called only when IsFishingLoot() is true (checked in Core.lua).
    if not FK.db.settings.trackStats then return end

    local numItems = GetNumLootItems()
    if numItems == 0 then
        FK:Debug("OnLootReady: no loot items")
        return
    end

    -- Count one cast for this loot event (successful resolution).
    -- Casts are only counted here (catch) or in the CHANNEL_STOP 1s timeout (miss)
    -- so that re-casts — where the old bobber is cancelled before it resolves —
    -- are never counted.
    self:OnCastStart()

    for i = 1, numItems do
        local texture, name, count, quality = GetLootSlotInfo(i)
        if name and count and count > 0 then
            local link = GetLootSlotLink(i)
            local itemID = nil
            if link then
                itemID = tonumber(string.match(link, "item:(%d+)"))
            end
            FK:Debug("OnLootReady: caught " .. tostring(name) .. " x" .. count)
            self:RecordCatch({
                itemID = itemID or 0,
                name = name,
                quantity = count,
                quality = quality or 0,
                link = link,
            })
        end
    end

end

function Stats:OnLootClosed()
end

-- Update all fish-count tables (session, chardb, globalStats) for one caught item.
local function TrackFishCount(itemID, itemName, quantity, quality)
    if not sessionData.fishCaught[itemID] then
        sessionData.fishCaught[itemID] = { name = itemName, count = 0, quality = quality }
    end
    sessionData.fishCaught[itemID].count = sessionData.fishCaught[itemID].count + quantity

    if FK.chardb and FK.chardb.stats then
        if not FK.chardb.stats.fishCaught then FK.chardb.stats.fishCaught = {} end
        if not FK.chardb.stats.fishCaught[itemID] then
            FK.chardb.stats.fishCaught[itemID] = { name = itemName, count = 0, quality = quality, firstCaught = time() }
        end
        FK.chardb.stats.fishCaught[itemID].count = FK.chardb.stats.fishCaught[itemID].count + quantity
        FK.chardb.stats.fishCaught[itemID].lastCaught = time()
    end

    if FK.db and FK.db.globalStats then
        if not FK.db.globalStats.fishCaught then FK.db.globalStats.fishCaught = {} end
        if not FK.db.globalStats.fishCaught[itemID] then
            FK.db.globalStats.fishCaught[itemID] = { name = itemName, count = 0, quality = quality }
        end
        FK.db.globalStats.fishCaught[itemID].count = FK.db.globalStats.fishCaught[itemID].count + quantity
    end
end

-- Update zone catch counters (session and chardb) for one caught item.
local function TrackZoneCatch(zone, itemID, quantity)
    if not zone or zone == "" then return end

    if sessionData.zones[zone] then
        sessionData.zones[zone].catches = (sessionData.zones[zone].catches or 0) + 1
    end

    if FK.chardb and FK.chardb.stats and FK.chardb.stats.zoneStats then
        local zs = FK.chardb.stats.zoneStats[zone]
        if zs then
            zs.catches = (zs.catches or 0) + 1
            if not zs.fish then zs.fish = {} end
            zs.fish[itemID] = (zs.fish[itemID] or 0) + quantity
        end
    end
end

-- Update vendor/AH copper accumulators for one caught item.
local function TrackGoldValue(lootData, itemID, quantity)
    local _, _, _, _, _, _, _, _, _, _, sellPrice = GetItemInfo(lootData.link or itemID)
    local vendorValue = (sellPrice and sellPrice > 0) and sellPrice or 0
    if vendorValue > 0 then
        sessionData.vendorCopper = (sessionData.vendorCopper or 0) + (vendorValue * quantity)
    end

    local ahValue = 0
    if FK.db and FK.db.ahPrices and FK.db.ahPrices[itemID] then
        ahValue = FK.db.ahPrices[itemID]
        sessionData.ahCopper = (sessionData.ahCopper or 0) + (ahValue * quantity)
    end

    local blendedValue = ahValue > 0 and ahValue or vendorValue
    if blendedValue > 0 then
        sessionData.blendedCopper = (sessionData.blendedCopper or 0) + (blendedValue * quantity)
    end
end

function Stats:RecordCatch(lootData)
    local itemID = lootData.itemID
    local itemName = lootData.name
    local quantity = lootData.quantity or 1
    local quality = lootData.quality or 0
    local zone = FK:GetZone() or "Unknown"

    local isJunk = FK.Database:IsJunk(itemID)
    local isSpecial = FK.Database:IsSpecial(itemID)

    if isJunk then
        sessionData.junk = sessionData.junk + 1
        if FK.chardb and FK.chardb.stats then
            FK.chardb.stats.totalJunk = (FK.chardb.stats.totalJunk or 0) + 1
        end
        FK:Debug("Junk recorded: " .. itemName)
    else
        sessionData.catches = sessionData.catches + 1
        if FK.chardb and FK.chardb.stats then
            FK.chardb.stats.totalCatches = (FK.chardb.stats.totalCatches or 0) + 1
            FK.chardb.stats.sessionCatches = (FK.chardb.stats.sessionCatches or 0) + 1
        end
        if FK.db and FK.db.globalStats then
            FK.db.globalStats.totalCatches = (FK.db.globalStats.totalCatches or 0) + 1
        end

        TrackFishCount(itemID, itemName, quantity, quality)
        TrackZoneCatch(zone, itemID, quantity)

        if quality >= 3 or isSpecial then self:RecordRareCatch(lootData, zone) end
        self:AddToLootHistory(lootData, zone)

        if FK.UI and FK.UI.OnCatch then FK.UI:OnCatch(itemName, lootData.link) end
        self:RecordEfficiencyBucket()
        if FK.db and FK.db.settings.milestones then self:CheckMilestone() end

        FK:Debug("Catch recorded: " .. itemName .. " x" .. quantity)
    end

    TrackGoldValue(lootData, itemID, quantity)
end

function Stats:RecordRareCatch(lootData, zone)
    if FK.chardb and FK.chardb.stats then
        if not FK.chardb.stats.rareCatches then
            FK.chardb.stats.rareCatches = {}
        end

        table.insert(FK.chardb.stats.rareCatches, {
            itemID = lootData.itemID,
            name = lootData.name,
            quality = lootData.quality,
            zone = zone,
            timestamp = time(),
        })

        -- Keep only last 100 rare catches (one item inserted at a time, so if suffices)
        if #FK.chardb.stats.rareCatches > 100 then
            table.remove(FK.chardb.stats.rareCatches, 1)
        end
    end

    -- Announce rare catch
    local qualityColor = FK.Colors.rare
    if lootData.quality >= 4 then
        qualityColor = FK.Colors.epic
    elseif lootData.quality >= 5 then
        qualityColor = FK.Colors.legendary
    end

    FK:Print("Rare catch: " .. qualityColor .. lootData.name .. "|r in " .. zone .. "!", FK.Colors.highlight)
end

function Stats:AddToLootHistory(lootData, zone)
    if not FK.db.settings.trackLoot then return end

    if FK.chardb then
        if not FK.chardb.lootHistory then
            FK.chardb.lootHistory = {}
        end

        table.insert(FK.chardb.lootHistory, {
            itemID = lootData.itemID,
            name = lootData.name,
            quantity = lootData.quantity,
            quality = lootData.quality,
            zone = zone,
            timestamp = time(),
        })

        -- Keep only last 500 items (one item inserted at a time, so if suffices)
        if #FK.chardb.lootHistory > 500 then
            table.remove(FK.chardb.lootHistory, 1)
        end
    end
end

-- ============================================================================
-- Skill Tracking
-- ============================================================================

function Stats:OnSkillUp()
    sessionData.skillUps = sessionData.skillUps + 1

    if FK.chardb and FK.chardb.stats then
        FK.chardb.stats.skillUps = (FK.chardb.stats.skillUps or 0) + 1
        FK.chardb.stats.lastSkillUp = time()
    end

    local skill, maxSkill = FK:GetFishingSkill()
    FK:Print("Fishing skill increased to " .. FK.Colors.highlight .. skill .. "|r!", FK.Colors.success)
end

-- ============================================================================
-- Session Management
-- ============================================================================

function Stats:SaveSession()
    if not FK.db.settings.trackStats then return end

    local duration = GetTime() - sessionData.startTime

    if FK.chardb then
        if not FK.chardb.sessions then
            FK.chardb.sessions = {}
        end

        table.insert(FK.chardb.sessions, {
            startTime = sessionData.startTime,
            duration = duration,
            casts = sessionData.casts,
            catches = sessionData.catches,
            gotAway = sessionData.gotAway,
            junk = sessionData.junk,
            skillUps = sessionData.skillUps,
            timestamp = time(),
            fishCaught = FK:TableCopy(sessionData.fishCaught),
            vendorCopper = sessionData.vendorCopper or 0,
            ahCopper = sessionData.ahCopper or 0,
            blendedCopper = sessionData.blendedCopper or 0,
        })

        -- Keep only last 50 sessions (one session inserted at a time, so if suffices)
        if #FK.chardb.sessions > 50 then
            table.remove(FK.chardb.sessions, 1)
        end
    end

    FK:Debug("Session saved: " .. sessionData.casts .. " casts, " .. sessionData.catches .. " catches")
end

function Stats:ResetSession()
    sessionData = {
        startTime = GetTime(),
        casts = 0,
        catches = 0,
        gotAway = 0,
        junk = 0,
        skillUps = 0,
        fishCaught = {},
        zones = {},
        vendorCopper = 0,
        ahCopper = 0,
        blendedCopper = 0,
        efficiencyBuckets = {},
        lastBucketTime = 0,
        fishingTime = 0,
        fishingPoleEquipTime = nil,
    }

    if FK.chardb and FK.chardb.stats then
        FK.chardb.stats.sessionCasts = 0
        FK.chardb.stats.sessionCatches = 0
    end

    FK:Print("Session statistics reset.", FK.Colors.info)
end

-- Called by Equipment module when fishing pole is equipped.
-- Starts the fishing-time clock for the new session.
function Stats:OnFishingGearEquipped()
    sessionData.fishingPoleEquipTime = GetTime()
    FK:Debug("Fishing gear equipped - session timer started")
end

-- Called by Equipment module when fishing pole is unequipped.
-- Saves and resets the session so the timer starts fresh next time.
function Stats:OnFishingGearUnequipped()
    -- Accumulate any time that was running
    if sessionData.fishingPoleEquipTime then
        sessionData.fishingTime = (sessionData.fishingTime or 0) + (GetTime() - sessionData.fishingPoleEquipTime)
        sessionData.fishingPoleEquipTime = nil
    end
    -- Save the completed session before resetting
    self:SaveSession()
    -- Reset so the next equip starts a fresh session
    self:ResetSession()
    FK:Debug("Fishing gear unequipped - session saved and reset")
end

function Stats:ResetStats()
    -- Reset per-character stats
    if FK.chardb then
        FK.chardb.stats = {
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
        }
        FK.chardb.lootHistory = {}
        FK.chardb.sessions = {}
    end

    -- Reset session
    self:ResetSession()
end

-- ============================================================================
-- Statistics Getters
-- ============================================================================

function Stats:GetSessionStats()
    -- Only count time while fishing gear is equipped
    local duration = sessionData.fishingTime or 0
    if sessionData.fishingPoleEquipTime then
        duration = duration + (GetTime() - sessionData.fishingPoleEquipTime)
    end

    -- Casts are only counted at resolution (catch or genuine timeout), so
    -- sessionData.casts already excludes any in-progress cast.
    local successRate = 0
    if sessionData.casts > 0 then
        successRate = (sessionData.catches / sessionData.casts) * 100
    end

    return {
        duration = duration,
        casts = sessionData.casts,
        catches = sessionData.catches,
        gotAway = sessionData.gotAway,
        junk = sessionData.junk,
        skillUps = sessionData.skillUps,
        successRate = successRate,
        fishPerHour = duration > 0 and (sessionData.catches / duration * 3600) or 0,
        vendorCopper = sessionData.vendorCopper or 0,
        ahCopper = sessionData.ahCopper or 0,
        blendedCopper = sessionData.blendedCopper or 0,
        vendorPerHour = duration > 0 and ((sessionData.vendorCopper or 0) / duration * 3600) or 0,
        ahPerHour = duration > 0 and ((sessionData.ahCopper or 0) / duration * 3600) or 0,
        blendedPerHour = duration > 0 and ((sessionData.blendedCopper or 0) / duration * 3600) or 0,
        efficiencyBuckets = sessionData.efficiencyBuckets,
    }
end

function Stats:GetTotalStats()
    if not FK.chardb or not FK.chardb.stats then
        return {
            totalCasts = 0,
            totalCatches = 0,
            totalJunk = 0,
            totalGotAway = 0,
            successRate = 0,
            uniqueFish = 0,
        }
    end

    local stats = FK.chardb.stats
    local successRate = 0
    if stats.totalCasts and stats.totalCasts > 0 then
        successRate = ((stats.totalCatches or 0) / stats.totalCasts) * 100
    end

    local uniqueFish = 0
    if stats.fishCaught then
        for _ in pairs(stats.fishCaught) do
            uniqueFish = uniqueFish + 1
        end
    end

    return {
        totalCasts = stats.totalCasts or 0,
        totalCatches = stats.totalCatches or 0,
        totalJunk = stats.totalJunk or 0,
        totalGotAway = stats.totalGotAway or 0,
        successRate = successRate,
        uniqueFish = uniqueFish,
        skillUps = stats.skillUps or 0,
    }
end

function Stats:GetTopFish(limit)
    limit = limit or 10
    local fishList = {}

    if FK.chardb and FK.chardb.stats and FK.chardb.stats.fishCaught then
        for itemID, data in pairs(FK.chardb.stats.fishCaught) do
            table.insert(fishList, {
                itemID = itemID,
                name = data.name,
                count = data.count,
                quality = data.quality,
            })
        end
    end

    table.sort(fishList, function(a, b) return a.count > b.count end)

    local result = {}
    for i = 1, math.min(limit, #fishList) do
        result[i] = fishList[i]
    end

    return result
end

function Stats:GetZoneStats(zoneName)
    if FK.chardb and FK.chardb.stats and FK.chardb.stats.zoneStats then
        return FK.chardb.stats.zoneStats[zoneName]
    end
    return nil
end

function Stats:GetRecentRareCatches(limit)
    limit = limit or 10

    if FK.chardb and FK.chardb.stats and FK.chardb.stats.rareCatches then
        local result = {}
        local start = math.max(1, #FK.chardb.stats.rareCatches - limit + 1)
        for i = #FK.chardb.stats.rareCatches, start, -1 do
            table.insert(result, FK.chardb.stats.rareCatches[i])
        end
        return result
    end

    return {}
end

-- ============================================================================
-- Milestones
-- ============================================================================

function Stats:CheckMilestone()
    if not FK.chardb or not FK.chardb.stats then return end

    local totalCatches = FK.chardb.stats.totalCatches or 0

    for _, threshold in ipairs(MILESTONES) do
        if totalCatches == threshold then
            -- Celebration!
            FK:Print(FK.Colors.highlight .. "MILESTONE!|r " .. FK.Colors.success ..
                FK:FormatNumber(threshold) .. " fish caught!|r Congratulations!", FK.Colors.highlight)

            -- Play milestone sound
            if FK.Alerts and FK.Alerts.PlaySound then
                FK.Alerts:PlaySound("rare")
            end

            -- Flash the UI
            if FK.UI and FK.UI.OnCatchSuccess then
                FK.UI:OnCatchSuccess()
            end

            break
        end
    end
end

-- ============================================================================
-- Session Efficiency Tracking (5-minute buckets)
-- ============================================================================

function Stats:RecordEfficiencyBucket()
    local elapsed = GetTime() - sessionData.startTime
    local bucketIndex = math.floor(elapsed / 300) + 1  -- 5 minute buckets

    if not sessionData.efficiencyBuckets[bucketIndex] then
        sessionData.efficiencyBuckets[bucketIndex] = 0
    end
    sessionData.efficiencyBuckets[bucketIndex] = sessionData.efficiencyBuckets[bucketIndex] + 1
end

function Stats:GetEfficiencyTrend()
    local buckets = sessionData.efficiencyBuckets
    if not buckets or not next(buckets) then return nil end

    -- Convert to fish/hour per bucket
    local trend = {}
    local maxBucket = 0
    for idx, _ in pairs(buckets) do
        if idx > maxBucket then maxBucket = idx end
    end

    for i = 1, maxBucket do
        local count = buckets[i] or 0
        -- Each bucket is 5 minutes, so fish/hour = count * 12
        table.insert(trend, {
            bucket = i,
            catches = count,
            fph = count * 12,
        })
    end

    return trend
end

-- ============================================================================
-- Bite Timing Tracking
-- ============================================================================

function Stats:RecordBiteTime()
    if not FK:GetCastStartTime() then return end
    if not FK.chardb then return end

    local elapsed = GetTime() - FK:GetCastStartTime()
    -- Only record reasonable bite times (between 2-21 seconds)
    if elapsed < 2 or elapsed > 21 then return end

    local zone = FK:GetZone() or "Unknown"
    if not FK.chardb.biteTimings then
        FK.chardb.biteTimings = {}
    end
    if not FK.chardb.biteTimings[zone] then
        FK.chardb.biteTimings[zone] = {}
    end

    table.insert(FK.chardb.biteTimings[zone], elapsed)

    -- Keep only last 50 per zone (one item inserted at a time, so if suffices)
    if #FK.chardb.biteTimings[zone] > 50 then
        table.remove(FK.chardb.biteTimings[zone], 1)
    end

    -- Invalidate the cache for this zone so GetBiteConfidence recomputes on next call
    biteConfidenceCache[zone] = nil

    FK:Debug("Bite time recorded: " .. string.format("%.1f", elapsed) .. "s in " .. zone)
end

function Stats:GetBiteConfidence(zone)
    if not FK.chardb or not FK.chardb.biteTimings then return nil end

    zone = zone or FK:GetZone() or "Unknown"
    local timings = FK.chardb.biteTimings[zone]
    if not timings or #timings < 5 then return nil end

    if biteConfidenceCache[zone] then
        return biteConfidenceCache[zone]
    end

    -- Sort a copy to find percentiles
    local sorted = {}
    for _, v in ipairs(timings) do
        sorted[#sorted + 1] = v
    end
    table.sort(sorted)

    local n = #sorted
    -- 35th and 65th percentile for a tight band
    local p35Index = math.max(1, math.floor(n * 0.35 + 0.5))
    local p65Index = math.min(n, math.floor(n * 0.65 + 0.5))

    -- Median (50th percentile)
    local medianIndex = math.max(1, math.floor(n * 0.5 + 0.5))

    biteConfidenceCache[zone] = {
        low = sorted[p35Index],
        high = sorted[p65Index],
        median = sorted[medianIndex],
        samples = n,
    }
    return biteConfidenceCache[zone]
end

-- ============================================================================
-- Fishing Goals
-- ============================================================================

function Stats:GetSessionFishCount(itemID)
    if not itemID then return 0 end
    if sessionData.fishCaught[itemID] then
        return sessionData.fishCaught[itemID].count or 0
    end
    return 0
end

function Stats:GetSessionFishCountByName(name)
    if not name then return 0 end
    local lowerName = string.lower(name)
    for _, data in pairs(sessionData.fishCaught) do
        if data.name and string.lower(data.name) == lowerName then
            return data.count or 0
        end
    end
    return 0
end

function Stats:GetGoalProgress()
    if not FK.chardb or not FK.chardb.goals or #FK.chardb.goals == 0 then
        return nil
    end

    -- Return first incomplete goal
    for _, goal in ipairs(FK.chardb.goals) do
        local progress = 0
        if goal.itemID then
            progress = self:GetSessionFishCount(goal.itemID)
        else
            progress = self:GetSessionFishCountByName(goal.name)
        end
        if progress < goal.target then
            return {
                name = goal.name,
                current = progress,
                target = goal.target,
                complete = false,
            }
        end
    end

    -- All goals complete, return last one
    local lastGoal = FK.chardb.goals[#FK.chardb.goals]
    local progress = 0
    if lastGoal.itemID then
        progress = self:GetSessionFishCount(lastGoal.itemID)
    else
        progress = self:GetSessionFishCountByName(lastGoal.name)
    end
    return {
        name = lastGoal.name,
        current = progress,
        target = lastGoal.target,
        complete = true,
    }
end

-- ============================================================================
-- Display Functions
-- ============================================================================

function Stats:ShowSummary()
    local session = self:GetSessionStats()
    local total = self:GetTotalStats()
    local skill, maxSkill = FK:GetFishingSkill()

    FK:Print("=== Fishing Statistics ===", FK.Colors.highlight)

    -- Session Stats
    print(FK.Colors.info .. "Session:|r")
    print("  Duration: " .. FK:FormatTime(session.duration))
    print("  Casts: " .. session.casts .. " | Catches: " .. session.catches)
    print("  Success Rate: " .. string.format("%.1f%%", session.successRate))
    print("  Fish/Hour: " .. string.format("%.1f", session.fishPerHour))

    -- Total Stats
    print(FK.Colors.info .. "All Time:|r")
    print("  Total Casts: " .. FK:FormatNumber(total.totalCasts))
    print("  Total Catches: " .. FK:FormatNumber(total.totalCatches))
    print("  Success Rate: " .. string.format("%.1f%%", total.successRate))
    print("  Unique Fish: " .. total.uniqueFish)
    print("  Skill Ups: " .. total.skillUps)

    -- Current Skill
    print(FK.Colors.info .. "Current Skill:|r " .. skill .. "/" .. maxSkill)

    -- Top Fish
    local topFish = self:GetTopFish(5)
    if #topFish > 0 then
        print(FK.Colors.info .. "Top Catches:|r")
        for i, fish in ipairs(topFish) do
            local r, g, b = unpack(FK.Database:GetQualityColor(fish.quality))
            local colorCode = string.format("|cFF%02X%02X%02X", r * 255, g * 255, b * 255)
            print("  " .. i .. ". " .. colorCode .. fish.name .. "|r x" .. fish.count)
        end
    end
end

-- ============================================================================
-- Utility Functions
-- ============================================================================

function Stats:GetItemIDFromLink(link)
    if not link then return nil end
    local itemID = string.match(link, "item:(%d+)")
    return itemID and tonumber(itemID) or nil
end

FK:Debug("Statistics module loaded")
