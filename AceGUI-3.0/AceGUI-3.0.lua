
local MAJOR, MINOR = "AceGUI-3.0", 0
local AceGUI, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not AceGUI then 
    return
end

local function safecall(func, ...)
	local success, err = pcall(func, ...)
	if success then return err end
	if not err:find("%.lua:%d+:") then err = (debugstack():match("\n(.-: )in.-\n") or "") .. err end 
	geterrorhandler()(err)
end

-- Recycling functions
local new, del
do
	local objPools = {}
	--Returns a new instance, if none are available either returns a new table or calls the given contructor
	function new(type,constructor,...)
	    if not type then
	        type = "table"
	    end
		if not objPools[type] then
			objPools[type] = {}
		end
		local newObj = tremove(objPools[type])
		if not newObj then
			if constructor then
				newObj = constructor(...)
			else
				newObj = {}
			end
		end
		return newObj
	end
	-- Releases an instace to the Pool
	function del(obj,type)
	    if not type then
	        type = "table"
	    end
		if not objPools[type] then
			objPools[type] = {}
		end
		tinsert(objPools[type],obj)
	end
end

-------------------
-- API Functions --
-------------------

-- Gets a widget Object
function AceGUI:Create(type)
    local reg = self.WidgetRegistry
    if reg[type] then
        local widget = new(type,reg[type])
        widget:Aquire()
        return widget
    end
end

-- Releases a widget Object
function AceGUI:Release(widget)
    if widget.ReleaseChildren then
        widget:ReleaseChildren()
    end
    for k in pairs(widget.userdata) do
        widget.userdata[k] = nil
    end
    for k in pairs(widget.events) do
        widget.userdata[k] = nil
    end
    widget:Release()
    del(widget,widget.type)
end


--------------------------
-- Widget Base Template --
--------------------------
do
    local function fixlevels(parent,...)
        local i = 1
        local child = select(i, ...)
        while child do
            child:SetFrameLevel(parent:GetFrameLevel()+1)
            fixlevels(child, child:GetChildren())
            i = i + 1
            child = select(i, ...)
        end
    end
    
    local WidgetBase = {
        SetParent = function(self, parent)
			local frame = self.frame
            frame:SetParent(nil)
            frame:SetParent(parent)
            fixlevels(frame,frame:GetChildren())
        end,
        
        SetCallback = function(self, name, func)
            if type(func) == "function" then
                self.events[name] = func
            end
        end,
        
        Fire = function(self, name,...)
            if self.events[name] then
                safecall(self.events[name], self, name, ...)
            end
        end
        
    }
    
    local WidgetContainerBase = {
        
        PauseLayout = function(self)
            self.LayoutPaused = true
        end,
        
        ResumeLayout = function(self)
            self.LayoutPaused = nil
        end,
        
        DoLayout = function(self)
            if self.LayoutFunc and not self.LayoutPaused then
                self.LayoutFunc(self.content, self.children)
            end
        end,
        
        AddChild = function(self, child)
            tinsert(self.children,child)
            child:SetParent(self.content)
            child.frame:Show()
            self:DoLayout()
        end,
        
        ReleaseChildren = function(self)
            local children = self.children
            for i = #children, 1, -1 do
                AceGUI:Release(children[i])
                children[i] = nil
            end
        end,
        
        SetLayout = function(self, Layout)
            self.LayoutFunc = AceGUI:GetLayout(Layout)
        end,
    }

    setmetatable(WidgetContainerBase,{__index=WidgetBase})

    --One of these function should be called on each Widget Instance as part of its creation process
    function AceGUI:RegisterAsContainer(widget)
        widget.children = {}
        widget.userdata = {}
        widget.events = {}
        widget.base = WidgetContainerBase
        setmetatable(widget,{__index=WidgetContainerBase})
		widget:SetLayout("List")
    end
    
    function AceGUI:RegisterAsWidget(widget)
        widget.userdata = {}
        widget.events = {}
        widget.base = WidgetBase
        setmetatable(widget,{__index=WidgetBase})
    end
end




------------------
-- Widget API   --
------------------
AceGUI.WidgetRegistry = {}
AceGUI.LayoutRegistry = {}
-- Registers a widget Constructor, this function returns a new instance of the Widget
function AceGUI:RegisterWidgetType(Name, Constructor)
    assert(type(Constructor) == "function")
	local reg = self.WidgetRegistry
    reg[Name] = Constructor
end
-- Registers a Layout Function
function AceGUI:RegisterLayout(Name, LayoutFunc)
	assert(type(Name) == "string" and type(LayoutFunc) == "function")
    local reg = self.LayoutRegistry
    reg[Name:upper()] = LayoutFunc
end

function AceGUI:GetLayout(Name)
	assert(type(Name) == "string")
    return self.LayoutRegistry[Name:upper()]
end

---------------------
-- Common Elements --
---------------------

local FrameBackdrop = {
	bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", 
	tile = true, tileSize = 32, edgeSize = 32, 
	insets = { left = 8, right = 8, top = 8, bottom = 8 }
}

