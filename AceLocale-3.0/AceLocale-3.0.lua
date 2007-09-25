--[[ $Id$ ]]
local MAJOR,MINOR = "AceLocale-3.0", 0

local AceLocale = LibStub:NewLibrary(MAJOR, MINOR)

if not AceLocale then 
	return -- no upgrade needed
end

AceLocale.apps = AceLocale.apps or {}	         -- array of ["AppName"]=localetableref
AceLocale.appnames = AceLocale.appnames or {}  -- array of [localetableref]="AppName"

-- This __newindex is used for most locale tables
local function __newindex(self,key,value)
	-- assigning values: replace 'true' with key string
	if value==true then
		rawset(self, key, key)
	else
		rawset(self, key, value)
	end
end

-- __newindex_default is used for when the default locale is being registered.
-- Reason 1: Allows loading locales in any order
-- Reason 2: If 2 modules have the same string, but only the first one to be 
--           loaded has a translation for the current locale, the translation
--           doesn't get overwritten.
--
local function __newindex_default(self,key,value)
	if rawget(self,key) then
		return	-- don't allow default locale to overwrite current locale stuff
	end
	__newindex(self,key,value)
end


-- The metatable used by all locales (yes, same one!)
local meta = {
	__newindex = __newindex,
	
	__index = function(self, key)	-- requesting totally unknown entries: fire off a nonbreaking error and return key
		geterrorhandler()(MAJOR..": "..tostring(self[0].application)..": Missing entry for '"..tostring(key).."'")
		return key
	end
}


-- AceLocale:NewLocale(application, locale, isDefault)
--
--  application (string)  - unique name of addon / module
--  locale (string)       - name of locale to register
--  isDefault (string)    - if this is the default locale being registered
--
-- Returns a table where localizations can be filled out, or nil if the locale is not needed

function lib:NewLocale(application, locale, isDefault)

	local app = AceLocale.apps[application]
	
	if not app then
		app = setmetatable({}, meta)
		AceLocale.apps[application] = app
		AceLocale.appnames[app] = application
	end
	
	if isDefault then
		getmetatable(app).__newindex = __newindex_default
		return app
	end
	
	local GAME_LOCALE = GAME_LOCALE or GetLocale()
	if GAME_LOCALE=="enGB" then
		GAME_LOCALE="enUS"
	end
	
	if locale~=GAME_LOCALE then
		return -- nop, we don't need these translations	
	end
	
	getmetatable(app).__newindex = __newindex
	return app	-- okay, we're trying to register translations for the current game locale, go ahead
end


-- AceLocale:GetLocale(application)
--
--  application (string) - unique name of addon 
--
-- returns appropriate localizations for the current locale, errors if localizations are missing

function AceLocale:GetLocale(application)
	local app = AceLocale.apps[application]

	if not app then
		error("GetLocale(): No locales registered for '"..tostring(application).."'", 2)
	end
	
	return app
end
