--[[
AceConfigDialog-3.0

]]

local MAJOR, MINOR = "AceConfigDialog-3.0", 0
local lib = LibStub:NewLibrary(MAJOR, MINOR)

if not lib then return end

lib.OpenFrames = lib.OpenFrames or {}

local gui = LibStub("AceGUI-3.0")
local reg = LibStub("AceConfigRegistry-3.0")

--[[
Group Types
  Tree 	- All Descendant Groups will all become nodes on the tree, direct child options will appear above the tree
  		- Descendant Groups with inline=true and thier children will not become nodes
  		
  Tab	- Direct Child Groups will become tabs, direct child options will appear above the tab control
  		- Grandchild groups will default to inline unless specified otherwise
  
  Select- Same as Tab but with entries in a dropdown rather than tabs
  
  
  Inline Groups
  	- Will not become nodes of a select group, they will be effectivly part of thier parent group seperated by a border
  	- If declared on a direct child of a root node of a select group, they will appear above the group container control
  	- When a group is displayed inline, all descendants will also be inline members of the group

]]

-- Recycling functions
local new, del
do
	local pool = {}
	function new()
		return tremove(pool) or {}
	end
	function copy(t)
		local c = new()
		for k, v in pairs(t) do
			c[k] = v
		end
		return c
	end
	function del(t)
		for k in pairs(t) do
			t[k] = nil
		end	
		tinsert(pool,t)
	end
end

-- picks the first non-nil value and returns it
local function pickfirstset(...)	
  for i=1,select("#",...) do
    if select(i,...)~=nil then
      return select(i,...)
    end
  end
end

local function AceOptions3MouseOver(widget, event)
	--show a tooltip/set the status bar to the desc text
	widget.userdata.rootframe:SetStatusText(widget.userdata.desc)
end

local function AceOptions3ActivateControl(widget, event, ...)
	--This function will call the set / execute handler for the widget
	--widget.userdata contains the needed info
end

local function AceOptions3Get(option)
	--Call the get function for the option
end

--TODO: set an on release handler to del() the tabs
local function AceOptions3BuildTabs(group)
	local tabs = new()
	local text = new()
	
	for k, v in pairs(group.args) do
		if v.type == "group" then
			local inline = pickfirstset(v.dialogInline,v.guiInline,v.inline, false)
			if not inline then
				tinsert(tabs, k)
				text[k] = v.name
			end
		end
	end
	
	return tabs, text

end

local function AceOptions3BuildSubTree(group, tree)
	for k, v in pairs(group.args) do
		if v.type == "group" then
			local inline = pickfirstset(v.dialogInline,v.guiInline,v.inline, false)
			if not inline then
				local entry = new()
				entry.value = k
				entry.text = v.name
				if not tree.children then tree.children = new() end
				tinsert(tree.children,entry)
				AceOptions3BuildSubTree(v,entry)
			end
		end
	end
end

--TODO: set an on release handler to del() the tree
local function AceOptions3BuildTree(group)
	local tree = new()
	
	for k, v in pairs(group.args) do
		if v.type == "group" then
			local inline = pickfirstset(v.dialogInline,v.guiInline,v.inline, false)
			if not inline then
				local entry = new()
				entry.value = k
				entry.text = v.name
				tinsert(tree,entry)
				AceOptions3BuildSubTree(v,entry)
			end
		end
	end
	
	return tree
end

local function AceOptions3InjectInfo(control, options, option, path, rootframe)
		local user = control.userdata
		for i,key in ipairs(path) do
			user[i] = key
		end
		user.rootframe = rootframe
		user.option = option
		user.options = options
		user.path = copy(path)
		control:SetCallback("OnRelease", AceOptionsClearUserData)
end


--[[
	options - root of the options table being fed
	container - widget that controls will be placed in
	rootframe - Frame object the options are in
	path - table with the keys to get to the group being fed
--]]

