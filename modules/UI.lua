--[[
    FishingKit - TBC Anniversary Edition
    UI Module - Main user interface

    This module creates:
    - Main fishing HUD panel
    - Integrated fishing cast bar
    - Skill display with progress bar
    - Zone information panel
    - Session statistics with catch tracking
    - Lure timer
    - Quick action buttons
]]

local ADDON_NAME, FK = ...

FK.UI = {}
local UI = FK.UI

-- UI State
local uiState = {
    mainFrame = nil,
    visible = false,
    elapsed = 0,       -- accumulator for fast (0.1s) cast-bar updates
    slowElapsed = 0,   -- accumulator for slow (1.0s) panel updates
    goldElapsed = 0,   -- accumulator for gold/hr display (10s)
    lastCatch = nil,
}

-- UI Constants
local FRAME_WIDTH           = 290
local FRAME_HEIGHT          = 352   -- expanded
local FRAME_HEIGHT_COLLAPSED = 168  -- collapsed (title + cast + buttons + footer)
local PADDING               = 10
local ROW_HEIGHT            = 16

-- Design palette
local D = {
    bg       = {0.04, 0.04, 0.06},  bgA  = 0.92,
    border   = {0.18, 0.18, 0.23},  borA = 0.80,
    divider  = {0.14, 0.14, 0.18},  divA = 0.90,
    accent   = {0.28, 0.74, 0.97},              -- soft cyan
    label    = {0.40, 0.40, 0.45},              -- muted label text
    value    = {0.82, 0.84, 0.88},              -- bright value text
    success  = {0.26, 0.76, 0.42},              -- green
    warn     = {0.95, 0.64, 0.10},              -- amber
    danger   = {0.90, 0.30, 0.30},              -- red
    gold     = {1.00, 0.82, 0.00},              -- WoW gold
    barBg    = {0.07, 0.07, 0.09},
}

-- Helper: draw a 1 px horizontal separator line
local function AddDivider(frame, yPos)
    local t = frame:CreateTexture(nil, "ARTWORK")
    t:SetHeight(1)
    t:SetPoint("TOPLEFT",  frame, "TOPLEFT",  PADDING, yPos)
    t:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING, yPos)
    t:SetColorTexture(D.divider[1], D.divider[2], D.divider[3], D.divA)
    return t
end

-- Helper: draw a 1 px border around a button using 4 edge textures
local function AddThinBorder(btn, r, g, b, a)
    local top = btn:CreateTexture(nil, "OVERLAY")
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(1)
    top:SetColorTexture(r, g, b, a)
    local bot = btn:CreateTexture(nil, "OVERLAY")
    bot:SetPoint("BOTTOMLEFT"); bot:SetPoint("BOTTOMRIGHT"); bot:SetHeight(1)
    bot:SetColorTexture(r, g, b, a)
    local lft = btn:CreateTexture(nil, "OVERLAY")
    lft:SetPoint("TOPLEFT"); lft:SetPoint("BOTTOMLEFT"); lft:SetWidth(1)
    lft:SetColorTexture(r, g, b, a)
    local rgt = btn:CreateTexture(nil, "OVERLAY")
    rgt:SetPoint("TOPRIGHT"); rgt:SetPoint("BOTTOMRIGHT"); rgt:SetWidth(1)
    rgt:SetColorTexture(r, g, b, a)
end

-- Openable containers caught while fishing (clams, crates, etc.)
local OPENABLE_ITEMS = {
    -- Clams
    [5523]  = "Small Barnacled Clam",
    [5524]  = "Thick-Shelled Clam",
    [7973]  = "Big-mouth Clam",
    [15874] = "Soft-shelled Clam",
    [24476] = "Jaggal Clam",
    -- TBC Clams
    [33567] = "Broiled Bloodfin",  -- Not a clam but openable
    -- Crates and containers
    [6352]  = "Waterlogged Crate",
    [6353]  = "Small Barnacled Clam",
    [13874] = "Heavy Crate",
    [13875] = "Mithril Bound Trunk",
    [21113] = "Watertight Trunk",
    [27481] = "Heavy Supply Crate",
    [27482] = "Inscribed Scrollcase",
    [27511] = "Inscribed Scrollcase",
    [27513] = "Curious Crate",
}

-- ============================================================================
-- Initialization
-- ============================================================================

function UI:Initialize()
    self:CreateMainFrame()
    self:CreateCastBar()
    self:CreateSkillBar()
    self:CreateZonePanel()
    self:CreateStatsPanel()
    self:CreateLureBar()
    self:CreateButtons()
    self:CreateFooter()
    self:CreateMinimapButton()

    -- Load saved position
    self:LoadPosition()

    -- Apply collapsed state
    self:ApplyCollapsedState()

    -- Initial update
    self:Update()

    -- Show if enabled
    if FK.db.settings.showUI then
        self:Show()
    end

    -- Setup double-right-click casting
    self:SetupDoubleClickCast()

    FK:Debug("UI module initialized")
end

-- ============================================================================
-- Main Frame
-- ============================================================================

function UI:CreateMainFrame()
    local frame = CreateFrame("Frame", "FishingKitMainFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)

    -- Clean dark backdrop with thin tooltip-style border
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

    -- Title bar (no fill — just text + separator line)
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetHeight(22)
    titleBar:SetPoint("TOPLEFT",  frame, "TOPLEFT",  PADDING, -PADDING)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING, -PADDING)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 0, 0)
    titleText:SetText("|cFF47BEF5FishingKit|r")
    frame.titleText = titleText
    frame.titleBar  = titleBar

    -- Helper: small styled icon button matching config window aesthetic
    local function MakeIconBtn(parent, symbol)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(16, 16)
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(D.barBg[1], D.barBg[2], D.barBg[3], 0.8)
        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("CENTER", 0, 0)
        lbl:SetText(symbol)
        lbl:SetTextColor(D.label[1], D.label[2], D.label[3])
        btn.lbl = lbl
        btn:SetScript("OnEnter", function(self) self.lbl:SetTextColor(D.value[1], D.value[2], D.value[3]) end)
        btn:SetScript("OnLeave", function(self) self.lbl:SetTextColor(D.label[1], D.label[2], D.label[3]) end)
        return btn
    end

    -- Zone Fish toggle button (fish icon, opens catch-rate panel below)
    local zoneFishBtn = MakeIconBtn(titleBar, "%")
    zoneFishBtn:SetPoint("RIGHT", titleBar, "RIGHT", -36, 0)
    zoneFishBtn:SetScript("OnClick", function()
        if FK.ZoneFish then FK.ZoneFish:Toggle() end
    end)
    zoneFishBtn:SetScript("OnEnter", function(self)
        self.lbl:SetTextColor(0.28, 0.74, 0.97)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Zone Catch Rates", 1, 0.82, 0)
        GameTooltip:AddLine("Show fish caught in this zone with %", 1, 1, 1)
        GameTooltip:Show()
    end)
    zoneFishBtn:SetScript("OnLeave", function(self)
        self.lbl:SetTextColor(0.40, 0.40, 0.45)
        GameTooltip:Hide()
    end)
    frame.zoneFishBtn = zoneFishBtn

    -- Collapse button
    local collapseBtn = MakeIconBtn(titleBar, "−")
    collapseBtn:SetPoint("RIGHT", titleBar, "RIGHT", -18, 0)
    collapseBtn:SetScript("OnClick", function() UI:ToggleCollapse() end)
    frame.collapseBtn = collapseBtn

    -- Close button
    local closeBtn = MakeIconBtn(titleBar, "×")
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", 0, 0)
    closeBtn:SetScript("OnClick", function() UI:Hide() end)

    -- Thin separator line under the title
    local titleDiv = frame:CreateTexture(nil, "ARTWORK")
    titleDiv:SetHeight(1)
    titleDiv:SetPoint("TOPLEFT",  frame, "TOPLEFT",  PADDING, -(PADDING + 24))
    titleDiv:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING, -(PADDING + 24))
    titleDiv:SetColorTexture(D.divider[1], D.divider[2], D.divider[3], D.divA)

    -- Make draggable
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not FK.db.settings.locked then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        UI:SavePosition()
    end)

    -- Update timer: cast bar at 0.1s, everything else at 1.0s
    frame:SetScript("OnUpdate", function(self, elapsed)
        uiState.elapsed = uiState.elapsed + elapsed
        if uiState.elapsed >= 0.1 then
            uiState.elapsed = 0
            UI:UpdateCastBar()
        end
        uiState.slowElapsed = uiState.slowElapsed + elapsed
        if uiState.slowElapsed >= 1.0 then
            uiState.slowElapsed = 0
            UI:UpdatePanel()
        end
    end)

    -- Content area: below title (22px) + PADDING top + 1px divider + 3px gap
    frame.contentTop = -(PADDING + 22 + 1 + 4)

    uiState.mainFrame = frame
    frame:Hide()
end

-- ============================================================================
-- Fishing Cast Bar (Integrated)
-- ============================================================================

