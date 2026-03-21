# FishingKit — Personal Fork

This is a personal fork of the original **FishingKit** addon for World of Warcraft TBC Classic Anniversary.

**Original addon:** https://www.curseforge.com/wow/addons/fishingkit-tbc-anniversary-edition

All credit for the original work goes to the original author. This fork exists purely for personal use and adds features I personally enjoy as well as fixes for bugs I encountered while fishing.

---

# FishingKit - TBC Anniversary Edition

## Description

**FishingKit** is a comprehensive fishing companion addon for World of Warcraft: The Burning Crusade Classic (Anniversary Edition). It provides everything you need for an enhanced fishing experience - from gear management and lure tracking to detailed statistics, gold tracking, auction house price scanning, and quality-of-life improvements.

## Features

### 📊 Main Fishing Panel
- **Skill Display** - Shows your current fishing skill with progress bar and fish-to-level counter
- **Skill Above Fish Button** - Current skill level always visible above the Fish button, even when collapsed
- **Effective Skill** - Calculates total skill including gear and lure bonuses with catches-to-level estimate
- **Zone Information** - Displays zone skill requirements, no-getaway threshold, and color-coded catch rate percentage (95 zones)
- **Seasonal & Time-of-Day Notes** - Shows seasonal fish status (Winter Squid, Summer Bass) and time-window fish (Nightfin Snapper, Sunscale Salmon) with real-time availability
- **Live Cast Bar** - Visual progress bar while fishing with elapsed time, catch notifications, and bite confidence band
- **Bite Confidence Band** - Green highlight on the cast bar showing the most likely bite window based on your catch history
- **Session Statistics** - Track casts, catches, success rate, fish per hour, and gold per hour in real-time
- **Lure Timer** - Countdown timer showing remaining lure duration with color coding (green/orange/red)
- **Goal Progress** - Active fishing goals display on the idle status line
- **Collapsible View** - Collapse the panel to show only the cast bar and action buttons for a compact layout
- **STV Contest Bar** - Compact Tastyfish counter and timer appears above the panel during the Fishing Extravaganza

### 🎣 Quick Action Buttons
- **Fish** - One-click casting (secure action button) with skill level displayed above
- **Gear** - Instantly swap between fishing gear and normal equipment
- **Lure** - Automatically applies your best available lure to your fishing pole
- **Open** - Quickly open clams, crates, and containers caught while fishing
- **Stats** - Access comprehensive lifetime statistics with 5 tabbed views
- **Route** - Start/stop pool route navigation with world map lines and arrow
- **Config** - Addon settings and configuration

### 🖱️ Double-Click to Cast
- Double-right-click anywhere in the 3D world to cast Fishing instantly
- Uses `SetOverrideBindingSpell` to bind BUTTON2 directly to the Fishing spell on double-click detection (ZenFishing-style approach)
- Single right-click behaves normally (loot bobber, interact with NPCs, rotate camera)
- Override binding automatically cleared on every non-double-click so single clicks are never intercepted
- Skips firing while the loot window is open
- Binding cleared on entering combat
- 0.05-0.4 second double-click detection window
- Enabled by default — toggle on/off in General config tab

### 📊 Persistent Footer Bar
- Always-visible footer at the bottom of the panel, even when collapsed
- Shows last fish caught (name and quantity, persists 5 minutes)
- Shows bag space counter with color coding (green/orange/red/FULL!)
- Shows "2x Click to Cast" indicator when double-click casting is enabled

### 🎒 Equipment Management
- Save your fishing gear set (pole, hat, boots, gloves)
- Save your normal combat gear set
- One-click swap between gear sets
- Automatically saves normal gear before equipping fishing gear
- Persists across sessions - never lose track of your gear

### ⚔️ Auto-Combat Fishing Recovery
- Detects entering combat while fishing pole is equipped
- Chat warning when combat is detected
- Automatically re-equips fishing gear when combat ends so you can resume fishing immediately
- Retry logic for reliable lockdown-safe swapping (up to 10 attempts)
- Toggle on/off in Equipment config tab

### 🪱 Smart Lure System
- Automatically detects the best lure in your bags
- One-click lure application with secure macro
- **Live lure timer** that reads the actual bonus from your fishing pole tooltip
- Color-coded countdown: Green (>60s), Orange (>30s), Red (<30s)
- Audio warning when lure is about to expire (30 seconds)
- **Missing lure warning** - periodic alert when fishing without an active lure
- Works correctly even for lures applied before logging in

