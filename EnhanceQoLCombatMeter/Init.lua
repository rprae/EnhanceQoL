local parentAddonName = "EnhanceQoL"
local addonName, addon = ...
if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

addon.CombatMeter = {}
addon.CombatMeter.functions = {}
addon.LCombatMeter = {}

addon.functions.InitDBValue("combatMeterEnabled", false)
addon.functions.InitDBValue("combatMeterHistory", {})
