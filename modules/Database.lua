--[[
    FishingKit - TBC Anniversary Edition
    Database Module - Comprehensive fishing data for TBC

    This module contains:
    - Complete TBC fish database with item IDs
    - Zone fishing requirements and available catches
    - Fishing pool definitions
    - Lure and equipment data
    - Vendor recipes and item locations
]]

local ADDON_NAME, FK = ...

FK.Database = {}
local DB = FK.Database

-- ============================================================================
-- Item Quality Constants
-- ============================================================================

DB.Quality = {
    POOR = 0,       -- Gray
    COMMON = 1,     -- White
    UNCOMMON = 2,   -- Green
    RARE = 3,       -- Blue
    EPIC = 4,       -- Purple
    LEGENDARY = 5,  -- Orange
}

-- ============================================================================
-- Fish Item Database
-- Complete list of TBC fishing catches with item IDs
-- ============================================================================

DB.Fish = {
    -- ========================================
    -- Classic Azeroth Fish
    -- ========================================

    -- Low-Level Fish (1-75 zones)
    [6291]  = { name = "Raw Brilliant Smallfish", quality = DB.Quality.COMMON, minSkill = 1, zone = "Starting Zones" },
    [6289]  = { name = "Raw Longjaw Mud Snapper", quality = DB.Quality.COMMON, minSkill = 1, zone = "Starting Zones" },
    [6303]  = { name = "Raw Slitherskin Mackerel", quality = DB.Quality.COMMON, minSkill = 1, zone = "Coastal Starting Zones" },
    [6361]  = { name = "Raw Rainbow Fin Albacore", quality = DB.Quality.COMMON, minSkill = 55, zone = "Darkshore, Westfall, Loch Modan" },
    [6317]  = { name = "Raw Loch Frenzy", quality = DB.Quality.COMMON, minSkill = 75, zone = "Loch Modan" },

    -- Mid-Level Fish (75-225 zones)
    [6358]  = { name = "Raw Bristle Whisker Catfish", quality = DB.Quality.COMMON, minSkill = 100, zone = "Redridge, Duskwood, Ashenvale, Hillsbrad" },
    [4603]  = { name = "Raw Spotted Yellowtail", quality = DB.Quality.COMMON, minSkill = 175, zone = "Stranglethorn Vale, Tanaris, Feralas" },
    [6362]  = { name = "Raw Rockscale Cod", quality = DB.Quality.COMMON, minSkill = 150, zone = "Alterac, Arathi, Stranglethorn, Tanaris, Feralas, Azshara" },
    [8365]  = { name = "Raw Mithril Head Trout", quality = DB.Quality.COMMON, minSkill = 175, zone = "Arathi, Alterac, Hillsbrad" },

    -- High-Level Fish (225-300 zones)
    [13754] = { name = "Raw Glossy Mightfish", quality = DB.Quality.COMMON, minSkill = 225, zone = "Azshara, Tanaris, Feralas" },
    [13755] = { name = "Winter Squid", quality = DB.Quality.COMMON, minSkill = 225, seasonal = "winter", zone = "Azshara, Tanaris, Feralas, Hinterlands" },
    [13756] = { name = "Raw Summer Bass", quality = DB.Quality.COMMON, minSkill = 225, seasonal = "summer", zone = "Azshara, Tanaris, Feralas, Hinterlands" },
    [13757] = { name = "Lightning Eel", quality = DB.Quality.UNCOMMON, minSkill = 250, zone = "Feralas, Azshara, Hinterlands, Felwood, Western Plaguelands, Eastern Plaguelands, Moonglade" },
    [13758] = { name = "Raw Redgill", quality = DB.Quality.COMMON, minSkill = 225, zone = "Azshara, Felwood, Hinterlands" },
    [13759] = { name = "Raw Nightfin Snapper", quality = DB.Quality.COMMON, minSkill = 225, timeWindow = "night", zone = "Moonglade, Felwood, Un'Goro, Western Plaguelands" },
    [13760] = { name = "Raw Sunscale Salmon", quality = DB.Quality.COMMON, minSkill = 225, timeWindow = "day", zone = "Moonglade, Felwood, Un'Goro, Western Plaguelands" },
    [13888] = { name = "Darkclaw Lobster", quality = DB.Quality.COMMON, minSkill = 225, zone = "Azshara, Blasted Lands, Swamp of Sorrows" },
    [13889] = { name = "Raw Whitescale Salmon", quality = DB.Quality.COMMON, minSkill = 275, zone = "Eastern Plaguelands, Winterspring, Burning Steppes" },
    [13893] = { name = "Large Raw Mightfish", quality = DB.Quality.COMMON, minSkill = 300, zone = "Azshara (Bay of Storms)" },

    -- Reagent Fish (Alchemy)
    [6359]  = { name = "Oily Blackmouth", quality = DB.Quality.COMMON, minSkill = 55, reagent = true, zone = "Darkshore, Westfall, Silverpine, Loch Modan, The Barrens" },
    [6360]  = { name = "Firefin Snapper", quality = DB.Quality.COMMON, minSkill = 130, reagent = true, zone = "Wetlands, Stonetalon, Desolace, Dustwallow, Stranglethorn, Tanaris, Azshara, Feralas" },
    [13422] = { name = "Stonescale Eel", quality = DB.Quality.UNCOMMON, minSkill = 275, reagent = true, zone = "Tanaris, Azshara, Hinterlands" },

    -- Sagefish
    [21071] = { name = "Raw Sagefish", quality = DB.Quality.COMMON, minSkill = 75, zone = "Hillsbrad, Silverpine, Ashenvale, Stonetalon" },
    [21153] = { name = "Raw Greater Sagefish", quality = DB.Quality.COMMON, minSkill = 175, zone = "Alterac, Arathi, Hillsbrad, Stranglethorn" },

    -- Special / Quest Fish
    [6522]  = { name = "Deviate Fish", quality = DB.Quality.UNCOMMON, minSkill = 50, special = true, zone = "The Barrens / Wailing Caverns" },
    [19807] = { name = "Speckled Tastyfish", quality = DB.Quality.COMMON, minSkill = 225, special = true, rare = true, zone = "Stranglethorn Vale (Contest)" },
    [7079]  = { name = "Globe of Water", quality = DB.Quality.COMMON, minSkill = 1, special = true, zone = "Swamp of Sorrows, Azshara" },
    [34484] = { name = "Old Ironjaw", quality = DB.Quality.RARE, minSkill = 1, rare = true, zone = "Ironforge" },
    [34486] = { name = "Old Crafty", quality = DB.Quality.RARE, minSkill = 1, rare = true, zone = "Orgrimmar" },

    -- Clam Drops
    [7973]  = { name = "Big-mouth Clam", quality = DB.Quality.COMMON, minSkill = 200, container = true },
    [4655]  = { name = "Giant Clam", quality = DB.Quality.COMMON, minSkill = 250, container = true },

    -- ========================================
    -- TBC Outland Fish
    -- ========================================

    -- Common Catches (Open Water)
    [27422] = { name = "Barbed Gill Trout", quality = DB.Quality.COMMON, minSkill = 300, tbc = true, zone = "Hellfire, Zangarmarsh, Terokkar, Nagrand, Blade's Edge, Shadowmoon" },
    [27425] = { name = "Spotted Feltail", quality = DB.Quality.COMMON, minSkill = 305, tbc = true, zone = "Zangarmarsh, Terokkar, Nagrand, Shadowmoon" },
    [27429] = { name = "Zangarian Sporefish", quality = DB.Quality.COMMON, minSkill = 305, tbc = true, zone = "Zangarmarsh" },
    [27435] = { name = "Figluster's Mudfish", quality = DB.Quality.COMMON, minSkill = 340, tbc = true, zone = "Nagrand" },
    [27437] = { name = "Icefin Bluefish", quality = DB.Quality.COMMON, minSkill = 355, tbc = true, zone = "Nagrand" },
    [27438] = { name = "Golden Darter", quality = DB.Quality.COMMON, minSkill = 355, tbc = true, zone = "Terokkar Forest" },
    [27441] = { name = "Felblood Snapper", quality = DB.Quality.COMMON, minSkill = 280, tbc = true, zone = "Hellfire Peninsula, Shadowmoon Valley" },
    [27513] = { name = "Crescent-Tail Skullfish", quality = DB.Quality.COMMON, minSkill = 375, tbc = true, zone = "Netherstorm" },

    -- Rare / Uncommon Catches
    [27439] = { name = "Furious Crawdad", quality = DB.Quality.RARE, minSkill = 350, tbc = true, rare = true, zone = "Terokkar Forest (Highland Lakes)" },
    [27515] = { name = "Huge Spotted Feltail", quality = DB.Quality.UNCOMMON, minSkill = 310, tbc = true, pool = true, zone = "Zangarmarsh" },
    [27516] = { name = "Enormous Barbed Gill Trout", quality = DB.Quality.UNCOMMON, minSkill = 300, tbc = true, pool = true, zone = "Terokkar Forest" },
    [34867] = { name = "Monstrous Felblood Snapper", quality = DB.Quality.UNCOMMON, minSkill = 280, tbc = true, zone = "Hellfire Peninsula, Shadowmoon Valley" },

    -- Special TBC Items
    [22578] = { name = "Mote of Water", quality = DB.Quality.UNCOMMON, minSkill = 380, tbc = true, special = true, zone = "Nagrand (Pure Water pools)" },
    [27388] = { name = "Mr. Pinchy", quality = DB.Quality.RARE, minSkill = 430, tbc = true, rare = true, zone = "Terokkar Forest (Highland Lakes)" },

    -- Bloated Fish (Containers)
    [35313] = { name = "Bloated Barbed Gill Trout", quality = DB.Quality.COMMON, minSkill = 300, tbc = true, container = true },
    [35286] = { name = "Bloated Spotted Feltail", quality = DB.Quality.COMMON, minSkill = 305, tbc = true, container = true },

    -- Pets
    [34864] = { name = "Baby Crocolisk", quality = DB.Quality.RARE, minSkill = 1, tbc = true, pet = true, zone = "Shattrath Fishing Daily" },

    -- Junk
    [27420] = { name = "Polished Bone Chip", quality = DB.Quality.POOR, minSkill = 1, tbc = true, junk = true },
    [27421] = { name = "Grime-Encrusted Scale", quality = DB.Quality.POOR, minSkill = 1, tbc = true, junk = true },
}

