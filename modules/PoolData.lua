--[[
    FishingKit - TBC Anniversary Edition
    PoolData Module - Pre-filled static pool spawn database
    Source: Wowhead (wowhead.com) pool spawn coordinate data

    Ships known pool spawn locations so users start with
    populated map pins on first install. These are reference
    data points — user-discovered pools (timesSeen >= 1)
    always take precedence.

    Format matches FK.db.poolLocations:
    FK.PoolData[uiMapID] = { {name="Pool Name", x=0.xxx, y=0.yyy}, ... }
]]

local ADDON_NAME, FK = ...
FK.PoolData = {}

-- ============================================================================
-- Westfall (uiMapID 1436)
-- Pools: Oily Blackmouth School, Firefin Snapper School, Floating Debris
-- Oily Blackmouth & Firefin Snapper share spawn points; Floating Debris has additional points
-- ============================================================================
FK.PoolData[1436] = {
    -- Oily Blackmouth School / Firefin Snapper School (shared spawn points)
    {name="Oily Blackmouth School", x=0.251, y=0.543},
    {name="Oily Blackmouth School", x=0.252, y=0.448},
    {name="Oily Blackmouth School", x=0.253, y=0.642},
    {name="Oily Blackmouth School", x=0.255, y=0.376},
    {name="Oily Blackmouth School", x=0.268, y=0.751},
    {name="Oily Blackmouth School", x=0.287, y=0.293},
    {name="Oily Blackmouth School", x=0.294, y=0.819},
    {name="Oily Blackmouth School", x=0.313, y=0.227},
    {name="Oily Blackmouth School", x=0.348, y=0.182},
    {name="Oily Blackmouth School", x=0.349, y=0.883},
    {name="Oily Blackmouth School", x=0.375, y=0.128},
    {name="Oily Blackmouth School", x=0.420, y=0.081},
    {name="Oily Blackmouth School", x=0.462, y=0.075},
    {name="Oily Blackmouth School", x=0.527, y=0.083},
    -- Floating Debris (additional points beyond the shared ones)
    {name="Floating Debris", x=0.608, y=0.116},
    {name="Floating Debris", x=0.613, y=0.161},
    {name="Floating Debris", x=0.636, y=0.370},
    {name="Floating Debris", x=0.637, y=0.213},
    {name="Floating Debris", x=0.637, y=0.300},
    {name="Floating Debris", x=0.654, y=0.427},
}

-- ============================================================================
-- Silverpine Forest (uiMapID 1421)
-- Pools: Oily Blackmouth School, Firefin Snapper School, Floating Debris
-- ============================================================================
FK.PoolData[1421] = {
    -- Oily Blackmouth School / Firefin Snapper School (shared spawn points)
    {name="Oily Blackmouth School", x=0.309, y=0.120},
    {name="Oily Blackmouth School", x=0.326, y=0.163},
    {name="Oily Blackmouth School", x=0.361, y=0.240},
    {name="Oily Blackmouth School", x=0.376, y=0.287},
    {name="Oily Blackmouth School", x=0.379, y=0.341},
    -- Floating Debris (additional points)
    {name="Floating Debris", x=0.420, y=0.825},
    {name="Floating Debris", x=0.439, y=0.778},
    {name="Floating Debris", x=0.465, y=0.768},
    {name="Floating Debris", x=0.468, y=0.823},
    {name="Floating Debris", x=0.572, y=0.182},
    {name="Floating Debris", x=0.572, y=0.256},
    {name="Floating Debris", x=0.582, y=0.326},
    {name="Floating Debris", x=0.598, y=0.363},
    {name="Floating Debris", x=0.612, y=0.161},
    {name="Floating Debris", x=0.639, y=0.396},
    {name="Floating Debris", x=0.648, y=0.196},
    {name="Floating Debris", x=0.652, y=0.363},
    {name="Floating Debris", x=0.658, y=0.124},
    {name="Floating Debris", x=0.670, y=0.438},
    {name="Floating Debris", x=0.691, y=0.269},
    {name="Floating Debris", x=0.696, y=0.328},
    {name="Floating Debris", x=0.702, y=0.176},
    {name="Floating Debris", x=0.703, y=0.091},
    {name="Floating Debris", x=0.705, y=0.378},
    {name="Floating Debris", x=0.766, y=0.188},
    {name="Floating Debris", x=0.766, y=0.258},
    {name="Floating Debris", x=0.777, y=0.328},
}

-- ============================================================================
-- Darkshore (uiMapID 1439)
-- Pools: Oily Blackmouth School, Firefin Snapper School, Floating Debris
-- All three share the same spawn points
-- ============================================================================
FK.PoolData[1439] = {
    {name="Oily Blackmouth School", x=0.338, y=0.860},
    {name="Oily Blackmouth School", x=0.349, y=0.813},
    {name="Oily Blackmouth School", x=0.358, y=0.700},
    {name="Oily Blackmouth School", x=0.360, y=0.413},
    {name="Oily Blackmouth School", x=0.362, y=0.644},
    {name="Oily Blackmouth School", x=0.367, y=0.786},
    {name="Oily Blackmouth School", x=0.371, y=0.576},
    {name="Oily Blackmouth School", x=0.374, y=0.469},
    {name="Oily Blackmouth School", x=0.374, y=0.743},
    {name="Oily Blackmouth School", x=0.376, y=0.363},
    {name="Oily Blackmouth School", x=0.376, y=0.518},
    {name="Oily Blackmouth School", x=0.389, y=0.295},
    {name="Oily Blackmouth School", x=0.395, y=0.675},
    {name="Oily Blackmouth School", x=0.419, y=0.285},
    {name="Oily Blackmouth School", x=0.430, y=0.413},
    {name="Oily Blackmouth School", x=0.433, y=0.190},
    {name="Oily Blackmouth School", x=0.435, y=0.246},
    {name="Oily Blackmouth School", x=0.450, y=0.382},
    {name="Oily Blackmouth School", x=0.453, y=0.640},
    {name="Oily Blackmouth School", x=0.453, y=0.689},
    {name="Oily Blackmouth School", x=0.455, y=0.596},
    {name="Oily Blackmouth School", x=0.462, y=0.551},
    {name="Oily Blackmouth School", x=0.470, y=0.423},
    {name="Oily Blackmouth School", x=0.474, y=0.475},
    {name="Oily Blackmouth School", x=0.483, y=0.382},
    {name="Oily Blackmouth School", x=0.487, y=0.176},
    {name="Oily Blackmouth School", x=0.497, y=0.411},
    {name="Oily Blackmouth School", x=0.509, y=0.335},
    {name="Oily Blackmouth School", x=0.533, y=0.157},
    {name="Oily Blackmouth School", x=0.569, y=0.130},
    {name="Oily Blackmouth School", x=0.586, y=0.093},
    {name="Oily Blackmouth School", x=0.613, y=0.052},
}

