# Extreme FishingKit - CLAUDE.md

## Project Overview

Extreme FishingKit is a World of Warcraft addon for **TBC Classic Anniversary** (interface version 20504/20505, game version 2.5.5). It provides fishing quality-of-life features: session statistics, catch tracking, fishing alerts, gear/lure management, and pool location recording.

The addon uses a global namespace `FK` (also `FishingKit`) populated via the addon vararg `local ADDON_NAME, FK = ...`.

## File Structure

| File | Purpose |
|---|---|
| [Core.lua](Core.lua) | Main framework: event registration, state machine, module coordination, C_Container shim |
| [modules/Statistics.lua](modules/Statistics.lua) | Session stats, catch recording, loot event handling |
| [modules/Alerts.lua](modules/Alerts.lua) | Sound/visual alerts for fish bites |
| [modules/Config.lua](modules/Config.lua) | Settings persistence and defaults |
| [modules/Database.lua](modules/Database.lua) | Fish/item classification (fish vs junk vs special) |
| [modules/Equipment.lua](modules/Equipment.lua) | Fishing gear, lure management, and combat weapon swap |
| [modules/UI.lua](modules/UI.lua) | Addon UI frames |
| [modules/ZoneFish.lua](modules/ZoneFish.lua) | Zone catch-rate panel (expandable panel below main HUD) |
| [modules/Pools.lua](modules/Pools.lua) | Fishing pool location tracking |
| [modules/PoolData.lua](modules/PoolData.lua) | Pool name/location data |
| [modules/Navigation.lua](modules/Navigation.lua) | Map/minimap utilities |

## Game Version Notes (Critical)

- **TBC Classic Anniversary uses the `C_Container` namespace** — legacy globals like `GetContainerNumSlots`, `GetContainerItemLink`, `GetContainerItemInfo` may not exist.
- A compatibility shim in [Core.lua lines 17-33](Core.lua) maps legacy globals to `C_Container` equivalents.
- `C_Container.GetContainerItemInfo` returns a **table** (fields: `iconFileID`, `stackCount`, `isLocked`, `quality`, etc.) — the shim wraps it to return legacy multiple-return-value style.
- **`LOOT_READY` event is available** in TBC Classic Anniversary and fires before auto-loot processes items.
- **`IsFishingLoot()`** is a Blizzard built-in API available in TBC Classic Anniversary that returns `true` when the current loot source is a fishing bobber.
- **`GetLootSlotInfo(slot)`** returns `texture, name, count, quality, locked` (5 values, no `currencyID` — that is a Retail-only return value).
- With auto-loot enabled, `GetNumLootItems()` returns 0 in `LOOT_OPENED` because items are already processed. Use `LOOT_READY` instead.

## State Machine (Core.lua)

```
FK.State = {
    isFishing        -- true while channel is active
    castStartTime    -- GetTime() when bobber lands (CHANNEL_START), reset on re-cast; nil when not fishing
    castGen          -- increments each cast (SPELLCAST_START), used to discard stale timer callbacks
    channelCastGen   -- snapshot of castGen at CHANNEL_START; used in CHANNEL_STOP to detect stale re-cast
    channelStarted   -- true once CHANNEL_START has fired (bobber is in water); false on new SPELLCAST_START
    waitingForLoot   -- true from CHANNEL_STOP until LOOT_CLOSED (or 1s timeout)
    lootCastGen      -- castGen value at CHANNEL_STOP time
    bobberGUID       -- GUID of the fishing bobber unit
    currentZone      -- current zone name
    currentSubZone   -- current subzone name
    hasLure          -- whether a lure is active
    lureExpireTime   -- when the lure expires
    fishingSkill     -- current fishing skill
    fishingSkillModifier
    sessionStartTime
    sessionActive
    combatSwapQueued
    preCombatPole    -- GetInventoryItemLink("player", 16) snapshotted at PLAYER_REGEN_DISABLED;
                     -- used to restore only the pole after combat (not full gear set)
}
```

