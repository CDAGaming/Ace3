--[[ $Id$ ]]
local MAJOR,MINOR = "AceLocale-3.0", 0

local AceLocale, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not AceLocale then return end -- no upgrade needed


AceLocale.apps = AceLocale.apps or {}          -- array of ["AppName"]=localetableref
AceLocale.appnames = AceLocale.appnames or {}  -- array of [localetableref]="AppName"

-- This metatable is used on all tables returned from GetLocale
local readmeta = {
	__index = function(self, key)	-- requesting totally unknown entries: fire off a nonbreaking error and return key
		geterrorhandler()(MAJOR..": "..tostring(AceLocale.appnames[self])..": Missing entry for '"..tostring(key).."'")
		return key
	end
}

-- Remember the locale table being registered right now
local registering

-- This metatable proxy is used when registering nondefault locales
local writeproxy = setmetatable({}, {
	__newindex = function(self, key, value)
		rawset(registering, key, value == true and key or value) -- assigning values: replace 'true' with key string
	end,
	__index = function() assert(false) end
})

-- This metatable proxy is used when registering the default locale. 
-- It refuses to overwrite existing values
-- Reason 1: Allows loading locales in any order
-- Reason 2: If 2 modules have the same string, but only the first one to be 
--           loaded has a translation for the current locale, the translation
--           doesn't get overwritten.
--
local writedefaultproxy = setmetatable({}, {
	__newindex = function(self, key, value)
		if not rawget(registering, key) then
			rawset(registering, key, value == true and key or value)
		end
	end,
	__index = function() assert(false) end
})

-- AceLocale:NewLocale(application, locale, isDefault)
--
--  application (string)  - unique name of addon / module
--  locale (string)       - name of locale to register
--  isDefault (string)    - if this is the default locale being registered
--
-- Returns a table where localizations can be filled out, or nil if the locale is not needed
function AceLocale:NewLocale(application, locale, isDefault)

	-- GAME_LOCALE allows translators to test translations of addons without having that wow client installed
	-- STOP MOVING THIS CHUNK OUT TO GLOBAL SCOPE GODDAMNIT!!!!!!  /Mikk
	local gameLocale = GAME_LOCALE or GetLocale()
	if gameLocale == "enGB" then
		gameLocale = "enUS"
	end

	if locale ~= gameLocale and not isDefault then
		return -- nop, we don't need these translations
	end
	
	local app = AceLocale.apps[application]
	
	if not app then
		app = setmetatable({}, readmeta)
		AceLocale.apps[application] = app
		AceLocale.appnames[app] = application
	end

	registering = app	-- remember globally for writeproxy and writedefaultproxy
	
	if isDefault then
		return writedefaultproxy
	end

	return writeproxy
end

-- AceLocale:GetLocale(application [, silent])
--
--  application (string) - unique name of addon
--  silent (boolean)     - if true, the locale is optional, silently return nil if it's not found 
--
-- Returns localizations for the current locale or default locale
-- Errors if nothing is registered (spank developer, not just a missing translation)
function AceLocale:GetLocale(application, silent)
	if not silent and not AceLocale.apps[application] then
		error("Usage: GetLocale(application[, silent]): 'application' - No locales registered for '"..tostring(application).."'", 2)
	end
	return AceLocale.apps[application]
end