-- ============================================================================
-- Northern Barrens (uiMapID 1413)
-- Pools: Oily Blackmouth School, Firefin Snapper School, Floating Debris,
--        School of Deviate Fish, Southern Barrens pools
-- ============================================================================
FK.PoolData[1413] = {
    -- Oily Blackmouth School / Firefin Snapper School / Floating Debris (shared coastal spawns)
    {name="Oily Blackmouth School", x=0.687, y=0.747},
    {name="Oily Blackmouth School", x=0.696, y=0.716},
    {name="Oily Blackmouth School", x=0.704, y=0.778},
    {name="Oily Blackmouth School", x=0.712, y=0.691},
    {name="Oily Blackmouth School", x=0.712, y=0.928},
    {name="Oily Blackmouth School", x=0.716, y=0.838},
    {name="Oily Blackmouth School", x=0.720, y=0.803},
    {name="Oily Blackmouth School", x=0.725, y=0.889},
    {name="Oily Blackmouth School", x=0.743, y=0.815},
    -- School of Deviate Fish
    {name="School of Deviate Fish", x=0.375, y=0.436},
    {name="School of Deviate Fish", x=0.375, y=0.471},
    {name="School of Deviate Fish", x=0.401, y=0.743},
    {name="School of Deviate Fish", x=0.554, y=0.786},
    {name="School of Deviate Fish", x=0.554, y=0.815},
    -- Southern Barrens area (same uiMapID in Classic)
    {name="Oily Blackmouth School", x=0.695, y=0.433},
    {name="Oily Blackmouth School", x=0.696, y=0.394},
    {name="Oily Blackmouth School", x=0.712, y=0.477},
    {name="Oily Blackmouth School", x=0.725, y=0.322},
    {name="Oily Blackmouth School", x=0.725, y=0.374},
}

-- ============================================================================
-- Wetlands (uiMapID 1437)
-- Pools: Oily Blackmouth School, Firefin Snapper School, Floating Wreckage (Schooner)
-- ============================================================================
FK.PoolData[1437] = {
    -- Oily Blackmouth School / Firefin Snapper School (shared coastal spawns)
    {name="Oily Blackmouth School", x=0.059, y=0.621},
    {name="Oily Blackmouth School", x=0.072, y=0.559},
    {name="Oily Blackmouth School", x=0.080, y=0.592},
    {name="Oily Blackmouth School", x=0.086, y=0.528},
    {name="Oily Blackmouth School", x=0.099, y=0.625},
    {name="Oily Blackmouth School", x=0.123, y=0.533},
    {name="Oily Blackmouth School", x=0.126, y=0.374},
    {name="Oily Blackmouth School", x=0.132, y=0.312},
    {name="Oily Blackmouth School", x=0.133, y=0.582},
    {name="Oily Blackmouth School", x=0.137, y=0.535},
    {name="Oily Blackmouth School", x=0.154, y=0.258},
    {name="Oily Blackmouth School", x=0.156, y=0.623},
    {name="Oily Blackmouth School", x=0.183, y=0.512},
    {name="Oily Blackmouth School", x=0.183, y=0.609},
    {name="Oily Blackmouth School", x=0.186, y=0.209},
    {name="Oily Blackmouth School", x=0.202, y=0.545},
    {name="Oily Blackmouth School", x=0.211, y=0.580},
    {name="Oily Blackmouth School", x=0.244, y=0.192},
    {name="Oily Blackmouth School", x=0.286, y=0.165},
    {name="Oily Blackmouth School", x=0.318, y=0.139},
    -- Schooner Wreckage (additional inland/harbor points)
    {name="Schooner Wreckage", x=0.160, y=0.347},
    {name="Schooner Wreckage", x=0.186, y=0.462},
    {name="Schooner Wreckage", x=0.189, y=0.413},
    {name="Schooner Wreckage", x=0.217, y=0.357},
    {name="Schooner Wreckage", x=0.240, y=0.260},
    {name="Schooner Wreckage", x=0.270, y=0.322},
    {name="Schooner Wreckage", x=0.309, y=0.219},
    {name="Schooner Wreckage", x=0.309, y=0.345},
    {name="Schooner Wreckage", x=0.338, y=0.285},
    {name="Schooner Wreckage", x=0.344, y=0.260},
    {name="Schooner Wreckage", x=0.396, y=0.275},
    {name="Schooner Wreckage", x=0.436, y=0.357},
    {name="Schooner Wreckage", x=0.448, y=0.302},
    {name="Schooner Wreckage", x=0.475, y=0.328},
    {name="Schooner Wreckage", x=0.490, y=0.368},
    {name="Schooner Wreckage", x=0.507, y=0.324},
    {name="Schooner Wreckage", x=0.529, y=0.361},
    {name="Schooner Wreckage", x=0.534, y=0.403},
    {name="Schooner Wreckage", x=0.547, y=0.450},
    {name="Schooner Wreckage", x=0.586, y=0.603},
    {name="Schooner Wreckage", x=0.589, y=0.685},
    {name="Schooner Wreckage", x=0.591, y=0.487},
    {name="Schooner Wreckage", x=0.598, y=0.528},
    {name="Schooner Wreckage", x=0.606, y=0.565},
    {name="Schooner Wreckage", x=0.611, y=0.726},
    {name="Schooner Wreckage", x=0.634, y=0.580},
    {name="Schooner Wreckage", x=0.650, y=0.646},
    {name="Schooner Wreckage", x=0.651, y=0.611},
    {name="Schooner Wreckage", x=0.656, y=0.683},
    {name="Schooner Wreckage", x=0.663, y=0.728},
}

