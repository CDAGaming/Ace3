--[[ $Id$ ]]
local ACEHOOK_MAJOR, ACEHOOK_MINOR = "AceHook-3.0", 0
local AceHook, oldminor = LibStub:NewLibrary(ACEHOOK_MAJOR, ACEHOOK_MINOR)

if not AceHook then return end -- No upgrade needed

AceHook.embeded = AceHook.embeded or {}
AceHook.registry = AceHook.registry or setmetatable({}, {__index = function(tbl, key) tbl[key] = {} return tbl[key] end })
AceHook.handlers = AceHook.handlers or {}
AceHook.actives = AceHook.actives or {}
AceHook.scripts = AceHook.scripts or {}
AceHook.onceSecure = AceHook.onceSecure or {}
AceHook.hooks = AceHook.hooks or {}

-- local upvalues
local registry = AceHook.registry
local handlers = AceHook.handlers
local actives = AceHook.actives
local scripts = AceHook.scripts
local onceSecure = AceHook.onceSecure
local _G = _G

-- functions for later definition
local donothing, createHook, unhook, hook

local protectedScripts = {
	OnClick = true,
}

-- upgrading of embeded is done at the bottom of the file

local mixins = {
	"Hook", "SecureHook",
	"HookScript", "SecureHookScript",
	"Unhook", "UnhookAll",
	"IsHooked",
	"RawHook", "RawHookScript"
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

function createHook(self, handler, orig, secure, failsafe)
	local uid
	local method = type(handler) == "string"
	uid = function(...)
		if actives[uid] then
			if failsafe then orig(...) end -- failsafe?
			if method then
				return self[handler](self, ...)
			else
				return handler(...)
			end
		elseif not secure then -- backup on non secure
			return orig(...)
		end
	end
	return uid
end

function unhook(self, obj, method)
	assert(not obj or type(obj) == "table")
	assert(type(method) == "string")
	
	local uid
	if obj then
		uid = registry[self][obj][method]
	else
		uid = registry[self][method]
	end
	assert(uid and actives[uid], not not uid)
	
	actives[uid], handlers[uid] = nil, nil
	
	if obj then
		if scripts[uid] and obj:GetScript(method) == uid then  -- unhooks scripts
			obj:SetScript(method, self.hooks[obj][method] ~= donothing and self.hooks[obj][method] or nil)	
			scripts[uid] = nil
		elseif obj and self.hooks[obj] and self.hooks[obj][method] and obj[method] == uid then -- unhooks methods
			obj[method] = self.hooks[obj][method]
		end
		
		self.hooks[obj][method] = nil
		registry[self][obj][method] = nil
		
		self.hooks[obj] = next(self.hooks[obj]) and self.hooks[obj] or nil
		registry[self][obj] = next(registry[self][obj]) and registry[self][obj] or nil
	else
		if self.hooks[method] and _G[method] == uid then -- unhooks functions
			_G[method] = self.hooks[method]
		end
		
		self.hooks[method] = nil
		registry[self][method] = nil
	end
end

function donothing() end

function hook(self, obj, method, handler, script, secure, raw)
	if not handler then hander = method end
	
	assert(not obj or type(obj) == "table")
	assert(type(method) == "string")
	assert((type(handler) == "string" and type(self[handler]) == "function") or type(handler) == "function")
	assert(not script or type(script) == "boolean")
	assert(not secure or type(secure) == "boolean")
	assert(not raw or type(raw) == "boolean")
	--Need to check on secure variable hooking here as well
	if script then assert(obj and obj.GetScript and obj:HasScript(method)) end

	local uid
	
	if obj then
		uid = registry[self][obj] and registry[self][obj][method]
	else
		uid = registry[self][method]
	end
	
	if uid then
		assert(not actives[uid]) -- active hook?
		
		if handlers[uid] == handler then
			actives[uid] = true
			return
		elseif obj then
			if self.hooks and self.hooks[obj] then
				self.hooks[obj][method] = nil
			end
			registry[self][obj][method] = nil
		else
			if self.hooks then
				self.hooks[method] = nil
			end
			registry[self][method] = nil
		end
		handlers[uid], actives[uid], scripts[uid] = nil, nil, nil
		uid = nil
	end
	
	local orig
	if script then
		orig = obj:GetScript(method) or donothing  -- I'm assuming that script hooking returns nil if there is no original function.
	elseif obj then
		orig = obj[method]
	else
		orig = _G[method]
	end
	assert(orig)
	
	uid = createHook(self, handler, orig, secure, not raw)
	
	if obj then
		self.hooks[obj] = self.hooks[obj] or {}
		registry[self][obj] = registry[self][obj] or {}
		registry[self][obj][method] = uid

		if not secure then
			if script then
				obj:SetScript(method, uid)
			else
				obj[method] = uid
			end
			self.hooks[obj][method] = orig
		else
			if script then
				obj:HookScript(method, uid)
			else
				hooksecurefunc(obj, method, uid)
			end
		end
	else
		registry[self][method] = uid
		
		if not secure then
			_G[method] = uid
			self.hooks[method] = orig
		else
			hooksecurefunc(method, uid)
		end
	end
	
	actives[uid], handlers[uid], scripts[uid] = true, handler, script and true or nil	
end

-- ("function" [, handler] [, hookSecure]) or (object, "method" [, handler] [, hookSecure])
function AceHook:Hook(object, method, handler, hookSecure)
	if type(object) == "string" then
		method, handler, hookSecure, object = object, method, handler, nil
	end
	
	if handler == true then
		handler, hookSecure = nil, true
	end
	
	hook(self, object, method, handler, false, false, false)	
end

-- ("function" [, handler] [, hookSecure]) or (object, "method" [, handler] [, hookSecure])
function AceHook:RawHook(object, method, handler, hookSecure)
	if type(object) == "string" then
		method, handler, hookSecure, object = object, method, handler, nil
	end
	
	if handler == true then
		handler, hookSecure = nil, true
	end
	
	hook(self, object, method, handler, false, false, true)
end

-- ("function", handler) or (object, "method", handler)
function AceHook:SecureHook(object, method, handler)
	if type(object) == "string" then
		method, handler, object = object, method, nil
	end
	
	hook(self, object, method, handler, false, true)
end

function AceHook:HookScript(frame, script, handler)
	hook(self, frame, script, handler, true, false, false)
end

function AceHook:RawHookScript(frame, script, handler)
	hook(self, frame, script, handler, true, false, true)
end

function AceHook:SecureHookScript(frame, script, handler)
	hook(self, frame, script, handler, true, true)
end

-- ("function") or (object, "method")
function AceHook:Unhook(obj, method)
	if type(obj) == "string" then
		unhook(self, nil, obj)
	else
		unhook(self, obj, method)
	end
end

function AceHook:UnhookAll()
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
	-- we don't check if registry[self] exists, this is done by evil magicks in the metatable
	if type(obj) == "string" then
		if registry[self][obj] and actives[registry[self][obj]] then
			return true, handlers[registry[self][obj]]
		end
	else
		if registry[self][obj] and registry[self][obj][method] and actives[registry[self][obj][method]] then
			return true, handlers[registry[self][obj][method]]
		end
	end
	
	return false, nil
end

--- Upgrade our old embeded
for target, v in pairs( AceHook.embeded ) do
	AceHook:Embed( target )
end