-- ============================================================================
-- Zone Fishing Data
-- Skill requirements and available catches per zone
-- ============================================================================

-- Zone skill formula (pre-3.1 / TBC Classic):
--   minSkill = noGetaway - 95 (minimum to cast, clamped to 1)
--   noGetaway = skill for 100% catch rate (no fish escape)

DB.Zones = {
    -- ========================================
    -- Tier 1: Starting Zones (noGetaway 25)
    -- ========================================

    ["Elwynn Forest"] = {
        continent = "Eastern Kingdoms",
        minSkill = 1,
        noGetaway = 25,
        fish = { 6291, 6289 },
        pools = {},
    },

    ["Dun Morogh"] = {
        continent = "Eastern Kingdoms",
        minSkill = 1,
        noGetaway = 25,
        fish = { 6291, 6289 },
        pools = {},
    },

    ["Tirisfal Glades"] = {
        continent = "Eastern Kingdoms",
        minSkill = 1,
        noGetaway = 25,
        fish = { 6291, 6289 },
        pools = {},
    },

    ["Eversong Woods"] = {
        continent = "Eastern Kingdoms",
        minSkill = 1,
        noGetaway = 25,
        fish = { 6291, 6289 },
        pools = {},
        tbc = true,
    },

    ["Durotar"] = {
        continent = "Kalimdor",
        minSkill = 1,
        noGetaway = 25,
        fish = { 6291, 6303 },
        pools = {},
    },

    ["Mulgore"] = {
        continent = "Kalimdor",
        minSkill = 1,
        noGetaway = 25,
        fish = { 6291, 6289 },
        pools = {},
    },

    ["Teldrassil"] = {
        continent = "Kalimdor",
        minSkill = 1,
        noGetaway = 25,
        fish = { 6291, 6289 },
        pools = {},
    },

    ["Azuremyst Isle"] = {
        continent = "Kalimdor",
        minSkill = 1,
        noGetaway = 25,
        fish = { 6291, 6303 },
        pools = {},
        tbc = true,
    },

    -- ========================================
    -- Tier 2: Low Zones + Cities (noGetaway 75)
    -- ========================================

    ["Westfall"] = {
        continent = "Eastern Kingdoms",
        minSkill = 1,
        noGetaway = 75,
        fish = { 6289, 6361, 6303, 6359 },
        pools = { "Oily Blackmouth School", "Floating Debris" },
    },

    ["Loch Modan"] = {
        continent = "Eastern Kingdoms",
        minSkill = 1,
        noGetaway = 75,
        fish = { 6289, 6317, 6361 },
        pools = { "Oily Blackmouth School" },
    },

    ["Silverpine Forest"] = {
        continent = "Eastern Kingdoms",
        minSkill = 1,
        noGetaway = 75,
        fish = { 6289, 6303, 6359 },
        pools = { "Oily Blackmouth School", "Sagefish School" },
    },

    ["Ghostlands"] = {
        continent = "Eastern Kingdoms",
        minSkill = 1,
        noGetaway = 75,
        fish = { 6289, 6361 },
        pools = {},
        tbc = true,
    },

    ["Darkshore"] = {
        continent = "Kalimdor",
        minSkill = 1,
        noGetaway = 75,
        fish = { 6289, 6303, 6361, 6359 },
        pools = { "Oily Blackmouth School" },
    },

    ["The Barrens"] = {
        continent = "Kalimdor",
        minSkill = 1,
        noGetaway = 75,
        fish = { 6291, 6289, 6358, 6522, 6359 },
        pools = { "School of Deviate Fish", "Oily Blackmouth School" },
        deviate = true,
    },

    ["Wailing Caverns"] = {
        continent = "Kalimdor",
        minSkill = 1,
        noGetaway = 75,
        fish = { 6522 },
        pools = { "School of Deviate Fish" },
        deviate = true,
        instance = true,
    },

    ["Bloodmyst Isle"] = {
        continent = "Kalimdor",
        minSkill = 1,
        noGetaway = 75,
        fish = { 6289, 6361, 6303 },
        pools = {},
        tbc = true,
    },

    -- Instances (noGetaway 75)
    ["Blackfathom Deeps"] = {
        continent = "Kalimdor",
        minSkill = 1,
        noGetaway = 75,
        fish = { 6291, 6289, 6359 },
        pools = {},
        instance = true,
    },

    ["The Deadmines"] = {
        continent = "Eastern Kingdoms",
        minSkill = 1,
        noGetaway = 75,
        fish = { 6291, 6289, 6359 },
        pools = {},
        instance = true,
    },

    -- Cities (noGetaway 75)
    ["Shattrath City"] = {
        continent = "Outland",
        minSkill = 1,
        noGetaway = 75,
        fish = { 6291, 6289 },
        pools = {},
        city = true,
        tbc = true,
    },

    ["Silvermoon City"] = {
        continent = "Eastern Kingdoms",
        minSkill = 1,
        noGetaway = 75,
        fish = { 6291, 6289 },
        pools = {},
        city = true,
        tbc = true,
    },

    ["The Exodar"] = {
        continent = "Kalimdor",
        minSkill = 1,
        noGetaway = 75,
        fish = { 6291, 6289 },
        pools = {},
        city = true,
        tbc = true,
    },

    ["Stormwind City"] = {
        continent = "Eastern Kingdoms",
        minSkill = 1,
        noGetaway = 75,
        fish = { 6291, 6289 },
        pools = {},
        city = true,
    },

    ["Ironforge"] = {
        continent = "Eastern Kingdoms",
        minSkill = 1,
        noGetaway = 75,
        fish = { 6291, 6289 },
        pools = {},
        city = true,
    },

    ["Undercity"] = {
        continent = "Eastern Kingdoms",
        minSkill = 1,
        noGetaway = 75,
        fish = { 6291, 6289 },
        pools = {},
        city = true,
    },

    ["Orgrimmar"] = {
        continent = "Kalimdor",
        minSkill = 1,
        noGetaway = 75,
        fish = { 6291, 6289 },
        pools = {},
        city = true,
    },

    ["Thunder Bluff"] = {
        continent = "Kalimdor",
        minSkill = 1,
        noGetaway = 75,
        fish = { 6291, 6289 },
        pools = {},
        city = true,
    },

    ["Darnassus"] = {
        continent = "Kalimdor",
        minSkill = 1,
        noGetaway = 75,
        fish = { 6291, 6289 },
        pools = {},
        city = true,
    },

    -- ========================================
    -- Tier 4: Level 21-30 Zones (noGetaway 150)
    -- ========================================

    ["Redridge Mountains"] = {
        continent = "Eastern Kingdoms",
        minSkill = 55,
        noGetaway = 150,
        fish = { 6289, 6358, 6361 },
        pools = {},
    },

    ["Duskwood"] = {
        continent = "Eastern Kingdoms",
        minSkill = 55,
        noGetaway = 150,
        fish = { 6289, 6358, 6362 },
        pools = {},
    },

    ["Wetlands"] = {
        continent = "Eastern Kingdoms",
        minSkill = 55,
        noGetaway = 150,
        fish = { 6289, 6358, 6359, 6360 },
        pools = { "Oily Blackmouth School", "Firefin Snapper School" },
    },

    ["Hillsbrad Foothills"] = {
        continent = "Eastern Kingdoms",
        minSkill = 55,
        noGetaway = 150,
        fish = { 6358, 6359, 6360, 21071, 21153 },
        pools = { "Oily Blackmouth School", "Firefin Snapper School", "Sagefish School", "Greater Sagefish School" },
    },

    ["Ashenvale"] = {
        continent = "Kalimdor",
        minSkill = 55,
        noGetaway = 150,
        fish = { 6289, 6358, 6359, 21071 },
        pools = { "Oily Blackmouth School", "Sagefish School" },
    },

    ["Stonetalon Mountains"] = {
        continent = "Kalimdor",
        minSkill = 55,
        noGetaway = 150,
        fish = { 6289, 6358, 6360, 21071 },
        pools = { "Firefin Snapper School", "Sagefish School" },
    },

    -- ========================================
    -- Tier 5: Level 31-40 Zones (noGetaway 225)
    -- ========================================

    ["Alterac Mountains"] = {
        continent = "Eastern Kingdoms",
        minSkill = 130,
        noGetaway = 225,
        fish = { 6358, 6362, 8365, 21153 },
        pools = { "Greater Sagefish School" },
    },

    ["Arathi Highlands"] = {
        continent = "Eastern Kingdoms",
        minSkill = 130,
        noGetaway = 225,
        fish = { 6358, 6362, 8365, 21153, 6360 },
        pools = { "Greater Sagefish School", "Firefin Snapper School", "Floating Wreckage" },
    },

    ["Scarlet Monastery"] = {
        continent = "Eastern Kingdoms",
        minSkill = 130,
        noGetaway = 225,
        fish = { 6358, 6362, 8365 },
        pools = {},
        instance = true,
    },

    ["Stranglethorn Vale"] = {
        continent = "Eastern Kingdoms",
        minSkill = 130,
        noGetaway = 225,
        fish = { 4603, 6359, 6360, 6362, 13754, 13422 },
        pools = { "Firefin Snapper School", "Oily Blackmouth School", "Floating Wreckage", "Stonescale Eel Swarm", "School of Tastyfish", "Floating Wreckage Pool", "Schooner Wreckage", "Waterlogged Wreckage Pool", "Bloodsail Wreckage Pool", "Oil Spill", "Greater Sagefish School", "Mixed Ocean School" },
        contest = true,
    },

    ["Desolace"] = {
        continent = "Kalimdor",
        minSkill = 130,
        noGetaway = 225,
        fish = { 6358, 6360, 6362, 8365 },
        pools = { "Firefin Snapper School" },
    },

    ["Dustwallow Marsh"] = {
        continent = "Kalimdor",
        minSkill = 130,
        noGetaway = 225,
        fish = { 6358, 6360, 6362, 8365 },
        pools = { "Firefin Snapper School", "Floating Wreckage" },
    },

    ["Swamp of Sorrows"] = {
        continent = "Eastern Kingdoms",
        minSkill = 130,
        noGetaway = 225,
        fish = { 6358, 6362, 8365, 7079 },
        pools = { "Patch of Elemental Water" },
    },

    ["Thousand Needles"] = {
        continent = "Kalimdor",
        minSkill = 130,
        noGetaway = 225,
        fish = { 6358, 6359, 6360 },
        pools = { "Oily Blackmouth School", "Firefin Snapper School" },
    },

    -- ========================================
    -- Tier 6: Level 40-55 Zones (noGetaway 300)
    -- ========================================

    ["Maraudon"] = {
        continent = "Kalimdor",
        minSkill = 205,
        noGetaway = 300,
        fish = { 13759, 13760 },
        pools = {},
        instance = true,
    },

    ["The Temple of Atal'Hakkar"] = {
        continent = "Eastern Kingdoms",
        minSkill = 205,
        noGetaway = 300,
        fish = { 13759, 13760 },
        pools = {},
        instance = true,
    },

    ["Feralas"] = {
        continent = "Kalimdor",
        minSkill = 205,
        noGetaway = 300,
        fish = { 4603, 6360, 6362, 13754, 13755, 13756, 13757, 13758, 13422 },
        pools = { "Oily Blackmouth School", "Firefin Snapper School", "Floating Wreckage", "Stonescale Eel Swarm" },
    },

    ["The Hinterlands"] = {
        continent = "Eastern Kingdoms",
        minSkill = 205,
        noGetaway = 300,
        fish = { 4603, 6360, 6362, 13754, 13755, 13756, 13757, 13422 },
        pools = { "Oily Blackmouth School", "Firefin Snapper School", "Floating Wreckage", "Stonescale Eel Swarm" },
    },

    ["Western Plaguelands"] = {
        continent = "Eastern Kingdoms",
        minSkill = 205,
        noGetaway = 300,
        fish = { 13757, 13758, 13759, 13760 },
        pools = {},
    },

    ["Felwood"] = {
        continent = "Kalimdor",
        minSkill = 205,
        noGetaway = 300,
        fish = { 13757, 13758, 13759, 13760 },
        pools = {},
    },

    ["Moonglade"] = {
        continent = "Kalimdor",
        minSkill = 205,
        noGetaway = 300,
        fish = { 13757, 13759, 13760 },
        pools = {},
    },

    ["Tanaris"] = {
        continent = "Kalimdor",
        minSkill = 205,
        noGetaway = 300,
        fish = { 4603, 6360, 6362, 13754, 13755, 13756, 13422 },
        pools = { "Oily Blackmouth School", "Firefin Snapper School", "Floating Wreckage", "Stonescale Eel Swarm" },
    },

    ["Un'Goro Crater"] = {
        continent = "Kalimdor",
        minSkill = 205,
        noGetaway = 300,
        fish = { 13757, 13759, 13760 },
        pools = {},
    },

    ["Azshara"] = {
        continent = "Kalimdor",
        minSkill = 205,
        noGetaway = 300,
        fish = { 4603, 6360, 6362, 13754, 13755, 13756, 13757, 13888, 13889, 13893, 13422 },
        pools = { "Oily Blackmouth School", "Firefin Snapper School", "Floating Wreckage", "Stonescale Eel Swarm", "Patch of Elemental Water" },
    },

    -- ========================================
    -- Tier 7: Outland Entry (noGetaway 375)
    -- ========================================

    ["Hellfire Peninsula"] = {
        continent = "Outland",
        minSkill = 280,
        noGetaway = 375,
        fish = { 27422, 27441 },
        pools = {},
        tbc = true,
    },

    ["Shadowmoon Valley"] = {
        continent = "Outland",
        minSkill = 280,
        noGetaway = 375,
        fish = { 27422, 27441 },
        pools = { "Feltail School" },
        tbc = true,
    },

    -- ========================================
    -- Tier 8: Zangarmarsh East (noGetaway 400)
    -- ========================================

    ["Zangarmarsh"] = {
        continent = "Outland",
        minSkill = 305,
        noGetaway = 400,
        fish = { 27422, 27425, 27429, 27515 },
        pools = { "Sporefish School", "Spotted Feltail School", "Feltail School", "Brackish Mixed School", "Steam Pump Flotsam" },
        tbc = true,
    },

    -- ========================================
    -- Tier 9: High Azeroth + Outland (noGetaway 425)
    -- ========================================

    ["Eastern Plaguelands"] = {
        continent = "Eastern Kingdoms",
        minSkill = 330,
        noGetaway = 425,
        fish = { 13757, 13758, 13759, 13760, 13889 },
        pools = {},
    },

    ["Scholomance"] = {
        continent = "Eastern Kingdoms",
        minSkill = 330,
        noGetaway = 425,
        fish = { 13889, 13759, 13760 },
        pools = {},
        instance = true,
    },

    ["Stratholme"] = {
        continent = "Eastern Kingdoms",
        minSkill = 330,
        noGetaway = 425,
        fish = { 13889, 13759, 13760 },
        pools = {},
        instance = true,
    },

    ["Zul'Gurub"] = {
        continent = "Eastern Kingdoms",
        minSkill = 330,
        noGetaway = 425,
        fish = { 13889, 13759, 13760 },
        pools = {},
        instance = true,
    },

    ["Burning Steppes"] = {
        continent = "Eastern Kingdoms",
        minSkill = 330,
        noGetaway = 425,
        fish = { 13757, 13759, 13760, 13889 },
        pools = {},
    },

    ["Deadwind Pass"] = {
        continent = "Eastern Kingdoms",
        minSkill = 330,
        noGetaway = 425,
        fish = { 13757, 13759, 13760, 13889, 27422 },
        pools = {},
    },

    ["Winterspring"] = {
        continent = "Kalimdor",
        minSkill = 330,
        noGetaway = 425,
        fish = { 13757, 13759, 13760, 13889 },
        pools = {},
    },

    ["Silithus"] = {
        continent = "Kalimdor",
        minSkill = 330,
        noGetaway = 425,
        fish = { 13757, 13758, 13759, 13760, 13889 },
        pools = {},
    },

    -- ========================================
    -- Tier 10: Outland Mid (noGetaway 450)
    -- ========================================

    ["Terokkar Forest"] = {
        continent = "Outland",
        minSkill = 355,
        noGetaway = 450,
        fish = { 27422, 27425, 27438, 27516 },
        pools = { "School of Darter", "Brackish Mixed School", "Feltail School", "Highland Mixed School" },
        tbc = true,
        lakes = { "Lake Jorune", "Lake Ere'Noru", "Blackwind Lake", "Silmyr Lake" },
    },

    ["Isle of Quel'Danas"] = {
        continent = "Eastern Kingdoms",
        minSkill = 355,
        noGetaway = 450,
        fish = { 27422, 27425 },
        pools = {},
        tbc = true,
    },

    -- ========================================
    -- Tier 11: Outland High (noGetaway 475)
    -- ========================================

    ["Nagrand"] = {
        continent = "Outland",
        minSkill = 380,
        noGetaway = 475,
        fish = { 27422, 27435, 27437, 22578 },
        pools = { "Mudfish School", "Bluefish School", "Pure Water" },
        tbc = true,
        elemental_water = true,
    },

    ["Netherstorm"] = {
        continent = "Outland",
        minSkill = 380,
        noGetaway = 475,
        fish = { 27422, 27435, 27437, 27513 },
        pools = {},
        tbc = true,
    },

    ["Blade's Edge Mountains"] = {
        continent = "Outland",
        minSkill = 380,
        noGetaway = 475,
        fish = { 27422, 27438 },
        pools = {},
        tbc = true,
    },

    -- ========================================
    -- Tier 13: Terokkar Highland Lakes (noGetaway 500)
    -- ========================================

    ["Skettis Lakes"] = {
        continent = "Outland",
        minSkill = 405,
        noGetaway = 500,
        fish = { 27439, 27438, 27422 },
        pools = { "Highland Mixed School" },
        tbc = true,
        flying_required = true,
        crawdad = true,
    },
}

