dofile("wow_api.lua")
dofile("LibStub.lua")
dofile("../CallbackHandler-1.0/CallbackHandler-1.0.lua")
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
				siblingDeriv = {
					starDefault = "not-so-starDefault",
				},
			},
			doubleStarTest = {
				["**"] = {
					doubleStarDefault = "doubleStarDefault",
				},
				sibling = {
					siblingDefault = "siblingDefault",
				},
				siblingDeriv = {
					doubleStarDefault = "overruledDefault",
				}
			},
			starTest2 = {
				["*"] = "fun",
				sibling = "notfun",
			}
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
	assert(db.profile.doubleStarTest.siblingDeriv.doubleStarDefault == "overruledDefault")
	assert(db.profile.starTest2.randomkey == "fun")
	assert(db.profile.starTest2.sibling == "notfun")
	
	db.profile.doubleStarTest.siblingDeriv.doubleStarDefault = "doubleStarDefault"
	db.profile.starTest2.randomkey = "notfun"
	db.profile.starTest2.randomkey2 = "fun" 
	db.profile.starTest2.sibling = "fun"
	
	WoWAPI_FireEvent("PLAYER_LOGOUT")
	
	assert(db.profile.singleEntry == nil)
	assert(db.profile.tableEntry == nil)
	assert(db.profile.starTest.randomkey.starDefault == nil)
	assert(db.profile.starTest.sibling == nil)
	assert(db.profile.doubleStarTest.randomkey.doubleStarDefault == nil)
	assert(db.profile.doubleStarTest.siblingDeriv.doubleStarDefault == "doubleStarDefault")
	assert(db.profile.starTest2.randomkey == "notfun")
	assert(db.profile.starTest2.randomkey2 == nil)
	assert(db.profile.starTest2.sibling == "fun")
end

do
	local AceDB = LibStub("AceDB-3.0") 
	local defaultTest = { 
		profile = { 
			units = { 
				["**"] = { 
					test = 2 
				}, 
				["player"] = { 
				} 
			} 
		} 
	} 
	
	local bugdb = { 
		["profileKeys"] = { 
			["player - Realm Name"] = "player - Realm Name", 
		}, 
		["profiles"] = { 
			["player - Realm Name"] = { 
				["units"] = { 
					["player"] = { 
					}, 
					["pet"] = {
					}, 
					["focus"] = { 
					}, 
				}, 
			}, 
		}, 
	} 
	
	local data = LibStub("AceDB-3.0"):New(bugdb, defaultTest) 
	 
	assert(data.profile.units["player"].test == 2)
	assert(data.profile.units["pet"].test == 2)
	assert(data.profile.units["focus"].test == 2)
end

do
	local AceDB = LibStub("AceDB-3.0") 
	local defaultTest = { 
		profile = { 
			units = { 
				["*"] = { 
					test = 2 
				}, 
				["player"] = { 
				} 
			} 
		} 
	} 
	
	local bugdb = { 
		["profileKeys"] = { 
			["player - Realm Name"] = "player - Realm Name", 
		}, 
		["profiles"] = { 
			["player - Realm Name"] = { 
				["units"] = { 
					["player"] = { 
					}, 
					["pet"] = {
					}, 
				}, 
			}, 
		}, 
	} 
	
	local data = LibStub("AceDB-3.0"):New(bugdb, defaultTest) 
	 
	assert(data.profile.units["player"].test == nil)
	assert(data.profile.units["pet"].test == 2)
	assert(data.profile.units["focus"].test == 2)
end