local PaneBackdrop  = {

    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

local ControlBackdrop  = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

-------------
-- Widgets --
-------------
--[[
    Widgets must provide the following functions
        Aquire() - Called when the object is aquired, should set everything to a default hidden state
        Release() - Called when the object is Released, should remove any anchors and hide the Widget
        
    And the following members
        frame - the frame or derivitive object that will be treated as the widget for size and anchoring purposes
        type - the type of the object, same as the name given to :RegisterWidget()
        
    Widgets contain a table called userdata, this is a safe place to store data associated with the wigdet
    It will be cleared automatically when a widget is released
	Placing values directly into a widget object should be avoided
    
    If the Widget can act as a container for other Widgets the following
        content - frame or derivitive that children will be anchored to
        
    The Widget can supply the following Optional Members
    
    FrameLevelChanged(level) - Called when the frame level is changed
        .frame will already be set to the new level
        .content will be set to level+10 if the control is a container, use level to level+9 for your widgets elements if needed
        children will be set to .contents level + 1

]]

----------------
-- Main Frame --
----------------
--[[
    Events :
        OnClose

]]
do
    local function frameOnClose(this)
        local self = this.obj
        self:Fire("OnClose")
    end
    
    local function closeOnClick(this)
    	this.obj:Hide()
    end
    
    local function frameOnMouseDown(this)
    	this:GetParent():StartMoving()
    end
    
    local function frameOnMouseUp(this)
    	this:GetParent():StopMovingOrSizing()
    end
    
    local function sizerseOnMouseDown(this)
    	this:GetParent():StartSizing("BOTTOMRIGHT")
    end
    
    local function sizersOnMouseDown(this)
    	this:GetParent():StartSizing("BOTTOM")
    end
    
    local function sizereOnMouseDown(this)
    	this:GetParent():StartSizing("RIGHT")
    end
    
    local function sizerOnMouseUp(this)
    	this:GetParent():StopMovingOrSizing() 
    end

    local function SetTitle(self,title)
        self.titletext:SetText(title)
    end
    
    local function SetStatusText(self,text)
        self.statustext:SetText(text)
    end
    
    local function Hide(self)
        self.frame:Hide()
    end
	
	local function Show(self)
		self.frame:Show()
	end
    
    local function Aquire(self)

    end
    
    local function Release(self)
        self.frame:ClearAllPoints()
        self.frame:Hide()
    end
    

    local function Constructor()
        local frame = CreateFrame("Frame",nil,UIParent)
        local self = {}
        self.type = "Frame"
        
        self.Hide = Hide
		self.Show = Show
        self.SetTitle =  SetTitle
        self.Release = Release
        self.Aquire = Aquire
        self.SetStatusText = SetStatusText
        self.FrameLevelChanged = FrameLevelChanged
		
    	self.frame = frame
    	frame.obj = self
    	frame:SetWidth(700)
    	frame:SetHeight(500)
    	frame:SetPoint("CENTER",UIParent,"CENTER",0,0)
    	frame:EnableMouse()
    	frame:SetMovable(true)
    	frame:SetResizable(true)
    	frame:SetFrameStrata("DIALOG")
    	
    	frame:SetBackdrop(FrameBackdrop)
    	frame:SetBackdropColor(0,0,0,1)
    	frame:SetScript("OnHide",frameOnClose)
		frame:SetMinResize(600,200)
    	
    	local closebutton = CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
    	closebutton:SetScript("OnClick", closeOnClick)
    	closebutton:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-27,17)
    	closebutton:SetHeight(20)
    	closebutton:SetWidth(100)
    	closebutton:SetText("Close")
    	
    	self.closebutton = closebutton
    	closebutton.obj = self
    	
    	local statusbg = CreateFrame("Frame",nil,frame)
        statusbg:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",15,15)
        statusbg:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-132,15)
        statusbg:SetHeight(24)
        statusbg:SetBackdrop(PaneBackdrop)
        statusbg:SetBackdropColor(0.1,0.1,0.1)
        statusbg:SetBackdropBorderColor(0.4,0.4,0.4)
        self.statusbg = statusbg
    	
    	local statustext = statusbg:CreateFontString(nil,"OVERLAY","GameFontNormal")
        self.statustext = statustext
        statustext:SetPoint("TOPLEFT",statusbg,"TOPLEFT",7,-2)
        statustext:SetPoint("BOTTOMRIGHT",statusbg,"BOTTOMRIGHT",-7,2)
        statustext:SetHeight(20)
        statustext:SetJustifyH("LEFT")
        statustext:SetText("")
    	
    	local title = CreateFrame("Frame",nil,frame)
    	self.title = title
    	title:EnableMouse()
    	title:SetScript("OnMouseDown",frameOnMouseDown)
    	title:SetScript("OnMouseUp", frameOnMouseUp)
    	
    	
    	local titlebg = frame:CreateTexture(nil,"OVERLAY")
    	titlebg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    	titlebg:SetTexCoord(0.31,0.67,0,0.63)
    	titlebg:SetPoint("TOP",frame,"TOP",0,12)
    	titlebg:SetWidth(100)
    	titlebg:SetHeight(40)

    	local titlebg_l = frame:CreateTexture(nil,"OVERLAY")
    	titlebg_l:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    	titlebg_l:SetTexCoord(0.21,0.31,0,0.63)
    	titlebg_l:SetPoint("RIGHT",titlebg,"LEFT",0,0)
    	titlebg_l:SetWidth(30)
    	titlebg_l:SetHeight(40)
    	
    	local titlebg_right = frame:CreateTexture(nil,"OVERLAY")
    	titlebg_right:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    	titlebg_right:SetTexCoord(0.67,0.77,0,0.63)
    	titlebg_right:SetPoint("LEFT",titlebg,"RIGHT",0,0)
    	titlebg_right:SetWidth(30)
    	titlebg_right:SetHeight(40)
    	
        title:SetAllPoints(titlebg)			
    	local titletext = title:CreateFontString(nil,"OVERLAY","GameFontNormal")
    	titletext:SetPoint("TOP",titlebg,"TOP",0,-14)
    
    	self.titletext = titletext	
    	
    	local sizer_se = CreateFrame("Frame",nil,frame)
    	sizer_se:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)
    	sizer_se:SetWidth(25)
    	sizer_se:SetHeight(25)
    	sizer_se:EnableMouse()
    	sizer_se:SetScript("OnMouseDown",sizerseOnMouseDown)
    	sizer_se:SetScript("OnMouseUp", sizerOnMouseUp)
    	self.sizer_se = sizer_se

        local line1 = sizer_se:CreateTexture(nil, "BACKGROUND")
        self.line1 = line1
		line1:SetWidth(14)
		line1:SetHeight(14)
		line1:SetPoint("BOTTOMRIGHT", -8, 8)
		line1:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
		local x = 0.1 * 14/17
		line1:SetTexCoord(0.05 - x, 0.5, 0.05, 0.5 + x, 0.05, 0.5 - x, 0.5 + x, 0.5)

		local line2 = sizer_se:CreateTexture(nil, "BACKGROUND")
		self.line2 = line2
		line2:SetWidth(8)
		line2:SetHeight(8)
		line2:SetPoint("BOTTOMRIGHT", -8, 8)
		line2:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
		local x = 0.1 * 8/17
		line2:SetTexCoord(0.05 - x, 0.5, 0.05, 0.5 + x, 0.05, 0.5 - x, 0.5 + x, 0.5)

    	local sizer_s = CreateFrame("Frame",nil,frame)
    	sizer_s:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-25,0)
    	sizer_s:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",0,0)
    	sizer_s:SetHeight(25)
    	sizer_s:EnableMouse()
    	sizer_s:SetScript("OnMouseDown",sizersOnMouseDown)
    	sizer_s:SetScript("OnMouseUp", sizerOnMouseUp)
    	self.sizer_s = sizer_s
    	
    	local sizer_e = CreateFrame("Frame",nil,frame)
    	sizer_e:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,25)
    	sizer_e:SetPoint("TOPRIGHT",frame,"TOPRIGHT",0,0)
    	sizer_e:SetWidth(25)
    	sizer_e:EnableMouse()
    	sizer_e:SetScript("OnMouseDown",sizereOnMouseDown)
    	sizer_e:SetScript("OnMouseUp", sizerOnMouseUp)
    	self.sizer_e = sizer_e
    
    
        --Container Support
        local content = CreateFrame("Frame",nil,frame)
        self.content = content
        content:SetPoint("TOPLEFT",frame,"TOPLEFT",17,-27)
        content:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-17,40)
        
        AceGUI:RegisterAsContainer(self)
        return self	
    end
    
    AceGUI:RegisterWidgetType("Frame",Constructor)
end


