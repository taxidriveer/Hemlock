if (select(2, UnitClass("player"))) ~= "ROGUE" then return end

--[[
Name: Hemlock
Revision: $Rev: 1 $
Developed by: Antiarc
Documentation:
SVN: http://svn.wowace.com/wowace/trunk/Hemlock
Description: Minimalistic addon to automate poison buying and creation
Dependencies: AceLibrary, Dewdrop-2.0
]]--

--[[*** Configuramation ***]]--

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
local poisonIDs = {6947, 2892, 3775, 10918, 5237, 21835}

--[[ Flash powder. Don't need anything else right now. ]]--
local reagentIDs = {5140}

--[[*** End Configuramation ***]]--

Hemlock = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceEvent-2.0", "AceDB-2.0")
if not AceLibrary("Dewdrop-2.0") then error("Hemlock requires Dewdrop-2.0") end
Hemlock:RegisterDB("HemlockDB", "HemlockDBPC")
local dewdrop = AceLibrary("Dewdrop-2.0")

local defaults = {
	poisonRequirements = {},
	reagentRequirements = {},
	autoBuy = {},
	dontUse = {}
}

for k,v in ipairs(poisonIDs) do
	local itemName = GetItemInfo(v)
	if itemName then
		defaults.poisonRequirements[itemName] = 0
	end
end

for k,v in ipairs(reagentIDs) do
	local itemName = GetItemInfo(v)
	if itemName then
		defaults.reagentRequirements[itemName] = 0
	end
end

Hemlock:RegisterDefaults("profile", defaults)
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
			desc = k,
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
					set = function(v2)
						self.db.profile.poisonRequirements[k] = v2
					end
				},
				exclude = {
					type = "toggle",
					name = self:L("dont_include", k),
					desc = self:L("dont_include_desc", k),
					get = function()
						return self.db.profile.dontUse[k]
					end,
					set = function(v2)
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
			desc = k,
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
					set = function(v2)
						self.db.profile.reagentRequirements[k] = v2
					end
				},
				exclude = {
					type = "toggle",
					name = self:L("dont_include", k),
					desc = self:L("dont_include_desc", k),
					get = function()
						return self.db.profile.dontUse[k]
					end,
					set = function(v2)
						self.db.profile.dontUse[k] = v2
						self:InitFrames()
					end
				},
				autobuy = {
					type = "toggle",
					name = self:L("autobuy"),
					desc = self:L("autobuy_desc", itemName),
					get  = function() return self.db.profile.autoBuy[k] end,
					set	= function(v) self.db.profile.autoBuy[k] = v end
				}
			}						
		}
	end

	Hemlock:RegisterChatCommand({"/hemlock"}, options, "HEMLOCK")
end