local function FeedOptions(options,container,rootframe,path,group,inline)
	container:ReleaseChildren()
	local scroll = gui:Create("ScrollFrame")
	scroll:SetLayout("flow")
	container:SetLayout("fill")
	container:AddChild(scroll)
	
	
	for k, v in pairs(group.args) do
		if v.type == "group" then
			if inline or pickfirstset(v.dialogInline,v.guiInline,v.inline, false) then
				--Inline group
				local GroupContainer = gui:Create("InlineGroup")
				GroupContainer:SetTitle(v.name or "")
				GroupContainer.width = "fill"
				GroupContainer:SetLayout("flow")
				scroll:AddChild(GroupContainer)
				tinsert(path, k)
				FeedGroup(options,GroupContainer,rootframe,path)
				tremove(path)
			end
		else
			--Control to feed
			local control
			if v.type == "execute" then
				control = gui:Create("Button")
				control:SetText(v.name)
				control:SetCallback("OnClick",AceOptions3ActiveControl)
				
			elseif v.type == "input" then
				control = gui:Create("EditBox")
				control:SetLabel(v.name)
				
			elseif v.type == "toggle" then
				control = gui:Create("CheckBox")
				control:SetLabel(v.name)
				
			elseif v.type == "range" then
				control = gui:Create("Slider")
				control:SetLabel(v.name)
				
			elseif v.type == "select" then
				control = gui:Create("DropDown")
				control:SetLabel(v.name)
				
			elseif v.type == "multiselect" then
				--control = gui:Create("")
				
			elseif v.type == "color" then
				--control = gui:Create("")
				
			elseif v.type == "keybinding" then
				--control = gui:Create("")
				
			end

			--Common Init
			if control then
				AceOptions3InjectInfo(control, options, v, path, rootframe)
				control:SetCallback("OnEnter",AceOptions3MouseOver)
				scroll:AddChild(control)
			end				
		end
	end
end

-- ... is the path up the tree to the current node
local function AceOptions3GroupSelected(widget, event, value, ...)

	
	local user = widget.userdata
	
	local options = user.options
	local option = user.option
	local path = user.path
	local rootframe = user.rootframe
	
	local feedpath = new()
	for i, v in ipairs(path) do
		feedpath[i] = v
	end
	
	for i = 1, select('#',...) do
		tinsert(feedpath, select(i,...))
	end
	
	tinsert(feedpath, value)

	local group = options
	for i, v in ipairs(feedpath) do
		group = options.args[v]
	end	
	FeedOptions(options,widget,rootframe,feedpath,group)
	
	del(feedpath)
end

local function AceOptionsClearUserData(widget, event)
	local user = widget.userdata
	
	if user.path then
		del(user.path)
	end	
end


local function FeedInlineGroup(options,container,rootframe,path,group)
	local GroupContainer = gui:Create("InlineGroup")
	GroupContainer:SetTitle(v.name or "")
	GroupContainer.width = "fill"
	GroupContainer:SetLayout("flow")
	container:AddChild(GroupContainer)
	tinsert(path, k)
	FeedOptions(options,GroupContainer,rootframe,path,group,true)
	tremove(path)
end

--[[
This function will feed one group, and any inline child groups into the given container
Select Groups will only have the selection control (tree, tabs, dropdown) fed in
and have a group selected, this event will trigger the feeding of child groups
--]]
function lib:FeedGroup(options,container,rootframe,path)
	local group = options
	--follow the path to get to the curent group
	local inline
	
	for i, v in ipairs(path) do
		if group.args[v] then
			group = group.args[v]
		end
		inline = inline or pickfirstset(v.dialogInline,v.guiInline,v.inline, false)
	end
	
	if inline then
		local scroll = gui:Create("ScrollFrame")
		scroll:SetLayout("flow")
		container:SetLayout("fill")
		container:AddChild(scroll)
		FeedOptions(options,scroll,rootframe,path,group)
	else
		local grouptype = group.childGroups
		
		if grouptype == "tab" then
			local tab = gui:Create("TabGroup")
			AceOptions3InjectInfo(tab, options, group, path, rootframe)
			container:SetLayout("fill")
			tab:SetTabs(AceOptions3BuildTabs(group))
			tab:SetCallback("OnGroupSelected", AceOptions3GroupSelected)
			
			container:AddChild(tab)
			
		elseif grouptype == "select" then
			local select = gui:Create("DropdownGroup")
			AceOptions3InjectInfo(select, options, group, path, rootframe)
			select:SetCallback("OnGroupSelected", AceOptions3GroupSelected)
			container:SetLayout("fill")
			container:AddChild(select)
		else
			local tree = gui:Create("TreeGroup")
			AceOptions3InjectInfo(tree, options, group, path, rootframe)
			container:SetLayout("fill")
			tree:SetTree(AceOptions3BuildTree(group))
			tree:SetCallback("OnGroupSelected", AceOptions3GroupSelected)

			container:AddChild(tree)
		end
	end

end 

function lib:Open(appName)
	
	local options = reg:GetOptionsTable(appName)("dialog", MAJOR)
	
	local f
	if not self.OpenFrames[appName] then
		f = gui:Create("Frame")
		self.OpenFrames[appName] = f
	else
		f = self.OpenFrames[appName]
	end
	f:ReleaseChildren()
	f:SetTitle(options.name or "")
	f:SetLayout("fill")

	local path = new()
	
	self:FeedGroup(options,f,f,path)
	f:Show()
	del(path)


	

end