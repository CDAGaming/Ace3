--[[ $Id$ ]]
local ACEEVENT_MAJOR, ACEEVENT_MINOR = "AceEvent-3.0", 1
local AceEvent, oldminor = LibStub:NewLibrary(ACEEVENT_MAJOR, ACEEVENT_MINOR)

if not AceEvent then 
	return
elseif not oldminor then  -- This is the first version
	AceEvent.events = setmetatable({}, {__index = function(tbl, key) tbl[key] = {} return tbl[key] end }) -- Blizzard events
	AceEvent.messages = setmetatable({}, {__index = function(tbl, key) tbl[key] = {} return tbl[key] end }) -- Own messages
	AceEvent.frame = CreateFrame("Frame", "AceEvent30Frame") -- our event frame
	AceEvent.embeds = {} -- what objects embed this lib
	-- ANY new members must be added AFTER the if clause!
end


-- upgrading of embeds is done at the bottom of the file

-- local upvalues
local events, messages = AceEvent.events, AceEvent.messages

local function safecall( func, ... )
	local success, err = pcall(func,...)
	if success then return err end
	if not err:find("%.lua:%d+:") then err = (debugstack():match("\n(.-: )in.-\n") or "") .. err end 
	geterrorhandler()(err)
end

-- generic event and message firing function
-- fires the event/message into the given registry
local function Fire(registry, event, ...)
	for obj, method in pairs( registry[event] ) do
		if type(method) == "string" then
			safecall( obj[method], obj, event, ... ) 
		else
			safecall( method, event, ... )
		end
	end
	
	-- I've added event to the args passed in, in anticipation of our decision in jira.  
	-- TODO: If its reversed reverse this change
end

-- Generic registration and unregisration for messages and events
local function RegOrUnreg(self, unregister, registry, event, method )
	if self == AceEvent then error( "Can not register events on the AceEvent library object.", 3) end
	if type(event) ~= "string" then error( "Bad argument #2 to (Un)registerEvent. (string expected)", 3) end
	
	if unregister then -- unregister
		registry[event][self] = nil
	else -- overwrite any old registration
		if not method then method = event end
		if type( method ) ~= "string" and type( method ) ~= "function" then error( "Bad argument #3 to RegisterEvent. (string or function expected).", 3) end
		if type( method ) == "string" and type( self[method] ) ~= "function" then error( "Bad argument #3 to RegisterEvent. Method not found on target object.", 3) end
		registry[event][self] = method
	end
end

--- embedding and embed handling

local mixins = {
	"RegisterEvent", "UnregisterEvent",
	"RegisterMessage", "UnregisterMessage",
	"SendMessage",
	"UnregisterAllEvents", "UnregisterAllMessages",
} 

-- AceEvent:Embed( target )
-- target (object) - target object to embed AceEvent in
--
-- Embeds AceEevent into the target object making the functions from the mixins list available on target:..
function AceEvent:Embed( target )
	for k, v in pairs( mixins ) do
		target[v] = self[v]
	end
	self.embeds[target] = true
end

-- AceEvent:OnEmbedDisable( target )
-- target (object) - target object that is being disabled
--
-- Unregister all events messages etc when the target disables.
-- this method should be called by the target manually or by an addon framework
function AceEvent:OnEmbedDisable( target )
	target:UnregisterAllEvents()
	target:UnregisterAllMessages()
end

-- AceEvent:RegisterEvent( event, method )
-- event (string) - Blizzard event to register for
-- method (string or function) - Method to call on self or function to call when event is triggered
--
-- Registers a blizzard event and binds it to the given method
function AceEvent:RegisterEvent( event, method )
	RegOrUnreg(self, false, events, event, method)
	AceEvent.frame:RegisterEvent(event)
end

-- AceEvent:UnregisterEvent( event )
-- event (string) - Blizzard event to unregister
--
-- Unregisters a blizzard event
function AceEvent:UnregisterEvent( event )
	RegOrUnreg(self, true, events, event )
	if not next(events[event]) then	-- events[event] _will_ exist after RegOrUnreg call
		AceEvent.frame:UnregisterEvent(event)
	end
end

-- AceEvent:RegisterMessage( message, method )
-- message (string) - Inter Addon message to register for
-- method (string or function) - Method to call on self or function to call when message is received
--
-- Registers an inter addon message and binds it to the given method
function AceEvent:RegisterMessage( message, method )
	RegOrUnreg(self, false, messages, message, method )
end

-- AceEvent:UnregisterMessage( message )
-- message (string) - Interaddon message to unregister
--
-- Unregisters an interaddon message
function AceEvent:UnregisterMessage( message )
	RegOrUnreg(self, true, messages, message )
end

-- AceEvent:SendMessage( message, ... )
-- message (string) - Message to send
-- ... (tuple) - Arguments to the message
-- 
-- Sends an interaddon message with arguments
function AceEvent:SendMessage(message, ... )
	Fire(messages, message, ...)
end

-- AceEvent:UnregisterAllEvents()
-- 
-- Unregisters all events registered by self
function AceEvent:UnregisterAllEvents()
	for event, slot in pairs( events ) do
		if slot[self] then
			self:UnregisterEvent(event) -- call unregisterevent instead of regunreg here to make sure the frame gets unregistered if needed
		end
	end
end

-- AceEvent:UnregisterAllMessages()
-- 
-- Unregisters all messages registered by self
function AceEvent:UnregisterAllMessages()
	for message, slot in pairs( messages ) do
		if slot[self] then
			RegOrUnreg(self, true, messages, message )
		end
	end
end

-- Last step of upgrading

-- Fire blizzard events into the event listeners
AceEvent.frame:SetScript("OnEvent", function(this, event, ...)
	Fire(events, event, ...)
end)

--- Upgrade our old embeds
for target, v in pairs( AceEvent.embeds ) do
	AceEvent:Embed( target )
end
