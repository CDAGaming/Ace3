--[[ $Id$ ]]
local MAJOR, MINOR = "CallbackHandler-1.0", 7
local CallbackHandler = LibStub:NewLibrary(MAJOR, MINOR)

if not CallbackHandler then return end -- No upgrade needed

local meta = {__index = function(tbl, key) tbl[key] = {} return tbl[key] end}

-- Lua APIs
local tgetn = table.getn
local strgsub, strsub = string.gsub, string.sub
local assert, error, loadstring, unpack = assert, error, loadstring, unpack
local setmetatable, rawset, rawget = setmetatable, rawset, rawget
local next, select, pairs, type, tostring = next, select, pairs, type, tostring

-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: geterrorhandler

local xpcall = xpcall

local function errorhandler(err)
	return geterrorhandler()(err)
end
CallbackHandler.errorhandler = errorhandler

local function CreateDispatcher(argCount)
	local code = [[
		local xpcall, errorhandler = xpcall, LibStub("CallbackHandler-1.0").errorhandler
		local method, UP_ARGS
		local function call()
			local func, ARGS = method, UP_ARGS
			method, UP_ARGS = nil, NILS
			return func(ARGS)
		end
		return function(handlers, ARGS)
			local index
			index, method = next(handlers)
			if not method then return end
			repeat
				UP_ARGS = ARGS
				xpcall(call, errorhandler)
				index, method = next(handlers, index)
			until not method
		end
	]]
	local c = 4*argCount-1
	local s = "b01,b02,b03,b04,b05,b06,b07,b08,b09,b10"
	code = strgsub(code, "UP_ARGS", strsub(s,1,c))
	s = "a01,a02,a03,a04,a05,a06,a07,a08,a09,a10"
	code = strgsub(code, "ARGS", strsub(s,1,c))
	s = "nil,nil,nil,nil,nil,nil,nil,nil,nil,nil"
	code = strgsub(code, "NILS", strsub(s,1,c))
	return assert(loadstring(code, "safecall Dispatcher["..tostring(argCount).."]"))()
end

local Dispatchers = setmetatable({}, {__index=function(self, argCount)
	local dispatcher = CreateDispatcher(argCount)
	rawset(self, argCount, dispatcher)
	return dispatcher
end})

--------------------------------------------------------------------------
-- CallbackHandler:New
--
--   target            - target object to embed public APIs in
--   RegisterName      - name of the callback registration API, default "RegisterCallback"
--   UnregisterName    - name of the callback unregistration API, default "UnregisterCallback"
--   UnregisterAllName - name of the API to unregister all callbacks, default "UnregisterAllCallbacks". false == don't publish this API.

