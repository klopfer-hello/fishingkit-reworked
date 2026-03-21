--[[
    FishingKit - TBC Anniversary Edition
    Equipment Module - Fishing gear management and swapping

    This module handles:
    - Saving and loading fishing gear sets
    - Automatic gear swapping
    - Fishing pole detection
    - Lure management and application
    - Equipment bonus calculations
]]

local ADDON_NAME, FK = ...

FK.Equipment = {}
local Equip = FK.Equipment

-- Inventory slot constants
local SLOT_HEAD = 1
local SLOT_HANDS = 10
local SLOT_MAINHAND = 16
local SLOT_OFFHAND = 17
local SLOT_FEET = 8

-- Equipment state
local equipState = {
    hasFishingPole = false,
    currentPoleBonus = 0,
    totalBonus = 0,
    hasLure = false,
    lureExpireTime = 0,
    lureBonus = 0,
    scanTooltip = nil,  -- Hidden tooltip for scanning
}

-- ============================================================================
-- Tooltip Scanning (to read lure bonus from fishing pole)
-- ============================================================================

local function CreateScanTooltip()
    if equipState.scanTooltip then return equipState.scanTooltip end

    local tooltip = CreateFrame("GameTooltip", "FishingKitScanTooltip", nil, "GameTooltipTemplate")
    tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    equipState.scanTooltip = tooltip
    return tooltip
end

-- Scan the fishing pole tooltip to find the lure bonus
function Equip:GetLureBonusFromTooltip()
    local tooltip = CreateScanTooltip()
    tooltip:ClearLines()
    tooltip:SetInventoryItem("player", SLOT_MAINHAND)

    -- Scan tooltip lines for fishing bonus from lure (temporary enchant)
    -- Lure lines look like: "Fishing +75 (10 min)", "+75 Fishing Skill", etc.
    -- We look for lines with both a number and timing info, or green-colored enchant text
    for i = 1, tooltip:NumLines() do
        local leftText = _G["FishingKitScanTooltipTextLeft" .. i]
        if leftText then
            local text = leftText:GetText()
            if text then
                -- Check if this line mentions time remaining (indicates temporary enchant)
                local hasTimeInfo = string.find(text, "min") or string.find(text, "sec")

                -- Pattern 1: "Fishing +75" or "Fishing Skill +75"
                local bonus = string.match(text, "Fishing%D*%+?(%d+)")
                if bonus and hasTimeInfo then
                    local bonusNum = tonumber(bonus)
                    if bonusNum and bonusNum > 0 then
                        return bonusNum
                    end
                end

                -- Pattern 2: "+75 Fishing"
                bonus = string.match(text, "%+(%d+)%s*Fishing")
                if bonus and hasTimeInfo then
                    local bonusNum = tonumber(bonus)
                    if bonusNum and bonusNum > 0 then
                        return bonusNum
                    end
                end

                -- Pattern 3: Check for green text (enchants are often green) without time check
                -- for format like "Fishing +75" as a standalone enchant line
                local r, g, b = leftText:GetTextColor()
                local isGreen = (g > 0.9 and r < 0.5 and b < 0.5)
                if isGreen then
                    bonus = string.match(text, "%+(%d+)")
                    if bonus and string.find(text, "Fishing") then
                        local bonusNum = tonumber(bonus)
                        if bonusNum and bonusNum >= 25 and bonusNum <= 100 then
                            return bonusNum
                        end
                    end
                end
            end
        end
    end

    return 0  -- No lure bonus found
end

-- ============================================================================
-- Initialization
-- ============================================================================

function Equip:Initialize()
    -- Scan current equipment on init
    self:ScanEquipment()

    -- Rescan after a delay to catch items that weren't cached yet
    C_Timer.After(1, function()
        self:ScanEquipment()
        FK:Debug("Equipment rescanned after delay")
    end)

    -- Another rescan after 3 seconds for slow loading
    C_Timer.After(3, function()
        self:ScanEquipment()
    end)

    FK:Debug("Equipment module initialized")
end

-- ============================================================================
-- Equipment Scanning
-- ============================================================================

