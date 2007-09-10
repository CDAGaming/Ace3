local _G = getfenv(0)

local donothing = function() end

local frames = {} -- Stores globally created frames.
local scriptHandlers = {} -- Stores frame handlers.
local registeredEvents = {} -- Stores frame event registration.

local frameClass = {} -- A class for creating frames.
function frameClass:SetScript(script,handler)
	if not scriptHandlers[self] then
		scriptHandlers[self] = {}
	end
	scriptHandlers[self][script] = handler
end
function frameClass:RegisterEvent(event)
	if not registeredEvents[self] then
		registeredEvents[self] = {}
	end
	registeredEvents[self][event] = true
end
function frameClass:UnregisterEvent(event)
	if registeredEvents[self][event] then
		registeredEvents[self][event] = nil
	end
end
function frameClass:UnregisterAllEvents(frame)
	if registeredEvents[self] then
		for k in pairs(registeredEvents[self]) do
			registeredEvents[self][k] = nil
		end
	end
end
frameClass.Show = donothing
frameClass.Hide = donothing


function CreateFrame(kind, name, parent)
	local frame = {}
	for k,v in pairs(frameClass) do
		frame[k] = v
	end
	table.insert(frames,frame)
	if name then
		_G[name] = frame
	end
	return frame
end

function UnitName(unit)
	return unit
end

function GetRealmName()
	return "Realm Name"
end

function UnitClass(unit)
	return "Warrior", "WARRIOR"
end

function UnitHealthMax()
	return 100
end

function UnitHealth()
	return 50
end

function GetNumRaidMembers()
	return 1
end

function GetNumPartyMembers()
	return 1
end

FACTION_HORDE = "Horde"
FACTION_ALLIANCE = "Alliance"

function UnitFactionGroup(unit)
	return "Horde", "Horde"
end

function UnitRace(unit)
	return "Undead", "Scourge"
end

function GetTime()
	return os.clock()
end

function IsAddOnLoaded() return nil end

SlashCmdList = {}

function __WOW_Input(text)
	local a,b = string.find(text, "^/%w+")
	local arg, text = string.sub(text, a,b), string.sub(text, b + 2)
	for k,handler in pairs(SlashCmdList) do
		local i = 0
		while true do
			i = i + 1
			if not _G["SLASH_" .. k .. i] then
				break
			elseif _G["SLASH_" .. k .. i] == arg then
				handler(text)
				return
			end
		end
	end;
	print("No command found:", text)
end

DEFAULT_CHAT_FRAME = {
	AddMessage = function(self, text)
		print((string.gsub(text, "|c%x%x%x%x%x%x%x%x(.-)|r", "%1")))
	end
}

for i=1,7 do
	_G["ChatFrame"..i] = DEFAULT_CHAT_FRAME
end

debugstack = debug.traceback
date = os.date

function GetLocale()
	return "enUS"
end

function GetAddOnInfo()
	return
end

function GetNumAddOns()
	return 0
end

function getglobal(k)
	return _G[k]
end

function setglobal(k, v)
	_G[k] = v
end

function geterrorhandler() 
	return error
end

function InCombatLockdown()
	return false
end

function IsLoggedIn()
	return false
end

time = os.clock

RED_FONT_COLOR_CODE = ""
GREEN_FONT_COLOR_CODE = ""

StaticPopupDialogs = {}


function WoWAPI_FireEvent(event,...)
	for i, frame in ipairs(frames) do
		if registeredEvents[frame] and registeredEvents[frame][event] then
			if scriptHandlers[frame] and scriptHandlers[frame]["OnEvent"] then
				scriptHandlers[frame]["OnEvent"](frame,event,...)
			end
		end
	end
end