-- ============================================================================
-- Fishing Pool Types
-- ============================================================================

DB.Pools = {
    -- ========================================================================
    -- Classic Pools
    -- ========================================================================

    ["Floating Wreckage"] = {
        fish = {},
        containers = true,
        minSkill = 1,
        spawnTime = 600,
        treasure = true,
        zone = "Stranglethorn Vale, Tanaris, Feralas, Azshara",
    },

    ["Patch of Elemental Water"] = {
        fish = { 7079 },  -- Globe of Water
        minSkill = 1,
        spawnTime = 300,
        special = true,
        zone = "Swamp of Sorrows, Azshara",
    },

    ["Floating Debris"] = {
        fish = {},
        containers = true,
        minSkill = 1,
        spawnTime = 600,
        treasure = true,
        zone = "Various",
    },

    ["Oil Spill"] = {
        fish = { 8363 },  -- Oily Blackmouth, Firefin Snapper
        minSkill = 1,
        spawnTime = 300,
        zone = "Stranglethorn Vale",
    },

    ["Firefin Snapper School"] = {
        fish = { 6360 },
        minSkill = 130,
        spawnTime = 300,
        reagent = true,
        zone = "Wetlands, Stonetalon Mountains, Desolace, Dustwallow Marsh, Stranglethorn Vale, Tanaris, Azshara, Feralas",
    },

    ["Greater Sagefish School"] = {
        fish = { 21153 },
        minSkill = 175,
        spawnTime = 300,
        zone = "Alterac Mountains, Arathi Highlands, Stranglethorn Vale, Hillsbrad Foothills",
    },

    ["Oily Blackmouth School"] = {
        fish = { 6359 },
        minSkill = 55,
        spawnTime = 300,
        reagent = true,
        zone = "Darkshore, Silverpine Forest, Westfall, Loch Modan, The Barrens, Tanaris, Azshara, Feralas",
    },

    ["Sagefish School"] = {
        fish = { 21071 },
        minSkill = 75,
        spawnTime = 300,
        zone = "Hillsbrad Foothills, Silverpine Forest, Ashenvale, Stonetalon Mountains",
    },

    ["School of Deviate Fish"] = {
        fish = { 6522 },
        minSkill = 1,
        spawnTime = 180,
        special = true,
        zone = "The Barrens / Wailing Caverns",
    },

    ["Stonescale Eel Swarm"] = {
        fish = { 13422 },
        minSkill = 275,
        spawnTime = 300,
        reagent = true,
        zone = "Tanaris, Azshara, Bay of Storms, The Hinterlands",
    },

    ["School of Tastyfish"] = {
        fish = { 19807 },  -- Speckled Tastyfish
        minSkill = 225,
        spawnTime = 300,
        special = true,
        zone = "Stranglethorn Vale",
    },

    ["Floating Wreckage Pool"] = {
        fish = {},
        containers = true,
        minSkill = 1,
        spawnTime = 600,
        treasure = true,
        zone = "Various coastal zones",
    },

    ["Schooner Wreckage"] = {
        fish = {},
        containers = true,
        minSkill = 1,
        spawnTime = 600,
        treasure = true,
        zone = "Stranglethorn Vale",
    },

    ["Waterlogged Wreckage Pool"] = {
        fish = {},
        containers = true,
        minSkill = 1,
        spawnTime = 600,
        treasure = true,
        zone = "Stranglethorn Vale, Feralas",
    },

    ["Bloodsail Wreckage Pool"] = {
        fish = {},
        containers = true,
        minSkill = 1,
        spawnTime = 600,
        treasure = true,
        zone = "Stranglethorn Vale",
    },

    ["Mixed Ocean School"] = {
        fish = { 6362, 6358, 4603 },  -- Raw Rockscale Cod, Oily Blackmouth, Raw Spotted Yellowtail
        minSkill = 130,
        spawnTime = 300,
        zone = "Various coastal zones",
    },

    -- ========================================================================
    -- TBC Pools
    -- ========================================================================

    ["Sporefish School"] = {
        fish = { 27429 },  -- Zangarian Sporefish
        minSkill = 305,
        spawnTime = 300,
        zone = "Zangarmarsh",
        tbc = true,
    },

    ["Feltail School"] = {
        fish = { 27425 },  -- Spotted Feltail
        minSkill = 305,
        spawnTime = 300,
        zone = "Zangarmarsh, Terokkar Forest, Nagrand, Shadowmoon Valley",
        tbc = true,
    },

    ["Spotted Feltail School"] = {
        fish = { 27425, 27515 },  -- Spotted Feltail, Huge Spotted Feltail
        minSkill = 305,
        spawnTime = 300,
        zone = "Zangarmarsh, Terokkar Forest, Nagrand",
        tbc = true,
    },

    ["Brackish Mixed School"] = {
        fish = { 27438, 27425 },  -- Golden Darter, Spotted Feltail
        minSkill = 305,
        spawnTime = 300,
        zone = "Zangarmarsh, Terokkar Forest",
        tbc = true,
    },

    ["Steam Pump Flotsam"] = {
        fish = {},
        containers = true,
        minSkill = 305,
        spawnTime = 600,
        zone = "Zangarmarsh",
        tbc = true,
        treasure = true,
    },

    ["School of Darter"] = {
        fish = { 27438 },  -- Golden Darter
        minSkill = 355,
        spawnTime = 300,
        zone = "Terokkar Forest",
        tbc = true,
    },

    ["Mudfish School"] = {
        fish = { 27435 },  -- Figluster's Mudfish
        minSkill = 380,
        spawnTime = 300,
        zone = "Nagrand",
        tbc = true,
    },

    ["Bluefish School"] = {
        fish = { 27437 },  -- Icefin Bluefish
        minSkill = 380,
        spawnTime = 300,
        zone = "Nagrand",
        tbc = true,
    },

    ["Pure Water"] = {
        fish = { 22578 },  -- Mote of Water
        minSkill = 380,
        spawnTime = 300,
        zone = "Nagrand",
        tbc = true,
        special = true,
    },

    ["Highland Mixed School"] = {
        fish = { 27439, 27422, 27438 },  -- Furious Crawdad, Golden Darter, Enormous Barbed Gill Trout
        minSkill = 400,
        spawnTime = 300,
        zone = "Terokkar Forest (Elevated Lakes)",
        tbc = true,
        crawdad = true,
        flying_required = true,
    },
}