function Equip:ScanEquipment()
    -- Reset state
    equipState.hasFishingPole = false
    equipState.currentPoleBonus = 0
    equipState.totalBonus = 0

    -- Check main hand for fishing pole
    local mainHandLink = GetInventoryItemLink("player", SLOT_MAINHAND)
    if mainHandLink then
        local itemID = self:GetItemIDFromLink(mainHandLink)
        if itemID then
            local poleData = FK.Database.FishingPoles[itemID]
            if poleData then
                equipState.hasFishingPole = true
                equipState.currentPoleBonus = poleData.bonus or 0
            else
                -- Check if it's a fishing pole by item subtype
                local _, _, _, _, _, itemType, itemSubType = GetItemInfo(mainHandLink)
                if itemSubType and (itemSubType == "Fishing Poles" or itemSubType == "Fishing Pole") then
                    equipState.hasFishingPole = true
                end
            end
        end
    end

    -- Check for fishing hat
    local headLink = GetInventoryItemLink("player", SLOT_HEAD)
    if headLink then
        local itemID = self:GetItemIDFromLink(headLink)
        if itemID then
            local hatData = FK.Database.FishingHats[itemID]
            if hatData then
                equipState.totalBonus = equipState.totalBonus + (hatData.bonus or 0)
            end
        end
    end

    -- Check for fishing boots
    local feetLink = GetInventoryItemLink("player", SLOT_FEET)
    if feetLink then
        local itemID = self:GetItemIDFromLink(feetLink)
        if itemID then
            local bootData = FK.Database.FishingBoots[itemID]
            if bootData then
                equipState.totalBonus = equipState.totalBonus + (bootData.bonus or 0)
            end
        end
    end

    -- Add pole bonus to total
    equipState.totalBonus = equipState.totalBonus + equipState.currentPoleBonus

    -- Check for lure (weapon enchant)
    self:ScanLure()

    FK:Debug("Equipment scanned. Pole: " .. tostring(equipState.hasFishingPole) ..
             ", Total Bonus: " .. equipState.totalBonus)
end

function Equip:ScanLure()
    local hasMainHandEnchant, mainHandExpiration = GetWeaponEnchantInfo()

    if hasMainHandEnchant and mainHandExpiration and mainHandExpiration > 0 then
        -- Check if main hand is a fishing pole (independent check)
        local hasPole = equipState.hasFishingPole
        if not hasPole then
            -- Double-check by examining the weapon directly
            local mainHandLink = GetInventoryItemLink("player", SLOT_MAINHAND)
            if mainHandLink then
                local _, _, _, _, _, _, itemSubType = GetItemInfo(mainHandLink)
                if itemSubType and (itemSubType == "Fishing Poles" or itemSubType == "Fishing Pole") then
                    hasPole = true
                    equipState.hasFishingPole = true  -- Update the flag
                end
            end
        end

        if hasPole then
            equipState.hasLure = true
            equipState.lureExpireTime = GetTime() + (mainHandExpiration / 1000)

            -- Estimate lure bonus based on duration
            -- Most lures: 10 min = 100 bonus, 5 min = 75 bonus, etc.
            local durationMins = mainHandExpiration / 60000
            if durationMins > 8 then
                equipState.lureBonus = 100
            elseif durationMins > 5 then
                equipState.lureBonus = 75
            elseif durationMins > 3 then
                equipState.lureBonus = 50
            else
                equipState.lureBonus = 25
            end
        else
            equipState.hasLure = false
            equipState.lureExpireTime = 0
            equipState.lureBonus = 0
        end
    else
        equipState.hasLure = false
        equipState.lureExpireTime = 0
        equipState.lureBonus = 0
    end

    -- Update core state
    FK.State.hasLure = equipState.hasLure
    FK.State.lureExpireTime = equipState.lureExpireTime

    FK:Debug("Lure scanned: " .. tostring(equipState.hasLure) ..
             ", Expires: " .. tostring(equipState.lureExpireTime) ..
             ", Bonus: " .. tostring(equipState.lureBonus))
end

-- ============================================================================
-- Gear Set Management
-- ============================================================================

