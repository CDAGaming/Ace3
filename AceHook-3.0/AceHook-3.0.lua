--[[ $Id$ ]]
local ACEHOOK_MAJOR, ACEHOOK_MINOR = "AceHook-3.0", 0
local AceHook, oldminor = LibStub:NewLibrary(ACEHOOK_MAJOR, ACEHOOK_MINOR)

if not AceHook then 
	return -- no upgrade needed
end

AceHook.embeded = AceHook.embeded or {}
AceHook.registry = AceHook.registry or {}
AceHook.handlers = AceHook.handlers or {}
AceHook.actives = AceHook.actives or {}
AceHook.scripts = AceHook.scripts or {}
AceHook.onceSecure = AceHook.onceSecure or {}

-- local upvalues
local registry = AceHook.registry
local handlers = AceHook.handlers
local actives = AceHook.actives
local scripts = AceHook.scripts
local onceSecure = AceHook.onceSecure
local _G = _G

-- functions for later definition
local createFunctionHook, hookFunction, unhookFunction, hookMethod, unhookMethod, donothing

local protectedScripts = {
	OnClick = true,
}

-- upgrading of embeded is done at the bottom of the file

local function safecall( func, ... )
	local success, err = pcall(func,...)
	if success then return err end
	if not err:find("%.lua:%d+:") then err = (debugstack():match("\n(.-: )in.-\n") or "") .. err end 
	geterrorhandler()(err)
end

local mixins = {
	"Hook", "SecureHook",
	"HookScript", "SecureHookScript",
	"Unhook", "UnhookAll",
	"IsHooked",
}

-- AceHook:Embed( target )
-- target (object) - target object to embed AceHook in
--
-- Embeds AceEevent into the target object making the functions from the mixins list available on target:..
function AceHook:Embed( target )
	for k, v in pairs( mixins ) do
		target[v] = self[v]
	end
	self.embeded[target] = true
	-- inject the hooks table safely
	target.hooks = target.hooks or {}
end

-- AceHook:OnEmbedDisable( target )
-- target (object) - target object that is being disabled
--
-- Unhooks all hooks when the target disables.
-- this method should be called by the target manually or by an addon framework
function AceHook:OnEmbedDisable( target )
	target:UnhookAll()
end

function createFunctionHook(self, handler, orig, secure)
	if not secure then
		if type(handler) == "string" then
			-- The handler is a method, need to self it
			local uid
			uid = function(...)
				if actives[uid] then
					return self[handler](self, ...)
				else
					return orig(...)
				end
			end
			return uid
		else
			-- The handler is a function, just call it
			local uid
			uid = function(...)
				if actives[uid] then
					return handler(...)
				else
					return orig(...)
				end
			end
			return uid
		end
	else
		-- secure hooks don't call the original method
		if type(handler) == "string" then
			-- The handler is a method, need to self it
			local uid
			uid = function(...)
				if actives[uid] then
					return self[handler](self, ...)
				end
			end
			return uid
		else
			-- The handler is a function, just call it
			local uid
			uid = function(...)
				if actives[uid] then
					return handler(...)
				end
			end
			return uid
		end
	end
end

function hookFunction(self, func, handler, secure)
	local orig = _G[func]
	
	if not orig or type(orig) ~= "function" then
		error( ("Attempt to hook a non-existant function %q"):format(func), 3)
	end
	
	if not handler then
		handler = func
	end

	local uid = registry[self][func]
	if uid then
		if actives[uid] then
			-- We have an active hook from this source.  Don't multi-hook
			error(("%q already has an active hook from this source."):format(func), 3)
		end
		
		if handlers[uid] == handler then
			-- The hook is inactive, so reactivate it
			actives[uid] = true
			return
		else
			self.hooks[func] = nil
			registry[self][func] = nil
			handlers[uid] = nil
			uid = nil
		end
	end
	
	if type(handler) == "string" then
		if type(self[handler]) ~= "function" then
			error(("Could not find the the handler %q when hooking function %q"):format(handler, func), 3)
		end
	elseif type(handler) ~= "function" then
		error(("Could not find the handler you supplied when hooking %q"):format(func), 3)
	end
	
	uid = createFunctionHook(self, func, handler, orig, secure)
	registry[self][func] = uid
	actives[uid] = true
	handlers[uid] = handler
	
	if not secure then
		_G[func] = uid
		if not self.hooks then self.hooks = {} end -- just in case we're not being used as a mixin
		self.hooks[func] = orig
	else
		hooksecurefunc(func, uid)
	end
