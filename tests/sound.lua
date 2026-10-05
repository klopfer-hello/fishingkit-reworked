local H = ...
local original = {
	Sound_MasterVolume = "0.31",
	Sound_SFXVolume = "0.72",
	Sound_EnableAmbience = "1",
	Sound_MusicVolume = "0.45",
	Sound_EnableMusic = "1",
	Sound_EnableAllSound = "0",
	Sound_EnablePetSounds = "1",
	Sound_EnableSoundWhenGameIsInBG = "0",
	Sound_EnableSFX = "0",
}
local function fixture()
	local w, FK = H.new()
	for name, value in pairs(original) do
		w.cvars[name] = value
	end
	w:load("modules/Alerts.lua")
	FK.Alerts:Initialize()
	return w, FK
end
local function restored(w)
	for name, value in pairs(original) do
		H.eq(w.cvars[name], value, name)
	end
end

H.test("logout restores all sound settings during a cast", function()
	local w = fixture()
	w:cast()
	H.eq(w.cvars.Sound_EnableMusic, "0", "music muted during cast")
	w:event("PLAYER_LOGOUT")
	restored(w)
end)

H.test("recasts retain the original sound snapshot", function()
	local w = fixture()
	w:cast()
	w:stop()
	w:cast()
	w:event("PLAYER_LOGOUT")
	restored(w)
end)

H.test("logout after normal completion does not restore twice", function()
	local w = fixture()
	w:cast()
	w:stop()
	w:catch(true)
	restored(w)
	w.cvars.Sound_MusicVolume = "0.8"
	local writes = w.cvarWrites
	w:event("PLAYER_LOGOUT")
	H.eq(w.cvarWrites, writes)
	H.eq(w.cvars.Sound_MusicVolume, "0.8")
end)

H.test("disabling enhanced sound mid cast still restores on logout", function()
	local w, FK = fixture()
	w:cast()
	FK.db.settings.enhancedSound = false
	w:event("PLAYER_LOGOUT")
	restored(w)
end)

H.test("disabled sound enhancement makes no cvar writes", function()
	local w, FK = fixture()
	FK.db.settings.enhancedSound = false
	w:cast()
	w:event("PLAYER_LOGOUT")
	H.eq(w.cvarWrites, 0)
	restored(w)
end)
