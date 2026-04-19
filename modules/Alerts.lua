--[[
    FishingKit - TBC Anniversary Edition
    Alerts Module - Sound and visual alert system

    This module handles:
    - Visual flash effects on successful catch
    - Sound cues for fishing events (catch, lure expiring)
    - Lure expiration warnings

    NOTE: Automatic "fish on the line" detection is NOT possible via WoW API.
    The bobber tooltip always shows "Fishing Bobber" regardless of fish state.
    Listen for the in-game splash sound with your speakers.
]]

local ADDON_NAME, FK = ...

FK.Alerts = {}
local Alerts = FK.Alerts

-- Alert state
local alertState = {
    watching = false,
    castTime = 0,
    splashDetected = false,  -- Set to true when LOOT_OPENED fires (successful catch)
    flashFrame = nil,
    lureWarned = false,
    watchFrame = nil,
    -- Enhanced sound state
    soundBoosted = false,
    -- Missing lure warning state
    lastLureWarningTime = 0,
}

-- CVars to mute/restore when enhanced fishing sound is active.
-- Same list as BetterFishing's CVarCacheSounds.
local soundCVarList = {
    "Sound_MasterVolume",
    "Sound_SFXVolume",
    "Sound_EnableAmbience",
    "Sound_MusicVolume",
    "Sound_EnableMusic",
    "Sound_EnableAllSound",
    "Sound_EnablePetSounds",
    "Sound_EnableSoundWhenGameIsInBG",
    "Sound_EnableSFX",
}
local soundCVarCache = {}

-- Sound file paths (TBC compatible)
-- Using sound kit IDs that work in TBC
local sounds = {
    splash = 888,         -- SOUNDKIT.GS_LOGIN or water sound
    warning = 8959,       -- SOUNDKIT.RAID_WARNING
    success = 878,        -- SOUNDKIT.LEVELUP
    rare = 8989,          -- SOUNDKIT.UI_EPICLOOT_TOAST
    lureExpire = 8959,    -- SOUNDKIT.RAID_WARNING
    test = 6674,          -- Bell sound for testing
}

-- ============================================================================
-- Initialization
-- ============================================================================

function Alerts:Initialize()
    -- Create the flash overlay frame
    self:CreateFlashFrame()

    -- Create the cast timer frame
    self:CreateTimerFrame()

    -- Subscribe to fishing events
    FK.Events:On("FISHING_STARTED",  function() Alerts:OnCastStart() end)
    FK.Events:On("BOBBER_LANDED",    function() Alerts:OnBobberLanded() end)
    FK.Events:On("FISHING_BITE",     function() Alerts:OnFishingEnd() end)
    FK.Events:On("FISHING_MISSED",   function() Alerts:OnFishingComplete() end)
    FK.Events:On("FISHING_FAILED",   function() Alerts:OnFishingComplete() end)
    FK.Events:On("FISHING_COMPLETE", function() Alerts:OnFishingComplete() end)
    FK.Events:On("ZONE_CHANGED",     function() Alerts:CheckCycleFishWindows() end)

end

-- ============================================================================
-- Flash Effect Frame
-- ============================================================================

