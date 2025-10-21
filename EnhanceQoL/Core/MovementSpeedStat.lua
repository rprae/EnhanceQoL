local addonName, addon = ...

addon.MovementSpeedStat = addon.MovementSpeedStat or {}
local mod = addon.MovementSpeedStat

local MOVEMENT_STAT_KEY = "EQOL_MOVEMENT_SPEED"
local CATEGORY_ID = "ENHANCEMENTS"
local BASE_MS = _G.BASE_MOVEMENT_SPEED or 7
local MOVEMENT_STAT_ENTRY = {
	stat = MOVEMENT_STAT_KEY,
	hideAt = 0,
}
local SPEED_EVENTS = {
	"UNIT_SPEED",
	"PLAYER_STARTED_MOVING",
	"PLAYER_STOPPED_MOVING",
	"PLAYER_MOUNT_DISPLAY_CHANGED",
	"UNIT_AURA",
	"UPDATE_SHAPESHIFT_FORM",
	"UNIT_ENTERED_VEHICLE",
	"UNIT_EXITED_VEHICLE",
	"ZONE_CHANGED",
	"ZONE_CHANGED_INDOORS",
	"ZONE_CHANGED_NEW_AREA",
}

local TICK = 0.2
local CACHE_EPSILON_PCT = 0.25
local CACHE_EPSILON_YPS = 0.05

local cache = { yps = BASE_MS, pct = 100 }
local accum = TICK
local active = false
local installed = false
local eventsRegistered = false

local ticker = CreateFrame("Frame")
ticker:Hide()

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

local function CharacterUIReady()
	return type(PAPERDOLL_STATINFO) == "table" and type(PAPERDOLL_STATCATEGORIES) == "table"
end

local function GetStatCategory()
	if not CharacterUIReady() then return nil end

	for _, category in ipairs(PAPERDOLL_STATCATEGORIES) do
		if category.categoryFrame == "EnhancementsCategory" or category.id == CATEGORY_ID then return category end
	end
end

local function StatEntryMatches(entry)
	if type(entry) == "table" then return entry.stat == MOVEMENT_STAT_KEY end
	return entry == MOVEMENT_STAT_KEY
end

local function AddStatToCategory()
	local category = GetStatCategory()
	if not category or not category.stats then return end

	for _, entry in ipairs(category.stats) do
		if StatEntryMatches(entry) then return end
	end

	table.insert(category.stats, MOVEMENT_STAT_ENTRY)
	installed = true
end

local function RemoveStatFromCategory()
	local category = GetStatCategory()
	if not category or not category.stats then return end

	for index = #category.stats, 1, -1 do
		if StatEntryMatches(category.stats[index]) then table.remove(category.stats, index) end
	end

	installed = false
end

local function RebuildPaperDoll()
	if not CharacterUIReady() then return end

	if PaperDoll_InitStatCategories then
		PaperDoll_InitStatCategories(PAPERDOLL_STATCATEGORY_DEFAULTORDER, "statCategoryOrder", "statCategoriesCollapsed", "player")
	end

	if PaperDollFrame_UpdateStats then PaperDollFrame_UpdateStats() end
end

local function Compute(unit)
	unit = unit or "player"

	if unit == "player" and UnitInVehicle("player") then unit = "vehicle" end

	local speed, runSpeed = GetUnitSpeed(unit)
	speed = speed or 0
	runSpeed = runSpeed or 0

	if speed < runSpeed then speed = runSpeed end

	if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
		local advanced, _, glideSpeed = C_PlayerInfo.GetGlidingInfo()
		if advanced and glideSpeed and glideSpeed > speed then speed = glideSpeed end
	end

	if speed <= 0 then
		if runSpeed > 0 then
			speed = runSpeed
		else
			speed = BASE_MS
		end
	end

	local pct = (speed / BASE_MS) * 100
	return speed, pct
end

local function PercentText(p)
	return string.format("%.0f", p)
end