-- ============================================================================
-- Fishing Equipment Database
-- ============================================================================

DB.FishingPoles = {
    -- Basic Poles
    [6256]  = { name = "Fishing Pole", bonus = 0, source = "Vendor" },
    [6365]  = { name = "Strong Fishing Pole", bonus = 5, source = "Vendor" },
    [6366]  = { name = "Darkwood Fishing Pole", bonus = 15, source = "Vendor (Horde)" },
    [6367]  = { name = "Big Iron Fishing Pole", bonus = 20, source = "Shellfish Trap (Desolace)" },
    [12225] = { name = "Blump Family Fishing Pole", bonus = 3, source = "Quest (Alliance)" },

    -- Rare/Event Poles
    [19022] = { name = "Nat Pagle's Extreme Angler FC-5000", bonus = 25, source = "Quest (Dustwallow)" },
    [19970] = { name = "Arcanite Fishing Pole", bonus = 35, source = "Stranglethorn Fishing Extravaganza" },
    [25978] = { name = "Seth's Graphite Fishing Pole", bonus = 20, source = "Quest (Terokkar Forest)", tbc = true },

    -- TBC Poles
    [34834] = { name = "Jeweled Fishing Pole", bonus = 30, source = "Fishing Daily (Shattrath)", tbc = true },
    [45858] = { name = "Nat's Lucky Fishing Pole", bonus = 25, source = "Fishing Daily", tbc = true },
}

