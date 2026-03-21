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
}

-- Pending loot tracking (for when loot window is open)
local pendingLoot = {}

-- Milestone thresholds for celebration
local MILESTONES = { 100, 250, 500, 1000, 2500, 5000, 10000 }

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
    local zone = FK.State.currentZone
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

    local zone = FK.State.currentZone
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

function Stats:OnLootOpened()
    if not FK.db.settings.trackStats then return end

    -- Clear pending loot
    pendingLoot = {}

    -- Scan the loot window
    local numItems = GetNumLootItems()
    for i = 1, numItems do
        local lootIcon, lootName, lootQuantity, currencyID, lootQuality, locked, isQuestItem, questId, isActive = GetLootSlotInfo(i)
        local lootLink = GetLootSlotLink(i)

        if lootLink then
            local itemID = self:GetItemIDFromLink(lootLink)
            if itemID then
                table.insert(pendingLoot, {
                    slot = i,
                    itemID = itemID,
                    name = lootName,
                    quantity = lootQuantity or 1,
                    quality = lootQuality or 0,
                    link = lootLink,
                })
            end
        end
    end

    FK:Debug("Loot window opened with " .. #pendingLoot .. " items")
end

function Stats:OnLootSlotCleared(slot)
    if not FK.db.settings.trackStats then return end

    -- Find the item in pending loot
    for i, loot in ipairs(pendingLoot) do
        if loot.slot == slot and not loot.recorded then
            self:RecordCatch(loot)
            loot.recorded = true
            break
        end
    end
end

function Stats:OnLootClosed()
    if not FK.db.settings.trackStats then return end

    -- Count any remaining unrecorded loot (auto-loot scenarios)
    for _, loot in ipairs(pendingLoot) do
        if not loot.recorded then
            self:RecordCatch(loot)
        end
    end

    pendingLoot = {}
    FK:Debug("Loot closed, catch finalized")
end

function Stats:RecordCatch(lootData)
    local itemID = lootData.itemID
    local itemName = lootData.name
    local quantity = lootData.quantity or 1
    local quality = lootData.quality or 0
    local zone = FK.State.currentZone or "Unknown"

    -- Check if it's junk
    local isJunk = FK.Database:IsJunk(itemID)
    local isFish = FK.Database:IsFish(itemID)
    local isSpecial = FK.Database:IsSpecial(itemID)

    if isJunk then
        sessionData.junk = sessionData.junk + 1
        if FK.chardb and FK.chardb.stats then
            FK.chardb.stats.totalJunk = (FK.chardb.stats.totalJunk or 0) + 1
        end
        FK:Debug("Junk recorded: " .. itemName)
    else
        -- Count as catch
        sessionData.catches = sessionData.catches + 1

        if FK.chardb and FK.chardb.stats then
            FK.chardb.stats.totalCatches = (FK.chardb.stats.totalCatches or 0) + 1
            FK.chardb.stats.sessionCatches = (FK.chardb.stats.sessionCatches or 0) + 1
        end

        if FK.db and FK.db.globalStats then
            FK.db.globalStats.totalCatches = (FK.db.globalStats.totalCatches or 0) + 1
        end

        -- Track by fish type
        if not sessionData.fishCaught[itemID] then
            sessionData.fishCaught[itemID] = { name = itemName, count = 0, quality = quality }
        end
        sessionData.fishCaught[itemID].count = sessionData.fishCaught[itemID].count + quantity

        -- Per-character tracking
        if FK.chardb and FK.chardb.stats then
            if not FK.chardb.stats.fishCaught then
                FK.chardb.stats.fishCaught = {}
            end
            if not FK.chardb.stats.fishCaught[itemID] then
                FK.chardb.stats.fishCaught[itemID] = { name = itemName, count = 0, quality = quality, firstCaught = time() }
            end
            FK.chardb.stats.fishCaught[itemID].count = FK.chardb.stats.fishCaught[itemID].count + quantity
            FK.chardb.stats.fishCaught[itemID].lastCaught = time()
        end

        -- Global tracking
        if FK.db and FK.db.globalStats then
            if not FK.db.globalStats.fishCaught then
                FK.db.globalStats.fishCaught = {}
            end
            if not FK.db.globalStats.fishCaught[itemID] then
                FK.db.globalStats.fishCaught[itemID] = { name = itemName, count = 0, quality = quality }
            end
            FK.db.globalStats.fishCaught[itemID].count = FK.db.globalStats.fishCaught[itemID].count + quantity
        end

        -- Zone tracking
        if zone and zone ~= "" then
            if sessionData.zones[zone] then
                sessionData.zones[zone].catches = (sessionData.zones[zone].catches or 0) + 1
            end

            if FK.chardb and FK.chardb.stats and FK.chardb.stats.zoneStats then
                if FK.chardb.stats.zoneStats[zone] then
                    FK.chardb.stats.zoneStats[zone].catches = (FK.chardb.stats.zoneStats[zone].catches or 0) + 1

                    if not FK.chardb.stats.zoneStats[zone].fish then
                        FK.chardb.stats.zoneStats[zone].fish = {}
                    end
                    FK.chardb.stats.zoneStats[zone].fish[itemID] = (FK.chardb.stats.zoneStats[zone].fish[itemID] or 0) + quantity
                end
            end
        end

        -- Track rare catches
        if quality >= 3 or isSpecial then
            self:RecordRareCatch(lootData, zone)
        end

        -- Add to loot history
        self:AddToLootHistory(lootData, zone)

        -- Notify UI of catch
        if FK.UI and FK.UI.OnCatch then
            FK.UI:OnCatch(itemName, lootData.link)
        end

        -- Track efficiency bucket (5-minute intervals)
        self:RecordEfficiencyBucket()

        -- Check milestones
        if FK.db and FK.db.settings.milestones then
            self:CheckMilestone()
        end

        FK:Debug("Catch recorded: " .. itemName .. " x" .. quantity)
    end

    -- Calculate vendor value using GetItemInfo sellPrice (11th return)
    -- Use itemLink first (more reliable in TBC), fall back to itemID
    local _, _, _, _, _, _, _, _, _, _, sellPrice = GetItemInfo(lootData.link or itemID)
    local vendorValue = (sellPrice and sellPrice > 0) and sellPrice or 0
    if vendorValue > 0 then
        sessionData.vendorCopper = (sessionData.vendorCopper or 0) + (vendorValue * quantity)
    end

    -- Calculate AH value if we have cached prices
    local ahValue = 0
    if FK.db and FK.db.ahPrices and FK.db.ahPrices[itemID] then
        ahValue = FK.db.ahPrices[itemID]
        sessionData.ahCopper = (sessionData.ahCopper or 0) + (ahValue * quantity)
    end

    -- Blended value: use AH price if available, otherwise vendor price
    local blendedValue = ahValue > 0 and ahValue or vendorValue
    if blendedValue > 0 then
        sessionData.blendedCopper = (sessionData.blendedCopper or 0) + (blendedValue * quantity)
    end
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

        -- Keep only last 100 rare catches
        while #FK.chardb.stats.rareCatches > 100 do
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

        -- Keep only last 500 items
        while #FK.chardb.lootHistory > 500 do
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
        })

        -- Keep only last 50 sessions
        while #FK.chardb.sessions > 50 do
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
    }

    if FK.chardb and FK.chardb.stats then
        FK.chardb.stats.sessionCasts = 0
        FK.chardb.stats.sessionCatches = 0
    end

    FK:Print("Session statistics reset.", FK.Colors.info)
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
    local duration = GetTime() - sessionData.startTime
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
    if not FK.State.castStartTime then return end
    if not FK.chardb then return end

    local elapsed = GetTime() - FK.State.castStartTime
    -- Only record reasonable bite times (between 2-21 seconds)
    if elapsed < 2 or elapsed > 21 then return end

    local zone = FK.State.currentZone or "Unknown"
    if not FK.chardb.biteTimings then
        FK.chardb.biteTimings = {}
    end
    if not FK.chardb.biteTimings[zone] then
        FK.chardb.biteTimings[zone] = {}
    end

    table.insert(FK.chardb.biteTimings[zone], elapsed)

    -- Keep only last 50 per zone
    while #FK.chardb.biteTimings[zone] > 50 do
        table.remove(FK.chardb.biteTimings[zone], 1)
    end

    FK:Debug("Bite time recorded: " .. string.format("%.1f", elapsed) .. "s in " .. zone)