-- ============================================================================
-- Hillsbrad Foothills (uiMapID 1424)
-- Pools: Oily Blackmouth School, Firefin Snapper School, Schooner Wreckage
-- ============================================================================
FK.PoolData[1424] = {
    -- Oily Blackmouth School / Firefin Snapper School (shared coastal spawns)
    {name="Oily Blackmouth School", x=0.296, y=0.836},
    {name="Oily Blackmouth School", x=0.326, y=0.788},
    {name="Oily Blackmouth School", x=0.352, y=0.811},
    {name="Oily Blackmouth School", x=0.391, y=0.792},
    {name="Oily Blackmouth School", x=0.422, y=0.786},
    {name="Oily Blackmouth School", x=0.471, y=0.761},
    {name="Oily Blackmouth School", x=0.493, y=0.739},
    {name="Oily Blackmouth School", x=0.524, y=0.755},
    {name="Oily Blackmouth School", x=0.538, y=0.796},
    {name="Oily Blackmouth School", x=0.568, y=0.836},
    {name="Oily Blackmouth School", x=0.590, y=0.873},
    -- Schooner Wreckage (additional inland points)
    {name="Schooner Wreckage", x=0.288, y=0.304},
    {name="Schooner Wreckage", x=0.319, y=0.297},
    {name="Schooner Wreckage", x=0.343, y=0.264},
    {name="Schooner Wreckage", x=0.370, y=0.234},
    {name="Schooner Wreckage", x=0.391, y=0.190},
    {name="Schooner Wreckage", x=0.404, y=0.153},
    {name="Schooner Wreckage", x=0.427, y=0.120},
    {name="Schooner Wreckage", x=0.522, y=0.700},
    {name="Schooner Wreckage", x=0.540, y=0.646},
    {name="Schooner Wreckage", x=0.576, y=0.615},
    {name="Schooner Wreckage", x=0.593, y=0.586},
    {name="Schooner Wreckage", x=0.607, y=0.528},
    {name="Schooner Wreckage", x=0.612, y=0.438},
    {name="Schooner Wreckage", x=0.634, y=0.386},
    {name="Schooner Wreckage", x=0.672, y=0.349},
    {name="Schooner Wreckage", x=0.693, y=0.300},
}

-- ============================================================================
-- Ashenvale (uiMapID 1440)
-- Pools: Oily Blackmouth School, Firefin Snapper School, Schooner Wreckage
-- ============================================================================
FK.PoolData[1440] = {
    -- Oily Blackmouth School / Firefin Snapper School (shared coastal spawns)
    {name="Oily Blackmouth School", x=0.084, y=0.135},
    {name="Oily Blackmouth School", x=0.104, y=0.168},
    {name="Oily Blackmouth School", x=0.106, y=0.283},
    {name="Oily Blackmouth School", x=0.128, y=0.184},
    {name="Oily Blackmouth School", x=0.130, y=0.242},
    {name="Oily Blackmouth School", x=0.133, y=0.269},
    {name="Oily Blackmouth School", x=0.139, y=0.215},
    -- Schooner Wreckage (additional river/lake points)
    {name="Schooner Wreckage", x=0.330, y=0.499},
    {name="Schooner Wreckage", x=0.357, y=0.520},
    {name="Schooner Wreckage", x=0.370, y=0.466},
    {name="Schooner Wreckage", x=0.384, y=0.502},
    {name="Schooner Wreckage", x=0.450, y=0.699},
    {name="Schooner Wreckage", x=0.474, y=0.728},
    {name="Schooner Wreckage", x=0.490, y=0.679},
    {name="Schooner Wreckage", x=0.516, y=0.726},
    {name="Schooner Wreckage", x=0.525, y=0.695},
    {name="Schooner Wreckage", x=0.590, y=0.792},
    {name="Schooner Wreckage", x=0.612, y=0.757},
    {name="Schooner Wreckage", x=0.633, y=0.716},
    {name="Schooner Wreckage", x=0.646, y=0.669},
    {name="Schooner Wreckage", x=0.683, y=0.633},
    {name="Schooner Wreckage", x=0.699, y=0.578},
    {name="Schooner Wreckage", x=0.724, y=0.533},
    {name="Schooner Wreckage", x=0.740, y=0.504},
    {name="Schooner Wreckage", x=0.762, y=0.452},
    {name="Schooner Wreckage", x=0.781, y=0.506},
    {name="Schooner Wreckage", x=0.788, y=0.582},
    {name="Schooner Wreckage", x=0.788, y=0.642},
    {name="Schooner Wreckage", x=0.791, y=0.706},
    {name="Schooner Wreckage", x=0.825, y=0.636},
    {name="Schooner Wreckage", x=0.854, y=0.679},
}

-- ============================================================================
-- Stonetalon Mountains (uiMapID 1442)
-- Pools: Greater Sagefish School, Schooner Wreckage (shared spawn points)
-- ============================================================================
FK.PoolData[1442] = {
    {name="Greater Sagefish School", x=0.480, y=0.735},
    {name="Greater Sagefish School", x=0.512, y=0.471},
    {name="Greater Sagefish School", x=0.630, y=0.518},
    {name="Greater Sagefish School", x=0.663, y=0.477},
    {name="Greater Sagefish School", x=0.664, y=0.565},
    {name="Greater Sagefish School", x=0.717, y=0.588},
}

-- ============================================================================
-- Arathi Highlands (uiMapID 1417)
-- Pools: Oily Blackmouth School, Firefin Snapper School, Schooner Wreckage,
--        Greater Sagefish School
-- ============================================================================
FK.PoolData[1417] = {
    -- Oily Blackmouth School / Firefin Snapper School / Schooner Wreckage (shared coastal)
    {name="Oily Blackmouth School", x=0.215, y=0.866},
    {name="Oily Blackmouth School", x=0.224, y=0.813},
    {name="Oily Blackmouth School", x=0.238, y=0.850},
    {name="Oily Blackmouth School", x=0.259, y=0.805},
    {name="Oily Blackmouth School", x=0.266, y=0.827},
    -- Greater Sagefish School (inland)
    {name="Greater Sagefish School", x=0.177, y=0.537},
    {name="Greater Sagefish School", x=0.216, y=0.543},
    {name="Greater Sagefish School", x=0.392, y=0.788},
    {name="Greater Sagefish School", x=0.396, y=0.730},
    {name="Greater Sagefish School", x=0.397, y=0.840},
    {name="Greater Sagefish School", x=0.406, y=0.879},
    {name="Greater Sagefish School", x=0.629, y=0.650},
    {name="Greater Sagefish School", x=0.634, y=0.689},
}

