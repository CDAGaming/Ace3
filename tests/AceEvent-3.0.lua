dofile("wow_api.lua")
dofile("LibStub.lua")
dofile("../AceEvent-3.0/AceEvent-3.0.lua")

local AceEvent = LibStub("AceEvent-3.0")

local addon = {}

AceEvent:Embed(addon)

do -- Tests on events
	local eventResult
	function addon:EVENT_TEST(event,arg1)
		eventResult = arg1
	end

	eventResult = 1
	addon:RegisterEvent("EVENT_TEST")
	WoWAPI_FireEvent("EVENT_TEST", 2)
	assert(eventResult==2)

	eventResult = 3
	addon:UnregisterEvent("SOMETHINGELSE")
	WoWAPI_FireEvent("SOMETHINGELSE", 4)
	assert(eventResult==3)

	eventResult = 5
	addon:UnregisterEvent("SOMETHINGELSE")
	WoWAPI_FireEvent("EVENT_TEST", 6)
	assert(eventResult==6)

	eventResult = 7
	addon:UnregisterEvent("EVENT_TEST")
	WoWAPI_FireEvent("EVENT_TEST", 8)
	assert(eventResult==7)
end

do -- Tests on messages.
	local messageResult
	function addon:MESSAGE_TEST(message,...)
	end
end
