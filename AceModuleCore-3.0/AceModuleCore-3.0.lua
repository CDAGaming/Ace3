local MAJOR, MINOR = "AceModuleCore-3.0", 0
local AceModuleCore, oldversion = LibStub:NewLibrary( MAJOR, MINOR )
local AceAddon = LibStub:GetLibrary("AceAddon-3.0")

if not AceAddon then
    error(MAJOR.." requires AceAddon-3.0")
end

if not AceModuleCore then 
    return 
elseif not oldversion then
    AceModuleCore.embeded = {} -- contains a list of namespaces this has been embeded into
end

local function safecall(func,...)
	if type(func) == "function" then 
		local success, err = pcall(func,...)
		if not err:find("%.lua:%d+:") then err = (debugstack():match("\n(.-: )in.-\n") or "") .. err end 
		geterrorhandler()(err)
	end
end

-- AceModuleCore:GetModule( name, [silent])
-- name (string) - unique module object name
-- silent (boolean) - if true, module is optional, silently return nil if its not found
--
-- throws an error if the addon object can not be found (except silent is set)
-- returns the module object if found
function GetModule(self, name, silent)
	if not silent and not self.modules[name] then
		error(("Cannot find a module named '%s'."):format(name), 2)
	end
	return self.modules[name]
end

-- AceModuleCore:NewModule( name, [prototype, [lib, lib, lib, ...] )
-- name (string) - unique module object name for this addon
-- prototype (object) - object to derive this module from, methods and values from this table will be mixed into the module, if a string is passed a lib is assumed
-- [lib] (string) - optional libs to embed in the addon object
--
-- returns the addon object when succesful
function NewModule(self, name, prototype, ... )
	assert( type( name ) == "string", "Bad argument #2 to 'NewModule' (string expected)" )
	assert( type( prototype ) == "string" or type( prototype ) == "string" or type( prototype ) == "nil" ), "Bad argument #3 to 'NewModule' (string, table or nil expected)" )
	
	if self.modules[name] then
		error( ("Module '%s' already exists."):format(name), 2 )
	end
    
    local module = AceAddon:NewAddon(string.format("%s_%s", self.name or tostring(self), name)
        
	if type( prototype ) == "table" then
		module = AceAddon:EmbedLibraries( module, ... )
        setmetatable(module, {__index=prototype})  -- More of a Base class type feel.
	elseif prototype then
		module = AceAddon:EmbedLibraries( module, prototype, ... )
	end
    
    safecall(module.OnModuleCreated, self) -- Was in Ace2 and I think it could be a cool thing to have handy.  
	self.modules[name] = module
    
	return module
end

local mixins = {NewModule = NewModule, GetModule = GetModule, modules = {}}

-- AceModuleCore:Embed( target )
-- target (object) - target object to embed the modulecore in
-- 
-- Embeds acemodule core into the target object
function AceModuleCore:Embed( target )
	for k, v in pairs( mixins ) do
		target[k] = v
	end
    table.insert(self.embeded, target)
end

function AceModuleCore:OnEmbedEnable( target )
	for name, module in pairs( target.modules ) do
		AceAddon:EnableAddon( module )
	end
end

function AceModuleCore:OnEmbedDisable( target )
	for name, module in pairs( target.modules ) do
		AceAddon:DisableAddon( module )
	end
end