### 🗺️ Complete Zone Database
- **68 fishable zones** with accurate skill requirements for TBC Classic (pre-3.1)
- Every zone includes minimum skill to cast and no-getaway skill for 100% catch rate
- **Starting Zones**: Elwynn Forest, Dun Morogh, Durotar, Mulgore, Teldrassil, Tirisfal Glades, Eversong Woods, Azuremyst Isle
- **Classic Zones**: All Azeroth zones from Westfall to Winterspring
- **TBC Zones**: Hellfire Peninsula, Zangarmarsh, Terokkar Forest, Nagrand, Netherstorm, Blade's Edge Mountains, Shadowmoon Valley, Isle of Quel'Danas, Skettis Lakes
- **Cities**: Stormwind, Ironforge, Undercity, Orgrimmar, Thunder Bluff, Darnassus, Shattrath City, Silvermoon City, The Exodar
- **Instances & Raids**: Blackfathom Deeps, The Deadmines, Wailing Caverns, Scarlet Monastery, Maraudon, The Temple of Atal'Hakkar, Scholomance, Stratholme, Zul'Gurub

### 📈 Comprehensive Statistics
- **Session Stats**: Casts, catches, success rate, fish per hour, gold per hour, session duration
- **Lifetime Stats**: Total casts, catches, fish caught by type, skill ups
- **Zone Statistics**: Track your fishing success in each zone with top fish breakdown
- **Zone Fish Browser**: See all catchable fish in your current zone with skill requirements, catch counts, and values
- **Rare Catches**: History of rare and valuable catches with timestamps and personal drop rates
- **Top 5 Catches**: Gold-highlighted ranking of your most-caught fish with percentages
- **Rare Fish Tracker**: Checklist of all rare fish with catch status and discovery count
- **Loot History**: Recent catch log with zone and quality info
- **Efficiency Trend**: Bar graph showing fish/hour over 5-minute intervals throughout the session
- **Gold Summary**: Vendor and AH value totals with per-hour rates
- Tabbed statistics panel with Overview, Fish Caught, Zone Fish, Zones, and History views

### 💰 Gold Tracking
- Tracks vendor value of catches using real item sell prices from GetItemInfo
- Scans AH prices automatically when you visit the Auction House (up to 20 fish per visit)
- AH prices cached account-wide for cross-session and cross-character use
- Displays vendor gold/hr and AH gold/hr on the main panel stats row
- Stats panel Overview shows total vendor value, AH value, and per-hour rates
- Fish tooltips show cached AH prices

### 🎣 Tooltip Enrichment
- Hover over any fish item (bags, AH, loot, trade) to see FishingKit data
- Shows: total caught, catch zones, minimum skill (color-coded), seasonal availability
- Displays cached AH price per unit
- Shows your best personal catch zone for that fish

### 📊 Bite Timing Analysis
- Cast bar shows a confidence band highlighting the most likely bite window
- Semi-transparent green band marks the 35th-65th percentile range
- Thin bright green line marks the median bite time
- Based on your actual catch timing data per zone (persists across sessions)
- Data improves with more catches; requires 5+ catches in a zone to display

### 🏆 STV Fishing Extravaganza
- Compact gold-bordered contest bar appears above the main panel during the event
- Only visible when in Stranglethorn Vale during Sunday 2-4 PM server time
- Shows Tastyfish count (X/40) with progress bar and minutes remaining
- "Turn in to win!" message at 40 Tastyfish
- Completely hidden outside contest hours or zones

### ⌨️ Key Bindings
- All major actions available in the WoW Key Bindings menu
- Bindable: Toggle Panel, Swap Fishing/Normal Gear, Lure Info, Toggle Stats, Toggle Settings
- Access via Game Menu > Key Bindings > FishingKit

### 🗺️ Pre-filled Pool Database
- Ships with **653 known pool spawn locations** across 27 zones (24 Classic + 3 TBC)
- All coordinates sourced from Wowhead — real verified spawn data
- Map pins appear on first install with no discovery required
- User-discovered pools always take precedence over static data
- Static pools merge on load with deduplication to avoid duplicates

### 🗺️ Pool Map Markers (Community vs Discovered)
- Discovered fishing pools are marked on both the **minimap** and **world map**
- **Two-color pin system** for instant visual distinction:
  - **Chartreuse (yellow-green)**: Community pool data — pre-filled database locations (unconfirmed)
  - **Cyan (teal)**: Pools you've personally discovered or confirmed by fishing