--------------------------
-- Inline Group         --
--------------------------
do
    local Type = "InlineGroup"
    
    local function Aquire(self)

    end
    
    local function Release(self)
        self.frame:ClearAllPoints()
        self.frame:Hide()
    end
    
    local function SetTitle(self,title)
        self.titletext:SetText(title)
    end


    local function Constructor()
        local frame = CreateFrame("Frame",nil,UIParent)
        local self = {}
        self.type = Type

        self.Release = Release
        self.Aquire = Aquire
        self.SetTitle = SetTitle
        self.FrameLevelChanged = FrameLevelChanged
    	self.frame = frame
    	frame.obj = self
        
        frame:SetHeight(100)
        frame:SetWidth(100)
        frame:SetFrameStrata("DIALOG")
        
        local titletext = frame:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    	titletext:SetPoint("TOPLEFT",frame,"TOPLEFT",14,0)
    	titletext:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-14,0)
    	titletext:SetJustifyH("LEFT")
    	titletext:SetHeight(18)
    	
    
    	self.titletext = titletext	
    	
        local border = CreateFrame("Frame",nil,frame)
        self.border = border
        border:SetPoint("TOPLEFT",frame,"TOPLEFT",3,-17)
        border:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-3,3)
        
        border:SetBackdrop(PaneBackdrop)
        border:SetBackdropColor(0.1,0.1,0.1)
        border:SetBackdropBorderColor(0.4,0.4,0.4)
        
        --Container Support
        local content = CreateFrame("Frame",nil,border)
        self.content = content
        content:SetPoint("TOPLEFT",border,"TOPLEFT",10,-10)
        content:SetPoint("BOTTOMRIGHT",border,"BOTTOMRIGHT",-10,10)
        
        AceGUI:RegisterAsContainer(self)
        return self
    end
    
    AceGUI:RegisterWidgetType(Type,Constructor)
end

--------------------------
-- Select Group         --
--------------------------
--[[
    Events :
        OnGroupSelected

]]
do
    local Type = "SelectGroup"
    
    local function Aquire(self)

    end
    
    local function Release(self)
        self.frame:ClearAllPoints()
        self.frame:Hide()
    end
    
    local function SetTitle(self,title)
        self.titletext:SetText(title)
    end
    

    local function SelectedGroup(self,event,value)
        self.parentgroup:Fire("OnGroupSelected", value)
    end
    
    local function SetGroupList(self,list)
        self.dropdown.list = list
    end
    
    local function SetGroup(self,group)
        self.dropdown:SetValue(group)
    end
    
    local function Constructor()
        local frame = CreateFrame("Frame",nil,UIParent)
        local self = {}
        self.type = Type

        self.Release = Release
        self.Aquire = Aquire
        self.SetTitle = SetTitle
        
        self.FrameLevelChanged = FrameLevelChanged
        self.SetGroupList = SetGroupList
        self.SetGroup = SetGroup

    	self.frame = frame
    	frame.obj = self
        
        frame:SetHeight(100)
        frame:SetWidth(100)
        frame:SetFrameStrata("DIALOG")
        
        local titletext = frame:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    	titletext:SetPoint("TOPLEFT",frame,"TOPLEFT",14,0)
    	titletext:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-14,0)
    	titletext:SetJustifyH("LEFT")
    	titletext:SetHeight(18)
    	
    
    	self.titletext = titletext	
    	
    	local dropdown = AceGUI:Create("Dropdown")
        self.dropdown = dropdown
		dropdown:SetStrict(true)
        dropdown:SetParent(frame)
        dropdown.parentgroup = self
        dropdown:SetCallback("OnValueChanged",SelectedGroup)
        
        dropdown.frame:SetPoint("TOPLEFT",titletext,"BOTTOMLEFT",-7,3)
        
        local border = CreateFrame("Frame",nil,frame)
        self.border = border
        border:SetPoint("TOPLEFT",frame,"TOPLEFT",3,-40)
        border:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-3,3)
        
        border:SetBackdrop(PaneBackdrop)
        border:SetBackdropColor(0.1,0.1,0.1)
        border:SetBackdropBorderColor(0.4,0.4,0.4)
        
        --Container Support
        local content = CreateFrame("Frame",nil,border)
        self.content = content
        content:SetPoint("TOPLEFT",border,"TOPLEFT",10,-10)
        content:SetPoint("BOTTOMRIGHT",border,"BOTTOMRIGHT",-10,10)
        
        AceGUI:RegisterAsContainer(self)
        return self
    end
    
    AceGUI:RegisterWidgetType(Type,Constructor)
end


--------------------------
-- Edit box             --
--------------------------
--[[
    Events :
        OnTextChanged
		OnEnterPressed

]]
do
    local Type = "EditBox"
    
    local function Aquire(self)
        self:SetDisabled(false)
    end
    
    local function Release(self)
        self.frame:ClearAllPoints()
        self.frame:Hide()
    end
    
    local function EditBox_OnEscapePressed(this)
    	this:ClearFocus()
    end
    
    local function EditBox_OnEnterPressed(this)
        local self = this.obj
        local value = this:GetText()
    	self:Fire("OnEnterPressed",value)
    end
    

    local function UglyScrollLeft()
      this:HighlightText(0,1);
      this:Insert(" "..strsub(this:GetText(),1,1));
      this:HighlightText(0,1);
      this:Insert("");
      this:SetScript("OnUpdate", nil);
    end
    
    local function EditBox_OnTextChanged(this)
    	local self = this.obj
    	local value = this:GetText()
		if value ~= self.lasttext then
			self:Fire("OnTextChanged",value)
			self.lasttext = value
		end
    end
    
    local function SetDisabled(self, disabled)
        self.disabled = disabled
        if disabled then
    		self.editbox:EnableMouse(false)
    		self.editbox:ClearFocus()
    		self.editbox:SetTextColor(0.5,0.5,0.5)
    	else
    		self.editbox:EnableMouse(true)
    		self.editbox:SetTextColor(1,1,1)
    	end
    end
    
    local function SetText(self, text)
		self.lasttext = text
    	self.editbox:SetText(text)
    	self.editbox:SetScript("OnUpdate", UglyScrollLeft);
    end
    
    local function SetWidth(self, width)
        self.frame:SetWidth(width)
    end
    
    local function SetLabel(self, text)
        if text and text ~= "" then
            self.label:SetText(text)
            self.label:Show()
            self.editbox:SetPoint("TOPLEFT",self.frame,"TOPLEFT",0,-18)
            self.frame:SetHeight(44)
        else
            self.label:SetText("")
            self.label:Hide()
            self.editbox:SetPoint("TOPLEFT",self.frame,"TOPLEFT",0,0)
            self.frame:SetHeight(26)
        end
    end

    local function Constructor()
        local frame = CreateFrame("Frame",nil,UIParent)
        local editbox = CreateFrame("EditBox",nil,frame)
        
        local self = {}
        self.type = Type

        self.Release = Release
        self.Aquire = Aquire

        self.SetDisabled = SetDisabled
        self.SetText = SetText
        self.SetWidth = SetWidth
        self.FrameLevelChanged = FrameLevelChanged
        self.SetLabel = SetLabel
        
    	self.frame = frame
    	frame.obj = self
    	self.editbox = editbox
    	editbox.obj = self
        
        frame:SetHeight(44)
    	frame:SetWidth(300)

    	
    	--frame:SetScript("OnEnter",Control_OnEnter)
    	--frame:SetScript("OnLeave",Control_OnLeave)
    	editbox:SetFontObject(ChatFontNormal)
    	editbox:SetScript("OnEscapePressed",EditBox_OnEscapePressed)
    	editbox:SetScript("OnEnterPressed",EditBox_OnEnterPressed)
    	editbox:SetScript("OnTextChanged",EditBox_OnTextChanged)
    	editbox:SetTextInsets(5,5,3,3)
    	editbox:SetMaxLetters(256)
    	editbox:SetAutoFocus(false)

    	editbox:SetBackdrop(ControlBackdrop)
    	editbox:SetBackdropColor(0,0,0)
    	editbox:SetBackdropBorderColor(0.4,0.4,0.4)
    	
    	editbox:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",0,0)
    	editbox:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)
        editbox:SetHeight(26)
        
        local label = frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
    	label:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0)
    	label:SetPoint("TOPRIGHT",frame,"TOPRIGHT",0,0)
    	label:SetJustifyH("CENTER")
    	label:SetHeight(18)
    	self.label = label
    	
        --Container Support
        --local content = CreateFrame("Frame",nil,frame)
        --self.content = content
        
        --AceGUI:RegisterAsContainer(self)
        AceGUI:RegisterAsWidget(self)
        return self
    end
    
    AceGUI:RegisterWidgetType(Type,Constructor)
