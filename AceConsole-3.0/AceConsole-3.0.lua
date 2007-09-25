--[[ $Id$ ]]
local MAJOR,MINOR = "AceConsole-3.0", 0

local AceConsole, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not AceConsole then 
	return -- no upgrade needed
end

AceConsole.embeds = AceConsole.embeds or {}
AceConsole.commands = AceConsole.commands or {}

--[[ TODO
	- Check first argument of Print function to see if it is a ChatFrame, if so output to that chatframe or maybe even better?
		Check if .AddMessage exists and call that on first object?
	- OnEmbedDisable -> Unregister chatcommands? or Soft Disable them and Enable them OnEmbedEnable.
		This means keeping a proper registry of commands and enable/disable them where needed.
--]]

-- AceConsole:Print( ... )
--
-- Print to ChatFrame
function AceConsole:Print(...)
	local text
	if self ~= AceConsole then
		text = tostring( self )..": "
	end
	for i=1, select("#", ...) do
		text = text .. tostring( select( i, ...) ) .." "
	end
	-- TODO: Should check if the first argument is a chatframe and output to there if needed
	DEFAULT_CHAT_FRAME:AddMessage( text )
end

-- AceConsole:RegisterChatCommand(. command, func )
--
-- Register a simple chat command
function AceConsole:RegisterChatCommand( command, func )
	local name = "ACECONSOLE_"..command:upper()
	if SlashCmdList[name] then
		error( "Chat Command '"..command.."' already exists", 2 )
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
