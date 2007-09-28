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
	
	db.profile.doubleStarTest.siblingDeriv.doubleStarDefault = "doubleStarDefault"
	
	db:RegisterDefaults({})
	
	assert(db.profile.singleEntry == nil)
	assert(db.profile.tableEntry == nil)
	assert(db.profile.starTest.randomkey.starDefault == nil)
	assert(db.profile.starTest.sibling == nil)
	assert(db.profile.doubleStarTest.randomkey.doubleStarDefault == nil)
	assert(db.profile.doubleStarTest.siblingDeriv.doubleStarDefault == "doubleStarDefault")
end