end

function Stats:GetBiteConfidence(zone)
    if not FK.chardb or not FK.chardb.biteTimings then return nil end

    zone = zone or FK.State.currentZone or "Unknown"
    local timings = FK.chardb.biteTimings[zone]
    if not timings or #timings < 5 then return nil end

    -- Sort a copy
    local sorted = {}
    for _, v in ipairs(timings) do
        table.insert(sorted, v)
    end
    table.sort(sorted)

    local n = #sorted
    -- 35th and 65th percentile for a tight band
    local p35Index = math.max(1, math.floor(n * 0.35 + 0.5))
    local p65Index = math.min(n, math.floor(n * 0.65 + 0.5))

    -- Median (50th percentile)
    local medianIndex = math.max(1, math.floor(n * 0.5 + 0.5))

    return {
        low = sorted[p35Index],
        high = sorted[p65Index],
        median = sorted[medianIndex],
        samples = n,
    }
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

-- ============================================================================
-- Comprehensive Statistics Panel
-- ============================================================================

local statsPanel = {
    frame = nil,
    currentTab = "overview",
    scrollOffset = 0,
}

function Stats:CreateStatsPanel()
    if statsPanel.frame then return end

    local frame = CreateFrame("Frame", "FishingKitStatsPanel", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(450, 500)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- Backdrop
    local backdropInfo = {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 }
    }

    if frame.SetBackdrop then
        frame:SetBackdrop(backdropInfo)
        frame:SetBackdropColor(0.05, 0.05, 0.1, 0.95)
    end

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -12)
    title:SetText("|cFF00D1FFFishingKit|r - Statistics")
    frame.title = title

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)

    -- Tab buttons
    local tabs = {
        { id = "overview", label = "Overview" },
        { id = "fish", label = "Fish Caught" },
        { id = "zonefish", label = "Zone Fish" },
        { id = "zones", label = "Zones" },
        { id = "history", label = "History" },
    }

    local tabWidth = 80
    local tabContainer = CreateFrame("Frame", nil, frame)
    tabContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -40)
    tabContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -40)
    tabContainer:SetHeight(28)

    frame.tabs = {}
    for i, tabInfo in ipairs(tabs) do
        local tab = CreateFrame("Button", nil, tabContainer)
        tab:SetSize(tabWidth, 24)
        tab:SetPoint("LEFT", tabContainer, "LEFT", (i - 1) * (tabWidth + 4), 0)

        local bg = tab:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.2, 0.2, 0.3, 0.8)
        tab.bg = bg

        local text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("CENTER")
        text:SetText(tabInfo.label)
        tab.text = text

        tab:SetScript("OnClick", function()
            Stats:ShowTab(tabInfo.id)
        end)

        tab:SetScript("OnEnter", function(self)
            if statsPanel.currentTab ~= tabInfo.id then
                self.bg:SetColorTexture(0.3, 0.3, 0.4, 0.9)
            end
        end)

        tab:SetScript("OnLeave", function(self)
            if statsPanel.currentTab ~= tabInfo.id then
                self.bg:SetColorTexture(0.2, 0.2, 0.3, 0.8)
            end
        end)

        frame.tabs[tabInfo.id] = tab
    end

    -- Content area
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -72)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    frame.content = content

    -- Create scroll frame for content
    local scrollFrame = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -24, 0)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(400, 800)
    scrollFrame:SetScrollChild(scrollChild)
    frame.scrollChild = scrollChild

    statsPanel.frame = frame
    frame:Hide()

    -- Show default tab
    self:ShowTab("overview")
