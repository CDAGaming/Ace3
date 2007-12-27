
--[[
AceConfigCmd-3.0

Handles commandline optionstable access

REQUIRES: AceConsole-3.0 for command registration (loaded on demand)

]]

-- TODO: handle disabled / hidden
-- TODO: implement handlers for all types
-- TODO: plugin args


local MAJOR, MINOR = "AceConfigCmd-3.0", 1
local lib = LibStub:NewLibrary(MAJOR, MINOR)

if not lib then return end

local cfgreg = LibStub("AceConfigRegistry-3.0")
local AceConsole -- LoD
local AceConsoleName = "AceConsole-3.0"


local L = setmetatable({}, {	-- TODO: replace with proper locale
	__index = function(self,k) return k end
})



local function print(msg)
	(SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME):AddMessage(msg)
end


-- pickfirstset() - picks the first non-nil value and returns it

local function pickfirstset(...)	
	for i=1,select("#",...) do
		if select(i,...)~=nil then
			return select(i,...)
		end
	end
end


-- err() - produce real error() regarding malformed options tables etc

local function err(info,inputpos,msg )
	local cmdstr=" "..strsub(info.input, 1, inputpos-1)
	error(MAJOR..": /" ..info[0] ..cmdstr ..": "..(msg or "malformed options table"), 2)
end


-- usererr() - produce chatframe message regarding bad slash syntax etc

local function usererr(info,inputpos,msg )
	local cmdstr=strsub(info.input, 1, inputpos-1);
	print("/" ..info[0] .. " "..cmdstr ..": "..(msg or "malformed options table"))
end


-- callmethod() - call a given named method (e.g. "get", "set") with given arguments

local function callmethod(info, inputpos, tab, methodtype, ...)
	local method = info[methodtype]
	if not method then
		err(info, inputpos, "'"..methodtype.."': not set")
	end

	info.arg = tab.arg

	if type(method)=="function" then
		return method(info, ...)
	elseif type(method)=="string" then
		if type(info.handler[method])~="function" then
			err(info, inputpos, "'"..methodtype.."': '"..method.."' is not a member function of "..tostring(info.handler))
		end
		return info.handler[method](info.handler, info, ...)
	else
		assert(false)	-- type should have already been checked on read
	end
end

-- callfunction() - call a given named function (e.g. "name", "desc") with given arguments

local function callfunction(info, tab, methodtype, ...)
	local method = tab[methodtype]

	info.arg = tab.arg
	
	if type(method)=="function" then
		return method(info, ...)
	else
		assert(false) -- type should have already been checked on read
	end
end

-- do_final() - do the final step (set/execute) along with validation and confirmation

local function do_final(info, inputpos, tab, methodtype, ...)
	if info.validate then 
		local res = callmethod(info,inputpos,tab,"validate",...)
		if type(res)=="string" then
			usererr(info, inputpos, "'"..strsub(info.input, inputpos).."' - "..res)
			return
		end
	end
	-- console ignores .confirm
	
	callmethod(info,inputpos,tab,methodtype, ...)
end


-- getparam() - used by handle() to retreive and store "handler", "get", "set", etc

local function getparam(info, inputpos, tab, depth, paramname, types, errormsg)
	local old,oldat = info[paramname], info[paramname.."_at"]
	local val=tab[paramname]
	if val~=nil then
		if val==false then
			val=nil
		elseif not types[type(val)] then 
			err(info, inputpos, "'" .. paramname.. "' - "..errormsg) 
		end
		info[paramname] = val
		info[paramname.."_at"] = depth
	end
	return old,oldat
end


-- iterateargs(tab) - custom iterator that iterates both t.args and t.plugins.*
local dummytable={}

local function iterateargs(tab)
	if not tab.plugins then 
		return pairs(tab.args) 
	end
	
	local argtabkey,argtab=next(tab.plugins)
	local v
	
	return function(_, k)
		while argtab do
			k,v = next(argtab, k)
			if k then return k,v end
			if argtab==tab.args then
				argtab=nil
			else
				argtabkey,argtab = next(tab.plugins, argtabkey)
				if not argtabkey then
					argtab=tab.args
				end
			end
		end
	end
end