function UI:CreateCastBar()
    local frame = uiState.mainFrame
    local yPos = frame.contentTop

    local container = CreateFrame("Frame", nil, frame)
    container:SetHeight(46)
    container:SetPoint("TOPLEFT",  frame, "TOPLEFT",  PADDING, yPos)
    container:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING, yPos)

    -- Status text (left, slightly larger)
    local statusText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    statusText:SetText("|cFF66666BIdle|r")
    frame.castStatusText = statusText

    -- Timer text (right, small dim)
    local timerText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timerText:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, -1)
    timerText:SetJustifyH("RIGHT")
    timerText:SetTextColor(D.label[1], D.label[2], D.label[3])
    timerText:SetText("")
    frame.castTimerText = timerText

    -- Bar background — dark, inset look, taller for prominence
    local barBg = container:CreateTexture(nil, "BACKGROUND")
    barBg:SetPoint("TOPLEFT",  statusText, "BOTTOMLEFT",  0, -5)
    barBg:SetPoint("TOPRIGHT", container,  "TOPRIGHT",    0, -5)
    barBg:SetHeight(20)
    barBg:SetColorTexture(D.barBg[1], D.barBg[2], D.barBg[3], 1)
    frame.castBarBg = barBg

    -- Bite confidence band (semi-transparent green fill behind the bar)
    local biteBand = container:CreateTexture(nil, "BORDER")
    biteBand:SetPoint("TOPLEFT", barBg, "TOPLEFT", 1, -1)
    biteBand:SetHeight(18)
    biteBand:SetWidth(1)
    biteBand:SetColorTexture(D.success[1], D.success[2], D.success[3], 0.18)
    biteBand:Hide()
    frame.biteBand = biteBand

    -- Bite median marker
    local biteMedian = container:CreateTexture(nil, "BORDER")
    biteMedian:SetPoint("TOPLEFT", barBg, "TOPLEFT", 1, -1)
    biteMedian:SetHeight(18)
    biteMedian:SetWidth(2)
    biteMedian:SetColorTexture(D.success[1], D.success[2], D.success[3], 0.55)
    biteMedian:Hide()
    frame.biteMedian = biteMedian

    -- Cast bar fill
    local bar = container:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT", barBg, "TOPLEFT", 1, -1)
    bar:SetHeight(18)
    bar:SetWidth(1)
    bar:SetColorTexture(D.accent[1], D.accent[2], D.accent[3], 1)
    frame.castBar = bar

    frame.castContainer = container
    frame.contentTop = yPos - 50
end

-- ============================================================================
-- Skill Bar
-- ============================================================================

function UI:CreateSkillBar()
    local frame = uiState.mainFrame
    local yPos = frame.contentTop

    AddDivider(frame, yPos)
    yPos = yPos - 6

    local container = CreateFrame("Frame", nil, frame)
    container:SetHeight(36)
    container:SetPoint("TOPLEFT",  frame, "TOPLEFT",  PADDING, yPos)
    container:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING, yPos)

    -- "SKILL" label (dim, uppercase)
    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    label:SetText("SKILL")
    label:SetTextColor(D.label[1], D.label[2], D.label[3])

    -- Skill value (bright, right-aligned)
    local skillText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    skillText:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
    skillText:SetJustifyH("RIGHT")
    skillText:SetTextColor(D.value[1], D.value[2], D.value[3])
    skillText:SetText("0 / 375")
    frame.skillText = skillText

    -- Thin skill progress bar
    local barBg = container:CreateTexture(nil, "BACKGROUND")
    barBg:SetPoint("TOPLEFT",  label,     "BOTTOMLEFT",  0, -3)
    barBg:SetPoint("TOPRIGHT", skillText, "BOTTOMRIGHT", 0, -3)
    barBg:SetHeight(5)
    barBg:SetColorTexture(D.barBg[1], D.barBg[2], D.barBg[3], 1)

    local bar = container:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT", barBg, "TOPLEFT", 1, -1)
    bar:SetHeight(3)
    bar:SetWidth(1)
    bar:SetColorTexture(D.accent[1], D.accent[2], D.accent[3], 1)
    frame.skillBar   = bar
    frame.skillBarBg = barBg

    -- Effective skill (dim sub-line)
    local effectiveText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    effectiveText:SetPoint("TOPLEFT", barBg, "BOTTOMLEFT", 0, -3)
    effectiveText:SetTextColor(D.label[1], D.label[2], D.label[3])
    effectiveText:SetText("Effective: 0 (+0)")
    frame.effectiveText = effectiveText

    frame.skillContainer = container
    frame.contentTop = yPos - 38
end

-- ============================================================================
-- Zone Panel
-- ============================================================================

function UI:CreateZonePanel()
    local frame = uiState.mainFrame
    local yPos = frame.contentTop

    AddDivider(frame, yPos)
    yPos = yPos - 6

    local container = CreateFrame("Frame", nil, frame)
    container:SetHeight(32)
    container:SetPoint("TOPLEFT",  frame, "TOPLEFT",  PADDING, yPos)
    container:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING, yPos)

    -- Zone name (accent color, left)
    local zoneName = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    zoneName:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    zoneName:SetTextColor(D.accent[1], D.accent[2], D.accent[3])
    zoneName:SetText("Unknown Zone")
    frame.zoneName = zoneName

    -- Zone skill requirement (dim, below)
    local zoneSkill = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    zoneSkill:SetPoint("TOPLEFT", zoneName, "BOTTOMLEFT", 0, -2)
    zoneSkill:SetTextColor(D.label[1], D.label[2], D.label[3])
    zoneSkill:SetText("")
    frame.zoneSkill = zoneSkill

    -- Seasonal note (even dimmer, optional third line)
    local seasonalNote = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    seasonalNote:SetPoint("TOPLEFT", zoneSkill, "BOTTOMLEFT", 0, -1)
    seasonalNote:SetText("")
    frame.seasonalNote = seasonalNote

    frame.zoneContainer = container
    frame.contentTop = yPos - 34
end

-- ============================================================================
-- Stats Panel
-- ============================================================================

function UI:CreateStatsPanel()
    local frame = uiState.mainFrame
    local yPos = frame.contentTop

    AddDivider(frame, yPos)
    yPos = yPos - 6

    local container = CreateFrame("Frame", nil, frame)
    container:SetHeight(62)
    container:SetPoint("TOPLEFT",  frame, "TOPLEFT",  PADDING, yPos)
    container:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING, yPos)

    -- "SESSION" label left, time right — both dim
    local header = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    header:SetText("SESSION")
    header:SetTextColor(D.label[1], D.label[2], D.label[3])

    local sessionTime = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sessionTime:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
    sessionTime:SetJustifyH("RIGHT")
    sessionTime:SetTextColor(D.label[1], D.label[2], D.label[3])
    sessionTime:SetText("0m")
    frame.sessionTime = sessionTime

    -- Column offset for right column (half panel width)
    local col2 = (FRAME_WIDTH - PADDING * 2) / 2

    -- Row 1: Casts | Catches
    local castsLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    castsLabel:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -16)
    castsLabel:SetText("Casts")
    castsLabel:SetTextColor(D.label[1], D.label[2], D.label[3])

    local castsValue = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    castsValue:SetPoint("LEFT", castsLabel, "RIGHT", 5, 0)
    castsValue:SetTextColor(D.value[1], D.value[2], D.value[3])
    castsValue:SetText("0")
    frame.statsCasts = castsValue

    local catchesLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    catchesLabel:SetPoint("TOPLEFT", container, "TOPLEFT", col2, -16)
    catchesLabel:SetText("Catches")
    catchesLabel:SetTextColor(D.label[1], D.label[2], D.label[3])

    local catchesValue = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    catchesValue:SetPoint("LEFT", catchesLabel, "RIGHT", 5, 0)
    catchesValue:SetTextColor(D.success[1], D.success[2], D.success[3])
    catchesValue:SetText("0")
    frame.statsCatches = catchesValue

    -- Row 2: Rate | Fish/hr
    local rateLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rateLabel:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -30)
    rateLabel:SetText("Rate")
    rateLabel:SetTextColor(D.label[1], D.label[2], D.label[3])

    local rateValue = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rateValue:SetPoint("LEFT", rateLabel, "RIGHT", 5, 0)
    rateValue:SetTextColor(D.value[1], D.value[2], D.value[3])
    rateValue:SetText("0%")
    frame.statsRate = rateValue

    local fphLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fphLabel:SetPoint("TOPLEFT", container, "TOPLEFT", col2, -30)
    fphLabel:SetText("Fish/hr")
    fphLabel:SetTextColor(D.label[1], D.label[2], D.label[3])

    local fphValue = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fphValue:SetPoint("LEFT", fphLabel, "RIGHT", 5, 0)
    fphValue:SetTextColor(D.value[1], D.value[2], D.value[3])
    fphValue:SetText("0")
    frame.statsFPH = fphValue

    -- Row 3: Gold/hr (Vendor + AH) — full width
    local goldLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    goldLabel:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -44)
    goldLabel:SetText("Gold/hr")
    goldLabel:SetTextColor(D.label[1], D.label[2], D.label[3])

    local goldVendorValue = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    goldVendorValue:SetPoint("LEFT", goldLabel, "RIGHT", 5, 0)
    goldVendorValue:SetTextColor(0.72, 0.72, 0.76)
    goldVendorValue:SetText("")
    frame.statsGoldVendor = goldVendorValue

    local goldAHValue = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    goldAHValue:SetPoint("LEFT", goldVendorValue, "RIGHT", 2, 0)
    goldAHValue:SetTextColor(D.gold[1], D.gold[2], D.gold[3])
    goldAHValue:SetText("")
    frame.statsGoldAH = goldAHValue

    frame.statsContainer = container
    frame.contentTop = yPos - 66