-- ============================================================================
-- Swamp of Sorrows (uiMapID 1435)
-- Pools: Oily Blackmouth School, Firefin Snapper School, Stonescale Eel Swarm,
--        Floating Wreckage (all share spawn points)
-- ============================================================================
FK.PoolData[1435] = {
    {name="Oily Blackmouth School", x=0.636, y=0.477},
    {name="Oily Blackmouth School", x=0.636, y=0.588},
    {name="Oily Blackmouth School", x=0.682, y=0.629},
    {name="Oily Blackmouth School", x=0.727, y=0.423},
    {name="Oily Blackmouth School", x=0.740, y=0.619},
    {name="Stonescale Eel Swarm", x=0.742, y=0.081},
    {name="Stonescale Eel Swarm", x=0.775, y=0.100},
    {name="Oily Blackmouth School", x=0.779, y=0.442},
    {name="Stonescale Eel Swarm", x=0.796, y=0.077},
    {name="Stonescale Eel Swarm", x=0.800, y=0.135},
    {name="Floating Wreckage", x=0.801, y=0.910},
    {name="Stonescale Eel Swarm", x=0.818, y=0.161},
    {name="Floating Wreckage", x=0.835, y=0.881},
    {name="Stonescale Eel Swarm", x=0.840, y=0.188},
    {name="Floating Wreckage", x=0.848, y=0.829},
    {name="Oily Blackmouth School", x=0.856, y=0.460},
    {name="Stonescale Eel Swarm", x=0.858, y=0.219},
    {name="Floating Wreckage", x=0.862, y=0.776},
    {name="Stonescale Eel Swarm", x=0.873, y=0.260},
    {name="Floating Wreckage", x=0.888, y=0.712},
    {name="Stonescale Eel Swarm", x=0.893, y=0.318},
    {name="Oily Blackmouth School", x=0.895, y=0.584},
    {name="Oily Blackmouth School", x=0.900, y=0.434},
    {name="Stonescale Eel Swarm", x=0.904, y=0.372},
    {name="Floating Wreckage", x=0.908, y=0.652},
}

-- ============================================================================
-- Desolace (uiMapID 1443)
-- Pools: Oily Blackmouth School, Firefin Snapper School, Greater Sagefish School
-- ============================================================================
FK.PoolData[1443] = {
    -- Oily Blackmouth School / Firefin Snapper School (shared coastal spawns)
    {name="Oily Blackmouth School", x=0.218, y=0.708},
    {name="Oily Blackmouth School", x=0.250, y=0.741},
    {name="Oily Blackmouth School", x=0.252, y=0.800},
    {name="Oily Blackmouth School", x=0.345, y=0.417},
    {name="Oily Blackmouth School", x=0.360, y=0.355},
    {name="Oily Blackmouth School", x=0.362, y=0.277},
    {name="Oily Blackmouth School", x=0.398, y=0.217},
    {name="Oily Blackmouth School", x=0.420, y=0.215},
    {name="Oily Blackmouth School", x=0.428, y=0.165},
    {name="Oily Blackmouth School", x=0.462, y=0.145},
    -- Greater Sagefish School (inland)
    {name="Greater Sagefish School", x=0.426, y=0.520},
    {name="Greater Sagefish School", x=0.437, y=0.803},
    {name="Greater Sagefish School", x=0.452, y=0.547},
    {name="Greater Sagefish School", x=0.624, y=0.353},
    {name="Greater Sagefish School", x=0.639, y=0.448},
    {name="Greater Sagefish School", x=0.660, y=0.401},
    {name="Greater Sagefish School", x=0.700, y=0.784},
    {name="Greater Sagefish School", x=0.731, y=0.763},
    {name="Greater Sagefish School", x=0.733, y=0.689},
}

-- ============================================================================
-- Dustwallow Marsh (uiMapID 1445)
-- Pools: Oily Blackmouth School, Firefin Snapper School, Greater Sagefish School
-- ============================================================================
FK.PoolData[1445] = {
    -- Greater Sagefish School (inland)
    {name="Greater Sagefish School", x=0.349, y=0.568},
    {name="Greater Sagefish School", x=0.360, y=0.683},
    {name="Greater Sagefish School", x=0.373, y=0.217},
    {name="Greater Sagefish School", x=0.392, y=0.596},
    {name="Greater Sagefish School", x=0.395, y=0.714},
    {name="Greater Sagefish School", x=0.415, y=0.644},
    {name="Greater Sagefish School", x=0.448, y=0.196},
    {name="Greater Sagefish School", x=0.476, y=0.689},
    {name="Greater Sagefish School", x=0.477, y=0.770},
    {name="Greater Sagefish School", x=0.488, y=0.223},
    {name="Greater Sagefish School", x=0.506, y=0.695},
    {name="Greater Sagefish School", x=0.569, y=0.697},
    -- Oily Blackmouth School / Firefin Snapper School (shared coastal spawns)
    {name="Oily Blackmouth School", x=0.551, y=0.149},
    {name="Oily Blackmouth School", x=0.569, y=0.613},
    {name="Oily Blackmouth School", x=0.586, y=0.176},
    {name="Oily Blackmouth School", x=0.597, y=0.568},
    {name="Oily Blackmouth School", x=0.598, y=0.631},
    {name="Oily Blackmouth School", x=0.606, y=0.446},
    {name="Oily Blackmouth School", x=0.613, y=0.271},
    {name="Oily Blackmouth School", x=0.626, y=0.666},
    {name="Oily Blackmouth School", x=0.634, y=0.514},
    {name="Oily Blackmouth School", x=0.637, y=0.363},
    {name="Oily Blackmouth School", x=0.678, y=0.566},
    {name="Oily Blackmouth School", x=0.693, y=0.456},
    {name="Oily Blackmouth School", x=0.720, y=0.535},
}

-- ============================================================================
-- Feralas (uiMapID 1444)
-- Pools: Oily Blackmouth School, Firefin Snapper School, Greater Sagefish School
-- ============================================================================
FK.PoolData[1444] = {
    -- Oily Blackmouth School / Firefin Snapper School (shared coastal spawns)
    {name="Oily Blackmouth School", x=0.243, y=0.467},
    {name="Oily Blackmouth School", x=0.291, y=0.557},
    {name="Oily Blackmouth School", x=0.294, y=0.411},
    {name="Oily Blackmouth School", x=0.331, y=0.454},
    {name="Oily Blackmouth School", x=0.338, y=0.520},
    {name="Oily Blackmouth School", x=0.363, y=0.357},
    {name="Oily Blackmouth School", x=0.404, y=0.374},
    {name="Oily Blackmouth School", x=0.441, y=0.452},
    {name="Oily Blackmouth School", x=0.443, y=0.403},
    {name="Oily Blackmouth School", x=0.444, y=0.526},
    {name="Oily Blackmouth School", x=0.465, y=0.576},
    {name="Oily Blackmouth School", x=0.470, y=0.526},
    -- Greater Sagefish School (inland)
    {name="Greater Sagefish School", x=0.471, y=0.124},
    {name="Greater Sagefish School", x=0.484, y=0.099},
    {name="Greater Sagefish School", x=0.488, y=0.137},
    {name="Greater Sagefish School", x=0.494, y=0.052},
    {name="Greater Sagefish School", x=0.510, y=0.149},
    {name="Greater Sagefish School", x=0.512, y=0.062},
    {name="Greater Sagefish School", x=0.532, y=0.066},
    {name="Greater Sagefish School", x=0.532, y=0.145},
    {name="Greater Sagefish School", x=0.538, y=0.108},
    {name="Greater Sagefish School", x=0.563, y=0.524},
    {name="Greater Sagefish School", x=0.621, y=0.495},
    {name="Greater Sagefish School", x=0.637, y=0.520},
    {name="Greater Sagefish School", x=0.641, y=0.566},
    {name="Greater Sagefish School", x=0.743, y=0.477},
    {name="Greater Sagefish School", x=0.752, y=0.425},
    {name="Greater Sagefish School", x=0.775, y=0.467},
    {name="Greater Sagefish School", x=0.792, y=0.504},
}