Key state transitions:
- `SPELLCAST_START` → `isFishing = true`, increment `castGen`, `channelStarted = false`, clear `waitingForLoot`
- `CHANNEL_START` → `channelStarted = true`, snapshot `channelCastGen = castGen`, reset `castStartTime`
- `CHANNEL_STOP` (if `channelCastGen == castGen`) → `waitingForLoot = true`, save `lootCastGen`, start 1s timeout
- `CHANNEL_STOP` (if `channelCastGen != castGen`) → ignored (stale event from old bobber on re-cast)
- 1s timeout (no loot, `UnitChannelInfo == nil`) → reset `isFishing`, `waitingForLoot` (handles "fish got away")
- `LOOT_CLOSED` → reset `isFishing`, `waitingForLoot` (if `castGen` matches `lootCastGen`)

## Catch Detection (Current Approach)

**Event**: `LOOT_READY` + `IsFishingLoot()` — the approach used by FishingBuddy.

```lua
-- Core.lua
eventHandlers.LOOT_READY = function()
    if IsFishingLoot and IsFishingLoot() then
        FK.Statistics:OnLootReady()
    end
end

-- Statistics.lua
function Stats:OnLootReady()
    local numItems = GetNumLootItems()
    for i = 1, numItems do
        local texture, name, count, quality = GetLootSlotInfo(i)
        local link = GetLootSlotLink(i)
        self:RecordCatch({ itemID, name, quantity=count, quality, link })
    end
end
```

**Why `LOOT_READY` not `LOOT_OPENED`**: With auto-loot, `LOOT_OPENED` fires after items are already taken — `GetNumLootItems()` returns 0. `LOOT_READY` fires before auto-loot runs, so the loot table is always populated.

**Why not bag diff**: Previous approach (snapshotting bags in `CHANNEL_STOP`, diffing in `LOOT_CLOSED`) was intermittent because: (a) if the player took >1 second to click after fish bite, the 1-second timeout reset the state before `LOOT_CLOSED` fired; (b) timing of `CHANNEL_STOP` relative to fish bite vs player click is unreliable in TBC 2.5.5.

## Reference Addon: FishingBuddy

FishingBuddy is located at `d:\Games\World of Warcraft\_anniversary_\Interface\AddOns\FishingBuddy`. **Do not modify it** — it exists solely as a reference for correct TBC Classic API usage.

Key files to reference:
- `Libs/LibFishing-1.0/LibFishing-1.0.lua` — core fishing detection logic
- `FishingBuddy.lua` — main event handling, uses `LOOT_READY` + `IsFishingLoot()` + `GetLootInfo()`

## Bugs Fixed (Commit History)