end

-- ============================================================================
-- Lure Bar
-- ============================================================================

function UI:CreateLureBar()
    local frame = uiState.mainFrame
    local yPos = frame.contentTop

    AddDivider(frame, yPos)
    yPos = yPos - 6

    local container = CreateFrame("Frame", nil, frame)
    container:SetHeight(24)
    container:SetPoint("TOPLEFT",  frame, "TOPLEFT",  PADDING, yPos)
    container:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING, yPos)

    -- "LURE" label (dim)
    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    label:SetText("LURE")
    label:SetTextColor(D.label[1], D.label[2], D.label[3])

    -- Status (right-aligned, same row)
    local lureStatus = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lureStatus:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
    lureStatus:SetJustifyH("RIGHT")
    lureStatus:SetTextColor(D.label[1], D.label[2], D.label[3])
    lureStatus:SetText("None")
    frame.lureStatus = lureStatus

    -- Thin lure progress bar
    local barBg = container:CreateTexture(nil, "BACKGROUND")
    barBg:SetPoint("TOPLEFT",  label,     "BOTTOMLEFT",  0, -4)
    barBg:SetPoint("TOPRIGHT", container, "TOPRIGHT",    0, -4)
    barBg:SetHeight(5)
    barBg:SetColorTexture(D.barBg[1], D.barBg[2], D.barBg[3], 1)

    local bar = container:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT", barBg, "TOPLEFT", 1, -1)
    bar:SetHeight(3)
    bar:SetWidth(1)
    bar:SetColorTexture(D.warn[1], D.warn[2], D.warn[3], 1)
    frame.lureBar   = bar
    frame.lureBarBg = barBg

    frame.lureContainer = container
    frame.contentTop = yPos - 28
end

-- ============================================================================
-- Action Buttons (Simple Icon Style)
-- ============================================================================

local function CreateSimpleIconButton(parent, name, size, iconPath, isSecure)
    local template = isSecure and "SecureActionButtonTemplate" or nil
    local btn = CreateFrame("Button", name, parent, template)
    btn:SetSize(size, size)
    btn:RegisterForClicks("AnyUp", "AnyDown")

    -- Dark flat background
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.08, 0.08, 0.10, 1)
    btn.bg = bg

    -- Icon with small inset
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT",     3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3,  3)
    icon:SetTexture(iconPath)
    btn.icon = icon

    -- Thin 1 px border using 4 edge textures (no Quickslot2 texture)
    AddThinBorder(btn, D.border[1], D.border[2], D.border[3], D.borA)

    -- Highlight on hover (ADD blend keeps it subtle)
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    btn:GetHighlightTexture():SetBlendMode("ADD")

    -- Subtle push effect
    btn:SetScript("OnMouseDown", function(self)
        self.icon:SetPoint("TOPLEFT",     4, -4)
        self.icon:SetPoint("BOTTOMRIGHT", -2,  2)
    end)
    btn:SetScript("OnMouseUp", function(self)
        self.icon:SetPoint("TOPLEFT",     3, -3)
        self.icon:SetPoint("BOTTOMRIGHT", -3,  3)
    end)

    return btn
end