end





--------------------------
-- Check Box            --
--------------------------
--[[
    Events :
        OnValueChanged

]]
do
    local Type = "CheckBox"
    
    local function Aquire(self)
        self:SetValue(false)
    end
    
    local function Release(self)
        self.frame:ClearAllPoints()
        self.frame:Hide()
        self.check:Hide()
        self.checked = nil
        self:SetType()
    end
    
  
    local function CheckBox_OnEnter(this)
    	local self = this.obj
    	if not self.disabled then
    		self.highlight:Show()
    	end
    	self:Fire("OnEnter")
    end
    
    local function CheckBox_OnLeave(this)
    	local self = this.obj
    	if not self.down then
    		self.highlight:Hide()
    	end
    	self:Fire("OnLeave")
    end
    
    local function CheckBox_OnMouseUp(this)
    	local self = this.obj
    	if not self.disabled then
    		self:ToggleChecked()
    		self:Fire("OnValueChanged",self.checked)
    		self.text:SetPoint("LEFT",self.check,"RIGHT",0,0)
    	end
    	self.down = nil
    end
    
    local function CheckBox_OnMouseDown(this)
    	local self = this.obj
    	if not self.disabled then
    		self.text:SetPoint("LEFT",self.check,"RIGHT",1,-1)
    		self.down = true
    	end
    end

    local function SetDisabled(self,disabled)
        self.disabled = disabled
        if disabled then
    		self.text:SetTextColor(0.5,0.5,0.5)
    		SetDesaturation(self.check, true)
    	else
    		self.text:SetTextColor(1,1,1)
    		SetDesaturation(self.check, false)
    	end
    end
    
    local function SetValue(self,value)
    	self.checked = value
    	if value then
    		self.check:Show()
    	else
    		self.check:Hide()
    	end
    end
    
    local function GetValue(self)
        return self.checked
    end
    
    local function SetType(self, type)
    	local checkbg = self.checkbg
    	local check = self.check
    	local highlight = self.highlight
    
    	if type == "radio" then
    		checkbg:SetTexture("Interface\\Buttons\\UI-RadioButton")
    		checkbg:SetTexCoord(0,0.25,0,1)
    		check:SetTexture("Interface\\Buttons\\UI-RadioButton")
    		check:SetTexCoord(0.5,0.75,0,1)
    		check:SetBlendMode("ADD")
    		highlight:SetTexture("Interface\\Buttons\\UI-RadioButton")
			highlight:SetTexCoord(0.5,0.75,0,1)
    	else
    		checkbg:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
    		checkbg:SetTexCoord(0,1,0,1)
    		check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    		check:SetTexCoord(0,1,0,1)
    		check:SetBlendMode("BLEND")
            highlight:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
            highlight:SetTexCoord(0,1,0,1)
    	end
    end
    
    local function ToggleChecked(self)
    	self:SetValue(not self:GetValue())
    end
    
    local function SetLabel(self, label)
        self.text:SetText(label)
    end
    
    local function Constructor()
        local frame = CreateFrame("Button",nil,UIParent)
        local self = {}
        self.type = Type

        self.Release = Release
        self.Aquire = Aquire

        self.SetValue = SetValue
        self.GetValue = GetValue
        self.SetDisabled = SetDisabled
        self.SetType = SetType
        self.ToggleChecked = ToggleChecked
        self.SetLabel = SetLabel
        
    	self.frame = frame
    	frame.obj = self

    
        local text = frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    	self.text = text
    
    	frame:SetScript("OnEnter",CheckBox_OnEnter)
    	frame:SetScript("OnLeave",CheckBox_OnLeave)
    	frame:SetScript("OnMouseUp",CheckBox_OnMouseUp)
    	frame:SetScript("OnMouseDown",CheckBox_OnMouseDown)
    	frame:EnableMouse()
    	local checkbg = frame:CreateTexture(nil,"ARTWORK")
    	self.checkbg = checkbg
    	checkbg:SetWidth(24)
    	checkbg:SetHeight(24)
    	checkbg:SetPoint("LEFT",frame,"LEFT",0,0)
    	checkbg:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
    	local check = frame:CreateTexture(nil,"OVERLAY")
    	self.check = check
    	check:SetWidth(24)
    	check:SetHeight(24)
    	check:SetPoint("LEFT",frame,"LEFT",0,0)
    	check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    
    	local highlight = frame:CreateTexture(nil, "BACKGROUND")
    	self.highlight = highlight
    	highlight:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    	highlight:SetBlendMode("ADD")
    	highlight:SetAllPoints(checkbg)
    	highlight:Hide()
    
    
    	text:SetJustifyH("LEFT")
    	text:SetTextColor(1,1,1)
    	frame:SetHeight(24)
    	frame:SetWidth(200)
    	text:SetHeight(24)
    	text:SetPoint("LEFT",check,"RIGHT",0,0)
	
        --Container Support
        --local content = CreateFrame("Frame",nil,frame)
        --self.content = content
        
        --AceGUI:RegisterAsContainer(self)
        AceGUI:RegisterAsWidget(self)
        return self
    end
    
    AceGUI:RegisterWidgetType(Type,Constructor)
end



