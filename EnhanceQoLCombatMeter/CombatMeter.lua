local parentAddonName = "EnhanceQoL"
local addonName, addon = ...
if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

addon.CombatMeter.inCombat = false
addon.CombatMeter.fightStartTime = 0

local frame = CreateFrame("Frame")
addon.CombatMeter.frame = frame

local function handleEvent(self, event, ...)
	if event == "PLAYER_REGEN_DISABLED" or event == "ENCOUNTER_START" then
		addon.CombatMeter.inCombat = true
		addon.CombatMeter.fightStartTime = GetTime()
	elseif event == "PLAYER_REGEN_ENABLED" or event == "ENCOUNTER_END" then
		addon.CombatMeter.inCombat = false
	elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
		-- Combat log handling will be implemented later
	end
end

frame:SetScript("OnEvent", handleEvent)
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

SLASH_EQOLCM1 = "/eqolcm"
SlashCmdList["EQOLCM"] = function(msg)
	if msg == "reset" then
		addon.db["combatMeterHistory"] = {}
		print("EnhanceQoL Combat Meter data reset.")
	end
end
