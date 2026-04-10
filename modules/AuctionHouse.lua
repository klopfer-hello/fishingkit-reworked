--[[
    FishingKit - TBC Anniversary Edition
    AuctionHouse Module — AH tab UI and fish price scanning

    Adds a "FishingKit" tab to the Auction House window with a one-click
    price scanner. Queries every known fish by name, records the lowest
    buyout per item, and caches results in FK.db.ahPrices (account-wide).

    Prices are considered fresh for 4 hours; items scanned recently are
    skipped on subsequent visits to keep the scan fast.

    Event flow:
        AUCTION_HOUSE_SHOW         → CreateTab (once)
        [user clicks Scan]         → StartScan → ScanNext loop
        AUCTION_ITEM_LIST_UPDATE   → ReadResults → ScanNext
        AUCTION_HOUSE_CLOSED       → Finish (abort)
]]

local ADDON_NAME, FK = ...

FK.AuctionHouse = {}
local AH = FK.AuctionHouse

-- ============================================================================
-- Module-local state
-- ============================================================================

local scan = {
    active           = false,
    queue            = {},    -- array of { itemID, fishName }
    currentIndex     = 0,
    results          = { found = 0, noListings = 0, ahClosed = 0, throttled = 0 },
    waitingForResults = false,
    currentFish      = nil,
    currentItemID    = nil,
}

local tab = {
    created    = false,
    tabIndex   = nil,
    tabButton  = nil,
    content    = nil,
    statusText = nil,
    scanButton = nil,
    progressText = nil,
    resultsHeader = nil,
    scrollFrame  = nil,
    scrollChild  = nil,
    namePool     = {},
    pricePool    = {},
}

-- ============================================================================
-- Initialization
-- ============================================================================

function AH:Initialize()
end

-- ============================================================================
-- Event handlers (called from Core.lua)
-- ============================================================================

function AH:OnAuctionHouseShow()
    C_Timer.After(0.1, function()
        AH:CreateTab()
    end)
end

function AH:OnAuctionHouseClosed()
    if scan.active then
        FK:Debug("AH scan: aborted (AH closed)")
        AH:Finish()
    end
    if tab.content then
        tab.content:Hide()
    end
end

function AH:OnAuctionItemListUpdate()
    if scan.active and scan.waitingForResults then
        scan.waitingForResults = false
        AH:ReadResults()
    end
end

-- ============================================================================
-- Tab UI
-- ============================================================================

