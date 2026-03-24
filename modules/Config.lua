--[[
    FishingKit - TBC Anniversary Edition
    Config Module - Settings and options panel

    This module creates:
    - Options panel accessible via /fk config
    - Settings for all features
    - Gear set management interface
    - Statistics reset options
]]

local ADDON_NAME, FK = ...

FK.Config = {}
local Config = FK.Config

-- Config state
local configState = {
    frame = nil,
    visible = false,
    currentTab = 1,
}

-- UI Constants
local FRAME_WIDTH   = 400
local FRAME_HEIGHT  = 550
local PADDING       = 14
local ROW_HEIGHT    = 24
local CHECKBOX_SIZE = 22

-- Design palette (mirrors UI.lua)
local CD = {
    bg      = {0.04, 0.04, 0.06},  bgA  = 0.93,
    border  = {0.18, 0.18, 0.23},  borA = 0.80,
    divider = {0.14, 0.14, 0.18},  divA = 0.90,
    accent  = {0.28, 0.74, 0.97},
    label   = {0.40, 0.40, 0.45},
    value   = {0.82, 0.84, 0.88},
    success = {0.26, 0.76, 0.42},
    barBg   = {0.07, 0.07, 0.09},
}

-- Draw a 1 px border around any frame using 4 edge textures
local function AddThinBorder(f, r, g, b, a)
    local t  = f:CreateTexture(nil,"OVERLAY"); t:SetPoint("TOPLEFT");     t:SetPoint("TOPRIGHT");    t:SetHeight(1); t:SetColorTexture(r,g,b,a)
    local bb = f:CreateTexture(nil,"OVERLAY"); bb:SetPoint("BOTTOMLEFT"); bb:SetPoint("BOTTOMRIGHT"); bb:SetHeight(1); bb:SetColorTexture(r,g,b,a)
    local l  = f:CreateTexture(nil,"OVERLAY"); l:SetPoint("TOPLEFT");     l:SetPoint("BOTTOMLEFT");  l:SetWidth(1);  l:SetColorTexture(r,g,b,a)
    local rr = f:CreateTexture(nil,"OVERLAY"); rr:SetPoint("TOPRIGHT");   rr:SetPoint("BOTTOMRIGHT"); rr:SetWidth(1); rr:SetColorTexture(r,g,b,a)
end

-- Section header: dim uppercase label + 1 px separator line
function Config:CreateSectionHeader(parent, text, yOffset)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    lbl:SetText(text)
    lbl:SetTextColor(CD.label[1], CD.label[2], CD.label[3])

    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, yOffset - 14)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset - 14)
    line:SetColorTexture(CD.divider[1], CD.divider[2], CD.divider[3], CD.divA)

    return yOffset - 22
end

-- Flat dark action button (replaces UIPanelButtonTemplate)
function Config:CreateConfigButton(parent, text, width, height)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width or 120, height or 22)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.10, 0.10, 0.13, 1)
    btn.bg = bg

    AddThinBorder(btn, CD.border[1], CD.border[2], CD.border[3], CD.borA)

    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetAllPoints()
    lbl:SetJustifyH("CENTER")
    lbl:SetText(text)
    lbl:SetTextColor(CD.value[1], CD.value[2], CD.value[3])
    btn.label = lbl

    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    btn:GetHighlightTexture():SetBlendMode("ADD")

    return btn
end

-- ============================================================================
-- Initialization
-- ============================================================================

function Config:Initialize()
    self:CreateConfigFrame()
    FK:Debug("Config module initialized")
end

-- ============================================================================
-- Main Config Frame
-- ============================================================================