DB.FishingHats = {
    [19972] = { name = "Lucky Fishing Hat", bonus = 5, source = "Stranglethorn Fishing Extravaganza" },
    [33820] = { name = "Weather-Beaten Fishing Hat", bonus = 75, source = "Fishing Daily (Shattrath)", tbc = true, special = "Find Fish" },
}

DB.FishingGloves = {
    [18263] = { name = "Flarecore Gloves", bonus = 0, special = "Fire Resistance" },
    -- Note: No specific fishing gloves in TBC, but glove enchant exists
}

DB.FishingBoots = {
    [19969] = { name = "Nat Pagle's Extreme Anglin' Boots", bonus = 5, source = "Stranglethorn Fishing Extravaganza" },
}

-- ============================================================================
-- Fishing Lures
-- ============================================================================

DB.Lures = {
    [6529]  = { name = "Shiny Bauble", bonus = 25, duration = 600, source = "Vendor" },
    [6530]  = { name = "Nightcrawlers", bonus = 50, duration = 600, source = "Vendor" },
    [6532]  = { name = "Bright Baubles", bonus = 75, duration = 600, source = "Vendor/Crafted" },
    [6533]  = { name = "Aquadynamic Fish Attractor", bonus = 100, duration = 600, source = "Crafted (Engineering)" },
    [6811]  = { name = "Aquadynamic Fish Lens", bonus = 50, duration = 600, source = "Quest" },
    [7307]  = { name = "Flesh Eating Worm", bonus = 75, duration = 600, source = "Rotting Carcass" },
    [33820] = { name = "Weather-Beaten Fishing Hat", bonus = 75, special = "Equip Effect", tbc = true },
    [34861] = { name = "Sharpened Fish Hook", bonus = 100, duration = 600, source = "Fishing Daily", tbc = true },
}