--------------------------
-- Dropdown             --
--------------------------
--[[
    Events :
        OnValueChanged

]]
do
    local Type = "Dropdown"
    
    local function Aquire(self)
		self:SetStrict(true)
    end
    
    local function Release(self)
        self.frame:ClearAllPoints()
        self.frame:Hide()
        self:SetLabel(nil)
		self.list = nil
    end
    
    local function SetText(self, text)
        self.editbox:SetText(text)
    end
	
	local function SetValue(self, value)
		if self.list then
			self.editbox:SetText(self.list[value])
		end
		self.editbox.value = value
	end
	
	local function SetList(self, list)
		self.list = list
	end
	
	local function AddItem(self, value, text)
		if self.list then
			self.list[value] = text
		end
	end
    
    local function Dropdown_OnEscapePressed(this)
    	this:ClearFocus()
    end
    
    local function Dropdown_OnEnterPressed(this)
    	local self = this.obj
    	if not self.disabled then
    		local ret
    		if self.strict and this.value then
    			ret = this.value
    		else
    			ret = this:GetText()
    		end
    		self:Fire("OnValueChanged",ret)
    	end
    end
    
    local function Dropdown_TogglePullout(this)
    	local self = this.obj
    	if self.open then
    		self.open = nil
    		self.pullout:Hide()
    	else
    		self.open = true
    		self:BuildPullout()
    		if self.lines[1] and self.lines[1]:IsShown() then
    			self.pullout:Show()
    		end
    	end
    end
    
    local function Dropdown_OnHide(this)
    	this.obj.pullout:Hide()
    end
    
    local function Dropdown_LineClicked(this)
    	local self = this.obj
    	self.open = false
    	self.pullout:Hide()
    	self.editbox:SetText(this.text:GetText())
    	self.editbox.value = this.value
    	Dropdown_OnEnterPressed(self.editbox)
    end
    
    local function Dropdown_LineEnter(this)
    	this.highlight:Show()
    end
    
    local function Dropdown_LineLeave(this)
    	this.highlight:Hide()
    end    
	
	local function SetStrict(self, strict)
		self.strict = strict
		if strict then
			self.editbox:EnableMouse(false)
			self.editbox:ClearFocus()
			self.editbox:SetTextColor(1,1,1)
		else
			self.editbox:EnableMouse(true)
			self.editbox:SetTextColor(1,1,1)
		end
	end
    
    local ddsort = {}
    local function BuildPullout(self)
        local list = self.list
    	local lines = self.lines
    	local totalheight = 10
    	self:ClearPullout()
    	self.pullout:SetFrameLevel(self.frame:GetFrameLevel()+1000)
    	if type(list) == "table" then
    		for k, v in pairs(list) do
    			tinsert(ddsort,k)
    		end
    		table.sort(ddsort)
    		for i, value in pairs(ddsort) do
    			local text = list[value]
    			if not lines[i] then
    				lines[i] = self:CreateLine()
    				if i == 1 then
    					lines[i]:SetPoint("TOP",self.pullout,"TOP",0,-5)
    				else
    					lines[i]:SetPoint("TOP",lines[i-1],"BOTTOM",0,0)
    				end
    			end
    			lines[i].text:SetText(text)
    			lines[i]:SetFrameLevel(self.frame:GetFrameLevel()+1001)
    			if type(value) == "string" then
    				lines[i].value = value
    			else
    				lines[i].value = text
    			end
    			if lines[i].value == self.editbox.value and self.getFunc then
    				lines[i].check:Show()
    			else
    				lines[i].check:Hide()
    			end
    			lines[i]:Show()
    			totalheight = totalheight + 17
    			i = i + 1
    		end
    		for k in pairs(ddsort) do
    			ddsort[k] = nil
    		end
    	elseif type(list) == "function" then
    		for i, text, value in list() do
    			if not lines[i] then
    				lines[i] = self:CreateLine()
    				if i == 1 then
    					lines[i]:SetPoint("TOP",self.pullout,"TOP",0,-5)
    				else
    					lines[i]:SetPoint("TOP",lines[i-1],"BOTTOM",0,0)
    				end
    			end
    			lines[i].text:SetText(text)
    			lines[i].value = value
    			lines[i]:Show()
    			totalheight = totalheight + 17
    		end
    	end
    	self.pullout:SetHeight(totalheight)
    end

    local function ClearPullout(self)
    	if self.lines then
    		for i, line in ipairs(self.lines) do
    			line.text:SetText("")
    			line:Hide()
    		end
    	end
    	self.pullout:SetHeight(10)
    	self.pullout:SetWidth(200)
    end
    
    local function SetLabel(self, text)
        if text and text ~= "" then
            self.label:SetText(text)
            self.label:Show()
            self.editbox:SetPoint("TOPLEFT",self.frame,"TOPLEFT",0,-18)
            self.frame:SetHeight(44)
        else
            self.label:SetText("")
            self.label:Hide()
            self.editbox:SetPoint("TOPLEFT",self.frame,"TOPLEFT",0,0)
            self.frame:SetHeight(26)
        end
    end

    -- For large list, if specified, 0 based row, 1 based column gives a grid.
    local function CreateLine(self, row, column)
    	local frame = CreateFrame("Button",nil,self.pullout)
    	frame.text = frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    	frame.text:SetTextColor(1,1,1)
    	frame.text:SetJustifyH("LEFT")
    	frame:SetHeight(17)
    	frame:SetPoint("LEFT",self.pullout,"LEFT",6,0)
    	frame:SetPoint("RIGHT",self.pullout,"RIGHT",-6,0)
    	frame:SetFrameStrata("DIALOG")
    	frame.obj = self
    
    	local highlight = frame:CreateTexture(nil, "OVERLAY")
    	highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    	highlight:SetBlendMode("ADD")
    	highlight:SetAllPoints(frame)
    	highlight:Hide()
    	frame.highlight = highlight
    
    	local check = frame:CreateTexture("OVERLAY")
    	frame.check = check
    	check:SetWidth(16)
    	check:SetHeight(16)
    	check:SetPoint("LEFT",frame,"LEFT",0,0)
    	check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    	frame.text:SetPoint("TOPLEFT",frame,"TOPLEFT",16,0)
    	frame.text:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)
    
    	frame:SetScript("OnClick",Dropdown_LineClicked)
    	frame:SetScript("OnEnter",Dropdown_LineEnter)
    	frame:SetScript("OnLeave",Dropdown_LineLeave)
    	return frame
    end

    local function Constructor()
        local frame = CreateFrame("Frame",nil,UIParent)
        local self = {}
        self.type = Type

        self.Release = Release
        self.Aquire = Aquire

        self.CreateLine = CreateLine
        self.ClearPullout = ClearPullout
        self.BuildPullout = BuildPullout
        self.UpdateLine = UpdateLine
        self.SetText = SetText
        self.FrameLevelChanged = FrameLevelChanged
		self.SetValue = SetValue
		self.SetList = SetList
		self.AddItem = AddItem
		self.SetStrict = SetStrict
		self.SetLabel = SetLabel
		
    	self.frame = frame
    	frame.obj = self

        local editbox = CreateFrame("EditBox",nil,frame)
    	self.editbox = editbox
    	editbox.obj = self
    	editbox:SetFontObject(ChatFontNormal)
    	editbox:SetScript("OnEscapePressed",Dropdown_OnEscapePressed)
    	editbox:SetScript("OnEnterPressed",Dropdown_OnEnterPressed)
    	frame:SetScript("OnEnter",Control_OnEnter)
    	frame:SetScript("OnLeave",Control_OnLeave)
    	editbox:SetScript("OnEnter",Control_OnEnter)
    	editbox:SetScript("OnLeave",Control_OnLeave)
    	editbox:SetTextInsets(5,5,3,3)
    	editbox:SetMaxLetters(256)
    	editbox:SetAutoFocus(false)
    	editbox:SetBackdrop(ControlBackdrop)
    	editbox:SetBackdropColor(0,0,0)
    
    	editbox:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0)
    	editbox:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-20,0)
    	local button = CreateFrame("Button",nil,frame)
    	self.button = button
    	button.obj = self
    	button:SetWidth(24)
    	button:SetHeight(24)
    	button:SetScript("OnEnter",Control_OnEnter)
    	button:SetScript("OnLeave",Control_OnLeave)
    	button:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    	button:GetNormalTexture():SetTexCoord(.09,.91,.09,.91)
    	button:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
    	button:GetPushedTexture():SetTexCoord(.09,.91,.09,.91)
    	button:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled")
    	button:GetDisabledTexture():SetTexCoord(.09,.91,.09,.91)
    	button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    	button:GetHighlightTexture():SetTexCoord(.09,.91,.09,.91)
    	button:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)
    	button:SetScript("OnClick",Dropdown_TogglePullout)
    	frame:SetHeight(26)
    	frame:SetWidth(200)
    	frame:SetScript("OnHide",Dropdown_OnHide)
    	local pullout = CreateFrame("Frame",nil,UIParent)
    	self.pullout = pullout
    	frame:EnableMouse()
    	pullout:SetBackdrop(ControlBackdrop)
    	pullout:SetBackdropColor(0,0,0)
    	pullout:SetFrameStrata("DIALOG")
    	pullout:SetPoint("TOPLEFT",frame,"BOTTOMLEFT",0,0)
    	pullout:SetPoint("TOPRIGHT",frame,"BOTTOMRIGHT",-24,0)
    	pullout:SetClampedToScreen(true)
    	pullout:Hide()
    
        local label = frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
    	label:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0)
    	label:SetPoint("TOPRIGHT",frame,"TOPRIGHT",0,0)
    	label:SetJustifyH("CENTER")
    	label:SetHeight(18)
    	label:Hide()
    	self.label = label
    	
    	self.lines = {}
        --Container Support
        --local content = CreateFrame("Frame",nil,frame)
        --self.content = content
        
        --AceGUI:RegisterAsContainer(self)
        AceGUI:RegisterAsWidget(self)
        return self
    end
    
    AceGUI:RegisterWidgetType(Type,Constructor)
