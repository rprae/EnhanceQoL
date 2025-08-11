-- luacheck: globals EnhanceQoL GAMEMENU_OPTIONS STAT_HASTE STAT_MASTERY STAT_VERSATILITY STAT_CRITICAL_STRIKE CR_HASTE_MELEE CR_MASTERY CR_VERSATILITY_DAMAGE_DONE CR_VERSATILITY_DAMAGE_TAKEN CR_CRIT_MELEE
local addonName, addon = ...
local L = addon.L

local AceGUI = addon.AceGUI
local db
local stream

local function ensureDB()
	addon.db.datapanel = addon.db.datapanel or {}
	addon.db.datapanel.stats = addon.db.datapanel.stats or {}
	db = addon.db.datapanel.stats
	db.fontSize = db.fontSize or 14
	db.vertical = db.vertical or false
	db.haste = db.haste or { enabled = true, rating = false }
	db.mastery = db.mastery or { enabled = true, rating = false }
	db.versatility = db.versatility or { enabled = true, rating = false }
	db.crit = db.crit or { enabled = true, rating = false }
end

local function RestorePosition(frame)
	if db.point and db.x and db.y then
		frame:ClearAllPoints()
		frame:SetPoint(db.point, UIParent, db.point, db.x, db.y)
	end
end

local aceWindow
local function addStatOptions(frame, key, label)
	local group = AceGUI:Create("InlineGroup")
	group:SetTitle(label)
	group:SetFullWidth(true)
	group:SetLayout("List")

	local show = AceGUI:Create("CheckBox")
	show:SetLabel("Show")
	show:SetValue(db[key].enabled)
	show:SetCallback("OnValueChanged", function(_, _, val)
		db[key].enabled = val and true or false
		addon.DataHub:RequestUpdate(stream)
	end)
	group:AddChild(show)

	local rating = AceGUI:Create("CheckBox")
	rating:SetLabel("Use rating")
	rating:SetValue(db[key].rating)
	rating:SetCallback("OnValueChanged", function(_, _, val)
		db[key].rating = val and true or false
		addon.DataHub:RequestUpdate(stream)
	end)
	group:AddChild(rating)

	frame:AddChild(group)
end

local function createAceWindow()
	if aceWindow then
		aceWindow:Show()
		return
	end
	ensureDB()
	local frame = AceGUI:Create("Window")
	aceWindow = frame.frame
	frame:SetTitle(GAMEMENU_OPTIONS)
	frame:SetWidth(300)
	frame:SetHeight(500)
	frame:SetLayout("List")

	frame.frame:SetScript("OnShow", function(self) RestorePosition(self) end)
	frame.frame:SetScript("OnHide", function(self)
		local point, _, _, xOfs, yOfs = self:GetPoint()
		db.point = point
		db.x = xOfs
		db.y = yOfs
	end)

	local fontSize = AceGUI:Create("Slider")
	fontSize:SetLabel("Font size")
	fontSize:SetSliderValues(8, 32, 1)
	fontSize:SetValue(db.fontSize)
	fontSize:SetCallback("OnValueChanged", function(_, _, val)
		db.fontSize = val
		addon.DataHub:RequestUpdate(stream)
	end)
	frame:AddChild(fontSize)

	local vertical = AceGUI:Create("CheckBox")
	vertical:SetLabel("Display vertically")
	vertical:SetValue(db.vertical)
	vertical:SetCallback("OnValueChanged", function(_, _, val)
		db.vertical = val and true or false
		addon.DataHub:RequestUpdate(stream)
	end)
	frame:AddChild(vertical)

	addStatOptions(frame, "haste", STAT_HASTE or "Haste")
	addStatOptions(frame, "mastery", STAT_MASTERY or "Mastery")
	addStatOptions(frame, "versatility", STAT_VERSATILITY or "Versatility")
	addStatOptions(frame, "crit", STAT_CRITICAL_STRIKE or "Crit")

	frame.frame:Show()
end

local function formatStat(label, rating, percent)
	if rating then
		return ("%s %d"):format(label, rating)
	else
		return ("%s %.2f%%"):format(label, percent)
	end
end

local function checkStats(stream)
	ensureDB()
	local texts = {}
	local sep = db.vertical and "\n" or " "
	local size = db.fontSize or 14
	stream.snapshot.fontSize = size
	stream.snapshot.tooltip = L["Right-Click for options"]

	if db.haste.enabled then
		local text
		if db.haste.rating then
			text = formatStat(STAT_HASTE or "Haste", GetCombatRating(CR_HASTE_MELEE), nil)
		else
			text = formatStat(STAT_HASTE or "Haste", nil, GetHaste())
		end
		texts[#texts + 1] = text
	end

	if db.mastery.enabled then
		local text
		if db.mastery.rating then
			text = formatStat(STAT_MASTERY or "Mastery", GetCombatRating(CR_MASTERY), nil)
		else
			text = formatStat(STAT_MASTERY or "Mastery", nil, GetMastery())
		end
		texts[#texts + 1] = text
	end

	if db.versatility.enabled then
		local text
		if db.versatility.rating then
			text = formatStat(STAT_VERSATILITY or "Vers", GetCombatRating(CR_VERSATILITY_DAMAGE_DONE), nil)
		else
			local dmg = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) + GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE)
			local red = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_TAKEN) + GetVersatilityBonus(CR_VERSATILITY_DAMAGE_TAKEN)
			text = ("%s %.2f%%/%.2f%%"):format(STAT_VERSATILITY or "Vers", dmg, red)
		end
		texts[#texts + 1] = text
	end

	if db.crit.enabled then
		local text
		if db.crit.rating then
			text = formatStat(STAT_CRITICAL_STRIKE or "Crit", GetCombatRating(CR_CRIT_MELEE), nil)
		else
			text = formatStat(STAT_CRITICAL_STRIKE or "Crit", nil, GetCritChance())
		end
		texts[#texts + 1] = text
	end

	stream.snapshot.text = table.concat(texts, sep)
end

local provider = {
	id = "stats",
	version = 1,
	title = "Stats",
	update = checkStats,
	events = {
		UNIT_SPELL_HASTE = function(stream, _, unit)
			if unit == "player" then addon.DataHub:RequestUpdate(stream) end
		end,
		UNIT_ATTACK_SPEED = function(stream, _, unit)
			if unit == "player" then addon.DataHub:RequestUpdate(stream) end
		end,
		UNIT_STATS = function(stream, _, unit)
			if unit == "player" then addon.DataHub:RequestUpdate(stream) end
		end,
		UNIT_AURA = function(stream, _, unit)
			if unit == "player" then addon.DataHub:RequestUpdate(stream) end
		end,
		COMBAT_RATING_UPDATE = function(stream) addon.DataHub:RequestUpdate(stream) end,
		MASTERY_UPDATE = function(stream) addon.DataHub:RequestUpdate(stream) end,
		PLAYER_EQUIPMENT_CHANGED = function(stream) addon.DataHub:RequestUpdate(stream) end,
		PLAYER_TALENT_UPDATE = function(stream) addon.DataHub:RequestUpdate(stream) end,
		ACTIVE_TALENT_GROUP_CHANGED = function(stream) addon.DataHub:RequestUpdate(stream) end,
		UPDATE_SHAPESHIFT_FORM = function(stream) addon.DataHub:RequestUpdate(stream) end,
		PLAYER_ENTERING_WORLD = function(stream) addon.DataHub:RequestUpdate(stream) end,
	},
	OnClick = function(_, btn)
		if btn == "RightButton" then createAceWindow() end
	end,
}

stream = EnhanceQoL.DataHub.RegisterStream(provider)

return provider