function AH:CreateTab()
    if not AuctionFrame then
        FK:Debug("AH tab: AuctionFrame not found")
        return
    end
    if tab.created then
        return
    end
    tab.created = true

    -- Create the tab button following Blizzard's AuctionFrameTab naming pattern
    local numTabs = AuctionFrame.numTabs or 3
    local newIndex = numTabs + 1
    local tabButton = CreateFrame("Button", "AuctionFrameTab" .. newIndex, AuctionFrame, "AuctionTabTemplate")
    tabButton:SetID(newIndex)
    tabButton:SetText("FishingKit")
    tabButton:SetPoint("LEFT", _G["AuctionFrameTab" .. numTabs], "RIGHT", -15, 0)

    PanelTemplates_SetNumTabs(AuctionFrame, newIndex)
    PanelTemplates_EnableTab(AuctionFrame, newIndex)
    PanelTemplates_TabResize(tabButton, 0, nil, 36)

    tab.tabIndex  = newIndex
    tab.tabButton = tabButton

    -- Content frame (hidden by default, shown when our tab is selected)
    -- Matches Auctionator's wrapper pattern: TOPLEFT x=12, BOTTOMRIGHT y=37
    -- y=37 clears the tab buttons at the bottom of AuctionFrame
    local content = CreateFrame("Frame", "FishingKitAHFrame", AuctionFrame)
    content:SetPoint("TOPLEFT",     AuctionFrame, "TOPLEFT",     12, -10)
    content:SetPoint("BOTTOMRIGHT", AuctionFrame, "BOTTOMRIGHT", -8,  37)
    content:Hide()
    tab.content = content

    -- Title
    local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", content, "TOP", 0, -8)
    title:SetText("|cFF00D1FFFishingKit|r - Fish Price Scanner")

    -- Status text
    local status = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    status:SetPoint("TOP", title, "BOTTOM", 0, -6)
    status:SetText("Scan auction house prices for all known fish.")
    tab.statusText = status

    -- Scan button
    local scanBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    scanBtn:SetSize(180, 28)
    scanBtn:SetPoint("TOP", status, "BOTTOM", 0, -6)
    scanBtn:SetText("Scan Fish Prices")
    scanBtn:SetScript("OnClick", function()
        if scan.active then
            FK:Print("Scan already in progress.", FK.Colors.warning)
        else
            AH:StartScan()
        end
    end)
    tab.scanButton = scanBtn

    -- Progress text
    local progress = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    progress:SetPoint("TOP", scanBtn, "BOTTOM", 0, -4)
    progress:SetText("")
    tab.progressText = progress

    -- Results header
    local resultsHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    resultsHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -96)
    resultsHeader:SetText("Cached Prices:")
    tab.resultsHeader = resultsHeader

    -- Column headers
    local colName = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colName:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -112)
    colName:SetText("|cFFFFD100Fish|r")
    colName:SetJustifyH("LEFT")

    local colPrice = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colPrice:SetPoint("TOPRIGHT", content, "TOPRIGHT", -30, -112)
    colPrice:SetText("|cFFFFD100Price Per Unit|r")
    colPrice:SetJustifyH("RIGHT")

    -- Scroll frame for the price list
    local scrollFrame = CreateFrame("ScrollFrame", "FishingKitAHScroll", content, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     content, "TOPLEFT",     6,   -126)
    scrollFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -28,    4)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    tab.scrollFrame = scrollFrame
    tab.scrollChild = scrollChild

    scrollFrame:SetScript("OnSizeChanged", function(self, w, h)
        scrollChild:SetWidth(w)
    end)

    -- Hook tab clicks to show/hide our content
    hooksecurefunc("AuctionFrameTab_OnClick", function(self)
        local id = self:GetID()
        if id == tab.tabIndex then
            AuctionFrameAuctions:Hide()
            AuctionFrameBrowse:Hide()
            AuctionFrameBid:Hide()
            tab.content:Show()
            AH:RefreshPriceList()
        else
            tab.content:Hide()
        end
    end)

end

-- ============================================================================
-- Price list display
-- ============================================================================