end


--------------
-- TreeView --
--------------

do
    local Type = "TreeView"
    
    local function Aquire(self)

    end
    
	local function ButtonOnClick(this)
		local self = this.obj
		local status = self.status or self.localstatus
		
		if this.selected then
			status[this.value] = not status[this.value]
		else
			status[this.value] = true
			self:SetSelected(this.value)
			this.selected = true
			this:LockHighlight()
		end
		self:RefreshTree()
	end
	
	local function CreateButton(self)
		local button = CreateFrame("Button",nil,UIParent)
		button.obj = self
		button:SetHeight(20)
		button:SetWidth(136)
		button:SetScript("OnClick",ButtonOnClick)
		local line = button:CreateTexture(nil,"BACKGROUND")
		line:SetWidth(7)
		line:SetHeight(20)
		line:SetPoint("LEFT",button,"LEFT",13,0)
		line:SetTexCoord(0,0.4375,0,0.625)
		line:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-FilterLines")
		button.line = line

		button:SetNormalTexture("Interface\\AuctionFrame\\UI-AuctionFrame-FilterBg")
		button:GetNormalTexture():SetTexCoord(0,0.53125,0,0.625)

		button:SetHighlightTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight")
		button:GetHighlightTexture():SetBlendMode("ADD")

		local text = button:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
		button:SetFontString(text)
		button.text = text
		text:SetWidth(115)
		text:SetHeight(8)
		text:SetJustifyH("LEFT")
		text:SetPoint("LEFT",button,"LEFT",4,0)

		button:SetFont("GameFontNormalSmall",8)
		
		return button
	end

	local function UpdateButton(button, level, value, text, selected, last)
		text = text or ""
		button.value = value
		if selected then
			button:LockHighlight()
			button.selected = true
		else
			button:UnlockHighlight()
			button.selected = false
		end
		local normalText = button.text
		local normalTexture = button:GetNormalTexture()
		local line = button.line
		if ( level == 1 ) then
			button:SetText(text)
			normalText:SetPoint("LEFT", button, "LEFT", 4, 0)
			normalTexture:SetAlpha(1.0)	
			line:Hide();
		elseif ( level == 2 ) then
			button:SetText(HIGHLIGHT_FONT_COLOR_CODE..text..FONT_COLOR_CODE_CLOSE)
			normalText:SetPoint("LEFT", button, "LEFT", 12, 0)
			normalTexture:SetAlpha(0.4)
			line:Hide()
		elseif ( level >= 3 ) then
			button:SetText(HIGHLIGHT_FONT_COLOR_CODE..text..FONT_COLOR_CODE_CLOSE)
			normalText:SetPoint("LEFT", button, "LEFT", 20 + (level-3)*8, 0)
			line:SetPoint("LEFT",button,"LEFT",13 + (level-3)*8,0)
			normalTexture:SetAlpha(0.0)
			if ( last ) then
				line:SetTexCoord(0.4375, 0.875, 0, 0.625)
			else
				line:SetTexCoord(0, 0.4375, 0, 0.625)
			end
			line:Show();
		end
	end

    local function Release(self)
        self.frame:ClearAllPoints()
        self.frame:Hide()
    end
    
	local function OnScrollValueChanged(this, value)
		if this.obj.noupdate then return end
		this.obj.scrollvalue = value
		this.obj:RefreshTree()
	end
	
	-- called to set an external table to store status in
	local function SetStatusTable(self, status)
		assert(type(status) == "table")
		self.status = status
	end

	--sets the tree to be displayed
	--[[
		example tree
		
		Alpha
		Bravo
		  -Charlie
		  -Delta
		    -Echo
		Foxtrot
		
		tree = { "A", "B", "F", B = { "C", "D", D = { "E" } } }
		text = { A = "Alpha", B = "Bravo" ... }
	]]
	local function SetTree(self, tree, text)
		assert(type(tree) == "table" and type(text) == "table")
		
		self.tree = tree
		self.text = text
		self:RefreshTree()
	end

	
	local function BuildLevel(self, tree, level)
		local lines = self.lines
		local levels = self.levels
		local status = self.status or self.localstatus
		
		for i, v in ipairs(tree) do
			lines[#lines+1] = v
			levels[v] = level
			if tree[v] and status[v] then
				self:BuildLevel(tree[v], level+1)
			end
		end
	end
	
	--fire an update after one frame to catch the treeframes height
	local function FirstFrameUpdate(this)
		local self = this.obj
		this:SetScript("OnUpdate",nil)
		self:RefreshTree()
	end
	
	local function ResizeUpdate(this)
		this.obj:RefreshTree()
	end
	
	local function RefreshTree(self)
		--Build the list of visible entries from the tree and status tables
		local status = self.status or self.localstatus
		local tree = self.tree
		local lines = self.lines
		local buttons = self.buttons
		local levels = self.levels
		local text = self.text
		local treeframe = self.treeframe
		
		while tremove(lines) do end
		
		self:BuildLevel(tree, 1)
		
		for i, v in ipairs(buttons) do
			v:Hide()
		end
		
		local numlines = #lines
		
		local maxlines = (math.floor((self.treeframe:GetHeight()or 0) / 20))
		
		local first, last
		
		if numlines <= maxlines then
			--the whole tree fits in the frame
			self.scrollvalue = 0
			self:ShowScroll(false)
			first, last = 1, numlines
		else
			self:ShowScroll(true)
			--scrolling will be needed
			self.noupdate = true
			self.scrollbar:SetMinMaxValues(0, numlines - maxlines)
			--check if we are scrolled down too far
			if numlines - self.scrollvalue < maxlines then
				self.scrollvalue = numlines - maxlines
				self.scrollbar:SetValue(self.scrollvalue)
			end
			self.noupdate = nil
			first, last = self.scrollvalue+1, self.scrollvalue + maxlines
		end
		
		local buttonnum = 1
		for i = first, last do
			local v = lines[i]
			local button = buttons[buttonnum]
			if not button then
				button = self:CreateButton()
				if self.showscroll then
					button:SetWidth(134)
				else
					button:SetWidth(150)
				end
				buttons[buttonnum] = button
				button:SetParent(treeframe)
				button:SetFrameLevel(treeframe:GetFrameLevel()+1)
				if i == 1 then
					button:SetPoint("TOPLEFT", self.treeframe,"TOPLEFT",0,0)
					button:SetPoint("TOPRIGHT", self.treeframe,"TOPRIGHT",-16,0)
				else
					button:SetParent(self.treeframe)
					button:SetPoint("TOPLEFT", buttons[buttonnum-1], "BOTTOMLEFT",0,0)
					button:SetPoint("TOPRIGHT", buttons[buttonnum-1], "BOTTOMRIGHT",0,0)
				end
			end

			UpdateButton(button, levels[v], v,  text[v], self.selected == v, (not lines[i+1]) or levels[lines[i+1]] ~= levels[v] )
			button:Show()
			buttonnum = buttonnum + 1
		end

	end
	
	local function SetSelected(self, value)
		if self.selected ~= value then
			self.selected = value
			self:Fire("OnGroupSelected", value)
		end
	end
	
	local function ShowScroll(self, show)
		self.showscroll = show
		if show then
			self.scrollbar:Show()
			for i, v in ipairs(self.buttons) do
				v:SetWidth(134)
			end
		else
			self.scrollbar:Hide()
			for i, v in ipairs(self.buttons) do
				v:SetWidth(150)
			end
		end
		
	end
	
    local function Constructor()
        local frame = CreateFrame("Frame",nil,UIParent)
        local self = {}
        self.type = Type
		self.localstatus = {}
		self.lines = {}
		self.levels = {}
		self.buttons = {}
		
		local treeframe = CreateFrame("Frame",nil,frame)
		treeframe.obj = self
		treeframe:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0)
		treeframe:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",0,0)
		treeframe:SetWidth(150)
		treeframe:SetScript("OnUpdate",FirstFrameUpdate)
		treeframe:SetScript("OnSizeChanged",ResizeUpdate)
		self.treeframe = treeframe
        self.Release = Release
        self.Aquire = Aquire
        
		self.SetTree = SetTree
		self.RefreshTree = RefreshTree
		self.SetStatusTable = SetStatusTable
		self.BuildLevel = BuildLevel
		self.CreateButton = CreateButton
		self.SetSelected = SetSelected
		self.ShowScroll = ShowScroll
		
    	self.frame = frame
    	frame.obj = self

		local scrollbar = CreateFrame("Slider",nil,treeframe,"UIPanelScrollBarTemplate")
		self.scrollbar = scrollbar
		scrollbar.obj = self
		self.noupdate = true
		scrollbar:SetPoint("TOPRIGHT",treeframe,"TOPRIGHT",0,-16)
		scrollbar:SetPoint("BOTTOMRIGHT",treeframe,"BOTTOMRIGHT",0,16)
		scrollbar:SetScript("OnValueChanged", OnScrollValueChanged)
		scrollbar:SetMinMaxValues(0,0)
		self.scrollvalue = 0
		scrollbar:SetValueStep(1)
		scrollbar:SetValue(0)
		scrollbar:SetWidth(16)
		self.noupdate = nil

		
		
        --Container Support
        local content = CreateFrame("Frame",nil,frame)
        self.content = content
		
		content:SetPoint("TOPRIGHT",frame,"TOPRIGHT",0,0)
		content:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)
		content:SetPoint("LEFT",treeframe,"RIGHT",5,0)
        
        AceGUI:RegisterAsContainer(self)
        --AceGUI:RegisterAsWidget(self)
        return self
    end
    
    AceGUI:RegisterWidgetType(Type,Constructor)
