--[[
    FishingKit - TBC Anniversary Edition
    ZoneFish Module — Zone catch-rate panel

    Expandable panel anchored below the main HUD. Shows every fish/item
    caught in the current zone, sorted by catch rate, with count and %.
    Refreshes every 2 seconds while visible.
]]

local ADDON_NAME, FK = ...

FK.ZoneFish = {}
local ZF = FK.ZoneFish

local panel = nil
local rows  = {}    -- pre-created FontString triplets {name, count, rate}
local refreshElapsed = 0

-- Layout constants (match UI.lua)
local FRAME_WIDTH = 290
local PADDING     = 10
local ROW_H       = 18
local MAX_ROWS    = 12

-- Design palette — mirrors UI.lua's D table
local C = {
    bg      = {0.04, 0.04, 0.06},  bgA  = 0.92,
    border  = {0.18, 0.18, 0.23},  borA = 0.80,
    divider = {0.14, 0.14, 0.18},  divA = 0.90,
    accent  = {0.28, 0.74, 0.97},
    label   = {0.40, 0.40, 0.45},
    value   = {0.82, 0.84, 0.88},
    barBg   = {0.07, 0.07, 0.09},
}

-- ============================================================================
-- Panel creation
-- ============================================================================

function ZF:CreatePanel()
    local mainFrame = _G["FishingKitMainFrame"]
    if not mainFrame then
        FK:Debug("ZoneFish: main frame not found")
        return
    end

    local maxH = PADDING + 22 + 4 + MAX_ROWS * ROW_H + PADDING

    panel = CreateFrame("Frame", "FishingKitZoneFishPanel", UIParent,
                        BackdropTemplateMixin and "BackdropTemplate" or nil)
    panel:SetSize(FRAME_WIDTH, maxH)
    panel:SetPoint("TOP", mainFrame, "BOTTOM", 0, 0)
    panel:SetFrameStrata("MEDIUM")
    panel:SetClampedToScreen(true)
    panel:Hide()

    -- Backdrop matching the main frame
    if panel.SetBackdrop then
        panel:SetBackdrop({
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        panel:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], C.bgA)
        panel:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.borA)
    else
        local bg = panel:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(C.bg[1], C.bg[2], C.bg[3], C.bgA)
    end

    -- Header: "Zone Fish  — Zangarmarsh"
    local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", PADDING, -PADDING)
    header:SetText("|cFF47BEF5Zone Fish|r")
    panel.header = header

    -- Divider below header
    local div = panel:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    div:SetPoint("TOPLEFT",  panel, "TOPLEFT",  PADDING, -(PADDING + 18))
    div:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PADDING, -(PADDING + 18))
    div:SetColorTexture(C.divider[1], C.divider[2], C.divider[3], C.divA)

    -- Column headers
    local colTop = -(PADDING + 18 + 2)
    local hdrName = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrName:SetPoint("TOPLEFT", panel, "TOPLEFT", PADDING, colTop)
    hdrName:SetText("Fish")
    hdrName:SetTextColor(C.label[1], C.label[2], C.label[3])

    local hdrCount = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrCount:SetPoint("TOPLEFT", panel, "TOPLEFT", PADDING + 175, colTop)
    hdrCount:SetText("#")
    hdrCount:SetJustifyH("RIGHT")
    hdrCount:SetWidth(30)
    hdrCount:SetTextColor(C.label[1], C.label[2], C.label[3])

    local hdrRate = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrRate:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PADDING, colTop)
    hdrRate:SetText("Rate")
    hdrRate:SetJustifyH("RIGHT")
    hdrRate:SetWidth(40)
    hdrRate:SetTextColor(C.label[1], C.label[2], C.label[3])

    -- Divider below column headers
    local hdrDiv = panel:CreateTexture(nil, "ARTWORK")
    hdrDiv:SetHeight(1)
    hdrDiv:SetPoint("TOPLEFT",  panel, "TOPLEFT",  PADDING, colTop - ROW_H + 2)
    hdrDiv:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PADDING, colTop - ROW_H + 2)
    hdrDiv:SetColorTexture(C.divider[1], C.divider[2], C.divider[3], C.divA * 0.5)

    -- Pre-create MAX_ROWS row FontStrings (reused each refresh, no GC pressure)
    local rowTop = colTop - ROW_H - 2
    for i = 1, MAX_ROWS do
        local y = rowTop - (i - 1) * ROW_H

        local nameFstr = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameFstr:SetPoint("TOPLEFT", panel, "TOPLEFT", PADDING, y)
        nameFstr:SetWidth(170)
        nameFstr:SetJustifyH("LEFT")
        nameFstr:SetText("")

        local countFstr = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        countFstr:SetPoint("TOPLEFT", panel, "TOPLEFT", PADDING + 175, y)
        countFstr:SetJustifyH("RIGHT")
        countFstr:SetWidth(30)
        countFstr:SetText("")
        countFstr:SetTextColor(C.label[1], C.label[2], C.label[3])

        local rateFstr = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rateFstr:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PADDING, y)
        rateFstr:SetJustifyH("RIGHT")
        rateFstr:SetWidth(40)
        rateFstr:SetText("")
        rateFstr:SetTextColor(C.accent[1], C.accent[2], C.accent[3])

        rows[i] = { name = nameFstr, count = countFstr, rate = rateFstr }
    end

    -- Refresh every 2s while visible
    panel:SetScript("OnUpdate", function(self, elapsed)
        refreshElapsed = refreshElapsed + elapsed
        if refreshElapsed >= 2.0 then
            refreshElapsed = 0
            ZF:Refresh()
        end
    end)