local function showhelp(info, inputpos, tab, noHead)
	if not noHead then
		print(info.appName..": arguments to /"..info[0].." "..strsub(info.input,1,inputpos-1)..":")
	end
	
	local sortTbl = {}	-- [1..n]=name
	local refTbl = {}   -- [name]=tableref
	
	for k,v in iterateargs(tab) do
		if not refTbl[k] then	-- a plugin overriding something in .args
			table.insert(sortTbl, k)
			refTbl[k] = v
		end
	end
	
	table.sort(sortTbl, function(one, two) 
		local o1 = refTbl[one].order or 100
		local o2 = refTbl[two].order or 100
		if type(o1) == "function" or type(o1) == "string" then
			info.order = o1
			info[#info+1] = one
			o1 = callmethod(info, inputpos, refTbl[one], "order")
			info[#info] = nil
			info.order = nil
		end
		if type(o2) == "function" or type(o1) == "string" then
			info.order = o2
			info[#info+1] = two
			o2 = callmethod(info, inputpos, refTbl[two], "order")
			info[#info] = nil
			info.order = nil
		end
		if o1<0 and o2<0 then return o1<o2 end
		if o2<0 then return true end
		if o1<0 then return false end
		if o1==o2 then return tostring(one)<tostring(two) end   -- compare names
		return o1<o2
	end)
	
	for _,k in ipairs(sortTbl) do
		local v = refTbl[k]
		-- recursively show all inline groups
		local name, desc = v.name, v.desc
		if type(name) == "function" then
			name = callfunction(info, v, 'name')
		end
		if type(desc) == "function" then
			desc = callfunction(info, v, 'desc')
		end
		if v.type == "group" and pickfirstset(v.cmdInline, v.inline, false) then
			print("  "..(desc or name)..":")
			showhelp(info, inputpos, v, true)
		else
			print("  "..k.." - "..(desc or name or ""))
		end
	end
end




-- constants used by getparam() calls below

local handlertypes = {["table"]=true}
local handlermsg = "expected a table"

local functypes = {["function"]=true, ["string"]=true}
local funcmsg = "expected function or member name"

-- handle() - selfrecursing function that processes input->optiontable 
-- - depth - starts at 0
-- - retfalse - return false rather than produce error if a match is not found (used by inlined groups)

local function handle(info, inputpos, tab, depth, retfalse)

	if not(type(tab)=="table" and type(tab.type)=="string") then err(info,inputpos) end

	-------------------------------------------------------------------
	-- Grab hold of handler,set,get,func,etc if set (and remember old ones)
	-- Note that we do NOT validate if method names are correct at this stage,
	-- the handler may change before they're actually used!

	local oldhandler,oldhandler_at = getparam(info,inputpos,tab,depth,"handler",handlertypes,handlermsg)
	local oldset,oldset_at = getparam(info,inputpos,tab,depth,"set",functypes,funcmsg)
	local oldget,oldget_at = getparam(info,inputpos,tab,depth,"get",functypes,funcmsg)
	local oldfunc,oldfunc_at = getparam(info,inputpos,tab,depth,"func",functypes,funcmsg)
	local oldvalidate,oldvalidate_at = getparam(info,inputpos,tab,depth,"validate",functypes,funcmsg)
	local oldconfirm,oldconfirm_at = getparam(info,inputpos,tab,depth,"confirm",functypes,funcmsg)
	
	-------------------------------------------------------------------
	-- Act according to .type of this table
		
	if tab.type=="group" then
		------------ group --------------------------------------------
		
		if type(tab.args)~="table" then err(info, inputpos) end
		if tab.plugins and type(tab.plugins)~="table" then err(info,inputpos) end
		
		-- grab next arg from input
		local _,nextpos,arg = string.find(info.input, " *([^ ]+) *", inputpos)
		if not arg then
			showhelp(info, inputpos, tab)
			return
		end
		nextpos=nextpos+1
		
		-- loop .args and try to find a key with a matching name
		for k,v in iterateargs(tab) do
			if not(type(k)=="string" and type(v)=="table" and type(v.type)=="string") then err(info,inputpos, "options table child '"..tostring(k).."' is malformed") end
			
			-- is this child an inline group? if so, traverse into it
			if v.type=="group" and pickfirstset(v.cmdInline, v.inline, false) then
				info[depth+1] = k
				if handle(info, inputpos, v, depth+1, true)==false then
					info[depth+1] = nil
					-- wasn't found in there, but that's ok, we just keep looking down here
				else
					return	-- done, name was found in inline group
				end
			-- matching name and not a inline group
			elseif strlower(arg)==strlower(k) then
				info[depth+1] = k
				return handle(info,nextpos,v,depth+1)
			end
		end
			
		-- no match 
		if retfalse then
			-- restore old infotable members and return false to indicate failure
			info.handler,info.handler_at = oldhandler,oldhandler_at
			info.set,info.set_at = oldset,oldset_at
			info.get,info.get_at = oldget,oldget_at
			info.func,info.func_at = oldfunc,oldfunc_at
			info.validate,info.validate_at = oldvalidate,oldvalidate_alt
			info.confirm,info.confirm_at = oldconfirm,oldconfirm_at
			return false
		end
		
		-- couldn't find the command, display error
		usererr(info, inputpos, "'"..arg.."' - " .. L["unknown argument"])
		return
	end
	
	local str = strsub(info.input,inputpos);
	
	if tab.type=="execute" then
		------------ execute --------------------------------------------
		do_final(info, inputpos, tab, "func")
		

	
	elseif tab.type=="input" then
		------------ input --------------------------------------------
		
		local res = true
		if tab.pattern then
			if not(type(tab.pattern)=="string") then err(info, inputpos, "'pattern' - expected a string") end
			if not strmatch(str, tab.pattern) then
				usererr(info, inputpos, "'"..str.."' - " .. L["invalid input"])
				return
			end
		end
		
		do_final(info, inputpos, tab, "set", str)
		

	
	elseif tab.type=="toggle" then
		------------ toggle --------------------------------------------
		local b
		local str = strtrim(strlower(str))
		if str=="" then
			b = not callmethod(info, inputpos, tab, "get")
		elseif str==L["on"] then
			b = true
		elseif str==L["off"] then
			b = false
		else
			usererr(info, inputpos, format(L["'%s' - expected 'on' or 'off', or no argument to toggle."], str))
			return
		end
		
		do_final(info, inputpos, tab, "set", b)
		

	elseif tab.type=="range" then
		------------ range --------------------------------------------
		local val = tonumber(str)
		if not val then
			usererr(info, inputpos, "'"..str.."' - "..L["expected number"])
			return
		end
		if type(info.step)=="number" then
			val = val- (val % info.step)
		end
		if type(info.min)=="number" and val<info.min then
			usererr(info, inputpos, val.." - "..format(L["must be equal to or higher than %s"], tostring(info.min)) )
			return
		end
		if type(info.max)=="number" and val>info.max then
			usererr(info, inputpos, val.." - "..format(L["must be equal to or lower than %s"], tostring(info.max)) )
			return
		end
		
		do_final(info, inputpos, tab, "set", val)

	
	elseif tab.type=="select" or tab.type=="multiselect" then
		------------ select / multiselect ------------------------------------
		local str = strtrim(strlower(str))

		local sels   -- sels = table with list of arguments (just a single one for type=select)
		if tab.type=="select" then
			if str=="" then
				usererr(info, inputpos, "missing selection")
			end
			sels = { str }
		else
			sels = {}
			for v in string.gmatch("  a  b c  ", "[^ ]+") do
				tinsert(sels, v)
			end
		end
		
		local values = tab.values
		if type(values) == "function" or type(values) == "string" then
			info.values = values
			values = callmethod(info, inputpos, tab, "values")
			info.values = nil
		end
		if type(values)~="table" then err(info, inputpos, "'values' - expected a table") end
		for selk, sel in pairs(sels) do
			local ok
			for k,v in pairs(values) do 
				if strlower(k)==str then
					sels[selk] = k	-- overwrite with key (in case of case mismatches)
					ok = true
					break
				end
			end
			if not ok then
				usererr(info, inputpos, "'"..sel.."' - "..L["unknown selection"])
				return
			end
		end
		
		do_final(info, inputpos, tab, "set", unpack(t))
		
	
	elseif tab.type=="color" then
		------------ color --------------------------------------------
		error("TODO: color type")
		

	elseif tab.type=="keybinding" then
		------------ keybinding --------------------------------------------
		error("TODO: keybinding type")

	else
		err(info, inputpos, "unknown options table item type '"..tostring(tab.type).."'")
	end
end


-----------------------------------------------------------------------
-- HandleCommand(slashcmd, appName, input)
--
-- Call this from a chat command handler to parse the command input as operations on an aceoptions table
-- 
-- slashcmd (string) - the slash command WITHOUT leading slash (only used for error output)
-- appName (string) - the application name as given to AceConfigRegistry:RegisterOptionsTable()
-- input (string) -- the commandline input (as given by the WoW handler, i.e. without the command itself)

function lib:HandleCommand(slashcmd, appName, input)

	local optgetter = cfgreg:GetOptionsTable(appName)
	if not optgetter then
		error([[Usage: HandleCommand("slashcmd", "appName", "input"): 'appName' - no options table "]]..tostring(appName)..[[" has been registered]], 2)
	end
	local options = assert( optgetter("cmd", MAJOR) )
	
	local info = {   -- Don't try to recycle this, it gets handed off to callbacks and whatnot
		[0] = slashcmd,
		appName = appName,
		options = options,
		input = input,
		self = self,
		handler = self
	}
	
	handle(info, 1, options, 0)  -- (info, inputpos, table, depth)
end



-----------------------------------------------------------------------
-- CreateChatCommand(slashcmd, appName)
--
-- Utility function to create a slash command handler.
-- Also registers tab completion with AceTab
-- 
-- slashcmd (string) - the slash command WITHOUT leading slash (only used for error output)
-- appName (string) - the application name as given to AceConfigRegistry:RegisterOptionsTable()

function lib:CreateChatCommand(slashcmd, appName)
	if not AceConsole then
		AceConsole = LibStub(AceConsoleName)
	end
	AceConsole.RegisterChatCommand(self, slashcmd, function(input)
				lib.HandleCommand(self, slashcmd, appName, input)	-- upgradable
		end,
	true)
end
