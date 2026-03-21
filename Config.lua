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
local FRAME_WIDTH = 400
local FRAME_HEIGHT = 550
local PADDING = 12
local ROW_HEIGHT = 28
local CHECKBOX_SIZE = 24

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

    -- Backdrop
    local backdropInfo = {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 }
    }

    if frame.SetBackdrop then
        frame:SetBackdrop(backdropInfo)
        frame:SetBackdropColor(0, 0, 0, 0.95)
    end

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -16)
    title:SetText("|cFF00D1FFFishingKit|r Options")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function()
        Config:Hide()
    end)

    -- Make draggable
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- Tab buttons
    local tabs = { "General", "Alerts", "Gear", "Pools", "Routes", "Stats" }
    local tabButtons = {}
    local tabWidth = (FRAME_WIDTH - PADDING * 2 - 8) / #tabs

    for i, tabName in ipairs(tabs) do
        local tabBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        tabBtn:SetSize(tabWidth, 24)
        if i == 1 then
            tabBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -44)
        else
            tabBtn:SetPoint("LEFT", tabButtons[i-1], "RIGHT", 2, 0)
        end
        tabBtn:SetText(tabName)
        tabBtn.tabIndex = i
        tabBtn:SetScript("OnClick", function(self)
            Config:SelectTab(self.tabIndex)
        end)
        tabButtons[i] = tabBtn
    end
    frame.tabButtons = tabButtons

    -- Content area
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", tabButtons[1], "BOTTOMLEFT", 0, -8)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PADDING, PADDING + 30)
    frame.content = content

    -- Store frame reference BEFORE creating tabs (they need it)
    configState.frame = frame

    -- Create tab panels
    self:CreateGeneralTab(content)
    self:CreateAlertsTab(content)
    self:CreateEquipmentTab(content)
    self:CreatePoolsTab(content)
    self:CreateRoutesTab(content)
    self:CreateStatisticsTab(content)

    -- Bottom buttons
    local saveBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    saveBtn:SetSize(100, 24)
    saveBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PADDING, PADDING)
    saveBtn:SetText("Close")
    saveBtn:SetScript("OnClick", function()
        Config:Hide()
    end)

    local resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetBtn:SetSize(100, 24)
    resetBtn:SetPoint("RIGHT", saveBtn, "LEFT", -8, 0)
    resetBtn:SetText("Defaults")
    resetBtn:SetScript("OnClick", function()
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

    -- Update button appearance
    for i, btn in ipairs(frame.tabButtons) do
        if i == tabIndex then
            btn:SetNormalFontObject("GameFontHighlight")
        else
            btn:SetNormalFontObject("GameFontNormal")
        end
    end

    -- Show/hide panels
    if frame.generalPanel then frame.generalPanel:SetShown(tabIndex == 1) end
    if frame.alertsPanel then frame.alertsPanel:SetShown(tabIndex == 2) end
    if frame.equipmentPanel then frame.equipmentPanel:SetShown(tabIndex == 3) end
    if frame.poolsPanel then frame.poolsPanel:SetShown(tabIndex == 4) end
    if frame.routesPanel then frame.routesPanel:SetShown(tabIndex == 5) end
    if frame.statisticsPanel then frame.statisticsPanel:SetShown(tabIndex == 6) end
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

    -- Double-right-click casting
    local doubleClickCheck = self:CreateCheckbox(panel, "Double-right-click to cast", yOffset, function(checked)
        FK.db.settings.doubleClickCast = checked
    end, function() return FK.db.settings.doubleClickCast end)
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

    -- Sound header
    local soundHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    soundHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    soundHeader:SetText("Sound Alerts")
    soundHeader:SetTextColor(1.0, 0.82, 0.0)
    yOffset = yOffset - 24

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

    -- Test sound button
    local testBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testBtn:SetSize(120, 24)
    testBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, yOffset)
    testBtn:SetText("Test Sound")
    testBtn:SetScript("OnClick", function()
        if FK.Alerts then
            FK.Alerts:TestSound()
        end
    end)
    yOffset = yOffset - 40

    -- Visual header
    local visualHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    visualHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    visualHeader:SetText("Visual Alerts")
    visualHeader:SetTextColor(1.0, 0.82, 0.0)
    yOffset = yOffset - 24

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

    -- Enhanced Sound header
    local enhancedHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enhancedHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    enhancedHeader:SetText("Enhanced Fishing Sound")
    enhancedHeader:SetTextColor(1.0, 0.82, 0.0)
    yOffset = yOffset - 24

    -- Enhanced sound
    local enhancedSoundCheck = self:CreateCheckbox(panel, "Boost splash sound while fishing", yOffset, function(checked)
        FK.db.settings.enhancedSound = checked
        if not checked and FK.Alerts then
            FK.Alerts:RestoreFishingSound()
        end
    end, function() return FK.db.settings.enhancedSound end)
    yOffset = yOffset - ROW_HEIGHT

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

    -- Auto-equip settings
    local equipHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    equipHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    equipHeader:SetText("Equipment Management")
    equipHeader:SetTextColor(1.0, 0.82, 0.0)
    yOffset = yOffset - 24

    -- Auto-equip
    local autoEquipCheck = self:CreateCheckbox(panel, "Auto-save normal gear when equipping fishing gear", yOffset, function(checked)
        FK.db.settings.autoEquip = checked
    end, function() return FK.db.settings.autoEquip end)
    yOffset = yOffset - ROW_HEIGHT

    -- Auto-lure
    local autoLureCheck = self:CreateCheckbox(panel, "Remind to apply lure when missing", yOffset, function(checked)
        FK.db.settings.autoLure = checked
    end, function() return FK.db.settings.autoLure end)
    yOffset = yOffset - ROW_HEIGHT

    -- Auto-combat swap
    local autoCombatCheck = self:CreateCheckbox(panel, "Re-equip fishing gear after combat", yOffset, function(checked)
        FK.db.settings.autoCombatSwap = checked
    end, function() return FK.db.settings.autoCombatSwap end)
    yOffset = yOffset - ROW_HEIGHT * 1.5

    -- Gear set buttons
    local gearHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gearHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    gearHeader:SetText("Gear Sets")
    gearHeader:SetTextColor(1.0, 0.82, 0.0)
    yOffset = yOffset - 24

    -- Save fishing gear
    local saveFishingBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    saveFishingBtn:SetSize(150, 24)
    saveFishingBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, yOffset)
    saveFishingBtn:SetText("Save Fishing Gear")
    saveFishingBtn:SetScript("OnClick", function()
        FK.Equipment:SaveFishingGear()
        FK:Print("Fishing gear saved!", FK.Colors.success)
    end)

    -- Save normal gear
    local saveNormalBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    saveNormalBtn:SetSize(150, 24)
    saveNormalBtn:SetPoint("LEFT", saveFishingBtn, "RIGHT", 10, 0)
    saveNormalBtn:SetText("Save Normal Gear")
    saveNormalBtn:SetScript("OnClick", function()
        FK.Equipment:SaveNormalGear()
        FK:Print("Normal gear saved!", FK.Colors.success)
    end)
    yOffset = yOffset - 40

    -- Current gear status
    local statusHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    statusHeader:SetText("Current Status")
    statusHeader:SetTextColor(1.0, 0.82, 0.0)
    yOffset = yOffset - 24

    local statusText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    statusText:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, yOffset)
    statusText:SetText("Loading...")
    statusText:SetJustifyH("LEFT")
    statusText:SetWidth(FRAME_WIDTH - 40)
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

    -- Pool Detection header
    local detectHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    detectHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    detectHeader:SetText("Pool Detection")
    detectHeader:SetTextColor(1.0, 0.82, 0.0)
    yOffset = yOffset - 24

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

    -- Map Pins header
    local pinsHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pinsHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    pinsHeader:SetText("Map Pins")
    pinsHeader:SetTextColor(1.0, 0.82, 0.0)
    yOffset = yOffset - 24

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

    -- Find Fish header
    local findFishHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    findFishHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    findFishHeader:SetText("Find Fish Tracking")
    findFishHeader:SetTextColor(1.0, 0.82, 0.0)
    yOffset = yOffset - 24

    -- Auto Find Fish
    local autoFindFishCheck = self:CreateCheckbox(panel, "Auto-enable Find Fish when equipping fishing gear", yOffset, function(checked)
        FK.db.settings.autoFindFish = checked
    end, function() return FK.db.settings.autoFindFish end)
    yOffset = yOffset - ROW_HEIGHT

    -- Pool Data header
    local dataHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dataHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    dataHeader:SetText("Pool Data")
    dataHeader:SetTextColor(1.0, 0.82, 0.0)
    yOffset = yOffset - 24

    -- Pool count display
    local poolCountText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    poolCountText:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, yOffset)
    poolCountText:SetText("Loading...")
    poolCountText:SetJustifyH("LEFT")
    poolCountText:SetWidth(FRAME_WIDTH - 40)
    panel.poolCountText = poolCountText
    yOffset = yOffset - 40

    -- Clear zone pool data
    local clearZoneBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    clearZoneBtn:SetSize(150, 24)
    clearZoneBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, yOffset)
    clearZoneBtn:SetText("Clear Zone Pools")
    clearZoneBtn:SetScript("OnClick", function()
        if FK.Pools and FK.Pools.ClearZonePoolData then
            FK.Pools:ClearZonePoolData()
            Config:UpdatePoolsDisplay(panel)
        end
    end)

    -- Clear all pool data
    local clearAllBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    clearAllBtn:SetSize(150, 24)
    clearAllBtn:SetPoint("LEFT", clearZoneBtn, "RIGHT", 10, 0)
    clearAllBtn:SetText("Clear All Pools")
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

    -- Navigation header
    local navHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    navHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    navHeader:SetText("Pool Route Navigation")
    navHeader:SetTextColor(1.0, 0.82, 0.0)
    yOffset = yOffset - 24

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

    -- Action buttons header
    local actionsHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    actionsHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    actionsHeader:SetText("Route Actions")
    actionsHeader:SetTextColor(1.0, 0.82, 0.0)
    yOffset = yOffset - 24

    -- Navigation action buttons
    local startStopBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    startStopBtn:SetSize(110, 24)
    startStopBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, yOffset)
    startStopBtn:SetText("Start Route")
    startStopBtn:SetScript("OnClick", function(self)
        if FK.Navigation then
            FK.Navigation:ToggleRoute()
            self:SetText(FK.Navigation:IsActive() and "Stop Route" or "Start Route")
        end
    end)
    panel.startStopBtn = startStopBtn

    local skipBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    skipBtn:SetSize(110, 24)
    skipBtn:SetPoint("LEFT", startStopBtn, "RIGHT", 6, 0)
    skipBtn:SetText("Skip Waypoint")
    skipBtn:SetScript("OnClick", function()
        if FK.Navigation then
            FK.Navigation:SkipWaypoint()
        end
    end)

    local recalcBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    recalcBtn:SetSize(110, 24)
    recalcBtn:SetPoint("LEFT", skipBtn, "RIGHT", 6, 0)
    recalcBtn:SetText("Recalculate")
    recalcBtn:SetScript("OnClick", function()
        if FK.Navigation then
            FK.Navigation:RecalculateFromNearest()
        end
    end)
    yOffset = yOffset - 34

    -- Import GatherMate2 button
    local importBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    importBtn:SetSize(180, 24)
    importBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, yOffset)
    importBtn:SetText("Import GatherMate2 Data")
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

    -- Tracking settings
    local trackHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    trackHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    trackHeader:SetText("Statistics Tracking")
    trackHeader:SetTextColor(1.0, 0.82, 0.0)
    yOffset = yOffset - 24

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

    -- Statistics display
    local statsHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statsHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    statsHeader:SetText("All-Time Statistics")
    statsHeader:SetTextColor(1.0, 0.82, 0.0)
    yOffset = yOffset - 24

    local statsText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    statsText:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, yOffset)
    statsText:SetText("Loading...")
    statsText:SetJustifyH("LEFT")
    statsText:SetWidth(FRAME_WIDTH - 40)
    panel.statsText = statsText
    yOffset = yOffset - 80

    -- Reset buttons
    local resetHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    resetHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    resetHeader:SetText("Reset Options")
    resetHeader:SetTextColor(1.0, 0.82, 0.0)
    yOffset = yOffset - 24

    -- Reset session
    local resetSessionBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetSessionBtn:SetSize(120, 24)
    resetSessionBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, yOffset)
    resetSessionBtn:SetText("Reset Session")
    resetSessionBtn:SetScript("OnClick", function()
        if FK.Statistics then
            FK.Statistics:ResetSession()
            Config:UpdateStatisticsDisplay(panel)
        end
    end)

    -- Reset all stats
    local resetAllBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetAllBtn:SetSize(120, 24)
    resetAllBtn:SetPoint("LEFT", resetSessionBtn, "RIGHT", 10, 0)
    resetAllBtn:SetText("Reset All Stats")
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

    local checkbox = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
    checkbox:SetPoint("LEFT", container, "LEFT", 0, 0)

    if checkbox.text then
        checkbox.text:SetText(label)
        checkbox.text:SetFontObject("GameFontNormal")
    else
        local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
        text:SetText(label)
    end

    checkbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        if onChange then onChange(checked) end
    end)

    -- Update on show
    container:SetScript("OnShow", function()
        if getValue then
            checkbox:SetChecked(getValue())
        end
    end)

    return container
end

function Config:CreateSlider(parent, label, yOffset, minVal, maxVal, step, onChange, getValue)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(FRAME_WIDTH - PADDING * 2, 44)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)

    local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    text:SetText(label)

    local slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -4)
    slider:SetSize(200, 16)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    local valueText = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueText:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    valueText:SetText(tostring(getValue and getValue() or minVal))

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        valueText:SetText(string.format("%.1f", value))
        if onChange then onChange(value) end
    end)

    -- Update on show
    container:SetScript("OnShow", function()
        if getValue then
            slider:SetValue(getValue())
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
        doubleClickCast = true,
        enhancedSound = true,
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