end


--------------------------
-- Scroll Frame         --
--------------------------
do
    local Type = "ScrollFrame"
    
    local function Aquire(self)

    end
    
    local function Release(self)
        self.frame:ClearAllPoints()
        self.frame:Hide()
    end
	
	local function SetScroll(self, value)
		local frame, child = self.scrollframe, self.content
		local viewheight = frame:GetHeight()
		local height = child:GetHeight()
		local offset
		if viewheight > height then
			offset = 0
		else
			offset = floor((height - viewheight) / 1000.0 * value)
		end
		child:ClearAllPoints()
		child:SetPoint("TOPLEFT",frame,"TOPLEFT",0,offset)
		child:SetPoint("TOPRIGHT",frame,"TOPRIGHT",0,offset)
		child.offset = offset

		self.scrollvalue = value
	end
	
	local function MoveScroll(self, value)
		local frame, child = self.scrollframe, self.content
		local height, viewheight = frame:GetHeight(), child:GetHeight()
		if height > viewheight then
			self.scrollbar:Hide()
		else
			self.scrollbar:Show()
			local diff = height - viewheight
			local delta = 1
			if value < 0 then
				delta = -1
			end
			self.scrollbar:SetValue(math.min(math.max(self.scrollvalue + delta*(1000/(diff/45)),0), 1000))
		end
	end
	
	local function FixScroll(self)
		if self.noFixScroll then return end
		local frame, child = self.scrollframe, self.content
		local height, viewheight = frame:GetHeight(), child:GetHeight()
		local offset = child.offset
		if not offset then
			offset = 0
		end
		local curvalue = self.scrollbar:GetValue()

		if viewheight < height then
			self.scrollbar:Hide()
			self.scrollbar:SetValue(0)
		else
			self.scrollbar:Show()
			local value = (offset / (viewheight - height) * 1000)
			if value > 1000 then value = 1000 end
			self.scrollbar:SetValue(value)
			self:SetScroll(value)
			if value < 1000 then
				child:ClearAllPoints()
				child:SetPoint("TOPLEFT",frame,"TOPLEFT",0,offset)
				child:SetPoint("TOPRIGHT",frame,"TOPRIGHT",0,offset)
				child.offset = offset
			end
		end
	end
	
	local function OnMouseWheel(this,value)
		this.obj:MoveScroll(value)
	end

	local function OnScrollValueChanged(this, value)
		this.obj:SetScroll(value)
	end
	
	local function OnSizeChanged(this)
		this.obj:FixScroll()
	end
    

    local function Constructor()
        local frame = CreateFrame("Frame",nil,UIParent)
        local self = {}
        self.type = Type

        self.Release = Release
        self.Aquire = Aquire
        
		self.MoveScroll = MoveScroll
		self.FixScroll = FixScroll
		self.SetScroll = SetScroll
		
    	self.frame = frame
    	frame.obj = self

		
		
		
        --Container Support
		local scrollframe = CreateFrame("ScrollFrame",nil,frame)
        local content = CreateFrame("Frame",nil,scrollframe)
		local scrollbar = CreateFrame("Slider",nil,scrollframe,"UIPanelScrollBarTemplate")
		self.scrollframe = scrollframe
        self.content = content
		self.scrollbar = scrollbar
		
		scrollbar.obj = self
		scrollframe.obj = self
		
		scrollframe:SetScrollChild(content)
		scrollframe:SetPoint("TOPLEFT",frame,"TOPLEFT",8,-12)
		scrollframe:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-28,12)
		scrollframe:EnableMouseWheel(true)
		scrollframe:SetScript("OnMouseWheel", OnMouseWheel)
		scrollframe:SetScript("OnSizeChanged", OnSizeChanged)
		
		
		content:SetPoint("TOPLEFT",scrollframe,"TOPLEFT",0,0)
		content:SetPoint("TOPRIGHT",scrollframe,"TOPRIGHT",0,0)
		content:SetHeight(400)
		
		scrollbar:SetPoint("TOPLEFT",scrollframe,"TOPRIGHT",0,-16)
		scrollbar:SetPoint("BOTTOMLEFT",scrollframe,"BOTTOMRIGHT",0,16)
		scrollbar:SetScript("OnValueChanged", OnScrollValueChanged)
		scrollbar:SetMinMaxValues(0,1000)
		scrollbar:SetValueStep(1)
		scrollbar:SetValue(0)
		scrollbar:SetWidth(16)
		
		self.scrollvalue = 0
		

        self:FixScroll()
        AceGUI:RegisterAsContainer(self)
        --AceGUI:RegisterAsWidget(self)
        return self
    end
    
    AceGUI:RegisterWidgetType(Type,Constructor)
