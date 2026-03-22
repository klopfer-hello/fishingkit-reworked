--[[
    FishingKit - TBC Anniversary Edition
    DailyQuests Module - Shattrath / Outland fishing daily quest tracker

    Tracks the 5 fishing daily quests offered by Old Man Barlo near Silmyr Lake
    in Terokkar Forest. Only one quest is offered per day; the module checks the
    player's quest log and completion state so the user always knows what to fish.

    Detection:
    - IsQuestComplete(questID)  -- true if today's quest has been turned in
    - QUEST_TURNED_IN event     -- fires on hand-in to update the panel live
    - GetQuestLogTitle(i)       -- used to find the currently offered quest
]]

local ADDON_NAME, FK = ...

FK.DailyQuests = {}
local DQ = FK.DailyQuests

-- The 5 rotating fishing daily quests from Old Man Barlo (Terokkar Forest)
DQ.QUESTS = {
    { id = 10249, name = "Crocolisks in the City",      zone = "SW/Org canals",    fish = "Baby Crocolisk" },
    { id = 10243, name = "Fish Don't Leave Footprints",  zone = "Zangarmarsh",      fish = "Zangarian Sporefish" },
    { id = 10736, name = "Felblood Fillet",              zone = "Hellfire Peninsula", fish = "Monstrous Felblood Snapper" },
    { id = 10237, name = "Shrimpin' Ain't Easy",         zone = "Terokkar Forest",  fish = "Barbed Gill Trout" },
    { id = 10255, name = "The One That Got Away",        zone = "Nagrand",          fish = "10 pound Mud Snapper" },
}

-- Build a lookup set for quick membership testing in QUEST_TURNED_IN
local DAILY_IDS = {}
for _, q in ipairs(DQ.QUESTS) do
    DAILY_IDS[q.id] = true
end

-- Module state
local dqState = {
    frame = nil,
    rows  = {},   -- array of row frames (one per quest)
}

-- ============================================================================
-- Design palette (mirrors Config.lua / UI.lua)
-- ============================================================================

local D = {
    bg      = {0.04, 0.04, 0.06},  bgA   = 0.93,
    border  = {0.18, 0.18, 0.23},  borA  = 0.80,
    divider = {0.14, 0.14, 0.18},  divA  = 0.90,
    accent  = {0.28, 0.74, 0.97},
    label   = {0.40, 0.40, 0.45},
    value   = {0.82, 0.84, 0.88},
    done    = {0.26, 0.76, 0.42},   -- green
    pending = {0.95, 0.64, 0.10},   -- amber
    active  = {0.28, 0.74, 0.97},   -- cyan (in quest log, not yet done)
}

local function AddThinBorder(f, r, g, b, a)
    local t  = f:CreateTexture(nil, "OVERLAY"); t:SetPoint("TOPLEFT");     t:SetPoint("TOPRIGHT");    t:SetHeight(1); t:SetColorTexture(r, g, b, a)
    local bb = f:CreateTexture(nil, "OVERLAY"); bb:SetPoint("BOTTOMLEFT"); bb:SetPoint("BOTTOMRIGHT"); bb:SetHeight(1); bb:SetColorTexture(r, g, b, a)
    local l  = f:CreateTexture(nil, "OVERLAY"); l:SetPoint("TOPLEFT");     l:SetPoint("BOTTOMLEFT");  l:SetWidth(1);  l:SetColorTexture(r, g, b, a)
    local rr = f:CreateTexture(nil, "OVERLAY"); rr:SetPoint("TOPRIGHT");   rr:SetPoint("BOTTOMRIGHT"); rr:SetWidth(1); rr:SetColorTexture(r, g, b, a)
end

-- ============================================================================
-- Quest status helpers
-- ============================================================================

-- Returns "done", "active" (in quest log, not yet turned in), or "pending"
function DQ:GetStatus(questID)
    if IsQuestComplete(questID) then
        return "done"
    end

    -- Check the quest log for the offered quest
    local numEntries = GetNumQuestLogEntries()
    for i = 1, numEntries do
        local _, _, _, _, _, _, _, logID = GetQuestLogTitle(i)
        if logID == questID then
            return "active"
        end
    end

    return "pending"
