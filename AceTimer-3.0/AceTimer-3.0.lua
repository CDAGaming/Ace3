
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
-- CAUTION: The BUCKETS constant constrains how many timers can be efficiently handled. With too many hash collisions, performance will decrease.


local ACETIMER_MAJOR = "AceTimer-3.0"
local ACETIMER_MINOR = 0

local AceTimer = LibStub:NewLibrary(ACETIMER_MAJOR, ACETIMER_MINOR)
if not AceTimer then return end

local HZ=11					-- Timers will not be fired more often than HZ-1 times per second. 
												-- Keep at intended speed PLUS ONE or we get bitten by floating point rounding errors
												-- If this is ever LOWERED, all existing timers need to be enforced to have a delay >= 1/HZ on lib upgrade.
												-- If this number is ever changed, all entries need to be rehashed on lib upgrade.
local BUCKETS=131		-- Prime for good distribution
												-- If this number is ever changed, all entries need to be rehashed on lib upgrade.

local hash = AceTimer.hash or {}
AceTimer.hash = hash

for i=0,BUCKETS-1 do
	hash[i] = hash[i] or {}
end

local curint = floor(GetTime()*HZ)

local OnUpdate()
	local now = GetTime()
	local nowint = floor(now*HZ)
	
	if nowint==curint then
		return
	end

	if curint<=nowint-BUCKETS then		-- Happens on e.g. instance loads
		curint = nowint - BUCKETS+1
	else
		curint = curint + 1
	end
	
	local soon=now+1	-- +1 is safe as long as 1 < HZ < BUCKETS/2
	
	for curint=curint,nowint do	-- loop until we catch up with "now", usually only 1 iteration
		local curbucket = curint % BUCKETS
		local curbuckettable = hash[curbucket]
		
		for timer,when in pairs(curbuckettable) do		-- all timers in the current bucket
			if when<soon then
				timer.method(timer.arg)
				
				local delay=timer.delay
				local newtime = when+delay
				if newtime<now then			-- TODO: Still won't catch cases of landing in the same bucket!
					newtime = now+delay
				end
				local newbucket = floor(newtime*HZ) % BUCKETS
				if newbucket~=curbucket then		-- Is this test necessary? Will the for loop screw up if we delete and reinsert or not?
					curbuckettable[timer] = nil
					curbuckettable[timer] = newtime
				end
			end
		end
	
	end	

	curint = nowint
		
end

function AceTimer:ScheduleRepeatingTimer(method,delay,arg)
	local timer = { object=self, method=method, delay=delay, arg=arg }
	hash[ floor((now+delay)*HZ) % BUCKETS ][timer] = now + delay
	return timer
end

function AceTimer:CancelTimer(timer)
	for k,v in pairs(hash) do
		if v[timer] then
			v[timer] = nil
		end
	end
end
