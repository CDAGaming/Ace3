local AceGUI = LibStub("AceGUI-3.0")

local function print(a)
    DEFAULT_CHAT_FRAME:AddMessage(a)
end

function TestFrame()
    local f = AceGUI:Create("Frame")
    f:SetCallback("OnClose",function(widget, event) print("Closing") AceGUI:Release(widget) end )
    f:SetTitle("AceGUI Prototype")
    f:SetStatusText("Root Frame Status Bar")
    f:SetLayout("Fill")
    
	local t = AceGUI:Create("TreeView")
	t:SetLayout("Fill")
	
	local tree = { "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", B = { "B1", "B2", B1 = { "B11", "B12" } } }
	local text = { A = "Option 1", B = "Option 2", C = "Option 3", D = "Option 4", E = "Option 5", F = "Option 6", G = "Option 7", H = "Option 8", I = "Option 9",
					J = "Option 10", K = "Option 11", L = "Option 12", B1 = "Option 2-1", B2 = "Option 2-2", B11 = "Option 2-1-1", B12 = "Option 2-1-2" }
	t:SetTree(tree, text)
	t:SetCallback("OnGroupSelected", function(widget, event, value) print(value) end )
	local sf = AceGUI:Create("ScrollFrame")
	sf:SetLayout("List")
	f:AddChild(t)
	
	t:AddChild(sf)
	
    local c = AceGUI:Create("InlineGroup")
    c:SetTitle("Inline Group")
    c.width = "fill"
    c:SetLayout("Fill")
    c.frame:SetHeight(150)
    sf:AddChild(c)
    
    local c2 = AceGUI:Create("SelectGroup")
    c2:SetLayout("List")
    c2:SetGroupList({A ="Group A", B = "Group B"})
	c2:SetGroup('A')
	local edit = AceGUI:Create("EditBox")
	edit:SetText("Raaa")
	edit:SetWidth(200)
	edit:SetLabel("Group A Option")
	edit:SetCallback("OnEnterPressed",function(widget,event,text) widget:SetLabel(text) end )
	edit:SetCallback("OnTextChanged",function(widget,event,text) print(text) end )
	c2:AddChild(edit)
    c2:SetTitle("Selection Group")
    c2:SetCallback("OnGroupSelected", function(widget, event, value) 
        c2:ReleaseChildren()
        if value == "A" then
            local edit = AceGUI:Create("EditBox")
            edit:SetText("Testing")
            edit:SetWidth(200)
            edit:SetLabel("Group A Option")
            edit:SetCallback("OnEnterPressed",function(widget,event,text) widget:SetLabel(text) end )
            edit:SetCallback("OnTextChanged",function(widget,event,text) print(text) end )
            c2:AddChild(edit)
        elseif value == "B" then
            local check = AceGUI:Create("CheckBox")
            check:SetLabel("Group B Checkbox")
            check:SetCallback("OnValueChanged",function(widget,event,value) print(value and "Checked" or "Unchecked") end )
            check:SetCallback("OnEnter",function(widget,event,value) f:SetStatusText("Help Text For Test Check") end )
            check:SetCallback("OnLeave",function(widget,event,value) f:SetStatusText("") end )
            
            local dropdown = AceGUI:Create("Dropdown")
            dropdown:SetText("Test")
            dropdown.list = {"Test","Test2"}
            dropdown:SetCallback("OnValueChanged",function(widget,event,value) print(value) end )

            c2:AddChild(check)
            c2:AddChild(dropdown)
        end
    end )
    c2.width = "fill"
    c2.frame:SetHeight(100)
    c:AddChild(c2)
    
    local c3 = AceGUI:Create("InlineGroup")
    c3:SetTitle("Another Inline Group")
    c3:SetLayout("List")
    c3.width = "fill"
    c3.frame:SetHeight(400)
    sf:AddChild(c3)
    
    local edit = AceGUI:Create("EditBox")
    edit:SetText("Testing")
    edit:SetWidth(200)
    edit:SetLabel("Test")
    edit:SetCallback("OnEnterPressed",function(widget,event,text) widget:SetLabel(text) end )
    edit:SetCallback("OnTextChanged",function(widget,event,text) print(text) end )
    c3:AddChild(edit)
    
    local check = AceGUI:Create("CheckBox")
    check:SetLabel("Test Check")
    check:SetCallback("OnValueChanged",function(widget,event,value) print(value and "Checked" or "Unchecked") end )
    check:SetCallback("OnEnter",function(widget,event,value) f:SetStatusText("Help Text For Test Check") end )
    check:SetCallback("OnLeave",function(widget,event,value) f:SetStatusText("") end )
    
    local radio = AceGUI:Create("CheckBox")
    radio:SetLabel("Test Radio")
    radio:SetCallback("OnValueChanged",function(widget,event,value) print(value and "Checked" or "Unchecked") end )
    radio:SetCallback("OnEnter",function(widget,event,value) f:SetStatusText("Help Text For Test Check") end )
    radio:SetCallback("OnLeave",function(widget,event,value) f:SetStatusText("") end )
    radio:SetType("radio")
    
    local dropdown = AceGUI:Create("Dropdown")
    dropdown:SetValue("Test")
    dropdown.list = {"Test","Test2"}
    dropdown:SetLabel("Test Dropdown")
    dropdown:SetCallback("OnValueChanged",function(widget,event,value) print(value) end )

	local button = AceGUI:Create("Button")
	button:SetText("Button!")
	
    c3:AddChild(check)
    c3:AddChild(radio)
    c3:AddChild(dropdown)
	c3:AddChild(button)
	
	f:Show()
end

TestFrame()