-- ============================================================================
-- The Hinterlands (uiMapID 1425)
-- Pools: Oily Blackmouth School, Firefin Snapper School, Greater Sagefish School
-- ============================================================================
FK.PoolData[1425] = {
    -- Oily Blackmouth School / Firefin Snapper School (shared coastal spawns)
    {name="Oily Blackmouth School", x=0.794, y=0.619},
    {name="Oily Blackmouth School", x=0.794, y=0.673},
    {name="Oily Blackmouth School", x=0.813, y=0.471},
    {name="Oily Blackmouth School", x=0.818, y=0.357},
    {name="Oily Blackmouth School", x=0.819, y=0.419},
    {name="Oily Blackmouth School", x=0.819, y=0.576},
    {name="Oily Blackmouth School", x=0.826, y=0.518},
    {name="Oily Blackmouth School", x=0.841, y=0.392},
    -- Greater Sagefish School (inland)
    {name="Greater Sagefish School", x=0.286, y=0.448},
    {name="Greater Sagefish School", x=0.310, y=0.444},
    {name="Greater Sagefish School", x=0.344, y=0.710},
    {name="Greater Sagefish School", x=0.398, y=0.596},
    {name="Greater Sagefish School", x=0.479, y=0.372},
    {name="Greater Sagefish School", x=0.516, y=0.357},
    {name="Greater Sagefish School", x=0.559, y=0.359},
    {name="Greater Sagefish School", x=0.564, y=0.598},
    {name="Greater Sagefish School", x=0.573, y=0.557},
    {name="Greater Sagefish School", x=0.595, y=0.363},
    {name="Greater Sagefish School", x=0.638, y=0.382},
    {name="Greater Sagefish School", x=0.641, y=0.609},
    {name="Greater Sagefish School", x=0.677, y=0.394},
    {name="Greater Sagefish School", x=0.709, y=0.429},
    {name="Greater Sagefish School", x=0.748, y=0.456},
}

-- ============================================================================
-- Tanaris (uiMapID 1446)
-- Pools: Oily Blackmouth School, Firefin Snapper School, Stonescale Eel Swarm,
--        Floating Wreckage (all share same coastal spawn points)
-- ============================================================================
FK.PoolData[1446] = {
    {name="Stonescale Eel Swarm", x=0.484, y=0.858},
    {name="Stonescale Eel Swarm", x=0.506, y=0.914},
    {name="Oily Blackmouth School", x=0.533, y=0.333},
    {name="Oily Blackmouth School", x=0.536, y=0.392},
    {name="Stonescale Eel Swarm", x=0.536, y=0.955},
    {name="Oily Blackmouth School", x=0.540, y=0.266},
    {name="Oily Blackmouth School", x=0.553, y=0.436},
    {name="Stonescale Eel Swarm", x=0.566, y=0.920},
    {name="Oily Blackmouth School", x=0.585, y=0.440},
    {name="Stonescale Eel Swarm", x=0.594, y=0.864},
    {name="Stonescale Eel Swarm", x=0.599, y=0.798},
    {name="Oily Blackmouth School", x=0.626, y=0.429},
    {name="Floating Wreckage", x=0.636, y=0.621},
    {name="Floating Wreckage", x=0.647, y=0.592},
    {name="Oily Blackmouth School", x=0.674, y=0.566},
    {name="Oily Blackmouth School", x=0.677, y=0.405},
    {name="Oily Blackmouth School", x=0.712, y=0.533},
    {name="Oily Blackmouth School", x=0.720, y=0.433},
    {name="Oily Blackmouth School", x=0.730, y=0.485},
}

-- ============================================================================
-- Azshara (uiMapID 1447)
-- Pools: Oily Blackmouth School, Firefin Snapper School, Floating Debris
-- All share the same spawn points
-- ============================================================================
FK.PoolData[1447] = {
    {name="Oily Blackmouth School", x=0.426, y=0.850},
    {name="Oily Blackmouth School", x=0.431, y=0.467},
    {name="Oily Blackmouth School", x=0.439, y=0.541},
    {name="Oily Blackmouth School", x=0.444, y=0.592},
    {name="Oily Blackmouth School", x=0.457, y=0.400},
    {name="Oily Blackmouth School", x=0.461, y=0.867},
    {name="Oily Blackmouth School", x=0.572, y=0.928},
    {name="Oily Blackmouth School", x=0.585, y=0.879},
    {name="Oily Blackmouth School", x=0.603, y=0.085},
    {name="Oily Blackmouth School", x=0.612, y=0.673},
    {name="Oily Blackmouth School", x=0.620, y=0.056},
    {name="Oily Blackmouth School", x=0.637, y=0.889},
    {name="Oily Blackmouth School", x=0.656, y=0.662},
    {name="Oily Blackmouth School", x=0.711, y=0.730},
    {name="Oily Blackmouth School", x=0.713, y=0.609},
    {name="Oily Blackmouth School", x=0.718, y=0.365},
    {name="Oily Blackmouth School", x=0.724, y=0.792},
    {name="Oily Blackmouth School", x=0.743, y=0.675},
    {name="Oily Blackmouth School", x=0.756, y=0.312},
    {name="Oily Blackmouth School", x=0.775, y=0.580},
    {name="Oily Blackmouth School", x=0.788, y=0.623},
    {name="Oily Blackmouth School", x=0.800, y=0.357},
    {name="Oily Blackmouth School", x=0.808, y=0.252},
    {name="Oily Blackmouth School", x=0.845, y=0.384},
    {name="Oily Blackmouth School", x=0.849, y=0.539},
    {name="Oily Blackmouth School", x=0.861, y=0.594},
    {name="Oily Blackmouth School", x=0.892, y=0.372},
}

