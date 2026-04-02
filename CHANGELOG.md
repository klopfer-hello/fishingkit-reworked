# Extreme FishingKit - TBC Anniversary Edition - Changelog

## v1.3.4

### Bug Fixes

- **Addon broken on non-English WoW clients** — All spell names, item subtypes, zone names, and tracking names were hardcoded in English (e.g. "Fishing", "Find Fish", "Stranglethorn Vale", "Fishing Poles"), causing the addon to silently fail on localized clients (German "Angeln", etc.). Replaced all hardcoded strings with locale-independent API lookups:
  - Fishing spell name resolved dynamically via `GetSpellInfo(7620)`
  - Fishing pole detection via `GetItemSubClassInfo(2, 20)` + centralized `FK:IsFishingPoleItem()` helper
  - Double-click cast, macro button, and cast bar use localized spell name
  - Find Fish tracking lookup uses `GetSpellInfo(43308)` instead of English string
  - STV Fishing Extravaganza detection uses `C_Map` mapID (224) instead of English zone names
  - Lure tooltip scanning patterns use localized fishing spell name

### Files Modified

- `Core.lua` (localized spell/zone resolution, `IsFishingPoleItem()`, `IsFishingSpell()` cleanup, `IsInSTV()` mapID check)
- `modules/Equipment.lua` (replaced all English `"Fishing Pole(s)"` checks with `FK:IsFishingPoleItem()`, localized lure tooltip patterns)
- `modules/Pools.lua` (Find Fish tracking uses localized spell name)
- `modules/UI.lua` (cast button, cast bar, double-click use `FK.FishingSpellName`)

### Credits

- Thanks to Reddit user **u/S4ntaS4m** for reporting the localization issues and testing the fix.

---

## v1.3.3

### Bug Fixes

- **Incorrect fishing pool coordinates** — Corrected pool spawn coordinates across 18 zones (Tanaris, Azshara, Stranglethorn Vale, Feralas, The Hinterlands, Felwood, Western Plaguelands, Moonglade, Un'Goro Crater, Eastern Plaguelands, Burning Steppes, Winterspring, Deadwind Pass, Silithus, Scholomance, Stratholme, Zul'Gurub, and more). Removed inland entries and added GatherMate2-verified coastal positions.
- **Stale pool data persisted forever** — `MergePoolData` only added static entries to SavedVariables but never removed them when the static data was corrected. Added a pruning step that removes entries with `timesSeen=0` that no longer match any static PoolData entry.

### Files Modified

- `modules/PoolData.lua` (corrected coordinates across 18 zones)
- `modules/Pools.lua` (added stale entry pruning in `MergePoolData`)

---

## v1.3.2

### Bug Fixes

- **Catches double-counted** — `LOOT_READY` can fire twice for the same loot window (once for data-ready, once for auto-loot), causing every catch to be recorded twice. Added a `_lootProcessed` guard flag in `OnLootReady` that is cleared on `FISHING_COMPLETE` and `FISHING_MISSED`.

### Files Modified

- `modules/Statistics.lua` (loot-processed guard, `FISHING_COMPLETE` subscription)

---

## v1.3.1

*Re-release of v1.3.0 to trigger CurseForge stable upload (beta-to-stable tag conversion did not publish).*

---

## v1.3.0

### Bug Fixes

- **Enhanced audio while fishing not working** — `IsFishingSpell` always returned false for `UNIT_SPELLCAST_CHANNEL_START`/`CHANNEL_STOP` because TBC Classic Anniversary uses the modern 3-arg event signature `(unit, castGUID, spellID)` where spellID is arg3, not the old 5-arg format where spellID is arg5. This broke enhanced sound, cast timer, and the fishing state machine. Restored dual-signature handling with `arg5 or arg3` fallback, matching BetterFishing's approach.

- **Sound stuck after interrupted fishing** — `UNIT_SPELLCAST_INTERRUPTED` did not fire any event that restored enhanced sound. Replaced direct module calls with `FK.Events:Fire("FISHING_MISSED")`/`"FISHING_FAILED"`; Alerts now subscribes to `FISHING_FAILED`.

### Removed

- **Shattrath fishing daily quest tracker removed** — the feature was non-functional and has been removed entirely.

### Internal Refactoring

- **FK.Events pub/sub event bus** — Core.lua now fires named events (`FISHING_STARTED`, `BOBBER_LANDED`, `FISHING_BITE`, `FISHING_COMPLETE`, `ZONE_CHANGED`, etc.) instead of calling module methods directly. All modules subscribe in their `Initialize()` functions, decoupling the event source from the listeners.

- **State getter functions** — Added `FK:GetZone()`, `FK:GetSubZone()`, `FK:IsFishing()`, `FK:GetCastStartTime()`, `FK:GetFishingSkill()`, and `FK:HasLure()`. All modules now read state through these getters instead of accessing `FK.State.*` fields directly.

- **Named constants** — Magic numbers for loot delays and inventory slot numbers replaced with named locals.

- **`FK:ForEachBagSlot()` helper** — Bag iteration loops consolidated into a single shared iterator.

- **`StatsPanel.lua` extracted** — ~1000 lines of statistics window UI moved from `Statistics.lua` into a new `modules/StatsPanel.lua`.

- **`TryRestorePole` extracted** — Combat pole-restore retry logic extracted into a named function.

- **UI.lua section headers** — Frame creation and runtime sections labeled with clear boundary comments.

## v1.2.4

### Bug Fixes

- **Daily quest reminder fires even when quest was already turned in** — `IsQuestComplete()` only returns true while quest objectives are done but not yet handed in; it returns nil for already-turned-in quests. Replaced with `GetQuestsCompleted()[questID]` which correctly reflects daily quests completed (turned in) today until the next daily reset.

- **Zone Fish (%) panel stayed visible after closing main window** — `UI:Hide()` hid the main frame but not the ZoneFish panel anchored below it. Added explicit `FK.ZoneFish:Hide()` call in `UI:Hide()`. Also added missing `ZF:Hide()` and `ZF:Show()` methods to ZoneFish.lua (the missing method caused a silent Lua error).

