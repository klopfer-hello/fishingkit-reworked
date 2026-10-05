local H = ...

H.test("restoring twice retains the original nested settings", function()
	local _, FK = H.new()
	FK.db.settings.position.x = 12
	FK.db.globalStats.fishCaught[6291] = { count = 4 }
	FK:CreateBackup()
	FK:RestoreBackup()
	FK.db.settings.position.x = 80
	FK.db.globalStats.fishCaught[6291].count = 99
	FK:RestoreBackup()
	H.eq(FK.db.settings.position.x, 12, "saved position")
	H.eq(FK.db.globalStats.fishCaught[6291].count, 4, "saved global fish")
	assert(FK.db.settings.position ~= FK.db.backup.settings.position)
end)

H.test("character stats goals and gear stay independent of backup", function()
	local _, FK = H.new()
	FK.chardb.stats.fishCaught[6291] = { count = 3 }
	FK.chardb.goals[1] = { itemID = 6291, quantity = 10 }
	FK.chardb.fishingGear.mainHand = "item:6256"
	FK.chardb.releaseList[6291] = true
	FK:CreateBackup()
	FK:RestoreBackup()
	FK.chardb.stats.fishCaught[6291].count = 8
	FK.chardb.goals[1].quantity = 30
	FK.chardb.fishingGear.mainHand = "item:12225"
	FK.chardb.releaseList[6291] = nil
	FK:RestoreBackup()
	H.eq(FK.chardb.stats.fishCaught[6291].count, 3)
	H.eq(FK.chardb.goals[1].quantity, 10)
	H.eq(FK.chardb.fishingGear.mainHand, "item:6256")
	H.eq(FK.chardb.releaseList[6291], true)
end)

H.test("restoring preserves excluded live history and backup metadata", function()
	local w, FK = H.new()
	FK:CreateBackup()
	local backup, charBackup, timestamp = FK.db.backup, FK.chardb.backup, FK.db.lastBackupTime
	local pools, prices, history, sessions =
		FK.db.poolLocations, FK.db.ahPrices, FK.chardb.lootHistory, FK.chardb.sessions
	pools[1] = { { name = "New pool" } }
	prices[6291] = 70
	history[1] = { itemID = 6291 }
	sessions[1] = { casts = 4 }
	w:advance(1)
	FK:RestoreBackup()
	H.eq(FK.db.poolLocations, pools)
	H.eq(FK.db.ahPrices, prices)
	H.eq(FK.chardb.lootHistory, history)
	H.eq(FK.chardb.sessions, sessions)
	H.eq(FK.db.backup, backup)
	H.eq(FK.chardb.backup, charBackup)
	H.eq(FK.db.lastBackupTime, timestamp)
end)

H.test("missing character backup still restores global settings", function()
	local _, FK = H.new()
	FK:CreateBackup()
	FK.chardb.backup = nil
	FK.db.settings.scale = 2
	FK:RestoreBackup()
	H.eq(FK.db.settings.scale, 1)
end)
