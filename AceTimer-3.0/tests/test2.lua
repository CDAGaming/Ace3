dofile("utils.lua")

local MAJOR = "AceTimer-3.0"

dofile("../"..MAJOR..".lua")

local AceTimer,minor = LibStub:GetLibrary(MAJOR)

-- NOTE, the below pcalls should NOT contain error position information.
-- The reason is that if the error level is correctly set, it will point to _inside_ the pcall(), which does not have a position


-------------------------------------------------------------------
-- Test ScheduleTimer errorchecking of method

obj = {}

ok,msg = pcall(AceTimer.ScheduleTimer, obj, "method", 4, "arg")	-- This should fail - method not defined
assert(not ok)
assert(msg == "Usage: ScheduleTimer(callback, delay, arg): 'callback' - method not found on target object.", msg)


obj.method = "hi, i'm NOT a function, i'm something else"

ok,msg = pcall(AceTimer.ScheduleTimer, obj, "method", 4, "arg")	-- This should fail - obj["method"] is not a function
assert(not ok)
assert(msg == "Usage: ScheduleTimer(callback, delay, arg): 'callback' - method not found on target object.", msg)


ok,msg = pcall(AceTimer.ScheduleTimer, obj, nil, 4, "arg")	-- This should fail (method is nil)
assert(not ok)
assert(msg == "Usage: ScheduleTimer(callback, delay, arg): 'callback' - string or function expected.", msg)


ok,msg = pcall(AceTimer.ScheduleTimer, obj, {}, 4, "arg")	-- This should fail (method is table)
assert(not ok)
assert(msg == "Usage: ScheduleTimer(callback, delay, arg): 'callback' - string or function expected.", msg)


-- (Note: ScheduleRepeatingTimer here just to check naming)
ok,msg = pcall(AceTimer.ScheduleRepeatingTimer, obj, 123, 4, "arg")	-- This should fail too (method is integer)
assert(not ok)
assert(msg == "Usage: ScheduleRepeatingTimer(callback, delay, arg): 'callback' - string or function expected.", msg)



-------------------------------------------------------------------
-- Check AceTimer:CancelAllTimers() -- not allowed

ok,msg = pcall(AceTimer.CancelAllTimers, AceTimer)
assert(not ok)
assert(string.match(msg, "^../AceTimer%-3.0.lua:%d*: assertion failed!"), msg)


-------------------------------------------------------------------
--

cnt=0
obj.method = function() cnt=cnt+1 end

AceTimer.ScheduleRepeatingTimer(obj, "method", 1, "arg")

FireUpdate(2)	-- Border case: at this exact bucket, we should be able to convince the timer to fire twice even though it only gets a single onupdate
assert(cnt==2, cnt)

errors=0
function geterrorhandler() 
	return function(msg)
		errors=errors+1
		assert(strmatch(msg, ": attempt to call a string value"))
	end
end

obj.method = "this should cause errors"
FireUpdate(4)

assert(errors==2)  -- timer should have run twice



-----------------------------------------------------------------------

print "OK"
