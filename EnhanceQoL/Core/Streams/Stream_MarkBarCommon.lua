-- luacheck: globals EnhanceQoL
local addonName, addon = ...
local L = addon.L

if addon.MarkBarOptions then return end

local AceGUI = addon.AceGUI
local MARKBAR_RING_SIZE_OFFSET = 8
local MARKBAR_ICON_SIZE_OFFSET = -4

local function ensureDB()
	addon.db = addon.db or {}
	addon.db.datapanel = addon.db.datapanel or {}
	addon.db.datapanel.markbar = addon.db.datapanel.markbar or {}
	local db = addon.db.datapanel.markbar
	if db.showTargets == nil then db.showTargets = true end
	if db.showWorld == nil then db.showWorld = true end
	if db.showUtility == nil then db.showUtility = true end
	if db.iconSize == nil then db.iconSize = 14 end
	if db.iconSize < 10 then db.iconSize = 10 end
	if db.iconSize > 18 then db.iconSize = 18 end
	return db
end

local function getIconSizes()
	local db = ensureDB()
	local base = db.iconSize or 16
	return base + MARKBAR_RING_SIZE_OFFSET, base + MARKBAR_ICON_SIZE_OFFSET
end

local function requestUpdates()
	if not addon.DataHub or not addon.DataHub.RequestUpdate then return end
	addon.DataHub:RequestUpdate("markbar_target")
	addon.DataHub:RequestUpdate("markbar_world")
	addon.DataHub:RequestUpdate("markbar_util")
end

local aceWindow
local function showOptions()
	if InCombatLockdown and InCombatLockdown() then
		if UIErrorsFrame and ERR_NOT_IN_COMBAT then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT) end
		return
	end
	if aceWindow then
		aceWindow:Show()
		return
	end

	local db = ensureDB()
	local frame = AceGUI:Create("Window")
	aceWindow = frame.frame
	frame:SetTitle(L["Mark Bar"] or "Mark Bar")
	frame:SetWidth(280)
	frame:SetHeight(160)
	frame:SetLayout("List")

	local iconSize = AceGUI:Create("Slider")
	iconSize:SetLabel(L["MarkBarIconSize"] or "Icon size")
	iconSize:SetSliderValues(10, 18, 1)
	iconSize:SetValue(db.iconSize or 14)
	iconSize:SetCallback("OnValueChanged", function(_, _, val)
		db.iconSize = math.floor(val + 0.5)
		requestUpdates()
	end)
	frame:AddChild(iconSize)

	frame.frame:Show()
end

addon.MarkBarOptions = {
	Show = showOptions,
	RequestUpdates = requestUpdates,
	EnsureDB = ensureDB,
	GetIconSizes = getIconSizes,
}
