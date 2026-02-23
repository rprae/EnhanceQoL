local addonName, addon = ...

addon.variables.NewVersionTableEQOL = {

	-- Economy -> Bank -> Warband Bank gold sync
	["EQOL_ECONOMY"] = true,
	["EQOL_Bank"] = true,
	["EQOL_autoWarbandGold"] = true,
	["EQOL_autoWarbandGoldTargetGold"] = true,
	["EQOL_autoWarbandGoldTargetCharacter"] = true,
	["EQOL_autoWarbandGoldTargetGoldPerCharacter"] = true,
	["EQOL_autoWarbandGoldWithdraw"] = true,

	-- Interface -> Map Navigation -> Square Minimap Stats
	["EQOL_UI"] = true,
	["EQOL_MapNavigation"] = true,
	["EQOL_enableSquareMinimapStats"] = true,

	-- Interface -> Mover -> Activities -> Queue Status Button
	["EQOL_Mover"] = true,
	["EQOL_moverFrame_QueueStatusButton"] = true,

	-- General -> Mouse -> Ring progress (Cast/GCD)
	["EQOL_GENERAL"] = true,
	["EQOL_MouseAndAccessibility"] = true,
	["EQOL_mouseRingCastProgress"] = true,
	["EQOL_mouseRingCastProgressColor"] = true,
	["EQOL_mouseRingGCDProgress"] = true,
	["EQOL_mouseRingGCDProgressColor"] = true,
	["EQOL_mouseRingGCDProgressMode"] = true,
	["EQOL_mouseRingProgressStyle"] = true,
	["EQOL_mouseRingProgressShowEdge"] = true,
	["EQOL_mouseRingProgressHideDuringSwipe"] = true,

	-- Gameplay -> Macros & Consumables -> Flask Macro
	["EQOL_GAMEPLAY"] = true,
	["EQOL_MacrosAndConsumables"] = true,
	["EQOL_flaskMacroEnabled"] = true,

	-- Economy -> Vendor - Auto-Sell Rules (Uncommon/Rare/Epic)
	["EQOL_AutoSellRules"] = true,
	["EQOL_vendorUncommonIgnoreEquipmentSets"] = true,
	["EQOL_vendorRareIgnoreEquipmentSets"] = true,
	["EQOL_vendorEpicIgnoreEquipmentSets"] = true,
}
