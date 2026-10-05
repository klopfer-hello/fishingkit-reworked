local H = { passed = 0 }
local source = os.getenv("FISHINGKIT_SOURCE") or "."

function H.eq(actual, expected, label)
	assert(
		actual == expected,
		(label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)
	)
end

function H.test(name, fn)
	if arg[2] and arg[2] ~= name then
		return
	end
	local ok, err = xpcall(fn, debug.traceback)
	if not ok then
		error(name .. "\n" .. err, 0)
	end
	H.passed = H.passed + 1
	print("PASS " .. name)
end

local function frame()
	local f = { scripts = {}, events = {}, shown = true }
	function f:SetScript(name, fn)
		self.scripts[name] = fn
	end
	function f:RegisterEvent(name)
		self.events[name] = true
	end
	function f:UnregisterAllEvents()
		self.events = {}
	end
	function f:Show()
		self.shown = true
	end
	function f:Hide()
		self.shown = false
	end
	function f:IsShown()
		return self.shown
	end
	function f:SetText(value)
		self.text = value
	end
	function f:CreateTexture()
		return frame()
	end
	function f:CreateFontString()
		return frame()
	end
	function f:CreateAnimationGroup()
		return frame()
	end
	function f:CreateAnimation()
		return frame()
	end
	for _, name in ipairs({
		"SetSize",
		"SetPoint",
		"SetFrameStrata",
		"SetClampedToScreen",
		"SetMovable",
		"EnableMouse",
		"RegisterForDrag",
		"SetTexture",
		"SetWidth",
		"SetTextColor",
		"RegisterForClicks",
		"SetAllPoints",
		"SetAlpha",
		"SetColorTexture",
		"SetFromAlpha",
		"SetToAlpha",
		"SetDuration",
		"SetOrder",
		"ClearAllPoints",
	}) do
		f[name] = function() end
	end
	return f
end

