 -- Hemlock = {};
 -- Hemlock.frame = CreateFrame( "Frame", "Hemlockframe", UIParent );
 -- Hemlock.frame.name = "Hemlock";
 -- InterfaceOptions_AddCategory(Hemlock.frame);

local addOnName = ...

-- main frame
local frame = CreateFrame("Frame")
frame.name = addOnName
InterfaceOptions_AddCategory(frame)
frame:Hide()

frame:SetScript("OnShow", function(frame)
	local options = {}
	local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText(addOnName)

	local description = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	description:SetText("Minimalistic addon to automate poison buying and creation")

	local function newCheckbox(label, description, onClick)
		local check = CreateFrame("CheckButton", "HemlockButtons" .. label, frame, "InterfaceOptionsCheckButtonTemplate")
		check:SetScript("OnClick", function(self)
			local tick = self:GetChecked()
			onClick(self, tick and true or false)
			if tick then
				PlaySound(856) -- SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
			else
				PlaySound(857) -- SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
			end
		end)
		check.label = _G[check:GetName() .. "Text"]
		check.label:SetText(label)
		check.tooltipText = label
		check.tooltipRequirement = description
		return check
	end

	local smartTextCount = newCheckbox(
		"Smart Text Count",
		"Hemlock buttons will only display the amount of needed poisons or reagents",
		function(self, value) Hemlock.db.profile.options.smartTextCount = value end)
	smartTextCount:SetChecked(Hemlock.db.profile.options.smartTextCount)
	smartTextCount:SetPoint("TOPLEFT", description, "BOTTOMLEFT", -2, -16)
	
	local chatMessages = newCheckbox(
		"Print Hemlock Output",
		"Hemlock will print help messages in the chat",
		function(self, value) Hemlock.db.profile.options.chatMessages = value end)
	chatMessages:SetChecked(Hemlock.db.profile.options.chatMessages)
	chatMessages:SetPoint("TOPLEFT", smartTextCount, "BOTTOMLEFT", 0, -8)
	
	local buyConfirmation = newCheckbox(
		"Confirmation Popup",
		"Hemlock will display the amount of reagents and the total price before buying poisons or reagents",
		function(self, value) Hemlock.db.profile.options.buyConfirmation = value end)
	buyConfirmation:SetChecked(Hemlock.db.profile.options.buyConfirmation)
	buyConfirmation:SetPoint("TOPLEFT", chatMessages, "BOTTOMLEFT", 0, -8)
	
	local alternativeWoundPoisonIcon = newCheckbox(
		"Alternative Wound Poison Icon",
		"Hemlock will display an alternavite Wound Poison Icon",
		function(self, value) Hemlock.db.profile.options.alternativeWoundPoisonIcon = value; Hemlock:InitFrames() end)
	alternativeWoundPoisonIcon:SetChecked(Hemlock.db.profile.options.alternativeWoundPoisonIcon)
	alternativeWoundPoisonIcon:SetPoint("TOPLEFT", buyConfirmation, "BOTTOMLEFT", 0, -8)
	
	local clear = CreateFrame("Button", "BugSackSaveButton", frame, "UIPanelButtonTemplate")
	clear:SetText("Reset Hemlock Buttons")
	clear:SetWidth(177)
	clear:SetHeight(24)
	clear:SetPoint("TOPLEFT", alternativeWoundPoisonIcon, "BOTTOMLEFT", 17, -15)
	clear:SetScript("OnClick", function()
		Hemlock:Reset();
		PlaySound(856);
	end)
	clear.tooltipText = "Reset"
	clear.newbieText = "Hemlock will reset all hidden buttons"
	
	frame:SetScript("OnShow", nil)
end)