function Alerts:CreateFlashFrame()
    if alertState.flashFrame then return end

    local frame = CreateFrame("Frame", "FishingKitFlashFrame", UIParent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetAllPoints(UIParent)
    frame:SetAlpha(0)
    frame:Hide()

    local texture = frame:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints()
    texture:SetColorTexture(0.2, 0.6, 1.0, 0.4)  -- Blue tint for water

    alertState.flashFrame = frame

    -- Animation for flash
    local animGroup = frame:CreateAnimationGroup()
    local fadeIn = animGroup:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(0.4)
    fadeIn:SetDuration(0.1)
    fadeIn:SetOrder(1)

    local fadeOut = animGroup:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(0.4)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(0.3)
    fadeOut:SetOrder(2)

    animGroup:SetScript("OnFinished", function()
        frame:Hide()
        frame:SetAlpha(0)
    end)

    frame.animGroup = animGroup
end

function Alerts:Flash()
    if not FK.db.settings.screenFlash then return end
    if not alertState.flashFrame then return end

    alertState.flashFrame:Show()
    alertState.flashFrame.animGroup:Play()
end

-- ============================================================================
-- Cast Timer Frame (DISABLED - integrated into main UI now)
-- ============================================================================

function Alerts:CreateTimerFrame()
    -- Timer is now integrated into the main UI panel
    -- This function is kept for compatibility but does nothing
end

function Alerts:ShowTimer()
    -- Disabled - timer is in main UI
end

function Alerts:HideTimer()
    -- Disabled - timer is in main UI
end

-- ============================================================================
-- Sound Playback
-- ============================================================================

function Alerts:PlaySound(soundType)
    if not FK.db.settings.soundEnabled then return end

    local soundID = sounds[soundType]
    if soundID then
        -- TBC compatible PlaySound (just pass the ID)
        PlaySound(soundID)
    end
end

function Alerts:TestSound()
    -- Play a simple bell/ding sound for testing
    PlaySound(3081)  -- TELLMESSAGE sound - reliable in TBC
    FK:Print("Test sound played.", FK.Colors.info)
end

-- ============================================================================
-- Fishing Event Handlers
-- ============================================================================

function Alerts:OnCastStart()
    alertState.castTime = GetTime()
    alertState.watching = false
    alertState.splashDetected = false

end

function Alerts:OnBobberLanded()
    -- Bobber is now in the water, start watching for loot.
    -- BoostFishingSound is idempotent via the soundBoosted guard: if the
    -- player re-casts while the bobber is still in the water, the second
    -- call is a no-op and the original CVar cache is preserved.
    alertState.watching = true
    alertState.splashDetected = false

    self:BoostFishingSound()
    self:ShowTimer()

    -- Start the fishing event watching system
    self:StartWatching()
end

function Alerts:OnFishingEnd()
    -- CHANNEL_STOP fired — the fishing channel ended.  Do NOT restore sound
    -- here: the player may be re-casting, and the sound should stay boosted
    -- until fishing is truly finished (loot collected or 1-second timeout).
    -- RestoreFishingSound is called only from OnFishingComplete.
    alertState.watching = false

    self:HideTimer()
    self:StopWatching()

end

-- Called when fishing is truly done (loot closed or timeout).
-- RestoreFishingSound is a no-op if not currently boosted.
function Alerts:OnFishingComplete()
    self:RestoreFishingSound()
end

-- ============================================================================
-- Fishing Event Watching
-- ============================================================================
-- NOTE: Automatic "fish on the line" detection is NOT possible via the WoW API.
-- The bobber tooltip always shows "Fishing Bobber" whether a fish is biting or not.
-- Blizzard designed it this way to prevent automated fishing.
--
-- What we CAN detect:
-- - LOOT_OPENED: When you successfully click the bobber and get loot
-- - UNIT_SPELLCAST_CHANNEL_STOP: When the fishing channel ends (timeout or recast)
--
-- For fish bite notification, you must listen for the in-game splash SOUND
-- with your speakers - there is no API event for it.
-- ============================================================================

function Alerts:StartWatching()
    if alertState.watchFrame then return end

    -- Create a frame to watch for fishing events (reuse if previously created)
    local frame = alertState._watchFrameCache or CreateFrame("Frame")
    alertState._watchFrameCache = frame
    alertState.watchFrame = frame

    -- Register events we CAN reliably detect
    frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    frame:RegisterEvent("LOOT_OPENED")

    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "LOOT_OPENED" and alertState.watching then
            -- Player successfully caught something!
            Alerts:OnCatchSuccess()
        elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
            local unit = ...
            if unit == "player" then
                -- Fishing channel stopped
                if alertState.watching and not alertState.splashDetected then
                    Alerts:OnFishGotAway()
                end
            end
        end
    end)

    -- Set up OnUpdate for lure expiration and missing lure checks
    frame:SetScript("OnUpdate", function(self, elapsed)
        Alerts:CheckLureExpiration()
        Alerts:CheckMissingLure()
    end)
end

function Alerts:StopWatching()
    if alertState.watchFrame then
        alertState.watchFrame:UnregisterAllEvents()
        alertState.watchFrame:SetScript("OnUpdate", nil)
        alertState.watchFrame:SetScript("OnEvent", nil)
        alertState.watchFrame = nil
    end
end

function Alerts:OnCatchSuccess()
    alertState.splashDetected = true

    -- Play success sound
    self:PlaySound("success")

    -- Screen flash on successful catch
    self:Flash()

    -- Briefly turn UI panel green to indicate success
    if FK.UI and FK.UI.OnCatchSuccess then
        FK.UI:OnCatchSuccess()
    end

end