function CallbackHandler:New(target, RegisterName, UnregisterName, UnregisterAllName)

	RegisterName = RegisterName or "RegisterCallback"
	UnregisterName = UnregisterName or "UnregisterCallback"
	if UnregisterAllName==nil then	-- false is used to indicate "don't want this method"
		UnregisterAllName = "UnregisterAllCallbacks"
	end

	-- we declare all objects and exported APIs inside this closure to quickly gain access
	-- to e.g. function names, the "target" parameter, etc


	-- Create the registry object
	local events = setmetatable({}, meta)
	local registry = { recurse=0, events=events }

	-- registry:Fire() - fires the given event/message into the registry
	function registry:Fire(eventname, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
		local args = { a1, a2, a3, a4, a5, a6, a7, a8, a9, a10 }
		if not rawget(events, eventname) or not next(events[eventname]) then return end
		local oldrecurse = registry.recurse
		registry.recurse = oldrecurse + 1

		Dispatchers[tgetn(args) + 1](events[eventname], eventname, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)

		registry.recurse = oldrecurse

		if registry.insertQueue and oldrecurse==0 then
			-- Something in one of our callbacks wanted to register more callbacks; they got queued
			for eventname,callbacks in pairs(registry.insertQueue) do
				local first = not rawget(events, eventname) or not next(events[eventname])	-- test for empty before. not test for one member after. that one member may have been overwritten.
				for self,func in pairs(callbacks) do
					events[eventname][self] = func
					-- fire OnUsed callback?
					if first and registry.OnUsed then
						registry.OnUsed(registry, target, eventname)
						first = nil
					end
				end
			end
			registry.insertQueue = nil
		end
	end

	-- Registration of a callback, handles:
	--   self["method"], leads to self["method"](self, ...)
	--   self with function ref, leads to functionref(...)
	--   "addonId" (instead of self) with function ref, leads to functionref(...)
	-- all with an optional arg, which, if present, gets passed as first argument (after self if present)
	target[RegisterName] = function(self, eventname, method, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
		local args = {arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9}
		if type(eventname) ~= "string" then
			error("Usage: "..RegisterName.."(eventname, method[, arg]): 'eventname' - string expected.", 2)
		end

		method = method or eventname

		local first = not rawget(events, eventname) or not next(events[eventname])	-- test for empty before. not test for one member after. that one member may have been overwritten.

		if type(method) ~= "string" and type(method) ~= "function" then
			error("Usage: "..RegisterName.."(\"eventname\", \"methodname\"): 'methodname' - string or function expected.", 2)
		end

		local regfunc

		if type(method) == "string" then
			-- self["method"] calling style
			if type(self) ~= "table" then
				error("Usage: "..RegisterName.."(\"eventname\", \"methodname\"): self was not a table?", 2)
			elseif self==target then
				error("Usage: "..RegisterName.."(\"eventname\", \"methodname\"): do not use Library:"..RegisterName.."(), use your own 'self'", 2)
			elseif type(self[method]) ~= "function" then
				error("Usage: "..RegisterName.."(\"eventname\", \"methodname\"): 'methodname' - method '"..tostring(method).."' not found on self.", 2)
			end

			if tgetn(args) >= 1 then	-- this is not the same as testing for arg==nil!
				regfunc = function(...) self[method](self,arg1,unpack(args)) end
			else
				regfunc = function(...) self[method](self,unpack(args)) end
			end
		else
			-- function ref with self=object or self="addonId" or self=thread
			if type(self)~="table" and type(self)~="string" and type(self)~="thread" then
				error("Usage: "..RegisterName.."(self or \"addonId\", eventname, method): 'self or addonId': table or string or thread expected.", 2)
			end

			if tgetn(args) >= 1 then	-- this is not the same as testing for arg==nil!
				regfunc = function(...) method(arg1,unpack(args)) end
			else
				regfunc = method
			end
		end


		if events[eventname][self] or registry.recurse<1 then
		-- if registry.recurse<1 then
			-- we're overwriting an existing entry, or not currently recursing. just set it.
			events[eventname][self] = regfunc
			-- fire OnUsed callback?
			if registry.OnUsed and first then
				registry.OnUsed(registry, target, eventname)
			end
		else
			-- we're currently processing a callback in this registry, so delay the registration of this new entry!
			-- yes, we're a bit wasteful on garbage, but this is a fringe case, so we're picking low implementation overhead over garbage efficiency
			registry.insertQueue = registry.insertQueue or setmetatable({},meta)
			registry.insertQueue[eventname][self] = regfunc
		end
	end

	-- Unregister a callback
	target[UnregisterName] = function(self, eventname)
		if not self or self==target then
			error("Usage: "..UnregisterName.."(eventname): bad 'self'", 2)
		end
		if type(eventname) ~= "string" then
			error("Usage: "..UnregisterName.."(eventname): 'eventname' - string expected.", 2)
		end
		if rawget(events, eventname) and events[eventname][self] then
			events[eventname][self] = nil
			-- Fire OnUnused callback?
			if registry.OnUnused and not next(events[eventname]) then
				registry.OnUnused(registry, target, eventname)
			end
		end
		if registry.insertQueue and rawget(registry.insertQueue, eventname) and registry.insertQueue[eventname][self] then
			registry.insertQueue[eventname][self] = nil
		end
	end

	-- OPTIONAL: Unregister all callbacks for given selfs/addonIds
	if UnregisterAllName then
		target[UnregisterAllName] = function(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
			local args = {arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9}
			if tgetn(args)<1 then
				error("Usage: "..UnregisterAllName.."([whatFor]): missing 'self' or \"addonId\" to unregister events for.", 2)
			end
			if tgetn(args)==1 and args[1]==target then
				error("Usage: "..UnregisterAllName.."([whatFor]): supply a meaningful 'self' or \"addonId\"", 2)
			end


			for i=1,tgetn(args) do
				local self = args[i]
				if registry.insertQueue then
					for eventname, callbacks in pairs(registry.insertQueue) do
						if callbacks[self] then
							callbacks[self] = nil
						end
					end
				end
				for eventname, callbacks in pairs(events) do
					if callbacks[self] then
						callbacks[self] = nil
						-- Fire OnUnused callback?
						if registry.OnUnused and not next(callbacks) then
							registry.OnUnused(registry, target, eventname)
						end
					end
				end
			end
		end
	end

	return registry
end


-- CallbackHandler purposefully does NOT do explicit embedding. Nor does it
-- try to upgrade old implicit embeds since the system is selfcontained and
-- relies on closures to work.

