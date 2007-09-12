--[[ $Id$ ]]
local ACEDB_MAJOR, ACEDB_MINOR = "AceDB-3.0", 1
local AceDB, oldminor = LibStub:NewLibrary(ACEDB_MAJOR, ACEDB_MINOR)

if AceDB and oldminor then
	-- Handle upgrading here
end


local DBObjectLib = {}

--[[-------------------------------------------------------------------------
	AceDB Utility Functions
---------------------------------------------------------------------------]]

-- Simple shallow copy for copying defaults
local function copyTable(src)
	local dest = {}
	for k,v in pairs(src) do
		if type(k) == "table" then
			k = copyTable(k)
		end
		if type(v) == "table" then
			v = copyTable(v)
		end
		dest[k] = v
	end
	return dest
end

-- Called to add defaults to a section of the database
--
-- There is some heavy metatable magic here to compensate for when you INDEX a part
-- of the database that has a ["*"] default that is a table.  If we didn't have
-- this magic, then when new keys are indexed, they would be added to the table
-- and stored, even if no defaults changed.  This allows them to exist, and only
-- become part of the saved table, when they are first altered.
local function copyDefaults(dest, src, force)
	for k,v in pairs(src) do
		if k == "*" or k == "**" then
			if type(v) == "table" then
				-- This is a metatable used for table defaults
				local mt = {
					-- A cache table for storing ["*"] subtables until altered
					__cache = {},
					-- This handles the lookup and creation of new ["*"] subtables
					__index = function(t,k)
							local mt = getmetatable(dest)
							local cache = rawget(mt, "__cache")
							local tbl = rawget(cache, k)
							if not tbl then
								local parent = t
								local parentkey = k
								-- v here is the value part of ["*"]
								tbl = copyTable(v)
								rawset(cache, k, tbl)
								-- This metatable will handle altering of
								-- an existing table that's been created
								-- by the __index metamethod.
								local alter_mt = getmetatable(tbl)
								if not alter_mt then
									alter_mt = {}
									setmetatable(tbl, alter_mt)
								end
								-- When a new key is added to a table
								-- that was created with ["*"] magic, it 
								-- will become a real value in the table
								-- rather than just part of the metatable
								local newindex = function(t,k,v)
									rawset(parent, parentkey, t)
									rawset(t, k, v)
								end
								rawset(alter_mt, "__newindex", newindex)
							end
							return tbl
						end,
				}
				setmetatable(dest, mt)
			else
				-- Values are not tables, so this is just a simple return
				local mt = {__index = function() return v end}
				setmetatable(dest, mt)
			end
		elseif type(v) == "table" then
			if not dest[k] then dest[k] = {} end
			copyDefaults(dest[k], v, force)
			if src['**'] then
				copyDefaults(dest[k], src['**'])
			end
		else
			if (dest[k] == nil) or force then
				dest[k] = v
			end
		end
	end
end

-- Called to remove all defaults in the default table from the database
local function removeDefaults(db, defaults)
	for k,v in pairs(defaults) do
		if k == "*" and type(v) == "table" then
			-- check for any defaults that have been changed
			local mt = getmetatable(db)
			local cache = rawget(mt, "__cache")

			for cacheKey,cacheValue in pairs(cache) do
				removeDefaults(cacheValue, v)
				if next(cacheValue) ~= nil then
					-- Something's changed
					rawset(db, cacheKey, cacheValue)
				end
			end
			-- Now loop through all the actual k,v pairs and remove
			for key,value in pairs(db) do
				removeDefaults(value, v)
			end
		elseif type(v) == "table" and db[k] then
			removeDefaults(db[k], v)
			if not next(db[k]) then
				db[k] = nil
			end
		else
			if db[k] == defaults[k] then
				db[k] = nil
			end
		end
	end
end

-- This is called when a table section is first accessed, to set up the
-- defaults
local function initSection(db, section, svstore, key, defaults)
	local sv = rawget(db, "sv")

	local tableCreated
	if not sv[svstore] then sv[svstore] = {} end
	if not sv[svstore][key] then
		sv[svstore][key] = {}
		tableCreated = true
	end

	local tbl = sv[svstore][key]

	if defaults then
		copyDefaults(tbl, defaults)
	end
	rawset(db, section, tbl)

	return tableCreated, tbl