end




	
--------------------------
-- Button          --
--------------------------
do
    local Type = "Button"
    
    local function Aquire(self)

    end
    
    local function Release(self)
        self.frame:ClearAllPoints()
        self.frame:Hide()
    end
    
	local function Button_OnClick(this)
		local self = this.obj
		self:Fire("OnClick")
	end
	
	local function Button_OnEnter(this)
		local self = this.obj
		self:Fire("OnEnter")
	end
	
	local function Button_OnLeave(this)
		local self = this.obj
		self:Fire("OnLeave")
	end
	
	local function SetText(self, text)
		self.text:SetText(text or "")
	end
	
    local function Constructor()
        local frame = CreateFrame("Button",nil,UIParent,"UIPanelButtonTemplate")
        local self = {}
        self.type = Type
		self.frame = frame

		--local text = frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
		local text = frame:GetFontString()
		self.text = text
		text:SetPoint("LEFT",frame,"LEFT",7,0)
		text:SetPoint("RIGHT",frame,"RIGHT",-7,0)

		frame:SetScript("OnClick",Button_OnClick)
		frame:SetScript("OnEnter",Button_OnEnter)
		frame:SetScript("OnLeave",Button_OnLeave)

		self.SetText = SetText
		
		frame:EnableMouse()

		frame:SetHeight(24)
		frame:SetWidth(150)
	
        self.Release = Release
        self.Aquire = Aquire
        
    	self.frame = frame
    	frame.obj = self

        --Container Support
        --local content = CreateFrame("Frame",nil,frame)
        --self.content = content
        
        --AceGUI:RegisterAsContainer(self)
        AceGUI:RegisterAsWidget(self)
        return self
    end
    
    AceGUI:RegisterWidgetType(Type,Constructor)
end

--[[ Widget Template

--------------------------
-- Widget Name          --
--------------------------
do
    local Type = "Type"
    
    local function Aquire(self)

    end
    
    local function Release(self)
        self.frame:ClearAllPoints()
        self.frame:Hide()
    end
    

    local function Constructor()
        local frame = CreateFrame("Frame",nil,UIParent)
        local self = {}
        self.type = Type

        self.Release = Release
        self.Aquire = Aquire
        
    	self.frame = frame
    	frame.obj = self

        --Container Support
        --local content = CreateFrame("Frame",nil,frame)
        --self.content = content
        
        --AceGUI:RegisterAsContainer(self)
        AceGUI:RegisterAsWidget(self)
        return self
    end
    
    AceGUI:RegisterWidgetType(Type,Constructor)
end


]]

-------------
-- Layouts --
-------------

--[[
    A Layout is a func that takes 2 parameters
        content - the frame that widgets will be placed inside
        children - a table containing the widgets to layout

]]

-- Very simple Layout, Children are stacked on top of each other down the left side
AceGUI:RegisterLayout("List",
     function(content, children)
        for i, child in ipairs(children) do
            local frame = child.frame
            frame:ClearAllPoints()
            if i == 1 then
                frame:SetPoint("TOPLEFT",content,"TOPLEFT",0,0)
            else
                frame:SetPoint("TOPLEFT",children[i-1].frame,"BOTTOMLEFT",0,0)
            end
            if child.width == "fill" then
                frame:SetPoint("RIGHT",content,"RIGHT")
            end
        end
     end
    )
    
-- A single control fills the whole content area
AceGUI:RegisterLayout("Fill",
     function(content, children)
        if children[1] then
            children[1].frame:SetAllPoints(content)
        end
     end
    )





