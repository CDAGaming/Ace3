local MAJOR, MINOR = "AceBucket-3.0", 0
local AceBucket, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

local AceEvent = LibStub:GetLibrary("AceEvent-3.0")
local AceTimer = LibStub:GetLibrary("AceTimer-3.0")

if not AceBucket then
	return
elseif not oldminor then
	-- initial setup
	AceBucket.buckets = {}
	AceBucket.embeds = {}
end

--- embedding and embed handling

local mixins = {
	"RegisterBucketEvent",
	"RegisterBucketMessage", 
} 

-- AceEvent:Embed( target )
-- target (object) - target object to embed AceEvent in
--
-- Embeds AceEevent into the target object making the functions from the mixins list available on target:..
function AceBucket:Embed( target )
	for k, v in pairs( mixins ) do
		target[v] = self[v]
	end
	self.embeds[target] = true
end

local function safecall( func, ... )
	local success, err = pcall(func,...)
	if success then return err end
	if not err:find("%.lua:%d+:") then err = (debugstack():match("\n(.-: )in.-\n") or "") .. err end 
	geterrorhandler()(err)
end

local function FireBucket(bucket)
	local callback = bucket.callback
	local received = bucket.received
	if type(callback) == "string" then
		safecall(bucket.object[callback], bucket.object, received)
	else
		safecall(callback, received)
	end
	
	local empty = not next(received)
	for k in pairs(received) do
		received[k] = nil
	end
	
	-- if the bucket was not empty, schedule another FireBucket in interval seconds
	if not empty then
		bucket.timer = AceTimer.ScheduleTimer(bucket, FireBucket, bucket.interval, bucket)
	else -- if it was empty, clear the timer and wait for the next event
		bucket.timer = nil
	end
end

local function BucketHandler(self, event, arg1)
	if arg1 == nil then
		arg1 = "nil"
	end
	
	self.received[arg1] = (self.received[arg1] or 0) + 1
	
	-- if we are not scheduled yet, fire the last event, which will automatically schedule the bucket again
	if not self.timer then
		FireBucket(self)
	end
end

local function RegisterBucket(self, event, interval, callback, isMessage)
	local bucket = { object = self, handler = BucketHandler, callback = callback, interval = interval, received = {} }
	if not isMessage then
		AceEvent.RegisterEvent(bucket, event, "handler")
	else
		AceEvent.RegisterMessage(bucket, event, "handler")
	end
	
	local handle = tostring(bucket)
	AceBucket.buckets[handle] = bucket
	
	return handle
end


function AceBucket:RegisterBucketEvent(event, interval, callback)
	return RegisterBucket(self, event, interval, callback, false)
end

function AceBucket:RegisterBucketMessage(message, interval, callback)
	return RegisterBucket(self, message, interval, callback, true)
end