function Equip:SaveFishingGear()
    if not FK.chardb then return end

    local mainHand = GetInventoryItemLink("player", SLOT_MAINHAND)
    local head = GetInventoryItemLink("player", SLOT_HEAD)
    local hands = GetInventoryItemLink("player", SLOT_HANDS)
    local feet = GetInventoryItemLink("player", SLOT_FEET)
    local offHand = GetInventoryItemLink("player", SLOT_OFFHAND)

    FK.chardb.fishingGear = {
        mainHand = mainHand,
        head = head,
        hands = hands,
        feet = feet,
        offHand = offHand,
    }

    -- Debug output to verify what was saved
    FK:Debug("Fishing gear saved:")
    FK:Debug("  MainHand: " .. (mainHand or "empty"))
    FK:Debug("  OffHand: " .. (offHand or "empty"))
end

function Equip:SaveNormalGear()
    if not FK.chardb then
        FK:Debug("SaveNormalGear: FK.chardb is nil!")
        return
    end

    local mainHand = GetInventoryItemLink("player", SLOT_MAINHAND)
    local head = GetInventoryItemLink("player", SLOT_HEAD)
    local hands = GetInventoryItemLink("player", SLOT_HANDS)
    local feet = GetInventoryItemLink("player", SLOT_FEET)
    local offHand = GetInventoryItemLink("player", SLOT_OFFHAND)

    -- Check if we're about to save fishing gear as normal gear (prevent overwrite)
    if mainHand then
        local itemID = self:GetItemIDFromLink(mainHand)
        if itemID then
            local poleData = FK.Database and FK.Database.FishingPoles and FK.Database.FishingPoles[itemID]
            if poleData then
                FK:Debug("WARNING: Fishing pole equipped - not overwriting normal gear")
                return  -- Don't save fishing gear as normal gear
            end
            -- Also check by subtype
            local _, _, _, _, _, _, itemSubType = GetItemInfo(mainHand)
            if itemSubType and (itemSubType == "Fishing Poles" or itemSubType == "Fishing Pole") then
                FK:Debug("WARNING: Fishing pole equipped (by subtype) - not overwriting normal gear")
                return
            end
        end
    end

    FK.chardb.normalGear = {
        mainHand = mainHand,
        head = head,
        hands = hands,
        feet = feet,
        offHand = offHand,
    }

    -- Debug output to verify what was saved
    FK:Debug("Normal gear saved:")
    FK:Debug("  MainHand: " .. (mainHand or "empty"))
    FK:Debug("  OffHand: " .. (offHand or "empty"))
    FK:Debug("  Head: " .. (head or "empty"))
    FK:Debug("  Hands: " .. (hands or "empty"))
    FK:Debug("  Feet: " .. (feet or "empty"))
end

function Equip:EquipFishingGear()
    if InCombatLockdown() then
        FK:Print("Cannot swap gear during combat.", FK.Colors.error)
        return false
    end

    if not FK.chardb or not FK.chardb.fishingGear then
        FK:Print("No fishing gear saved. Use /fk savegear fishing first.", FK.Colors.warning)
        return false
    end

    -- Check if fishing gear is already equipped
    if equipState.hasFishingPole then
        FK:Print("Fishing gear is already equipped.", FK.Colors.info)
        return true
    end

    -- ALWAYS save current gear as normal gear before swapping to fishing gear
    -- This ensures we can swap back after logout/login
    self:SaveNormalGear()

    local gear = FK.chardb.fishingGear

    -- Equip main hand (fishing pole) first
    if gear.mainHand then
        self:EquipItemByLink(gear.mainHand, SLOT_MAINHAND)
    end

    -- Equip other pieces
    if gear.head then
        self:EquipItemByLink(gear.head, SLOT_HEAD)
    end
    if gear.hands then
        self:EquipItemByLink(gear.hands, SLOT_HANDS)
    end
    if gear.feet then
        self:EquipItemByLink(gear.feet, SLOT_FEET)
    end

    -- Equip offhand with a small delay (main hand must be equipped first)
    -- Note: Most fishing poles don't allow offhand, but some setups might
    if gear.offHand then
        C_Timer.After(0.3, function()
            self:EquipItemByLink(gear.offHand, SLOT_OFFHAND)
        end)
    end

    FK:Print("Fishing gear equipped.", FK.Colors.success)

    -- Rescan equipment
    C_Timer.After(0.5, function()
        self:ScanEquipment()
    end)

    -- Auto-enable Find Fish tracking
    C_Timer.After(0.3, function()
        if FK.Pools and FK.Pools.EnableFindFishTracking then
            FK.Pools:EnableFindFishTracking()
        end
    end)

    return true
