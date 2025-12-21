local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceQoL_LayoutTools")
local db = addon.db["eqolLayoutTools"]

local groupOrder = {
	blizzard = 10,
}

local groups = {
	blizzard = {
		label = L["Blizzard"] or "Blizzard",
		expanded = true,
	},
}

local frames = {
	{
		id = "SettingsPanel",
		label = SETTINGS,
		group = "blizzard",
		names = { "SettingsPanel" },
		addon = "Blizzard_Settings",
		defaultEnabled = true,
	},
	{
		id = "GameMenuFrame",
		label = MAINMENU_BUTTON,
		group = "blizzard",
		names = { "GameMenuFrame" },
		addon = "Blizzard_GameMenu",
		defaultEnabled = true,
	},
}

local settings = {
	{
		type = "checkbox",
		var = "layoutToolsEnabled",
		text = L["Global Move Enabled"] or "Enable moving",
		default = true,
		get = function() return db.enabled end,
		set = function(value)
			db.enabled = value
			addon.LayoutTools.functions.ApplyAll()
		end,
	},
	{
		type = "checkbox",
		var = "layoutToolsRequireModifier",
		text = L["Require Modifier For Move"] or "Require modifier to move",
		default = true,
		get = function() return db.requireModifier end,
		set = function(value) db.requireModifier = value end,
	},
	{
		type = "dropdown",
		var = "layoutToolsModifier",
		text = L["Move Modifier"] or (L["Scale Modifier"] or "Modifier"),
		list = { SHIFT = "SHIFT", CTRL = "CTRL", ALT = "ALT" },
		order = { "SHIFT", "CTRL", "ALT" },
		default = "SHIFT",
		get = function() return db.modifier or "SHIFT" end,
		set = function(value) db.modifier = value end,
		parentCheck = function() return db.requireModifier end,
	},
}

addon.LayoutTools.variables.groupOrder = groupOrder
addon.LayoutTools.variables.groups = groups
addon.LayoutTools.variables.frames = frames
addon.LayoutTools.variables.settings = settings

for groupId, group in pairs(groups) do
	local order = groupOrder[groupId] or group.order
	addon.LayoutTools.functions.RegisterGroup(groupId, group.label, {
		order = order,
		expanded = group.expanded,
	})
end

for _, def in ipairs(frames) do
	if def.group and groupOrder[def.group] and def.groupOrder == nil then def.groupOrder = groupOrder[def.group] end
	addon.LayoutTools.functions.RegisterFrame(def)
end
