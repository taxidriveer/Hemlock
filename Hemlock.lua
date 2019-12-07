if (select(2, UnitClass("player"))) ~= "ROGUE" then return end

--[[
Name: Hemlock
Revision: $Rev: 1.0.7 $
Developed by: Antiarc
Fan update by: Grome
Documentation:
SVN: http://svn.wowace.com/wowace/trunk/Hemlock
Description: Minimalistic addon to automate poison buying and creation
Dependencies: AceLibrary, Dewdrop-2.0
]]--

--[[*** Configuration ***]]--

--[[
	-- Item IDs - using these precludes the need to hardcode icon paths or localize item names.
	Crippling: 3775
	Instant: 6947
	Wound: 10918
	Mind-numbing: 5237
	Anesthetic: 21835
	Deadly: 2892

	-- I need the Deathweed to check if it's a poison vendor. Yay for locale-agnostic code!
	Deathweed: 5173

	These are the IDs of items that Hemlock should check to decide if we have an empty cache or not.
	It's not foolproof, but it should help a bit.
]]--
local safeIDs = {6947, 5173, 3775}

--[[ These should be the rank 1 poison IDs - ie, without a rank suffix! ]]--
local poisonIDs = {6947, 2892, 3775, 10918, 5237}

--[[ These are all the Wound Poison item IDs, used for alternative icon ]]--
local woundPoisonIDs = {10918,10920,10921,10922}

