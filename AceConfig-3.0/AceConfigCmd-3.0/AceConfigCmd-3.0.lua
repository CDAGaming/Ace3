
--[[
AceConfigCmd-3.0

Handles commandline optionstable access

REQUIRES: AceConsole-3.0 (loaded on demand)

]]


local MAJOR, MINOR = "AceConfigCmd-3.0", 0
local lib = LibStub:NewLibrary(MAJOR, MINOR)

if not lib then return end

local cfgreg = LibStub("AceConfigRegistry-3.0")
local con = LibStub("AceConsole-3.0")



local function pickfirstset(...)	-- picks the first non-nil value and returns it
	for i=1,select("#",...) do
		if select(i,...)~=nil then
			return select(i,...)
		end
	end
end


local function err(info,inputpos,msg )
	local cmdstr=" "..strsub(info.input, 1, inputpos-1)
	error(MAJOR..": /" ..info.slashcmd ..cmdstr ..": "..(msg or "malformed options table"), 2)
end

local function usererr(info,inputpos,msg )
	local cmdstr=" "..strsub(info.input, 1, inputpos-1)
	(SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME):AddMessage("/" ..info.slashcmd ..cmdstr ..": "..(msg or "malformed options table"))
end


function lib:ShowHelp(slashcmd, options)
	error("TODO: implement")
end


local function callmethod(info, inputpos, tab, methodtype, ...)
	local method = info[methodtype]==nil
	if not method then
		err(info, inputpos, "'"..methodtype.."': not set")
	end

	info.arg = tab.arg

	if type(method)=="function" then
		method(info, ...)
	elseif type(method)=="string" then
		if type(info.handler[method])~="function" then
			err(info, inputpos, "'"..methodtype.."': '"..method.."' is not a member function of "..tostring(info.handler))
		end
		info.handler[method]
	
	if 
	
	
end


local function handle(info, inputpos, depth, tab)

	if not(type(tab)=="table" and type(tab.type)=="string") err(info,inputpos) end

	-------------------------------------------------------------------
	-- Grab hold of handler,set,get,func if set (and remember old ones)
	-- For method names: we do NOT validate if they're correct at this stage, the handler may change before they're actually used!
	
	local oldhandler,oldhandler_at = info.handler,info.handler_at
	if tab.handler then
		if not(type(tab.handler)=="table") then err(info, inputpos, "'handler' - expected a table") end
		info.handler = tab.handler
		info.handler_at = depth
	end

	local oldset,oldset_at = info.set,info.set_at
	if tab.set then
		if not(type(tab.set)=="function" or type(tab.set)=="string") then err(info, inputpos, "'set' - expected a function or string") end
		info.set,info.set_at = tab.set,depth
	end
	
	local oldget,oldget_at = info.get,info.get_at
	if tab.get then
		if not(type(tab.get)=="function" or type(tab.get)=="string") then err(info, inputpos, "'get' - expected a function or string") end
		info.get,info.get_at = tab.get,depth
	end

	local oldfunc,oldfunc_at = info.func,info.func_at
	if tab.func then
		if not(type(tab.func)=="function" or type(tab.func)=="string") then err(info, inputpos, "'func' - expected a function or string") end
		info.func,info.func_at = tab.func,depth
	end
	
	local oldvalidate,oldvalidate_at = info.validate,info.validate_at
	if tab.validate then
		if not(type(tab.validate)=="function" or type(tab.validate)=="string") then err(info, inputpos, "'validate' - expected a function or string") end
		info.validate,info.validate_at = tab.validate,depth
	end
	
	
	-------------------------------------------------------------------
	-- Act according to .type of this table
		
	if tab.type=="group" then
		------------ group --------------------------------------------
		
		if not(type(tab.args)=="table") then err(info, inputpos) end
		
		-- grab next arg from input
		local arg,nextpos = con:GetArgs(info.input, 1, inputpos)
		if not arg then
			lib:ShowHelp(info.slashcmd, tab)
			return
		end
		
		-- loop .args and try to find a key with a matching name
		for k,v in pairs(tab.args) do
			if not(type(k)=="string" and type(v)=="table" and type(v.type)=="string") err(info,inputpos, "options table child '"..tostring(k).."' is malformed") end

			-- is this child an inline group? if so, traverse into it
			if v.type=="group" and pickfirstset(v.cmdInline, v.inline, false) then
				info[depth+1] = k
				if(handle(info, inputpos, depth+1, v)==false) then
					info[depth+1] = nil
					-- wasn't found in there, but that's ok, we just keep looking down here
				else
					return	-- done, name was found in inline group
				end
			end
			
			-- matching name?
			if strlower(arg)==strlower(k) then
				info[depth+1] = k
				return handle(info,nextpos,depth+1,v)
			end
		end
		
		-- no match - return false to indicate failure (and restore old infotable members)
		info.handler,info.handler_at = oldhandler,oldhandler_at
		info.set,info.set_at = oldset,oldset_at
		info.get,info.get_at = oldget,oldget_at
		info.func,info.func_at = oldfunc,oldfunc_at
		return false
		
		
	
	elseif tab.type=="execute" then
		------------ execute --------------------------------------------
		callmethod(info, inputpos, tab, "func")
		

	
	elseif tab.type=="input" then
		------------ input --------------------------------------------
		local str = strtrim(strsub(info.input, inputpos))
		
		local res = true
		if tab.pattern then
			res = not not strmatch(str, tab.pattern)
		end
		if res and info.validate then
			res = callmethod(info, inputpos, tab, "validate", str)
		end
		if not res then
			res = L["invalid input"]
		end
		if type(res)=="string" then
			usererr(info, inputpos, "'"..str.."' - "..res)
			return
		end
		
		
		
		callmethod(info, inputpos, tab, "set", str)
		

	
	elseif tab.type=="toggle" then
		------------ toggle --------------------------------------------
		local b
		local str = strtrim(strlower(strsub(info.input,inputpos)))
		if str=="" then
			b = not callmethod(info, inputpos, tab, "get")
		elseif str==L["on"] then
			b = true
		elseif str==L["off"] then
			b = false
		else
			usererr(info, inputpos, format(L["'%s' - expected 'on' or 'off', or no argument to toggle"], str))
		end
		
		callmethod(info, inputpos, tab, "set", b)
		

	elseif tab.type=="range" then
		------------ range --------------------------------------------
		local v = tonumber(strsub(info.input,inputpos))
		if not v then
			con:Print()

	elseif tab.type=="select" then
		------------ select --------------------------------------------
		

	elseif tab.type=="multiselect" then
		------------ multiselect --------------------------------------------
		

	elseif tab.type=="color" then
		------------ color --------------------------------------------
		

	elseif tab.type=="keybinding" then
		------------ keybinding --------------------------------------------
		

	else
		err(info, inputpos, "unknown options table item type '"..tostring(tab.type).."'")
	end
end



function lib:HandleCommand(slashcmd, optionsName, input)

	local info = {   -- Recycle this and Mikk will laugh mercilessly at you, and probably scold you for taking shortcuts and not clearing leftover integer indices properly
		[0] = slashcmd,
		slashcmd = slashcmd,
		options = options,
		input = input,
		self = self,
		handler = self
	}
	
	handle(info, 1, 0, options)  -- (info, inputpos, depth, table)
end

