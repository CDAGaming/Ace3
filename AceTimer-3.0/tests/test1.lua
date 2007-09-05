-- Test1: Tests basic functionality and upgrading of AceTimer

dofile("utils.lua")

local MAJOR = "AceTimer-3.0"

dofile("../"..MAJOR..".lua")

local AceTimer,minor = LibStub:GetLibrary(MAJOR)


-----------------------------------------------------------------------
-- Test embedding

local obj={}
AceTimer:Embed(obj)

assert(type(obj.ScheduleTimer)=="function")
assert(type(obj.ScheduleRepeatingTimer)=="function")
assert(type(obj.CancelTimer)=="function")
assert(type(obj.CancelAllTimers)=="function")



-----------------------------------------------------------------------
-- Test basic registering, both ways

t1s = 0
function obj:Timer1(arg)
	assert(self==obj)
	assert(arg=="t1")
	t1s = t1s + 1
end

t2s = 0
function Timer2(arg)
	assert(arg=="t2")
	t2s = t2s + 1
end

function obj:Timer3()
	assert(false)	-- This should never run!
end

t4s=0
t5s=0
function obj:Timer4(arg)
	assert(arg=="t4s" or arg=="t5s")
	_G[arg] = _G[arg] + 1
end

timer1 = obj:ScheduleRepeatingTimer("Timer1", 1, "t1")
timer2 = obj:ScheduleRepeatingTimer(Timer2, 2, "t2")
timer3 = obj:ScheduleRepeatingTimer("Timer3", 3, "t3")	
timer4 = obj:ScheduleTimer("Timer4", 1, "t4s")
timer5 = obj:ScheduleTimer("Timer4", 2, "t5s")	 -- same handler function as timer4!

t3s = 0
function obj:Timer3(arg) 	-- This should be the one to run, not the old Timer3
	assert(self==obj)
	assert(arg=="t3")
	t3s = t3s + 1
end


-----------------------------------------------------------------------
-- Now do some basic tests of timers running at the right time and 
-- the right amount of times


FireUpdate(0)
assert(t1s==0 and t2s==0 and t3s==0 and t4s==0 and t5s==0)

FireUpdate(0.99)
assert(t1s==0 and t2s==0 and t3s==0 and t4s==0 and t5s==0)

FireUpdate(1.00)
assert(t1s==1 and t2s==0 and t3s==0 and t4s==1 and t5s==0)

FireUpdate(1.99)
assert(t1s==1 and t2s==0 and t3s==0 and t4s==1 and t5s==0)

FireUpdate(2.5)
assert(t1s==2 and t2s==1 and t3s==0 and t4s==1 and t5s==1)

FireUpdate(2.99)
assert(t1s==2 and t2s==1 and t3s==0)

FireUpdate(3.099)
assert(t1s==3 and t2s==1, t2s and t3s==1, t3s)

FireUpdate(6.000)
assert(t3s==2)

assert(t4s==1 and t5s==1)	-- make sure our single shot timers haven't run more than once



t6s=0
obj:ScheduleTimer(function() t6s=t6s+1 end, 1)	-- fire up a single oneshot timer to live past our upgrade below


-----------------------------------------------------------------------
-- Screw up our mixins, pretend to have an older acetimer loaded, and reload acetimer

obj.ScheduleTimer = 12345

dofile("../"..MAJOR..".lua")

assert(obj.ScheduleTimer == 12345)	-- shouldn't have gotten replaced yet

LibStub.minors[MAJOR] = LibStub.minors[MAJOR] - 1

dofile("../"..MAJOR..".lua")

assert(type(obj.ScheduleTimer)=="function")	-- should have been replaced now


-----------------------------------------------------------------------
-- Test that timers still live

t1s, t2s, t3s, t4s, t5s = 0,0,0,0,0

FireUpdate(6.5)
assert(t1s==0 and t2s==0 and t3s==0 and t4s==0 and t5s==0 and t6s==0)

FireUpdate(7.01)
assert(t1s==1 and t2s==0 and t3s==0 and t4s==0 and t5s==0 and t6s==1)

FireUpdate(8.01)
assert(t1s==2 and t2s==1 and t3s==0 and t4s==0 and t5s==0 and t6s==1)

FireUpdate(9.01)
assert(t1s==3 and t2s==1 and t3s==1 and t4s==0 and t5s==0 and t6s==1)


-----------------------------------------------------------------------
-- Test cancelling

t1s, t2s, t3s, t4s, t5s, t6s = 0,0,0,0,0,0

obj:CancelTimer(timer1)	-- cancel a single timer

FireUpdate(10.01)
assert(t1s==0, t1s)
assert(t2s==1, t2s)
assert(t1s==0 and t2s==1)	-- timer 2 should still work


t1s, t2s, t3s, t4s, t5s = 0,0,0,0,0

obj:CancelAllTimers()

FireUpdate(20.01)	-- long time in the future
assert(t1s==0 and t2s==0 and t3s==0 and t4s==0 and t5s==0 and t6s==0)	-- nothing should have fired




-----------------------------------------------------------------------

print "OK"