function Alerts:OnFishGotAway()
    -- Fish got away (didn't click in time or cast expired)
end

-- ============================================================================
-- Lure Expiration Warning
-- ============================================================================

function Alerts:CheckLureExpiration()
    if not FK.db.settings.soundEnabled then return end

    local hasLure, expireTime = FK:HasLure()

    if hasLure then
        local remaining = expireTime - GetTime()

        -- Warn at 30 seconds remaining
        if remaining > 0 and remaining <= 30 and not alertState.lureWarned then
            alertState.lureWarned = true
            self:PlaySound("lureExpire")
            FK:Print("Lure expiring in " .. math.ceil(remaining) .. " seconds!", FK.Colors.warning)
        elseif remaining > 30 then
            alertState.lureWarned = false
        end
    else
        alertState.lureWarned = false
    end
end

-- ============================================================================
-- Rare Catch Alert
-- ============================================================================

function Alerts:OnRareCatch(itemName, quality)
    -- Play special sound for rare catches
    if quality >= 3 then
        self:PlaySound("rare")

        -- Extra flash for rare items
        if FK.db.settings.screenFlash then
            self:Flash()
        end
    end
end

-- ============================================================================
-- Enhanced Fishing Sound
-- Mutes music, ambience and pet sounds; boosts SFX + master to a configured
-- level so the bobber splash is easy to hear. Mirrors BetterFishing's
-- EnhanceSounds approach so the two addons behave consistently.
-- ============================================================================

function Alerts:BoostFishingSound()
    if not FK.db or not FK.db.settings.enhancedSound then return end
    if alertState.soundBoosted then return end

    -- Snapshot all sound CVars before changing anything
    for _, cvar in ipairs(soundCVarList) do
        soundCVarCache[cvar] = GetCVar(cvar)
    end

    -- Mute everything first
    for _, cvar in ipairs(soundCVarList) do
        SetCVar(cvar, 0)
    end

    -- Re-enable SFX only, at the configured volume level
    local scale = FK.db.settings.enhanceSoundScale or 1.0
    SetCVar("Sound_EnableAllSound", 1)
    SetCVar("Sound_EnableSFX", 1)
    SetCVar("Sound_EnableSoundWhenGameIsInBG", 1)
    SetCVar("Sound_SFXVolume", tostring(scale))
    SetCVar("Sound_MasterVolume", tostring(scale))

    alertState.soundBoosted = true
end

function Alerts:RestoreFishingSound()
    if not alertState.soundBoosted then return end

    -- Restore all CVars to pre-boost values
    for _, cvar in ipairs(soundCVarList) do
        if soundCVarCache[cvar] then
            SetCVar(cvar, soundCVarCache[cvar])
        end
    end

    alertState.soundBoosted = false
end

-- ============================================================================
-- Missing Lure Warning
-- ============================================================================

function Alerts:CheckMissingLure()
    if not FK.db.settings.missingLureWarning then return end
    if not FK:IsFishing() then return end
    if not FK.Equipment or not FK.Equipment:HasFishingPole() then return end

    local hasLure = FK:HasLure()
    if hasLure then
        alertState.lastLureWarningTime = 0
        return
    end

    -- Check interval
    local now = GetTime()
    local interval = FK.db.settings.missingLureInterval or 60
    if alertState.lastLureWarningTime > 0 and (now - alertState.lastLureWarningTime) < interval then
        return
    end

    alertState.lastLureWarningTime = now
    FK:Print("No lure active! Apply a lure for bonus fishing skill.", FK.Colors.warning)
    self:PlaySound("warning")
end

-- ============================================================================
-- Pool Detection Alert
-- ============================================================================

function Alerts:OnPoolDetected(poolName)
    if FK.db.settings.poolSound then
        self:PlaySound("warning")
    end

    if FK.db.settings.visualAlert then
        -- Could add a pool indicator here
    end
end

-- ============================================================================
-- Cycle Fish Time Window Alerts
-- ============================================================================

local cycleFishState = {
    lastWindowCheck = nil,  -- "night" or "day" or nil
    lastCheckTime = 0,
}

function Alerts:CheckCycleFishWindows()
    if not FK.db or not FK.db.settings.cycleFishAlerts then return end

    local now = GetTime()
    if now - cycleFishState.lastCheckTime < 60 then return end
    cycleFishState.lastCheckTime = now

    local hour = FK:GetServerHour()
    local currentWindow = (hour >= 6 and hour < 18) and "day" or "night"

    if cycleFishState.lastWindowCheck and cycleFishState.lastWindowCheck ~= currentWindow then
        -- Window just changed — check if current zone has time-window fish
        local zone = FK:GetZone() or ""
        if zone ~= "" and FK.Database then
            local fishList = FK.Database:GetFishForZone(zone)
            for _, fish in ipairs(fishList) do
                local fullInfo = FK.Database:GetFishInfo(fish.itemID)
                if fullInfo and fullInfo.timeWindow and fullInfo.timeWindow == currentWindow then
                    FK:Print("|cFF00FF00" .. fullInfo.name .. " are now available!|r (" ..
                        (currentWindow == "night" and "18:00-06:00" or "06:00-18:00") .. " server time)")
                end
            end
        end
    end

    cycleFishState.lastWindowCheck = currentWindow
end

-- ============================================================================
-- Settings
-- ============================================================================

function Alerts:SetSoundEnabled(enabled)
    FK.db.settings.soundEnabled = enabled
end

function Alerts:SetVisualAlertEnabled(enabled)
    FK.db.settings.visualAlert = enabled
end

function Alerts:SetScreenFlashEnabled(enabled)
    FK.db.settings.screenFlash = enabled
end