function Config:CreateConfigFrame()
    local frame = CreateFrame("Frame", "FishingKitConfigFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)

    -- Clean dark backdrop, thin tooltip border
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        frame:SetBackdropColor(CD.bg[1], CD.bg[2], CD.bg[3], CD.bgA)
        frame:SetBackdropBorderColor(CD.border[1], CD.border[2], CD.border[3], CD.borA)
    else
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(CD.bg[1], CD.bg[2], CD.bg[3], CD.bgA)
    end

    -- Title: "FishingKit" accent, "Settings" dim, left-aligned
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -PADDING)
    title:SetText("|cFF47BEF5FishingKit|r  |cFF66666BSettings|r")

    -- Close button (custom small × text button)
    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING + 4, -PADDING + 2)
    local closeX = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    closeX:SetAllPoints()
    closeX:SetJustifyH("CENTER")
    closeX:SetText("|cFF66666B×|r")
    closeBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    closeBtn:GetHighlightTexture():SetBlendMode("ADD")
    closeBtn:SetScript("OnClick", function() Config:Hide() end)
    closeBtn:SetScript("OnEnter", function(self) closeX:SetText("|cFFCCCCCC×|r") end)
    closeBtn:SetScript("OnLeave", function(self) closeX:SetText("|cFF66666B×|r") end)

    -- Title divider
    local titleDiv = frame:CreateTexture(nil, "ARTWORK")
    titleDiv:SetHeight(1)
    titleDiv:SetPoint("TOPLEFT",  frame, "TOPLEFT",  PADDING, -(PADDING + 20))
    titleDiv:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING, -(PADDING + 20))
    titleDiv:SetColorTexture(CD.divider[1], CD.divider[2], CD.divider[3], CD.divA)

    -- Make draggable
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- Custom flat tab buttons
    local tabs = { "General", "Alerts", "Gear", "Pools", "Routes", "Auto", "Stats" }
    local tabButtons = {}
    local tabWidth = (FRAME_WIDTH - PADDING * 2) / #tabs

    for i, tabName in ipairs(tabs) do
        local tabBtn = CreateFrame("Button", nil, frame)
        tabBtn:SetSize(tabWidth, 26)
        if i == 1 then
            tabBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -(PADDING + 24))
        else
            tabBtn:SetPoint("LEFT", tabButtons[i-1], "RIGHT", 0, 0)
        end

        -- Background
        local tbg = tabBtn:CreateTexture(nil, "BACKGROUND")
        tbg:SetAllPoints()
        tbg:SetColorTexture(0.06, 0.06, 0.08, 1)
        tabBtn.bg = tbg

        -- Active accent underline (2px, hidden when inactive)
        local tline = tabBtn:CreateTexture(nil, "OVERLAY")
        tline:SetHeight(2)
        tline:SetPoint("BOTTOMLEFT")
        tline:SetPoint("BOTTOMRIGHT")
        tline:SetColorTexture(CD.accent[1], CD.accent[2], CD.accent[3], 1)
        tline:Hide()
        tabBtn.line = tline

        -- Label
        local tlbl = tabBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tlbl:SetAllPoints()
        tlbl:SetJustifyH("CENTER")
        tlbl:SetText(tabName)
        tlbl:SetTextColor(CD.label[1], CD.label[2], CD.label[3])
        tabBtn.label = tlbl

        tabBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        tabBtn:GetHighlightTexture():SetBlendMode("ADD")

        tabBtn.tabIndex = i
        tabBtn:SetScript("OnClick", function(self)
            Config:SelectTab(self.tabIndex)
        end)
        tabButtons[i] = tabBtn
    end
    frame.tabButtons = tabButtons

    -- Tab row bottom divider
    local tabDiv = frame:CreateTexture(nil, "ARTWORK")
    tabDiv:SetHeight(1)
    tabDiv:SetPoint("TOPLEFT",  tabButtons[1], "BOTTOMLEFT")
    tabDiv:SetPoint("TOPRIGHT", tabButtons[#tabs], "BOTTOMRIGHT")
    tabDiv:SetColorTexture(CD.divider[1], CD.divider[2], CD.divider[3], CD.divA)

    -- Content area (below tab row)
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT",     tabButtons[1], "BOTTOMLEFT", 0, -10)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PADDING, PADDING + 36)
    frame.content = content

    -- Store frame reference BEFORE creating tabs (they need it)
    configState.frame = frame

    -- Create tab panels
    self:CreateGeneralTab(content)
    self:CreateAlertsTab(content)
    self:CreateEquipmentTab(content)
    self:CreatePoolsTab(content)
    self:CreateRoutesTab(content)
    self:CreateAutomationTab(content)
    self:CreateStatisticsTab(content)

    -- Bottom divider
    local botDiv = frame:CreateTexture(nil, "ARTWORK")
    botDiv:SetHeight(1)
    botDiv:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  PADDING, PADDING + 32)
    botDiv:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PADDING, PADDING + 32)
    botDiv:SetColorTexture(CD.divider[1], CD.divider[2], CD.divider[3], CD.divA)

    -- Bottom flat buttons
    local closeBtn2 = self:CreateConfigButton(frame, "Close", 90, 22)
    closeBtn2:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PADDING, PADDING + 6)
    closeBtn2:SetScript("OnClick", function() Config:Hide() end)

    local defaultsBtn = self:CreateConfigButton(frame, "Defaults", 90, 22)
    defaultsBtn:SetPoint("RIGHT", closeBtn2, "LEFT", -8, 0)
    defaultsBtn:SetScript("OnClick", function()
        StaticPopup_Show("FISHINGKIT_RESET_DEFAULTS")
    end)

    frame:Hide()

    -- Select first tab
    self:SelectTab(1)

    -- Register static popup
    StaticPopupDialogs["FISHINGKIT_RESET_DEFAULTS"] = {
        text = "Reset all FishingKit settings to defaults?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            Config:ResetToDefaults()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
end

-- ============================================================================
-- Tab Selection
-- ============================================================================

function Config:SelectTab(tabIndex)
    configState.currentTab = tabIndex
    local frame = configState.frame

    -- Update tab button appearance
    for i, btn in ipairs(frame.tabButtons) do
        if i == tabIndex then
            -- Active: bright text + accent underline + slightly lighter bg
            if btn.label then btn.label:SetTextColor(CD.value[1], CD.value[2], CD.value[3]) end
            if btn.line  then btn.line:Show() end
            if btn.bg    then btn.bg:SetColorTexture(0.10, 0.10, 0.13, 1) end
        else
            -- Inactive: dim text, no underline, dark bg
            if btn.label then btn.label:SetTextColor(CD.label[1], CD.label[2], CD.label[3]) end
            if btn.line  then btn.line:Hide() end
            if btn.bg    then btn.bg:SetColorTexture(0.06, 0.06, 0.08, 1) end
        end
    end

    -- Show/hide panels
    if frame.generalPanel    then frame.generalPanel:SetShown(tabIndex == 1) end
    if frame.alertsPanel     then frame.alertsPanel:SetShown(tabIndex == 2) end
    if frame.equipmentPanel  then frame.equipmentPanel:SetShown(tabIndex == 3) end
    if frame.poolsPanel      then frame.poolsPanel:SetShown(tabIndex == 4) end
    if frame.routesPanel     then frame.routesPanel:SetShown(tabIndex == 5) end
    if frame.automationPanel then frame.automationPanel:SetShown(tabIndex == 6) end
    if frame.statisticsPanel then frame.statisticsPanel:SetShown(tabIndex == 7) end
end

-- ============================================================================
-- General Tab
-- ============================================================================

function Config:CreateGeneralTab(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()

    local yOffset = 0

    -- Enable addon
    local enableCheck = self:CreateCheckbox(panel, "Enable FishingKit", yOffset, function(checked)
        FK.db.settings.enabled = checked
    end, function() return FK.db.settings.enabled end)
    yOffset = yOffset - ROW_HEIGHT

    -- Show UI
    local showUICheck = self:CreateCheckbox(panel, "Show fishing HUD", yOffset, function(checked)
        FK.db.settings.showUI = checked
        if checked then
            FK.UI:Show()
        else
            FK.UI:Hide()
        end
    end, function() return FK.db.settings.showUI end)
    yOffset = yOffset - ROW_HEIGHT

    -- Lock UI
    local lockCheck = self:CreateCheckbox(panel, "Lock UI position", yOffset, function(checked)
        FK.db.settings.locked = checked
    end, function() return FK.db.settings.locked end)
    yOffset = yOffset - ROW_HEIGHT

    -- UI Scale slider
    local scaleSlider = self:CreateSlider(panel, "UI Scale", yOffset, 0.5, 2.0, 0.1, function(value)
        FK.db.settings.scale = value
        FK.UI:SetScale(value)
    end, function() return FK.db.settings.scale end)
    yOffset = yOffset - 50

    -- Minimap button (placeholder)
    local minimapCheck = self:CreateCheckbox(panel, "Show minimap button", yOffset, function(checked)
        FK.db.settings.showMinimap = checked
    end, function() return FK.db.settings.showMinimap end)
    yOffset = yOffset - ROW_HEIGHT

    configState.frame.generalPanel = panel
end

-- ============================================================================
-- Alerts Tab
-- ============================================================================

function Config:CreateAlertsTab(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    panel:Hide()

    local yOffset = 0

    yOffset = self:CreateSectionHeader(panel, "SOUND ALERTS", yOffset)

    -- Enable sounds
    local soundCheck = self:CreateCheckbox(panel, "Enable sound alerts", yOffset, function(checked)
        FK.db.settings.soundEnabled = checked
    end, function() return FK.db.settings.soundEnabled end)
    yOffset = yOffset - ROW_HEIGHT

    -- Pool sound
    local poolSoundCheck = self:CreateCheckbox(panel, "Sound on pool detection", yOffset, function(checked)
        FK.db.settings.poolSound = checked
    end, function() return FK.db.settings.poolSound end)
    yOffset = yOffset - ROW_HEIGHT

    local testBtn = self:CreateConfigButton(panel, "Test Sound", 110, 22)
    testBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, yOffset)
    testBtn:SetScript("OnClick", function()
        if FK.Alerts then FK.Alerts:TestSound() end
    end)
    yOffset = yOffset - 34

    yOffset = self:CreateSectionHeader(panel, "VISUAL ALERTS", yOffset)

    -- Visual alert
    local visualCheck = self:CreateCheckbox(panel, "Show visual alerts", yOffset, function(checked)
        FK.db.settings.visualAlert = checked
    end, function() return FK.db.settings.visualAlert end)
    yOffset = yOffset - ROW_HEIGHT

    -- Screen flash
    local flashCheck = self:CreateCheckbox(panel, "Screen flash on rare catch", yOffset, function(checked)
        FK.db.settings.screenFlash = checked
    end, function() return FK.db.settings.screenFlash end)
    yOffset = yOffset - ROW_HEIGHT

    -- Milestone celebrations
    local milestoneCheck = self:CreateCheckbox(panel, "Milestone celebrations (100, 500, 1000...)", yOffset, function(checked)
        FK.db.settings.milestones = checked
    end, function() return FK.db.settings.milestones end)
    yOffset = yOffset - ROW_HEIGHT

    -- Cycle fish alerts (Nightfin/Sunscale time windows)
    local cycleFishCheck = self:CreateCheckbox(panel, "Cycle fish time window alerts (Nightfin/Sunscale)", yOffset, function(checked)
        FK.db.settings.cycleFishAlerts = checked
    end, function() return FK.db.settings.cycleFishAlerts end)
    yOffset = yOffset - ROW_HEIGHT * 1.5

    yOffset = self:CreateSectionHeader(panel, "ENHANCED SOUND", yOffset)

    -- Enhanced sound
    local enhancedSoundCheck = self:CreateCheckbox(panel, "Enhance sounds while fishing (mute music/ambience, boost SFX)", yOffset, function(checked)
        FK.db.settings.enhancedSound = checked
        if not checked and FK.Alerts then
            FK.Alerts:RestoreFishingSound()
        end
    end, function() return FK.db.settings.enhancedSound end)
    yOffset = yOffset - ROW_HEIGHT

    -- SFX volume level while fishing
    local soundScaleSlider = self:CreateSlider(panel, "SFX volume while fishing", yOffset, 0.1, 1.0, 0.1, function(value)
        FK.db.settings.enhanceSoundScale = value
    end, function() return FK.db.settings.enhanceSoundScale or 1.0 end)
    yOffset = yOffset - 52

    -- Missing lure warning
    local lureWarningCheck = self:CreateCheckbox(panel, "Warn when fishing without a lure", yOffset, function(checked)
        FK.db.settings.missingLureWarning = checked
    end, function() return FK.db.settings.missingLureWarning end)
    yOffset = yOffset - ROW_HEIGHT

    configState.frame.alertsPanel = panel
end

-- ============================================================================
-- Equipment Tab
-- ============================================================================

function Config:CreateEquipmentTab(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    panel:Hide()

    local yOffset = 0

    yOffset = self:CreateSectionHeader(panel, "EQUIPMENT MANAGEMENT", yOffset)

    -- Auto-lure
    local autoLureCheck = self:CreateCheckbox(panel, "Remind to apply lure when missing", yOffset, function(checked)
        FK.db.settings.autoLure = checked
    end, function() return FK.db.settings.autoLure end)
    yOffset = yOffset - ROW_HEIGHT * 1.5

    yOffset = self:CreateSectionHeader(panel, "GEAR SETS", yOffset)

    local saveFishingBtn = self:CreateConfigButton(panel, "Save Fishing Gear", 140, 22)
    saveFishingBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    saveFishingBtn:SetScript("OnClick", function()
        FK.Equipment:SaveFishingGear()
        FK:Print("Fishing gear saved!", FK.Colors.success)
    end)

    local saveNormalBtn = self:CreateConfigButton(panel, "Save Normal Gear", 140, 22)
    saveNormalBtn:SetPoint("LEFT", saveFishingBtn, "RIGHT", 8, 0)
    saveNormalBtn:SetScript("OnClick", function()
        FK.Equipment:SaveNormalGear()
        FK:Print("Normal gear saved!", FK.Colors.success)
    end)
    yOffset = yOffset - 34

    yOffset = self:CreateSectionHeader(panel, "CURRENT STATUS", yOffset)

    local statusText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, yOffset)
    statusText:SetText("Loading...")
    statusText:SetJustifyH("LEFT")
    statusText:SetWidth(FRAME_WIDTH - 40)
    statusText:SetTextColor(CD.value[1], CD.value[2], CD.value[3], 1)
    panel.statusText = statusText

    -- Update status periodically
    panel:SetScript("OnShow", function()
        Config:UpdateEquipmentStatus(panel)
    end)

    configState.frame.equipmentPanel = panel
end

function Config:UpdateEquipmentStatus(panel)
    if not panel.statusText then return end

    local hasPole = FK.Equipment:HasFishingPole()
    local bonus = FK.Equipment:GetTotalBonus()
    local hasLure, lureRemaining = FK.Equipment:GetLureInfo()

    local status = ""
    status = status .. "Fishing Pole: " .. (hasPole and "|cFF00FF00Yes|r" or "|cFFFF0000No|r") .. "\n"
    status = status .. "Equipment Bonus: |cFF00D1FF+" .. bonus .. "|r\n"

    if hasLure then
        status = status .. "Lure Active: |cFF00FF00" .. FK:FormatTime(lureRemaining) .. "|r\n"
    else
        status = status .. "Lure Active: |cFFFF0000None|r\n"
    end

    -- Saved gear sets
    local hasFishingSet = FK.chardb and FK.chardb.fishingGear and FK.chardb.fishingGear.mainHand
    local hasNormalSet = FK.chardb and FK.chardb.normalGear and FK.chardb.normalGear.mainHand

    status = status .. "\nFishing Gear Set: " .. (hasFishingSet and "|cFF00FF00Saved|r" or "|cFFFFFF00Not saved|r")
    status = status .. "\nNormal Gear Set: " .. (hasNormalSet and "|cFF00FF00Saved|r" or "|cFFFFFF00Not saved|r")

    panel.statusText:SetText(status)
end

-- ============================================================================
-- Pools Tab
-- ============================================================================

function Config:CreatePoolsTab(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    panel:Hide()

    local yOffset = 0

    yOffset = self:CreateSectionHeader(panel, "POOL DETECTION", yOffset)

    -- Track pools
    local trackPoolsCheck = self:CreateCheckbox(panel, "Track fishing pools", yOffset, function(checked)
        FK.db.settings.trackPools = checked
    end, function() return FK.db.settings.trackPools end)
    yOffset = yOffset - ROW_HEIGHT

    -- Pool detection sound
    local poolSoundCheck = self:CreateCheckbox(panel, "Sound on pool detection", yOffset, function(checked)
        FK.db.settings.poolSound = checked
    end, function() return FK.db.settings.poolSound end)
    yOffset = yOffset - ROW_HEIGHT

    yOffset = self:CreateSectionHeader(panel, "MAP PINS", yOffset)

    -- Show pool pins on maps
    local showPoolPinsCheck = self:CreateCheckbox(panel, "Show discovered pools on minimap and world map", yOffset, function(checked)
        FK.db.settings.showPoolPins = checked
        if FK.Pools and FK.Pools.RefreshAllPins then
            FK.Pools:RefreshAllPins()
        end
    end, function() return FK.db.settings.showPoolPins end)
    yOffset = yOffset - ROW_HEIGHT

    -- Show community pools
    local showCommunityCheck = self:CreateCheckbox(panel, "Show community (unconfirmed) pool pins", yOffset, function(checked)
        FK.db.settings.showCommunityPools = checked
        if FK.Pools and FK.Pools.RefreshAllPins then
            FK.Pools:RefreshAllPins()
        end
    end, function() return FK.db.settings.showCommunityPools end)
    yOffset = yOffset - ROW_HEIGHT

    yOffset = self:CreateSectionHeader(panel, "POOL DATA", yOffset)

    -- Pool count display
    local poolCountText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    poolCountText:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, yOffset)
    poolCountText:SetText("Loading...")
    poolCountText:SetJustifyH("LEFT")
    poolCountText:SetWidth(FRAME_WIDTH - 40)
    poolCountText:SetTextColor(CD.value[1], CD.value[2], CD.value[3], 1)
    panel.poolCountText = poolCountText
    yOffset = yOffset - 40

    local clearZoneBtn = self:CreateConfigButton(panel, "Clear Zone Pools", 140, 22)
    clearZoneBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    clearZoneBtn:SetScript("OnClick", function()
        if FK.Pools and FK.Pools.ClearZonePoolData then
            FK.Pools:ClearZonePoolData()
            Config:UpdatePoolsDisplay(panel)
        end
    end)

    local clearAllBtn = self:CreateConfigButton(panel, "Clear All Pools", 140, 22)
    clearAllBtn:SetPoint("LEFT", clearZoneBtn, "RIGHT", 8, 0)
    clearAllBtn:SetScript("OnClick", function()
        StaticPopup_Show("FISHINGKIT_CLEAR_POOLS")
    end)

    -- Update on show
    panel:SetScript("OnShow", function()
        Config:UpdatePoolsDisplay(panel)
    end)

    configState.frame.poolsPanel = panel
end

-- ============================================================================
-- Routes Tab
-- ============================================================================

function Config:CreateRoutesTab(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    panel:Hide()

    local yOffset = 0

    yOffset = self:CreateSectionHeader(panel, "POOL ROUTE NAVIGATION", yOffset)

    -- Enable pool navigation
    local poolNavCheck = self:CreateCheckbox(panel, "Enable pool route navigation", yOffset, function(checked)
        FK.db.settings.poolNavEnabled = checked
        if not checked and FK.Navigation and FK.Navigation:IsActive() then
            FK.Navigation:StopRoute()
        end
    end, function() return FK.db.settings.poolNavEnabled end)
    yOffset = yOffset - ROW_HEIGHT

    -- Show navigation arrow
    local navArrowCheck = self:CreateCheckbox(panel, "Show navigation arrow", yOffset, function(checked)
        FK.db.settings.poolNavArrow = checked
    end, function() return FK.db.settings.poolNavArrow end)
    yOffset = yOffset - ROW_HEIGHT

    -- Show route on world map
    local navWorldMapCheck = self:CreateCheckbox(panel, "Show route on world map", yOffset, function(checked)
        FK.db.settings.poolNavWorldMapRoute = checked
    end, function() return FK.db.settings.poolNavWorldMapRoute end)
    yOffset = yOffset - ROW_HEIGHT

    -- Waypoint arrival sound
    local navSoundCheck = self:CreateCheckbox(panel, "Waypoint arrival sound", yOffset, function(checked)
        FK.db.settings.poolNavSound = checked
    end, function() return FK.db.settings.poolNavSound end)
    yOffset = yOffset - ROW_HEIGHT

    -- Arrival distance slider
    local arrivalSlider = self:CreateSlider(panel, "Arrival Distance (yards)", yOffset, 10, 40, 5, function(value)
        FK.db.settings.poolNavArrivalDistance = value
    end, function() return FK.db.settings.poolNavArrivalDistance end)
    yOffset = yOffset - 50

    yOffset = self:CreateSectionHeader(panel, "ROUTE ACTIONS", yOffset)

    -- Navigation action buttons
    local startStopBtn = self:CreateConfigButton(panel, "Start Route", 110, 22)
    startStopBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    startStopBtn:SetScript("OnClick", function(self)
        if FK.Navigation then
            FK.Navigation:ToggleRoute()
            self:SetText(FK.Navigation:IsActive() and "Stop Route" or "Start Route")
        end
    end)
    panel.startStopBtn = startStopBtn

    local skipBtn = self:CreateConfigButton(panel, "Skip Waypoint", 110, 22)
    skipBtn:SetPoint("LEFT", startStopBtn, "RIGHT", 6, 0)
    skipBtn:SetScript("OnClick", function()
        if FK.Navigation then
            FK.Navigation:SkipWaypoint()
        end
    end)

    local recalcBtn = self:CreateConfigButton(panel, "Recalculate", 110, 22)
    recalcBtn:SetPoint("LEFT", skipBtn, "RIGHT", 6, 0)
    recalcBtn:SetScript("OnClick", function()
        if FK.Navigation then
            FK.Navigation:RecalculateFromNearest()
        end
    end)
    yOffset = yOffset - 32

    -- Import GatherMate2 button
    local importBtn = self:CreateConfigButton(panel, "Import GatherMate2 Data", 200, 22)
    importBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    importBtn:SetScript("OnClick", function()
        if FK.Navigation then
            FK.Navigation:ImportFromGatherMate2()
        end
    end)

    -- Update on show
    panel:SetScript("OnShow", function()
        if panel.startStopBtn and FK.Navigation then
            panel.startStopBtn:SetText(FK.Navigation:IsActive() and "Stop Route" or "Start Route")
        end
    end)

    configState.frame.routesPanel = panel
end

-- ============================================================================
-- Automation Tab
-- ============================================================================

function Config:CreateAutomationTab(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    panel:Hide()

    local yOffset = 0

    yOffset = self:CreateSectionHeader(panel, "CASTING", yOffset)

    local doubleClickCheck = self:CreateCheckbox(panel, "Double-right-click to cast", yOffset, function(checked)
        FK.db.settings.doubleClickCast = checked
    end, function() return FK.db.settings.doubleClickCast end)
    yOffset = yOffset - ROW_HEIGHT * 1.5

    yOffset = self:CreateSectionHeader(panel, "GEAR", yOffset)

    local autoEquipCheck = self:CreateCheckbox(panel, "Auto-save normal gear when equipping fishing gear", yOffset, function(checked)
        FK.db.settings.autoEquip = checked
    end, function() return FK.db.settings.autoEquip end)
    yOffset = yOffset - ROW_HEIGHT

    local autoCombatCheck = self:CreateCheckbox(panel, "Auto swap weapons in combat, restore pole after", yOffset, function(checked)
        FK.db.settings.autoCombatSwap = checked
    end, function() return FK.db.settings.autoCombatSwap end)
    yOffset = yOffset - ROW_HEIGHT * 1.5

    yOffset = self:CreateSectionHeader(panel, "LURE", yOffset)

    local autoLureReapplyCheck = self:CreateCheckbox(panel, "Auto-reapply best lure after each catch (when missing/expired)", yOffset, function(checked)
        FK.db.settings.autoLureReapply = checked
    end, function() return FK.db.settings.autoLureReapply end)
    yOffset = yOffset - ROW_HEIGHT * 1.5

    yOffset = self:CreateSectionHeader(panel, "LOOT", yOffset)

    local autoOpenCheck = self:CreateCheckbox(panel, "Auto-open crates and scroll cases after fishing", yOffset, function(checked)
        FK.db.settings.autoOpenContainers = checked
    end, function() return FK.db.settings.autoOpenContainers end)
    yOffset = yOffset - ROW_HEIGHT * 1.5

    yOffset = self:CreateSectionHeader(panel, "TRACKING", yOffset)

    local autoFindFishCheck = self:CreateCheckbox(panel, "Auto-enable Find Fish when equipping fishing gear", yOffset, function(checked)
        FK.db.settings.autoFindFish = checked
    end, function() return FK.db.settings.autoFindFish end)
    yOffset = yOffset - ROW_HEIGHT * 1.5

    configState.frame.automationPanel = panel
end

function Config:UpdatePoolsDisplay(panel)
    if not panel.poolCountText then return end

    local totalPools = 0
    local totalZones = 0
    if FK.db and FK.db.poolLocations then
        for mapID, pools in pairs(FK.db.poolLocations) do
            if #pools > 0 then
                totalZones = totalZones + 1
                totalPools = totalPools + #pools
            end
        end
    end

    local text = "Discovered Pools: |cFFFFFFFF" .. totalPools .. "|r across |cFFFFFFFF" .. totalZones .. "|r zone(s)"

    -- Show current zone pool count
    local uiMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if uiMapID and FK.db and FK.db.poolLocations and FK.db.poolLocations[uiMapID] then
        local zoneCount = #FK.db.poolLocations[uiMapID]
        text = text .. "\nCurrent Zone: |cFFFFFFFF" .. zoneCount .. "|r pool(s)"
    end

    panel.poolCountText:SetText(text)
end

-- ============================================================================
-- Statistics Tab
-- ============================================================================

function Config:CreateStatisticsTab(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    panel:Hide()

    local yOffset = 0

    yOffset = self:CreateSectionHeader(panel, "STATISTICS TRACKING", yOffset)

    -- Track stats
    local trackStatsCheck = self:CreateCheckbox(panel, "Track fishing statistics", yOffset, function(checked)
        FK.db.settings.trackStats = checked
    end, function() return FK.db.settings.trackStats end)
    yOffset = yOffset - ROW_HEIGHT

    -- Track loot
    local trackLootCheck = self:CreateCheckbox(panel, "Track loot history", yOffset, function(checked)
        FK.db.settings.trackLoot = checked
    end, function() return FK.db.settings.trackLoot end)
    yOffset = yOffset - ROW_HEIGHT * 1.5

    yOffset = self:CreateSectionHeader(panel, "ALL-TIME STATISTICS", yOffset)

    local statsText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsText:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, yOffset)
    statsText:SetText("Loading...")
    statsText:SetJustifyH("LEFT")
    statsText:SetWidth(FRAME_WIDTH - 40)
    statsText:SetTextColor(CD.value[1], CD.value[2], CD.value[3], 1)
    panel.statsText = statsText
    yOffset = yOffset - 80

    yOffset = self:CreateSectionHeader(panel, "RESET OPTIONS", yOffset)

    -- Reset session
    local resetSessionBtn = self:CreateConfigButton(panel, "Reset Session", 130, 22)
    resetSessionBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    resetSessionBtn:SetScript("OnClick", function()
        if FK.Statistics then
            FK.Statistics:ResetSession()
            Config:UpdateStatisticsDisplay(panel)
        end
    end)

    -- Reset all stats
    local resetAllBtn = self:CreateConfigButton(panel, "Reset All Stats", 130, 22)
    resetAllBtn:SetPoint("LEFT", resetSessionBtn, "RIGHT", 8, 0)
    resetAllBtn:SetScript("OnClick", function()
        StaticPopup_Show("FISHINGKIT_RESET_STATS")
    end)

    -- Register popup
    StaticPopupDialogs["FISHINGKIT_RESET_STATS"] = {
        text = "Reset all fishing statistics? This cannot be undone.",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            if FK.Statistics then
                FK.Statistics:ResetStats()
                Config:UpdateStatisticsDisplay(panel)
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    -- Update on show
    panel:SetScript("OnShow", function()
        Config:UpdateStatisticsDisplay(panel)
    end)

    configState.frame.statisticsPanel = panel
end

function Config:UpdateStatisticsDisplay(panel)
    if not panel.statsText then return end
    if not FK.Statistics then return end

    local total = FK.Statistics:GetTotalStats()

    local stats = ""
    stats = stats .. "Total Casts: |cFFFFFFFF" .. FK:FormatNumber(total.totalCasts) .. "|r\n"
    stats = stats .. "Total Catches: |cFFFFFFFF" .. FK:FormatNumber(total.totalCatches) .. "|r\n"
    stats = stats .. "Success Rate: |cFFFFFFFF" .. string.format("%.1f%%", total.successRate) .. "|r\n"
    stats = stats .. "Unique Fish: |cFFFFFFFF" .. total.uniqueFish .. "|r\n"
    stats = stats .. "Skill Ups: |cFFFFFFFF" .. total.skillUps .. "|r"

    panel.statsText:SetText(stats)
end

-- ============================================================================
-- UI Component Helpers
-- ============================================================================

function Config:CreateCheckbox(parent, label, yOffset, onChange, getValue)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(FRAME_WIDTH - PADDING * 2, CHECKBOX_SIZE)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)

    -- Custom 14×14 checkbox square
    local box = CreateFrame("Button", nil, container)
    box:SetSize(14, 14)
    box:SetPoint("LEFT", container, "LEFT", 0, 0)

    local boxBg = box:CreateTexture(nil, "BACKGROUND")
    boxBg:SetAllPoints()
    boxBg:SetColorTexture(CD.barBg[1], CD.barBg[2], CD.barBg[3], 1)

    AddThinBorder(box, CD.border[1], CD.border[2], CD.border[3], 0.85)

    -- Accent fill when checked
    local fill = box:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT",     2, -2)
    fill:SetPoint("BOTTOMRIGHT", -2, 2)
    fill:SetColorTexture(CD.accent[1], CD.accent[2], CD.accent[3], 1)
    fill:Hide()

    box:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    box:GetHighlightTexture():SetBlendMode("ADD")

    -- Label text
    local txt = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txt:SetPoint("LEFT", box, "RIGHT", 8, 0)
    txt:SetText(label)
    txt:SetTextColor(CD.value[1], CD.value[2], CD.value[3])

    -- State tracking (closure)
    local isChecked = false
    local function setChecked(val)
        isChecked = not not val
        if isChecked then fill:Show() else fill:Hide() end
    end

    box:SetScript("OnClick", function()
        setChecked(not isChecked)
        if onChange then onChange(isChecked) end
    end)

    container:SetScript("OnShow", function()
        if getValue then setChecked(getValue()) end
    end)

    return container
end

function Config:CreateSlider(parent, label, yOffset, minVal, maxVal, step, onChange, getValue)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(FRAME_WIDTH - PADDING * 2, 38)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)

    -- Label (dim, left)
    local txt = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txt:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    txt:SetText(label)
    txt:SetTextColor(CD.label[1], CD.label[2], CD.label[3])

    -- Value readout (bright, right)
    local valTxt = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valTxt:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
    valTxt:SetJustifyH("RIGHT")
    valTxt:SetTextColor(CD.value[1], CD.value[2], CD.value[3])
    valTxt:SetText(string.format("%.1f", getValue and getValue() or minVal))

    -- Track background (full width, thin)
    local trackBg = container:CreateTexture(nil, "BACKGROUND")
    trackBg:SetPoint("TOPLEFT",  txt, "BOTTOMLEFT",  0, -8)
    trackBg:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, -8)
    trackBg:SetHeight(4)
    trackBg:SetColorTexture(CD.barBg[1], CD.barBg[2], CD.barBg[3], 1)

    -- Accent fill
    local trackFill = container:CreateTexture(nil, "ARTWORK")
    trackFill:SetPoint("TOPLEFT", trackBg, "TOPLEFT", 0, 0)
    trackFill:SetHeight(4)
    trackFill:SetWidth(1)
    trackFill:SetColorTexture(CD.accent[1], CD.accent[2], CD.accent[3], 1)

    -- Thumb (small vertical bar at current position)
    local thumb = container:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(3, 10)
    thumb:SetColorTexture(CD.value[1], CD.value[2], CD.value[3], 0.9)
    thumb:SetPoint("LEFT", trackBg, "LEFT", 0, 0)

    -- Invisible native Slider for mouse input (sits over the track)
    local slider = CreateFrame("Slider", nil, container)
    slider:SetPoint("TOPLEFT",     trackBg, "TOPLEFT",     0,  6)
    slider:SetPoint("BOTTOMRIGHT", trackBg, "BOTTOMRIGHT", 0, -6)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:EnableMouse(true)

    local function updateVisuals(value)
        valTxt:SetText(string.format("%.1f", value))
        local w = trackBg:GetWidth()
        if w and w > 1 then
            local pct = (value - minVal) / math.max(1, maxVal - minVal)
            local fw = math.max(1, w * pct)
            trackFill:SetWidth(fw)
            thumb:ClearAllPoints()
            thumb:SetPoint("LEFT", trackBg, "LEFT", math.max(0, fw - 1), 0)
        end
    end

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        updateVisuals(value)
        if onChange then onChange(value) end
    end)

    container:SetScript("OnShow", function()
        if getValue then
            local v = getValue()
            slider:SetValue(v)
            updateVisuals(v)
        end
    end)

    return container
end

-- ============================================================================
-- Reset to Defaults
-- ============================================================================

function Config:ResetToDefaults()
    -- Reset settings
    FK.db.settings = {
        enabled = true,
        showUI = true,
        locked = false,
        scale = 1.0,
        showMinimap = true,
        collapsed = false,
        soundEnabled = true,
        soundVolume = 1.0,
        visualAlert = true,
        screenFlash = false,
        trackPools = true,
        poolSound = true,
        showPoolPins = true,
        showCommunityPools = true,
        autoFindFish = true,
        autoEquip = false,
        autoLure = false,
        autoCombatSwap = true,
        autoOpenContainers = true,
        doubleClickCast = true,
        enhancedSound = true,
        enhanceSoundScale = 1.0,
        missingLureWarning = true,
        missingLureInterval = 60,
        milestones = true,
        poolNavEnabled = true,
        poolNavArrow = true,
        poolNavWorldMapRoute = true,
        poolNavArrivalDistance = 20,
        poolNavSound = true,
        arrowPosition = nil,
        trackStats = true,
        trackLoot = true,
        position = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 200,
        },
    }

    -- Reset UI
    FK.UI:ResetPosition()
    FK.UI:SetScale(1.0)

    FK:Print("Settings reset to defaults.", FK.Colors.success)

    -- Refresh config panels
    self:SelectTab(configState.currentTab)
end

-- ============================================================================
-- Visibility
-- ============================================================================

function Config:Show()
    if configState.frame then
        configState.frame:Show()
        configState.visible = true
        self:SelectTab(1)
    end
end

function Config:Hide()
    if configState.frame then
        configState.frame:Hide()
        configState.visible = false
    end
end

function Config:Toggle()
    if configState.visible then
        self:Hide()
    else
        self:Show()
    end
end

FK:Debug("Config module loaded")