function UI:CreateButtons()
    local frame = uiState.mainFrame

    -- Thin divider above button row
    local btnDiv = frame:CreateTexture(nil, "ARTWORK")
    btnDiv:SetHeight(1)
    btnDiv:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  PADDING, PADDING + 16 + 54 + 4)
    btnDiv:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PADDING, PADDING + 16 + 54 + 4)
    btnDiv:SetColorTexture(D.divider[1], D.divider[2], D.divider[3], D.divA)

    -- Container above the footer
    local container = CreateFrame("Frame", nil, frame)
    container:SetHeight(54)
    container:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  PADDING, PADDING + 16)
    container:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PADDING, PADDING + 16)

    -- 7 × 36px icons + 6 × 3px gaps = 252 + 18 = 270 = FRAME_WIDTH - 2*PADDING (290-20)
    local iconSize = 36
    local spacing  = 3
    local startX   = 0  -- exact fit, no centering offset needed

    -- Helper: muted label beneath each button
    local function AddLabel(btn, text)
        local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOP", btn, "BOTTOM", 0, -2)
        label:SetText(text)
        label:SetTextColor(D.label[1], D.label[2], D.label[3])
        return label
    end

    -- ========== 1. FISH BUTTON ==========
    local fishBtn = CreateSimpleIconButton(container, "FishingKitFishButton", iconSize, "Interface\\Icons\\Trade_Fishing", true)
    fishBtn:SetPoint("LEFT", container, "LEFT", startX, 6)

    -- Use type1/macrotext1 for left-click (TBC format)
    fishBtn:SetAttribute("type1", "macro")
    fishBtn:SetAttribute("macrotext1", "/cast Fishing")

    -- Fishing skill text ABOVE the button
    local fishSkillText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fishSkillText:SetPoint("BOTTOM", fishBtn, "TOP", 0, 2)
    fishSkillText:SetText("")
    fishSkillText:SetTextColor(0.5, 0.8, 1.0)
    frame.fishSkillText = fishSkillText

    -- "2x" overlay on Fish button icon (shown when double-click casting is enabled)
    local dcOverlay = fishBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dcOverlay:SetPoint("BOTTOMRIGHT", fishBtn, "BOTTOMRIGHT", -1, 1)
    dcOverlay:SetText("")
    dcOverlay:SetTextColor(0, 1, 0)
    frame.fishDCOverlay = dcOverlay

    fishBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Fishing", 1, 0.82, 0)
        GameTooltip:AddLine("Click to cast your line", 1, 1, 1)
        if FK.db and FK.db.settings.doubleClickCast then
            GameTooltip:AddLine("2x Right-Click casting enabled", 0, 1, 0)
        end
        GameTooltip:Show()
    end)
    fishBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.fishBtn = fishBtn
    frame.fishLabel = AddLabel(fishBtn, "Fish")

    -- ========== 2. EQUIP BUTTON ==========
    local equipBtn = CreateSimpleIconButton(container, "FishingKitEquipButton", iconSize, "Interface\\Icons\\INV_Fishingpole_02", false)
    equipBtn:SetPoint("LEFT", fishBtn, "RIGHT", spacing, 0)
    equipBtn:RegisterForClicks("LeftButtonUp")  -- Only fire on release
    equipBtn:SetScript("OnClick", function()
        if FK.Equipment:HasFishingPole() then
            FK.Equipment:EquipNormalGear()
        else
            FK.Equipment:EquipFishingGear()
        end
    end)
    equipBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if FK.Equipment:HasFishingPole() then
            GameTooltip:SetText("Equip Normal Gear", 1, 0.82, 0)
            GameTooltip:AddLine("Swap back to saved gear", 1, 1, 1)
        else
            GameTooltip:SetText("Equip Fishing Gear", 1, 0.82, 0)
            GameTooltip:AddLine("Equip your fishing gear", 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    equipBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.equipBtn = equipBtn
    frame.equipLabel = AddLabel(equipBtn, "Gear")

    -- ========== 3. LURE BUTTON ==========
    local lureBtn = CreateSimpleIconButton(container, "FishingKitLureButton", iconSize, "Interface\\Icons\\INV_Misc_Food_26", true)
    lureBtn:SetPoint("LEFT", equipBtn, "RIGHT", spacing, 0)

    -- Use type1/macrotext1 for left-click (TBC format)
    lureBtn:SetAttribute("type1", "macro")
    lureBtn:SetAttribute("macrotext1", "")

    -- Lure timer text ABOVE the button
    local lureTimer = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lureTimer:SetPoint("BOTTOM", lureBtn, "TOP", 0, 2)
    lureTimer:SetText("")
    lureTimer:SetTextColor(1, 0.8, 0)
    frame.lureTimer = lureTimer

    lureBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local lure = FK.Equipment:GetBestAvailableLure()
        if lure then
            GameTooltip:SetText("Apply Lure", 1, 0.82, 0)
            GameTooltip:AddLine(lure.name .. " (+" .. lure.bonus .. ")", 0.2, 1, 0.2)
        else
            GameTooltip:SetText("No Lures", 1, 0.2, 0.2)
            GameTooltip:AddLine("No lures in your bags", 1, 1, 1)
        end
        GameTooltip:Show()
        if not InCombatLockdown() then UI:UpdateLureButton() end
    end)
    lureBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    lureBtn:SetScript("PreClick", function()
        if not InCombatLockdown() then UI:UpdateLureButton() end
    end)
    frame.lureBtn = lureBtn
    frame.lureLabel = AddLabel(lureBtn, "Lure")

    -- ========== 4. CLAM BUTTON (Open Clams/Crates) ==========
    local clamBtn = CreateSimpleIconButton(container, "FishingKitClamButton", iconSize, "Interface\\Icons\\INV_Misc_Shell_01", true)
    clamBtn:SetPoint("LEFT", lureBtn, "RIGHT", spacing, 0)
    clamBtn:RegisterForClicks("AnyUp", "AnyDown")
    clamBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local items, totalCount = UI:GetOpenableItems()
        if totalCount > 0 then
            GameTooltip:SetText("Open Clams/Crates", 1, 0.82, 0)
            GameTooltip:AddLine(totalCount .. " items to open", 0.2, 1, 0.2)
            -- Show first few items
            for i = 1, math.min(3, #items) do
                GameTooltip:AddLine("  " .. items[i].name .. " x" .. items[i].count, 1, 1, 1)
            end
            if #items > 3 then
                GameTooltip:AddLine("  ..." .. (#items - 3) .. " more types", 0.7, 0.7, 0.7)
            end
        else
            GameTooltip:SetText("Open Clams/Crates", 1, 0.82, 0)
            GameTooltip:AddLine("No clams or crates to open", 0.5, 0.5, 0.5)
        end
        GameTooltip:Show()
        if not InCombatLockdown() then UI:UpdateClamButton() end
    end)
    clamBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    clamBtn:SetScript("PreClick", function()
        if not InCombatLockdown() then UI:UpdateClamButton() end
    end)
    clamBtn:SetScript("PostClick", function()
        -- Update after opening to show next item
        C_Timer.After(0.1, function()
            if not InCombatLockdown() then UI:UpdateClamButton() end
        end)
    end)
    frame.clamBtn = clamBtn
    frame.clamLabel = AddLabel(clamBtn, "Open")

    -- ========== 5. STATS BUTTON ==========
    local statsBtn = CreateSimpleIconButton(container, "FishingKitStatsButton", iconSize, "Interface\\Icons\\INV_Misc_Note_01", false)
    statsBtn:SetPoint("LEFT", clamBtn, "RIGHT", spacing, 0)
    statsBtn:RegisterForClicks("LeftButtonUp")  -- Only fire on release, not both
    statsBtn:SetScript("OnClick", function()
        if FK.Statistics and FK.Statistics.ToggleStatsPanel then
            FK.Statistics:ToggleStatsPanel()
        end
    end)
    statsBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Statistics", 1, 0.82, 0)
        GameTooltip:AddLine("View detailed fishing stats", 1, 1, 1)
        GameTooltip:Show()
    end)
    statsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.statsBtn = statsBtn
    frame.statsLabel = AddLabel(statsBtn, "Stats")

    -- ========== 6. ROUTE BUTTON ==========
    local routeBtn = CreateSimpleIconButton(container, "FishingKitRouteButton", iconSize, "Interface\\Icons\\Ability_Tracking", false)
    routeBtn:SetPoint("LEFT", statsBtn, "RIGHT", spacing, 0)
    routeBtn:RegisterForClicks("LeftButtonUp")
    routeBtn:SetScript("OnClick", function()
        if FK.Navigation then
            FK.Navigation:ToggleRoute()
            UI:UpdateRouteButton()
        end
    end)
    routeBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local isActive = FK.Navigation and FK.Navigation:IsActive()
        if isActive then
            GameTooltip:SetText("Stop Route", 1, 0.82, 0)
            GameTooltip:AddLine("Stop pool route navigation", 1, 1, 1)
        else
            GameTooltip:SetText("Start Route", 1, 0.82, 0)
            GameTooltip:AddLine("Start pool route navigation", 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    routeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.routeBtn = routeBtn
    frame.routeLabel = AddLabel(routeBtn, "Route")

    -- ========== 7. CONFIG BUTTON ==========
    local configBtn = CreateSimpleIconButton(container, "FishingKitConfigButton", iconSize, "Interface\\Icons\\Trade_Engineering", false)
    configBtn:SetPoint("LEFT", routeBtn, "RIGHT", spacing, 0)
    configBtn:RegisterForClicks("LeftButtonUp")  -- Only fire on release, not both
    configBtn:SetScript("OnClick", function()
        if FK.Config and FK.Config.Toggle then
            FK.Config:Toggle()
        end
    end)
    configBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Settings", 1, 0.82, 0)
        GameTooltip:AddLine("Open configuration", 1, 1, 1)
        GameTooltip:Show()
    end)
    configBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.configBtn = configBtn
    frame.configLabel = AddLabel(configBtn, "Config")

    frame.buttonContainer = container
end

-- ============================================================================
-- Footer Bar (always visible - last catch + 2xClick status)
-- ============================================================================

function UI:CreateFooter()
    local frame = uiState.mainFrame

    -- Thin line above footer
    local footDiv = frame:CreateTexture(nil, "ARTWORK")
    footDiv:SetHeight(1)
    footDiv:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  PADDING, PADDING + 14 + 2)
    footDiv:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PADDING, PADDING + 14 + 2)
    footDiv:SetColorTexture(D.divider[1], D.divider[2], D.divider[3], D.divA)

    local footer = CreateFrame("Frame", nil, frame)
    footer:SetHeight(14)
    footer:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  PADDING, PADDING)
    footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PADDING, PADDING)

    -- Bag space (right, very muted)
    local bagText = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bagText:SetPoint("RIGHT", footer, "RIGHT", 0, 0)
    bagText:SetJustifyH("RIGHT")
    bagText:SetText("")
    bagText:SetTextColor(D.label[1], D.label[2], D.label[3])
    frame.footerBags = bagText

    -- Last catch (left, equally muted)
    local lastCatchText = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lastCatchText:SetPoint("LEFT",  footer, "LEFT",  0, 0)
    lastCatchText:SetPoint("RIGHT", bagText, "LEFT", -6, 0)
    lastCatchText:SetJustifyH("LEFT")
    lastCatchText:SetWordWrap(false)
    lastCatchText:SetText("")
    lastCatchText:SetTextColor(D.label[1], D.label[2], D.label[3])
    frame.footerLastCatch = lastCatchText

    frame.footerContainer = footer
end

-- ============================================================================
-- Update Functions
-- ============================================================================

-- Full refresh — called when the panel needs an immediate sync (e.g. on show).
function UI:Update()
    if not uiState.mainFrame or not uiState.visible then return end
    self:UpdateCastBar()
    self:UpdatePanel()
end