- Community pin tooltips show "Community Pool Data" with "Fish here to confirm this location"
- Discovered pin tooltips show "Seen: X time(s)" with last-seen timestamp
- Once you fish at a community pool, it converts to a confirmed discovered pool (cyan)
- **Toggle community pools on/off** in Config > Pools — hide all unconfirmed pins to see only your discovered pools
- Pool locations **persist across logout/reload** (stored account-wide)
- Pools detected on mouseover (tooltip alert) and recorded at close range
- Fishing a pool refines its pin to the most accurate position
- Position uses 15-yard facing offset for accurate pin placement
- Minimap pins support indoor/outdoor radius and minimap rotation
- World map pins use the standard MapCanvasDataProviderMixin system

### 🗺️ Pool Route Navigation
- Build an optimized route through discovered pools with `/fk route`
- **TomTom-style navigation arrow** points to the next pool with full metadata:
  - Pool name, coordinates, distance in yards, and ETA
  - Source tag: **Community** (chartreuse) or **Discovered (Xx seen)** (green)
  - Community pools show "Unconfirmed location"; discovered pools show "Last seen: Xh ago"
  - Waypoint counter (e.g. 3/12) and coordinates in bottom corners
- Nearest-neighbor TSP algorithm starts from the closest pool to the player
- Numbered waypoints shown on world map with colored connecting lines
- Current waypoint highlighted in green, others in cyan
- Arrow color changes based on direction accuracy (bright cyan = on target)
- Automatic arrival detection advances to next waypoint when close enough
- Right-click arrow to skip a waypoint, or use `/fk route skip`
- Recalculate from nearest pool with `/fk route nearest`
- New pool discoveries automatically inserted into active route via cheapest-insertion
- Route auto-rebuilds when changing zones
- Arrow hides during combat and returns after
- Arrow position is draggable and persists across sessions
- Import pool data from GatherMate2 with `/fk import gathermate`

### 🐟 Auto Find Fish Tracking
- Automatically enables **Find Fish** minimap tracking when equipping fishing gear
- Restores your previous tracking type (e.g. Find Herbs) when unequipping
- Requires the Find Fish ability (learned from Weather-Beaten Journal)

### 🐚 Container Opening
- Detects clams, crates, and other openable containers in your bags
- Shows total count of items to open
- Spam-click to quickly open all containers
- Supports: Big-mouth Clam, Thick-Shelled Clam, Jaggal Clam, Waterlogged Crate, Inscribed Scrollcase, Curious Crate, and more

### 🎯 Fishing Goals
- Set session catch targets via `/fk goal <fish name> <count>`
- Track progress on the idle status line with color-coded display
- Completion celebration with visual and audio feedback
- Multiple goals supported, first incomplete goal shown
- Fish matched by name against catch history and database

### 🐟 Catch & Release
- Mark junk fish for automatic deletion: `/fk release <fish name>`
- Only deletes gray and white quality items for safety
- Higher quality items rejected with error message
- Keeps your bags clean during extended fishing sessions

### 🔔 Alerts & Notifications
- Screen flash on successful catch
- Panel briefly turns green when you catch something
- Sound alerts for catches and rare items
- Lure expiration audio warning at 30 seconds remaining
- **Pool discovery sound** when mousing over a fishing pool
- **Enhanced fishing sound** - boosts SFX volume while fishing for easier splash detection, restores when done
- **Missing lure warning** - periodic alert when fishing without an active lure
- **Milestone celebrations** at 100, 250, 500, 1000, 2500, 5000, 10000 total catches
- **Cycle fish time window alerts** - notifies when Nightfin/Sunscale become available based on server time
- All alerts can be toggled in settings

### 💾 Automatic Backups
- SavedVariables backed up automatically every 24 hours
- `/fk backup` to force a backup, `/fk backup restore` to restore, `/fk backup info` for status
- Backs up both global and per-character data with confirmation dialog for restore

### 🗺️ Minimap Button
- Quick access to show/hide the fishing panel
- Right-click for settings
- Draggable around the minimap

## Slash Commands

