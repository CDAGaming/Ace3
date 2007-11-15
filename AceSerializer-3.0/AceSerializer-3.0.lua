
local MAJOR,MINOR = "AceSerializer-3.0", 1
local AceSerializer, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not AceSerializer then return end

local strbyte=string.byte
local strchar=string.char
local tconcat=table.concat
local gsub=string.gsub
local gmatch=string.gmatch
local pcall=pcall


local function SerializeStringHelper(ch)	-- Used by SerializeValue for strings
	local n = strbyte(ch)
	if n<=32 then 			-- nonprint + space
		return "\126"..strchar(n+64)
	elseif n==94 then		-- unit separator
		return "\126\125"
	elseif n==126 then		-- our escape character
		return "\126\124"
	elseif n==127 then		-- nonprint (delete)
		return "\126\123"
	else
		assert(false)
	end
end

local function SerializeValue(v, res, nres)

	local t=type(v)
	
	if t=="string" then
		res[nres+1] = "^S"
		res[nres+2] = gsub(v,"[%c \94\126\127]", SerializeStringHelper)
		nres=nres+2
	elseif t=="number" then
		res[nres+1] = "^N"
		res[nres+2] = tonumber(v)
		nres=nres+2
	elseif t=="table" then
		nres=nres+1
		res[nres] = "^T"
		for k,v in pairs(v) do
			nres = SerializeValue(k, res, nres)
			nres = SerializeValue(v, res, nres)
		end
		nres=nres+1
		res[nres] = "^t"
	elseif t=="boolean" then
		nres=nres+1
		if v then
			res[nres] = "^B"	-- true
		else
			res[nres] = "^b"	-- false
		end
	elseif t=="nil" then
		nres=nres+1
		res[nres] = "^Z"
	else
		error(MAJOR..": Cannot serialize a value of type '"..t.."'")	-- can't produce error on right level, this is wildly recursive
	end
	
	return nres
end



-----------------------------------------------------------------------
-- API Serialize(...)
--
-- Takes a list of values (strings, numbers, booleans, nils, tables)
-- and returns it in serialized form (a string).
-- May throw errors on invalid data types.
--

function AceSerializer:Serialize(...)
	local res = { "^1" }	-- "^1" = Hi, I'm data serialized by AceSerializer protocol rev 1
	local nres = 1
	
	for i=1,select("#",...) do
		local v = select(i,...)
		nres = SerializeValue(v, res, nres)
	end
	
	res[nres+1] = "^^"	-- "^^" = End of serialized data
	
	return tconcat(res,"")
end


local function DeserializeStringHelper(escape)
	if escape<"~\123" then
		return strchar(strbyte(escape,2,2)-64)
	elseif escape=="~\123" then
		return "\127"
	elseif escape=="~\124" then
		return "\126"
	elseif escape=="~\125" then
		return "\94"
	end
	print("oof")
	return ""
end

local function DeserializeValue(iter,single,ctl,data)

	if not single then
		ctl,data = iter()
	end

	if not ctl then 
		error("Supplied data misses AceSerializer terminator ('^^')")
	end	

	if ctl=="^^" then
		return
	end

	local res
	
	if ctl=="^S" then
		res = gsub(data, "~.", DeserializeStringHelper)
	elseif ctl=="^N" then
		res = tonumber(data)
		if not res then
			error("Invalid serialized number: '"..data.."'")
		end
	elseif ctl=="^B" then	-- yeah yeah ignore data portion
		res = true
	elseif ctl=="^b" then   -- yeah yeah ignore data portion
		res = false
	elseif ctl=="^Z" then	-- yeah yeah ignore data portion
		res = nil
	elseif ctl=="^T" then
		-- ignore ^T's data, future extensibility?
		res = {}
		local k,v
		while true do
			ctl,data = iter()
			if ctl=="^t" then break end	-- ignore ^t's data
			k = DeserializeValue(iter,true,ctl,data)
			ctl,data = iter()
			v = DeserializeValue(iter,true,ctl,data)
			res[k]=v
		end
	else
		error("Invalid AceSerializer control code '"..ctl.."'")
	end
	
	if not single then
		return res,DeserializeValue(iter)
	else
		return res
	end
end


-----------------------------------------------------------------------
-- API Deserialize(str)
-- 
-- Takes serialized data, ignoring all control characters and whitespace.
--
-- Returns true followed by a list of values OR false followed by a message
--

function AceSerializer:Deserialize(str)
	str = gsub(str, "[%c ]", "")	-- ignore all control characters; nice for embedding in email and stuff

	local iter = string.gmatch(str, "(^.)([^^]*)")	-- Any ^x followed by string of non-^
	local ctl,data = iter()
	if not ctl or ctl~="^1" then
		-- we purposefully ignore the data portion of the start code, it can be used as an extension mechanism
		return false, "Supplied data is not AceSerializer data (rev 1)"
	end

	return pcall(DeserializeValue, iter)
end


----------------------------------------
-- Base library stuff
----------------------------------------

AceSerializer.internals = {	-- for test scripts
	SerializeValue = SerializeValue,
	SerializeStringHelper = SerializeStringHelper,
}

local mixins = {
	"Serialize",
	"Deserialize",
}

AceSerializer.embeds = AceSerializer.embeds or {}

function AceSerializer:Embed(target)
	for k, v in pairs(mixins) do
		target[v] = self[v]
	end
	self.embeds[target] = true
end

-- Update embeds
for target, v in pairs(AceSerializer.embeds) do
	AceSerializer:Embed(target)
end