-- Slow panel refresh (1 Hz) — everything except the cast bar.
function UI:UpdatePanel()
    if not uiState.mainFrame or not uiState.visible then return end

    local frame = uiState.mainFrame

    -- Update skill display
    local skill, maxSkill = FK:GetFishingSkill()
    maxSkill = maxSkill or 375
    frame.skillText:SetText(skill .. " / " .. maxSkill)

    -- Update skill text above Fish button
    if frame.fishSkillText then
        frame.fishSkillText:SetText(tostring(skill))
    end

    local barWidth = frame.skillBarBg:GetWidth() - 2
    local progress = maxSkill > 0 and (skill / maxSkill) or 0
    frame.skillBar:SetWidth(math.max(1, barWidth * progress))

    -- Update effective skill with fish-to-level counter
    local bonus = FK.Equipment:GetTotalBonus()
    local effective = skill + bonus

    -- Fish-to-level calculation (pre-3.1 TBC formula)
    local fishToLevel = ""
    if skill > 0 and skill < maxSkill then
        local catchesNeeded
        if skill <= 75 then
            catchesNeeded = 1
        else
            catchesNeeded = math.ceil((skill - 75) / 25)
        end
        fishToLevel = " | |cFFAADDFF~" .. catchesNeeded .. " to level|r"
    elseif skill >= maxSkill then
        fishToLevel = " | |cFF888888Max|r"
    end

    frame.effectiveText:SetText("Effective: " .. effective .. " (+" .. bonus .. ")" .. fishToLevel)

    -- Update zone info with catch rate
    local zone, subZone = FK:GetZoneInfo()
    frame.zoneName:SetText(zone)

    local zoneData = FK.Database:GetZoneInfo(zone)
    if zoneData then
        local minSkill = zoneData.minSkill or 1
        local noGetaway = zoneData.noGetaway or 1
        local skillColor = effective >= minSkill and "|cFF00FF00" or "|cFFFF0000"
        local getawayColor = effective >= noGetaway and "|cFF00FF00" or "|cFFFFFF00"

        -- Calculate catch rate percentage
        local catchRate
        if effective >= noGetaway then
            catchRate = 100
        elseif effective < minSkill then
            catchRate = 0
        else
            catchRate = math.floor(((effective - minSkill) / (noGetaway - minSkill)) * 100)
        end

        -- Color code the catch rate
        local rateColor
        if catchRate >= 100 then
            rateColor = "|cFF00FF00"  -- Bright green
        elseif catchRate >= 75 then
            rateColor = "|cFF80FF00"  -- Yellow-green
        elseif catchRate >= 50 then
            rateColor = "|cFFFFFF00"  -- Yellow
        elseif catchRate >= 25 then
            rateColor = "|cFFFF8800"  -- Orange
        else
            rateColor = "|cFFFF0000"  -- Red
        end

        frame.zoneSkill:SetText("Req: " .. skillColor .. minSkill .. "|r | 100%: " .. getawayColor .. noGetaway .. "|r | " .. rateColor .. catchRate .. "%|r")
        -- Check for seasonal and time-of-day fish in this zone
        if frame.seasonalNote then
            local notesParts = {}
            local fishList = FK.Database:GetFishForZone(zone)
            for _, fish in ipairs(fishList) do
                local fullInfo = FK.Database:GetFishInfo(fish.itemID)
                if fullInfo then
                    -- Seasonal fish
                    if fullInfo.seasonal and #notesParts < 2 then
                        local month = FK:GetServerMonth()
                        local isWinter = month >= 9 or month <= 3
                        local isSummer = month >= 3 and month <= 9

                        if fullInfo.seasonal == "winter" and isWinter then
                            table.insert(notesParts, "|cFFAADDFF" .. fullInfo.name .. " in season|r")
                        elseif fullInfo.seasonal == "summer" and isSummer then
                            table.insert(notesParts, "|cFFFFDD88" .. fullInfo.name .. " in season|r")
                        elseif fullInfo.seasonal == "winter" and not isWinter then
                            table.insert(notesParts, "|cFF666666" .. fullInfo.name .. " (winter only)|r")
                        elseif fullInfo.seasonal == "summer" and not isSummer then
                            table.insert(notesParts, "|cFF666666" .. fullInfo.name .. " (summer only)|r")
                        end
                    end

                    -- Time-of-day fish
                    if fullInfo.timeWindow and #notesParts < 3 then
                        local hour = FK:GetServerHour()
                        local isAvailable = FK:IsFishAvailable(fish.itemID)

                        if fullInfo.timeWindow == "night" then
                            if isAvailable then
                                table.insert(notesParts, "|cFF00FF00" .. fullInfo.name .. ": NOW|r")
                            else
                                table.insert(notesParts, "|cFF666666" .. fullInfo.name .. ": 18:00|r")
                            end
                        elseif fullInfo.timeWindow == "day" then
                            if isAvailable then
                                table.insert(notesParts, "|cFF00FF00" .. fullInfo.name .. ": NOW|r")
                            else
                                table.insert(notesParts, "|cFF666666" .. fullInfo.name .. ": 06:00|r")
                            end
                        end
                    end
                end
            end
            frame.seasonalNote:SetText(table.concat(notesParts, " | "))
        end
    else
        frame.zoneSkill:SetText("Zone data unavailable")
        if frame.seasonalNote then frame.seasonalNote:SetText("") end
    end

    -- Update session stats (1 Hz)
    if FK.Statistics then
        local stats = FK.Statistics:GetSessionStats()
        frame.statsCasts:SetText(tostring(stats.casts))
        frame.statsCatches:SetText(tostring(stats.catches))
        frame.statsRate:SetText(string.format("%.0f%%", stats.successRate))
        frame.statsFPH:SetText(string.format("%.0f", stats.fishPerHour))
        frame.sessionTime:SetText(FK:FormatTime(stats.duration))

        -- Gold/hr changes slowly (running average over the whole session) — update every 10s
        uiState.goldElapsed = uiState.goldElapsed + 1
        if uiState.goldElapsed >= 10 and frame.statsGoldVendor then
            uiState.goldElapsed = 0
            local vendorGPH = stats.vendorPerHour or 0
            local ahGPH = stats.blendedPerHour or 0
            frame.statsGoldVendor:SetText("V: " .. FK:FormatCopper(math.floor(vendorGPH)))
            frame.statsGoldAH:SetText(" | AH: " .. FK:FormatCopper(math.floor(ahGPH)))
        end
    end

    -- Update lure status
    local hasLure, expireTime, lureBonus = FK.Equipment:GetLureInfo()
    if hasLure then
        local remaining = expireTime - GetTime()
        if remaining > 0 then
            local bonusText = lureBonus > 0 and ("+" .. lureBonus) or "?"
            frame.lureStatus:SetText(FK:FormatTime(remaining) .. " (" .. bonusText .. ")")
            frame.lureStatus:SetTextColor(0.2, 1.0, 0.2)

            local maxDuration = 600
            local lureBarWidth = frame.lureBarBg:GetWidth() - 2
            local lureProgress = remaining / maxDuration
            frame.lureBar:SetWidth(math.max(1, lureBarWidth * lureProgress))

            -- Update lure timer above button
            if frame.lureTimer then
                local mins = math.floor(remaining / 60)
                local secs = math.floor(remaining % 60)
                frame.lureTimer:SetText(string.format("%d:%02d", mins, secs))

                -- Color based on time remaining
                if remaining < 30 then
                    frame.lureTimer:SetTextColor(1, 0.2, 0.2)  -- Red
                    frame.lureBar:SetColorTexture(1.0, 0.2, 0.2, 1)
                elseif remaining < 60 then
                    frame.lureTimer:SetTextColor(1, 0.6, 0.2)  -- Orange
                    frame.lureBar:SetColorTexture(1.0, 0.6, 0.2, 1)
                else
                    frame.lureTimer:SetTextColor(0.2, 1, 0.2)  -- Green
                    frame.lureBar:SetColorTexture(0.8, 0.6, 0.2, 1)
                end
            end
        else
            frame.lureStatus:SetText("Expired!")
            frame.lureStatus:SetTextColor(1.0, 0.2, 0.2)
            frame.lureBar:SetWidth(1)
            if frame.lureTimer then
                frame.lureTimer:SetText("|cFFFF0000EXPIRED|r")
            end
        end
    else
        frame.lureStatus:SetText("None")
        frame.lureStatus:SetTextColor(0.5, 0.5, 0.5)
        frame.lureBar:SetWidth(1)
        if frame.lureTimer then
            frame.lureTimer:SetText("")  -- No lure active, hide timer
        end
    end

    -- Update contest panel (panel runs at 1 Hz; UpdateContestPanel is cheap)
    self:UpdateContestPanel()

    -- Check cycle fish windows (self-throttles internally to 60s)
    if FK.Alerts and FK.Alerts.CheckCycleFishWindows then
        FK.Alerts:CheckCycleFishWindows()
    end

    -- Update equip button text
    if FK.Equipment:HasFishingPole() then
        frame.equipBtn:SetText("Unequip")
    else
        frame.equipBtn:SetText("Equip")
    end

    -- Update lure and clam button macros
    if not InCombatLockdown() then
        self:UpdateLureButton()
        self:UpdateClamButton()
    end

    -- Update route button state
    self:UpdateRouteButton()

    -- Update bag space display
    if frame.footerBags then
        local totalSlots, freeSlots = 0, 0
        for bag = 0, 4 do
            totalSlots = totalSlots + GetContainerNumSlots(bag)
            freeSlots = freeSlots + GetContainerNumFreeSlots(bag)
        end
        if freeSlots == 0 then
            frame.footerBags:SetText("|cFFFF0000Bags FULL!|r")
        else
            local color
            if freeSlots > 10 then
                color = "|cFF00FF00"
            elseif freeSlots > 5 then
                color = "|cFFFF8800"
            else
                color = "|cFFFF0000"
            end
            frame.footerBags:SetText(color .. "Bags: " .. freeSlots .. "/" .. totalSlots .. "|r")
        end
    end

    -- Update 2x overlay on Fish button
    if frame.fishDCOverlay then
        if FK.db and FK.db.settings.doubleClickCast then
            frame.fishDCOverlay:SetText("|cFF00FF002x|r")
        else
            frame.fishDCOverlay:SetText("")
        end
    end
    if frame.footerLastCatch then
        if uiState.lastCatch then
            local timeSince = GetTime() - uiState.lastCatch.time
            if timeSince < 300 then
                frame.footerLastCatch:SetText("|cFF888888Last:|r " .. uiState.lastCatch.name)
            else
                frame.footerLastCatch:SetText("")
            end
        end
    end
end