| Command | Description |
|---------|-------------|
| `/fk` or `/fishingkit` | Toggle the main panel |
| `/fk show` | Show the panel |
| `/fk hide` | Hide the panel |
| `/fk equip` | Equip fishing gear |
| `/fk unequip` | Equip normal gear |
| `/fk savegear fishing` | Save current gear as fishing set |
| `/fk savegear normal` | Save current gear as normal set |
| `/fk sound on/off` | Toggle sound alerts |
| `/fk sound test` | Play test sound |
| `/fk stats` | Open statistics panel |
| `/fk config` | Open configuration |
| `/fk reset stats` | Reset all statistics |
| `/fk reset position` | Reset UI position |
| `/fk lock` / `/fk unlock` | Lock/unlock UI position |
| `/fk scale [0.5-2.0]` | Set UI scale |
| `/fk pools` | List discovered pools in current zone |
| `/fk pools clear` | Clear all saved pool data |
| `/fk pools clearzone` | Clear pool data for current zone only |
| `/fk route` | Toggle pool route navigation |
| `/fk route stop` | Stop navigation |
| `/fk route skip` | Skip current waypoint |
| `/fk route nearest` | Recalculate from nearest pool (alias: `recalc`) |
| `/fk import gathermate` | Import pool data from GatherMate2 |
| `/fk goal <fish> <count>` | Set a fishing goal for the session |
| `/fk goal` | List active goals |
| `/fk goal clear` | Clear all goals |
| `/fk release <fish>` | Add fish to auto-delete list |
| `/fk release` | List release items |
| `/fk release clear` | Clear release list |
| `/fk backup` | Force an immediate backup |
| `/fk backup restore` | Restore from last backup (requires /reload) |
| `/fk backup info` | Show last backup timestamp and age |
| `/fk debug` | Toggle debug mode |

## Configuration

The config panel (`/fk config`) includes 5 tabs:

### General
- Enable/disable addon, show/hide UI, lock position, UI scale, minimap button

### Alerts
- Sound alerts on/off, pool detection sound, test sound button
- Visual alerts, screen flash on rare catch, milestone celebrations
- Enhanced fishing sound (boost splash volume), missing lure warning

### Equipment
- Auto-save normal gear, re-equip fishing gear after combat toggle
- Save Fishing Gear / Save Normal Gear buttons
- Current equipment status display

### Pools
- Pool detection on/off, pool discovery sound
- Minimap/world map pin display toggle, community pool visibility toggle
- Auto Find Fish tracking toggle
- Pool Route Navigation: enable navigation, show arrow, show route on world map, waypoint sound, arrival distance slider
- Start/Stop Route, Skip Waypoint, Recalculate, Import GatherMate2 buttons
- Pool data count and clear buttons

### Statistics
- Track stats on/off, track loot history on/off
- All-time statistics summary
- Reset session / Reset all stats buttons

## Installation

1. Download and extract to your `Interface/AddOns` folder
2. Ensure the folder is named `FishingKit`
3. Restart WoW or type `/reload`

## Getting Started

1. Equip your normal combat gear and type `/fk savegear normal`
2. Equip your fishing gear and type `/fk savegear fishing`
3. Open the panel with `/fk` and start fishing!
4. Use the **Gear** button to swap between sets
5. Use the **Lure** button to apply lures with one click
6. Mouse over fishing pools to discover and mark their locations on your maps
7. If you have the Weather-Beaten Journal, Find Fish tracking enables automatically with your fishing gear
8. Visit the Auction House to scan fish prices for gold/hour tracking
9. Set key bindings via Game Menu > Key Bindings > FishingKit
10. Set fishing goals with `/fk goal <fish name> <count>`
11. Start a pool route with `/fk route` — the arrow guides you and the world map shows the route

## Compatibility

- **Game Version**: WoW TBC Classic Anniversary Edition (2.5.5)
- **Interface**: 20505
- **Addon Version**: 1.0.12

## Known Limitations

- **Fish Bite Detection**: The WoW API does not expose when a fish bites the bobber. Listen for the in-game splash sound to know when to click. The addon boosts SFX volume while fishing to help, and will flash green and play a sound when you successfully catch something.
- **AH Price Scanning**: Prices are scanned when you visit the AH (up to 20 fish per visit). Prices may become stale over time. Visit the AH periodically for updated values.
- **Lure Application**: Lure application requires the secure Lure button on the panel due to WoW combat lockdown restrictions. The keybind shows lure info but cannot apply directly.

## Credits

Created for the TBC Anniversary fishing community. Happy fishing!

---

**Feedback & Issues**: Please report any bugs or feature requests!