end

-- Metatable to handle the dynamic creation of sections and copying of sections.
local dbmt = {
	__index = function(t, section)
			local keys = rawget(t, "keys")
			local key = keys[section]
			if key then
				local defaultTbl = rawget(t, "defaults")
				local defaults = defaultTbl and defaultTbl[section]
				
				if section == "profile" then
					local new = initSection(t, section, "profiles", key, defaults)
					if new then
						-- Callback: OnNewProfile, database, newProfileKey
						t:TriggerCallback("OnNewProfile", t, key)
					end
				elseif section == "profiles" then
					local sv = rawget(t, "sv")
					if not sv.profiles then sv.profiles = {} end
					rawset(t, "profiles", sv.profiles)
				elseif section == "global" then
					local sv = rawget(t, "sv")
					if not sv.global then sv.global = {} end
					if defaults then
						copyDefaults(sv.global, defaults)
					end
					rawset(t, section, sv.global)
				else
					initSection(t, section, section, key, defaults)
				end
			end
			
			return rawget(t, section)
		end
}

-- Actual database initialization function
local function initdb(sv, defaults, defaultProfile, olddb)
	-- Generate the database keys for each section
	local charKey = string.format("%s - %s", UnitName("player"), GetRealmName())
	local realmKey = GetRealmName()
	local classKey = select(2, UnitClass("player"))
	local raceKey = select(2, UnitRace("player"))
	local factionKey = UnitFactionGroup("player")
	local factionrealmKey = string.format("%s - %s", factionKey, realmKey)
	
	-- Make a container for profile keys
	if not sv.profileKeys then sv.profileKeys = {} end
	
	-- Try to get the profile selected from the char db
	local profileKey = sv.profileKeys[charKey] or defaultProfile or charKey
	sv.profileKeys[charKey] = profileKey
	
	-- This table contains keys that enable the dynamic creation 
	-- of each section of the table.  The 'global' and 'profiles'
	-- have a key of true, since they are handled in a special case
	local keyTbl= {
		["char"] = charKey,
		["realm"] = realmKey,
		["class"] = classKey,
		["race"] = raceKey,
		["faction"] = factionKey,
		["factionrealm"] = factionrealmKey,
		["profile"] = profileKey,
		["global"] = true,
		["profiles"] = true,
	}
	
	-- This allows us to use this function to reset an entire database
	-- Clear out the old database
	if olddb then
		for k,v in pairs(olddb) do olddb[k] = nil end
	end
	
	-- Give this database the metatable so it initializes dynamically
	local db = setmetatable(olddb or {}, dbmt)
	
	-- Copy methods locally into the database object, to avoid hitting
	-- the metatable when calling methods
	
	for name,func in pairs(DBObjectLib) do
		db[name] = func
	end
	
	-- Set some properties in the database object
	db.profiles = sv.profiles
	db.keys = keyTbl
	db.sv = sv
	db.sv_name = name
	db.defaults = defaults
	
	return db
end

--TODO: Code a function to remove all defaults on PLAYER_LOGOUT

--[[-------------------------------------------------------------------------
	AceDB Object Method Definitions
---------------------------------------------------------------------------]]

-- DBObject:RegisterDefaults(defaults)
-- defaults (table) - A table of defaults for this database
--
-- Sets the defaults table for the given database object by clearing any
-- that are currently set, and then setting the new defaults.
function DBObjectLib:RegisterDefaults(defaults)
	if defaults and type(defaults) ~= "table" then
		error("Usage: AceDBObject:RegisterDefaults(defaults): 'defaults' - table or nil expected.", 3)
	end
	
	-- Remove any currently set defaults
	for section,key in pairs(self.keys) do
		if self.defaults[section] and rawget(self, section) then
			removeDefaults(self[section], self.defaults[section])
		end
	end
	
	-- Set the DBObject.defaults table
	self.defaults = defaults
	
	-- Copy in any defaults, only touching those sections already created
	if defaults then
		if defaults[section] and rawget(self, section) then
			copyDefaults(self[section], defaults[section])
		end
	end	
end