function UI:UpdateCastBar()
    local frame = uiState.mainFrame
    if not frame then return end

    -- Use WoW API as source of truth, just like Blizzard's cast bar
    local channelName = UnitChannelInfo("player")
    local apiSaysFishing = (channelName == "Fishing" or channelName == FK.FishingSpellName)
    if not apiSaysFishing and UnitCastingInfo then
        local castName = UnitCastingInfo("player")
        apiSaysFishing = (castName == "Fishing" or castName == FK.FishingSpellName)
    end

    -- Self-heal: if WoW says we're fishing but stale events corrupted our state, fix it
    if apiSaysFishing and not FK.State.isFishing then
        FK.State.isFishing = true
        if not FK.State.castStartTime then
            FK.State.castStartTime = GetTime()
        end
    end

    local isFishing = apiSaysFishing or FK.State.isFishing
    local barWidth = frame.castBarBg:GetWidth() - 2

    if isFishing then
        local elapsed = GetTime() - (FK.State.castStartTime or GetTime())
        local maxTime = 21  -- Fishing channel is ~21 seconds

        -- Show appropriate status based on elapsed time
        if elapsed < 1.5 then
            frame.castStatusText:SetText("|cFFFFFF00Casting...|r")
            frame.castBar:SetColorTexture(1.0, 0.8, 0.0, 1)
            frame.castTimerText:SetText(string.format("%.1fs", elapsed))
        else
            frame.castStatusText:SetText("|cFF00FF00Waiting for bite...|r")
            frame.castBar:SetColorTexture(0.2, 0.8, 0.2, 1)
            frame.castTimerText:SetText(string.format("%.1fs", elapsed))

            -- Color changes as time runs out
            if elapsed > 18 then
                frame.castBar:SetColorTexture(1.0, 0.2, 0.2, 1)  -- Red - running out!
                frame.castStatusText:SetText("|cFFFF6600Time running out!|r")
            elseif elapsed > 15 then
                frame.castBar:SetColorTexture(1.0, 0.6, 0.2, 1)  -- Orange
            end
        end

        -- Update bar (fills up as time passes)
        local progress = math.min(elapsed / maxTime, 1.0)
        frame.castBar:SetWidth(math.max(1, barWidth * progress))

        -- Show bite confidence band
        if frame.biteBand and FK.Statistics and FK.Statistics.GetBiteConfidence then
            local confidence = FK.Statistics:GetBiteConfidence()
            if confidence then
                local lowPx = math.max(1, (confidence.low / maxTime) * barWidth)
                local highPx = math.min(barWidth, (confidence.high / maxTime) * barWidth)
                local bandWidth = math.max(2, highPx - lowPx)

                frame.biteBand:ClearAllPoints()
                frame.biteBand:SetPoint("TOPLEFT", frame.castBarBg, "TOPLEFT", 1 + lowPx, -1)
                frame.biteBand:SetWidth(bandWidth)
                frame.biteBand:Show()

                -- Median marker
                local medianPx = (confidence.median / maxTime) * barWidth
                frame.biteMedian:ClearAllPoints()
                frame.biteMedian:SetPoint("TOPLEFT", frame.castBarBg, "TOPLEFT", 1 + medianPx - 1, -1)
                frame.biteMedian:Show()
            else
                frame.biteBand:Hide()
                frame.biteMedian:Hide()
            end
        end
    else
        -- Not fishing - show goal progress or idle
        local goalInfo = FK.Statistics and FK.Statistics.GetGoalProgress and FK.Statistics:GetGoalProgress()
        if goalInfo then
            if goalInfo.complete then
                frame.castStatusText:SetText("|cFF00FF00Goal Complete!|r " .. goalInfo.name .. " " .. goalInfo.current .. "/" .. goalInfo.target)
            else
                local pct = goalInfo.current / goalInfo.target
                local goalColor = pct >= 0.75 and "|cFFFFFF00" or "|cFFFFD700"
                frame.castStatusText:SetText(goalColor .. "Goal:|r " .. goalInfo.name .. " " .. goalInfo.current .. "/" .. goalInfo.target)
            end
        else
            frame.castStatusText:SetText("|cFF888888Idle - Ready to fish|r")
        end
        frame.castTimerText:SetText("")
        frame.castBar:SetWidth(1)
        frame.castBar:SetColorTexture(0.3, 0.3, 0.3, 1)

        -- Hide confidence band when not fishing
        if frame.biteBand then frame.biteBand:Hide() end
        if frame.biteMedian then frame.biteMedian:Hide() end
    end
end

function UI:UpdateLureButton()
    local frame = uiState.mainFrame
    if not frame or not frame.lureBtn then return end
    if InCombatLockdown() then return end

    local lure = FK.Equipment:GetBestAvailableLure()
    if lure then
        -- Macro: Use lure from bag, then apply to main hand (slot 16 = fishing pole)
        -- Two lines: first picks up lure, second applies to main hand
        local macroText = "/use " .. lure.bag .. " " .. lure.slot .. "\n/use 16"
        frame.lureBtn:SetAttribute("type1", "macro")
        frame.lureBtn:SetAttribute("macrotext1", macroText)

        -- Update icon
        local icon = lure.icon
        if not icon then
            local _, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(lure.itemID)
            icon = itemIcon
        end
        frame.lureBtn.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_Food_26")
        frame.lureBtn.icon:SetDesaturated(false)

        -- Show count
        if lure.count and lure.count > 1 then
            if not frame.lureBtn.countText then
                frame.lureBtn.countText = frame.lureBtn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
                frame.lureBtn.countText:SetPoint("BOTTOMRIGHT", -4, 4)
            end
            frame.lureBtn.countText:SetText(lure.count)
            frame.lureBtn.countText:Show()
        elseif frame.lureBtn.countText then
            frame.lureBtn.countText:Hide()
        end
    else
        -- No lure - clear macro
        frame.lureBtn:SetAttribute("macrotext1", "")
        frame.lureBtn.icon:SetTexture("Interface\\Icons\\INV_Misc_Food_26")
        frame.lureBtn.icon:SetDesaturated(true)
        if frame.lureBtn.countText then
            frame.lureBtn.countText:Hide()
        end
    end

    -- Update equip button icon to show current pole
    if frame.equipBtn then
        if FK.Equipment:HasFishingPole() then
            -- Show the actual equipped pole icon if possible
            local poleLink = GetInventoryItemLink("player", 16)
            if poleLink then
                local _, _, _, _, _, _, _, _, _, poleIcon = GetItemInfo(poleLink)
                if poleIcon then
                    frame.equipBtn.icon:SetTexture(poleIcon)
                else
                    frame.equipBtn.icon:SetTexture("Interface\\Icons\\INV_Fishingpole_02")
                end
            else
                frame.equipBtn.icon:SetTexture("Interface\\Icons\\INV_Fishingpole_02")
            end
            if frame.equipLabel then frame.equipLabel:SetText("Unequip") end
        else
            frame.equipBtn.icon:SetTexture("Interface\\Icons\\INV_Fishingpole_02")
            if frame.equipLabel then frame.equipLabel:SetText("Gear") end
        end
    end
end

-- Find openable items (clams, crates) in bags
function UI:GetOpenableItems()
    local items = {}
    local totalCount = 0

    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemLink = GetContainerItemLink(bag, slot)
            local itemCount

            -- Get item count
            if itemLink then
                local _, count = GetContainerItemInfo(bag, slot)
                itemCount = count or 1

                local itemID = tonumber(string.match(itemLink, "item:(%d+)"))
                if itemID and OPENABLE_ITEMS[itemID] then
                    table.insert(items, {
                        bag = bag,
                        slot = slot,
                        itemID = itemID,
                        name = OPENABLE_ITEMS[itemID],
                        count = itemCount,
                        link = itemLink,
                    })
                    totalCount = totalCount + itemCount
                end
            end
        end
    end

    return items, totalCount
end

-- Auto-open all fishing containers (crates, scroll cases, clams) in bags.
-- Called from Core.lua after LOOT_CLOSED for a fishing catch.
-- Uses UseContainerItem with staggered 0.5s delays so the server can process
-- each open before the next one is requested.
function UI:AutoOpenContainers()
    local items = self:GetOpenableItems()
    if #items == 0 then return end

    for i, item in ipairs(items) do
        C_Timer.After((i - 1) * 0.5, function()
            -- Re-verify the item is still in that bag slot (bag may have shifted)
            local link = GetContainerItemLink(item.bag, item.slot)
            local itemID = link and tonumber(string.match(link, "item:(%d+)"))
            if itemID and OPENABLE_ITEMS[itemID] then
                UseContainerItem(item.bag, item.slot)
                FK:Debug("Auto-opened: " .. item.name .. " (bag " .. item.bag .. " slot " .. item.slot .. ")")
            end
        end)
    end
end

function UI:UpdateClamButton()
    local frame = uiState.mainFrame
    if not frame or not frame.clamBtn then return end
    if InCombatLockdown() then return end

    local items, totalCount = self:GetOpenableItems()

    if #items > 0 then
        local firstItem = items[1]
        -- Macro to open the first clam/container found
        local macroText = "/use " .. firstItem.bag .. " " .. firstItem.slot
        frame.clamBtn:SetAttribute("type1", "macro")
        frame.clamBtn:SetAttribute("macrotext1", macroText)

        -- Update icon to show the item
        local _, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(firstItem.itemID)
        frame.clamBtn.icon:SetTexture(itemIcon or "Interface\\Icons\\INV_Misc_Shell_01")
        frame.clamBtn.icon:SetDesaturated(false)

        -- Show total count
        if not frame.clamBtn.countText then
            frame.clamBtn.countText = frame.clamBtn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
            frame.clamBtn.countText:SetPoint("BOTTOMRIGHT", -4, 4)
        end
        frame.clamBtn.countText:SetText(totalCount)
        frame.clamBtn.countText:Show()
    else
        -- No clams - clear macro
        frame.clamBtn:SetAttribute("macrotext1", "")
        frame.clamBtn.icon:SetTexture("Interface\\Icons\\INV_Misc_Shell_01")
        frame.clamBtn.icon:SetDesaturated(true)
        if frame.clamBtn.countText then
            frame.clamBtn.countText:Hide()
        end
    end
