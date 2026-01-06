-- luacheck: globals EnhanceQoL
local addonName, addon = ...
local L = addon.L
local options = addon.MarkBarOptions

local function ensureDB()
	addon.db = addon.db or {}
	addon.db.datapanel = addon.db.datapanel or {}
	addon.db.datapanel.markbar = addon.db.datapanel.markbar or {}
	local db = addon.db.datapanel.markbar
	if db.showTargets == nil then db.showTargets = true end
	if db.showWorld == nil then db.showWorld = true end
	if db.showUtility == nil then db.showUtility = true end
	if db.iconSize == nil then db.iconSize = 16 end
	return db
end

local function atlasIcon(name, size) return ("|A:%s:%d:%d|a"):format(name, size, size) end

local function textureIcon(path, size) return ("|T%s:%d:%d|t"):format(path, size, size) end

local function buildPingIcons(size)
	local icons = {}
	if C_Ping and C_Ping.GetDefaultPingOptions then
		local options = C_Ping.GetDefaultPingOptions()
		if type(options) == "table" then
			for _, info in ipairs(options) do
				if info.uiTextureKitID then icons[info.type] = atlasIcon(("Ping_Wheel_Icon_%s"):format(info.uiTextureKitID), size) end
			end
		end
	end
	return icons
end

local function buildParts(size)
	local parts = {}
	local icons = buildPingIcons(size)

	local function addPing(macro, pingType, fallback)
		parts[#parts + 1] = {
			text = icons[pingType] or fallback,
			secure = {
				forwardRightClick = true,
				attributes = {
					type = "macro",
					macrotext = macro,
				},
			},
		}
	end

	addPing("/ping [@target] 1", Enum.PingSubjectType.Attack, "Atk")
	addPing("/ping [@target] 2", Enum.PingSubjectType.Warning, "Warn")
	addPing("/ping [@target] 3", Enum.PingSubjectType.OnMyWay, "OMW")
	addPing("/ping [@target] 4", Enum.PingSubjectType.Assist, "Asst")
	addPing("/ping [@target] 5", Enum.PingSubjectType.AlertNotThreat, atlasIcon("Ping_Marker_Icon_NonThreat", size))
	addPing("/ping [@target] 6", Enum.PingSubjectType.AlertThreat, atlasIcon("Ping_Marker_Icon_Threat", size))

	parts[#parts + 1] = {
		text = textureIcon("Interface\\AddOns\\EnhanceQoL\\Modules\\MythicPlus\\Art\\coreRC.tga", size),
		secure = {
			forwardRightClick = true,
			attributes = {
				type = "macro",
				macrotext = "/readycheck",
			},
		},
	}

	parts[#parts + 1] = {
		text = textureIcon("Interface\\AddOns\\EnhanceQoL\\Modules\\MythicPlus\\Art\\corePull.tga", size),
		secure = {
			forwardRightClick = true,
			attributes = {
				type = "macro",
				macrotext = "/countdown 10",
			},
		},
	}

	parts[#parts + 1] = {
		text = atlasIcon("GM-raidMarker-remove", size),
		secure = {
			forwardRightClick = true,
			attributes = {
				type = "macro",
				macrotext = "/countdown 0",
			},
		},
	}

	return parts
end

local function update(stream)
	local db = ensureDB()
	if not db.showUtility then
		stream.snapshot.hidden = true
		stream.snapshot.parts = nil
		stream.snapshot.text = nil
		return
	end

	stream.snapshot.hidden = nil
	local size
	if addon.MarkBarOptions and addon.MarkBarOptions.GetIconSizes then
		size = addon.MarkBarOptions.GetIconSizes()
	else
		size = db.iconSize or 16
	end
	stream.snapshot.fontSize = size
	stream.snapshot.parts = buildParts(size)
end

local function openOptions()
	if options and options.Show then options.Show() end
end

local provider = {
	id = "markbar_util",
	version = 1,
	title = L["MarkBarUtility"] or "Mark Bar: Pings + Checks",
	OnClick = {
		RightButton = openOptions,
	},
	update = update,
	events = {
		PLAYER_LOGIN = function(s) addon.DataHub:RequestUpdate(s) end,
	},
}

EnhanceQoL.DataHub.RegisterStream(provider)

return provider
