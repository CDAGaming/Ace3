local MAJOR, MINOR = "AceAddon-3.0", 0
local AceAddon, oldminor = LibStub:NewLibrary( MAJOR, MINOR )

if not AceAddon then 
    return -- No Upgrade needed.
elseif not oldminor then -- This is the first version
    AceAddon.frame = CreateFrame("Frame", "AceAddon30Frame") -- Our very own frame
    AceAddon.addons = {} -- addons in general
    AceAddon.initializequeue = {} -- addons that are new and not initialized
    AceAddon.enablequeue = {} -- addons that are initialized and waiting to be enabled
    AceAddon.embeds = setmetatable({}, {__index = function(tbl, key) tbl[key] = {} return tbl[key] end }) -- contains a list of libraries embedded in an addon
end

local function safecall(func,...)
    if type(func) == "function" then 
        local success, err = pcall(func,...)
        if not err:find("%.lua:%d+:") then err = (debugstack():match("\n(.-: )in.-\n") or "") .. err end 
        geterrorhandler()(err)
    end
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
    
    local addon = { name = name}
	self.addons[name] = addon
	self:EmbedLibraries( addon, ... )

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
		self:EmbedLibrary(addon, libname, false, 3)
	end	
end

-- AceAddon:EmbedLibrary( addon, libname, silent, offset )
-- addon (object) - addon to embed the libs in
-- libname (string) - lib to embed
-- [silent] (boolean) - optional, marks an embed to fail silently if the library doesn't exist.
-- [offset] (number) - will push the error messages back to said offset defaults to 2
function AceAddon:EmbedLibrary( addon, libname, silent, offset )
    local lib = LibStub:GetLibrary(libname, true)
    if not silent and not lib then
        error(("Cannot find a library instance of %q."):format(tostring(libname)), offset or 2)
    elseif lib and type(lib.Embed) ~= "function" then
        lib:Embed(addon)
        table.insert( self.embeds[addon], libname )  
        return true
    elseif lib then
        error( ("Library '%s' is not Embed capable"):format(libname), offset or 2 )
    end
end

-- AceAddon:IntializeAddon( addon )
-- addon (object) - addon to intialize
--
-- calls OnInitialize on the addon object if available
-- calls OnEmbedInitialize on embedded libs in the addon object if available
function AceAddon:InitializeAddon( addon )
	safecall( addon.OnInitialize, addon )

    for k, libname in ipairs( self.embeds[addon] ) do
        local lib = LibStub:GetLibrary(libname, true)
        if lib then safecall( lib.OnEmbedInitialize, lib, addon ) end
    end
end

-- AceAddon:EnableAddon( addon )
-- addon (object) - addon to enable 
--
-- calls OnEnable on the addon object if available
-- calls OnEmbedEnable on embedded libs in the addon object if available
function AceAddon:EnableAddon( addon )
	-- TODO: enable only if needed
	-- TODO: handle 'first'? Or let addons do it on their own?
	safecall( addon.OnEnable, addon )
	for k, libname in ipairs( self.embeds[addon] ) do
        local lib = LibStub:GetLibrary(libname, true)
        if lib then safecall( lib.OnEmbedEnable, lib, addon ) end
    end
end

-- AceAddon:DisableAddon( addon )
-- addon (object) - addon to disable
--
-- calls OnDisable on the addon object if available
-- calls OnEmbedDisable on embedded libs in the addon object if available
function AceAddon:DisableAddon( addon )
	-- TODO: disable only if enabled
	safecall( addon.OnDisable, addon )
	if self.embeds[addon] then
		for k, libname in ipairs( self.embeds[addon] ) do
			local lib = LibStub:GetLibrary(libname, true)
			if lib then	safecall( lib.OnEmbedDisable, lib, addon ) end
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
        -- K: I say let it do it on PLAYER_LOGOUT, Or if it must it already will know OnEmbedDisable
		-- DISCUSSION WANTED!
end

--The next few funcs are just because no one should be reaching into the internal registries
--Thoughts?
function AceAddon:IterateAddons() return pairs(self.addons) end
function AceAddon:IterateEmbedsOnAddon(addon) return pairs(self.embeds[addon]) end

AceAddon.frame:RegisterEvent("ADDON_LOADED")
AceAddon.frame:RegisterEvent("PLAYER_LOGIN")
AceAddon.frame:SetScript( "OnEvent", onEvent )
