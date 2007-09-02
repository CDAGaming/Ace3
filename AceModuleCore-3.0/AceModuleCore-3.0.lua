local MAJOR = "AceModuleCore-3.0"
local MINOR = 0

local AceModuleCore = LibStub:NewLibrary( MAJOR, MINOR )

if not AceModuleCore then return end

-- upgrading
AceModuleCore.embeds = AceModuleCore.embeds or {} -- contains a list of libraries embedded in a module

local function safecall( func, ... )
	local success, err = pcall(func,...)
	if not success then geterrorhandler()(err:find("%.lua:%d+:") and err or (debugstack():match("\n(.-: )in.-\n") or "") .. err) end
end

local mixins = {
	"NewModule",
	"GetModule",
}

-- AceModuleCore:Embed( target )
-- target (object) - target object to embed the modulecore in
-- 
-- Embeds acemodule core into the target object
function AceModuleCore:Embed( target )
	for k, v in ipairs( mixins ) do
		target[v] = AceModuleCore[v]
	end
end

function AceModuleCore:OnEmbedInitialize( target )
	for name, module in pairs( target.modules ) do
		AceModuleCore:InitializeModule( v )
	end
end

function AceModuleCore:OnEmbedEnable( target )
	for name, module in pairs( target.modules ) do
		AceModuleCore:EnableModule( v )
	end
end

function AceModuleCore:OnEmbedDisable( target )
	for name, module in pairs( target.modules ) do
		AceModuleCore:DisableModule( v )
	end
end


-- AceModuleCore:NewModule( name, [prototype, [lib, lib, lib, ...] )
-- name (string) - unique module object name for this addon
-- prototype (object) - object to derive this module from, methods and values from this table will be mixed into the module, if a string is passed a lib is assumed
-- [lib] (string) - optional libs to embed in the addon object
--
-- returns the addon object when succesful
function AceModuleCore:NewModule( name, prototype, ... )
	assert( self ~= AceModuleCore ) -- we don't allow modules from AceModuleCore, it has no self.modules
	assert( type( name ) == "string", "Bad argument #2 to 'NewModule' (string expected)" )
	assert( type( prototype ) == "string" or type( prototype ) == "string" or type( prototype ) == "nil" ), "Bad argument #3 to 'NewModule' (string, table or nil expected)" )
	
	if self.modules[name] then
		error( ("Module '%s' already exists."):format(name), 2 )
	end

	local module = {}
	module.name = name

	if type( prototype ) == "table" then
		-- mixin the prototype
		for k, v in pairs( prototype ) do
			module[k] = v
		end
		AceModuleCore:EmbedLibraries( module, ... )
	else
		AceModuleCore:EmbedLibraries( module, prototype, ... )
	end

	self.modules[name] = addon
	return addon
end

-- AceModuleCore:GetModule( name, [silent])
-- name (string) - unique module object name
-- silent (boolean) - if true, module is optional, silently return nil if its not found
--
-- throws an error if the addon object can not be found (except silent is set)
-- returns the module object if found
function AceModuleCore:GetModule( name, silent )
	if not silent and not self.modules[name] then
		error(("Cannot find an module with name '%s'."):format(name), 2)
	end
	return self.modules[name]
end

-- AceModuleCore:EmbedLibraries( module, [lib, lib, lib, ...] )
-- module (object) - module to embed the libs in
-- [lib] (string) - optional libs to embed
function AceModuleCore:EmbedLibraries( module, ... )
	for i=1,select("#", ... ) do
		-- TODO: load on demand?
		local libname = select( i, ... )
		if libname then
			local lib = LibStub:GetLibrary( libname )
			if type( lib.Embed ) ~= "function" then
				error( ("Library '%s' is not Embed capable"):format(libname), 2 )
			else
				lib:Embed( module )
				if not self.embeds[module] then self.embeds[module] = {} end
				table.insert( self.embeds[module], libname ) -- register module using lib
			end
		end
	end	
end

-- AceModuleCore:IntializeModule( module )
-- module (object) - module to intialize
--
-- calls OnInitialize on the module object if available
-- calls OnEmbedInitialize on embedded libs in the module object if available
function AceModuleCore:InitializeAddon( module )
	if type( module.OnInitialize ) == "function" then
		safecall( module.OnInitialize, module )
	end

	if self.embeds[module] then
		for k, libname in ipairs( self.embeds[module] ) do
			local lib = LibStub:GetLibrary(libname, true)
			if lib and type( lib.OnEmbedInitialize ) == "function" then
				safecall( lib.OnEmbedInitialize, lib, module )
			end
		end
	end	
end

-- AceModuleCore:EnableModule( module )
-- module (object) - addon to enable 
--
-- calls OnEnable on the module object if available
-- calls OnEmbedEnable on embedded libs in the module object if available
function AceModuleCore:EnableModule( module )
	-- TODO: enable only if needed
	if type( module.OnEnable ) == "function" then
		-- TODO: handle 'first'? Or let addons do it on their own?
		safecall( module.OnEnable, module )
	end
	if self.embeds[module] then
		for k, libname in ipairs( self.embeds[addon] ) do
			local lib = LibStub:GetLibrary(libname, true)
			if lib and type( lib.OnEmbedEnable ) == "function" then
				safecall( lib.OnEmbedEnable, lib, addon )
			end
		end
	end	
end

-- AceModuleCore:DisableModule( module )
-- addon (object) - addon to disable
--
-- calls OnDisable on the module object if available
-- calls OnEmbedDisable on embedded libs in the module object if available
function AceModuleCore:DisableModule( module )
	-- TODO: disable only if enabled
	if type( module.OnDisable ) == "function" then
		safecall( module.OnDisable, module )
	end
	if self.embeds[module] then
		for k, libname in ipairs( self.embeds[module] ) do
			local lib = LibStub:GetLibrary(libname, true)
			if lib and type( lib.OnEmbedDisable ) == "function" then
				safecall( lib.OnEmbedDisable, lib, module )
			end
		end
	end	
end
