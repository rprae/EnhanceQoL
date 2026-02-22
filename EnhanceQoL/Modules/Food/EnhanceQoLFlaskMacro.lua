local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceQoL_DrinkMacro")

local UnitAffectingCombat = UnitAffectingCombat
local InCombatLockdown = InCombatLockdown
local GetMacroInfo = GetMacroInfo
local EditMacro = EditMacro
local CreateMacro = CreateMacro

local flaskMacroName = "EnhanceQoLFlaskMacro"

local function getCurrentSpecID()
	local specIndex = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization()
	if not specIndex then return addon.variables and addon.variables.unitSpecId or nil end

	local specID
	if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
		local info = C_SpecializationInfo.GetSpecializationInfo(specIndex)
		if type(info) == "table" then
			specID = info.specID
		else
			specID = info
		end
	end

	if type(specID) ~= "number" or specID <= 0 then return addon.variables and addon.variables.unitSpecId or nil end
	return specID
end

local function createMacroIfMissing()
	if not addon.db.flaskMacroEnabled then return end
	if InCombatLockdown and InCombatLockdown() then return end
	if GetMacroInfo(flaskMacroName) == nil then
		local macroId = CreateMacro(flaskMacroName, "INV_Misc_QuestionMark")
		if not macroId then
			print(L["flaskMacroLimitReached"] or "Flask Macro: Macro limit reached. Please free a slot.")
			return
		end
		if not (InCombatLockdown and InCombatLockdown()) then EditMacro(flaskMacroName, flaskMacroName, nil, "#showtooltip") end
	end
end

local function buildMacroString(itemID)
	if not itemID then return "#showtooltip" end
	return string.format("#showtooltip item:%d\n/use item:%d", itemID, itemID)
end

local function getBestCandidate(specID)
	if addon.Flasks and addon.Flasks.functions and addon.Flasks.functions.updateAllowedFlasks then
		local list = addon.Flasks.functions.updateAllowedFlasks(specID)
		if type(list) == "table" then return list[1] end
	end

	local list = addon.Flasks and addon.Flasks.filteredFlasks
	if type(list) == "table" then return list[1] end
	return nil
end

local lastMacroToken

function addon.Flasks.functions.updateFlaskMacro(ignoreCombat)
	if not addon.db.flaskMacroEnabled then return end
	if UnitAffectingCombat("player") and ignoreCombat == false then return end

	createMacroIfMissing()

	local specID = getCurrentSpecID()
	local best = getBestCandidate(specID)
	local itemID = best and best.id or nil
	local macroToken = itemID and ("item:" .. tostring(itemID)) or "none"
	local macroExists = GetMacroInfo(flaskMacroName) ~= nil

	if macroToken ~= lastMacroToken or not macroExists then
		if InCombatLockdown and InCombatLockdown() then return end
		if not GetMacroInfo(flaskMacroName) then createMacroIfMissing() end
		if GetMacroInfo(flaskMacroName) then
			local macroBody = buildMacroString(itemID)
			EditMacro(flaskMacroName, flaskMacroName, nil, macroBody)
			lastMacroToken = macroToken
		end
	end
end

function addon.Flasks.functions.InitFlaskMacro()
	if not addon.db or not addon.functions or not addon.functions.InitDBValue then return end

	local init = addon.functions.InitDBValue
	init("flaskMacroEnabled", false)
	init("flaskPreferCauldrons", true)
	init("flaskPreferredBySpec", {})
	init("flaskPreferredByRole", {})

	if type(addon.db.flaskPreferredBySpec) ~= "table" then addon.db.flaskPreferredBySpec = {} end
	if type(addon.db.flaskPreferredByRole) ~= "table" then addon.db.flaskPreferredByRole = {} end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

local function syncEventRegistration()
	if not addon.db then return end

	if addon.db.flaskMacroEnabled then
		frame:RegisterEvent("BAG_UPDATE_DELAYED")
		frame:RegisterEvent("PLAYER_LEVEL_UP")
		frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
		frame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
	else
		frame:UnregisterEvent("BAG_UPDATE_DELAYED")
		frame:UnregisterEvent("PLAYER_LEVEL_UP")
		frame:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED")
		frame:UnregisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
	end
end

addon.Flasks.functions.syncEventRegistration = syncEventRegistration

local pendingBagUpdate = false

frame:SetScript("OnEvent", function(_, event, arg1)
	if event == "PLAYER_LOGIN" then
		syncEventRegistration()
		if addon.db and addon.db.flaskMacroEnabled and addon.Flasks and addon.Flasks.functions and addon.Flasks.functions.updateFlaskMacro then
			addon.Flasks.functions.updateFlaskMacro(false)
		end
		return
	end

	if not addon.db or addon.db.flaskMacroEnabled ~= true then return end

	if event == "PLAYER_REGEN_ENABLED" then
		if addon.Flasks and addon.Flasks.functions and addon.Flasks.functions.updateFlaskMacro then addon.Flasks.functions.updateFlaskMacro(true) end
	elseif event == "BAG_UPDATE_DELAYED" then
		if pendingBagUpdate then return end
		pendingBagUpdate = true
		C_Timer.After(0.05, function()
			pendingBagUpdate = false
			if addon.db and addon.db.flaskMacroEnabled and addon.Flasks and addon.Flasks.functions and addon.Flasks.functions.updateFlaskMacro then
				addon.Flasks.functions.updateFlaskMacro(false)
			end
		end)
	elseif event == "PLAYER_LEVEL_UP" then
		if not UnitAffectingCombat("player") and addon.Flasks and addon.Flasks.functions and addon.Flasks.functions.updateFlaskMacro then
			addon.Flasks.functions.updateFlaskMacro(false)
		end
	elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
		if arg1 and arg1 ~= "player" then return end
		if addon.Flasks and addon.Flasks.functions and addon.Flasks.functions.updateFlaskMacro then addon.Flasks.functions.updateFlaskMacro(false) end
	elseif event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" then
		if addon.Flasks and addon.Flasks.functions and addon.Flasks.functions.updateFlaskMacro then addon.Flasks.functions.updateFlaskMacro(false) end
	end
end)