### Performance

- **AH price scan is now much faster on repeat visits** — Each scan result is now timestamped in `ahPriceTimes`. Items priced within the last 4 hours are skipped on subsequent visits. The first daily scan still queries everything; follow-up visits to the AH skip already-fresh prices and complete almost instantly.

### Files Modified
- `modules/DailyQuests.lua` — `GetStatus`
- `modules/UI.lua` — `UI:Hide`
- `modules/ZoneFish.lua` — added `ZF:Hide`, `ZF:Show`; refactored `ZF:Toggle`
- `Core.lua` — `StartAHScan`, `ReadAHResults`, default db schema (`ahPriceTimes`)

## v1.2.3

### Bug Fixes

- **Daily quest reminder now fires when no quest has been picked up yet** — previously the login reminder only printed if the quest was already in the player's quest log; it was silent when the player hadn't visited Old Man Barlo yet, which is the most common case. Now reminds to visit Barlo when no daily is in progress and none has been completed today.

- **Stats panel now matches addon theme** — replaced WoW's native `UIPanelCloseButton` with a custom `×` close button; dimmed the "Statistics" title word to match Config/Daily panels; replaced `UIPanelScrollFrameTemplate` (WoW silver scroll bar) with a plain scroll frame, mousewheel scrolling, and a thin custom scroll thumb. Tab switches now reset scroll position to the top.

### Files Modified
- `modules/DailyQuests.lua` — `CheckLoginReminder`
- `modules/Statistics.lua` — `CreateStatsPanel`, `ShowTab`

## v1.2.2

### Meta
- Switched to CurseForge Automatic Packaging (removed GitHub Actions workflow)

## v1.2.1

### Meta
- Renamed addon to **Extreme FishingKit**
- Added CurseForge auto-release via GitHub Actions (`BigWigsMods/packager`)

## v1.2.0

### New Features

#### Shattrath Fishing Daily Tracker
- Tracks the 5 rotating Outland fishing daily quests offered by Old Man Barlo (Silmyr Lake, Terokkar Forest)
- Quests tracked: Crocolisks in the City, Fish Don't Leave Footprints, Felblood Fillet, Shrimpin' Ain't Easy, The One That Got Away
- Shows completion status for each quest: **Done** (green), **In Progress** (cyan), or **—** (dim, not offered today)
- Toggle the panel via `/fk daily` or the **Show Daily Tracker** button in Config > Auto
- `/fk daily print` prints the status to chat
- Login reminder: if an active fishing daily is in the quest log, prints a hint with the required fish and zone (toggle in Config > Auto > DAILY QUESTS)
- Panel updates live when a daily quest is turned in (`QUEST_TURNED_IN` event)
- New module: `modules/DailyQuests.lua`

#### Auto-Lure Reapply
- After each catch (on `LOOT_CLOSED`), Extreme FishingKit checks whether the fishing pole has an active lure
- If no lure is active, or the current lure expires within 5 seconds, the best lure found in bags is applied automatically via `UseContainerItem` + `UseInventoryItem(16)`
- **Double-click cast integration**: when double-right-clicking to cast with no lure active, a `SecureActionButton` injects a `/use bag slot` + `/use 16` macro on that click — lure is applied immediately, Fishing casts on the next double-click
- Uses `GLOBAL_MOUSE_DOWN` event (same approach as FishingBuddy) so `SetOverrideBindingClick` takes effect on the current mouse-down event
- Prints a confirmation message with the lure name and bonus on successful application
- Toggle on/off in **Config > Auto > LURE** section
- Files changed: `Core.lua`, `modules/Equipment.lua`, `modules/Config.lua`, `modules/UI.lua`

## v1.1.0

### New Features

#### Combat Weapon Swap
- **Auto-swap weapons on combat entry** — when a fishing pole is equipped and you enter combat, your saved combat weapons (mainhand + offhand) are immediately equipped using `EquipItemByName("item:ID", slot)` — the only format that works under combat lockdown
- **Pole restoration after combat** — after combat ends, only the fishing pole is restored (not the full fishing gear set, which would corrupt the normal gear save)
- `combatWeapons` saved separately in per-character DB from `normalGear`, so saving/restoring normal gear does not interfere with the combat weapon swap
- Guard prevents re-equipping a pole already in the mainhand slot (avoids picking it up and leaving an empty slot)
- Toggle on/off in the new **Automation** config tab

#### Zone Fish Panel
- **New expandable panel** anchored below the main HUD, toggled with the `%` button in the title bar
- Shows every fish/item caught in the current zone, sorted by catch rate (descending)
- Columns: fish name, count, and catch rate percentage (e.g. "Golden Darter 42.3%")
- Header shows current zone name; updates every 2 seconds while visible
- Pre-creates up to 12 FontString rows — no GC pressure on refresh
- Dynamically resizes to fit the number of entries
- Implemented as a standalone module (`ZoneFish.lua`)

#### Auto-Open Containers
- **Automatically opens fishing crates and scroll cases** after each fishing loot window closes
- Supported containers: Waterlogged Crate, Inscribed Scrollcase, Curious Crate, and other known fishing loot containers
- Items staggered 0.5 seconds apart to avoid server throttling
- Re-verifies each bag slot before opening in case inventory changed
- Toggle on/off in the new **Automation** config tab

#### Automation Config Tab
- New dedicated **Auto** tab in the config panel (between Routes and Stats)
- Consolidates all automation settings from their previous scattered locations:
  - **CASTING**: Double-right-click to cast
  - **GEAR**: Auto-save normal gear when equipping fishing gear; Auto swap weapons in combat
  - **LOOT**: Auto-open crates and scroll cases after fishing
  - **TRACKING**: Auto-enable Find Fish when equipping fishing gear

