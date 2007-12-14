local AceGUI = LibStub("AceGUI-3.0")

--------------------------
-- Edit box			 --
--------------------------
--[[
	Events :
		OnTextChanged
		OnEnterPressed

]]
do
	local Type = "EditBox"
	local Version = 0
	
	local function Aquire(self)
		self:SetDisabled(false)
	end
	
	local function Release(self)
		self.frame:ClearAllPoints()
		self.frame:Hide()
		self:SetDisabled(false)
	end

	local ControlBackdrop  = {
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 3, right = 3, top = 3, bottom = 3 }
	}
	
	local function Control_OnEnter(this)
		this.obj:Fire("OnEnter")
	end
	
	local function Control_OnLeave(this)
		this.obj:Fire("OnLeave")
	end
	
	local function EditBox_OnEscapePressed(this)
		this:ClearFocus()
	end
	
	local function EditBox_OnEnterPressed(this)
		local value = this:GetText()
		this.obj:Fire("OnEnterPressed",value)
	end
	
	local function EditBox_OnReceiveDrag(this)
		local self = this.obj
		local type, id, info = GetCursorInfo()
		if type == "item" then
			self:SetText(info)
			self:Fire("OnEnterPressed",info)
			ClearCursor()
		elseif type == "spell" then
			local name, rank = GetSpellName(id, info)
			if rank and rank:match("%d") then
				name = name.." ("..rank..")"
			end
			self:SetText(name)
			self:Fire("OnEnterPressed",name)
			ClearCursor()
		end
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
		self.editbox:SetText(text or "")
		self.editbox:SetCursorPosition(0)
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
		self.SetLabel = SetLabel
		
		self.frame = frame
		frame.obj = self
		self.editbox = editbox
		editbox.obj = self
		
		frame:SetHeight(44)
		frame:SetWidth(200)

		editbox:SetScript("OnEnter",Control_OnEnter)
		editbox:SetScript("OnLeave",Control_OnLeave)
		
		editbox:SetAutoFocus(false)
		editbox:SetFontObject(ChatFontNormal)
		editbox:SetScript("OnEscapePressed",EditBox_OnEscapePressed)
		editbox:SetScript("OnEnterPressed",EditBox_OnEnterPressed)
		editbox:SetScript("OnTextChanged",EditBox_OnTextChanged)
		editbox:SetScript("OnReceiveDrag", EditBox_OnReceiveDrag)
		editbox:SetScript("OnMouseDown", EditBox_OnReceiveDrag)
		editbox:SetTextInsets(5,5,3,3)
		editbox:SetMaxLetters(256)
		

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

		AceGUI:RegisterAsWidget(self)
		return self
	end
	
	AceGUI:RegisterWidgetType(Type,Constructor,Version)
end