-- ============================================================================
-- Thousand Needles (uiMapID 1441)
-- Pools: Oily Blackmouth School, Firefin Snapper School, Stonescale Eel Swarm,
--        Floating Wreckage, Greater Sagefish School
-- ============================================================================
FK.PoolData[1441] = {
    -- Oily Blackmouth / Stonescale Eel / Floating Wreckage (shared coastal spawns)
    {name="Oily Blackmouth School", x=0.760, y=0.006},
    {name="Oily Blackmouth School", x=0.768, y=0.753},
    {name="Oily Blackmouth School", x=0.792, y=0.704},
    {name="Oily Blackmouth School", x=0.804, y=0.733},
    {name="Oily Blackmouth School", x=0.896, y=0.772},
    {name="Oily Blackmouth School", x=0.900, y=0.735},
    {name="Oily Blackmouth School", x=0.927, y=0.712},
    -- Greater Sagefish School (inland)
    {name="Greater Sagefish School", x=0.893, y=0.869},
}

-- ============================================================================
-- Blasted Lands (uiMapID 1419)
-- Pools: Oily Blackmouth School, Firefin Snapper School, Stonescale Eel Swarm,
--        Floating Wreckage, Greater Sagefish School
-- ============================================================================
FK.PoolData[1419] = {
    -- Oily Blackmouth / Stonescale Eel / Floating Wreckage (shared coastal spawns)
    {name="Stonescale Eel Swarm", x=0.432, y=0.908},
    {name="Stonescale Eel Swarm", x=0.467, y=0.885},
    {name="Stonescale Eel Swarm", x=0.527, y=0.848},
    {name="Stonescale Eel Swarm", x=0.575, y=0.842},
    {name="Stonescale Eel Swarm", x=0.615, y=0.848},
    {name="Stonescale Eel Swarm", x=0.680, y=0.796},
    {name="Stonescale Eel Swarm", x=0.693, y=0.359},
    {name="Stonescale Eel Swarm", x=0.695, y=0.403},
    {name="Stonescale Eel Swarm", x=0.698, y=0.297},
    {name="Stonescale Eel Swarm", x=0.709, y=0.236},
    {name="Stonescale Eel Swarm", x=0.712, y=0.755},
    {name="Stonescale Eel Swarm", x=0.721, y=0.438},
    {name="Stonescale Eel Swarm", x=0.721, y=0.623},
    {name="Stonescale Eel Swarm", x=0.721, y=0.695},
    {name="Stonescale Eel Swarm", x=0.738, y=0.211},
    -- Greater Sagefish School (inland)
    {name="Greater Sagefish School", x=0.380, y=0.761},
    {name="Greater Sagefish School", x=0.401, y=0.774},
    {name="Greater Sagefish School", x=0.423, y=0.636},
    {name="Greater Sagefish School", x=0.423, y=0.687},
    {name="Greater Sagefish School", x=0.423, y=0.751},
    {name="Greater Sagefish School", x=0.424, y=0.819},
    {name="Greater Sagefish School", x=0.446, y=0.702},
    {name="Greater Sagefish School", x=0.448, y=0.825},
    {name="Greater Sagefish School", x=0.453, y=0.646},
    {name="Greater Sagefish School", x=0.483, y=0.671},
}

-- ============================================================================
-- Duskwood (uiMapID 1431)
-- Pools: Floating Debris
-- ============================================================================
FK.PoolData[1431] = {
    {name="Floating Debris", x=0.053, y=0.355},
    {name="Floating Debris", x=0.072, y=0.438},
    {name="Floating Debris", x=0.082, y=0.293},
    {name="Floating Debris", x=0.082, y=0.508},
    {name="Floating Debris", x=0.085, y=0.578},
    {name="Floating Debris", x=0.086, y=0.652},
    {name="Floating Debris", x=0.113, y=0.706},
    {name="Floating Debris", x=0.130, y=0.250},
    {name="Floating Debris", x=0.145, y=0.745},
    {name="Floating Debris", x=0.178, y=0.782},
    {name="Floating Debris", x=0.207, y=0.233},
    {name="Floating Debris", x=0.277, y=0.248},
    {name="Floating Debris", x=0.323, y=0.221},
    {name="Floating Debris", x=0.370, y=0.176},
    {name="Floating Debris", x=0.422, y=0.166},
    {name="Floating Debris", x=0.474, y=0.145},
    {name="Floating Debris", x=0.507, y=0.106},
    {name="Floating Debris", x=0.568, y=0.114},
    {name="Floating Debris", x=0.610, y=0.135},
    {name="Floating Debris", x=0.686, y=0.145},
    {name="Floating Debris", x=0.752, y=0.159},
    {name="Floating Debris", x=0.816, y=0.161},
    {name="Floating Debris", x=0.882, y=0.124},
}

-- ============================================================================
-- Redridge Mountains (uiMapID 1433)
-- Pools: Floating Debris
-- ============================================================================
FK.PoolData[1433] = {
    {name="Floating Debris", x=0.193, y=0.458},
    {name="Floating Debris", x=0.215, y=0.500},
    {name="Floating Debris", x=0.231, y=0.448},
    {name="Floating Debris", x=0.250, y=0.516},
    {name="Floating Debris", x=0.273, y=0.460},
    {name="Floating Debris", x=0.283, y=0.506},
    {name="Floating Debris", x=0.329, y=0.514},
    {name="Floating Debris", x=0.344, y=0.466},
    {name="Floating Debris", x=0.348, y=0.547},
    {name="Floating Debris", x=0.361, y=0.596},
    {name="Floating Debris", x=0.380, y=0.615},
    {name="Floating Debris", x=0.405, y=0.596},
    {name="Floating Debris", x=0.431, y=0.623},
    {name="Floating Debris", x=0.457, y=0.615},
    {name="Floating Debris", x=0.485, y=0.621},
    {name="Floating Debris", x=0.502, y=0.592},
    {name="Floating Debris", x=0.516, y=0.479},
    {name="Floating Debris", x=0.518, y=0.557},
    {name="Floating Debris", x=0.547, y=0.500},
    {name="Floating Debris", x=0.636, y=0.625},
    {name="Floating Debris", x=0.661, y=0.611},
}

