dofile("wow_api.lua")
dofile("LibStub.lua")
dofile("../AceDB-3.0/AceDB-3.0.lua")
dofile("serialize.lua")

-- Test the defaults system
do

	local defaults = {
		profile = {
			singleEntry = "singleEntry",
			tableEntry = {
				tableDefault = "tableDefault",
			},
			starTest = {
				["*"] = {
					starDefault = "starDefault",
				},
				sibling = {
					siblingDefault = "siblingDefault",
				},
			},
			doubleStarTest = {
				["**"] = {
					doubleStarDefault = "doubleStarDefault",
				},
				sibling = {
					siblingDefault = "siblingDefault",
				},
			},
		},
	}

	local db = LibStub("AceDB-3.0"):New("MyDB", defaults)
	assert(db.profile.singleEntry == "singleEntry")
	assert(db.profile.tableEntry.tableDefault == "tableDefault")
	assert(db.profile.starTest.randomkey.starDefault == "starDefault")
	assert(db.profile.starTest.sibling.siblingDefault == "siblingDefault")
	assert(db.profile.starTest.sibling.starDefault == nil)
	assert(db.profile.doubleStarTest.randomkey.doubleStarDefault == "doubleStarDefault")
	assert(db.profile.doubleStarTest.sibling.siblingDefault == "siblingDefault")
	assert(db.profile.doubleStarTest.sibling.doubleStarDefault == "doubleStarDefault")
end


-- Test the dynamic creation of sections
do
	local defaults = {
		char = { alpha = "alpha",},
		realm = { beta = "beta",},
		class = { gamma = "gamma",},
		race = { delta = "delta",},
		faction = { epsilon = "epsilon",},
		factionrealm = { zeta = "zeta",},
		profile = { eta = "eta",},
		global = { theta = "theta",},
	}

	local db = LibStub("AceDB-3.0"):New({}, defaults)
	
	assert(rawget(db, "char") == nil)
	assert(rawget(db, "realm") == nil)
	assert(rawget(db, "class") == nil)
	assert(rawget(db, "race") == nil)
	assert(rawget(db, "faction") == nil)
	assert(rawget(db, "factionrealm") == nil)
	assert(rawget(db, "profile") == nil)
	assert(rawget(db, "global") == nil)
	assert(rawget(db, "profiles") == nil)

	-- Check dynamic default creation
	assert(db.char.alpha == "alpha")
	assert(db.realm.beta == "beta")
	assert(db.class.gamma == "gamma")
	assert(db.race.delta == "delta")
	assert(db.faction.epsilon == "epsilon")
	assert(db.factionrealm.zeta == "zeta")
	assert(db.profile.eta == "eta")
	assert(db.global.theta == "theta")
end

-- Verify that ["*"] and ["**"] tables aren't created until they are changed
do
	local defaults = {
		profile = {
			["*"] = {
				alpha = "alpha",
			}
		},
		char = {
			["**"] = {
				beta = "beta",
			},
			sibling = {
				gamma = "gamma",
			},
		},
	}

	local db = LibStub("AceDB-3.0"):New({}, defaults)

	-- Access each just to ensure they're created
	assert(db.profile.randomkey.alpha == "alpha")
	assert(db.char.randomkey.beta == "beta")

	assert(rawget(db.profile, "randomkey") == nil)
	assert(rawget(db.char, "randomkey") == nil)
	assert(type(rawget(db.char, "sibling")) == "table")
end

-- Test OnProfileChanged
do
	local testdb = LibStub("AceDB-3.0"):New({})
	
	local triggers = {}

	local function OnProfileChanged(message, db, ...)
		if message == "OnProfileChanged" and db == testdb then
			local profile = ...
			assert(profile == "Healers")
			triggers[message] = true
		end
	end

	testdb:RegisterCallback(OnProfileChanged)
	testdb:SetProfile("Healers")
	assert(triggers.OnProfileChanged)
end

-- Test GetProfiles() fix for ACE-35
do
	local db = LibStub("AceDB-3.0"):New({})
	
	local profiles = {
		"Healers",
		"Tanks",
		"Hunter",
	}

	for idx,profile in ipairs(profiles) do
		db:SetProfile(profile)
	end

	local profileList = db:GetProfiles()
	table.sort(profileList)
	assert(profileList[1] == "Healers")
	assert(profileList[2] == "Hunter")
	assert(profileList[3] == "Tanks")
	assert(profileList[4] == UnitName("player" .. " - " .. GetRealmName()))
end
