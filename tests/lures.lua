local H = ...
local lure = { bag = 0, slot = 1, name = "Lure", bonus = 100 }
local function fixture()
	local w, FK = H.new()
	w:load("modules/UI.lua")
	FK.UI:ArmLureReapply(lure)
	local button = w.env.FishingKitLureSAButton
	assert(w.bindings[button])
	return w, FK.UI, button
end
for _, duration in ipairs({ 5, 61 }) do
	H.test("lure binding clears after combat lasting " .. duration .. " seconds", function()
		local w, _, button = fixture()
		w.combat = true
		w:event("PLAYER_REGEN_DISABLED")
		w:advance(duration)
		w.combat = false
		w:event("PLAYER_REGEN_ENABLED")
		H.eq(w.bindings[button], nil)
		H.eq(button.attrs.type, nil)
		H.eq(button.attrs.macrotext, nil)
	end)
end
H.test("lure click during combat defers protected cleanup", function()
	local w, _, button = fixture()
	w.combat = true
	w:event("PLAYER_REGEN_DISABLED")
	button.scripts.PostClick(button)
	w.combat = false
	w:event("PLAYER_REGEN_ENABLED")
	H.eq(w.bindings[button], nil)
end)
H.test("lure timeout and normal click clear the binding", function()
	local w, ui, button = fixture()
	w:advance(60)
	H.eq(w.bindings[button], nil)
	ui:ArmLureReapply(lure)
	button.scripts.PostClick(button)
	H.eq(w.bindings[button], nil)
end)
H.test("old lure timeout does not clear a newer arm", function()
	local w, ui, button = fixture()
	w:advance(30)
	ui:ArmLureReapply(lure)
	w:advance(30)
	assert(w.bindings[button])
	w:advance(30)
	H.eq(w.bindings[button], nil)
end)
