if (select(2, UnitClass("player"))) ~= "ROGUE" then return end

--[[
Name: Hemlock
Revision: $Rev: 1 $
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

--[[ Flash powder. Don't need anything else right now. ]]--
local reagentIDs = {5140}

--[[*** End Configuration ***]]--

Hemlock = LibStub("AceAddon-3.0"):NewAddon("Hemlock", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")


local defaults = {
  profile = {
	poisonRequirements = {},
	reagentRequirements = {},
	autoBuy = {},
	dontUse = {}
  }
}

function Hemlock:Register()
	local options = {
	type='group',
	args = {
		scan = {
			type = "execute",
			func = function() Hemlock:ScanPoisons(1) end,
			name = self:L("Scan Poisons"),
			desc = self:L("Scan Poison Desc")
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
		print(itemName)
		defaults.profile.reagentRequirements[itemName] = 0
	end)
end
end

function Hemlock:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("HemlockDB", defaults, true)
	self.db = LibStub("AceDB-3.0"):New("HemlockDBPC", defaults, true)
	self:InitializeDB()
	C_Timer.After(0.2, function() -- Delay to cache items
		self:Register()
	end)
	-- self:Print("Hemlock is initializing")
	self.enabled = false
	self:RegisterEvent("MERCHANT_SHOW");
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
end

function Hemlock:MakeFrame(itemID, space, lastFrame, frameType)
	local itemName, _, _, _, _, _, _, _, _, invTexture = GetItemInfo(itemID)

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
	f:SetNormalTexture(invTexture)
	f:Show()
	f.tooltipText = itemName
	
	local menu = {}
	if frameType == 1 then
		menu = {
			type = "group",
			args = {
				slider = {
					type = 'range',
					name = itemName,
					desc = self:L("specify_make", itemName),
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
					name = self:L("dont_include", itemName),
					desc = self:L("dont_include_desc", itemName),
					get = function()
						return self.db.profile.dontUse[itemName]
					end,
					set = function(_,v2)
						self.db.profile.dontUse[itemName] = v2
						commanddItemName = itemName:gsub("%s+", "")
						local buttonStatus = self.db.profile.dontUse[itemName]
						if (buttonStatus) then
							Hemlock:Print("Type |cffffff78/Hemlock",commanddItemName,"exclude|r to show the icon again.")
						end
						self:InitFrames()
					end
				},				
			}
		}
		
		-- Coloring
		local poisonRequirement = self.db.profile.poisonRequirements[itemName]
		local poisonInventory = self:GetPoisonsInInventory(itemName)
		if (poisonRequirement > poisonInventory) then
			color = "|cffff0055"
		else
			color = "|cff00C621"
		end		
		f:SetText(self.db.profile.poisonRequirements[itemName] .. "\n" .. color .. self:GetPoisonsInInventory(itemName))
		
		f:RegisterForClicks("LeftButtonUp", "RightButtonUp");		
		f:SetScript("OnEnter", function()
				if (LDDMenu) then
					LDDMenu:Release();
				end
				GameTooltip:Hide();
				GameTooltip:SetOwner(UIParent,"ANCHOR_NONE");
				GameTooltip:SetPoint("LEFT", "HemlockPoisonButton" .. itemID, "RIGHT",3, 0);
				GameTooltip:SetText(f.tooltipText);
				GameTooltip:AddLine (self:L("clicktobuy"), 1, 1, 1);
				GameTooltip:AddLine (self:L("clicktoset",itemName), 1, 1, 1);
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
					name = itemName,
					desc = self:L("specify_make", itemName),
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
					name = self:L("autobuy"),
					desc = self:L("autobuy_desc", itemName),
					get  = function() return self.db.profile.autoBuy[itemName] end,
					set	= function(_,v) self.db.profile.autoBuy[itemName] = v end
				},
				exclude = {
					type = "toggle",
					name = self:L("dont_include", itemName),
					desc = self:L("dont_include_desc", itemName),
					get = function()
						return self.db.profile.dontUse[itemName]
					end,
					set = function(_,v2)
						self.db.profile.dontUse[itemName] = v2
						commanddItemName = itemName:gsub("%s+", "")
						local buttonStatus = self.db.profile.dontUse[itemName]
						if (buttonStatus) then
							Hemlock:Print("Type |cffffff78/Hemlock",commanddItemName,"exclude|r to show the icon again.")
						end
						self:InitFrames()
					end
				}				
			}
		}

		-- Coloring
		local reagentRequirements = self.db.profile.reagentRequirements[itemName]
		local reagentInventory = GetItemCount(itemName)
		if (reagentRequirements > reagentInventory) then
			color = "|cffff0055"
		else
			color = "|cff00C621"
		end	
		f:SetText((self.db.profile.reagentRequirements[itemName] or 0) .. "\n" .. color .. GetItemCount(itemName))
		
		f:RegisterForClicks("LeftButtonUp", "RightButtonUp");		
		f:SetScript("OnEnter", function()
				if (LDDMenu) then
					LDDMenu:Release();
				end
				GameTooltip:Hide();
				GameTooltip:SetOwner(UIParent,"ANCHOR_NONE");
				GameTooltip:SetPoint("LEFT", "HemlockPoisonButton" .. itemID, "RIGHT", 3, 0);
				GameTooltip:SetText(f.tooltipText);
				GameTooltip:AddLine (self:L("clicktobuy"), 1, 1, 1);
				GameTooltip:AddLine (self:L("clicktoset",itemName), 1, 1, 1);
		end)
		f:SetScript("OnClick", function(self, button)
			if (button == "LeftButton") then
				local toBuy = Hemlock.db.profile.reagentRequirements[itemName] - GetItemCount(itemName)
				if toBuy > 0 then
					Hemlock:BuyVendorItem(itemName, toBuy)
				else
					Hemlock:Print(Hemlock:L("skippingReagent", itemName, Hemlock.db.profile.reagentRequirements[itemName], GetItemCount(itemName)))
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
	
	HemlockFrame:SetHeight((lastFrame:GetHeight() + math.abs(space)) * self.frameIndex + math.abs(space))
end

function Hemlock:OnEnable()
	self.enabled = true
end

function Hemlock:OnDisable()
	self.enabled = false
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

function Hemlock:BAG_UPDATE(bag_id)
	if HemlockFrame:IsVisible() then
		for k, f in pairs(self.frames) do
			if f then
				local item = Item:CreateFromItemID(f.item_id)	
				item:ContinueOnItemLoad(function()
					local itemName, _, _, _, _, _, _, _, _, invTexture = GetItemInfo(f.item_id)
					if f.item_type == 1 then
						local poisonRequirement = self.db.profile.poisonRequirements[itemName]
						local poisonInventory = self:GetPoisonsInInventory(itemName)
						if (poisonRequirement > poisonInventory) then
							color = "|cffff0055"
						else
							color = "|cff00C621"
						end		
						f:SetText(self.db.profile.poisonRequirements[itemName] .. "\n" .. color .. self:GetPoisonsInInventory(itemName))
					else
						local reagentRequirements = self.db.profile.reagentRequirements[itemName]
						local reagentInventory = GetItemCount(itemName)
						if (reagentRequirements > reagentInventory) then
							color = "|cffff0055"
						else
							color = "|cff00C621"
						end	
						f:SetText((self.db.profile.reagentRequirements[itemName] or 0) .. "\n" .. color .. GetItemCount(itemName))							
					end
					f:Enable()
					f:GetNormalTexture():SetDesaturated(false)
				end)
			end
		end
	end
end

function Hemlock:GetPoisonsInInventory(name)
	local rankStrings = {"XX", "XIX", "XVIII", "XVII", "XVI", "XV", "XIV", "XIII", "XII", "XI", "X", "IX", "VIII", "VII", "VI", "V", "IV", "III", "II", "I"}
	for idx, str in ipairs(rankStrings) do
		if GetItemCount(name .. " " .. str) > 0 then
			return GetItemCount(name .. " " .. str)
		end
	end
	if GetItemCount(name) > 0 then
		return GetItemCount(name)
	end
	return 0
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
	local noMessage = false
	if not self.claimedReagents[skillIndex] then self.claimedReagents[skillIndex] = {} end

	if poison then
		local count = GetItemCount(GetTradeSkillItemLink(skillIndex))
		local toMake = math.ceil((amt - count) / GetTradeSkillNumMade(skillIndex))
		if toMake > 0 then
			for i = 1, GetTradeSkillNumReagents(skillIndex) do
				local reagentName, reagentTexture, reagentCount, playerReagentCount = GetTradeSkillReagentInfo(skillIndex, i)
				local toBuy = (reagentCount * toMake)
				local need = toBuy
				for k,v in pairs(self.claimedReagents) do
					if v[reagentName] and k ~= skillIndex then
						playerReagentCount = playerReagentCount - v[reagentName]
					end
				end
				toBuy = toBuy - playerReagentCount
				if toBuy > 0 then
					frame:Disable()
					frame:GetNormalTexture():SetDesaturated(true)
					self:ScheduleTimer(function() frame:Enable(); frame:GetNormalTexture():SetDesaturated(false) end, 2.5)
					local buyResult = self:BuyVendorItem(reagentName, toBuy)
					if not buyResult then
						Hemlock:Print(self:L("unableToBuy", toBuy, reagentName))
						noMessage = true
					else
						self.claimedReagents[skillIndex][reagentName] = need
					end
				else
					self.claimedReagents[skillIndex][reagentName] = need
				end
			end
			for i = 1, GetTradeSkillNumReagents(skillIndex) do
				local reagentName, reagentTexture, reagentCount, playerReagentCount = GetTradeSkillReagentInfo(skillIndex, i)
				local toBuy = (reagentCount * toMake) - playerReagentCount
				if toBuy > 0 then
					local bags = {0,1,2,3,4}
					for k,v in ipairs(bags) do
						local slots = GetContainerNumSlots(v)
						for j = 1, slots do
								if not noMessage and not GetContainerItemLink(v, j) then
									self:Print(self:L("pleasepress",  name))
									return
								end
						end
					end
					break
				end
			end

			for i = 1, GetTradeSkillNumReagents(skillIndex) do
				local reagentName, reagentTexture, reagentCount, playerReagentCount = GetTradeSkillReagentInfo(skillIndex, i)
			end
				DoTradeSkill(skillIndex, toMake)
				self.claimedReagents[skillIndex] = nil
		else
			Hemlock:Print(self:L("skipping", name, amt, count))
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
				-- self:Print(link);
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