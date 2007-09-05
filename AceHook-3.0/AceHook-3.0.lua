--[[ $Id$ ]]
local ACEHOOK_MAJOR, ACEHOOK_MINOR = "AceHook-3.0", 0
local AceHook, oldminor = LibStub:NewLibrary(ACEHOOK_MAJOR, ACEHOOK_MINOR)

if not AceHook then 
	return
elseif not oldminor then  -- This is the first version
	-- Any new members to AceHook should be added outside this if.
	AceHook.embeded = {} -- what objects embed this lib
end

-- upgrading of embeded is done at the bottom of the file

local function safecall( func, ... )
	local success, err = pcall(func,...)
	if success then return err end
	if not err:find("%.lua:%d+:") then err = (debugstack():match("\n(.-: )in.-\n") or "") .. err end 
	geterrorhandler()(err)
end

local mixins = {
	"Hook", "SecureHook",
	"HookScript", "SecureHookScript",
	"UnhookAll",
} 

-- AceHook:Embed( target )
-- target (object) - target object to embed AceHook in
--
-- Embeds AceEevent into the target object making the functions from the mixins list available on target:..
function AceHook:Embed( target )
	for k, v in pairs( mixins ) do
		target[v] = self[v]
	end
	self.embeded[target] = true
end

-- AceHook:OnEmbedDisable( target )
-- target (object) - target object that is being disabled
--
-- Unhooks all hooks when the target disables.
-- this method should be called by the target manually or by an addon framework
function AceHook:OnEmbedDisable( target )
	target:UnhookAll()
end


function AceHook:Hook( ... )
end

function AceHook:SecureHook( ... )
end

function AceHook:HookScript( ... )
end

function AceHook:SecureHookScript( ... )
end

function AceHook:UnhookAll()
end

--- Upgrade our old embeded
for target, v in pairs( AceHook.embeded ) do
	AceHook:Embed( target )
end