function AH:RefreshPriceList()
    if not tab.scrollChild then return end
    local child = tab.scrollChild

    -- Hide all pooled FontStrings
    for _, fs in ipairs(tab.namePool)  do fs:Hide() end
    for _, fs in ipairs(tab.pricePool) do fs:Hide() end

    if not FK.db or not FK.db.ahPrices then
        tab.resultsHeader:SetText("Cached Prices: (none)")
        child:SetHeight(1)
        return
    end

    -- Build sorted list of cached prices
    local priceList = {}
    for itemID, price in pairs(FK.db.ahPrices) do
        local fishName
        if FK.Database and FK.Database.Fish and FK.Database.Fish[itemID] then
            fishName = FK.Database.Fish[itemID].name
        end
        if not fishName and FK.chardb and FK.chardb.stats
                and FK.chardb.stats.fishCaught
                and FK.chardb.stats.fishCaught[itemID] then
            fishName = FK.chardb.stats.fishCaught[itemID].name
        end
        if fishName then
            table.insert(priceList, { name = fishName, price = price, itemID = itemID })
        end
    end
    table.sort(priceList, function(a, b) return a.name < b.name end)

    tab.resultsHeader:SetText("Cached Prices: " .. #priceList .. " fish")

    local listWidth = child:GetWidth()
    if not listWidth or listWidth < 100 then
        listWidth = tab.scrollFrame and tab.scrollFrame:GetWidth() or 700
        child:SetWidth(listWidth)
    end

    local yOff = 0
    for i, entry in ipairs(priceList) do
        local nameStr = tab.namePool[i]
        if not nameStr then
            nameStr = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            nameStr:SetJustifyH("LEFT")
            nameStr:SetWordWrap(false)
            tab.namePool[i] = nameStr
        end
        nameStr:ClearAllPoints()
        nameStr:SetPoint("TOPLEFT", child, "TOPLEFT", 4, -yOff)
        nameStr:SetPoint("RIGHT",   child, "RIGHT",  -160, 0)
        nameStr:SetText(entry.name)
        nameStr:Show()

        local priceStr = tab.pricePool[i]
        if not priceStr then
            priceStr = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            priceStr:SetWidth(150)
            priceStr:SetJustifyH("RIGHT")
            priceStr:SetWordWrap(false)
            tab.pricePool[i] = priceStr
        end
        priceStr:ClearAllPoints()
        priceStr:SetPoint("TOPRIGHT", child, "TOPRIGHT", -4, -yOff)
        priceStr:SetText(FK:FormatCopper(entry.price))
        priceStr:Show()

        yOff = yOff + 14
    end

    child:SetHeight(math.max(yOff + 10, 1))
end

-- ============================================================================
-- Scan orchestration
-- ============================================================================

function AH:UpdateProgress()
    if not tab.progressText then return end
    if not scan.active then return end
    local r = scan.results
    tab.progressText:SetText(
        "Scanning " .. scan.currentIndex .. "/" .. #scan.queue
        .. "  |  " .. r.found .. " priced, " .. r.noListings .. " no listings")
end

function AH:StartScan()
    if not FK.db then
        FK:Debug("AH scan: FK.db is nil, aborting")
        return
    end
    if not FK.db.ahPrices     then FK.db.ahPrices     = {} end
    if not FK.db.ahPriceTimes then FK.db.ahPriceTimes = {} end
    if scan.active then
        FK:Debug("AH scan: already scanning, ignoring")
        return
    end

    -- Prices are considered fresh for 4 hours; skip items scanned more recently.
    local STALE_SECS = 4 * 3600
    local now = time()

    -- Collect fish from catch history + full database
    local fishToScan = {}
    local fromCatches  = 0
    local fromDatabase = 0

    if FK.chardb and FK.chardb.stats and FK.chardb.stats.fishCaught then
        for itemID, data in pairs(FK.chardb.stats.fishCaught) do
            if data.name then
                fishToScan[itemID] = data.name
                fromCatches = fromCatches + 1
            end
        end
    end

    if FK.Database and FK.Database.Fish then
        for itemID, fishData in pairs(FK.Database.Fish) do
            if not fishData.junk then
                if not fishToScan[itemID] then
                    fromDatabase = fromDatabase + 1
                end
                fishToScan[itemID] = fishData.name
            end
        end
    end

    -- Build ordered queue, skipping items with a fresh cached price
    scan.queue = {}
    local skipped = 0
    for itemID, fishName in pairs(fishToScan) do
        local lastScan = FK.db.ahPriceTimes[itemID]
        if lastScan and (now - lastScan) < STALE_SECS then
            skipped = skipped + 1
        else
            table.insert(scan.queue, { itemID = itemID, fishName = fishName })
        end
    end
    table.sort(scan.queue, function(a, b) return a.fishName < b.fishName end)

    FK:Debug("AH scan: " .. #scan.queue .. " fish queued, " .. skipped .. " skipped (fresh price)")

    if #scan.queue == 0 then
        FK:Print("All AH prices are up to date (scanned within 4 hours).", FK.Colors.success)
        return
    end

    scan.active           = true
    scan.currentIndex     = 0
    scan.results          = { found = 0, noListings = 0, ahClosed = 0, throttled = 0 }
    scan.waitingForResults = false

    local skipMsg = skipped > 0 and " (" .. skipped .. " fresh, skipped)" or ""
    FK:Print("Scanning AH prices for " .. #scan.queue .. " fish items..." .. skipMsg, FK.Colors.info)
    if tab.statusText  then tab.statusText:SetText("Scanning " .. #scan.queue .. " fish...") end
    if tab.scanButton  then tab.scanButton:Disable() end
    AH:UpdateProgress()
    AH:ScanNext()
end

function AH:ScanNext()
    if not scan.active then return end

    scan.currentIndex = scan.currentIndex + 1
    local entry = scan.queue[scan.currentIndex]

    if not entry then
        FK:Debug("AH scan: all items processed")
        AH:Finish()
        return
    end

    if not AuctionFrame or not AuctionFrame:IsShown() then
        FK:Debug("AH scan [" .. scan.currentIndex .. "/" .. #scan.queue .. "]: AH closed, aborting")
        AH:Finish()
        return
    end

    scan.currentFish   = entry.fishName
    scan.currentItemID = entry.itemID

    if not CanSendAuctionQuery() then
        AH:WaitForThrottle()
        return
    end

    AH:SendQuery()
end

function AH:WaitForThrottle()
    local attempts    = 0
    local maxAttempts = 15
    local ticker
    ticker = C_Timer.NewTicker(0.2, function()
        attempts = attempts + 1
        if not scan.active then
            ticker:Cancel()
            return
        end
        if not AuctionFrame or not AuctionFrame:IsShown() then
            ticker:Cancel()
            FK:Debug("AH scan: AH closed while waiting for throttle")
            AH:Finish()
            return
        end
        if CanSendAuctionQuery() then
            ticker:Cancel()
            AH:SendQuery()
        elseif attempts >= maxAttempts then
            ticker:Cancel()
            FK:Debug("AH scan [" .. scan.currentIndex .. "/" .. #scan.queue .. "]: throttle timeout, skipping " .. (scan.currentFish or "?"))
            scan.results.throttled = scan.results.throttled + 1
            AH:ScanNext()
        end
    end)
end

function AH:SendQuery()
    if not scan.active or not scan.currentFish then return end
    if not AuctionFrame or not AuctionFrame:IsShown() then
        AH:Finish()
        return
    end

    local idx      = scan.currentIndex
    local fishName = scan.currentFish
    local itemID   = scan.currentItemID

    scan.waitingForResults = true
    SortAuctionSetSort("list", "unitprice")
    QueryAuctionItems(fishName, nil, nil, 0, nil, nil, false, false, nil)

    -- Safety timeout in case AUCTION_ITEM_LIST_UPDATE never fires
    C_Timer.After(3, function()
        if scan.waitingForResults and scan.active then
            FK:Debug("AH scan [" .. idx .. "/" .. #scan.queue .. "]: timeout waiting for \"" .. fishName .. "\"")
            scan.waitingForResults  = false
            scan.results.throttled = scan.results.throttled + 1
            AH:ScanNext()
        end
    end)
end

function AH:ReadResults()
    if not scan.active then return end

    local idx      = scan.currentIndex
    local fishName = scan.currentFish
    local itemID   = scan.currentItemID

    if not AuctionFrame or not AuctionFrame:IsShown() then
        FK:Debug("AH scan: AH closed before reading results")
        AH:Finish()
        return
    end

    local numBatch, numTotal = GetNumAuctionItems("list")

    local lowestBuyout = nil
    local matchCount   = 0

    for i = 1, numBatch do
        local name, _, count, _, _, _, _, _, _, buyoutPrice = GetAuctionItemInfo("list", i)
        if name and buyoutPrice and buyoutPrice > 0 and count and count > 0 then
            local perItem = math.floor(buyoutPrice / count)
            if name == fishName then
                matchCount = matchCount + 1
                if not lowestBuyout or perItem < lowestBuyout then
                    lowestBuyout = perItem
                end
            end
        end
    end

    FK.db.ahPriceTimes[itemID] = time()  -- record scan time regardless of result
    if lowestBuyout then
        FK.db.ahPrices[itemID]    = lowestBuyout
        scan.results.found        = scan.results.found + 1
    else
        scan.results.noListings = scan.results.noListings + 1
    end

    AH:UpdateProgress()
    AH:ScanNext()
end

function AH:Finish()
    if not scan.active then return end
    scan.active            = false
    scan.waitingForResults = false

    local r       = scan.results
    local scanned = scan.currentIndex
    FK:Debug("AH scan complete: " .. scanned .. " queried, " .. r.found .. " priced, "
        .. r.noListings .. " no listings, " .. r.throttled .. " throttled/timeout")

    local totalPriced = 0
    for _ in pairs(FK.db.ahPrices) do totalPriced = totalPriced + 1 end
    FK:Debug("AH scan: " .. totalPriced .. " total fish with cached AH prices")

    if r.found > 0 then
        FK:Print("AH scan done: " .. r.found .. " prices updated.", FK.Colors.success)
    else
        FK:Print("AH scan done: no listings found.", FK.Colors.warning)
    end

    if tab.scanButton    then tab.scanButton:Enable() end
    if tab.statusText    then tab.statusText:SetText("Scan complete. " .. r.found .. " prices found, " .. r.noListings .. " no listings.") end
    if tab.progressText  then tab.progressText:SetText("") end
    AH:RefreshPriceList()
end