function H.new()
	local w = {
		now = 100,
		timers = {},
		frames = {},
		loot = {},
		queries = {},
		listings = {},
		mapID = 1,
		x = 0.1,
		y = 0.1,
		canQuery = true,
		fishingLoot = true,
		cvars = {},
		cvarWrites = 0,
		bindings = {},
	}
	local env = setmetatable({}, { __index = _G })
	env._G = env
	w.env = env
	env.print = function() end
	env.GetTime = function()
		return w.now
	end
	env.time = function()
		return 100000 + math.floor(w.now)
	end
	env.date = os.date
	env.wipe = function(t)
		for k in pairs(t) do
			t[k] = nil
		end
		return t
	end
	env.SlashCmdList = {}
	env.DEFAULT_CHAT_FRAME = { AddMessage = function() end }
	env.GetSpellInfo = function(id)
		if id == 7620 then
			return "Fishing"
		end
	end
	env.GetRealZoneText = function()
		return "Test Lake"
	end
	env.GetSubZoneText = function()
		return "Shore"
	end
	env.GetNumSkillLines = function()
		return 0
	end
	env.GetWeaponEnchantInfo = function()
		return false
	end
	env.UnitChannelInfo = function()
		return w.channel
	end
	env.UnitPosition = function()
		return 0, 0
	end
	env.GetPlayerFacing = function()
		return nil
	end
	env.CreateFromMixins = function()
		return {}
	end
	env.UIParent = frame()
	env.InCombatLockdown = function() return w.combat or false end
	env.GameTooltip = { HookScript = function() end }
	env.SetOverrideBindingClick = function(owner, _, key, button)
		assert(not w.combat, "insecure binding write in combat")
		w.bindings[owner] = { key = key, button = button }
	end
	env.ClearOverrideBindings = function(owner)
		assert(not w.combat, "insecure binding cleanup in combat")
		w.bindings[owner] = nil
	end
	env.CreateFrame = function(_, name, parent, template)
		local f = frame()
		f.attrs = {}
		function f:SetAttribute(key, value)
			assert(not w.combat or not (template and template:find("Secure")), "insecure attribute write in combat")
			self.attrs[key] = value
		end
		w.frames[#w.frames + 1] = f
		if name then
			env[name] = f
		end
		return f
	end
	env.C_Map = {
		GetBestMapForUnit = function()
			return w.mapID
		end,
		GetPlayerMapPosition = function()
			return {
				GetXY = function()
					return w.x, w.y
				end,
			}
		end,
	}
	local function schedule(delay, callback, interval)
		local timer = { due = w.now + delay, callback = callback, interval = interval }
		function timer:Cancel()
			self.cancelled = true
		end
		w.timers[#w.timers + 1] = timer
		return timer
	end
	env.C_Timer = {
		After = function(delay, fn)
			schedule(delay, fn)
		end,
		NewTicker = function(delay, fn)
			return schedule(delay, fn, delay)
		end,
	}
	function w:advance(seconds)
		local target = self.now + seconds
		while true do
			local nextTimer
			for _, timer in ipairs(self.timers) do
				if not timer.cancelled and timer.due <= target and (not nextTimer or timer.due < nextTimer.due) then
					nextTimer = timer
				end
			end
			if not nextTimer then
				break
			end
			self.now = nextTimer.due
			if nextTimer.interval then
				nextTimer.due = self.now + nextTimer.interval
			else
				nextTimer.cancelled = true
			end
			nextTimer.callback()
		end
		self.now = target
	end
	env.GetNumLootItems = function()
		return #w.loot
	end
	env.IsFishingLoot = function()
		return w.fishingLoot
	end
	env.GetLootSlotInfo = function(i)
		local item = w.loot[i]
		return "texture", item.name, item.count or 1, item.quality or 1, false
	end
	env.GetLootSlotLink = function(i)
		return "item:" .. w.loot[i].id .. ":0"
	end
	env.GetItemInfo = function()
		return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 7
	end
	env.GetCVar = function(key)
		return w.cvars[key]
	end
	env.SetCVar = function(key, value)
		w.cvars[key] = tostring(value)
		w.cvarWrites = w.cvarWrites + 1
	end
	env.AuctionFrame = frame()
	env.CanSendAuctionQuery = function()
		return w.canQuery
	end
	env.SortAuctionSetSort = function() end
	env.QueryAuctionItems = function(name)
		w.queries[#w.queries + 1] = { name = name, time = w.now }
	end
	env.GetNumAuctionItems = function()
		return #w.listings, #w.listings
	end
	env.GetAuctionItemInfo = function(_, i)
		local item = w.listings[i]
		return item.name, nil, item.count or 1, nil, nil, nil, nil, nil, nil, item.buyout or 0
	end
	w.FK = {}
	function w:load(path)
		local file = assert(io.open(source .. "/" .. path, "rb"))
		local text = file:read("*a"):gsub("^\239\187\191", "")
		file:close()
		local chunk
		if setfenv then
			chunk = assert(loadstring(text, "@" .. path))
			setfenv(chunk, env)
		else
			chunk = assert(load(text, "@" .. path, "t", env))
		end
		chunk("FishingKit", self.FK)
	end
	function w:event(name, ...)
		-- Snapshot registrations so changes made by one handler do not add new
		-- listeners halfway through the same event dispatch.
		local callbacks = {}
		for _, f in ipairs(self.frames) do
			if f.events[name] and f.scripts.OnEvent then
				callbacks[#callbacks + 1] = { f, f.scripts.OnEvent }
			end
		end
		for _, cb in ipairs(callbacks) do
			cb[2](cb[1], name, ...)
		end
	end
	function w:cast(channelOnly)
		self.castID = (self.castID or 0) + 1
		if not channelOnly then
			self:event("UNIT_SPELLCAST_START", "player", "Cast-" .. self.castID, 7620)
		end
		self.channel = "Fishing"
		self:event("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-" .. self.castID, 7620)
	end
	function w:stop()
		self.channel = nil
		self:event("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-" .. self.castID, 7620)
	end
	function w:catch(close)
		self.loot = { { id = 6291, name = "Raw Brilliant Smallfish", count = 2 } }
		self:event("LOOT_READY")
		self:event("LOOT_READY")
		self.loot = {} -- auto-loot has removed items by LOOT_OPENED
		self:event("LOOT_OPENED")
		if close then
			self:event("LOOT_CLOSED")
		end
	end
	w:load("Core.lua")
	w:event("ADDON_LOADED", "FishingKit")
	w.FK.db.lastBackupTime = env.time()
	w.FK.db.settings.autoOpenContainers = false
	w.FK.db.settings.milestones = false
	w.FK.db.settings.soundEnabled = false
	w.FK.db.settings.poolNavSound = false
	return w, w.FK
end

function H.stats()
	local w, FK = H.new()
	w:load("modules/Database.lua")
	w:load("modules/Statistics.lua")
	FK.Statistics:Initialize()
	return w, FK, FK.Statistics
end

return H