end

function Equip:EquipNormalGear()
    if InCombatLockdown() then
        FK:Print("Cannot swap gear during combat.", FK.Colors.error)
        return false
    end

    if not FK.chardb or not FK.chardb.normalGear then
        FK:Print("No normal gear saved. Use /fk savegear normal first.", FK.Colors.warning)
        return false
    end

    local gear = FK.chardb.normalGear

    -- Check if there's actually anything saved
    if not gear.mainHand and not gear.head and not gear.hands and not gear.feet and not gear.offHand then
        FK:Print("Normal gear set is empty. Equip your normal gear and use /fk savegear normal", FK.Colors.warning)
        return false
    end

    FK:Debug("Equipping normal gear...")

    -- Equip main hand first
    if gear.mainHand then
        self:EquipItemByLink(gear.mainHand, SLOT_MAINHAND)
    end

    -- Equip other pieces
    if gear.head then
        self:EquipItemByLink(gear.head, SLOT_HEAD)
    end
    if gear.hands then
        self:EquipItemByLink(gear.hands, SLOT_HANDS)
    end
    if gear.feet then
        self:EquipItemByLink(gear.feet, SLOT_FEET)
    end

    -- Equip offhand with a small delay (main hand must be equipped first)
    if gear.offHand then
        C_Timer.After(0.3, function()
            self:EquipItemByLink(gear.offHand, SLOT_OFFHAND)
            FK:Debug("Equipped offhand: " .. gear.offHand)
        end)
    end

    FK:Print("Normal gear equipped.", FK.Colors.success)

    -- Rescan equipment
    C_Timer.After(0.8, function()
        self:ScanEquipment()
    end)

    -- Restore previous tracking (disable Find Fish)
    C_Timer.After(0.3, function()
        if FK.Pools and FK.Pools.RestorePreviousTracking then
            FK.Pools:RestorePreviousTracking()
        end
    end)

    return true
end

function Equip:EquipItemByLink(itemLink, slot)
    if not itemLink then return true end  -- Nothing to equip

    local itemID = self:GetItemIDFromLink(itemLink)
    if not itemID then
        FK:Debug("Could not get itemID from link: " .. itemLink)
        return false
    end

    -- Check if the item is already equipped in this slot
    local equippedLink = GetInventoryItemLink("player", slot)
    if equippedLink then
        local equippedID = self:GetItemIDFromLink(equippedLink)
        if equippedID and equippedID == itemID then
            FK:Debug("Item already equipped in slot " .. slot .. ": " .. itemLink)
            return true  -- Already wearing the right item
        end
    end

    -- Clear cursor first to avoid conflicts
    ClearCursor()

    -- Find the item in bags
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for bagSlot = 1, numSlots do
            local bagItemLink = GetContainerItemLink(bag, bagSlot)

            if bagItemLink then
                local bagItemID = self:GetItemIDFromLink(bagItemLink)
                if bagItemID == itemID then
                    -- Found the item, equip it using EquipItemByName which is more reliable
                    local itemName = GetItemInfo(itemLink)
                    if itemName then
                        EquipItemByName(itemName, slot)
                        FK:Debug("Equipped: " .. itemName .. " to slot " .. slot)
                        return true
                    else
                        -- Item info not cached, try by bag link
                        itemName = GetItemInfo(bagItemLink)
                        if itemName then
                            EquipItemByName(itemName, slot)
                            FK:Debug("Equipped (via bag): " .. itemName .. " to slot " .. slot)
                            return true
                        end
                        -- Fallback to pickup method
                        PickupContainerItem(bag, bagSlot)
                        EquipCursorItem(slot)
                        FK:Debug("Equipped (via pickup): itemID " .. itemID .. " to slot " .. slot)
                        return true
                    end
                end
            end
        end
    end

    FK:Debug("Item not found in bags (itemID " .. itemID .. "): " .. itemLink)
    return false
