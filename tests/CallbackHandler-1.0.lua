dofile("wow_api.lua")
dofile("LibStub.lua")
dofile("../CallbackHandler-1.0/CallbackHandler-1.0.lua")

local CH = assert(LibStub("CallbackHandler-1.0"))


-- test default names
do
	local test = {}
	CH:New(test, nil, nil, nil, OnUsed, OnUnused)

	assert(test.RegisterCallback)
	assert(test.UnregisterCallback)
	assert(test.UnregisterAllCallbacks)
end

-- test custom names
do
	local test = {}
	CH:New(test, "Reg", "Unreg", "UnregAll", OnUsed, OnUnused)

	assert(test.Reg)
	assert(test.Unreg)
	assert(test.UnregAll)
end

-- test with unregall==false
do
	local test = {}
	CH:New(test, "Reg", "Unreg", false, OnUsed, OnUnused)

	assert(test.Reg)
	assert(test.Unreg)
	assert(test.UnregisterAllCallbacks == nil)
end

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


-- We do not test the actual callback logic here. The AceEvent tests do that plenty.


-----------------------------------------------------------------------
print "OK"