-- ============================================================================
-- Junk Items (for filtering statistics)
-- ============================================================================

DB.JunkItems = {
    -- Common Junk
    [6289]  = false, -- Not junk, it's a fish
    [6294]  = true,  -- Small Locked Chest
    [6307]  = true,  -- Message in a Bottle
    [6352]  = true,  -- Waterlogged Crate
    [6353]  = true,  -- Small Barnacled Clam
    [6354]  = true,  -- Bloated Lesser Mightfish
    [13874] = true,  -- Heavy Leather
    [13875] = true,  -- Mithril Bound Trunk

    -- TBC Junk
    [24476] = true,  -- Jaggal Clam
    [24477] = true,  -- Jaggal Pearl
    [27388] = true,  -- Mr. Pinchy (special)
    [27420] = true,  -- Polished Bone Chip
    [27421] = true,  -- Grime-Encrusted Scale
    [27481] = true,  -- Heavy Supply Crate
    [27482] = true,  -- Inscribed Scrollcase
    [34109] = true,  -- Weather-Beaten Journal (special)
}

-- ============================================================================
-- Special Items and Achievements
-- ============================================================================

DB.SpecialItems = {
    -- Mr. Pinchy chain
    [27388] = {
        name = "Mr. Pinchy",
        source = "Highland Mixed School (Skettis)",
        wishes = 3,
        pet = 27445,
    },

    -- Pets from fishing
    [34864] = {
        name = "Baby Crocolisk",
        source = "Fishing Daily (Crocolisks in the City)",
        pet = true,
    },

    -- Weather-Beaten Journal (teaches Find Fish)
    [34109] = {
        name = "Weather-Beaten Journal",
        source = "Container fish (rare)",
        teaches = "Find Fish",
    },

    -- Deviate Fish (special cooking ingredient)
    [6522] = {
        name = "Deviate Fish",
        source = "The Barrens / Wailing Caverns",
        cooking = "Savory Deviate Delight",
    },
}