--[[ Flash powder. Don't need anything else right now. ]]--
local reagentIDs = {5140}

--[[*** End Configuration ***]]--

Hemlock = LibStub("AceAddon-3.0"):NewAddon("Hemlock", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")


local defaults = {
  profile = {
	poisonRequirements = {},
	reagentRequirements = {},
	autoBuy = {},
	dontUse = {},
	options = {}
  }
}

function Hemlock:Register()
	local options = {
	type='group',
	args = {
		scan = {
			type = "execute",
			func = function() Hemlock:ScanPoisons(1) end,
			name = self:L("Scan_Poisons"),
			desc = self:L("Scan_Poison_Desc")
		},
		reset = {
			type = "execute",
			func = function() Hemlock:Reset() end,
			name = self:L("cmd_reset"),
			desc = self:L("cmd_reset_desc"),
		},
		options = {
			type = "execute",
			func = function() InterfaceOptionsFrame_OpenToCategory(frame); InterfaceOptionsFrame_OpenToCategory(frame); end,
			name = self:L("cmd_options"),
			desc = self:L("cmd_options_desc"),
		},
		icon = {
			type = "execute",
			func = function() 
				if Hemlock.db.profile.options.alternativeWoundPoisonIcon == true then 
					local optionName = self:L("option_alternativeWoundPoisonIcon")
					local optionState = self:L("option_StateOff")
					Hemlock.db.profile.options.alternativeWoundPoisonIcon = false
					Hemlock:Print(optionName,"-|cffffd200",optionState.."|r")
					self:InitFrames()
				else
					local optionName = self:L("option_alternativeWoundPoisonIcon")
					local optionState = self:L("option_StateOn")
					Hemlock.db.profile.options.alternativeWoundPoisonIcon = true
					Hemlock:Print(optionName,"-|cffffd200",optionState.."|r")
					self:InitFrames()
				end
				Hemlock:RefreshOptions()
			end,
			name = self:L("option_alternativeWoundPoisonIcon"),
			desc = self:L("option_alternativeWoundPoisonIcon_desc"),
		},
		messages = {
			type = "execute",
			func = function() 
				if Hemlock.db.profile.options.chatMessages == true then 
					local optionName = self:L("option_chatMessages")
					local optionState = self:L("option_StateOff")
					Hemlock.db.profile.options.chatMessages = false
					Hemlock:Print(optionName,"-|cffffd200",optionState.."|r")
				else
					local optionName = self:L("option_chatMessages")
					local optionState = self:L("option_StateOn")
					Hemlock.db.profile.options.chatMessages = true
					Hemlock:Print(optionName,"-|cffffd200",optionState.."|r")
				end
				Hemlock:RefreshOptions()
			end,
			name = self:L("option_chatMessages"),
			desc = self:L("option_chatMessages_desc"),
		},
		smart = {
			type = "execute",
			func = function() 
				if Hemlock.db.profile.options.smartPoisonCount == true then 
					local optionName = self:L("option_smartPoisonCount")
					local optionState = self:L("option_StateOff")
					Hemlock.db.profile.options.smartPoisonCount = false
					Hemlock:Print(optionName,"-|cffffd200",optionState.."|r")
					self:InitFrames()
				else
					local optionName = self:L("option_smartPoisonCount")
					local optionState = self:L("option_StateOn")
					Hemlock.db.profile.options.smartPoisonCount = true
					Hemlock:Print(optionName,"-|cffffd200",optionState.."|r")
					self:InitFrames()
				end
				Hemlock:RefreshOptions()
			end,
			name = self:L("option_smartPoisonCount"),
			desc = self:L("option_smartPoisonCount_desc"),
		},
		confirmation = {
			type = "execute",
			func = function() 
				if Hemlock.db.profile.options.buyConfirmation == true then 
					local optionName = self:L("option_buyConfirmation")
					local optionState = self:L("option_StateOff")
					Hemlock.db.profile.options.buyConfirmation = false
					Hemlock:Print(optionName,"-|cffffd200",optionState.."|r")
					self:InitFrames()
				else
					local optionName = self:L("option_buyConfirmation")
					local optionState = self:L("option_StateOn")
					Hemlock.db.profile.options.buyConfirmation = true
					Hemlock:Print(optionName,"-|cffffd200",optionState.."|r")
					self:InitFrames()
				end
				Hemlock:RefreshOptions()
			end,
			name = self:L("option_buyConfirmation"),
			desc = self:L("option_buyConfirmation_desc"),
		}
	}
	}

	for k, v in pairs(self.db.profile.poisonRequirements) do
		options.args[gsub(k, " ", "")] = {
			type = "group",
			name = k,
			desc = self:L("cmd_poison_description"),
			args = {
				amount = {
					type = 'range',
					name = k,
					min = 0,
					max = 100,
					step = 5,
					isPercent = false,
					desc = self:L("specify_make", k),
					get = function()
						return self.db.profile.poisonRequirements[k]
					end,
					set = function(_,v2)
						self.db.profile.poisonRequirements[k] = v2
						self:InitFrames()
					end
				},
				exclude = {
					type = "toggle",
					name = self:L("dont_include", k),
					desc = self:L("dont_include_desc", k),
					get = function()
						return self.db.profile.dontUse[k]
					end,
					set = function(_,v2)
						self.db.profile.dontUse[k] = v2
						self:InitFrames()
					end
				}
			}
		}
	end

	for k, v in pairs(self.db.profile.reagentRequirements) do
		options.args[gsub(k, " ", "")] = {
			type = "group",
			name = k,
			desc = self:L("cmd_reagent_description"),
			args = {
				amount = {
					type = 'range',
					name = k,
					min = 0,
					max = 100,
					step = 5,
					isPercent = false,
					desc = self:L("specify_make", k),
					get = function()
						return self.db.profile.reagentRequirements[k]
					end,
					set = function(_,v2)
						self.db.profile.reagentRequirements[k] = v2
						self:InitFrames()
					end
				},
				exclude = {
					type = "toggle",
					name = self:L("dont_include", k),
					desc = self:L("dont_include_desc", k),
					get = function()
						return self.db.profile.dontUse[k]
					end,
					set = function(_,v2)
						self.db.profile.dontUse[k] = v2
						self:InitFrames()
					end
				},
				autobuy = {
					type = "toggle",
					name = self:L("autobuy", k),
					desc = self:L("autobuy_desc", itemName, k),
					get = function() return self.db.profile.autoBuy[k] end,
					set	= function(_,v) self.db.profile.autoBuy[k] = v end
				}
			}						
		}
	end
	LibStub("AceConfig-3.0"):RegisterOptionsTable("Hemlock", options, {"Hemlock"})
	self.db:RegisterDefaults(defaults)
end

function Hemlock:InitializeDB()

for k,v in ipairs(poisonIDs) do
	local item = Item:CreateFromItemID(v)
	item:ContinueOnItemLoad(function()
		local itemName = GetItemInfo(v)	
		defaults.profile.poisonRequirements[itemName] = 0
	end)
end

for k,v in ipairs(reagentIDs) do
	local item = Item:CreateFromItemID(v)
	item:ContinueOnItemLoad(function()
		local itemName = GetItemInfo(v)	
		defaults.profile.reagentRequirements[itemName] = 0
	end)
end

self.db.defaults.profile.options.smartPoisonCount = false
defaults.profile.options.chatMessages = true
self.db.defaults.profile.options.buyConfirmation = true
self.db.defaults.profile.options.alternativeWoundPoisonIcon = false
end

function Hemlock:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("HemlockDB", defaults, true)
	self.db = LibStub("AceDB-3.0"):New("HemlockDBPC", defaults, true)
	self:InitializeDB()
	-- C_Timer.After(0.2, function() -- Delay to cache items
		self:Register()
	-- end)
	-- self:Print("Hemlock is initializing")
	self:ConfirmationPopupCheckbox()
	confirmationCheckBoxFrame:Hide()
	self.enabled = false
	self:RegisterEvent("MERCHANT_SHOW");
	self:RegisterEvent("MERCHANT_CLOSED");
	self:RegisterEvent("BAG_UPDATE");
	self:RegisterEvent("PLAYER_LOGIN");
	self.frameIndex = 0
	self.frames = {}
	self.inited = false
end

function Hemlock:PLAYER_LOGIN()
	
	-- Detect whether or not we know poison.
	for i = 1, MAX_SKILLLINE_TABS do
		local name, texture, offset, numSpells = GetSpellTabInfo(i);
		if not name then
			break;
		end
		for s = offset + 1, offset + numSpells do
			local spell, rank = GetSpellBookItemName(s, BOOKTYPE_SPELL);
			local texture = GetSpellTexture(s, BOOKTYPE_SPELL)
			if strfind(texture, "136242") then
				self.poisonSpellName = spell
				break
			end
		end
		if self.poisonSpellName then break end
	end
	
	if not self.poisonSpellName then return end
	for k,v in ipairs(safeIDs) do
		local item = Item:CreateFromItemID(v)
		item:ContinueOnItemLoad(function()
			local itemName = GetItemInfo(v)	
			if not GetItemInfo(v) then
				StaticPopup_Show("HEMLOCK_NOTIFY_NEED_SCAN")
			end
		end)	
	end
	
	-- Backward compatibility
	if Hemlock.db.profile.options.smartButtonCount == true then 
		Hemlock.db.profile.options.smartPoisonCount = true
		Hemlock.db.profile.options.smartButtonCount = nil
	end
end

function Hemlock:MakeFrame(itemID, space, lastFrame, frameType)
	local woundPoison = false
	local alternativeWoundPoisonIcon = Hemlock.db.profile.options.alternativeWoundPoisonIcon
	local itemName, _, _, _, _, _, _, _, _, invTexture = GetItemInfo(itemID)

	for k,v in ipairs(woundPoisonIDs) do
		if itemID == v then
			woundPoison = true
		end
	end

	if not itemName then return nil end
	if not self.db.profile.poisonRequirements[itemName] then
		self.db.profile.poisonRequirements[itemName] = 0
	end	

	local f = getglobal("HemlockPoisonButton" .. itemID)
	if not f then
		f = CreateFrame("Button", "HemlockPoisonButton" .. itemID, HemlockFrame, "HemlockPoisonTemplate")
		tinsert(self.frames, f)
	end
	if self.frameIndex == 0 then
		f:SetPoint("TOP", HemlockFrame, "TOP", 0, space)
	else
		f:SetPoint("TOP", lastFrame, "BOTTOM", 0, space)
	end

	if (alternativeWoundPoisonIcon and woundPoison) then
		f:SetNormalTexture(134197)
	else
		f:SetNormalTexture(invTexture)
	end
	f:Show()
	f.tooltipText = itemName
	
	local menu = {}
	if frameType == 1 then
		menu = {
			type = "group",
			args = {
				slider = {
					type = 'range',
					name = "|cffffffff" .. itemName,
					desc = "|cffffd200" .. self:L("specify_make", itemName),
					min = 0,
					max = 100,
					step = 5,
					order = 200,
					isPercent = false,
					get = function()
						return self.db.profile.poisonRequirements[itemName]
					end,
					set = function(_,v2)
						self.db.profile.poisonRequirements[itemName] = v2
						self:InitFrames()
					end,
				},
				exclude = {
					type = "toggle",
					name = "|cffffffff" .. self:L("dont_include", itemName),
					desc = "|cffffd200" .. self:L("dont_include_desc", itemName),
					get = function()
						return self.db.profile.dontUse[itemName]
					end,
					set = function(_,v2)
						self.db.profile.dontUse[itemName] = v2
						commanddItemName = itemName:gsub("%s+", "")
						local buttonStatus = self.db.profile.dontUse[itemName]
						if (buttonStatus) then
							Hemlock:PrintMessage(self:L("exclude_message", commanddItemName))
						end
						self:InitFrames()
					end
				},				
			}
		}
		Hemlock:ButtonText(f,itemName,frameType)
		
		f:RegisterForClicks("LeftButtonUp", "RightButtonUp");		
		f:SetScript("OnEnter", function()
				if (LDDMenu) then
					LDDMenu:Release();
				end
				GameTooltip:Hide();
				GameTooltip:SetOwner(UIParent,"ANCHOR_NONE");
				GameTooltip:SetPoint("LEFT", "HemlockPoisonButton" .. itemID, "RIGHT",3, 0);
				GameTooltip:SetText(f.tooltipText, 1, 1, 1);
				GameTooltip:AddLine (self:L("clicktobuy"));
				if Hemlock.db.profile.options.smartPoisonCount then
					GameTooltip:AddLine (self:L("clicktosetsmart",itemName,self.db.profile.poisonRequirements[itemName],self:GetPoisonsInInventory(itemName)));
				else
					GameTooltip:AddLine (self:L("clicktoset",itemName));
				end
		end)
		f:SetScript("OnClick", function(self, button)
			if (button == "LeftButton") then
				if TradeSkillFrame and TradeSkillFrame:IsVisible() then
					Hemlock:GetNeededPoisons(itemName, f)
				else
					CastSpellByName(Hemlock.poisonSpellName)
					C_Timer.After(0.1, function() 
						Hemlock:GetNeededPoisons(itemName, f) 
					end)
				end
			end
			if (button == "RightButton") then
				GameTooltip:Hide();
				LDDMenu = LibStub("LibDropdown-1.0"):OpenAce3Menu(menu)
				LDDMenu:SetPoint("TOPLEFT", "HemlockPoisonButton" .. itemID, "TOPRIGHT", 3, 1);
			end
		end)
	else
		menu = {
			type = "group",
			args = {
				slider = {
					type = 'range',
					name = "|cffffffff" .. itemName,
					desc = "|cffffd200" .. self:L("specify_make", itemName),
					min = 0,
					max = 100,
					step = 5,
					isPercent = false,
					order = 200,
					get = function()
						return self.db.profile.reagentRequirements[itemName]
					end,
					set = function(_,v2)
						self.db.profile.reagentRequirements[itemName] = v2
						self:InitFrames()
					end
				},
				autobuy = {
					type = "toggle",
					name = "|cffffffff" .. self:L("autobuy"),
					desc = "|cffffd200" .. self:L("autobuy_desc", itemName),
					get  = function() return self.db.profile.autoBuy[itemName] end,
					set	= function(_,v) self.db.profile.autoBuy[itemName] = v end
				},
				exclude = {
					type = "toggle",
					name = "|cffffffff" .. self:L("dont_include", itemName),
					desc = "|cffffd200" .. self:L("dont_include_desc", itemName),
					get = function()
						return self.db.profile.dontUse[itemName]
					end,
					set = function(_,v2)
						self.db.profile.dontUse[itemName] = v2
						commanddItemName = itemName:gsub("%s+", "")
						local buttonStatus = self.db.profile.dontUse[itemName]
						if (buttonStatus) then
							Hemlock:PrintMessage(self:L("exclude_message", commanddItemName))
						end
						self:InitFrames()
					end
				}				
			}
		}

		Hemlock:ButtonText(f,itemName,frameType)
		
		f:RegisterForClicks("LeftButtonUp", "RightButtonUp");		
		f:SetScript("OnEnter", function()
				if (LDDMenu) then
					LDDMenu:Release();
				end
				GameTooltip:Hide();
				GameTooltip:SetOwner(UIParent,"ANCHOR_NONE");
				GameTooltip:SetPoint("LEFT", "HemlockPoisonButton" .. itemID, "RIGHT", 3, 0);
				GameTooltip:SetText(f.tooltipText, 1, 1, 1);
				GameTooltip:AddLine (self:L("clicktobuy"));
				if Hemlock.db.profile.options.smartPoisonCount then
					GameTooltip:AddLine (self:L("clicktosetsmart",itemName,self.db.profile.reagentRequirements[itemName],GetItemCount(itemName)));
				else
					GameTooltip:AddLine (self:L("clicktoset",itemName));
				end
		end)
		f:SetScript("OnClick", function(self, button)
			if (button == "LeftButton") then
				local toBuy = Hemlock.db.profile.reagentRequirements[itemName] - GetItemCount(itemName)
				if toBuy > 0 then
					f:Disable()
					f:GetNormalTexture():SetDesaturated(true)
					toBuyTimer = true
					Hemlock:BuyVendorItem(itemName, toBuy)
				else
					Hemlock:PrintMessage(Hemlock:L("skippingReagent", itemName, Hemlock.db.profile.reagentRequirements[itemName], GetItemCount(itemName)))
					PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
				end
			end
			if (button == "RightButton") then
				GameTooltip:Hide();
				LDDMenu = LibStub("LibDropdown-1.0"):OpenAce3Menu(menu)
				LDDMenu:SetPoint("TOPLEFT", "HemlockPoisonButton" .. itemID, "TOPRIGHT", 3, 1);
			end
		end)
	end

	f.item_id = itemID
	f.item_type = frameType
	if self.db.profile.dontUse[itemName] then
		f:Hide()
		return nil
	end
	self.frameIndex = self.frameIndex + 1
	return f
end

function Hemlock:InitFrames()
	local lastFrame = nil
	local space = -3

	self.frameIndex = 0

	for k,v in pairs(poisonIDs) do
		local lf = Hemlock:MakeFrame(v, space, lastFrame, 1)
		if lf then lastFrame = lf end
	end

	for k,v in pairs(reagentIDs) do
		local lf = Hemlock:MakeFrame(v, space, lastFrame, 2)
		if lf then lastFrame = lf end
	end
	if lastFrame then
		HemlockFrame:SetHeight((lastFrame:GetHeight() + math.abs(space)) * self.frameIndex + math.abs(space))
	else
		Hemlock:Reset()
	end
end

function Hemlock:OnEnable()
	self.enabled = true
end

function Hemlock:OnDisable()
	self.enabled = false
end

function Hemlock:Reset()
	self.db.profile.dontUse = {}
	self:InitFrames()
	self:Print(self:L("cmd_reset_message"))
end

function Hemlock:PrintMessage(text,arg)
	if (Hemlock.db.profile.options.chatMessages) then
		if arg then
			Hemlock:Print(text, arg)
		else
			Hemlock:Print(text)
		end
	end
end

function Hemlock:ButtonText(f,itemName,frameType)
	if frameType == 1 then
		local poisonRequirement = self.db.profile.poisonRequirements[itemName]
		local poisonInventory = self:GetPoisonsInInventory(itemName)
		if (poisonRequirement > poisonInventory) then
			color = "|cffff0055"
		else
			color = "|cff00C621"
		end	
		
		if (Hemlock.db.profile.options.smartPoisonCount and poisonRequirement and poisonInventory) then
			poisonSmartText = poisonRequirement - poisonInventory
			if poisonSmartText < 1 then
				poisonSmartText = 0
			end
			f:SetText(color .. poisonSmartText)
		else
			f:SetText(poisonRequirement .. "\n" .. color .. poisonInventory)
		end
	else
		local reagentRequirements = self.db.profile.reagentRequirements[itemName] or 0
		local reagentInventory = GetItemCount(itemName) or 0
		if (reagentRequirements > reagentInventory) then
			color = "|cffff0055"
		else
			color = "|cff00C621"
		end
	
		if (Hemlock.db.profile.options.smartPoisonCount and reagentRequirements and reagentInventory) then
			reagentSmartText = reagentRequirements - reagentInventory
			if reagentSmartText < 1 then
				reagentSmartText = 0
			end
			f:SetText(color .. reagentSmartText)
		else
			f:SetText(reagentRequirements .. "\n" .. color .. reagentInventory)
		end
	end
end

function Hemlock:ConfirmationPopup(popupText,frame,pName)
	StaticPopupDialogs["HEMLOCK_CONFIRMATION"] = {
		text = "|cff55ff55Hemlock|r\n" .. popupText,
		button1 = self:L("popup_buy"),
		button2 = self:L("popup_cancel"),
		OnAccept = function()
			Hemlock:ConfirmationPopupAccepted(frame,pName)
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
	StaticPopup_Show ("HEMLOCK_CONFIRMATION")
	local checkboxState = Hemlock.db.profile.options.buyConfirmation
	if checkboxState then checkboxState = false else checkboxState = true end
	confirmationCheckBox:SetChecked(checkboxState);
	confirmationCheckBoxFrame:Show()
end

function Hemlock:ConfirmationPopupAccepted(frame,pName)
	frame:Disable()
	frame:GetNormalTexture():SetDesaturated(true)
	toBuyTimer = true

	for rName, rToBuy in pairs(buyTable) do
		if rName then
			local buyResult = self:BuyVendorItem(rName, rToBuy)
			if not buyResult then
				Hemlock:PrintMessage(self:L("unableToBuy", rToBuy, pName))
				noMessage = true
			else
				noMessage = false
			end
		end
	end
	if not noMessage then
		Hemlock:PrintMessage(self:L("pleasepress",  pName))
		return
	end
end

function Hemlock:ConfirmationPopupCheckbox()
	confirmationCheckBox = CreateFrame("CheckButton", "confirmationCheckBoxFrame", StaticPopup3, "ChatConfigCheckButtonTemplate");
	confirmationCheckBox:SetPoint("TOPRIGHT", -8.5, -8.5);
	confirmationCheckBoxFrame:SetScale(0.92);
	confirmationCheckBoxFrameText:SetText(self:L("popup_checkBoxText"));
	confirmationCheckBoxFrameText:SetFont("Fonts\\FRIZQT__.TTF", 9.5)
	confirmationCheckBoxFrameText:SetPoint("LEFT", -23, 0);
	confirmationCheckBox.tooltip = self:L("popup_checkBox");
	confirmationCheckBox:SetScript("OnClick", function(self)
		local value = self:GetChecked()
		if value then value = false else value = true end
		Hemlock.db.profile.options.buyConfirmation = value
		Hemlock:RefreshOptions()
		PlaySound(856)
	end);
end

function Hemlock:RefreshOptions()
	-- Verify if the options are loaded
	if HemlockCheckBoxSmartPoisonCount then
		HemlockCheckBoxSmartPoisonCount:SetChecked(Hemlock.db.profile.options.smartPoisonCount)
		HemlockCheckBoxChatMessages:SetChecked(Hemlock.db.profile.options.chatMessages)
		HemlockCheckBoxAlternativeWoundPoisonIcon:SetChecked(Hemlock.db.profile.options.alternativeWoundPoisonIcon)
		HemlockCheckBoxBuyConfirmation:SetChecked(Hemlock.db.profile.options.buyConfirmation)
	end
end
function Hemlock:MERCHANT_SHOW()
	local localclass, trueclass = UnitClass("player")

	if trueclass ~= "ROGUE" or not self.poisonSpellName or not IsUsableSpell(self.poisonSpellName) or not self.enabled then return end

	if not self.inited then
		self:InitFrames()
		self.inited = true
	end
	HemlockFrame:Hide()

	for itemName, v in pairs(self.db.profile.autoBuy) do
		if v then
			local toBuy = self.db.profile.reagentRequirements[itemName] - GetItemCount(itemName)
			if toBuy > 0 then
				Hemlock:BuyVendorItem(itemName, toBuy)
			end
		end
	end

	local haveNils = false
	self.claimedReagents = {}
	for i = 1, GetMerchantNumItems() do
		local id = GetMerchantItemID(i)
		local item = Item:CreateFromItemID(id)	
		item:ContinueOnItemLoad(function()
			local link = GetMerchantItemLink(i)
			-- If this is a deathweed vendor, we'll assume he's selling poison.
			if link and strfind(link, "Hitem:5173:") then
				HemlockFrame:Show()
				Hemlock:BAG_UPDATE()
				return
			elseif not link then
				haveNils = true
			end
		end)
	end
	-- We are not supposed to see this anymore since we are using ContinueOnItemLoad
	if haveNils then
		self:Print(self:L("cached_data_warning"))
	end
end

function Hemlock:MERCHANT_CLOSED()
	local popup_confirmation = StaticPopupDialogs["HEMLOCK_CONFIRMATION"]
	if popup_confirmation then
		confirmationCheckBoxFrame:Hide()
		StaticPopup_Hide("HEMLOCK_CONFIRMATION");
	end
end

function Hemlock:BAG_UPDATE(bag_id)
	if HemlockFrame:IsVisible() then
		for k, f in pairs(self.frames) do
			if f then
				local item = Item:CreateFromItemID(f.item_id)	
				item:ContinueOnItemLoad(function()
					local itemName, _, _, _, _, _, _, _, _, invTexture = GetItemInfo(f.item_id)
					if f.item_type == 1 then
						Hemlock:ButtonText(f,itemName,f.item_type)
					elseif f.item_type == 2 then
						Hemlock:ButtonText(f,itemName,f.item_type)					
					end
					if not toBuyTimer then
						f:Enable()
						f:GetNormalTexture():SetDesaturated(false)
					else
						self:ScheduleTimer((function() f:Enable(); f:GetNormalTexture():SetDesaturated(false); toBuyTimer = false; end), 0.5)
					end
				end)
			end
		end
	end
end

function Hemlock:GetPoisonsInInventory(name)
	local totalCount = 0
	local rankStrings = {" X", " IX", " VIII", " VII", " VI", " V", " IV", " III", " II", "I", ""}
	for idx, str in ipairs(rankStrings) do
		itemName = name .. str
		count = GetItemCount(itemName)  or 0
		totalCount = totalCount + count
	end
	if totalCount > 0 then
		return totalCount
	else
		return 0
	end
end

function Hemlock:GetMaxPoisonRank(poisonName)
	local ranks = {}
	-- TradeSkillFilterDropDown:SetChecked(false)
	poisonName = gsub(poisonName, "%-", "%%%-")
	for i = 1, GetNumTradeSkills() do
		local name, type = GetTradeSkillInfo(i)
		if type ~= "header" then
			if strfind(name, poisonName, 1) then
				tinsert(ranks, {name, i})
			end
		end
	end

	-- 20 is way more than we need, but eh.
	local rankStrings = {"XX", "XIX", "XVIII", "XVII", "XVI", "XV", "XIV", "XIII", "XII", "XI", "X", "IX", "VIII", "VII", "VI", "V", "IV", "III", "II", "I"}
	for idx, str in ipairs(rankStrings) do
		for k, v in ipairs(ranks) do
			if v[1] == poisonName .. " " .. str then
				return v[1], v[2]
			end
		end
	end
	return ranks[1][1], ranks[1][2]
end

function Hemlock:BuyVendorItem(pName, count, countTo)
	if MerchantFrame:IsVisible() then
		for i = 1, GetMerchantNumItems() do
			local name, tex, price, qty, available, usable = GetMerchantItemInfo(i)
			if name then
				local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, invTexture = GetItemInfo(GetMerchantItemLink(i))
				if name == pName then
					local ct = 0
					if count == nil and countTo ~= nil and GetMerchantItemLink(i) ~= nil then 
						local pCt = GetItemCount(GetMerchantItemLink(i))
						ct = pCt - countTo
					elseif count then
						ct = count
					end
					-- Hemlock:Print("|cff7777ffPlanned:",ct.."x"..itemLink);
					while ct > 0 do
						if (ct > itemStackCount) then
							ctam = itemStackCount
							-- Hemlock:Print("|cffff7777Buying stack:",ctam.."x".. itemName)
						else
							ctam = ct
							-- Hemlock:Print("|cff77ff77Last items:",ctam.."x".. itemName)
						end
						ct = ct - ctam
						-- Hemlock:Print("Need to buy:",ct.."x".. itemName);
						BuyMerchantItem(i, ctam)
					end
					return ct
				end
			end
		end
	end
	return false
end

function Hemlock:GetNeededPoisons(name, frame)
	local v = name
	local amt = self.db.profile.poisonRequirements[name]
	local poison, skillIndex = self:GetMaxPoisonRank(v)
	local buyConfirmation = Hemlock.db.profile.options.buyConfirmation
	local popupText = ""
	buyTable = {}
	noMessage = false
	if not self.claimedReagents[skillIndex] then self.claimedReagents[skillIndex] = {} end

	if poison then
		-- local count = GetItemCount(GetTradeSkillItemLink(skillIndex))
		local count = Hemlock:GetPoisonsInInventory(name)
		local toMake = math.ceil((amt - count) / GetTradeSkillNumMade(skillIndex))
		if toMake > 0 then
			for i = 1, GetTradeSkillNumReagents(skillIndex) do
				local reagentName, reagentTexture, reagentCount, playerReagentCount = GetTradeSkillReagentInfo(skillIndex, i)
				local toBuy = (reagentCount * toMake)
				local need = toBuy
				for k,v in pairs(self.claimedReagents) do
					if v[reagentName] and k ~= skillIndex and playerReagentCount < 0 then
						playerReagentCount = playerReagentCount - v[reagentName]
					end
				end
				toBuy = toBuy - playerReagentCount
				if toBuy > 0 then
					buyTable[reagentName] = toBuy
					noMessage = true
				else
					self.claimedReagents[skillIndex][reagentName] = need
				end
			end
			
			if not noMessage then
				for i = 1, GetTradeSkillNumReagents(skillIndex) do
					local reagentName, reagentTexture, reagentCount, playerReagentCount = GetTradeSkillReagentInfo(skillIndex, i)
				end
				DoTradeSkill(skillIndex, toMake)
				self.claimedReagents[skillIndex] = nil
				return
			end

		else
			Hemlock:PrintMessage(self:L("skipping", name, amt, count))
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
		end

	end
	for rName, rToBuy in pairs(buyTable) do
		if rName then
			popupText = popupText .. "\n" .. rName .. "|cffffd200 x " .. rToBuy .. "|r"
		end
	end
	if popupText ~= "" then
		if buyConfirmation then
			Hemlock:ConfirmationPopup(popupText,frame,name)
		else
			Hemlock:ConfirmationPopupAccepted(frame,name)
		end
	end
end

function Hemlock:L(str, ...)
	local s = nil
	if HemlockLocalization[GetLocale()] and HemlockLocalization[GetLocale()][str] then
		s = HemlockLocalization[GetLocale()][str]
	elseif HemlockLocalization["enUS"] and HemlockLocalization["enUS"][str] then
		s = HemlockLocalization["enUS"][str]
	else
		s = "INVALID LOCALIZATION KEY: " .. str
	end
	for k,v in pairs({...}) do
		s = gsub(s, "$S", v, 1)
	end
	return s
end

-- This really doesn't work very well.
function Hemlock:ScanPoisons(step)
	if step == 1 then
		for i=1,3 do
			CastSpellByName(self.poisonSpellName)
			if TradeSkillFrame and TradeSkillFrame:IsVisible() then
				break
			end
		end
		-- CastSpellByName(self.poisonSpellName) -- this is closing the window...
		self:Print(self:L("scan_step_1", "[1/3]"))
		self:ScheduleTimer(function() self:ScanPoisons(2) end, 2)	 
	end

	-- TradeSkillFilterDropDown:SetChecked(false)
	if step == 2 or step == 3 then
		GameTooltip:SetOwner(UIParent, "ANCHOR_LEFT")
		for i = 1, GetNumTradeSkills() do
			local skillName, skillType, numAvailable, isExpanded = GetTradeSkillInfo(i)
			if skillType ~= "header" then
				GameTooltip:SetTradeSkillItem(i)
				local link = GetTradeSkillItemLink(i)
				GameTooltip:Hide()
			end
		end
		if step == 2 then
			self:Print(self:L("scan_step_2", "[2/3]"))
		end
		-- self:ScheduleEvent(function() self:ScanPoisons(step + 1) end, 2)
		self:ScheduleTimer(function() self:ScanPoisons(step + 1) end, 2)
	end

	if step == 4 then
		GameTooltip:SetOwner(UIParent, "ANCHOR_LEFT")
		for i = 1, GetNumTradeSkills() do
			local skillName, skillType, numAvailable, isExpanded = GetTradeSkillInfo(i)
			if skillType ~= "header" then
				GameTooltip:SetTradeSkillItem(i)
				local link = GetTradeSkillItemLink(i)
				if link then
					for n = 1,2 do
						for j = 1, GetTradeSkillNumReagents(i) do
								GameTooltip:SetTradeSkillItem(i, j)
								link = GetTradeSkillReagentItemLink(i, j)
								GameTooltip:Hide()
						end
					end
				end
			end
		end
		self:Print(self:L("scan_step_3", "[3/3]"))
	end
end

StaticPopupDialogs["HEMLOCK_NOTIFY_NEED_SCAN"] = {
	text = Hemlock:L("need_scan"),
	button1 = "YES",
	button2 = "NO",
	timeout = 0,
	showAlert = 1,
	hideOnEscape = 1,
	OnAccept = function() Hemlock:ScanPoisons(1) end
};