end

function Stats:ShowTab(tabID)
    statsPanel.currentTab = tabID

    -- Update tab appearance
    for id, tab in pairs(statsPanel.frame.tabs) do
        if id == tabID then
            tab.bg:SetColorTexture(0.1, 0.4, 0.7, 1)
            tab.text:SetTextColor(1, 1, 1)
        else
            tab.bg:SetColorTexture(0.2, 0.2, 0.3, 0.8)
            tab.text:SetTextColor(0.7, 0.7, 0.7)
        end
    end

    -- Clear content
    local scrollChild = statsPanel.frame.scrollChild
    for _, child in pairs({scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    for _, region in pairs({scrollChild:GetRegions()}) do
        region:Hide()
        region:SetParent(nil)
    end

    -- Populate based on tab
    if tabID == "overview" then
        self:PopulateOverviewTab(scrollChild)
    elseif tabID == "fish" then
        self:PopulateFishTab(scrollChild)
    elseif tabID == "zonefish" then
        self:PopulateZoneFishTab(scrollChild)
    elseif tabID == "zones" then
        self:PopulateZonesTab(scrollChild)
    elseif tabID == "history" then
        self:PopulateHistoryTab(scrollChild)
    end
end

function Stats:PopulateOverviewTab(parent)
    local yOffset = -10
    local session = self:GetSessionStats()
    local total = self:GetTotalStats()
    local skill, maxSkill = FK:GetFishingSkill()

    -- Session Statistics Section
    local sessionHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    sessionHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    sessionHeader:SetText("|cFFFFD700Current Session|r")
    yOffset = yOffset - 25

    local sessionInfo = {
        { "Duration:", FK:FormatTime(session.duration) },
        { "Casts:", tostring(session.casts) },
        { "Catches:", tostring(session.catches), {0.2, 1, 0.2} },
        { "Got Away:", tostring(session.gotAway), {1, 0.5, 0.2} },
        { "Junk Items:", tostring(session.junk), {0.6, 0.6, 0.6} },
        { "Success Rate:", string.format("%.1f%%", session.successRate) },
        { "Fish/Hour:", string.format("%.1f", session.fishPerHour), {0.2, 0.8, 1} },
        { "Skill Ups:", tostring(session.skillUps), {0.2, 1, 0.2} },
    }

    for _, info in ipairs(sessionInfo) do
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
        label:SetText(info[1])
        label:SetTextColor(0.7, 0.7, 0.7)

        local value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        value:SetPoint("TOPLEFT", parent, "TOPLEFT", 140, yOffset)
        value:SetText(info[2])
        if info[3] then
            value:SetTextColor(unpack(info[3]))
        end

        yOffset = yOffset - 18
    end

    yOffset = yOffset - 15

    -- Lifetime Statistics Section
    local totalHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    totalHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    totalHeader:SetText("|cFFFFD700Lifetime Statistics|r")
    yOffset = yOffset - 25

    local totalInfo = {
        { "Total Casts:", FK:FormatNumber(total.totalCasts) },
        { "Total Catches:", FK:FormatNumber(total.totalCatches), {0.2, 1, 0.2} },
        { "Total Junk:", FK:FormatNumber(total.totalJunk), {0.6, 0.6, 0.6} },
        { "Total Got Away:", FK:FormatNumber(total.totalGotAway), {1, 0.5, 0.2} },
        { "Success Rate:", string.format("%.1f%%", total.successRate) },
        { "Unique Fish:", tostring(total.uniqueFish), {0.2, 0.8, 1} },
        { "Total Skill Ups:", tostring(total.skillUps), {0.2, 1, 0.2} },
    }

    for _, info in ipairs(totalInfo) do
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
        label:SetText(info[1])
        label:SetTextColor(0.7, 0.7, 0.7)

        local value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        value:SetPoint("TOPLEFT", parent, "TOPLEFT", 140, yOffset)
        value:SetText(info[2])
        if info[3] then
            value:SetTextColor(unpack(info[3]))
        end

        yOffset = yOffset - 18
    end

    yOffset = yOffset - 15

    -- Current Skill Section
    local skillHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    skillHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    skillHeader:SetText("|cFFFFD700Current Skill|r")
    yOffset = yOffset - 25

    local skillText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    skillText:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    skillText:SetText("Fishing: " .. skill .. " / " .. (maxSkill or 375))
    yOffset = yOffset - 18

    local bonus = FK.Equipment:GetTotalBonus()
    local bonusText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bonusText:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    bonusText:SetText("Effective Skill: |cFF00FF00" .. (skill + bonus) .. "|r (+" .. bonus .. " from gear)")
    yOffset = yOffset - 25

    -- Gold Earned Section
    yOffset = yOffset - 10
    local goldHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    goldHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    goldHeader:SetText("|cFFFFD700Session Gold|r")
    yOffset = yOffset - 25

    local blendedGold = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    blendedGold:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    local blendedCop = session.blendedCopper or 0
    blendedGold:SetText("Est. Value: |cFFFFD700" .. FK:FormatCopper(math.floor(blendedCop)) .. "|r (" .. FK:FormatCopper(math.floor(session.blendedPerHour or 0)) .. "/hr)")
    yOffset = yOffset - 18

    local vendorGold = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    vendorGold:SetPoint("TOPLEFT", parent, "TOPLEFT", 30, yOffset)
    vendorGold:SetText("|cFF888888Vendor: " .. FK:FormatCopper(math.floor(session.vendorCopper or 0)) .. "/hr|r")
    yOffset = yOffset - 16

    local ahGold = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ahGold:SetPoint("TOPLEFT", parent, "TOPLEFT", 30, yOffset)
    if (session.ahCopper or 0) > 0 then
        ahGold:SetText("|cFF888888AH: " .. FK:FormatCopper(math.floor(session.ahPerHour or 0)) .. "/hr|r")
    else
        ahGold:SetText("|cFF888888AH: scan prices at AH|r")
    end
    yOffset = yOffset - 25

    -- Efficiency Trend Section
    local trend = self:GetEfficiencyTrend()
    if trend and #trend > 1 then
        yOffset = yOffset - 10
        local trendHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        trendHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
        trendHeader:SetText("|cFFFFD700Efficiency Trend|r |cFF888888(fish/hr per 5 min)|r")
        yOffset = yOffset - 22

        -- Find max for scaling the bar graph
        local maxFph = 1
        for _, bucket in ipairs(trend) do
            if bucket.fph > maxFph then maxFph = bucket.fph end
        end

        -- Simple text-based bar chart
        for i, bucket in ipairs(trend) do
            local barLength = math.floor((bucket.fph / maxFph) * 20)
            local barStr = string.rep("|", barLength)

            -- Color based on relative performance
            local pct = bucket.fph / maxFph
            local barColor
            if pct >= 0.75 then barColor = "|cFF00FF00"
            elseif pct >= 0.5 then barColor = "|cFFFFFF00"
            else barColor = "|cFFFF8800" end

            local timeLabel = string.format("%d-%dm", (i-1)*5, i*5)
            local line = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            line:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
            line:SetText("|cFF888888" .. timeLabel .. "|r " .. barColor .. barStr .. "|r |cFFFFFFFF" .. bucket.fph .. "/hr|r")
            yOffset = yOffset - 14
        end
    end

    parent:SetHeight(math.abs(yOffset) + 50)
end

function Stats:PopulateFishTab(parent)
    local yOffset = -10

    -- Get all fish and sort by count
    local fishList = {}
    local totalCatches = FK.chardb and FK.chardb.stats and FK.chardb.stats.totalCatches or 0
    if FK.chardb and FK.chardb.stats and FK.chardb.stats.fishCaught then
        for itemID, data in pairs(FK.chardb.stats.fishCaught) do
            table.insert(fishList, {
                itemID = itemID,
                name = data.name or "Unknown",
                count = data.count or 0,
                quality = data.quality or 0,
            })
        end
    end

    table.sort(fishList, function(a, b) return a.count > b.count end)

    local qualityColors = {
        [0] = {0.6, 0.6, 0.6},  -- Poor (gray)
        [1] = {1, 1, 1},         -- Common (white)
        [2] = {0.12, 1, 0},      -- Uncommon (green)
        [3] = {0, 0.44, 0.87},   -- Rare (blue)
        [4] = {0.64, 0.21, 0.93},-- Epic (purple)
        [5] = {1, 0.5, 0},       -- Legendary (orange)
    }

    if #fishList == 0 then
        local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        header:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
        header:SetText("|cFFFFD700Fish Caught (All Time)|r")
        yOffset = yOffset - 25

        local noData = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        noData:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
        noData:SetText("|cFF888888No fish caught yet. Start fishing!|r")
        yOffset = yOffset - 20
    else
        -- ================================================================
        -- Top 5 Catches
        -- ================================================================
        local topHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        topHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
        topHeader:SetText("|cFFFFD700Top 5 Catches|r")
        yOffset = yOffset - 22

        local topCount = math.min(5, #fishList)
        for i = 1, topCount do
            local fish = fishList[i]
            local color = qualityColors[fish.quality] or {1, 1, 1}
            local pct = totalCatches > 0 and string.format("%.1f%%", fish.count / totalCatches * 100) or "—"

            local rankText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            rankText:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
            rankText:SetText("|cFFFFD700" .. i .. ".|r")

            local nameText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            nameText:SetPoint("TOPLEFT", parent, "TOPLEFT", 40, yOffset)
            nameText:SetText(fish.name)
            nameText:SetTextColor(unpack(color))

            local countText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            countText:SetPoint("TOPLEFT", parent, "TOPLEFT", 250, yOffset)
            countText:SetText("|cFFFFD700x" .. FK:FormatNumber(fish.count) .. "|r")

            local pctText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            pctText:SetPoint("TOPLEFT", parent, "TOPLEFT", 310, yOffset)
            pctText:SetText("|cFFFFD700" .. pct .. "|r")

            yOffset = yOffset - 18
        end

        -- Separator between Top 5 and Rare Fish
        yOffset = yOffset - 6
        local sep1 = parent:CreateTexture(nil, "ARTWORK")
        sep1:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, yOffset)
        sep1:SetSize(380, 1)
        sep1:SetColorTexture(0.4, 0.4, 0.4, 1)
        yOffset = yOffset - 10

        -- ================================================================
        -- Rare Fish Tracker
        -- ================================================================
        local rareHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        rareHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
        rareHeader:SetText("|cFFFFD700Rare Fish|r")
        yOffset = yOffset - 22

        -- Build list of all rare fish from database
        local rareFish = {}
        local rareCaught = 0
        local rareTotal = 0
        if FK.Database and FK.Database.Fish then
            for itemID, info in pairs(FK.Database.Fish) do
                if info.rare then
                    rareTotal = rareTotal + 1
                    local caught = FK.chardb and FK.chardb.stats and FK.chardb.stats.fishCaught and FK.chardb.stats.fishCaught[itemID]
                    local count = caught and caught.count or 0
                    if count > 0 then rareCaught = rareCaught + 1 end
                    table.insert(rareFish, {
                        itemID = itemID,
                        name = info.name,
                        quality = info.quality or 0,
                        count = count,
                        zone = info.zone or "",
                    })
                end
            end
        end

        table.sort(rareFish, function(a, b)
            if a.count > 0 and b.count == 0 then return true end
            if a.count == 0 and b.count > 0 then return false end
            return a.count > b.count
        end)

        local rareSummary = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        rareSummary:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
        rareSummary:SetText("|cFFAADDFFDiscovered: " .. rareCaught .. "/" .. rareTotal .. "|r")
        yOffset = yOffset - 18

        for _, fish in ipairs(rareFish) do
            local color = qualityColors[fish.quality] or {1, 1, 1}
            local nameText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            nameText:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)

            if fish.count > 0 then
                nameText:SetText(fish.name)
                nameText:SetTextColor(unpack(color))

                local countText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                countText:SetPoint("TOPLEFT", parent, "TOPLEFT", 250, yOffset)
                countText:SetText("x" .. FK:FormatNumber(fish.count))

                local pct = totalCatches > 0 and string.format("%.2f%%", fish.count / totalCatches * 100) or "—"
                local pctText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                pctText:SetPoint("TOPLEFT", parent, "TOPLEFT", 310, yOffset)
                pctText:SetText(pct)
                pctText:SetTextColor(0.6, 0.6, 0.6)
            else
                nameText:SetText("|cFF666666" .. fish.name .. "|r")

                local notYet = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                notYet:SetPoint("TOPLEFT", parent, "TOPLEFT", 250, yOffset)
                notYet:SetText("|cFF666666Not yet caught|r")
            end

            yOffset = yOffset - 18
        end

        -- Separator between Rare Fish and All Catches
        yOffset = yOffset - 6
        local sep1b = parent:CreateTexture(nil, "ARTWORK")
        sep1b:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, yOffset)
        sep1b:SetSize(380, 1)
        sep1b:SetColorTexture(0.4, 0.4, 0.4, 1)
        yOffset = yOffset - 10

        -- ================================================================
        -- All Catches
        -- ================================================================
        local allHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        allHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
        allHeader:SetText("|cFFFFD700All Catches|r")
        yOffset = yOffset - 22

        -- Column headers
        local nameHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
        nameHeader:SetText("Fish")
        nameHeader:SetTextColor(0.8, 0.8, 0.8)

        local countHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        countHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 250, yOffset)
        countHeader:SetText("Count")
        countHeader:SetTextColor(0.8, 0.8, 0.8)

        local pctHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        pctHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 310, yOffset)
        pctHeader:SetText("%")
        pctHeader:SetTextColor(0.8, 0.8, 0.8)

        yOffset = yOffset - 20

        local sep2 = parent:CreateTexture(nil, "ARTWORK")
        sep2:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, yOffset)
        sep2:SetSize(380, 1)
        sep2:SetColorTexture(0.4, 0.4, 0.4, 1)
        yOffset = yOffset - 8

        for i, fish in ipairs(fishList) do
            local color = qualityColors[fish.quality] or {1, 1, 1}
            local pct = totalCatches > 0 and string.format("%.1f%%", fish.count / totalCatches * 100) or "—"

            local nameText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            nameText:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
            nameText:SetText(fish.name)
            nameText:SetTextColor(unpack(color))

            local countText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            countText:SetPoint("TOPLEFT", parent, "TOPLEFT", 250, yOffset)
            countText:SetText("x" .. FK:FormatNumber(fish.count))

            local pctText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            pctText:SetPoint("TOPLEFT", parent, "TOPLEFT", 310, yOffset)
            pctText:SetText(pct)
            pctText:SetTextColor(0.6, 0.6, 0.6)

            yOffset = yOffset - 18
        end
    end

    -- Summary at bottom
    yOffset = yOffset - 15
    local summaryText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    summaryText:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    summaryText:SetText("|cFF888888Total unique fish types: " .. #fishList .. "|r")

    parent:SetHeight(math.abs(yOffset) + 50)
end

function Stats:PopulateZoneFishTab(parent)
    local yOffset = -10
    local zone = FK.State.currentZone or "Unknown"

    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    header:SetText("|cFFFFD700Available Fish in:|r |cFFFFFFFF" .. zone .. "|r")
    yOffset = yOffset - 25

    -- Get fish for this zone from the database
    local fishList = FK.Database:GetFishForZone(zone)

    if #fishList == 0 then
        local noData = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        noData:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
        noData:SetText("|cFF888888No fish data for this zone.|r")
        yOffset = yOffset - 20
    else
        -- Column headers
        local nameH = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameH:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
        nameH:SetText("Fish")
        nameH:SetTextColor(0.8, 0.8, 0.8)

        local skillH = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        skillH:SetPoint("TOPLEFT", parent, "TOPLEFT", 200, yOffset)
        skillH:SetText("Skill")
        skillH:SetTextColor(0.8, 0.8, 0.8)

        local caughtH = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        caughtH:SetPoint("TOPLEFT", parent, "TOPLEFT", 250, yOffset)
        caughtH:SetText("Caught")
        caughtH:SetTextColor(0.8, 0.8, 0.8)

        local valueH = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        valueH:SetPoint("TOPLEFT", parent, "TOPLEFT", 320, yOffset)
        valueH:SetText("Value")
        valueH:SetTextColor(0.8, 0.8, 0.8)

        yOffset = yOffset - 20

        local sep = parent:CreateTexture(nil, "ARTWORK")
        sep:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, yOffset)
        sep:SetSize(380, 1)
        sep:SetColorTexture(0.4, 0.4, 0.4, 1)
        yOffset = yOffset - 8

        -- Sort by quality desc then min skill
        table.sort(fishList, function(a, b)
            if a.quality ~= b.quality then return a.quality > b.quality end
            return a.minSkill < b.minSkill
        end)

        local skill = FK.State.fishingSkill or 0
        local qualityColors = {
            [0] = {0.6, 0.6, 0.6},
            [1] = {1, 1, 1},
            [2] = {0.12, 1, 0},
            [3] = {0, 0.44, 0.87},
            [4] = {0.64, 0.21, 0.93},
            [5] = {1, 0.5, 0},
        }

        for _, fish in ipairs(fishList) do
            local color = qualityColors[fish.quality] or {1, 1, 1}

            local nameText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            nameText:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
            nameText:SetText(fish.name)
            nameText:SetTextColor(unpack(color))

            -- Skill requirement (green if met, red if not)
            local skillColor = skill >= (fish.minSkill or 0) and {0.2, 1, 0.2} or {1, 0.3, 0.3}
            local skillText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            skillText:SetPoint("TOPLEFT", parent, "TOPLEFT", 200, yOffset)
            skillText:SetText(tostring(fish.minSkill or "?"))
            skillText:SetTextColor(unpack(skillColor))

            -- How many caught
            local caughtCount = 0
            if FK.chardb and FK.chardb.stats and FK.chardb.stats.fishCaught and FK.chardb.stats.fishCaught[fish.itemID] then
                caughtCount = FK.chardb.stats.fishCaught[fish.itemID].count or 0
            end
            local caughtText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            caughtText:SetPoint("TOPLEFT", parent, "TOPLEFT", 250, yOffset)
            caughtText:SetText(caughtCount > 0 and ("x" .. caughtCount) or "-")
            caughtText:SetTextColor(caughtCount > 0 and 0.2 or 0.5, caughtCount > 0 and 1 or 0.5, caughtCount > 0 and 0.2 or 0.5)

            -- AH or vendor value
            local valueStr = ""
            if FK.db and FK.db.ahPrices and FK.db.ahPrices[fish.itemID] then
                valueStr = FK:FormatCopper(FK.db.ahPrices[fish.itemID])
            else
                local _, _, _, _, _, _, _, _, _, _, sellPrice = GetItemInfo(fish.itemID)
                if sellPrice and sellPrice > 0 then
                    valueStr = FK:FormatCopper(sellPrice)
                end
            end
            local valueText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            valueText:SetPoint("TOPLEFT", parent, "TOPLEFT", 320, yOffset)
            valueText:SetText(valueStr ~= "" and valueStr or "-")
            valueText:SetTextColor(1, 0.82, 0)

            yOffset = yOffset - 18
        end
    end

    -- Also show pools
    local pools = FK.Database:GetPoolsForZone(zone)
    if #pools > 0 then
        yOffset = yOffset - 15
        local poolHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        poolHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
        poolHeader:SetText("|cFFFFD700Fishing Pools|r")
        yOffset = yOffset - 22

        for _, pool in ipairs(pools) do
            local poolText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            poolText:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
            poolText:SetText("|cFF00DDDD" .. pool.name .. "|r")
            yOffset = yOffset - 16
        end
    end

    -- Seasonal notes
    local seasonalFish = {}
    for _, fish in ipairs(fishList) do
        local fullInfo = FK.Database:GetFishInfo(fish.itemID)
        if fullInfo and fullInfo.seasonal then
            table.insert(seasonalFish, { name = fish.name, season = fullInfo.seasonal })
        end
    end
    if #seasonalFish > 0 then
        yOffset = yOffset - 15
        local seasonHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        seasonHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
        seasonHeader:SetText("|cFFFFD700Seasonal Notes|r")
        yOffset = yOffset - 22
        for _, sf in ipairs(seasonalFish) do
            local note = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            note:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
            local seasonText = sf.season == "winter" and "Winter (Sep-Mar)" or "Summer (Mar-Sep)"
            note:SetText("|cFFAADDFF" .. sf.name .. "|r - " .. seasonText)
            yOffset = yOffset - 16
        end
    end

    parent:SetHeight(math.abs(yOffset) + 50)