-- DBObject:SetProfile(name)
-- name (string) - The name of the profile to set as the current profile
--
-- Changes the profile of the database and all of it's namespaces to the
-- supplied named profile
function DBObjectLib:SetProfile(name)
	if type(name) ~= "string" then
		error("Usage: AceDBObject:SetProfile(name): 'name' - string expected.", 3)
	end
	
	local oldProfile = self.profile
	local defaults = self.defaults and self.defaults.profile
	
	if oldProfile and defaults then
		-- Remove the defaults from the old profile
		removeDefaults(oldProfile, defaults)
	end
	
	self.profile = nil
	self.keys["profile"] = name

	-- Callback: OnProfileChanged, database, newProfileKey
	self:TriggerCallback("OnProfileChanged", self, name)
end

-- DBObject:GetProfiles(tbl)
-- tbl (table) - A table to store the profile names in (optional)
--
-- Returns a table with the names of the existing profiles in the database.
-- You can optionally supply a table to re-use for this purpose.
function DBObjectLib:GetProfiles(tbl)
	if tbl and type(tbl) ~= "table" then
		error("Usage: AceDBObject:GetProfiles(tbl): 'tbl' - table or nil expected.", 3)
	end
	
	if tbl then
		for k,v in pairs(tbl) do tbl[k] = nil end
	else
		tbl = {}
	end
	
	local i = 0
	for profileKey in pairs(db.sv.profiles) do
		i = i + 1
		tbl[i] = profileKey
	end
	
	return tbl, i
end

-- DBObject:GetCurrentProfile()
--
-- Returns the current profile name used by the database
function DBObjectLib:GetCurrentProfile()
	return self.keys.profile
end

-- DBObject:DeleteProfile(name)
-- name (string) - The name of the profile to be deleted
--
-- Deletes a named profile.  This profile must not be the active profile.
function DBObjectLib:DeleteProfile(name)
	if type(name) ~= "string" then
		error("Usage: AceDBObject:DeleteProfile(name): 'name' - string expected.", 3)
	end
	
	if self.keys.profile == name then
		error("Cannot delete the active profile in an AceDBObject.", 3)
	end
	
	self.sv.profiles[name] = nil
	-- Callback: OnProfileDeleted, database, profileKey
	self:TriggerCallback("OnProfileDeleted", self, name)
end

-- DBObject:CopyProfile(name, force)
-- name (string) - The name of the profile to be copied into the current profile
--
-- Copies a named profile into the current profile, overwriting any conflicting
-- settings.
function DBObjectLib:CopyProfile(name)
	if type(name) ~= "string" then
		error("Usage: AceDBObject:CopyProfile(name): 'name' - string expected.", 3)
	end
	
	if name == self.keys.profile then
		error("Cannot have the same source and destination profiles.", 3)
	end

	-- Reset the profile before copying
	self:ResetProfile()
	
	local profile = self.profile
	local source = self.sv.profiles[name]
	
	copyDefaults(profile, source)
	
	-- Callback: OnProfileCopied, database, sourceProfileKey
	self:TriggerCallback("OnProfileCopied", self, name)
end

-- DBObject:ResetProfile()
-- 
-- Resets the current profile
function DBObjectLib:ResetProfile()
	local profile = self.profile
	
	for k,v in pairs(profile) do
		profile[k] = nil
	end
	
	local defaults = self.defaults and self.defaults.profile
	if defaults then
		copyDefaults(profile, defaults)
	end

	-- Callback: OnProfileReset, database
	self:TriggerCallback("OnProfileReset", self)
end

-- DBObject:ResetDB(defaultProfile)
-- defaultProfile (string) - The profile name to use as the default
--
-- Resets the entire database, using the string defaultProfile as the default
-- profile.
function DBObjectLib:ResetDB(defaultProfile)
	if defaultProfile and type(defaultProfile) ~= "string" then
		error("Usage: AceDBObject:ResetDB(defaultProfile): 'defaultProfile' - string or nil expected.", 3)
	end
	
	local sv = self.sv
	for k,v in pairs(sv) do
		sv[k] = nil
	end
	
	local parent = self.parent
	
	initdb(self.sv_name, self.defaults, defaultProfile, db)
	
	-- Callback: OnDatabaseReset, database
	self:TriggerCallback("OnDatabaseReset", self)
	-- Callback: OnProfileChanged, database, profileKey
	self:TriggerCallback("OnProfileChanged", self, self.keys["profile"])
	
	return db
