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

local bucketCache = setmetatable({}, {__mode='k'})

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
	local empty = not next(received)
	
	if not empty then
		if type(callback) == "string" then
			safecall(bucket.object[callback], bucket.object, received)
		else
			safecall(callback, received)
		end
		
		for k in pairs(received) do
			received[k] = nil
		end
	
		-- if the bucket was not empty, schedule another FireBucket in interval seconds
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
	if self == AceBucket then error("Cannot register buckets on the AceBucket library object.", 3) end
	if type(event) ~= "string" and type(event) ~= "table" then error("Bad argument #2 to RegisterBucket. (string or table expected)", 3) end
	if not tonumber(interval) then error("Bad argument #3 to RegisterBucket. (number expected)", 3) end
	if type( callback ) ~= "string" and type( callback ) ~= "function" then error( "Bad argument #3 to RegisterBucket. (string or function expected).", 3) end
	if type( callback ) == "string" and type( self[callback] ) ~= "function" then error( "Bad argument #3 to RegisterBucket. Method not found on target object.", 3) end
	
	local bucket = next(bucketCache)
	if bucket then
		bucketCache[bucket] = nil
	else
		bucket = { handler = BucketHandler, received = {} }
	end
	bucket.object, bucket.callback, bucket.interval = self, callback, tonumber(interval)
	
	local regFunc = isMessage and AceEvent.RegisterMessage or AceEvent.RegisterEvent
	
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

-- AceBucket:RegisterBucketEvent(event, interval, callback)
-- AceBucket:RegisterBucketMessage(message, interval, callback)
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

-- AceBucket:UnregisterBucket ( handle )
-- handle - the handle of the bucket as returned by RegisterBucket*
--
-- will unregister any events and messages from the bucket and clear any remaining data
function AceBucket:UnregisterBucket(handle)
	local bucket = AceBucket.buckets[handle]
	if bucket then
		AceEvent.UnregisterAllEvents(bucket)
		AceEvent.UnregisterAllMessages(bucket)
		
		-- clear any remaining data in the bucket
		for k in pairs(bucket.received) do
			bucket.received[k] = nil
		end
		
		if bucket.timer then
			AceTimer.CancelTimer(bucket, bucket.timer)
		end
		
		AceBucket.buckts[handle] = nil
		-- store our bucket in the cache
		bucketCache[bucket] = true
	end
end

--- embedding and embed handling

local mixins = {
	"RegisterBucketEvent",
	"RegisterBucketMessage", 
	"UnregisterBucket",
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

for addon,_ in pairs(AceTimer.embeds) do
	AceTimer:Embed(addon)
end