-- ============================================================================
-- Eastern Plaguelands (uiMapID 1423)
-- Pools: Greater Sagefish School, Floating Wreckage (shared spawn points)
-- ============================================================================
FK.PoolData[1423] = {
    {name="Greater Sagefish School", x=0.225, y=0.166},
    {name="Greater Sagefish School", x=0.261, y=0.155},
    {name="Greater Sagefish School", x=0.296, y=0.165},
    {name="Greater Sagefish School", x=0.309, y=0.133},
    {name="Greater Sagefish School", x=0.317, y=0.161},
    {name="Greater Sagefish School", x=0.453, y=0.419},
    {name="Greater Sagefish School", x=0.459, y=0.615},
    {name="Greater Sagefish School", x=0.465, y=0.648},
    {name="Greater Sagefish School", x=0.470, y=0.456},
    {name="Greater Sagefish School", x=0.488, y=0.413},
    {name="Greater Sagefish School", x=0.505, y=0.646},
    {name="Greater Sagefish School", x=0.524, y=0.588},
    {name="Greater Sagefish School", x=0.542, y=0.720},
    {name="Greater Sagefish School", x=0.544, y=0.448},
    {name="Greater Sagefish School", x=0.554, y=0.768},
    {name="Greater Sagefish School", x=0.569, y=0.710},
    {name="Greater Sagefish School", x=0.602, y=0.733},
    {name="Greater Sagefish School", x=0.603, y=0.475},
    {name="Greater Sagefish School", x=0.642, y=0.471},
    {name="Greater Sagefish School", x=0.658, y=0.295},
    {name="Greater Sagefish School", x=0.674, y=0.549},
    {name="Greater Sagefish School", x=0.676, y=0.598},
    {name="Greater Sagefish School", x=0.677, y=0.458},
    {name="Greater Sagefish School", x=0.690, y=0.514},
    {name="Greater Sagefish School", x=0.715, y=0.530},
    {name="Greater Sagefish School", x=0.715, y=0.574},
}

-- ============================================================================
-- Western Plaguelands (uiMapID 1422)
-- Pools: Greater Sagefish School
-- ============================================================================
FK.PoolData[1422] = {
    {name="Greater Sagefish School", x=0.299, y=0.689},
    {name="Greater Sagefish School", x=0.326, y=0.704},
    {name="Greater Sagefish School", x=0.352, y=0.693},
    {name="Greater Sagefish School", x=0.383, y=0.751},
    {name="Greater Sagefish School", x=0.417, y=0.768},
    {name="Greater Sagefish School", x=0.454, y=0.768},
    {name="Greater Sagefish School", x=0.465, y=0.745},
    {name="Greater Sagefish School", x=0.507, y=0.712},
    {name="Greater Sagefish School", x=0.534, y=0.739},
    {name="Greater Sagefish School", x=0.559, y=0.704},
    {name="Greater Sagefish School", x=0.575, y=0.788},
    {name="Greater Sagefish School", x=0.604, y=0.625},
    {name="Greater Sagefish School", x=0.621, y=0.823},
    {name="Greater Sagefish School", x=0.654, y=0.833},
    {name="Greater Sagefish School", x=0.667, y=0.629},
    {name="Greater Sagefish School", x=0.694, y=0.584},
    {name="Greater Sagefish School", x=0.695, y=0.446},
    {name="Greater Sagefish School", x=0.698, y=0.514},
    {name="Greater Sagefish School", x=0.700, y=0.398},
    {name="Greater Sagefish School", x=0.716, y=0.825},
    {name="Greater Sagefish School", x=0.730, y=0.594},
    {name="Greater Sagefish School", x=0.759, y=0.813},
    {name="Greater Sagefish School", x=0.765, y=0.617},
    {name="Greater Sagefish School", x=0.777, y=0.656},
    {name="Greater Sagefish School", x=0.788, y=0.800},
    {name="Greater Sagefish School", x=0.796, y=0.704},
    {name="Greater Sagefish School", x=0.797, y=0.747},
}

-- ============================================================================
-- Un'Goro Crater (uiMapID 1449)
-- Pools: Greater Sagefish School
-- ============================================================================
FK.PoolData[1449] = {
    {name="Greater Sagefish School", x=0.261, y=0.508},
    {name="Greater Sagefish School", x=0.317, y=0.518},
    {name="Greater Sagefish School", x=0.327, y=0.586},
    {name="Greater Sagefish School", x=0.335, y=0.250},
    {name="Greater Sagefish School", x=0.347, y=0.485},
    {name="Greater Sagefish School", x=0.356, y=0.551},
    {name="Greater Sagefish School", x=0.384, y=0.258},
    {name="Greater Sagefish School", x=0.431, y=0.302},
    {name="Greater Sagefish School", x=0.443, y=0.400},
    {name="Greater Sagefish School", x=0.490, y=0.398},
    {name="Greater Sagefish School", x=0.556, y=0.401},
    {name="Greater Sagefish School", x=0.608, y=0.427},
    {name="Greater Sagefish School", x=0.638, y=0.687},
    {name="Greater Sagefish School", x=0.651, y=0.739},
    {name="Greater Sagefish School", x=0.660, y=0.576},
    {name="Greater Sagefish School", x=0.668, y=0.431},
    {name="Greater Sagefish School", x=0.682, y=0.648},
    {name="Greater Sagefish School", x=0.698, y=0.716},
    {name="Greater Sagefish School", x=0.716, y=0.662},
    {name="Greater Sagefish School", x=0.727, y=0.582},
    {name="Greater Sagefish School", x=0.742, y=0.467},
}

-- ============================================================================
-- Moonglade (uiMapID 1450)
-- Pools: Greater Sagefish School
-- ============================================================================
FK.PoolData[1450] = {
    {name="Greater Sagefish School", x=0.400, y=0.493},
    {name="Greater Sagefish School", x=0.446, y=0.557},
    {name="Greater Sagefish School", x=0.518, y=0.621},
    {name="Greater Sagefish School", x=0.550, y=0.704},
    {name="Greater Sagefish School", x=0.595, y=0.619},
    {name="Greater Sagefish School", x=0.601, y=0.530},
    {name="Greater Sagefish School", x=0.611, y=0.444},
    {name="Greater Sagefish School", x=0.625, y=0.570},
}

-- ============================================================================
-- TBC ZONES
-- ============================================================================

