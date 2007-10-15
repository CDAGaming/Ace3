local AceGUI = LibStub("AceGUI-3.0")

local function print(a)
	DEFAULT_CHAT_FRAME:AddMessage(a)
end


local function ZOMGConfig(widget, event)
	AceGUI:Release(widget.userdata.parent)
	
	local f = AceGUI:Create("Frame")
	
	f:SetCallback("OnClose",function(widget, event) print("Closing") AceGUI:Release(widget) end )
	f:SetTitle("ZOMG Config!")
	f:SetStatusText("Status Bar")
	f:SetLayout("Fill")
	
	local maingroup = AceGUI:Create("DropdownGroup")
	maingroup:SetLayout("Fill")
	maingroup:SetGroupList({Addons = "Addons !!", Zomg = "Zomg Addons"})
	maingroup:SetGroup("Addons")
	maingroup:SetTitle("")
	
	f:AddChild(maingroup)
	
	local tree = { "A", "B", "C", "D", B = { "B1", "B2", B1 = { "B11", "B12" } }, C = { "C1", "C2", C1 = { "C11", "C12" } } }
	local text = { A = "Option 1", B = "Option 2", C = "Option 3", D = "Option 4", J = "Option 10", K = "Option 11", L = "Option 12", 
					B1 = "Option 2-1", B2 = "Option 2-2", B11 = "Option 2-1-1", B12 = "Option 2-1-2",
					C1 = "Option 3-1", C2 = "Option 3-2", C11 = "Option 3-1-1", C12 = "Option 3-1-2" }
	local t = AceGUI:Create("TreeGroup")
	t:SetLayout("Fill")
	t:SetTree(tree, text)
	maingroup:AddChild(t)
	
	local tab = AceGUI:Create("TabGroup")
	tab:SetTabs({"A","B","C","D"},{A="Yay",B="We",C="Have",D="Tabs"})
	tab:SetLayout("Fill")
	tab:SelectTab(1)
	t:AddChild(tab)
	
	local component = AceGUI:Create("DropdownGroup")
	component:SetLayout("Fill")
	component:SetGroupList({Blah = "Blah", Splat = "Splat"})
	component:SetGroup("Blah")
	component:SetTitle("Choose Componet")
	
	tab:AddChild(component)
	
	local more = AceGUI:Create("DropdownGroup")
	more:SetLayout("Fill")
	more:SetGroupList({ButWait = "But Wait!", More = "Theres More"})
	more:SetGroup("More")
	more:SetTitle("And More!")
	
	component:AddChild(more)
	
	local sf = AceGUI:Create("ScrollFrame")
	sf:SetLayout("Flow")
	more:AddChild(sf)
	local stuff = AceGUI:Create("Heading")
	stuff:SetText("Omg Stuff Here")
	stuff.width = "fill"
	sf:AddChild(stuff)
	
	for i = 1, 10 do
		local edit = AceGUI:Create("EditBox")
		edit:SetText("")
		edit:SetWidth(200)
		edit:SetLabel("Stuff!")
		edit:SetCallback("OnEnterPressed",function(widget,event,text) widget:SetLabel(text) end )
		edit:SetCallback("OnTextChanged",function(widget,event,text) print(text) end )
		sf:AddChild(edit)
	end
	
	f:Show()
end

local function GroupA(content)
	content:ReleaseChildren()
	
	local sf = AceGUI:Create("ScrollFrame")
	sf:SetLayout("Flow")
	
	local edit = AceGUI:Create("EditBox")
	edit:SetText("Testing")
	edit:SetWidth(200)
	edit:SetLabel("Group A Option")
	edit:SetCallback("OnEnterPressed",function(widget,event,text) widget:SetLabel(text) end )
	edit:SetCallback("OnTextChanged",function(widget,event,text) print(text) end )
	sf:AddChild(edit)
	
	local slider = AceGUI:Create("Slider")
	slider:SetLabel("Group A Slider")
	slider:SetSliderValues(0,1000,5)
	slider:SetDisabled(false)
	sf:AddChild(slider)
	
	local zomg = AceGUI:Create("Button")
	zomg.userdata.parent = content.userdata.parent
	zomg:SetText("Zomg!")
	zomg:SetCallback("OnClick", ZOMGConfig)
	sf:AddChild(zomg)
	
	local heading1 = AceGUI:Create("Heading")
	heading1:SetText("Heading 1")
	heading1.width = "fill"
	sf:AddChild(heading1)
	
	for i = 1, 5 do
		local radio = AceGUI:Create("CheckBox")
		radio:SetLabel("Test Check "..i)
		radio:SetCallback("OnValueChanged",function(widget,event,value) print(value and "Check "..i.." Checked" or "Check "..i.." Unchecked") end )
		sf:AddChild(radio)
	end
	
	local heading2 = AceGUI:Create("Heading")
	heading2:SetText("Heading 2")
	heading2.width = "fill"
	sf:AddChild(heading2)
	
	for i = 1, 5 do
		local radio = AceGUI:Create("CheckBox")
		radio:SetLabel("Test Check "..i+5)
		radio:SetCallback("OnValueChanged",function(widget,event,value) print(value and "Check "..i.." Checked" or "Check "..i.." Unchecked") end )
		sf:AddChild(radio)
	end
	
	local heading1 = AceGUI:Create("Heading")
	heading1:SetText("Heading 1")
	heading1.width = "fill"
	sf:AddChild(heading1)
	
    for i = 1, 5 do
	    local radio = AceGUI:Create("CheckBox")
	    radio:SetLabel("Test Check "..i)
	    radio:SetCallback("OnValueChanged",function(widget,event,value) print(value and "Check "..i.." Checked" or "Check "..i.." Unchecked") end )
	    sf:AddChild(radio)
	end
	
	local heading2 = AceGUI:Create("Heading")
	heading2:SetText("Heading 2")
	heading2.width = "fill"
	sf:AddChild(heading2)
	
    for i = 1, 5 do
	    local radio = AceGUI:Create("CheckBox")
	    radio:SetLabel("Test Check "..i+5)
	    radio:SetCallback("OnValueChanged",function(widget,event,value) print(value and "Check "..i.." Checked" or "Check "..i.." Unchecked") end )
	    sf:AddChild(radio)
	end
    
	content:AddChild(sf)