end

function Stats:PopulateZonesTab(parent)
    local yOffset = -10

    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    header:SetText("|cFFFFD700Fishing by Zone|r")
    yOffset = yOffset - 25

    -- Column headers
    local zoneHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    zoneHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    zoneHeader:SetText("Zone")
    zoneHeader:SetTextColor(0.8, 0.8, 0.8)

    local castsHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    castsHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 200, yOffset)
    castsHeader:SetText("Casts")
    castsHeader:SetTextColor(0.8, 0.8, 0.8)

    local catchesHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    catchesHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 270, yOffset)
    catchesHeader:SetText("Catches")
    catchesHeader:SetTextColor(0.8, 0.8, 0.8)

    local rateHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rateHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 350, yOffset)
    rateHeader:SetText("Rate")
    rateHeader:SetTextColor(0.8, 0.8, 0.8)

    yOffset = yOffset - 20

    -- Separator line
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, yOffset)
    sep:SetSize(380, 1)
    sep:SetColorTexture(0.4, 0.4, 0.4, 1)
    yOffset = yOffset - 8

    -- Get zone stats and sort by catches
    local zoneList = {}
    if FK.chardb and FK.chardb.stats and FK.chardb.stats.zoneStats then
        for zoneName, data in pairs(FK.chardb.stats.zoneStats) do
            table.insert(zoneList, {
                name = zoneName,
                casts = data.casts or 0,
                catches = data.catches or 0,
                fish = data.fish or {},
            })
        end
    end

    table.sort(zoneList, function(a, b) return a.catches > b.catches end)

    if #zoneList == 0 then
        local noData = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        noData:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
        noData:SetText("|cFF888888No zone data yet. Start fishing!|r")
        yOffset = yOffset - 20
    else
        for i, zone in ipairs(zoneList) do
            local rate = zone.casts > 0 and (zone.catches / zone.casts * 100) or 0

            local nameText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            nameText:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
            nameText:SetText(zone.name)
            nameText:SetTextColor(1, 0.82, 0)

            local castsText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            castsText:SetPoint("TOPLEFT", parent, "TOPLEFT", 200, yOffset)
            castsText:SetText(tostring(zone.casts))

            local catchesText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            catchesText:SetPoint("TOPLEFT", parent, "TOPLEFT", 270, yOffset)
            catchesText:SetText(tostring(zone.catches))
            catchesText:SetTextColor(0.2, 1, 0.2)

            local rateText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            rateText:SetPoint("TOPLEFT", parent, "TOPLEFT", 350, yOffset)
            rateText:SetText(string.format("%.0f%%", rate))

            yOffset = yOffset - 18

            -- Show top 3 fish for this zone
            local fishInZone = {}
            for itemID, count in pairs(zone.fish) do
                local fishData = FK.chardb.stats.fishCaught and FK.chardb.stats.fishCaught[itemID]
                local name = fishData and fishData.name or "Unknown Fish"
                table.insert(fishInZone, { name = name, count = count })
            end
            table.sort(fishInZone, function(a, b) return a.count > b.count end)

            if #fishInZone > 0 then
                local fishStr = "  "
                for j = 1, math.min(3, #fishInZone) do
                    if j > 1 then fishStr = fishStr .. ", " end
                    fishStr = fishStr .. fishInZone[j].name .. " x" .. fishInZone[j].count
                end

                local fishText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                fishText:SetPoint("TOPLEFT", parent, "TOPLEFT", 30, yOffset)
                fishText:SetText(fishStr)
                fishText:SetTextColor(0.5, 0.5, 0.5)
                yOffset = yOffset - 14
            end

            yOffset = yOffset - 6
        end
    end

    parent:SetHeight(math.abs(yOffset) + 50)
end

function Stats:PopulateHistoryTab(parent)
    local yOffset = -10

    -- Recent Catches
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    header:SetText("|cFFFFD700Recent Catches|r")
    yOffset = yOffset - 25

    if FK.chardb and FK.chardb.lootHistory and #FK.chardb.lootHistory > 0 then
        local count = math.min(20, #FK.chardb.lootHistory)
        for i = #FK.chardb.lootHistory, #FK.chardb.lootHistory - count + 1, -1 do
            local loot = FK.chardb.lootHistory[i]
            if loot then
                local qualityColors = {
                    [0] = {0.6, 0.6, 0.6},
                    [1] = {1, 1, 1},
                    [2] = {0.12, 1, 0},
                    [3] = {0, 0.44, 0.87},
                    [4] = {0.64, 0.21, 0.93},
                    [5] = {1, 0.5, 0},
                }
                local color = qualityColors[loot.quality] or {1, 1, 1}

                local itemText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                itemText:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
                itemText:SetText(loot.name .. (loot.quantity > 1 and (" x" .. loot.quantity) or ""))
                itemText:SetTextColor(unpack(color))

                local zoneText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                zoneText:SetPoint("TOPLEFT", parent, "TOPLEFT", 250, yOffset)
                zoneText:SetText(loot.zone or "Unknown")
                zoneText:SetTextColor(0.6, 0.6, 0.6)

                yOffset = yOffset - 18
            end
        end
    else
        local noData = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        noData:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
        noData:SetText("|cFF888888No loot history yet. Start fishing!|r")
        yOffset = yOffset - 20
    end

    yOffset = yOffset - 20

    -- Rare Catches
    local rareHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rareHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    rareHeader:SetText("|cFFFFD700Rare Catches|r")
    yOffset = yOffset - 25

    local rareCatches = self:GetRecentRareCatches(10)
    if #rareCatches > 0 then
        for _, catch in ipairs(rareCatches) do
            local qualityColors = {
                [3] = {0, 0.44, 0.87},
                [4] = {0.64, 0.21, 0.93},
                [5] = {1, 0.5, 0},
            }
            local color = qualityColors[catch.quality] or {0, 0.44, 0.87}

            local itemText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            itemText:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
            itemText:SetText(catch.name)
            itemText:SetTextColor(unpack(color))

            local infoText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            infoText:SetPoint("TOPLEFT", parent, "TOPLEFT", 200, yOffset)
            infoText:SetText(catch.zone .. " - " .. date("%m/%d %H:%M", catch.timestamp))
            infoText:SetTextColor(0.6, 0.6, 0.6)

            yOffset = yOffset - 18
        end
    else
        local noData = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        noData:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
        noData:SetText("|cFF888888No rare catches yet. Keep fishing!|r")
        yOffset = yOffset - 20
    end

    parent:SetHeight(math.abs(yOffset) + 50)
end

function Stats:ShowStatsPanel()
    if not statsPanel.frame then
        self:CreateStatsPanel()
    end

    self:ShowTab(statsPanel.currentTab)
    statsPanel.frame:Show()
end

function Stats:HideStatsPanel()
    if statsPanel.frame then
        statsPanel.frame:Hide()
    end
end

function Stats:ToggleStatsPanel()
    if statsPanel.frame and statsPanel.frame:IsShown() then
        self:HideStatsPanel()
    else
        self:ShowStatsPanel()
    end
end

FK:Debug("Statistics module loaded")
