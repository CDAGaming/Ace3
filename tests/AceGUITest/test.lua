local AceGUI = LibStub("AceGUI-3.0")

local function print(a)
    DEFAULT_CHAT_FRAME:AddMessage(a)
end

local function GroupA(content)
	content:ReleaseChildren()
	
	local sf = AceGUI:Create("ScrollFrame")
	sf:SetLayout("List")
	
	local edit = AceGUI:Create("EditBox")
    edit:SetText("Testing")
    edit:SetWidth(200)
    edit:SetLabel("Group A Option")
    edit:SetCallback("OnEnterPressed",function(widget,event,text) widget:SetLabel(text) end )
    edit:SetCallback("OnTextChanged",function(widget,event,text) print(text) end )
    sf:AddChild(edit)
	content:AddChild(sf)
end

local function GroupB(content)
	content:ReleaseChildren()
	local sf = AceGUI:Create("ScrollFrame")
	sf:SetLayout("List")
	
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
	sf:SetLayout("List")
	
 	local check = AceGUI:Create("CheckBox")
    check:SetLabel("Test Check")
    check:SetCallback("OnValueChanged",function(widget,event,value) print(value and "CheckButton Checked" or "CheckButton Unchecked") end )
    
    sf:AddChild(check)
    
    local inline = AceGUI:Create("InlineGroup")
    inline:SetTitle("Inline Group")
	inline.width = "fill"

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
	
	local tree = { "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", B = { "B1", "B2", B1 = { "B11", "B12" } } }
	local text = { A = "Option 1", B = "Option 2", C = "Option 3", D = "Option 4", E = "Option 5", F = "Option 6", G = "Option 7", H = "Option 8", I = "Option 9",
					J = "Option 10", K = "Option 11", L = "Option 12", B1 = "Option 2-1", B2 = "Option 2-2", B11 = "Option 2-1-1", B12 = "Option 2-1-2" }
	local t = AceGUI:Create("TreeGroup")
	t:SetLayout("Fill")
	t:SetTree(tree, text)
	t:SetCallback("OnGroupSelected", SelectGroup )
	content:AddChild(t)
	SelectGroup(t,"OnGroupSelected","A")
	
end

local function TabWindow(content)
	content:ReleaseChildren()
	local tab = AceGUI:Create("TabGroup")
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
	maingroup:SetLayout("Fill")
	maingroup:SetGroupList({Tab = "Tab Frame", Tree = "Tree Frame"})
	maingroup:SetGroup("Tab")
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

TestFrame()