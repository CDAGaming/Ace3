--[[ $Id$ ]]
local MAJOR,MINOR = "AceConsole-3.0", 0

local AceConsole, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not AceConsole then 
	return -- no upgrade needed
end

AceConsole.embeds = AceConsole.embeds or {}
AceConsole.commands = AceConsole.commands or {}

--[[ TODO
	- OnEmbedDisable -> Unregister chatcommands? or Soft Disable them and Enable them OnEmbedEnable.
		This means keeping a proper registry of commands and enable/disable them where needed.
		- Mikk: I say no. How the heck to you re-enable with the command gone?
--]]

-- AceConsole:Print( [chatframe,] ... )
--
-- Print to DEFAULT_CHAT_FRAME or given chatframe (anything with an .AddMessage member)
function AceConsole:Print(...)
	local text = ""
	if self ~= AceConsole then
		text = tostring( self )..": "
	end

	local frame = select(1, ...)
	if not frame.AddMessage then	-- Is first argument something with an .AddMessage member?
		frame=nil
	end
	
	for i=(frame and 2 or 1), select("#", ...) do
		text = text .. tostring( select( i, ...) ) .." "
	end
	(frame or DEFAULT_CHAT_FRAME):AddMessage( text )
end

-- AceConsole:RegisterChatCommand(. command, func )
--
-- Register a simple chat command
function AceConsole:RegisterChatCommand( command, func )
	local name = "ACECONSOLE_"..command:upper()
	if SlashCmdList[name] then
		geterrorhandler()(tostring(self) ": Chat Command '"..command.."' already exists, will not overwrite.")
		return
	end
	if type( func ) == "string" then
		SlashCmdList[name] = function(input)
			self[func](self, input)
		end
	else
		SlashCmdList[name] = func
	end
	setglobal("SLASH_"..name.."1", "/"..command:lower())
	AceConsole.commands[command] = name
end

-- AceConsole:UnregisterChatCommand( command )
-- 
-- Unregister a chatcommand
function AceConsole:UnregisterChatCommand( command )
	local name = AceConsole.commands[command]
	if name then
		SlashCmdList[name] = nil
		setglobal("SLASH_"..name.."1", nil)
		AceConsole.commands[command] = nil
	end
end

--- embedding and embed handling

local mixins = {
	"Print",
	"RegisterChatCommand", 
	"UnregisterChatCommand",
} 

-- AceConsole:Embed( target )
-- target (object) - target object to embed AceBucket in
--
-- Embeds AceConsole into the target object making the functions from the mixins list available on target:..
function AceConsole:Embed( target )
	for _, v in pairs( mixins ) do
		target[v] = self[v]
	end
	self.embeds[target] = true
end

for addon in pairs(AceConsole.embeds) do
	AceConsole:Embed(addon)
end