end

function unhookFunction(self, func)
	if not registry[self][func] then
		error(("Tried to unhook %q which is not currently hooked."):format(func), 3)
	end
	
	local uid = registry[self][func]
	
	if actives[uid] then
		-- See if we own the global function
		if self.hooks[func] and _G[func] == uid then
			_G[func] = self.hooks[func]
			self.hooks[func] = nil
			registry[self][func] = nil
			handlers[uid] = nil
			actives[uid] = nil
			-- Magically all-done
		else
			actives[uid] = nil
		end
	end
end

function donothing() end

function hookMethod(self, obj, method, handler, script, secure)
	if not handler then
		handler = method
	end
	
	if not obj or type(obj) ~= "table" then
		error("The object you supplied could not be found, or isn't a table.", 3)
	end
	
	local uid = registry[self][obj] and registry[self][obj][method]
	if uid then
		if actives[uid] then
			-- We have an active hook from this source.  Don't multi-hook
			error(("%q already has an active hook from this source."):format(method), 3)
		end
		
		if handlers[uid] == handler then
			-- The hook is inactive, reactivate it.
			actives[uid] = true
			return
		else
			if self.hooks and self.hooks[obj] then
				self.hooks[obj][method] = nil
			end
			registry[self][obj][method] = nil
			handlers[uid] = nil
			actives[uid] = nil
			scripts[uid] = nil
			uid = nil
		end
	end
	
	if type(handler) == "string" then
		if type(self[handler]) ~= "function" then
			error(("Could not find the handler %q you supplied when hooking method %q"):format(handler, method), 3)
		end
	elseif type(handler) ~= "function" then
		error(("Could not find the handler you supplied when hooking method %q"):format(method), 3 )
	end
	
	local orig
	if script then
		if not obj.GetScript then
			error("The object you supplied does not have a GetScript method.", 3 )
		end
		if not obj:HasScript(method) then
			error(("The object you supplied doesn't allow the %q method."):format(method), 3)
		end
		
		orig = obj:GetScript(method)
		if type(orig) ~= "function" then
			-- Sometimes there is not a original function for a script.
			orig = donothing
		end
	else
		orig = obj[method]
	end
	if not orig then
		error(("Could not find the method or script %q you are trying to hook."):format(method), 3)
	end
	
	if not self.hooks then self.hooks = {} end -- just in case we're not being used as a mixin
	
	if not self.hooks[obj] then
		self.hooks[obj] = {}
	end
	if not registry[self][obj] then
		registry[self][obj] = {}
	end
	
	local uid = createFunctionHook(self, handler, orig, secure)
	registry[self][obj][method] = uid
	actives[uid] = true
	handlers[uid] = handler
	scripts[uid] = script and true or nil
	
	if script then
		if not secure then
			obj:SetScript(method, uid)
			self.hooks[obj][method] = orig
		else
			obj:HookScript(method, uid)
		end
	else
		if not secure then
			obj[method] = uid
			self.hooks[obj][method] = orig
		else
			hooksecurefunc(obj, method, uid)
		end
	end
end

function unhookMethod(self, obj, method)
	if not registry[self][obj] or not registry[self][obj][method] then
		error(("Attempt to unhook a method %q that is not currently hooked."):format(method), 3)
		return
	end
	
	local uid = registry[self][obj][method]
	
	if actives[uid] then
		if scripts[uid] then -- If this is a script
			if obj:GetScript(method) == uid then
				-- We own the script.  Revert to normal.
				if self.hooks[obj][method] == donothing then
					obj:SetScript(method, nil)
				else
					obj:SetScript(method, self.hooks[obj][method])
				end
				self.hooks[obj][method] = nil
				registry[self][obj][method] = nil
				handlers[uid] = nil
				scripts[uid] = nil
				actives[uid] = nil
			else
				actives[uid] = nil
			end
		else
			if self.hooks[obj] and self.hooks[obj][method] and obj[method] == uid then
				-- We own the method.  Revert to normal.
				obj[method] = self.hooks[obj][method]
				self.hooks[obj][method] = nil
				registry[self][obj][method] = nil
				handlers[uid] = nil
				actives[uid] = nil
			else
				actives[uid] = nil
			end
		end
	end
	if self.hooks[obj] and not next(self.hooks[obj]) then
		self.hooks[obj] = nil
	end
	if not next(registry[self][obj]) then
		registry[self][obj] = nil
	end
