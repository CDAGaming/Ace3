
-- This file is only there in standalone Ace3 and provides handy dev tool stuff I guess
-- for now only /rl to reload your UI :)
-- note the complete overkill use of AceAddon and console, ain't it cool?

local gui = LibStub("AceGUI-3.0")
local reg = LibStub("AceConfigRegistry-3.0")
local dialog = LibStub("AceConfigDialog-3.0")

Ace3 = LibStub("AceAddon-3.0"):NewAddon("Ace3", "AceConsole-3.0")
local Ace3 = Ace3

local selectedgroup
local frame
local select
local status = {}
local configs = {}

local function frameOnClose()
	gui:Release(frame)
	frame = nil
end

local function RefreshConfigs()
	for name in reg:IterateOptionsTables() do
		configs[name] = name
	end
end

local function ConfigSelected(widget, event, value)
	selectedgroup = value
	dialog:Open(value, widget)	
end

function Ace3:Open()
	RefreshConfigs()
	if next(configs) == nil then
		self:Print("No Configs are Registered")
		return
	end
	
	frame = frame or gui:Create("Frame")
	frame:ReleaseChildren()
	frame:SetTitle("Ace3 Options")
	frame:SetLayout("FILL")
	frame:SetCallback("OnClose", frameOnClose)
	
	select = select or gui:Create("DropdownGroup")
	select:SetGroupList(configs)
	select:SetCallback("OnGroupSelected", ConfigSelected)
	if not selectedgroup then
		selectedgroup = next(configs)
	end
	select:SetGroup(selectedgroup)
	frame:AddChild(select)
	
	frame:Show()
end

function Ace3:OnInitialize()
	self:RegisterChatCommand("ace3", function() self:Open() end )
	self:RegisterChatCommand("rl", function() ReloadUI() end )
end