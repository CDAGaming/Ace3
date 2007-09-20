
local MAJOR,MINOR = "AceLocale-3.0", "$Revision: 1"

local lib = LibStub:RegisterLibrary(MAJOR, MINOR)

if not lib then return end


lib.apps = lib.apps or {}

local meta = {
	__newindex = function(self, key, value)	-- assigning values: replace 'true' with key string
		if value==true then
			self[key]=key
		else
			self[key]=value
		end
	end,
	
	__index = function(self, key)	-- requesting unknown values: fire off a nonbreaking error and return key
		geterrorhandler()("AceLocale-3.0: Missing translation for '"..tostring(key).."'")
		return key
	end
}

-- AceLocale:RegisterLocale(application, locale)
--
--  application (string) - unique name of addon
--  locale (string) - name of locale to register
--
-- Returns a table where localizations can be filled out, or nil if the locale is not needed
-- The first call to :RegisterLocale always returns a table - the "default locale"

function lib:RegisterLocale(application, locale)
	if locale=="enEN" then 
		locale="enUS" -- treat enEN like enUS
	end

	local app = lib.apps[application]
	
	if not app then		-- Always accept the first locale to be registered; it's the default one
		app = setmetatable({}, meta)
		lib.apps[application] = app
		
		return app
	end
	
	local GAME_LOCALE = GAME_LOCALE or GetLocale()
	if GAME_LOCALE=="enEN" then
		GAME_LOCALE="enUS"
	end
	
	if locale==GAME_LOCALE then
		return app	-- okay, we're trying to register translations for the current game locale, go ahead
	end
	
	return -- nop, we don't need these translations	
end


-- AceLocale:RegisterLocale(application, locale)
--
--  application (string) - unique name of addon
--
-- returns appropriate localizations for the current locale, errors if localizations are missing

function lib:GetCurrentLocale(application)
	local app = lib.apps[application]

	if not app then
		error("GetCurrentLocale(): No locale registered for '"..tostring(application).."'", 2)
	end
	
	return app
end

