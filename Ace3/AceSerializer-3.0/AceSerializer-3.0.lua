--[[ $Id$ ]]
local MAJOR,MINOR = "AceSerializer-3.0", 2
local AceSerializer, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not AceSerializer then return end

local strbyte = string.byte
local strchar = string.char
local tconcat = table.concat
local gsub = string.gsub
local gmatch = string.gmatch
local pcall = pcall
local format = string.format
local type = type
local tostring, tonumber = tostring, tonumber
local select = select

-- quick copies of string representations of wonky numbers
local serNaN = tostring(0/0)
local serInf = tostring(1/0)
local serNegInf = tostring(-1/0)


-----------------------------------------------------------------------
-- Serialization functions

local function SerializeStringHelper(ch)	-- Used by SerializeValue for strings
	-- We use \126 ("~") as an escape character for all nonprints plus a few more
	local n = strbyte(ch)
	if n<=32 then 			-- nonprint + space
		return "\126"..strchar(n+64)
	elseif n==94 then		-- value separator 
		return "\126\125"
	elseif n==126 then		-- our own escape character
		return "\126\124"
	elseif n==127 then		-- nonprint (DEL)
		return "\126\123"
	else
		assert(false)	-- can't be reached if caller uses a sane regex
	end
end

local function SerializeValue(v, res, nres)
	-- We use "^" as a value separator, followed by one byte for type indicator
	local t=type(v)
	
	if t=="string" then		-- ^S = string (escaped to remove nonprints, "^"s, etc)
		res[nres+1] = "^S"
		res[nres+2] = gsub(v,"[%c \94\126\127]", SerializeStringHelper)
		nres=nres+2
	
	elseif t=="number" then	-- ^N = number (just tostring()ed) or ^F (float components)
		local str = tostring(v)
		if tonumber(str)==v  or str==serNaN or str==serInf or str==serNegInf then
			-- translates just fine, transmit as-is
			res[nres+1] = "^N"
			res[nres+2] = str
			nres=nres+2
		else
			local m,e = frexp(v)
			res[nres+1] = "^F"
			res[nres+2] = format("%.0f",m*2^53)	-- force mantissa to become integer (it's originally 0.5--0.9999)
			res[nres+3] = "^f"
			res[nres+4] = tostring(e-53)	-- adjust exponent to counteract mantissa manipulation
			nres=nres+4
		end
	
	elseif t=="table" then	-- ^T...^t = table (list of key,value pairs)
		nres=nres+1
		res[nres] = "^T"
		for k,v in pairs(v) do
			nres = SerializeValue(k, res, nres)
			nres = SerializeValue(v, res, nres)
		end
		nres=nres+1
		res[nres] = "^t"
	
	elseif t=="boolean" then	-- ^B = true, ^b = false
		nres=nres+1
		if v then
			res[nres] = "^B"	-- true
		else
			res[nres] = "^b"	-- false
		end
	
	elseif t=="nil" then		-- ^Z = nil (zero, "N" was taken :P)
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
local serializeTbl = { "^1" }	-- "^1" = Hi, I'm data serialized by AceSerializer protocol rev 1
function AceSerializer:Serialize(...)
	local nres = 1
	
	for i=1,select("#", ...) do
		local v = select(i, ...)
		nres = SerializeValue(v, serializeTbl, nres)
	end
	
	serializeTbl[nres+1] = "^^"	-- "^^" = End of serialized data
	
	return tconcat(serializeTbl, "", 1, nres+1)
end


-----------------------------------------------------------------------
-- Deserialization functions


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
	error("DeserializeStringHelper got called for '"..escape.."'?!?")  -- can't be reached unless regex is screwed up
end

local function DeserializeNumberHelper(number)
	if number == serNaN then
		return 0/0
	elseif number == serNegInf then
		return -1/0
	elseif number == serInf then
		return 1/0
	else
		return tonumber(number)
	end
end

-- DeserializeValue: worker function for :Deserialize()
-- It works in two modes:
--   Main (top-level) mode: Deserialize a list of values and return them all
--   Recursive (table) mode: Deserialize only a single value (_may_ of course be another table with lots of subvalues in it)
--
-- The function _always_ works recursively due to having to build a list of values to return
--
-- Callers are expected to pcall(DeserializeValue) to trap errors

local function DeserializeValue(iter,single,ctl,data)

	if not single then
		ctl,data = iter()
	end

	if not ctl then 
		error("Supplied data misses AceSerializer terminator ('^^')")
	end	

	if ctl=="^^" then
		-- ignore extraneous data
		return
	end

	local res
	
	if ctl=="^S" then
		res = gsub(data, "~.", DeserializeStringHelper)
	elseif ctl=="^N" then
		res = DeserializeNumberHelper(data)
		if not res then
			error("Invalid serialized number: '"..tostring(data).."'")
		end
	elseif ctl=="^F" then     -- ^F<mantissa>^f<exponent>
		local ctl2,e = iter()
		if ctl2~="^f" then
			error("Invalid serialized floating-point number, expected '^f', not '"..tostring(ctl2).."'")
		end
		local m=tonumber(data)
		e=tonumber(e)
		if not (m and e) then
			error("Invalid serialized floating-point number, expected mantissa and exponent, got '"..tostring(m).."' and '"..tostring(e).."'")
		end
		res = m*(2^e)
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
			if k==nil then 
				error("Invalid AceSerializer table format (no table end marker)")
			end
			ctl,data = iter()
			v = DeserializeValue(iter,true,ctl,data)
			if v==nil then
				error("Invalid AceSerializer table format (no table end marker)")
			end
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
-- Accepts serialized data, ignoring all control characters and whitespace.
--
-- Returns true followed by a list of values, OR false followed by a message
--

function AceSerializer:Deserialize(str)
	str = gsub(str, "[%c ]", "")	-- ignore all control characters; nice for embedding in email and stuff

	local iter = gmatch(str, "(^.)([^^]*)")	-- Any ^x followed by string of non-^
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
	return target
end

-- Update embeds
for target, v in pairs(AceSerializer.embeds) do
	AceSerializer:Embed(target)
end