end

-- Return the quest that is currently in the player's log (if any)
function DQ:GetActiveQuest()
    local numEntries = GetNumQuestLogEntries()
    for i = 1, numEntries do
        local _, _, _, _, _, _, _, logID = GetQuestLogTitle(i)
        if DAILY_IDS[logID] then
            for _, q in ipairs(self.QUESTS) do
                if q.id == logID then
                    return q
                end
            end
        end
    end
    return nil
end

-- ============================================================================
-- Initialization
-- ============================================================================

function DQ:Initialize()
    self:CreateFrame()
    FK:Debug("DailyQuests module initialized")
end

-- ============================================================================
-- Chat status printer
-- ============================================================================

function DQ:PrintStatus()
    FK:Print("Outland Fishing Dailies (Old Man Barlo):", FK.Colors.highlight)
    for _, q in ipairs(self.QUESTS) do
        local status = self:GetStatus(q.id)
        local statusStr
        if status == "done" then
            statusStr = "|cFF00FF00Done|r"
        elseif status == "active" then
            statusStr = "|cFF47BEF5In Progress|r"
        else
            statusStr = "|cFFAAAAAA—|r"
        end
        print("  " .. statusStr .. "  " .. q.name .. " |cFF666666(" .. q.zone .. ")|r")
    end
end

-- ============================================================================
-- Login reminder
-- ============================================================================

function DQ:CheckLoginReminder()
    if not FK.db or not FK.db.settings.dailyQuestReminder then return end

    local active = self:GetActiveQuest()
    if active then
        -- Quest in log, not yet turned in
        FK:Print("Daily fishing quest in progress: " ..
            FK.Colors.highlight .. active.name .. "|r" ..
            " — need " .. FK.Colors.fish .. active.fish .. "|r" ..
            " from " .. FK.Colors.info .. active.zone .. "|r", FK.Colors.info)
    else
        -- No quest in log — remind to pick one up if none completed today
        local anyDone = false
        for _, q in ipairs(self.QUESTS) do
            if self:GetStatus(q.id) == "done" then
                anyDone = true
                break
            end
        end
        if not anyDone then
            FK:Print("Daily fishing quest available — visit Old Man Barlo at Silmyr Lake, Terokkar Forest.", FK.Colors.info)
        end
    end
end

-- ============================================================================
-- QUEST_TURNED_IN handler (called from Core.lua)
-- ============================================================================

function DQ:OnQuestTurnedIn(questID)
    if not DAILY_IDS[questID] then return end

    for _, q in ipairs(self.QUESTS) do
        if q.id == questID then
            FK:Print("Daily fishing quest complete: " ..
                FK.Colors.highlight .. q.name .. "|r! Good job!", FK.Colors.success)
            break
        end
    end

    -- Refresh panel if visible
    if dqState.frame and dqState.frame:IsShown() then
        self:UpdateFrame()
    end
end

-- ============================================================================
-- Panel UI
-- ============================================================================

local FRAME_W  = 320
local PADDING  = 12
local ROW_H    = 30