end

-- DBObject:RegisterNamespace(name [, defaults])
-- name (string) - The name of the new namespace
-- defaults (table) - A table of values to use as defaults
--
-- Creates a new database namespace, directly tied to the database.  This
-- is a full scale database in it's own rights other than the fact that
-- it cannot control its profile individually
function DBObjectLib:RegisterNamespace(name, defaults)
	if type(name) ~= "string" then
		error("Usage: AceDBObject:RegisterNamespace(name, defaults): 'name' - string expected.", 3)
	end
	if defaults and type(defaults) ~= "table" then
		error("Usage: AceDBObject:RegisterNamespace(name, defaults): 'defaults' - table or nil expected.", 3)
	end
	
	local sv = self.sv
	if not sv.namespaces then sv.namespaces = {} end
	if not sv.namespaces[name] then
		sv.namespaces[name] = {}
	end
	
	local newDB = initdb(sv.namespaces[name], defaults, self.keys.profile)
	-- TODO: Make this a cleaner method
	-- Remove the :SetProfile method from newDB
	newDB.SetProfile = nil
	
	if not self.children then self.children = {} end
	table.insert(self.children, newDB)
	return newDB
end

--[[-------------------------------------------------------------------------
	Simple callback system implementation
---------------------------------------------------------------------------]]

-- DBObject:RegisterCallback(handler)
-- handler (function) - The handler function to call when a message fires.
--
-- Registers a callback function for the given AceDB object. Callbacks are only
-- called on a per-database level, so developers must register with the specific
--  database they are concerned with.
function DBObjectLib:RegisterCallback(handler)
	if type(handler) ~= "function" then
		error("Usage: AceDBObject:RegisterCallback(message, handler): 'handler' - function expected.", 3)
	end

	if not self.callbacks then self.callbacks = {} end
	self.callbacks[handler] = true
end

-- DBObject:UnregisterCallback(handler)
-- handler (function) - The handler function to unregister.
--
-- Unregisters a callback handler.
function DBObjectLib:UnregisterCallback(handler)
	if type(handler) ~= "function" then
		error("Usage: AceDBObject:RegisterCallback(message, handler): 'handler' - function expected.", 3)
	end

	if not self.callbacks then self.callbacks = {} end
	self.callbacks[handler] = nil
end

-- DBObject:TriggerCallback(message, ...)
-- message (string) - The message to send to registered callbacks
-- ... - Any extra arguments to be sent
--
-- For internal use only.  Used to trigger callback messages on database/profile
-- state changes.
function DBObjectLib:TriggerCallback(message, ...)
	if self.callbacks then
		for handler in pairs(self.callbacks) do
			-- Safecall this?
			local succ,err = pcall(handler, message, ...)
			if not succ then
				geterrorhandler()(err)
			end
		end
	end
end

--[[-------------------------------------------------------------------------
	AceDB Exposed Methods
---------------------------------------------------------------------------]]

-- AceDB:New(name, defaults, defaultProfile)
-- name (table or string) - The name of variable, or table to use for the database
-- defaults (table) - A table of database defaults
-- defaultProfile (string) - The name of the default profile
--
-- Creates a new database object that can be used to handle database settings
-- and profiles.
function AceDB:New(tbl, defaults, defaultProfile)
	if type(tbl) == "string" then
		local name = tbl
		tbl = getglobal(name)
		if not tbl then
			tbl = {}
			setglobal(name, tbl)
		end
	end
	
	if type(tbl) ~= "table" then
		error("Usage: AceDB:New(tbl, defaults, defaultProfile): 'tbl' - table expected.", 3)
	end
	
	if defaults and type(defaults) ~= "table" then
		error("Usage: AceDB:New(tbl, defaults, defaultProfile): 'defaults' - table expected.", 3)
	end
	
	if defaultProfile and type(defaultProfile) ~= "string" then
		error("Usage: AceDB:New(tbl, defaults, defaultProfile): 'defaultProfile' - string expected.", 3)
	end
	
	return initdb(tbl, defaults, defaultProfile)
end
