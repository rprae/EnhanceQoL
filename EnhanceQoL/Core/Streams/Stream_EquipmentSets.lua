-- luacheck: globals EnhanceQoL MenuUtil MenuResponse C_EquipmentSet UnitCastingInfo UIErrorsFrame ERR_CLIENT_LOCKED_OUT EQUIPMENT_SETS GameTooltip UNKNOWN
local addonName, addon = ...
local L = addon.L

local format = string.format

local stream
local sets = {}

local function sortSetIDs(ids)
	if not C_EquipmentSet or not C_EquipmentSet.GetEquipmentSetAssignedSpec then return ids end
	local sorted = {}
	for _, setID in ipairs(ids) do
		if C_EquipmentSet.GetEquipmentSetAssignedSpec(setID) then sorted[#sorted + 1] = setID end
	end
	for _, setID in ipairs(ids) do
		if not C_EquipmentSet.GetEquipmentSetAssignedSpec(setID) then sorted[#sorted + 1] = setID end
	end
	return sorted
end

local function collectSets()
	if not C_EquipmentSet or not C_EquipmentSet.GetEquipmentSetIDs then return {} end
	local ids = C_EquipmentSet.GetEquipmentSetIDs() or {}
	ids = sortSetIDs(ids)
	for i, setID in ipairs(ids) do
		local name, icon, _, isEquipped, _, _, _, numLost = C_EquipmentSet.GetEquipmentSetInfo(setID)
		local entry = sets[i] or {}
		entry.id = setID
		entry.name = name
		entry.icon = icon
		entry.isEquipped = isEquipped
		entry.numLost = numLost or 0
		sets[i] = entry
	end
	for i = #ids + 1, #sets do
		sets[i] = nil
	end
	return ids
end

local function buildStreamText()
	local label = L["Set:"] or "Set:"
	local equippedName
	local equippedIcon
	for _, entry in ipairs(sets) do
		if entry.isEquipped then
			equippedName = entry.name
			equippedIcon = entry.icon
			break
		end
	end
	if not equippedName then return L["No Set Equipped"] or "No Set Equipped" end

	local iconText = ""
	if equippedIcon then iconText = format(" |T%d:16:16:0:0:64:64:4:60:4:60|t", equippedIcon) end
	return format("%s %s%s", label, equippedName, iconText)
end

local function updateSets(s)
	local ids = collectSets()

	s.snapshot.text = buildStreamText()
	s.snapshot.fontSize = 14
end

local function showSetMenu(owner)
	if not MenuUtil or not MenuUtil.CreateContextMenu then return end
	MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
		rootDescription:SetTag("MENU_EQOL_EQUIPMENT_SETS")
		rootDescription:CreateTitle(L["Equipment Sets"] or "Equipment Sets")

		if #sets == 0 then
			rootDescription:CreateButton(L["No Set Equipped"] or "No Set Equipped")
			return
		end

		for _, entry in ipairs(sets) do
			local name = entry.name or UNKNOWN
			local iconText = ""
			if entry.icon then iconText = format("|T%d:14:14:0:0:64:64:4:60:4:60|t ", entry.icon) end
			local label = iconText .. name
			rootDescription:CreateRadio(label, function() return entry.isEquipped end, function()
				if C_EquipmentSet and C_EquipmentSet.EquipmentSetContainsLockedItems and C_EquipmentSet.EquipmentSetContainsLockedItems(entry.id) then
					if UIErrorsFrame and ERR_CLIENT_LOCKED_OUT then UIErrorsFrame:AddMessage(ERR_CLIENT_LOCKED_OUT, 1.0, 0.1, 0.1, 1.0) end
					return
				end
				if UnitCastingInfo and UnitCastingInfo("player") then
					if UIErrorsFrame and ERR_CLIENT_LOCKED_OUT then UIErrorsFrame:AddMessage(ERR_CLIENT_LOCKED_OUT, 1.0, 0.1, 0.1, 1.0) end
					return
				end
				if C_EquipmentSet and C_EquipmentSet.UseEquipmentSet then C_EquipmentSet.UseEquipmentSet(entry.id) end
				return MenuResponse and MenuResponse.Close
			end, entry.id)
		end
	end)
end

local function showTooltip(btn)
	local tip = GameTooltip
	tip:ClearLines()
	tip:SetOwner(btn, "ANCHOR_TOPLEFT")
	tip:AddLine(L["Equipment Sets"] or "Equipment Sets")

	if #sets == 0 then
		tip:AddLine(" ")
		tip:AddLine(L["No Set Equipped"] or "No Set Equipped", 1, 1, 1)
		tip:Show()
		return
	end

	for i, entry in ipairs(sets) do
		if i == 1 then tip:AddLine(" ") end
		local iconText = ""
		if entry.icon then iconText = format("|T%d:14:14:0:0:64:64:4:60:4:60|t ", entry.icon) end
		local text = iconText .. (entry.name or UNKNOWN)
		if entry.numLost and entry.numLost > 0 then
			tip:AddLine(text, 1, 0.2, 0.2)
		elseif entry.isEquipped then
			tip:AddLine(text, 0.2, 1, 0.2)
		else
			tip:AddLine(text, 1, 1, 1)
		end
	end

	tip:Show()
end

local provider = {
	id = "equipmentsets",
	version = 1,
	title = L["Equipment Sets"] or "Equipment Sets",
	update = updateSets,
	events = {
		EQUIPMENT_SETS_CHANGED = function(s) addon.DataHub:RequestUpdate(s) end,
		EQUIPMENT_SWAP_FINISHED = function(s) addon.DataHub:RequestUpdate(s) end,
		PLAYER_EQUIPMENT_CHANGED = function(s) addon.DataHub:RequestUpdate(s) end,
		PLAYER_ENTERING_WORLD = function(s) addon.DataHub:RequestUpdate(s) end,
	},
	OnClick = function(button, btn)
		if btn == "LeftButton" then showSetMenu(button) end
	end,
	OnMouseEnter = function(btn) showTooltip(btn) end,
}

stream = EnhanceQoL.DataHub.RegisterStream(provider)

return provider
