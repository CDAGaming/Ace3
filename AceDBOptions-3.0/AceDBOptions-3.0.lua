--[[ $Id: AceDB-3.0.lua 62181 2008-02-20 07:17:43Z nevcairiel $ ]]
local ACEDBO_MAJOR, ACEDBO_MINOR = "AceDBOptions-3.0", 0
local AceDBOptions, oldminor = LibStub:NewLibrary(ACEDBO_MAJOR, ACEDBO_MINOR)

if not AceDBOptions then return end -- No upgrade needed

AceDBOptions.optionTables = AceDBOptions.optionTables or {}
AceDBOptions.handlers = AceDBOptions.handlers or {}

local L = setmetatable({}, {__index = function(t, k) return k end})

local defaultProfiles
local tmpprofiles = {}

--[[
	getProfileList(db, common, nocurrent)
	
	db - the db object to retrieve the profiles from
	common (boolean) - if common is true, getProfileList will add the default profiles to the return list, even if they have not been created yet
	nocurrent (boolean) - if true then getProfileList will not display the current profile in the list
]]--
local function getProfileList(db, common, nocurrent)
	local profiles = {}
	
	-- copy existing profiles into the table
	local currentProfile = db:GetCurrentProfile()
	for i,v in pairs(db:GetProfiles(tmpprofiles)) do 
		if not (nocurrent and v == currentProfile) then 
			profiles[v] = v 
		end 
	end
	
	-- add our default profiles to choose from ( or rename existing profiles)
	for k,v in pairs(defaultProfiles) do
		if (common or profiles[k]) and not (nocurrent and k == currentProfile) then
			profiles[k] = v
		end
	end
	
	return profiles
end

local function generateDefaultProfiles(db)
	defaultProfiles = {
		["Default"] = L["Default"],
		[db.keys.char] = db.keys.char,
		[db.keys.realm] = db.keys.realm,
		[db.keys.class] = UnitClass("player")
	}
end

local OptionsHandlerPrototype = {}
function OptionsHandlerPrototype:Reset()
	self.db:ResetProfile()
end

function OptionsHandlerPrototype:SetProfile(info, value)
	self.db:SetProfile(value)
end

function OptionsHandlerPrototype:GetCurrentProfile()
	return self.db:GetCurrentProfile()
end

function OptionsHandlerPrototype:ListProfiles(info)
	local arg = info.arg
	local profiles
	if arg == "common" then
		profiles = getProfileList(self.db, true, nil)
	elseif arg == "nocurrent" then
		profiles = getProfileList(self.db, nil, true)
	elseif arg == "both" then -- currently not used
		profiles = getProfileList(self.db, true, true)
	end
	
	return profiles
end

function OptionsHandlerPrototype:CopyProfile(info, value)
	self.db:CopyProfile(value)
end

function OptionsHandlerPrototype:DeleteProfile(info, value)
	self.db:DeleteProfile(value)
end

local function getOptionsHandler(db)
	local handler = AceDBOptions.handlers[db] or { db = db }
	
	for k,v in pairs(OptionsHandlerPrototype) do
		handler[k] = v
	end
	
	AceDBOptions.handlers[db] = handler
	return handler
end

local returnFalse = function() return false end

local optionsTable = {
	desc = {
		order = 1,
		type = "description",
		name = L["You can change the active database profile, so you can have different settings for every character, which will allow a very flexible configuration."] .. "\n",
	},
	descreset = {
		order = 9,
		type = "description",
		name = L["Reset the current profile back to its default values, in case your configuration is broken, or you simply want to start over."],
	},
	reset = {
		order = 10,
		type = "execute",
		name = L["Reset Profile"],
		desc = L["Reset the current profile to the default"],
		func = "Reset",
	},
	choosedesc = {
		order = 20,
		type = "description",
		name = "\n" .. L["You can create a new profile by entering a new name in the editbox, or choosing one of the already exisiting profiles."],
	},
	new = {
		name = L["New"],
		desc = L["Create a new empty profile."],
		type = "input",
		order = 30,
		get = returnFalse,
		set = "SetProfile",
	},
	choose = {
		name = L["Current"],
		desc = L["Select one of your currently available profiles."],
		type = "select",
		order = 40,
		get = "GetCurrentProfile",
		set = "SetProfile",
		values = "ListProfiles",
		arg = "common",
	},
	copydesc = {
		order = 50,
		type = "description",
		name = "\n" .. L["Copy the settings from one existing profile into the currently active profile."],
	},
	copyfrom = {
		order = 60,
		type = "select",
		name = L["Copy From"],
		desc = L["Copy the settings from another profile into the active profile."],
		get = returnFalse,
		set = "CopyProfile",
		values = "ListProfiles",
		arg = "nocurrent",
	},
	deldesc = {
		order = 70,
		type = "description",
		name = "\n" .. L["Delete existing and unused profiles from the database to save space, and cleanup the SavedVariables file."],
	},
	delete = {
		order = 80,
		type = "select",
		name = L["Delete a Profile"],
		desc = L["Deletes a profile from the database."],
		get = returnFalse,
		set = "DeleteProfile",
		values = "ListProfiles",
		arg = "nocurrent",
		confirm = true,
		confirmText = L["Are you sure you want to delete the selected profile?"],
	},
}

function AceDBOptions:GetOptionsTable(db)
	if not defaultProfiles then
		generateDefaultProfiles(db)
	end
	
	local tbl = AceDBOptions.optionTables[db] or {
			type = "group",
			name = L["Profiles"],
			desc = L["Manage Profiles"],
		}
	
	tbl.handler = getOptionsHandler(db)
	tbl.args = optionsTable

	AceDBOptions.optionTables[db] = tbl
	return tbl
end

-- upgrade existing tables
for db,tbl in pairs(AceDBOptions.optionTables) do
	tbl.handler = getOptionsHandler(db)
	tbl.args = optionsTable
end