end

-- ============================================================================
-- Data query
-- ============================================================================

local function GetZoneFishList()
    local zone = FK.State and FK.State.currentZone
    if not zone or zone == "" then return nil, zone end

    local zs = FK.chardb
               and FK.chardb.stats
               and FK.chardb.stats.zoneStats
               and FK.chardb.stats.zoneStats[zone]
    if not zs or not zs.fish then return nil, zone end

    -- Sum totals to use as denominator (percentages sum to 100%)
    local total = 0
    for _, cnt in pairs(zs.fish) do total = total + cnt end
    if total == 0 then return nil, zone end

    local list = {}
    for itemID, cnt in pairs(zs.fish) do
        local fishData = FK.chardb.stats.fishCaught and FK.chardb.stats.fishCaught[itemID]
        local name = (fishData and fishData.name)
                     or GetItemInfo(itemID)
                     or ("Item " .. itemID)
        table.insert(list, { name = name, count = cnt, rate = cnt / total * 100 })
    end

    table.sort(list, function(a, b) return a.rate > b.rate end)
    return list, zone
end

-- ============================================================================
-- Refresh
-- ============================================================================

function ZF:Refresh()
    if not panel or not panel:IsShown() then return end

    local list, zone = GetZoneFishList()

    -- Update header with zone name
    local zoneName = (zone and zone ~= "") and zone or "Unknown Zone"
    panel.header:SetText("|cFF47BEF5Zone Fish|r  |cFF505058\226\128\148 " .. zoneName .. "|r")

    -- Clear all rows
    for i = 1, MAX_ROWS do
        rows[i].name:SetText("")
        rows[i].count:SetText("")
        rows[i].rate:SetText("")
    end

    if not list or #list == 0 then
        rows[1].name:SetText("|cFF505058No catches recorded here yet.|r")
        self:ResizePanel(1)
        return
    end

    local shown = math.min(#list, MAX_ROWS)
    for i = 1, shown do
        local e = list[i]
        rows[i].name:SetText(e.name)
        rows[i].count:SetText(tostring(e.count))
        rows[i].rate:SetText(string.format("%.1f%%", e.rate))
    end

    self:ResizePanel(shown)
end

function ZF:ResizePanel(numRows)
    -- header (18) + hdrDiv (2) + colHeaders (ROW_H) + hdrDiv2 (2+2) + rows + padding
    local h = PADDING + 18 + 2 + ROW_H + 4 + numRows * ROW_H + PADDING
    panel:SetHeight(h)
end

-- ============================================================================
-- Public API
-- ============================================================================

function ZF:Toggle()
    if not panel then return end
    if panel:IsShown() then
        panel:Hide()
        refreshElapsed = 0
    else
        panel:Show()
        refreshElapsed = 0
        self:Refresh()
    end
end

function ZF:IsShown()
    return panel and panel:IsShown()
end

function ZF:Initialize()
    self:CreatePanel()
    FK:Debug("ZoneFish module initialized")
end

FK:Debug("ZoneFish module loaded")
