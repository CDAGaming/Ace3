dofile("wow_api.lua")
dofile("LibStub.lua")
dofile("../AceTimer-3.0/AceTimer-3.0.lua")

-- Maximum FPS in the simulation.
local MAX_FPS = 2

local AceTimer = LibStub("AceTimer-3.0")

local addon = {}
AceTimer:Embed(addon)
assert( type(addon.ScheduleTimer) == "function" )
assert( type(addon.ScheduleRepeatingTimer) == "function" )
assert( type(addon.CancelTimer) == "function" )
assert( type(addon.CancelAllTimers) == "function" )

local function callback(arg)
	print("Callback!")
end

local handle = addon:ScheduleTimer(callback,0.3,"test")


local delay = 1 / MAX_FPS
local coreTimer = os.clock()

-- This is the loop simulating OnUpdate per FPS.
while true do
	if os.clock() - coreTimer > delay then
		WoWAPI_FireUpdate()
		print("tick")
		coreTimer = os.clock()
	end
end
