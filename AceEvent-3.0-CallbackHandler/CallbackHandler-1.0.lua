--[[ $Id$ ]]
local MAJOR, MINOR = "CallbackHandler-1.0", 1
local lib = LibStub:NewLibrary(MAJOR, MINOR)

if not lib then return end

local meta = {__index = function(tbl, key) tbl[key] = {} return tbl[key] end}

local type = type
local pcall = pcall
local pairs = pairs


local function safecall(func, ...)
	local success, err = pcall(func, ...)
	if success then return err end
	if not err:find("%.lua:%d+:") then err = (debugstack():match("\n(.-: )in.-\n") or "") .. err end 
	geterrorhandler()(err)
end


--------------------------------------------------------------------------
-- CallbackHandler:New
--
--   target            - target object to embed public APIs in
--   RegisterName      - name of the callback registration API, default "RegisterCallback"
--   UnregisterName    - name of the callback unregistration API, default "UnregisterCallback"
--   UnregisterAllName - name of the API to unregister all callbacks, default "UnregisterAllCallbacks". false == don't publish this API.
--   OnUsed            - optional function to be called with params (target, eventname) when the first callback is added to an event
--   OnUnused          - optional function to be called with params (target, eventname) when the last callback is removed from an event

function lib:New(target, RegisterName, UnregisterName, UnregisterAllName, OnUsed, OnUnused)

	RegisterName = RegisterName or "RegisterCallback"
	UnregisterName = UnregisterName or "UnregisterCallback"
	if UnregisterAllName==nil then	-- false is used to indicate "don't want this method"
		UnregisterAllName = "UnregisterAllCallbacks"
	end

	-- we declare all objects and exported APIs inside this closure to quickly gain access 
	-- to e.g. function names, OnUsed callback, "target" parameter, etc


	-- Create the registry object
	local events = setmetatable({}, meta)
	local registry = { events=events }
	
	-- registry:Fire() - fires the given event/message into the registry
	function registry:Fire(eventname, ...)
		for _, method in pairs(events[eventname]) do
			safecall(method, ...)
		end
	end

	-- Registration of a callback, handles self["method"], self with function ref, "addonId" (instead of self) with function ref
	target[RegisterName] = function(self, eventname, method)
		if type(eventname) ~= "string" then 
			error("Usage: "..RegisterName.."(eventname, method): 'eventname' - string expected.", 2)
		end
	
		method = method or eventname
		
		local first = rawget(events, eventname) and next(events[eventname])	-- test for empty before. not test for one member after. that one member may have been overwritten.
		
		if type(method) ~= "string" and type(method) ~= "function" then
			error("Usage: "..RegisterName.."(eventname, method: 'method' - string or function expected.", 2)
		end
		
		if type(method) == "string" then
			-- self["method"] calling style
			if type(self) ~= "table" then
				error("Usage: "..RegisterName.."(eventname, methodname): self was not a table?", 2)
			elseif self==target then
				error("Usage: "..RegisterName.."(eventname, methodname): do not use Library:"..RegisterName.."(), use your own 'self'", 2)
			elseif type(self[method]) ~= "function" then
				error("Usage: "..RegisterName.."(eventname, methodname): 'methodname' - method not found on self.", 2)
			else
				events[eventname][self] = function(...) self[method](self,...) end
			end
		else
			if type(self)=="table" then
				-- function ref with self=object
				events[eventname][self] = function(...) method(self,...) end
			elseif type(self)~="string" then
				error("Usage: "..RegisterName.."(\"addonId\", eventname, method): 'addonId': string expected.", 2)
			else
				-- function ref with self="addonID"
				events[eventname][self] = method
			end
		end
		
		-- fire OnUsed callback?
		if OnUsed and first then		
			OnUsed(target, eventname)
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
			if OnUnused and not next(events[eventname]) then
				OnUnused(target, eventname)
			end
		end
	end
	
	-- OPTIONAL: Unregister all callbacks for given selfs/addonIds
	if UnregisterAllName then
		target[UnregisterAllName] = function(...)
			if select("#",...)<1 then
				error("Usage: "..UnregisterAllName.."(): missing 'self' or \"addonId\" to unregister events for.")
			end
			
			for i=1,select("#",...) do
				local self = select(i,...)
				for eventname, callbacks in events do
					if callbacks[self] then
						callbacks[self] = nil
						-- Fire OnUnused callback?
						if OnUnused and not next(callbacks) then
							OnUnused(target, eventname)
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

