﻿local addOnName = ...

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
				PlaySound(856)
			else
				PlaySound(857)
			end
		end)
		check.label = _G[check:GetName() .. "Text"]
		check.label:SetText(label)
		check.tooltipText = label
		check.tooltipRequirement = description
		return check
	end

	local smartButtonCount = newCheckbox(
		Hemlock:L("option_smart_button_count"),
		Hemlock:L("option_smart_button_count_desc"),
		function(self, value) Hemlock.db.profile.options.smartButtonCount = value; Hemlock:InitFrames() end)
	smartButtonCount:SetChecked(Hemlock.db.profile.options.smartButtonCount)
	smartButtonCount:SetPoint("TOPLEFT", description, "BOTTOMLEFT", -2, -16)
	
	local chatMessages = newCheckbox(
		Hemlock:L("option_chatMessages"),
		Hemlock:L("option_chatMessages_desc"),
		function(self, value) Hemlock.db.profile.options.chatMessages = value end)
	chatMessages:SetChecked(Hemlock.db.profile.options.chatMessages)
	chatMessages:SetPoint("TOPLEFT", smartButtonCount, "BOTTOMLEFT", 0, -8)
	
	local alternativeWoundPoisonIcon = newCheckbox(
		Hemlock:L("option_alternativeWoundPoisonIcon"),
		Hemlock:L("option_alternativeWoundPoisonIcon_desc"),
		function(self, value) Hemlock.db.profile.options.alternativeWoundPoisonIcon = value; Hemlock:InitFrames() end)
	alternativeWoundPoisonIcon:SetChecked(Hemlock.db.profile.options.alternativeWoundPoisonIcon)
	alternativeWoundPoisonIcon:SetPoint("TOPLEFT", chatMessages, "BOTTOMLEFT", 0, -8)
	
	local reset = CreateFrame("Button", "HemlockResetButton", frame, "UIPanelButtonTemplate")
	reset:SetText(Hemlock:L("option_reset_button"))
	reset:SetWidth(177)
	reset:SetHeight(24)
	reset:SetPoint("TOPLEFT", alternativeWoundPoisonIcon, "BOTTOMLEFT", 17, -15)
	reset:SetScript("OnClick", function()
		Hemlock:Reset();
		PlaySound(856);
	end)
	reset.tooltipText = Hemlock:L("option_reset_tooltip_title")
	reset.newbieText = Hemlock:L("option_reset_tooltip_desc")
	
	frame:SetScript("OnShow", nil)
end)