| Commit | Bug | Fix |
|---|---|---|
| `88c695a` | `trackLoot` guard blocked loot scanning when only `trackStats` was set | Changed `OnLootOpened`/`OnLootSlotCleared` guard to `trackStats` |
| `790ec0a` | Quality always 0 due to wrong `GetLootSlotInfo` return mapping | Removed extra `currencyID` variable (Retail-only return value) |
| `b74434b` | `fishCaught` and gold values not persisted across sessions | `SaveSession` now includes `fishCaught`, `vendorCopper`, `ahCopper`, `blendedCopper` |
| `1f1318f` | Statistics panel showed session total gold instead of per-hour rate | `vendorGold` display uses `session.vendorPerHour` not `session.vendorCopper` |
| `06132e1` | Catches = 0 with auto-loot (bag diff approach, intermittent) | Replaced `OnLootOpened` loot window scan with bag snapshot + diff |
| `d6ab687` | Bag diff intermittent (player >1s to click, timeout cleared state) | Replaced bag diff with `LOOT_READY` + `IsFishingLoot()` |
| `f347b47` | Sound permanently boosted / re-cast triggered double boost+restore | `BoostFishingSound` idempotent via guard; `RestoreFishingSound` only called from `OnFishingComplete` |
| `9b98408` | Cast timer not reset on re-cast | `castStartTime` set unconditionally at `CHANNEL_START` (was conditional nil-check) |
| `1a2b4de` | Combat weapon swap: offhand silently failed; item-name format failed in combat; calling from `UNIT_INVENTORY_CHANGED` failed (lockdown fully active by then) | Use `EquipItemByName("item:ID", slot)` immediately from `PLAYER_REGEN_DISABLED`; guard offhand with current-item check (pole doesn't displace slot 17) |
| `1a2b4de` | After combat, `EquipFishingGear` → `SaveNormalGear` overwrote normalGear with fishing hat/boots | `combatWeapons` stored separately in charDB; combat-end only restores the pole, never calls `EquipFishingGear`/`SaveNormalGear` |
| `1a2b4de` | Pole disappeared after combat (slot empty) | `EquipItemByName("item:poleID", 16)` when pole already in slot picks it up and leaves empty; guard with `GetItemIDFromLink` comparison before attempting equip |
| `18e9d40` | `SetOverrideBindingClick` set from `WorldFrame:OnMouseDown` never fired — the current click was already past the input dispatch stage | Moved double-click detection to `GLOBAL_MOUSE_DOWN` event (fires before click dispatch); `SetOverrideBindingClick` now takes effect for the same mouse-down event |
| (v1.2.3) | Stats panel out of theme: `UIPanelCloseButton` template, plain white title word, WoW native scroll bar | Replaced with custom `×` close button; dimmed title; plain `ScrollFrame` + mousewheel + thin custom scroll thumb |
| (v1.2.4) | Zone Fish (%) panel stays visible after closing main window — `UI:Hide()` never hid it; `ZF:Hide()` method didn't exist (silent Lua error) | Added `ZF:Hide()` + `ZF:Show()` to ZoneFish.lua; `UI:Hide()` calls `FK.ZoneFish:Hide()` |
| (v1.3.0) | `IsFishingSpell` always returned false for `CHANNEL_START`/`CHANNEL_STOP` — enhanced audio, cast timer, and state machine broken | TBC Anniversary uses modern `(unit, castGUID, spellID)` signature (spellID=arg3), not old `(unit, spellName, rank, lineID, spellID)` (spellID=arg5). Restored `arg5 or arg3` fallback in `IsFishingSpell` and all spell event handlers |
| (v1.3.0) | `UNIT_SPELLCAST_INTERRUPTED` never restored enhanced sound or fired events | Replaced direct `FK.Statistics`/`FK.UI` calls with `FK.Events:Fire("FISHING_MISSED")`/`"FISHING_FAILED"`; Alerts now subscribes to `FISHING_FAILED` |
| (v1.3.2) | Every catch counted twice — `LOOT_READY` fires twice per loot window | Added `_lootProcessed` guard in `OnLootReady`, cleared on `FISHING_COMPLETE` and `FISHING_MISSED` |
| (v1.3.3) | PoolData: many Tanaris and other zone fishing pool coordinates placed inland instead of on the coastline | Corrected coordinates across 18 zones; removed inland entries and added GatherMate2-verified coastal positions |
| (v1.3.3) | `MergePoolData` only added entries, never pruned stale ones — removed/corrected static entries persisted in SavedVariables forever | Added pruning step: entries with `timesSeen=0` that no longer match static data are removed on load |

## Important API Behaviour (TBC Classic 2.5.5)

- `GetLootSlotInfo(slot)` → `texture, name, count, quality, locked` (5 values)
- `GetLootSlotLink(slot)` → item hyperlink string
- `GetNumLootItems()` → number of items (valid at `LOOT_READY`, may be 0 at `LOOT_OPENED` with auto-loot)
- `IsFishingLoot()` → `true` if loot source is fishing bobber
- `LOOT_READY` → fires when loot data is ready, before auto-loot runs
- `LOOT_OPENED` → fires when loot window opens (after auto-loot with auto-loot enabled)
- `UNIT_SPELLCAST_CHANNEL_STOP` fires when the fishing channel ends — in TBC Classic this fires at fish bite time, not at player click time
- **`UNIT_SPELLCAST_*` event signature**: TBC Classic Anniversary uses the modern `(unit, castGUID, spellID)` 3-arg format (spellID is arg3), not the old TBC `(unit, spellName, rank, lineID, spellID)` 5-arg format (spellID is arg5). Use `local spellID = arg5 or arg3` to support both. BetterFishing confirms this: it destructures `CHANNEL_START` as `local unit, _, spellID = ...`.
- `C_Timer.After(delay, func)` is available
- Item links follow pattern `item:(%d+)` for extracting itemID
- **`EquipItemByName` in combat**: only `"item:ID"` format works under combat lockdown. Item-name strings (e.g. `"Fool's Bane"`) and full hyperlinks (`|H...|h`) silently fail. Must be called immediately from `PLAYER_REGEN_DISABLED` — by the time `UNIT_INVENTORY_CHANGED` fires, lockdown is fully active.
- **Fishing poles don't displace slot 17**: equipping a pole in slot 16 does not unequip the offhand. `EquipItemByName` only searches bags, so if the offhand is already in slot 17 the call silently fails. Always check `GetInventoryItemLink("player", SLOT_OFFHAND)` before attempting to equip.
- **`UseContainerItem(bag, slot)`** — the legacy global does not exist on TBC Classic Anniversary; it is shimmed in Core.lua to `C_Container.UseContainerItem`. Works outside combat for opening containers.
- **`GLOBAL_MOUSE_DOWN`** — WoW event available in TBC Classic Anniversary. Fires with `arg1 = "RightButton"` (etc.) before click events are dispatched to frames. Setting `SetOverrideBindingClick` inside this handler takes effect for the current mouse-down event. `WorldFrame:HookScript("OnMouseDown")` fires too late — the input has already been dispatched.
- **`SecureActionButtonTemplate` + `type=macro` + `macrotext`** — use `/use bag slot\n/use 16` macrotext to apply a lure and target the fishing pole slot in one secure click. The `target-slot` attribute for `type=item` is not required in TBC Classic when using macrotext instead.

## Coding Conventions

- Module pattern: `local Stats = {}; FK.Statistics = Stats`
- Debug logging: `FK:Debug("message")`
- Settings access: `FK.db.settings.trackStats` (persisted SavedVariables)
- Session data: local `sessionData` table in Statistics.lua, reset on `StartSession()`
- All event handlers registered via `local events = { "EVENT_NAME", ... }` table and dispatched through `eventHandlers.EVENT_NAME = function(...) end`

## Versioning

This project follows **Semantic Versioning** (`MAJOR.MINOR.PATCH`):

| Change type | Version bump | Example |
|---|---|---|
| Breaking changes (SavedVariables schema incompatible, removed features) | MAJOR | `1.x.x` → `2.0.0` |
| New features (backwards-compatible) | MINOR | `1.0.x` → `1.1.0` |
| Bug fixes only (no new features) | PATCH | `1.1.x` → `1.1.1` |

Current series started at `1.0.x` for initial development; proper semver applied from `v1.1.0` onward.

### Beta Releases

Beta releases use the semver pre-release suffix: `MAJOR.MINOR.PATCH-beta.N` where `N` starts at 1 and increments for each beta of the same target version.

- The target version (`MAJOR.MINOR.PATCH`) reflects what the final release will be.
- The git tag **must** contain the word `beta` — e.g. `v1.3.0-beta.1`.
- `FishingKit.toc` `## Version:` is set to the full pre-release string (e.g. `1.3.0-beta.1`) so the in-game tooltip shows it is a beta.
- Beta releases get a `CHANGELOG.md` entry at the top using the full version string (e.g. `## v1.3.0-beta.1`).
- When the beta graduates to stable, drop the suffix: bump `## Version:` to `1.3.0`, retag as `v1.3.0`, and replace the beta `CHANGELOG.md` entry with the final one.

Examples:
| Scenario | Tag |
|---|---|
| First beta for next patch | `v1.2.5-beta.1` |
| Second iteration of same beta | `v1.2.5-beta.2` |
| First beta for next minor | `v1.3.0-beta.1` |

## Release Process

### Stable release

Before each stable release, update **all four** of the following in a single commit, then tag:

1. **`CLAUDE.md`** — update File Structure, State Machine, Bugs Fixed, and API notes to reflect changes in this release
2. **`CHANGELOG.md`** — add a new `## vX.Y.Z` section at the top (below the title) documenting new features, fixes, and files modified
3. **`README.md`** — update the version badge in Compatibility, and reflect any new features or config tab changes
4. **`FishingKit.toc`** — bump `## Version:`

Then commit and tag:
```
git add CLAUDE.md CHANGELOG.md README.md FishingKit.toc
git commit -m "chore: release vX.Y.Z"
git tag -a vX.Y.Z -m "vX.Y.Z"
```

### Beta release

Beta releases only require `CHANGELOG.md` and `FishingKit.toc` — no need to update `README.md` or `CLAUDE.md` until the stable release:

1. **`CHANGELOG.md`** — add a new `## vX.Y.Z-beta.N` section at the top
2. **`FishingKit.toc`** — set `## Version:` to `X.Y.Z-beta.N`

Then commit and tag:
```
git add CHANGELOG.md FishingKit.toc
git commit -m "chore: release vX.Y.Z-beta.N"
git tag -a vX.Y.Z-beta.N -m "vX.Y.Z-beta.N"
```