-- ============================================================================
-- TBC Fishing Daily Rewards
-- ============================================================================

DB.DailyRewards = {
    ["Bag of Fishing Treasures"] = {
        contents = {
            { itemID = 34834, name = "Jeweled Fishing Pole", chance = 0.01 },
            { itemID = 33820, name = "Weather-Beaten Fishing Hat", chance = 0.01 },
            { itemID = 34861, name = "Sharpened Fish Hook", chance = 0.1 },
            { itemID = 34109, name = "Weather-Beaten Journal", chance = 0.05 },
            { itemID = 34864, name = "Baby Crocolisk", chance = 0.01, pet = true },
        },
        gold = { min = 5, max = 15 },
    },
}

-- ============================================================================
-- Utility Functions
-- ============================================================================

function DB:GetFishInfo(itemID)
    return self.Fish[itemID]
end

function DB:GetZoneInfo(zoneName)
    return self.Zones[zoneName]
end

function DB:GetPoolInfo(poolName)
    return self.Pools[poolName]
end

function DB:GetLureInfo(itemID)
    return self.Lures[itemID]
end

function DB:IsFish(itemID)
    return self.Fish[itemID] ~= nil
end

function DB:GetFishIDByName(name)
    local lowerName = string.lower(name)
    for itemID, data in pairs(self.Fish) do
        if data.name and string.lower(data.name) == lowerName then
            return itemID
        end
    end
    return nil