function DQ:CreateFrame()
    local totalH = PADDING + 20 + 6 + #self.QUESTS * ROW_H + PADDING + 28 + PADDING
    local frame = CreateFrame("Frame", "FishingKitDailyFrame", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(FRAME_W, totalH)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- Backdrop
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        frame:SetBackdropColor(D.bg[1], D.bg[2], D.bg[3], D.bgA)
        frame:SetBackdropBorderColor(D.border[1], D.border[2], D.border[3], D.borA)
    else
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(D.bg[1], D.bg[2], D.bg[3], D.bgA)
    end

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -PADDING)
    title:SetText("|cFF47BEF5FishingKit|r  |cFF66666BFishing Dailies|r")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING + 4, -PADDING + 2)
    local closeX = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    closeX:SetAllPoints(); closeX:SetJustifyH("CENTER")
    closeX:SetText("|cFF66666B\xC3\x97|r")
    closeBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    closeBtn:GetHighlightTexture():SetBlendMode("ADD")
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    closeBtn:SetScript("OnEnter", function() closeX:SetText("|cFFCCCCCC\xC3\x97|r") end)
    closeBtn:SetScript("OnLeave", function() closeX:SetText("|cFF66666B\xC3\x97|r") end)

    -- Divider below title
    local div = frame:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    div:SetPoint("TOPLEFT",  frame, "TOPLEFT",  PADDING, -(PADDING + 20))
    div:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING, -(PADDING + 20))
    div:SetColorTexture(D.divider[1], D.divider[2], D.divider[3], D.divA)

    -- Quest rows
    local rowY = -(PADDING + 26)
    for i, q in ipairs(self.QUESTS) do
        local row = CreateFrame("Frame", nil, frame)
        row:SetSize(FRAME_W - PADDING * 2, ROW_H - 2)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, rowY)

        -- Status dot (colored square)
        local dot = row:CreateTexture(nil, "ARTWORK")
        dot:SetSize(8, 8)
        dot:SetPoint("LEFT", row, "LEFT", 0, 0)
        dot:SetColorTexture(D.label[1], D.label[2], D.label[3], 1)
        row.dot = dot

        -- Quest name
        local nameStr = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameStr:SetPoint("LEFT", dot, "RIGHT", 6, 0)
        nameStr:SetText(q.name)
        nameStr:SetTextColor(D.value[1], D.value[2], D.value[3])
        nameStr:SetJustifyH("LEFT")
        row.nameStr = nameStr

        -- Zone text (right-aligned, dim)
        local zoneStr = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        zoneStr:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        zoneStr:SetText(q.zone)
        zoneStr:SetTextColor(D.label[1], D.label[2], D.label[3])
        zoneStr:SetJustifyH("RIGHT")
        row.zoneStr = zoneStr

        dqState.rows[i] = row
        rowY = rowY - ROW_H
    end

    -- Bottom divider
    local botDiv = frame:CreateTexture(nil, "ARTWORK")
    botDiv:SetHeight(1)
    botDiv:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  PADDING, PADDING + 28)
    botDiv:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PADDING, PADDING + 28)
    botDiv:SetColorTexture(D.divider[1], D.divider[2], D.divider[3], D.divA)

    -- Sub-text: NPC location
    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PADDING, PADDING + 10)
    hint:SetText("|cFF666666Old Man Barlo — Silmyr Lake, Terokkar Forest|r")
    hint:SetJustifyH("LEFT")

    frame:Hide()
    dqState.frame = frame
end

function DQ:UpdateFrame()
    if not dqState.frame then return end

    for i, q in ipairs(self.QUESTS) do
        local row = dqState.rows[i]
        if row then
            local status = self:GetStatus(q.id)
            if status == "done" then
                row.dot:SetColorTexture(D.done[1], D.done[2], D.done[3], 1)
                row.nameStr:SetTextColor(D.done[1], D.done[2], D.done[3])
                row.nameStr:SetText(q.name .. " |cFF666666(Done)|r")
            elseif status == "active" then
                row.dot:SetColorTexture(D.active[1], D.active[2], D.active[3], 1)
                row.nameStr:SetTextColor(D.active[1], D.active[2], D.active[3])
                row.nameStr:SetText(q.name .. " |cFF47BEF5(In Progress)|r")
            else
                row.dot:SetColorTexture(D.label[1], D.label[2], D.label[3], 0.5)
                row.nameStr:SetTextColor(D.label[1], D.label[2], D.label[3])
                row.nameStr:SetText(q.name)
            end
        end
    end
end

function DQ:Show()
    if not dqState.frame then return end
    self:UpdateFrame()
    dqState.frame:Show()
end

function DQ:Hide()
    if dqState.frame then dqState.frame:Hide() end
end

function DQ:Toggle()
    if dqState.frame and dqState.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

FK:Debug("DailyQuests module loaded")