end

-- ("function" [, handler] [, hookSecure]) or (object, "method" [, handler] [, hookSecure])
function AceHook:Hook(object, method, handler, hookSecure)
	if type(object) == "string" then
		method, handler, hookSecure = object, method, handler
		if handler == true then
			handler, hookSecure = nil, true
		end
		assert( type(handler) == "function" or type(handler) == "string" or type(handler) == "nil") -- TODO: nicer error here.
		assert( type(hookSecure) == "boolean" or type(hookSecure) == "nil") -- TODO: nicer error here.
		if issecurevariable(method) or onceSecure[method] then
			if hookSecure then
				onceSecure[method] = true
			else
				error(("Attempt to hook secure function %q. Use `SecureHook' or add `true' to the argument list to override."):format(method), 2)
			end
		end
		hookFunction(self, method, handler, false)
	else
		if handler == true then
			handler, hookSecure = nil, true
		end
		assert( type(object) == "table" )
		assert( type(method) == "string")
		assert( type(handler) == "function" or type(handler) == "string" or type(handler) == "nil" )
		assert( type(hookSecure) == "boolean" or type(hookSecure) == "nil" )
		if not object[method] then
			error(("Attempt to hook method %q failed, it does not exist in the given object %q."):format(method, object), 2)
		end
		if not hookSecure and issecurevariable(object, method) then
			error(("Attempt to hook secure method %q. Use `SecureHook' or add `true' to the argument list to override."):format(method), 2)
		end
		hookMethod(self, object, method, handler, false, false)
	end
end

-- ("function", handler) or (object, "method", handler)
function AceHook:SecureHook(object, method, handler)
	if type(object) == "string" then
		method, handler = object, method
		assert( type(handler) == "function" or type(handler) == "string" or type(handler) == "nil") -- TODO: nicer error here.
		hookFunction(self, method, handler, true)
	else
		assert( type(object) == "table" )
		assert( type(method) == "string")
		assert( type(handler) == "function" or type(handler) == "string" or type(handler) == "nil" )
		if not object[method] then
			error(("Attempt to hook method %q failed, it does not exist in the given object %q."):format(method, object), 2)
		end
		hookMethod(self, object, method, handler, false, true)
	end
end

function AceHook:HookScript(frame, script, handler)
	assert( type(frame) == "table" )
	if not frame[0] or type(frame.IsProtected) ~= "function" then
		error("Bad argument #2 to `HookScript'. Expected frame.", 2)
	end
	assert( type(script) == "string" )
	assert( type(handler) == "function" or type(handler) == "string" or type(handler) == "nil") -- TODO: nicer error here.
	if frame:IsProtected() and protectedScripts[script] then
		error(("Cannot hook secure script %q."):format(script))
	end
	hookMethod(self, frame, script, handler, true, false)
end

function AceHook:SecureHookScript(frame, script, handler)
	assert( type(frame) == "table" )
	if not frame[0] or type(frame.IsProtected) ~= "function" then
		error("Bad argument #2 to `HookScript'. Expected frame.", 2)
	end
	assert( type(script) == "string" )
	assert( type(handler) == "function" or type(handler) == "string" or type(handler) == "nil") -- TODO: nicer error here.
	hookMethod(self, frame, script, handler, true, true)
end

-- ("function") or (object, "method")
function AceHook:Unhook(obj, method)
	if type(obj) == "string" then
		unhookFunction(self, obj)
	else
		assert( type(obj) == "string" or type(obj) == "table")
		assert( type(method) == "string" )
		unhookMethod(self, obj, method)
	end
end

function AceHook:UnhookAll()
	if type(registry[self]) ~= "table" then return end
	for key, value in pairs(registry[self]) do
		if type(key) == "table" then
			for method in pairs(value) do
				self:Unhook(key, method)
			end
		else
			self:Unhook(key)
		end
	end
end

-- ("function") or (object, "method")
function AceHook:IsHooked(obj, method)
	if type(obj) == "string" then
		if registry[self][obj] and actives[registry[self][obj]] then
			return true, handlers[registry[self][obj]]
		end
	else
		if registry[self] and registry[self][obj] and registry[self][obj][method] and actives[registry[self][obj][method]] then
			return true, handlers[registry[self][obj][method]]
		end
	end
	
	return false, nil
end

--- Upgrade our old embeded
for target, v in pairs( AceHook.embeded ) do
	AceHook:Embed( target )
end