end

-- ============================================================================
-- Route Button Update
-- ============================================================================

function UI:UpdateRouteButton()
    local frame = uiState.mainFrame
    if not frame or not frame.routeBtn then return end

    local isActive = FK.Navigation and FK.Navigation:IsActive()
    if isActive then
        -- Active route — subtle green tint on the button bg
        frame.routeBtn.bg:SetColorTexture(0.04, 0.18, 0.08, 1)
        if frame.routeLabel then frame.routeLabel:SetText("|cFF44C468Route|r") end
    else
        -- Inactive — match standard button bg
        frame.routeBtn.bg:SetColorTexture(0.08, 0.08, 0.10, 1)
        if frame.routeLabel then frame.routeLabel:SetText("Route") end
    end
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

function UI:OnFishingStart()
    -- Cast time is tracked in FK.State.castStartTime
    self:Update()
end

function UI:OnFishingEnd()
    uiState.isFishing = false
    -- Reset panel color
    if uiState.mainFrame then
        self:SetPanelNormal()
    end
    self:Update()
end

-- Called when catch is successful - brief GREEN flash!
function UI:OnCatchSuccess()
    if uiState.mainFrame then
        self:SetPanelSuccess()
        -- Reset to normal after a brief moment
        C_Timer.After(0.5, function()
            self:SetPanelNormal()
        end)
    end
end

-- Set panel to success state (subtle green border flash)
function UI:SetPanelSuccess()
    local frame = uiState.mainFrame
    if not frame then return end

    if frame.SetBackdropColor then
        frame:SetBackdropColor(0.04, 0.10, 0.06, 0.95)
        frame:SetBackdropBorderColor(D.success[1], D.success[2], D.success[3], 0.90)
    end

    if frame.castStatusText then
        frame.castStatusText:SetText("|cFF44C468CAUGHT!|r")
    end
end

-- Reset panel to normal state
function UI:SetPanelNormal()
    local frame = uiState.mainFrame
    if not frame then return end

    if frame.SetBackdropColor then
        frame:SetBackdropColor(D.bg[1], D.bg[2], D.bg[3], D.bgA)
        frame:SetBackdropBorderColor(D.border[1], D.border[2], D.border[3], D.borA)
    end
end

function UI:OnLootOpened()
    self:Update()
end

function UI:OnCatch(itemName, itemLink)
    uiState.lastCatch = {
        name = itemName or "Something",
        link = itemLink,
        time = GetTime(),
    }
    self:Update()
end

function UI:OnZoneChanged()
    self:Update()
end

function UI:OnSkillUpdate()
    self:Update()
end

function UI:OnEquipmentChanged()
    self:Update()
end

-- ============================================================================
-- Visibility
-- ============================================================================

function UI:Show()
    if uiState.mainFrame then
        uiState.mainFrame:Show()
        uiState.visible = true
        FK.db.settings.showUI = true
        uiState.goldElapsed = 10  -- force immediate gold/hr refresh on first UpdatePanel
        self:Update()
    end
end

function UI:Hide()
    if uiState.mainFrame then
        uiState.mainFrame:Hide()
        uiState.visible = false
        FK.db.settings.showUI = false
        if FK.ZoneFish and FK.ZoneFish:IsShown() then
            FK.ZoneFish:Hide()
        end
    end
end

function UI:Toggle()
    if uiState.visible then
        self:Hide()
    else
        self:Show()
    end
end

function UI:IsVisible()
    return uiState.visible
end

-- ============================================================================
-- Collapse / Expand
-- ============================================================================

function UI:ToggleCollapse()
    FK.db.settings.collapsed = not FK.db.settings.collapsed
    self:ApplyCollapsedState()
end

function UI:ApplyCollapsedState()
    local frame = uiState.mainFrame
    if not frame then return end

    local collapsed = FK.db.settings.collapsed

    -- Toggle visibility of middle sections
    if frame.skillContainer then
        if collapsed then frame.skillContainer:Hide() else frame.skillContainer:Show() end
    end
    if frame.zoneContainer then
        if collapsed then frame.zoneContainer:Hide() else frame.zoneContainer:Show() end
    end
    if frame.statsContainer then
        if collapsed then frame.statsContainer:Hide() else frame.statsContainer:Show() end
    end
    if frame.lureContainer then
        if collapsed then frame.lureContainer:Hide() else frame.lureContainer:Show() end
    end

    -- Resize frame
    if collapsed then
        frame:SetHeight(FRAME_HEIGHT_COLLAPSED)
    else
        frame:SetHeight(FRAME_HEIGHT)
    end

    -- Update button icon (minus to collapse, plus to expand)
    if frame.collapseBtn then
        frame.collapseBtn.lbl:SetText(collapsed and "+" or "−")
    end
end

-- ============================================================================
-- Position Management
-- ============================================================================

function UI:SavePosition()
    if not uiState.mainFrame then return end

    local point, _, relativePoint, x, y = uiState.mainFrame:GetPoint()
    FK.db.settings.position = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end

function UI:LoadPosition()
    if not uiState.mainFrame or not FK.db.settings.position then return end

    local pos = FK.db.settings.position
    uiState.mainFrame:ClearAllPoints()
    uiState.mainFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
end

function UI:ResetPosition()
    if not uiState.mainFrame then return end

    uiState.mainFrame:ClearAllPoints()
    uiState.mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    self:SavePosition()
end

function UI:SetScale(scale)
    if uiState.mainFrame then
        uiState.mainFrame:SetScale(scale)
    end
end

-- ============================================================================
-- Minimap Button
-- ============================================================================

local minimapButton = nil
local minimapAngle = 225

function UI:CreateMinimapButton()
    if minimapButton then return end

    -- Create button frame
    local btn = CreateFrame("Button", "FishingKitMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

    -- Dark circle background (behind the icon, matches LibDBIcon standard)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)

    -- Icon
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexture("Interface\\Icons\\Trade_Fishing")
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    btn.icon = icon

    -- Border (standard minimap button border)
    local overlay = btn:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetPoint("TOPLEFT", 0, 0)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- Highlight
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- Position on minimap
    local function UpdatePosition()
        local angle = math.rad(minimapAngle)
        local x = math.cos(angle) * 80
        local y = math.sin(angle) * 80
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    -- Click handler
    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            UI:Toggle()
        elseif button == "RightButton" then
            if FK.Config and FK.Config.Toggle then
                FK.Config:Toggle()
            end
        end
    end)

    -- Drag handlers
    local isDragging = false
    btn:SetScript("OnDragStart", function(self)
        isDragging = true
        self:SetScript("OnUpdate", function(self)
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
            UpdatePosition()
        end)
    end)

    btn:SetScript("OnDragStop", function(self)
        isDragging = false
        self:SetScript("OnUpdate", nil)
        -- Save position
        if FK.db and FK.db.settings then
            FK.db.settings.minimapAngle = minimapAngle
        end
    end)

    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cFF00D1FFFishingKit|r")
        GameTooltip:AddLine("Left-click: Toggle window", 1, 1, 1)
        GameTooltip:AddLine("Right-click: Settings", 1, 1, 1)
        GameTooltip:AddLine("Drag: Move button", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    minimapButton = btn

    -- Load saved angle
    if FK.db and FK.db.settings and FK.db.settings.minimapAngle then
        minimapAngle = FK.db.settings.minimapAngle
    end
    UpdatePosition()

    -- Show based on settings
    if FK.db and FK.db.settings and FK.db.settings.showMinimap ~= false then
        btn:Show()
    else
        btn:Hide()
    end

    FK:Debug("Minimap button created")
end

function UI:ShowMinimapButton()
    if not minimapButton then
        self:CreateMinimapButton()
    end
    if minimapButton then
        minimapButton:Show()
        if FK.db and FK.db.settings then
            FK.db.settings.showMinimap = true
        end
    end
end

function UI:HideMinimapButton()
    if minimapButton then
        minimapButton:Hide()
        if FK.db and FK.db.settings then
            FK.db.settings.showMinimap = false
        end
    end
end

function UI:ToggleMinimapButton()
    if minimapButton and minimapButton:IsShown() then
        self:HideMinimapButton()
    else
        self:ShowMinimapButton()
    end
end

-- ============================================================================
-- STV Fishing Extravaganza Contest Panel
-- ============================================================================

local contestFrame = nil

function UI:UpdateContestPanel()
    if not FK.IsContestActive or not FK.IsInSTV then return end

    local isActive = FK:IsContestActive() and FK:IsInSTV()

    if isActive then
        if not contestFrame then
            self:CreateContestPanel()
        end
        -- Update contest info
        local tastyfish = FK:GetTaskyfishCount()
        local remaining = FK:GetContestTimeRemaining()

        contestFrame.countText:SetText("|cFFFFD700" .. tastyfish .. "/40|r Tastyfish")

        if tastyfish >= 40 then
            contestFrame.statusText:SetText("|cFF00FF00Turn in to win!|r")
        else
            contestFrame.statusText:SetText(remaining .. " min left")
        end

        -- Progress bar
        local progress = math.min(tastyfish / 40, 1.0)
        local barWidth = contestFrame.barBg:GetWidth() - 2
        contestFrame.bar:SetWidth(math.max(1, barWidth * progress))

        contestFrame:Show()
    else
        if contestFrame then
            contestFrame:Hide()
        end
    end
end

function UI:CreateContestPanel()
    if contestFrame then return end

    local frame = CreateFrame("Frame", "FishingKitContestFrame", uiState.mainFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(FRAME_WIDTH - 16, 36)
    frame:SetPoint("BOTTOMLEFT", uiState.mainFrame, "TOPLEFT", 8, 2)

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        frame:SetBackdropColor(0.06, 0.04, 0.01, 0.95)
        frame:SetBackdropBorderColor(D.gold[1], D.gold[2], D.gold[3], 0.70)
    end

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -5)
    title:SetText("|cFFFFD700STV Extravaganza|r")

    local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -5)
    statusText:SetJustifyH("RIGHT")
    statusText:SetTextColor(D.label[1], D.label[2], D.label[3])
    frame.statusText = statusText

    local barBg = frame:CreateTexture(nil, "BACKGROUND")
    barBg:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  6, 5)
    barBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 5)
    barBg:SetHeight(5)
    barBg:SetColorTexture(D.barBg[1], D.barBg[2], D.barBg[3], 1)
    frame.barBg = barBg

    local bar = frame:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT", barBg, "TOPLEFT", 1, -1)
    bar:SetHeight(3)
    bar:SetWidth(1)
    bar:SetColorTexture(D.gold[1], D.gold[2], D.gold[3], 1)
    frame.bar = bar

    local countText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("LEFT", title, "RIGHT", 8, 0)
    countText:SetText("0/40")
    frame.countText = countText

    frame:Hide()
    contestFrame = frame