end

-- ============================================================================
-- Lure Management
-- ============================================================================

function Equip:GetBestAvailableLure()
    -- Search bags for lures, aggregate counts across all stacks per lure type
    local lureTotals = {}  -- [itemID] = { total count, first bag, first slot, icon }

    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local texture, itemCount = GetContainerItemInfo(bag, slot)
            local itemIcon = texture
            local itemLink = GetContainerItemLink(bag, slot)

            if itemLink then
                local itemID = self:GetItemIDFromLink(itemLink)
                if itemID then
                    local lureData = FK.Database.Lures[itemID]
                    if lureData then
                        if not lureTotals[itemID] then
                            if not itemIcon then
                                local _, _, _, _, _, _, _, _, _, tex = GetItemInfo(itemID)
                                itemIcon = tex
                            end
                            lureTotals[itemID] = {
                                bag = bag,
                                slot = slot,
                                itemID = itemID,
                                name = lureData.name,
                                bonus = lureData.bonus,
                                duration = lureData.duration,
                                count = itemCount or 1,
                                icon = itemIcon,
                            }
                        else
                            lureTotals[itemID].count = lureTotals[itemID].count + (itemCount or 1)
                        end
                    end
                end
            end
        end
    end

    -- Pick the best lure (highest bonus)
    local bestLure = nil
    local bestBonus = 0
    for _, lure in pairs(lureTotals) do
        if lure.bonus > bestBonus then
            bestLure = lure
            bestBonus = lure.bonus
        end
    end

    return bestLure
end

function Equip:ApplyLure(lureBag, lureSlot)
    if InCombatLockdown() then
        FK:Print("Cannot apply lure during combat.", FK.Colors.error)
        return false
    end

    if not equipState.hasFishingPole then
        FK:Print("You need a fishing pole equipped to apply a lure.", FK.Colors.warning)
        return false
    end

    -- Find the best lure
    local bestLure = self:GetBestAvailableLure()
    if not bestLure then
        FK:Print("No lures found in bags.", FK.Colors.warning)
        return false
    end

    -- Due to Blizzard API restrictions, we cannot use items programmatically
    -- The user must click the Lure button in the UI, or use a macro
    FK:Print("Found: " .. FK.Colors.highlight .. bestLure.name .. "|r (+" .. bestLure.bonus .. ")", FK.Colors.info)
    FK:Print("Use the " .. FK.Colors.highlight .. "Lure|r button in the FishingKit panel, or create a macro:", FK.Colors.info)
    print("  /use " .. bestLure.bag .. " " .. bestLure.slot)

    return true
end

function Equip:SuggestLure()
    local zone = FK.State.currentZone
    local zoneData = FK.Database:GetZoneInfo(zone)

    if not zoneData then
        return nil, "Unknown zone"
    end

    local currentSkill = FK.State.fishingSkill + equipState.totalBonus
    local noGetaway = zoneData.noGetaway or 1

    if currentSkill >= noGetaway then
        return nil, "Your skill is sufficient for this zone"
    end

    local skillGap = noGetaway - currentSkill
    local lureID, lureData = FK.Database:GetBestLureForSkillGap(skillGap)

    return {
        itemID = lureID,
        name = lureData.name,
        bonus = lureData.bonus,
        skillGap = skillGap,
    }, "Suggested lure"
end

-- ============================================================================
-- Equipment Info Getters
-- ============================================================================

function Equip:HasFishingPole()
    return equipState.hasFishingPole
end

function Equip:GetTotalBonus()
    return equipState.totalBonus + (equipState.hasLure and equipState.lureBonus or 0)
end

function Equip:GetPoleBonus()
    return equipState.currentPoleBonus
end

