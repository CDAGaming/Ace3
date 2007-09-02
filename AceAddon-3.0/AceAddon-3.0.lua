local MAJOR = "AceAddon-3.0"
local MINOR = 0

local AceAddon = LibStub:NewLibrary( MAJOR, MINOR )

if not AceAddon then return end

-- upgrading
AceAddon.frame = AceAddon.frame or CreateFrame("Frame", "AceAddon30Frame") -- our event frame
AceAddon.addons = AceAddon.addons or {} -- addons in general
AceAddon.initializequeue = AceAddon.initializequeue or {} -- addons that are new and not initialized
AceAddon.enablequeue = AceAddon.enablequeue or {} -- addons that are initialized and waiting to be enabled
AceAddon.embeds = AceAddon.embeds or {} -- contains a list of libraries embedded in an addon

local function safecall( func, ... )
	local success, err = pcall(func,...)
	if not success then geterrorhandler()(err:find("%.lua:%d+:") and err or (debugstack():match("\n(.-: )in.-\n") or "") .. err) end
end

-- AceAddon:NewAddon( name, [lib, lib, lib, ...] )
-- name (string) - unique addon object name
-- [lib] (string) - optional libs to embed in the addon object
--
-- returns the addon object when succesful
function AceAddon:NewAddon( name, ... )
	assert( type( name ) == "string", "Bad argument #2 to 'NewAddon' (string expected)" )
	
	if self.addons[name] then
		error( ("AceAddon '%s' already exists."):format(name), 2 )
	end

	local addon = {}
	addon.name = name

	self:EmbedLibraries( addon, ... )

	self.addons[name] = addon
	-- add to queue of addons to be initialized upon ADDON_LOADED
	table.insert( self.initializequeue, addon )
	return addon
end

-- AceAddon:GetAddon( name, [silent])
-- name (string) - unique addon object name
-- silent (boolean) - if true, addon is optional, silently return nil if its not found
--
-- throws an error if the addon object can not be found (except silent is set)
-- returns the addon object if found
function AceAddon:GetAddon( name, silent )
	if not silent and not self.addons[name] then
		error(("Cannot find an AceAddon with name '%s'."):format(name), 2)
	end
	return self.addons[name]
end

-- AceAddon:EmbedLibraries( addon, [lib, lib, lib, ...] )
-- addon (object) - addon to embed the libs in
-- [lib] (string) - optional libs to embed
function AceAddon:EmbedLibraries( addon, ... )
	for i=1,select("#", ... ) do
		-- TODO: load on demand?
		local libname = select( i, ... )
		local lib = LibStub:GetLibrary( libname )
		if type( lib.Embed ) ~= "function" then
			error( ("Library '%s' is not Embed capable"):format(libname), 2 )
		else
			lib:Embed( addon )
			if not self.embeds[addon] then self.embeds[addon] = {} end
			table.insert( self.embeds[addon], libname ) -- register addon using lib
		end
	end	
end

-- AceAddon:IntializeAddon( addon )
-- addon (object) - addon to intialize
--
-- calls OnInitialize on the addon object if available
-- calls OnEmbedInitialize on embedded libs in the addon object if available
function AceAddon:InitializeAddon( addon )
	if type( addon.OnInitialize ) == "function" then
		safecall( addon.OnInitialize, addon )
	end

	if self.embeds[addon] then
		for k, libname in ipairs( self.embeds[addon] ) do
			local lib = LibStub:GetLibrary(libname, true)
			if lib and type( lib.OnEmbedInitialize ) == "function" then
				safecall( lib.OnEmbedInitialize, lib, addon )
			end
		end
	end	
end

-- AceAddon:EnableAddon( addon )
-- addon (object) - addon to enable 
--
-- calls OnEnable on the addon object if available
-- calls OnEmbedEnable on embedded libs in the addon object if available
function AceAddon:EnableAddon( addon )
	-- TODO: enable only if needed
	if type( addon.OnEnable ) == "function" then
		-- TODO: handle 'first'? Or let addons do it on their own?
		safecall( addon.OnEnable, addon )
	end
	if self.embeds[addon] then
		for k, libname in ipairs( self.embeds[addon] ) do
			local lib = LibStub:GetLibrary(libname, true)
			if lib and type( lib.OnEmbedEnable ) == "function" then
				safecall( lib.OnEmbedEnable, lib, addon )
			end
		end
	end	
end

-- AceAddon:DisableAddon( addon )
-- addon (object) - addon to disable
--
-- calls OnDisable on the addon object if available
-- calls OnEmbedDisable on embedded libs in the addon object if available
function AceAddon:DisableAddon( addon )
	-- TODO: disable only if enabled
	if type( addon.OnDisable ) == "function" then
		safecall( addon.OnDisable, addon )
	end
	if self.embeds[addon] then
		for k, libname in ipairs( self.embeds[addon] ) do
			local lib = LibStub:GetLibrary(libname, true)
			if lib and type( lib.OnEmbedDisable ) == "function" then
				safecall( lib.OnEmbedDisable, lib, addon )
			end
		end
	end	
end

-- Event Handling
local function onEvent( this, event, arg1 )
	if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" then
		for i = 1, #AceAddon.initializequeue do
			local addon = AceAddon.initializequeue[i]
			AceAddon:InitializeAddon( addon )
			AceAddon.initializequeue[i] = nil
			table.insert( AceAddon.enablequeue, addon )
		end

		if IsLoggedIn() then
			for i = 1, #AceAddon.enablequeue do
				local addon = AceAddon.enablequeue[i]
				AceAddon:EnableAddon( addon )
				AceAddon.enablequeue[i] = nil
			end
		end
	end
	
	-- TODO: do we want to disable addons on logout?
		-- Mikk: unnecessary code running imo, since disable isn't == logout (we can enable and disable in-game)
		-- Ammo: AceDB wants to massage the db on logout
		-- Mikk: AceDB can listen for PLAYER_LOGOUT on its own, and if it massages the db on disable, it'll ahve to un-massage it on reenables
		-- DISCUSSION WANTED!
end
AceAddon.frame:RegisterEvent("ADDON_LOADED")
AceAddon.frame:RegisterEvent("PLAYER_LOGIN")
AceAddon.frame:SetScript( "OnEvent", onEvent )