end

local function GroupB(content)
	content:ReleaseChildren()
	local sf = AceGUI:Create("ScrollFrame")
	sf:SetLayout("Flow")
	
 	local check = AceGUI:Create("CheckBox")
	check:SetLabel("Group B Checkbox")
	check:SetCallback("OnValueChanged",function(widget,event,value) print(value and "Checked" or "Unchecked") end )
	
	local dropdown = AceGUI:Create("Dropdown")
	dropdown:SetText("Test")
	dropdown:SetLabel("Group B Dropdown")
	dropdown.list = {"Test","Test2"}
	dropdown:SetCallback("OnValueChanged",function(widget,event,value) print(value) end )
	
	sf:AddChild(check)
	sf:AddChild(dropdown)
	content:AddChild(sf)
end

local function OtherGroup(content)
	content:ReleaseChildren()
	
	local sf = AceGUI:Create("ScrollFrame")
	sf:SetLayout("Flow")
	
 	local check = AceGUI:Create("CheckBox")
	check:SetLabel("Test Check")
	check:SetCallback("OnValueChanged",function(widget,event,value) print(value and "CheckButton Checked" or "CheckButton Unchecked") end )
	
	sf:AddChild(check)
	
	local inline = AceGUI:Create("InlineGroup")
	inline:SetLayout("Flow")
	inline:SetTitle("Inline Group")
	inline.width = "fill"

	local heading1 = AceGUI:Create("Heading")
	heading1:SetText("Heading 1")
	heading1.width = "fill"
	inline:AddChild(heading1)
	
	for i = 1, 10 do
		local radio = AceGUI:Create("CheckBox")
		radio:SetLabel("Test Radio "..i)
		radio:SetCallback("OnValueChanged",function(widget,event,value) print(value and "Radio "..i.." Checked" or "Radio "..i.." Unchecked") end )
		radio:SetType("radio")
		inline:AddChild(radio)
	end
	
	local heading2 = AceGUI:Create("Heading")
	heading2:SetText("Heading 2")
	heading2.width = "fill"
	inline:AddChild(heading2)
	
	for i = 1, 10 do
		local radio = AceGUI:Create("CheckBox")
		radio:SetLabel("Test Radio "..i)
		radio:SetCallback("OnValueChanged",function(widget,event,value) print(value and "Radio "..i.." Checked" or "Radio "..i.." Unchecked") end )
		radio:SetType("radio")
		inline:AddChild(radio)
	end
	
	
	sf:AddChild(inline)
	content:AddChild(sf)
end

local function SelectGroup(widget, event, value)
	if value == "A" then
		GroupA(widget)
	elseif value == "B" then
	 GroupB(widget)
	else
		OtherGroup(widget)
	end
end


local function TreeWindow(content)
	content:ReleaseChildren()
	
	local tree = { 
			{ 
				value = "A",
				text = "Alpha"
			},
			{
				value = "B",
				text = "Bravo",
				children = {
					{ 
						value = "C", 
						text = "Charlie",
					},
					{
						value = "D",	
						text = "Delta",
						children = { 
							{ 
								value = "E",
								text = "Echo",
							} 
						} 
					},
				}
			},
			{ 
				value = "F", 
				text = "Foxtrot",
			},
		}
	local t = AceGUI:Create("TreeGroup")
	t:SetLayout("Fill")
	t:SetTree(tree)
	t:SetCallback("OnGroupSelected", SelectGroup )
	content:AddChild(t)
	SelectGroup(t,"OnGroupSelected","A")
	
end

local function TabWindow(content)
	content:ReleaseChildren()
	local tab = AceGUI:Create("TabGroup")
	tab.userdata.parent = content.userdata.parent
	tab:SetTabs({"A","B","C","D"},{A="Alpha",B="Bravo",C="Charlie",D="Deltaaaaaaaaaaaaaa"})
	tab:SetTitle("Tab Group")
	tab:SetLayout("Fill")
	tab:SetCallback("OnGroupSelected",SelectGroup)
	tab:SelectTab(1)
	content:AddChild(tab)
	
end


function TestFrame()
	local f = AceGUI:Create("Frame")
	f:SetCallback("OnClose",function(widget, event) print("Closing") AceGUI:Release(widget) end )
	f:SetTitle("AceGUI Prototype")
	f:SetStatusText("Root Frame Status Bar")
	f:SetLayout("Fill")
	
	local maingroup = AceGUI:Create("DropdownGroup")
	maingroup.userdata.parent = f
	maingroup:SetLayout("Fill")
	maingroup:SetGroupList({Tab = "Tab Frame", Tree = "Tree Frame"})
	maingroup:SetGroup("Tab")
	maingroup:SetTitle("Select Group Type")
	maingroup:SetCallback("OnGroupSelected", function(widget, event, value)
		widget:ReleaseChildren()
		if value == "Tab" then
			TabWindow(widget)
		else
			TreeWindow(widget)
		end
	end )
	
	TabWindow(maingroup)
	f:AddChild(maingroup)
	
	
	f:Show()
end
--TestFrame()