#### UI Redesign
- **Main panel** fully restyled with a clean minimal dark aesthetic — dark background, thin accent borders, no Blizzard template chrome
- **Config panel** matching redesign — flat tab buttons with accent underline for active tab, custom checkboxes (14px square with accent fill), custom slider (thin track + thumb)
- **Stats window** restyled to match the main panel theme
- All Blizzard icon/template buttons replaced with minimal styled text buttons

### Fixes
- **Cast timer reset on re-cast**: `castStartTime` now unconditionally set at `CHANNEL_START` — previously guarded by a nil-check which prevented it from updating on the second cast
- **Casts counted at resolution**: casts now counted at `CHANNEL_STOP` (fish bite / got away), not at `CHANNEL_START`, so cancelled casts before the bobber lands aren't counted
- **CHANNEL_STOP guard on re-cast**: stale `CHANNEL_STOP` from the previous bobber after a re-cast is ignored via `channelCastGen` comparison
- **Three session/cast tracking bugs**: fixed session state not resetting correctly, double-counting casts during rapid re-casts, and stale loot state persisting across sessions
- **Enhanced sound timing**: sound restore now matches BetterFishing timing exactly — restores after loot closes, not on channel stop

### Performance
- **SavedVariables size halved**: large history arrays (lootHistory, biteTimes) excluded from account-wide backup to reduce file size
- **Bite confidence cached per zone**: `GetBiteConfidence` result cached and invalidated only on new catches, eliminating redundant percentile recalculation on every frame
- **Split update rates**: cast bar updates at 0.1s; panel stats (session numbers, gold/hr) update at 1.0s — reduces CPU load during active fishing
- **Gold/hr display**: rate recalculated every 10s instead of every frame update

### Refactors
- **Addon reorganized** into `modules/` and `media/` subfolders for cleaner project structure
- `RecordCatch` split into focused local helpers for clarity
- Dead code from the old bag-diff catch approach removed
- History list trimming simplified from a while-loop to an if-check (lists are bounded)

### Files Modified
- `FishingKit.toc` (version 1.0.12 → 1.1.0, added `modules\ZoneFish.lua`)
- `Core.lua` (`combatWeapons` in defaultCharDB, `autoOpenContainers` setting, `PLAYER_REGEN_DISABLED/ENABLED` combat weapon handlers, `LOOT_CLOSED` auto-open trigger)
- `modules/Equipment.lua` (`EquipCombatWeapons`, `SaveNormalGear` saves `combatWeapons`, already-equipped guard)
- `modules/UI.lua` (full dark redesign, `%` Zone Fish toggle button, `AutoOpenContainers`)
- `modules/Config.lua` (full dark redesign, new `CreateAutomationTab`, settings moved from General/Gear/Pools)
- `modules/Statistics.lua` (RecordCatch refactor, SavedVariables size optimization)
- `modules/ZoneFish.lua` (new module)

---

## v1.0.12

### Changes
- **Updated interface version to 20505** (TBC Classic Anniversary 2.5.5)
- **Fixed catch tracking reliability** — replaced intermittent bag-diff approach with `LOOT_READY` + `IsFishingLoot()` (Blizzard built-in API). `LOOT_READY` fires before auto-loot processes items so the loot table is always populated. Catches are now tracked consistently regardless of auto-loot settings or player reaction time.

### Files Modified
- `FishingKit.toc` (interface 20504 → 20505, version 1.0.11 → 1.0.12)
- `Core.lua` (version string, LOOT_READY event registration and handler)
- `Statistics.lua` (OnLootReady replaces TakeBagSnapshot/OnLootClosed bag-diff logic)

---

## v1.0.11

### Improvements