function Equip:GetLureInfo()
    -- Always check live status from GetWeaponEnchantInfo for accurate timing
    local hasMainHandEnchant, mainHandExpiration = GetWeaponEnchantInfo()

    if hasMainHandEnchant and mainHandExpiration and mainHandExpiration > 0 then
        -- Check if main hand is a fishing pole
        local hasPole = equipState.hasFishingPole
        if not hasPole then
            -- Double-check by examining the weapon directly
            local mainHandLink = GetInventoryItemLink("player", SLOT_MAINHAND)
            if mainHandLink then
                local _, _, _, _, _, _, itemSubType = GetItemInfo(mainHandLink)
                if itemSubType and (itemSubType == "Fishing Poles" or itemSubType == "Fishing Pole") then
                    hasPole = true
                    equipState.hasFishingPole = true
                end
            end
        end

        if hasPole then
            local expireTime = GetTime() + (mainHandExpiration / 1000)

            -- Get the lure bonus by scanning the fishing pole tooltip
            local lureBonus = self:GetLureBonusFromTooltip()

            -- Update cached state for other functions
            equipState.hasLure = true
            equipState.lureExpireTime = expireTime
            equipState.lureBonus = lureBonus
            FK.State.hasLure = true
            FK.State.lureExpireTime = expireTime

            return true, expireTime, lureBonus
        end
    end

    -- No lure active - reset all state
    equipState.hasLure = false
    equipState.lureExpireTime = 0
    equipState.lureBonus = 0
    FK.State.hasLure = false
    FK.State.lureExpireTime = 0

    return false, 0, 0
end

function Equip:GetEffectiveSkill()
    local baseSkill = FK.State.fishingSkill
    local bonus = self:GetTotalBonus()
    return baseSkill + bonus
end

-- ============================================================================
-- Equipment Changed Handler
-- ============================================================================

function Equip:OnEquipmentChanged(slot)
    -- Re-scan relevant slots
    if slot == SLOT_MAINHAND or slot == SLOT_HEAD or slot == SLOT_HANDS or slot == SLOT_FEET or slot == SLOT_OFFHAND then
        self:ScanEquipment()
    end
end

-- ============================================================================
-- Inventory Scanning
-- ============================================================================

function Equip:GetFishingPolesInBags()
    local poles = {}

    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemLink = GetContainerItemLink(bag, slot)

            if itemLink then
                local itemID = self:GetItemIDFromLink(itemLink)
                if itemID then
                    local poleData = FK.Database.FishingPoles[itemID]
                    if poleData then
                        table.insert(poles, {
                            bag = bag,
                            slot = slot,
                            itemID = itemID,
                            name = poleData.name,
                            bonus = poleData.bonus,
                            link = itemLink,
                        })
                    else
                        -- Check by item subtype
                        local _, _, _, _, _, itemType, itemSubType = GetItemInfo(itemLink)
                        if itemSubType and (itemSubType == "Fishing Poles" or itemSubType == "Fishing Pole") then
                            table.insert(poles, {
                                bag = bag,
                                slot = slot,
                                itemID = itemID,
                                name = itemLink,
                                bonus = 0,
                                link = itemLink,
                            })
                        end
                    end
                end
            end
        end
    end

    -- Sort by bonus
    table.sort(poles, function(a, b) return a.bonus > b.bonus end)

    return poles
end

function Equip:GetLuresInBags()
    local lures = {}

    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local _, itemCount = GetContainerItemInfo(bag, slot)
            local itemLink = GetContainerItemLink(bag, slot)

            if itemLink then
                local itemID = self:GetItemIDFromLink(itemLink)
                if itemID then
                    local lureData = FK.Database.Lures[itemID]
                    if lureData and lureData.duration then  -- Only consumable lures
                        table.insert(lures, {
                            bag = bag,
                            slot = slot,
                            itemID = itemID,
                            name = lureData.name,
                            bonus = lureData.bonus,
                            duration = lureData.duration,
                            count = itemCount or 1,
                        })
                    end
                end
            end
        end
    end

    -- Sort by bonus
    table.sort(lures, function(a, b) return a.bonus > b.bonus end)

    return lures
end

-- ============================================================================
-- Utility Functions
-- ============================================================================

function Equip:GetItemIDFromLink(link)
    if not link then return nil end
    local itemID = string.match(link, "item:(%d+)")
    return itemID and tonumber(itemID) or nil
end

FK:Debug("Equipment module loaded")