local function StatUpdate(statFrame, unit)
	if not addon.db or not addon.db.movementSpeedStatEnabled then
		statFrame:Hide()
		return
	end

	unit = unit or "player"

	local yps, pct = Compute(unit)
	cache.yps = yps
	cache.pct = pct

	statFrame.numericValue = pct
	PaperDollFrame_SetLabelAndText(statFrame, STAT_MOVEMENT_SPEED, PercentText(pct), true, pct)
	statFrame.tooltip = HIGHLIGHT_FONT_COLOR_CODE .. STAT_MOVEMENT_SPEED .. FONT_COLOR_CODE_CLOSE
	statFrame.tooltip2 = string.format("~%.2f yards/sec", yps)
	statFrame:Show()
end

local function EnsureStatInfo()
	if not CharacterUIReady() then return end
	if PAPERDOLL_STATINFO[MOVEMENT_STAT_KEY] then return end

	PAPERDOLL_STATINFO[MOVEMENT_STAT_KEY] = {
		category = CATEGORY_ID,
		updateFunc = StatUpdate,
	}
end

local function StatsPaneVisible()
	if PaperDollFrame and PaperDollFrame:IsVisible() then return true end
	if CharacterFrame and CharacterFrame:IsShown() then
		local pane = CharacterFrame.CharacterStatsPane or _G.CharacterStatsPane
		if pane and pane:IsVisible() then return true end
	end
	return false
end

local function ShouldUpdate()
	return active and StatsPaneVisible() and PaperDollFrame_UpdateStats ~= nil
end

local function ForceTick()
	accum = TICK
end

local function OnUpdate(_, elapsed)
	if not ShouldUpdate() then
		accum = TICK
		return
	end

	accum = accum + elapsed
	if accum < TICK then return end
	accum = 0

	local yps, pct = Compute("player")
	if math.abs(pct - cache.pct) > CACHE_EPSILON_PCT or math.abs(yps - cache.yps) > CACHE_EPSILON_YPS then
		cache.yps = yps
		cache.pct = pct
		if PaperDollFrame_UpdateStats then PaperDollFrame_UpdateStats() end
	end
end

ticker:SetScript("OnUpdate", OnUpdate)

local function StartTicker()
	if ticker:IsShown() or not active then return end
	ForceTick()
	ticker:Show()
end

local function StopTicker()
	if not ticker:IsShown() then return end
	ticker:Hide()
	accum = TICK
end

local function HookCharacterFrame()
	if mod._hookedCharacterFrame or not CharacterFrame then return end

	CharacterFrame:HookScript("OnShow", function()
		if active then
			StartTicker()
			if PaperDollFrame_UpdateStats then PaperDollFrame_UpdateStats() end
		end
	end)

	CharacterFrame:HookScript("OnHide", function() StopTicker() end)

	mod._hookedCharacterFrame = true

	if CharacterFrame:IsShown() then StartTicker() end
end

local function TryInstall()
	if not active then return end

	if not CharacterUIReady() then return end

	EnsureStatInfo()
	AddStatToCategory()
	HookCharacterFrame()

	RebuildPaperDoll()

	if CharacterFrame and CharacterFrame:IsShown() and ShouldUpdate() then StartTicker() end
end

local function RegisterSpeedEvents()
	if eventsRegistered then return end
	for _, eventName in ipairs(SPEED_EVENTS) do
		eventFrame:RegisterEvent(eventName)
	end
	eventsRegistered = true
end

local function UnregisterSpeedEvents()
	if not eventsRegistered then return end
	for _, eventName in ipairs(SPEED_EVENTS) do
		eventFrame:UnregisterEvent(eventName)
	end
	eventsRegistered = false
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		local name = ...
		if name == "Blizzard_CharacterUI" or name == "Blizzard_UIPanels_Game" then TryInstall() end
		return
	end

	if not active then return end
	if event == "UNIT_SPEED" then
		local unit = ...
		if unit ~= "player" and unit ~= "vehicle" then return end
	end

	if StatsPaneVisible() then ForceTick() end
end)

function mod.Enable()
	if active then return end
	active = true
	cache.yps, cache.pct = Compute("player")
	RegisterSpeedEvents()
	TryInstall()
end

function mod.Disable()
	if not active then return end
	active = false
	StopTicker()
	UnregisterSpeedEvents()

	if installed then
		RemoveStatFromCategory()
		RebuildPaperDoll()
	end
end

function mod.Refresh()
	if not addon.db then return end
	if addon.db.movementSpeedStatEnabled then
		mod.Enable()
	else
		mod.Disable()
	end
end
