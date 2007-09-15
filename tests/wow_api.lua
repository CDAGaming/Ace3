local _G = getfenv(0)

local donothing = function() end

local frames = {} -- Stores globally created frames, and their internal properties.

local FrameClass = {} -- A class for creating frames.
FrameClass.methods = { "SetScript", "RegisterEvent", "UnregisterEvent", "UnregisterAllEvents", "OnShow", "OnHide" }
function FrameClass:New()
	local frame = {}
	for i,method in ipairs(self.methods) do
		frame[method] = self[method]
	end
	local frameProps = {
		events = {},
		scripts = {},
		timer = GetTime(),
		isShow = true
	}
	return frame, frameProps
end
function FrameClass:SetScript(script,handler)
	frames[self].scripts[script] = handler
end
function FrameClass:RegisterEvent(event)
	frames[self].events[event] = true
end
function FrameClass:UnregisterEvent(event)
	frames[self].events[event] = nil
end
function FrameClass:UnregisterAllEvents(frame)
	for event in pairs(frames[self].events) do
		frames[self].events[event] = nil
	end
end
function FrameClass:Show()
	frames[self].isShow = true
end
function FrameClass:Hide()
	frames[self].isShow = false
end
function FrameClass:IsShown()
	return frames[self].isShow
end



function CreateFrame(kind, name, parent)
	local frame,internal = FrameClass:New()
	frames[frame] = internal
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


GetTime = os.clock

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

local ChatFrameTemplate = {
	AddMessage = function(self, text)
		print((string.gsub(text, "|c%x%x%x%x%x%x%x%x(.-)|r", "%1")))
	end
}

for i=1,7 do
	local f = {}
	for k,v in pairs(ChatFrameTemplate) do
		f[k] = v
	end
	_G["ChatFrame"..i] = f
end
DEFAULT_CHAT_FRAME = ChatFrame1

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

local function _errorhandler(msg)
	print("--------- geterrorhandler error -------\n"..msg.."\n-----end error-----\n")
end

function geterrorhandler() 
	return _errorhandler
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
	for frame, props in pairs(frames) do
		if props.events[event] then
			if props.scripts["OnEvent"] then
				props.scripts["OnEvent"](frame,event,...)
			end
		end
	end
end

function WoWAPI_FireUpdate()
	local now = GetTime()
	for frame,props in pairs(frames) do
		if props.isShow and props.scripts.OnUpdate then
			props.scripts.OnUpdate(frame,now-props.timer)
			props.timer = now
		end
	end
end