#### Double-Click to Cast — Complete Rewrite
- **Completely rewritten** from the ground up using the `SetOverrideBindingSpell` approach (inspired by ZenFishing)
- Removed the broken `SecureActionButtonTemplate` approach which detected double-clicks but never actually cast the spell
- Removed `Bindings.xml` from the addon entirely — it caused XML parse errors on TBC Anniversary (Interface 20504) and was not needed for the double-click system
- **How it works now**: Double-right-click in the 3D world to cast Fishing. Single right-click behaves normally (loot bobber, interact, camera). `SetOverrideBindingSpell` binds BUTTON2 directly to the Fishing spell on double-click detection — no SecureActionButton, no PreClick/PostClick, no attributes
- Override binding cleared on every non-double-click (matching ZenFishing's `ClearClickHandler` pattern) so single clicks are never intercepted
- Override binding cleared on entering combat
- Loot window check (`LootFrame:IsShown()`) prevents double-click from firing while looting
- Minimum 0.05s / maximum 0.4s double-click detection window
- Default changed from **disabled** to **enabled** — works out of the box
- Toggle on/off in General config tab

#### Combat Recovery Reworked
- **Re-equip fishing gear after combat** — previously the addon swapped to normal/combat gear after combat ended, which made no sense while fishing. Now it re-equips your fishing gear so you can resume fishing immediately
- Chat message updated: "Combat detected! Will re-equip fishing gear when combat ends."
- Config checkbox renamed from "Auto-swap to normal gear on combat" to "Re-equip fishing gear after combat"

#### Community Pool Visibility Toggle
- **New config option**: "Show community (unconfirmed) pool pins" in the Pools tab
- When disabled, hides all community (chartreuse) pool pins from both minimap and world map
- Routes built with `/fk route` will only include your personally discovered pools when community pools are hidden
- Enabled by default — toggle off to see only your confirmed pool locations

### Fixes
- **Removed Bindings.xml from TOC** — this file caused XML parse errors on TBC Anniversary clients. Key bindings are handled via the WoW Key Bindings menu without needing a Bindings.xml file in the TOC load order
- **Fixed C_Container API crash** — TBC Classic (Interface 20504) does not have the `C_Container` namespace. Added a compatibility shim in Core.lua that creates `C_Container` wrapper functions around the legacy API (`GetContainerNumSlots`, `GetContainerItemLink`, `GetContainerItemInfo`, `PickupContainerItem`) so all code can use the `C_Container` namespace safely
- **Fixed `GetContainerItemInfo` return value handling** — TBC's legacy `GetContainerItemInfo` returns multiple values, while the `C_Container` version returns a table. The compatibility shim normalizes the return to always be a table with `.iconFileID`, `.stackCount`, `.itemLink`, `.quality`, and `.isLocked` fields
- **Fixed config panel overflow** — config panel split into 6 tabbed sections to prevent checkboxes from overflowing the panel bounds. Tab labels shortened to fit
- **Fixed lure icon display** — lure button icon now correctly shows the actual lure item texture instead of a generic icon

### Files Modified
- `Core.lua` (v1.0.11, C_Container compatibility shim, combat recovery rework, doubleClickCast default true, new showCommunityPools setting)
- `UI.lua` (double-click casting complete rewrite using SetOverrideBindingSpell, removed SecureActionButton/PreClick/PostClick approach, lure icon fix)
- `Config.lua` (combat checkbox label updated, community pools checkbox, doubleClickCast default true, 6-tab layout)
- `Pools.lua` (community pool filtering in minimap and world map pin rendering)
- `Navigation.lua` (community pool filtering in BuildRoute)
- `FishingKit.toc` (Bindings.xml removed from load order)
- `CHANGELOG.md`
- `fishing.md`

---

## v1.0.10

### Code Quality & Compliance Audit

Full codebase audit for API compliance, memory safety, documentation accuracy, and engineering best practices.

#### Critical Fixes
- **Fixed STV Fishing Contest detection** — `IsContestActive()` relied solely on C_DateAndTime which doesn't exist in all clients. Added Lua `date()` fallback so contest detection works regardless of API availability

#### AH Panel Fixes
- **Fixed AH price list overflowing panel bounds** — Content frame now properly inset from AuctionFrame edges (TOPLEFT +12/-10, BOTTOMRIGHT -8/+37) matching Auctionator's wrapper pattern. Bottom clearance increased from 10px to 37px to clear the tab buttons
- **Removed broken SetClipsChildren calls** — This API doesn't exist in Classic/TBC WoW. ScrollFrame natively clips its viewport
- **Added column headers** — "Fish" and "Price Per Unit" header labels above the scroll area
- **Scroll child width set dynamically** — Uses OnSizeChanged callback instead of hardcoded width, properly resolves after anchor layout
- **Fixed FontString memory leak** — AH price list now uses FontString pooling instead of creating new FontStrings on every refresh. Old pattern leaked orphaned FontStrings that accumulated indefinitely

#### Nil Safety & Defensive Checks
- **Equipment.lua** — GetItemIDFromLink result now checked for nil before comparison in EquipItemByLink
- **Core.lua** — Nested C_Timer callbacks for combat gear swap now guard FK.Equipment existence
- **Alerts.lua** — StartWatching frame cached in alertState._watchFrameCache and reused instead of creating new unnamed frames each start/stop cycle
- **Slash commands** — `/fk scale` now gives explicit error messages for non-numeric input and out-of-range values instead of silently doing nothing

#### Documentation Fixes
- **Zone count corrected** — fishing.md claimed 68 zones, actual database contains 95 zones
- **Pool counts corrected** — Was 654, actual is 653 (both fishing.md and CHANGELOG.md)
- **Missing slash commands documented** — Added `/fk route recalc` alias notation
- **Bindings.xml TOC note corrected** — v1.0.6 changelog incorrectly stated Bindings.xml was "auto-loaded by WoW (not listed in TOC)"

### Files Modified
- `FishingKit.toc` (version bump)
- `Core.lua` (v1.0.10, IsContestActive fallback, AH panel rewrite, FontString pooling, nil guards, slash command validation)
- `Equipment.lua` (nil guard on GetItemIDFromLink)
- `Alerts.lua` (frame reuse guard in StartWatching)
- `CHANGELOG.md`
- `fishing.md` (zone count, pool count, slash command, version bump)

---

## v1.0.9

### New Features

#### Pre-filled Pool Spawn Database (PoolData.lua)
- Ships with 653 known pool spawn locations across 27 zones (24 Classic + 3 TBC)
- All coordinates sourced from Wowhead — real spawn data, not estimates
- Map pins appear immediately on first install — no discovery needed
- Static data merges with user-discovered pools (user pools always take precedence)
- Community pools shown in chartreuse (yellow-green) to distinguish from discovered pools (cyan)
- Tooltip shows "Community Pool Data" with "Fish here to confirm this location" hint
- Once you fish at a community pool, it converts to a confirmed discovered pool (cyan)

#### Community vs Discovered Pool Pins
- Two-color pin system for instant visual distinction on maps
- **Chartreuse (yellow-green)**: Community pool data from the pre-filled database (unconfirmed)
- **Cyan (teal)**: Pools you've personally discovered or confirmed by fishing
- Tooltips show source: "Community Pool Data" or "Seen: X time(s)" with last-seen timestamp
- Applies to both minimap pins and world map pins

#### Navigation Arrow Pool Info (TBC)
- Arrow frame enlarged to show full pool metadata
- Displays pool name, coordinates, source tag, and waypoint counter
- Source shown as "Community" (chartreuse) or "Discovered (Xx seen)" (green)
- Community pools show "Unconfirmed location"; discovered pools show "Last seen: Xh ago"
- Coordinates displayed in bottom-right corner of the arrow frame

#### Bag Space in Footer Bar
- New center element in the footer shows "Bags: free/total" at all times
- Color-coded: green (>10 free), orange (5-10), red (<5), flashing "Bags FULL!" at 0

#### Catch Percentage per Fish
- Each fish in the "Fish Caught" stats tab now shows its percentage of total catches
- New "%" column header alongside Fish and Count

#### Top 5 Catches Ranking
- Gold-highlighted "Top 5 Catches" section at the top of the Fish Caught tab
- Numbered ranks (1-5) with quality-colored names, counts, and percentages

#### Rare Fish Tracker
- Dedicated "Rare Fish" section in the Fish Caught tab
- Shows all rare fish from the database with catch status and personal drop rates
- "Discovered: X/Y" summary counter
- Uncaught rare fish displayed in gray with "Not yet caught" text
- Added Old Ironjaw, Old Crafty, and Speckled Tastyfish as rare catches

#### Cycle Fish Time Windows
- Nightfin Snapper (18:00-06:00) and Sunscale Salmon (06:00-18:00) now tracked by server time
- Zone info panel shows "Nightfin: NOW" (green) or "Nightfin: 18:00" (gray) when in relevant zones
- Chat alert fires when a time window opens while you're in an applicable zone
- Integrates with existing seasonal fish display (Winter Squid, Summer Bass)
- Toggle alerts in Config > Alerts > "Cycle fish time window alerts"

#### Automatic SavedVariable Backups
- Auto-backup every 24 hours on login (10-second delay for stability)
- `/fk backup` — Force an immediate backup
- `/fk backup restore` — Restore from last backup (confirmation dialog, requires /reload)
- `/fk backup info` — Show last backup timestamp and age
- Backs up both global (account-wide) and per-character saved variables

---

## v1.0.8

### New Features

#### Double-Click to Cast (Initial Implementation)
- Double-right-click anywhere to cast Fishing
- Initial implementation using SecureActionButtonTemplate with override binding
- 0.05-0.4 second double-click detection window
- Binding automatically cleared during combat
- Toggle on/off in General config tab
- **Note**: This implementation had issues — the SecureActionButton detected double-clicks but the spell cast did not reliably fire. Completely rewritten in v1.0.11 using SetOverrideBindingSpell

#### Persistent Footer Bar
- New footer bar at the bottom of the panel, always visible even when collapsed
- Left side: last fish caught (name and quantity, stays for 5 minutes)
- Right side: "2x Click to Cast" indicator when double-click casting is enabled
- Replaced previous title bar indicator and cast bar last-catch display

### Improvements

#### Reliable Cast Bar
- Cast bar now uses UnitChannelInfo/UnitCastingInfo as authoritative source of truth
- Self-healing: if WoW API says the player is fishing but addon state is corrupted, state is automatically restored
- Eliminates cast bar desync issues during rapid double-click recasting

#### Accurate Cast Counting
- Casts counted when bobber hits the water (CHANNEL_START event) for reliable tracking
- Fish got away events properly counted as valid casts with gotAway stat
- User cancellations during cast animation (before bobber deployed) are not counted
- Uses castGen counter to prevent stale events from corrupting state

#### Debug Print Cleanup
- Converted all hardcoded debug prints to FK:Debug() (only visible with `/fk debug`)
- Removed user-facing debug spam from event handlers and double-click system
- User-facing prints (help text, goal listing, release list) unchanged

### Fixes
- Fixed cast bar not resetting properly during rapid double-click recasting
- Fixed last fish caught display being immediately overwritten by idle text
- Fixed stale LOOT_CLOSED events resetting state for new casts (lootCastGen tracking)
- Fixed stale SPELLCAST_FAILED/INTERRUPTED events from old casts corrupting new cast state

### Files Modified
- `Core.lua` (v1.0.8, double-click setting, castGen counter, channelStarted flag, CHANNEL_START cast counting, debug print cleanup)
- `UI.lua` (double-click casting system, footer bar, UnitChannelInfo self-heal in cast bar, debug print cleanup)
- `Statistics.lua` (UndoCastCount method for interrupted casts)
- `Config.lua` (double-click casting toggle in General tab)
- `FishingKit.toc` (version bump to 1.0.8)
- `CHANGELOG.md`
- `fishing.md`

---

## v1.0.7

### New Features

#### Pool Route Navigation
- TomTom-style navigation arrow points to the next pool in your route
- Nearest-neighbor TSP algorithm builds optimized routes through discovered pools
- Route starts from the nearest pool to the player
- Numbered waypoints visible on the world map with colored connecting lines (SilverDragon-style MapCanvas pin approach)
- Current waypoint segment highlighted in green, others in cyan
- Arrow shows pool name, distance in yards, ETA, and waypoint counter
- Arrow color changes based on direction accuracy (bright cyan = on target, dim = wrong direction)
- Distance text color-coded: green (close), yellow (medium), white (far)
- Automatic arrival detection advances to next waypoint
- Right-click arrow to skip a waypoint
- Arrow hides in combat, returns after
- Arrow position is draggable and persists across sessions
- New pool discoveries auto-inserted into active route via cheapest-insertion algorithm
- Route auto-rebuilds when changing zones
- Falls back gracefully if player position is unavailable

#### Route Button
- New **Route** button on the main panel between Stats and Config
- One-click to start/stop pool route navigation
- Green background indicator when route is active
- Tooltip shows route status, pool count, and usage instructions

#### GatherMate2 Import
- Import fishing pool data from GatherMate2: `/fk import gathermate`
- Deduplicates against existing pool data
- Maps GatherMate2 node IDs to pool names for both Classic and TBC pools
- Reports import count by zone

#### Navigation Config
- New "Pool Route Navigation" section in the Pools config tab
- Enable/disable pool navigation toggle
- Show/hide navigation arrow toggle
- Show/hide route on world map toggle
- Waypoint arrival sound toggle
- Arrival distance slider (10-40 yards)
- Start/Stop Route, Skip Waypoint, Recalculate, and Import GatherMate2 buttons

### Fixes
- Fixed world map route lines not rendering: WorldMapFrame is load-on-demand and wasn't available at init time. Added lazy hooking via UpdateWorldMapRoute, DrawRouteOnWorldMap, and ADDON_LOADED listener for Blizzard_WorldMap
- Fixed pool deduplication being too aggressive (0.02 / ~20 yards → 0.005 / ~5 yards): nearby but distinct pool spawn points were being merged and positions overwritten. Now only deduplicates when pool name matches AND distance is within ~5 yards, and no longer overwrites existing pool positions
- Fixed BuildRoute silently failing when C_Map.GetPlayerMapPosition returns nil: now falls back to starting from the first pool instead of aborting

### Files Added
- `Navigation.lua` (route building, arrow, world map lines, GatherMate2 import)
- `arrow.tga` (TomTom-style arrow spritesheet, 1024x1024, 108 frames)

### Files Modified
- `FishingKit.xml` (added FishingKitRoutePinTemplate, FishingKitRouteConnectionTemplate for world map route lines)
- `Core.lua` (v1.0.7, new settings: poolNavEnabled, poolNavArrow, poolNavWorldMapRoute, poolNavArrivalDistance, poolNavSound; Navigation init/combat/zone hooks; route/import slash commands)
- `UI.lua` (Route button between Stats and Config, UpdateRouteButton, green active indicator)
- `Config.lua` (Pool Route Navigation section with checkboxes, slider, and action buttons in Pools tab)
- `Pools.lua` (pool dedup range fix 0.02→0.005, name-matching required for dedup, no position overwrite)
- `FishingKit.toc` (version bump to 1.0.7)
- `CHANGELOG.md`
- `fishing.md`

---

## v1.0.6

### New Features

#### Tooltip Enrichment
- Hovering over any fish item (bags, AH, loot, trade) shows Extreme FishingKit data
- Displays: total caught, catch zones, minimum skill requirement, seasonal availability
- Shows cached AH price per unit and your best personal catch zone
- Skill requirement shown in green (met) or red (not met)

#### Gold Tracking
- Vendor gold/hour displayed on the main panel session stats row
- AH gold/hour shown alongside vendor value when AH prices are available
- Vendor prices read live from GetItemInfo sell price at runtime (no hardcoded values)
- AH prices scanned automatically when you visit the Auction House (up to 20 fish per visit)
- AH prices cached account-wide in saved variables for cross-session use
- Stats panel Overview tab shows total vendor value, AH value, and per-hour rates
- "Visit AH to scan prices" hint shown when no AH data exists

#### Fish Zone Browser
- New "Zone Fish" tab in the statistics panel (5 tabs total now)
- Shows all catchable fish in your current zone sorted by quality
- Columns: fish name (quality colored), skill requirement, personal catch count, value
- Skill column green if you meet the requirement, red if not
- Value column shows AH price if scanned, otherwise vendor price
- Lists all fishing pool types available in the zone
- Seasonal notes section for time-limited fish (Winter Squid, Summer Bass)

#### STV Fishing Extravaganza Support
- Compact gold-bordered contest bar appears above the main panel
- Only visible when in Stranglethorn Vale during Sunday 2-4 PM server time
- Displays Tastyfish count (X/40) with a gold progress bar
- Shows minutes remaining in the contest
- "Turn in to win!" message when you reach 40 Tastyfish
- Completely hidden outside contest hours or when not in STV

#### Key Bindings
- Extreme FishingKit actions appear in the WoW Key Bindings menu under "Extreme FishingKit" header
- Bindable actions: Toggle Panel, Swap Fishing/Normal Gear, Apply Lure (Info), Toggle Statistics, Toggle Settings
- Access via Game Menu > Key Bindings > Extreme FishingKit
- Bindable actions available in Game Menu > Key Bindings > Extreme FishingKit

#### Session Efficiency Trend
- Stats panel Overview tab now includes a fish/hour bar graph over time
- Catches tracked in 5-minute interval buckets throughout the session
- Color-coded bars: green (high efficiency), yellow (medium), orange (low) relative to your best bucket
- Shows time range and exact fish/hour for each interval
- Appears after your first 5-minute interval completes

#### Seasonal/Time Notes
- Zone panel shows a subtle note below zone skill info when seasonal fish are available
- In-season fish shown in light blue (winter) or warm gold (summer) text
- Out-of-season fish shown in gray with "(winter only)" or "(summer only)" label
- Only displays for zones that contain seasonal fish

#### Bite Timing Confidence Band
- Cast bar now displays a semi-transparent green band during fishing
- Band highlights the 35th-65th percentile window where bites most likely occur
- Thin bright green vertical line marks the median bite time
- Based on your actual successful catch timing data per zone
- Requires minimum 5 catches in a zone before the band appears
- Bite timing data persists across sessions and improves with more catches
- Band hidden when not actively fishing

### Fixes
- Bindings.xml removed from TOC file (WoW auto-loads it; listing it caused XML parse error)

### Files Added
- `Bindings.xml` (key binding definitions, auto-loaded by WoW)

### Files Modified
- `Core.lua` (v1.0.6, AH price scanning with AUCTION_HOUSE events, STV contest functions, keybind labels, biteTimings in chardb, ahPrices in global DB, FormatCopper utility)
- `UI.lua` (GameTooltip hook for fish enrichment, gold/hr display row, seasonal note FontString in zone panel, STV contest panel, bite confidence band and median marker textures, frame height 330→340)
- `Statistics.lua` (vendor/AH copper tracking in RecordCatch and session data, Zone Fish tab, efficiency bucket tracking, bite timing recording and percentile calculation, tab count 4→5, tab width 100→80)
- `FishingKit.toc` (version bump to 1.0.6)
- `CHANGELOG.md`
- `fishing.md`

---

## v1.0.5

### New Features

#### Catch Rate Display
- Zone panel now shows your catch rate percentage with color coding
- Red (<25%), orange (<50%), yellow (<75%), green (75%+), bright green (100%)
- Calculated from your effective skill vs zone no-getaway threshold

#### Fish-to-Level Counter
- Skill bar now shows estimated catches needed for next fishing skill level
- Uses pre-3.1 TBC formula: 1 catch at skill ≤75, then ceil((skill - 75) / 25) at higher levels
- Shows "Max" when at skill cap (375)

#### Fishing Skill Above Fish Button
- Current fishing skill level displayed above the Fish button
- Visible even when the panel is collapsed for quick reference
- Light blue text matching the effective skill color scheme

#### Enhanced Fishing Sound
- Automatically boosts SFX volume to maximum when fishing for easier splash detection
- Lowers ambience volume slightly to make splash more prominent
- Restores original volume settings when fishing is truly complete (after loot window closes)
- Sound restore correctly timed: happens on LOOT_CLOSED or 1-second timeout, not on channel stop
- All SetCVar calls wrapped in pcall with string values for TBC compatibility
- Toggle in Alerts config tab

#### Missing Lure Warning
- Periodic chat warning when fishing without an active lure
- Warns once per 60 seconds (configurable) while fishing with a pole but no lure
- Only triggers when a fishing pole is equipped
- Toggle in Alerts config tab

#### Fishing Goals
- Set catch targets per session: `/fk goal Stonescale Eel 50`
- Goal progress shows on the idle status line when not casting
- Color-coded progress: gold while in progress, yellow when ≥75%, green when complete
- Multiple goals supported; first incomplete goal shown on cast bar
- Fish matched by name against catch history and Database.lua
- `/fk goal` to list active goals, `/fk goal clear` to reset all

#### Auto-Combat Gear Swap
- Detects entering combat while a fishing pole is equipped
- Chat warning: "Combat detected! Will swap to normal gear when combat ends."
- Automatically swaps to saved normal gear when combat ends
- 1-second delay after PLAYER_REGEN_ENABLED for lockdown to fully clear
- Retry logic if InCombatLockdown() still true after first attempt
- Helpful message if no normal gear saved: "Use /fk savegear normal"
- Toggle in Equipment config tab

#### Milestone Celebrations
- Sound and chat celebration at 100, 250, 500, 1000, 2500, 5000, 10000 total catches
- Green flash on the panel when a milestone is reached
- Uses rare item sound effect for celebration
- Toggle in Alerts config tab

#### Catch & Release
- Mark junk fish for automatic deletion on catch: `/fk release Driftwood`
- Only works on gray (quality 0) and white (quality 1) items for safety
- Higher quality items rejected with error message
- Fish looked up by name in catch history and Database.lua
- Auto-delete runs 0.3 seconds after loot window closes
- `/fk release` to list items, `/fk release clear` to reset list

### Fixes
- Fixed enhanced sound restore timing: sound was being restored on UNIT_SPELLCAST_CHANNEL_STOP which fires BEFORE the loot window opens, causing sound to revert too early. Created separate OnFishingComplete() method called from LOOT_CLOSED and timeout instead.
- Fixed SetCVar calls passing wrong types: TBC Classic requires string values for SetCVar. Wrapped all calls in pcall and added nil check on GetCVar return values.
- Fixed combat gear swap delay: increased from 0.5s to 1.0s and added retry logic for cases where InCombatLockdown() still returns true briefly after PLAYER_REGEN_ENABLED.

### Files Modified
- `Core.lua` (v1.0.5, new settings: enhancedSound, missingLureWarning, missingLureInterval, autoCombatSwap, milestones; new chardb fields: goals, releaseList; ProcessReleaseList function; combat swap in REGEN handlers; OnFishingComplete calls in LOOT_CLOSED and timeout; goal/release slash commands with full parsing; updated help text)
- `UI.lua` (catch rate % in zone panel, fish-to-level in effective skill text, goal progress on idle cast bar line, fishing skill text above Fish button, frame height adjustments)
- `Statistics.lua` (MILESTONES table, CheckMilestone, GetSessionFishCount, GetSessionFishCountByName, GetGoalProgress)
- `Alerts.lua` (enhanced sound state tracking, BoostFishingSound with pcall/string SetCVar, RestoreFishingSound, CheckMissingLure on OnUpdate, OnFishingComplete for sound restore, removed RestoreFishingSound from OnFishingEnd)
- `Config.lua` (new checkboxes: milestone celebrations, enhanced sound, missing lure warning in Alerts tab; auto-combat swap in Equipment tab; updated ResetToDefaults)
- `Database.lua` (added GetFishIDByName helper for goal/release name lookups)
- `FishingKit.toc` (version bump to 1.0.5)
- `CHANGELOG.md`

---

## v1.0.4

### New Features

#### Collapsible Panel
- Added collapse/expand toggle button (minus/plus icon) on the title bar
- Collapsed mode hides the middle section (skill bar, zone info, session stats, lure timer)
- Only the cast bar and action buttons remain visible when collapsed
- Panel resizes automatically to a compact form
- Collapse state persists across sessions

### Fixes
- Fixed catch notification text overlapping the lure countdown timer above the Lure button
- Catch notifications now display inline on the cast bar status line instead of a separate overlay

### Files Modified
- `UI.lua` (collapse toggle, ApplyCollapsedState, ToggleCollapse, catch text fix)
- `Core.lua` (added `collapsed` setting to defaults)
- `FishingKit.toc` (version bump to 1.0.4)
- `CHANGELOG.md`

---

## v1.0.3

### Zone Skill Accuracy Overhaul
- Corrected 9 zones with wrong no-getaway skill values:
  - Arathi Highlands: noGetaway 150 → 225
  - Redridge Mountains: noGetaway 75 → 150
  - Eastern Plaguelands: noGetaway 300 → 425
  - Feralas: noGetaway 225 → 300
  - The Hinterlands: noGetaway 225 → 300
  - Western Plaguelands: noGetaway 225 → 300
  - Swamp of Sorrows: noGetaway 425 → 225
  - Thousand Needles: noGetaway 300 → 225
  - Un'Goro Crater: noGetaway 375 → 300
- All zone skill values verified for pre-3.1 TBC Classic accuracy

### New Zones
- Added 3 missing cities: Shattrath City, Silvermoon City, The Exodar
- Added 8 fishable instances/raids: Blackfathom Deeps, The Deadmines, Scarlet Monastery, Maraudon, The Temple of Atal'Hakkar, Scholomance, Stratholme, Zul'Gurub
- Total fishable zones now: 68

### Improvements
- Reorganized all zones by fishing skill tier for clarity
- Removed incorrect "recommended" field from zone entries

### Files Modified
- `Database.lua` (zone skill corrections, added 11 zones)
- `FishingKit.toc` (version bump to 1.0.3)
- `CHANGELOG.md`

---

## v1.0.2

### Database Expansion

#### Complete Fish Database
- Added all missing Classic fish: Raw Spotted Yellowtail, Raw Sagefish, Raw Greater Sagefish, Speckled Tastyfish, Globe of Water
- Added missing TBC fish: Felblood Snapper (27441), Monstrous Felblood Snapper (34867), Mote of Water (22578), Mr. Pinchy (27388)
- Fixed duplicate item ID 6359 (was incorrectly listed as both "Raw Rockscale Cod" and "Oily Blackmouth")
- Added zone information to every fish entry
- Fixed quality ratings (Stonescale Eel, Lightning Eel, Deviate Fish)

#### Complete Zone Database
- Added ~30 missing Classic Azeroth zones with correct skill thresholds
- Starting zones: Dun Morogh, Tirisfal Glades, Eversong Woods, Mulgore, Teldrassil, Azuremyst Isle, Bloodmyst Isle
- Low zones: Loch Modan, Silverpine Forest, Darkshore, Ghostlands
- Mid zones: Wetlands, Hillsbrad Foothills, Ashenvale, Stonetalon Mountains
- Upper zones: Alterac Mountains, Arathi Highlands, Swamp of Sorrows, Desolace, Dustwallow Marsh
- High zones: The Hinterlands, Western Plaguelands, Felwood, Moonglade, Un'Goro Crater
- Max zones: Eastern Plaguelands, Burning Steppes, Deadwind Pass, Winterspring, Silithus
- Cities: Stormwind, Ironforge, Undercity, Orgrimmar, Thunder Bluff, Darnassus
- TBC: Isle of Quel'Danas

#### Complete Pool Database
- Added all missing Classic pools: Sagefish School, Greater Sagefish School, School of Tastyfish, Floating Wreckage Pool, Waterlogged Wreckage Pool, Bloodsail Wreckage Pool, Schooner Wreckage, Patch of Elemental Water, Floating Debris, Oil Spill, Mixed Ocean School
- Added missing TBC pools: Brackish Mixed School, Feltail School, Pure Water
- Updated all zone pool lists to include correct pools per zone

### Fixes
- Fixed pool detection not recognizing Brackish Mixed School and other "X School" named pools (pattern was "School of" which only matched "School of X" format)
- Replaced hardcoded pool pattern guesses with complete pool name list
- Added Felblood Snapper to Hellfire Peninsula and Shadowmoon Valley fish lists
- Added Mote of Water to Nagrand fish list
- Added Feltail School to Terokkar Forest and Shadowmoon Valley pool lists

### Files Modified
- `Database.lua` (major expansion: complete fish, zone, and pool databases)
- `Pools.lua` (complete pool name list for Classic + TBC)
- `FishingKit.toc` (version bump to 1.0.2)
- `CHANGELOG.md`
- `fishing.md` (updated documentation with v1.0.1 features)

---

## v1.0.1

### New Features

#### Pool Map Markers
- Discovered fishing pools are now marked on both the minimap and world map
- Colored circle pins (cyan/teal) show pool locations with hover tooltips
- Tooltips display pool name, times seen, last seen, and coordinates
- Pool locations persist across logout/reload (stored account-wide)
- Pools detected on mouseover (tooltip alert) and recorded at close range
- Fishing a pool refines its pin to the most accurate position
- Position uses 15-yard facing offset for accurate pin placement
- Minimap pin math uses world coordinate conversion with indoor/outdoor yard radius and rotation support
- World map pins use MapCanvasDataProviderMixin with AcquirePin pattern
- `/fk pools` - list discovered pools in current zone
- `/fk pools clear` - clear all pool data
- `/fk pools clearzone` - clear pool data for current zone only

#### Auto Find Fish Tracking
- Automatically enables Find Fish minimap tracking when equipping fishing gear
- Restores previous tracking type (e.g. Find Herbs) when unequipping
- Requires the Find Fish ability (Weather-Beaten Journal)

#### Pools Config Tab
- New dedicated "Pools" tab in the config panel
- Toggle pool detection on/off
- Toggle pool discovery sound alert
- Toggle minimap/world map pin display
- Toggle auto Find Fish tracking
- View discovered pool count
- Clear Zone Pools / Clear All Pools buttons with confirmation

#### Openable Containers
- Added Curious Crate (27513) to openable items
- Fixed Inscribed Scrollcase item ID (27511, was 27482)
- Improved bag scanning to handle both C_Container and legacy API paths

### Fixes
- Fixed Find Fish tracking API to use `C_Minimap.GetNumTrackingTypes()` and `C_Minimap.GetTrackingInfo()` for TBC Anniversary compatibility
- Fixed pool timesSeen counter incrementing on every mouseover (now requires 5-minute cooldown between increments)
- Fixed pool detection patterns to avoid false positives (removed broad patterns like "Swarm", "Pool", "Patch")

### Files Added
- `FishingKit.xml` (world map pin template)
- `track_circle.tga` (circle texture for map pins)
- `CHANGELOG.md`

### Files Modified
- `Core.lua` (new settings, events, slash commands, LOOT_OPENED hook)
- `Pools.lua` (major expansion: persistent storage, map pins, Find Fish)
- `Equipment.lua` (Find Fish hooks in equip/unequip)
- `Config.lua` (new Pools tab, Statistics moved to tab 5)
- `UI.lua` (added Curious Crate, fixed Inscribed Scrollcase ID, improved bag scan)
- `FishingKit.toc` (added FishingKit.xml)
