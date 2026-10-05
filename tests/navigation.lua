local H = ...
local function pool(name, x, seen)
	return { name = name, x = x, y = 0.1, timesSeen = seen or 1, lastSeen = seen == 0 and 0 or 100100 }
end
local function fixture(showCommunity)
	local w, FK = H.new()
	w:load("modules/Pools.lua")
	w:load("modules/Navigation.lua")
	FK.Pools.RefreshAllPins = function() end -- map rendering is outside these route tests
	FK.db.settings.showCommunityPools = showCommunity or false
	local hidden, visible = pool("Community", 0.1, 0), pool("Discovered", 0.2)
	FK.db.poolLocations[1] = { hidden, visible }
	FK.Navigation:StartRoute()
	return w, FK, FK.Navigation, visible, hidden
end

H.test("discovering a pool preserves filtered route targets", function()
	local w, FK, nav, visible = fixture()
	H.eq(nav:GetCurrentTarget(), visible)
	w.x = 0.4
	FK.Pools:RecordPoolLocation("New pool")
	H.eq(nav:GetCurrentTarget(), visible, "current target after discovery")
	nav:AdvanceWaypoint()
	H.eq(nav:GetCurrentTarget().name, "New pool")
	nav:AdvanceWaypoint()
	H.eq(nav:GetCurrentTarget(), visible, "route contains only two visible pools")
end)

H.test("discovery uses the supplied pool and ignores duplicate callbacks", function()
	local _, FK, nav, visible = fixture()
	local new, later = pool("New pool", 0.3), pool("Later pool", 0.5)
	table.insert(FK.db.poolLocations[1], new)
	table.insert(FK.db.poolLocations[1], later)
	nav:OnPoolDiscovered(new)
	nav:OnPoolDiscovered(new)
	H.eq(nav:GetCurrentTarget(), visible)
	nav:AdvanceWaypoint()
	H.eq(nav:GetCurrentTarget(), new)
	nav:AdvanceWaypoint()
	H.eq(nav:GetCurrentTarget(), visible)
end)

H.test("foreign and hidden pools do not enter an active route", function()
	local _, _, nav, visible, hidden = fixture()
	nav:OnPoolDiscovered(pool("Elsewhere", 0.3))
	nav:OnPoolDiscovered(hidden)
	nav:AdvanceWaypoint()
	H.eq(nav:GetCurrentTarget(), visible)
end)

H.test("community routes preserve current target during insertion", function()
	local w, FK, nav, visible, hidden = fixture(true)
	H.eq(nav:GetCurrentTarget(), hidden)
	nav:AdvanceWaypoint()
	H.eq(nav:GetCurrentTarget(), visible)
	w.x = 0.15
	FK.Pools:RecordPoolLocation("Between pools")
	H.eq(nav:GetCurrentTarget(), visible)
	nav:AdvanceWaypoint()
	H.eq(nav:GetCurrentTarget(), hidden)
	nav:AdvanceWaypoint()
	H.eq(nav:GetCurrentTarget().name, "Between pools")
	nav:AdvanceWaypoint()
	H.eq(nav:GetCurrentTarget(), visible)
end)

H.test("changing zones cannot insert pools into the previous route", function()
	local w, FK, nav, visible = fixture()
	w.mapID = 2
	w.x = 0.3
	FK.Pools:RecordPoolLocation("Other zone")
	nav:AdvanceWaypoint()
	H.eq(nav:GetCurrentTarget(), visible)
end)
