
-- Basic assumptions:
-- * In a typical system, we do more re-scheduling per second than there are timer pulses per second
-- * Regardless of timer implementation, we cannot guarantee timely delivery due to FPS restriction (may be as low as 10)

-- Not yet implemented assumptions:
-- * In a high FPS system (assume 50), one frame per addon (assume 50) means 2500 function calls per second.
--   PRO: Lower CPU load with 1 global frame
--   CON: Profiling?

-- This implementation:
-- CON: The smallest timer interval is constrained by HZ (currently 1/10s).
-- PRO: It will correctly fire any timer faster than HZ over a length of time, e.g. 0.11s interval -> 90 times over 10 seconds
-- PRO: In lag bursts, the system simly skips missed timer intervals to decrease load
--   CON: Algorithms depending on a timer firing "N times per minute" will fail
-- PRO: (Re-)scheduling is O(1) with a VERY small constant. It's a simple table insertion in a hash bucket.
-- PRO: ALLOWS scheduling multiple timers with the same funcref/method
-- CAUTION: The BUCKETS constant constrains how many timers can be efficiently handled. With too many hash collisions, performance will decrease.


local MAJOR, MINOR = "AceTimer-3.0", 0

local AceTimer = LibStub:NewLibrary(MAJOR, MINOR)
if not AceTimer then return end

local HZ=11					-- Timers will not be fired more often than HZ-1 times per second. 
												-- Keep at intended speed PLUS ONE or we get bitten by floating point rounding errors (n.5 + 0.1 can be n.599999)
												-- If this is ever LOWERED, all existing timers need to be enforced to have a delay >= 1/HZ on lib upgrade.
												-- If this number is ever changed, all entries need to be rehashed on lib upgrade.
local BUCKETS=131		-- Prime for good distribution
												-- If this number is ever changed, all entries need to be rehashed on lib upgrade.

AceTimer.hash = AceTimer.hash or {}			-- Array of [0..BUCKET-1]={[timerobj]=time, [timerobj2]=time2, ...}
AceTimer.selfs = AceTimer.selfs or {}		-- Array of [self]={[handle]=timerobj, [handle2]=timerobj2, ...}
AceTimer.frame = AceTimer.frame or CreateFrame("Frame", "AceTimer30Frame")

local hash = AceTimer.hash
for i=0,BUCKETS-1 do
	hash[i] = hash[i] or {}
end

local function safecall(func,...)
	local ok, res = pcall(func,...)
	if ok then return res end
	if not res:find("%.lua:%d+:") then res = (debugstack():match("\n(.-: )in.-\n") or "") .. res end 
	geterrorhandler()(res)
end



-- OnUpdate function - traverse buckets, always chasing "now", and fire timers that have expired

local lastint = floor(GetTime()*HZ)

local function OnUpdate()
	local now = GetTime()
	local nowint = floor(now*HZ)
	
	if nowint==lastint then
		return
	end

	if lastint<=nowint-BUCKETS then
		-- Happens on e.g. instance loads, but COULD happen on high local load situations also
		lastint = nowint - BUCKETS+1
	else
		lastint = lastint + 1
	end
	
	local soon=now+1	-- +1 is safe as long as 1 < HZ < BUCKETS/2

	
	for curint=lastint,nowint do	-- loop until we catch up with "now", usually only 1 iteration
		local curbucket = curint % BUCKETS
		local curbuckettable = hash[curbucket]
		
		for timer,when in pairs(curbuckettable) do		-- all timers in the current bucket
		
			if when<soon then
				
				-- Call the timer func, either as a method on given object, or a straight function ref
				local method = timer.object[timer.method]
				if method then
					safecall(method, timer.object, timer.arg)
				else
					safecall(timer.method, timer.arg)
				end
				
				local delay=timer.delay
				if not delay then
					-- single-shot timer
					curbuckettable[timer] = nil
					AceTimer.timers[tostring(timer)] = nil
				else
					-- repeating timer
					local newtime = when+delay
					if newtime<now then			-- Keep lag from making us firing a timer unnecessarily. (Note that this still won't catch too-short-delay timers though.)
						newtime = now+delay
					end
					local newbucket = floor(newtime*HZ) % BUCKETS
					if newbucket~=curbucket then		-- Is this test necessary? Will the for loop screw up if we delete and reinsert or not?
						curbuckettable[timer] = nil
						curbuckettable[timer] = newtime
					end
				end
			end -- if when<soon
		
		end -- for timer,when in pairs(curbuckettable)
	
	end	-- for curint=lastint,nowint

	lastint = nowint
		
end


-- Reg(): Workhorse for :ScheduleTimer() / :ScheduleRepeatingTimer()

local function Reg(self,method,delay,arg,repeat)
	assert(self~=AceTimer, "ScheduleTimer: error: called using AceTimer as 'self'")
	
	assert(type(method)=="function" or (self~=AceTimer and type(method)=="string" and type(self[method])=="function"),
		"ScheduleTimer: 'method': Expected function reference or self[\"method\"] call")
		
	if delay<1/(HZ-1) then
		delay = 1/(HZ-1)
	end
	
	local timer = { object=self, method=method, delay=(repeat and delay), arg=arg }
	hash[ floor((now+delay)*HZ) % BUCKETS ][timer] = now + delay
	
	local handle=tostring(timer)
	
	local selftimers = AceTimer.selfs[self]
	if not selftimers then
		selftimers = {}
		AceTimer.selfs[self] = {}
	end
	selftimers[handle] = timer
	
	return handle
end


-- AceTimer:ScheduleTimer( method, delay, arg )
-- AceTimer:ScheduleRepeatingTimer( method, delay, arg )
--
-- method - function reference or string name of method to call on self
-- delay  - delay in seconds, will be automatically rounded up to smallest allowable interval
-- arg    - optional argument to pass to method
--
-- returns a handle to the timer, which is used for cancelling it

function AceTimer:ScheduleTimer(method,delay,arg)
	return Reg(self,method,delay,arg)
end

function AceTimer:ScheduleRepeatingTimer(method,delay,arg)
	return Reg(self,method,delay,arg,true)
end


-- AceTimer:CancelTimer(handle)
--
-- handle - Opaque object given by ScheduleTimer
--
-- Cancels a timer with the given handle, registered by the same 'self' as given here

function AceTimer:CancelTimer(handle)
	local selftimers = AceTimer.timers[self]
	local timer = selftimers and selftimers[handle]
	if timer then
		selftimers[handle] = nil

		-- This is fairly expensive, but it is better to take the hit here rather than having an extra if-else in the OnUpdate
		for k,v in pairs(hash) do
			if v[timer] then
				v[timer] = nil
			end
		end
	end
end


-- AceTimer:CancelAllTimers()
--
-- Cancels all timers registered to given 'self'

function AceTimer:CancelAllTimers()
	assert(self~=AceTimer)
	
	local selftimers = AceTimer.selfs[self]
	if selftimers then
		for handle,_ in pairs(selftimers) do
			AceTimer.CancelTimer(self,handle)
		end
	end
end


-- Embed handling

AceTimer.embeds = AceTimer.embeds or {}

local embeds = {
	"ScheduleTimer", "ScheduleRepeatingTimer", 
	"CancelTimer", "CancelAllTimers"
}

function AceTimer:Embed(object)
	AceTimer.embeds[object] = true
	for k,v in pairs(embeds) do
		object[v] = AceTimer[v]
	end
end

for addon,_ in pairs(AceTimer.embeds) do
	AceTimer:Embed(addon)
end


-- Finishing touchups

AceTimer.frame:SetScript("OnUpdate", OnUpdate)