end

-- ============================================================================
-- Tooltip Enrichment
-- ============================================================================

local function OnTooltipSetItem(tooltip)
    if not FK.db or not FK.db.settings.enabled then return end

    local _, itemLink = tooltip:GetItem()
    if not itemLink then return end

    local itemID = tonumber(string.match(itemLink, "item:(%d+)"))
    if not itemID then return end

    -- Check if this item is in our fish database
    local fishInfo = FK.Database:GetFishInfo(itemID)
    if not fishInfo then return end

    -- Add separator
    tooltip:AddLine(" ")
    tooltip:AddLine("|cFF00D1FFFishingKit|r", 1, 1, 1)

    -- Show how many the player has caught
    if FK.chardb and FK.chardb.stats and FK.chardb.stats.fishCaught then
        local caught = FK.chardb.stats.fishCaught[itemID]
        if caught then
            tooltip:AddDoubleLine("Caught:", "|cFFFFFFFF" .. (caught.count or 0) .. "|r", 0.7, 0.7, 0.7)
        else
            tooltip:AddDoubleLine("Caught:", "|cFF8888880|r", 0.7, 0.7, 0.7)
        end
    end

    -- Show where to catch it
    if fishInfo.zone then
        tooltip:AddDoubleLine("Zones:", "|cFFFFD700" .. fishInfo.zone .. "|r", 0.7, 0.7, 0.7)
    end

    -- Show min skill
    if fishInfo.minSkill then
        local skill = FK.State.fishingSkill or 0
        local color = skill >= fishInfo.minSkill and "|cFF00FF00" or "|cFFFF0000"
        tooltip:AddDoubleLine("Min Skill:", color .. fishInfo.minSkill .. "|r", 0.7, 0.7, 0.7)
    end

    -- Seasonal note
    if fishInfo.seasonal then
        local season = fishInfo.seasonal == "winter" and "Winter only" or "Summer only"
        tooltip:AddDoubleLine("Season:", "|cFFAADDFF" .. season .. "|r", 0.7, 0.7, 0.7)
    end

    -- AH price if we have it
    if FK.db and FK.db.ahPrices and FK.db.ahPrices[itemID] then
        tooltip:AddDoubleLine("AH Price:", "|cFFFFD700" .. FK:FormatCopper(FK.db.ahPrices[itemID]) .. "|r", 0.7, 0.7, 0.7)
    end

    -- Best zone (where player has caught the most)
    if FK.chardb and FK.chardb.stats and FK.chardb.stats.zoneStats then
        local bestZone, bestCount = nil, 0
        for zoneName, zoneData in pairs(FK.chardb.stats.zoneStats) do
            if zoneData.fish and zoneData.fish[itemID] and zoneData.fish[itemID] > bestCount then
                bestZone = zoneName
                bestCount = zoneData.fish[itemID]
            end
        end
        if bestZone then
            tooltip:AddDoubleLine("Best Zone:", "|cFF00FF00" .. bestZone .. "|r (x" .. bestCount .. ")", 0.7, 0.7, 0.7)
        end
    end

    tooltip:Show()
end

-- Hook the tooltip
GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)

-- ============================================================================
-- Double-Right-Click Casting (ZenFishing-style)
-- ============================================================================
-- Double-click = cast Fishing (or apply lure first if auto-lure is on).
-- Uses GLOBAL_MOUSE_DOWN + SecureActionButton + SetOverrideBindingClick,
-- mirroring the FishingBuddy approach so the binding fires on the same click.

local dcFrame = CreateFrame("Frame", "FishingKitDCFrame", UIParent)
local dcLastClickTime = 0
local dcHooked = false
local dcSABtn = nil

local function GetDCSAButton()
    if dcSABtn then return dcSABtn end
    dcSABtn = CreateFrame("Button", "FishingKitSAButton", UIParent, "SecureActionButtonTemplate")
    dcSABtn:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
    dcSABtn:SetFrameStrata("LOW")
    dcSABtn:SetSize(1, 1)
    dcSABtn:Show()
    dcSABtn:RegisterForClicks("RightButtonDown")
    dcSABtn:SetScript("PostClick", function()
        ClearOverrideBindings(dcSABtn)
        for _, attr in ipairs({"type", "spell", "macrotext", "macro"}) do
            dcSABtn:SetAttribute(attr, nil)
        end
    end)
    return dcSABtn
end

local function DCInvoke()
    local btn = GetDCSAButton()
    -- Clear previous attributes
    for _, attr in ipairs({"type", "spell", "macrotext", "macro"}) do
        btn:SetAttribute(attr, nil)
    end

    -- If auto-lure is enabled, no lure active, and we have a lure in bags -- apply it first
    local needLure = false
    if FK.db and FK.db.settings.autoLureReapply and FK.Equipment then
        local hasMainHandEnchant = GetWeaponEnchantInfo()
        if not hasMainHandEnchant then
            local bestLure = FK.Equipment:GetBestAvailableLure()
            if bestLure then
                needLure = true
                local macrotext = "/use " .. bestLure.bag .. " " .. bestLure.slot .. "\n/use 16"
                btn:SetAttribute("type", "macro")
                btn:SetAttribute("macrotext", macrotext)
                FK:Debug("DCInvoke: applying lure " .. bestLure.name .. " via macro")
            end
        end
    end

    if not needLure then
        btn:SetAttribute("type", "spell")
        btn:SetAttribute("spell", FK.FishingSpellName or "Fishing")
        FK:Debug("DCInvoke: casting Fishing")
    end

    SetOverrideBindingClick(btn, true, "BUTTON2", "FishingKitSAButton")
end

function UI:SetupDoubleClickCast()
    if dcHooked then return end
    dcHooked = true

    GetDCSAButton()  -- create early so the frame exists

    dcFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")
    dcFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    dcFrame:SetScript("OnEvent", function(self, event, arg1)
        if event == "GLOBAL_MOUSE_DOWN" then
            if not FK.db or not FK.db.settings.doubleClickCast then return end
            if arg1 ~= "RightButton" then return end
            if InCombatLockdown() then return end
            if not FK.Equipment or not FK.Equipment:HasFishingPole() then return end

            -- Don't fire during active loot window
            if LootFrame and LootFrame:IsShown() then return end

            local now = GetTime()
            local delay = now - dcLastClickTime
            dcLastClickTime = now

            if delay > 0.05 and delay < 0.4 then
                FK:Debug("Double-click detected (delay=" .. string.format("%.3f", delay) .. ")")

                if IsMouselooking() then
                    MouselookStop()
                end

                DCInvoke()
            else
                -- Single click -- clear any stale binding
                if dcSABtn then ClearOverrideBindings(dcSABtn) end
            end
        elseif event == "PLAYER_REGEN_DISABLED" then
            if dcSABtn then ClearOverrideBindings(dcSABtn) end
            dcLastClickTime = 0
        end
    end)

    FK:Debug("Double-click casting setup complete")
end

-- No-ops for any leftover calls in Core.lua
function UI:ExtendDoubleClick() end
function UI:OnFishingLootClosed() end
function UI:OnFishingCastStarted() end

FK:Debug("UI module loaded")