-- ============================================================================
-- Zangarmarsh (uiMapID 1946)
-- Pools: Sporefish School, Brackish Mixed School (shared spawn points)
-- ============================================================================
FK.PoolData[1946] = {
    {name="Sporefish School", x=0.117, y=0.491},
    {name="Sporefish School", x=0.126, y=0.545},
    {name="Sporefish School", x=0.141, y=0.466},
    {name="Sporefish School", x=0.161, y=0.537},
    {name="Sporefish School", x=0.163, y=0.489},
    {name="Sporefish School", x=0.170, y=0.403},
    {name="Sporefish School", x=0.181, y=0.450},
    {name="Sporefish School", x=0.195, y=0.361},
    {name="Sporefish School", x=0.211, y=0.500},
    {name="Sporefish School", x=0.218, y=0.337},
    {name="Sporefish School", x=0.237, y=0.502},
    {name="Sporefish School", x=0.238, y=0.374},
    {name="Sporefish School", x=0.243, y=0.429},
    {name="Sporefish School", x=0.252, y=0.335},
    {name="Sporefish School", x=0.420, y=0.423},
    {name="Sporefish School", x=0.439, y=0.372},
    {name="Sporefish School", x=0.440, y=0.450},
    {name="Sporefish School", x=0.471, y=0.357},
    {name="Sporefish School", x=0.472, y=0.471},
    {name="Sporefish School", x=0.493, y=0.335},
    {name="Sporefish School", x=0.509, y=0.466},
    {name="Sporefish School", x=0.522, y=0.349},
    {name="Sporefish School", x=0.542, y=0.473},
    {name="Sporefish School", x=0.542, y=0.625},
    {name="Sporefish School", x=0.556, y=0.351},
    {name="Sporefish School", x=0.559, y=0.580},
    {name="Sporefish School", x=0.560, y=0.427},
    {name="Sporefish School", x=0.572, y=0.671},
    {name="Sporefish School", x=0.580, y=0.415},
    {name="Sporefish School", x=0.584, y=0.454},
    {name="Sporefish School", x=0.590, y=0.370},
    {name="Sporefish School", x=0.591, y=0.566},
    {name="Sporefish School", x=0.598, y=0.666},
    {name="Sporefish School", x=0.606, y=0.411},
    {name="Sporefish School", x=0.615, y=0.636},
    {name="Sporefish School", x=0.623, y=0.586},
    {name="Sporefish School", x=0.716, y=0.796},
    {name="Sporefish School", x=0.722, y=0.691},
    {name="Sporefish School", x=0.725, y=0.751},
    {name="Sporefish School", x=0.731, y=0.648},
    {name="Sporefish School", x=0.743, y=0.817},
    {name="Sporefish School", x=0.765, y=0.800},
    {name="Sporefish School", x=0.770, y=0.642},
    {name="Sporefish School", x=0.774, y=0.693},
    {name="Sporefish School", x=0.778, y=0.755},
}

-- ============================================================================
-- Terokkar Forest (uiMapID 1952)
-- Pools: Brackish Mixed School, School of Darter (shared spawn points),
--        Highland Mixed School (separate spawn points)
-- ============================================================================
FK.PoolData[1952] = {
    -- Brackish Mixed School / School of Darter (shared spawn points)
    {name="School of Darter", x=0.506, y=0.415},
    {name="School of Darter", x=0.520, y=0.349},
    {name="School of Darter", x=0.529, y=0.378},
    {name="School of Darter", x=0.532, y=0.409},
    {name="School of Darter", x=0.549, y=0.452},
    {name="School of Darter", x=0.553, y=0.493},
    {name="School of Darter", x=0.564, y=0.516},
    {name="School of Darter", x=0.568, y=0.304},
    {name="School of Darter", x=0.593, y=0.328},
    {name="School of Darter", x=0.598, y=0.368},
    {name="School of Darter", x=0.603, y=0.528},
    {name="School of Darter", x=0.613, y=0.287},
    {name="School of Darter", x=0.616, y=0.491},
    {name="School of Darter", x=0.625, y=0.417},
    {name="School of Darter", x=0.632, y=0.458},
    {name="School of Darter", x=0.678, y=0.446},
    {name="School of Darter", x=0.682, y=0.561},
    {name="School of Darter", x=0.698, y=0.545},
    {name="School of Darter", x=0.704, y=0.425},
    {name="School of Darter", x=0.709, y=0.502},
    {name="School of Darter", x=0.722, y=0.473},
    {name="School of Darter", x=0.730, y=0.398},
    -- Highland Mixed School (separate spawn points)
    {name="Highland Mixed School", x=0.449, y=0.403},
    {name="Highland Mixed School", x=0.589, y=0.627},
    {name="Highland Mixed School", x=0.599, y=0.603},
    {name="Highland Mixed School", x=0.633, y=0.747},
    {name="Highland Mixed School", x=0.637, y=0.790},
    {name="Highland Mixed School", x=0.658, y=0.827},
    {name="Highland Mixed School", x=0.664, y=0.739},
    {name="Highland Mixed School", x=0.686, y=0.763},
    {name="Highland Mixed School", x=0.686, y=0.819},
}

-- ============================================================================
-- Nagrand (uiMapID 1951)
-- Pools: Mudfish School, Bluefish School, Pure Water (all share spawn points,
--        Pure Water has additional northern spawns)
-- ============================================================================
FK.PoolData[1951] = {
    -- Mudfish School / Bluefish School / Pure Water (shared spawn points)
    {name="Mudfish School", x=0.252, y=0.454},
    {name="Mudfish School", x=0.306, y=0.502},
    {name="Mudfish School", x=0.306, y=0.541},
    {name="Mudfish School", x=0.323, y=0.467},
    {name="Mudfish School", x=0.336, y=0.537},
    {name="Mudfish School", x=0.351, y=0.444},
    {name="Mudfish School", x=0.361, y=0.512},
    {name="Mudfish School", x=0.369, y=0.473},
    {name="Mudfish School", x=0.397, y=0.491},
    {name="Mudfish School", x=0.474, y=0.442},
    {name="Mudfish School", x=0.502, y=0.475},
    {name="Mudfish School", x=0.514, y=0.429},
    {name="Mudfish School", x=0.537, y=0.386},
    {name="Bluefish School", x=0.538, y=0.260},
    {name="Mudfish School", x=0.541, y=0.434},
    {name="Bluefish School", x=0.549, y=0.295},
    {name="Bluefish School", x=0.564, y=0.240},
    {name="Mudfish School", x=0.585, y=0.365},
    {name="Bluefish School", x=0.591, y=0.244},
    {name="Pure Water", x=0.606, y=0.186},
    {name="Pure Water", x=0.607, y=0.137},
    {name="Mudfish School", x=0.615, y=0.275},
    {name="Mudfish School", x=0.616, y=0.341},
    {name="Mudfish School", x=0.623, y=0.314},
    {name="Pure Water", x=0.632, y=0.209},
    {name="Pure Water", x=0.637, y=0.165},
}

FK:Debug("PoolData module loaded")
