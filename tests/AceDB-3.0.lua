dofile("wow_api.lua")
dofile("LibStub.lua")
dofile("../AceDB-3.0/AceDB-3.0.lua")

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