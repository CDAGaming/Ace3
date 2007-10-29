dofile("wow_api.lua")
dofile("LibStub.lua")
dofile("../CallbackHandler-1.0/CallbackHandler-1.0.lua")

local CH = assert(LibStub("CallbackHandler-1.0"))


-----------------------------------------------------------------------
-- test default names
do
	local test = {}
	CH:New(test, nil, nil, nil, OnUsed, OnUnused)

	assert(test.RegisterCallback)
	assert(test.UnregisterCallback)
	assert(test.UnregisterAllCallbacks)
end


-----------------------------------------------------------------------
-- test custom names
do
	local test = {}
	CH:New(test, "Reg", "Unreg", "UnregAll", OnUsed, OnUnused)

	assert(test.Reg)
	assert(test.Unreg)
	assert(test.UnregAll)
end


-----------------------------------------------------------------------
-- test with unregall==false
do
	local test = {}
	CH:New(test, "Reg", "Unreg", false, OnUsed, OnUnused)

	assert(test.Reg)
	assert(test.Unreg)
	assert(test.UnregisterAllCallbacks == nil)
end


-----------------------------------------------------------------------
-- test OnUsed / OnUnused
do
	local test = {}

	local n=0
	
	local lastOnUsed
	local function OnUsed(self, event)
		assert(self==test)
		lastOnUsed=event
		n=n+1
	end
	
	local lastOnUnused
	local function OnUnused(self, event)
		assert(self==test)
		lastOnUnused=event
		n=n+1
	end
		

	local reg = CH:New(test, "Reg", "Unreg", "UnregAll", OnUsed, OnUnused)
	
	local function func() end
	
	test.Reg("addon1", "Thing1", func)		-- should fire an OnUsed Thing1
	assert(n==1 and lastOnUsed=="Thing1")

	test.Reg("addon1", "Thing2", func)		-- should fire an OnUsed Thing2
	assert(n==2 and lastOnUsed=="Thing2")
	
	test.Reg("addon1", "Thing1", func)		-- should NOT fire an OnUsed (Thing1 seen already)
	assert(n==2)
	
	test.Reg("addon2", "Thing1", func)		-- should NEITHER fire an OnUsed  (Thing1 seen already)
	assert(n==2)

	test.Reg("addon2", "Thing2", func)		-- should NEITHER fire an OnUsed  (Thing2 seen already)
	assert(n==2)

	-- now start unregging Thing1
	
	test.Unreg("addon1", "Thing1")		-- Still one left, shouldnt fire OnUnused yet
	assert(n==2)
	
	test.Unreg("addon2", "Thing1")
	assert(n==3 and lastOnUnused=="Thing1", dump(n,lastOnUnused))	-- Now we should get OnUnused Thing1
	
	-- aaand unreg Thing2 (via some UnregAlls)
	
	test.UnregAll("addon1")
	assert(n==3)
	test.UnregAll("addon2")
	assert(n==4 and lastOnUnused=="Thing2")
	
end


-----------------------------------------------------------------------
-- Test registering new handlers for an event while in a callback for that event
--
-- Problem: for k,v in pairs(eventlist)  eventlist[somethingnew]=foo end
-- This happens when we fire callback X, and the handler registers another handler for X

do
	local test={}
	local reg = CH:New(test, "Reg", "Unreg", "UnregAll")
	local REPEATS = 1000  -- we get roughly 50% failure ratio, so 1000 tests WILL trigger it
	
	local hasRun = {}
	local hasRunNoops = {}
	
	local function noop(noopName) 
		hasRunNoops[noopName]=hasRunNoops[noopName]+1
	end
	
	local rnd=math.random

	local regMore=true
	local function RegOne(name)
		hasRun[name]=hasRun[name]+1
		if regMore then
			local noopName
			repeat
				noopName = tostring(rnd(1,99999999))
			until not hasRunNoops[noopName] and not hasRun[noopName]
			hasRunNoops[noopName]=0
			test.Reg(noopName, "EVENT", noop, noopName)
		end
	end

	for i=1,REPEATS do	
		local name
		repeat
			name=tostring(rnd(1,99999999))
		until not hasRun[name]
		hasRun[name]=0
		test.Reg(name, "EVENT", RegOne, name)
	end
	
	-- Firing this event should lead to all 1000 callbacks running, and registering another 1000 callbacks
	reg:Fire("EVENT")
	
	-- Test that they all ran once
	local n=0
	for k,v in pairs(hasRun) do
		assert(v==1, dump(k,v).." should be ==1")
		n=n+1
	end
	assert(n==REPEATS, dump(n))
	
	-- And that all the noops didnt run (they should have been delayed til the next fire)
	local n=0
	for k,v in pairs(hasRunNoops) do
		assert(v==0, dump(k,v).." should be ==0")
		n=n+1
	end
	assert(n==REPEATS, dump(n))
	
	
	-- Now we run all of them again without registering more, so we should get 1000+1000 callbacks
	regMore=false
	reg:Fire("EVENT")
	
	-- Test that all main events ran another time (total 2)
	local n=0
	for k,v in pairs(hasRun) do
		assert(v==2, dump(k,v).." should be ==2")
		n=n+1
	end
	assert(n==REPEATS, dump(n))
	
	-- And that all the noops ran once
	local n=0
	for k,v in pairs(hasRunNoops) do
		assert(v==1, dump(k,v).." should be ==1")
		n=n+1
	end
	assert(n==REPEATS, dump(n))
end


-----------------------------------------------------------------------
-- TODO: TEST REENTRANCY (firing an event from inside a callback)


-- We do not test the actual callback logic here. The AceEvent tests do that plenty.


-----------------------------------------------------------------------
print "OK"