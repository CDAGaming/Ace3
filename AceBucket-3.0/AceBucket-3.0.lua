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

-- AceBucket:Embed( target )
-- target (object) - target object to embed AceBucket in
--
-- Embeds AceBucket into the target object making the functions from the mixins list available on target:..
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

-- FireBucket ( bucket )
--
-- send the bucket to the callback function and schedule the next FireBucket in interval seconds
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

-- BucketHandler ( event, arg1 )
-- 
-- callback func for AceEvent
-- stores arg1 in the received table, and fires/schedules buckets
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

-- RegisterBucket( event, interval, callback, isMessage )
--
-- event(string or table) - the event, or a table with the events, that this bucket listens to
-- interval(int) - time between bucket fireings
-- callback(func or string) - function pointer, or method name of the object, that gets called when the bucket is cleared
-- isMessage(boolean) - register AceEvent Messages instead of game events
local function RegisterBucket(self, event, interval, callback, isMessage)
	local bucket = { object = self, handler = BucketHandler, callback = callback, interval = interval, received = {} }
	
	local regFunc
	if isMessage then
		regFunc = AceEvent.RegisterMessage
	else
		regFunc = AceEvent.RegisterEvent
	end
	
	if type(event) == "table" then
		for _,e in pairs(event) do
			regFunc(bucket, e, "handler")
		end
	else
		regFunc(bucket, event, "handler")
	end
	
	local handle = tostring(bucket)
	AceBucket.buckets[handle] = bucket
	
	return handle
end

-- AceEvent:RegisterBucketEvent(event, interval, callback)
-- AceEvent:RegisterBucketMessage(message, interval, callback)
--
-- event/message(string or table) -  the event, or a table with the events, that this bucket listens to
-- interval(int) - time between bucket fireings
-- callback(func or string) - function pointer, or method name of the object, that gets called when the bucket is cleared
function AceBucket:RegisterBucketEvent(event, interval, callback)
	return RegisterBucket(self, event, interval, callback, false)
end

function AceBucket:RegisterBucketMessage(message, interval, callback)
	return RegisterBucket(self, message, interval, callback, true)
end