function Hemlock:OnInitialize()
	self:Register()
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
			local spell, rank = GetSpellName(s, BOOKTYPE_SPELL);
			local texture = GetSpellTexture(s, BOOKTYPE_SPELL)
			-- self:Print(s, spell, rank, texture, strfind(texture, "Trade_BrewPoison"))
			if strfind(texture, "Trade_BrewPoison") then
				self.poisonSpellName = spell
				break
			end
		end
		if self.poisonSpellName then break end
	end
	if not self.poisonSpellName then return end
	for k,v in ipairs(safeIDs) do
		if not GetItemInfo(v) then
			StaticPopup_Show("HEMLOCK_NOTIFY_NEED_SCAN")
			break
		end
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
	f.tooltipText = self:L("clicktobuy") .. "\n" .. self:L("clicktoset",itemName)
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
					set = function(v2)
						self.db.profile.poisonRequirements[itemName] = v2
						dewdrop:GetOpenedParent():SetText(
								Hemlock:GetPoisonsInInventory(itemName) .. "\n" .. Hemlock.db.profile.poisonRequirements[itemName]
						)
					end
				},
				exclude = {
					type = "toggle",
					name = self:L("dont_include", itemName),
					desc = self:L("dont_include_desc", itemName),
					get = function()
						return self.db.profile.dontUse[itemName]
					end,
					set = function(v2)
						self.db.profile.dontUse[itemName] = v2
						self:InitFrames()
					end
				},				
			}
		}

		f:SetText(self:GetPoisonsInInventory(itemName) .. "\n" .. self.db.profile.poisonRequirements[itemName])
		f:SetScript("OnClick", function()
			if TradeSkillFrame and TradeSkillFrame:IsVisible() then
				Hemlock:GetNeededPoisons(itemName, f)
			else
				CastSpellByName(self.poisonSpellName)
				if TradeSkillFrame and not TradeSkillFrame:IsVisible() then
					CastSpellByName(self.poisonSpellName)
				end
				if TradeSkillFrame and TradeSkillFrame:IsVisible() then
					CastSpellByName(self.poisonSpellName)
				end
				Hemlock:GetNeededPoisons(itemName, f)
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
					set = function(v2)
						self.db.profile.reagentRequirements[itemName] = v2
						dewdrop:GetOpenedParent():SetText(
								GetItemCount(itemName) .. "\n" .. Hemlock.db.profile.reagentRequirements[itemName]
						)
					end
				},
				autobuy = {
					type = "toggle",
					name = self:L("autobuy"),
					desc = self:L("autobuy_desc", itemName),
					get  = function() return self.db.profile.autoBuy[itemName] end,
					set	= function(v) self.db.profile.autoBuy[itemName] = v end
				},
				exclude = {
					type = "toggle",
					name = self:L("dont_include", itemName),
					desc = self:L("dont_include_desc", itemName),
					get = function()
						return self.db.profile.dontUse[itemName]
					end,
					set = function(v2)
						self.db.profile.dontUse[itemName] = v2
						self:InitFrames()
					end
				}				
			}
		}

		f:SetText(GetItemCount(itemName) .. "\n" .. (self.db.profile.reagentRequirements[itemName] or 0))
		f:SetScript("OnClick", function()
			local toBuy = self.db.profile.reagentRequirements[itemName] - GetItemCount(itemName)
			if toBuy > 0 then
				Hemlock:BuyVendorItem(itemName, toBuy)
			else
				Hemlock:Print(self:L("skippingReagent", itemName, self.db.profile.reagentRequirements[itemName], GetItemCount(itemName)))
			end
		end)
	end

	dewdrop:Register(f, 'children', menu, 'point', function(parent) return "TOPLEFT", "TOPRIGHT" end)
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
		local link = GetMerchantItemLink(i)
		-- self:Print(link)
		-- If this is a deathweed vendor, we'll assume he's selling poison.
		if link and strfind(link, "Hitem:5173:") then
			HemlockFrame:Show()
			Hemlock:BAG_UPDATE()
			break
		elseif not link then
			haveNils = true
		end
	end
	if haveNils then
		-- self:Print(self:L("cached_data_warning"))
	end
end

function Hemlock:BAG_UPDATE(bag_id)
	if HemlockFrame:IsVisible() then
		for k, f in pairs(self.frames) do
			if f then
				local itemName, _, _, _, _, _, _, _, _, invTexture = GetItemInfo(f.item_id)
				if f.item_type == 1 then
					f:SetText(self:GetPoisonsInInventory(itemName) .. "\n" .. self.db.profile.poisonRequirements[itemName])
				else
					f:SetText(GetItemCount(itemName) .. "\n" .. self.db.profile.reagentRequirements[itemName])
				end
				f:Enable()
				f:GetNormalTexture():SetDesaturated(false)
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
	TradeSkillFrameAvailableFilterCheckButton:SetChecked(false)
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
						ct = math.ceil(count / qty)
					end
					local ct_h = ct
					while ct > 0 do
						local ctam = 0
						if ct > math.floor(itemStackCount / qty) then
							ctam = math.floor(itemStackCount / qty)
						else
							ctam = ct
						end
						ct = ct - ctam
						BuyMerchantItem(i, ctam)
					end
					return ct_h
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
					self:ScheduleEvent(function() frame:Enable(); frame:GetNormalTexture():SetDesaturated(false) end, 2.5)
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
		CastSpellByName(self.poisonSpellName)
		self:Print(self:L("scan_step_1", "[1/3]"))
		self:ScheduleEvent(function() self:ScanPoisons(2) end, 4)
	end

	TradeSkillFrameAvailableFilterCheckButton:SetChecked(false)
	if step == 2 or step == 3 then
		GameTooltip:SetOwner(UIParent, "ANCHOR_LEFT")
		for i = 1, GetNumTradeSkills() do
			local skillName, skillType, numAvailable, isExpanded = GetTradeSkillInfo(i)
			if skillType ~= "header" then
				GameTooltip:SetTradeSkillItem(i)
				local link = GetTradeSkillItemLink(i)
			end
		end
		if step == 2 then
			self:Print(self:L("scan_step_2", "[2/3]"))
		end
		self:ScheduleEvent(function() self:ScanPoisons(step + 1) end, 2)
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
	button1 = TEXT(YES),
	button2 = TEXT(NO),
	timeout = 0,
	showAlert = 1,
	hideOnEscape = 1,
	OnAccept = function() Hemlock:ScanPoisons(1) end
};