end

function DB:IsJunk(itemID)
    return self.JunkItems[itemID] == true
end

function DB:IsSpecial(itemID)
    return self.SpecialItems[itemID] ~= nil
end

function DB:GetZoneMinSkill(zoneName)
    local zone = self.Zones[zoneName]
    if zone then
        return zone.minSkill or 1
    end
    return 1
end

function DB:GetZoneNoGetawaySkill(zoneName)
    local zone = self.Zones[zoneName]
    if zone then
        return zone.noGetaway or 1
    end
    return 1
end

function DB:GetBestLureForSkillGap(skillGap)
    -- Returns the most appropriate lure for a given skill gap
    local lures = {
        { id = 6529, bonus = 25 },   -- Shiny Bauble
        { id = 6530, bonus = 50 },   -- Nightcrawlers
        { id = 6532, bonus = 75 },   -- Bright Baubles
        { id = 6533, bonus = 100 },  -- Aquadynamic Fish Attractor
        { id = 34861, bonus = 100 }, -- Sharpened Fish Hook (TBC)
    }

    for _, lure in ipairs(lures) do
        if lure.bonus >= skillGap then
            return lure.id, self.Lures[lure.id]
        end
    end

    return lures[#lures].id, self.Lures[lures[#lures].id]
end

function DB:GetFishForZone(zoneName)
    local zone = self.Zones[zoneName]
    if zone and zone.fish then
        local fishList = {}
        for _, itemID in ipairs(zone.fish) do
            local fishInfo = self.Fish[itemID]
            if fishInfo then
                table.insert(fishList, {
                    itemID = itemID,
                    name = fishInfo.name,
                    quality = fishInfo.quality,
                    minSkill = fishInfo.minSkill,
                })
            end
        end
        return fishList
    end
    return {}
end

function DB:GetPoolsForZone(zoneName)
    local zone = self.Zones[zoneName]
    if zone and zone.pools then
        local poolList = {}
        for _, poolName in ipairs(zone.pools) do
            local poolInfo = self.Pools[poolName]
            if poolInfo then
                table.insert(poolList, {
                    name = poolName,
                    info = poolInfo,
                })
            end
        end
        return poolList
    end
    return {}
end

function DB:GetTBCZones()
    local tbcZones = {}
    for zoneName, zoneData in pairs(self.Zones) do
        if zoneData.tbc then
            table.insert(tbcZones, {
                name = zoneName,
                minSkill = zoneData.minSkill,
                recommended = zoneData.recommended,
            })
        end
    end
    table.sort(tbcZones, function(a, b) return a.minSkill < b.minSkill end)
    return tbcZones
end

function DB:GetQualityColor(quality)
    local colors = {
        [DB.Quality.POOR] = { 0.62, 0.62, 0.62 },
        [DB.Quality.COMMON] = { 1.0, 1.0, 1.0 },
        [DB.Quality.UNCOMMON] = { 0.12, 1.0, 0.0 },
        [DB.Quality.RARE] = { 0.0, 0.44, 0.87 },
        [DB.Quality.EPIC] = { 0.64, 0.21, 0.93 },
        [DB.Quality.LEGENDARY] = { 1.0, 0.5, 0.0 },
    }
    return colors[quality] or colors[DB.Quality.COMMON]
end

FK:Debug("Database module loaded")
