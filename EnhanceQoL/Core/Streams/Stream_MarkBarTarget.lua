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

local function atlasIcon(name, size)
	return ("|A:%s:%d:%d|a"):format(name, size, size)
end

local function markerIcon(marker, size)
	return atlasIcon("GM-raidMarker" .. tostring(marker), size)
end

local NUM_RAID_MARKERS = 8

local function reverseMarkerID(id)
	return NUM_RAID_MARKERS - id + 1
end

local function buildParts(size)
	local parts = {}
	for i = 1, 8 do
		parts[#parts + 1] = {
			text = markerIcon(i, size),
			secure = {
				forwardRightClick = true,
				attributes = {
					type = "macro",
					macrotext = "/tm " .. reverseMarkerID(i),
				},
			},
		}
	end
	parts[#parts + 1] = {
		text = atlasIcon("GM-raidMarker-remove", size),
		secure = {
			forwardRightClick = true,
			attributes = {
				type = "macro",
				macrotext = "/tm 0",
			},
		},
	}
	return parts
end

local function update(stream)
	local db = ensureDB()
	if not db.showTargets then
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
	if options and options.Show then
		options.Show()
	end
end

local provider = {
	id = "markbar_target",
	version = 1,
	title = L["MarkBarTargets"] or "Mark Bar: Target Icons",
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
