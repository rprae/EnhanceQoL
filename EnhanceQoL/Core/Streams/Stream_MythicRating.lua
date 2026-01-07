-- luacheck: globals EnhanceQoL C_PlayerInfo C_ChallengeMode COLOR_WHITE
local addonName, addon = ...
local L = addon.L

local format = string.format
local floor = math.floor

local lastScore
local lastRuns
local lastColor

local function getOptionsHint()
	if addon.DataPanel and addon.DataPanel.GetOptionsHintText then
		local text = addon.DataPanel.GetOptionsHintText()
		if text ~= nil then return text end
		return nil
	end
	return L["Right-Click for options"]
end

local function getScoreColor(score)
	if C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor then
		local color = C_ChallengeMode.GetDungeonScoreRarityColor(score)
		if color and color.GetRGB then return color:GetRGB() end
	end
	if COLOR_WHITE and COLOR_WHITE.GetRGB then return COLOR_WHITE:GetRGB() end
	return 1, 1, 1
end

local function toHex(r, g, b) return format("%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5)) end

local function updateRating(s)
	local summary = C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary and C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
	if not summary or not summary.currentSeasonScore then
		s.snapshot.text = L["No Mythic+ rating"] or "No Mythic+ rating"
		lastScore = nil
		lastRuns = nil
		return
	end

	local score = summary.currentSeasonScore or 0
	lastScore = score
	lastRuns = summary.runs
	local r, g, b = getScoreColor(score)
	lastColor = { r = r, g = g, b = b }

	s.snapshot.text = format("|cff%s%d|r", toHex(r, g, b), floor(score + 0.5))
	s.snapshot.fontSize = 14
end

local function addRunLine(tip, run)
	if not run then return end
	local name = C_ChallengeMode and C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(run.challengeModeID)
	if not name then
		local mapInfo = C_ChallengeMode and C_ChallengeMode.GetMapInfo and C_ChallengeMode.GetMapInfo(run.challengeModeID)
		name = mapInfo and mapInfo.name
	end
	name = name or ("Map " .. tostring(run.challengeModeID))

	local score = run.mapScore or 0
	local level = run.bestRunLevel or 0
	local lineLeft = format("%s (+%d)", name, level)
	local r, g, b = getScoreColor(score)
	tip:AddDoubleLine(lineLeft, format("%d", floor(score + 0.5)), 1, 1, 1, r, g, b)
end

local provider = {
	id = "mythicrating",
	version = 1,
	title = L["Mythic+ Rating"] or "Mythic+ Rating",
	update = updateRating,
	events = {
		CHALLENGE_MODE_COMPLETED = function(s) addon.DataHub:RequestUpdate(s) end,
		CHALLENGE_MODE_MAPS_UPDATE = function(s) addon.DataHub:RequestUpdate(s) end,
		PLAYER_ENTERING_WORLD = function(s) addon.DataHub:RequestUpdate(s) end,
	},
	OnMouseEnter = function(btn)
		local tip = GameTooltip
		tip:ClearLines()
		tip:SetOwner(btn, "ANCHOR_TOPLEFT")

		if not lastScore then
			tip:SetText(L["No Mythic+ rating"] or "No Mythic+ rating")
			tip:Show()
			return
		end

		local r, g, b = (lastColor and lastColor.r) or 1, (lastColor and lastColor.g) or 1, (lastColor and lastColor.b) or 1
		tip:AddDoubleLine(L["Mythic+ Rating"] or "Mythic+ Rating", format("%d", floor(lastScore + 0.5)), 1, 1, 1, r, g, b)

		if lastRuns and #lastRuns > 0 then
			tip:AddLine(" ")
			for _, run in ipairs(lastRuns) do
				addRunLine(tip, run, lastScore)
			end
		end

		local hint = getOptionsHint()
		if hint then
			tip:AddLine(" ")
			tip:AddLine(hint)
		end
		tip:Show()
	end,
}

EnhanceQoL.DataHub.RegisterStream(provider)

return provider
