local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceQoL_Mouse")

-- Hotpath locals & constants
local GetCursorPosition = GetCursorPosition
local IsMouseButtonDown = IsMouseButtonDown
local UIParent = UIParent
local UnitAffectingCombat = UnitAffectingCombat
local UnitClass = UnitClass
local GetClassColor = GetClassColor
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local GetTime = GetTime
local GetSpellCooldownInfo = (C_Spell and C_Spell.GetSpellCooldown) or GetSpellCooldown
local issecretvalue = _G.issecretvalue
local RING_FRAME_NAME = addonName .. "_MouseRingFrame"
local TEX_MOUSE = "Interface\\AddOns\\" .. addonName .. "\\Assets\\Mouse\\Mouse.tga"
local TEX_DOT = "Interface\\AddOns\\" .. addonName .. "\\Assets\\Mouse\\Dot.tga"
addon.Mouse.variables.TEXT_DOT = TEX_DOT
local TEX_TRAIL = "Interface\\AddOns\\" .. addonName .. "\\Assets\\Mouse\\MouseTrail.tga"
local PLAYER_UNIT = "player"
local GCD_SPELL_ID = 61304
local TWO_PI = math.pi * 2
local HALF_PI = math.pi * 0.5
local PROGRESS_STYLE_DOT = "DOT"
local PROGRESS_STYLE_RING = "RING"

local MaxActuationPoint = 1 -- Minimaler Bewegungsabstand für Trail-Elemente
local MaxActuationPointSq = MaxActuationPoint * MaxActuationPoint
local duration = 0.3 -- Lebensdauer der Trail-Elemente in Sekunden
local Density = 0.02 -- Zeitdichte für neue Elemente
local ElementCap = 28 -- Maximale Anzahl von Trail-Elementen
local PastCursorX, PastCursorY, PresentCursorX, PresentCursorY = nil, nil, nil, nil

local trailPool = {}
local activeCount = 0
local playerClass = UnitClass and select(2, UnitClass("player")) or nil
local classR, classG, classB
if playerClass and GetClassColor then
	classR, classG, classB = GetClassColor(playerClass)
end
local currentPreset = nil
local lastTrailWanted = false
local lastRingCombat = nil
local ringStyleDirty = true
local castInfo = nil
local gcdActive = nil
local gcdStart = nil
local gcdDuration = nil
local gcdRate = nil

local trailPresets = {
	[1] = { -- LOW
		MaxActuationPoint = 1.0,
		duration = 0.4,
		Density = 0.025,
		ElementCap = 20,
	},
	[2] = { -- MEDIUM
		MaxActuationPoint = 0.7,
		duration = 0.5,
		Density = 0.02,
		ElementCap = 40,
	},
	[3] = { -- HIGH (Sweet Spot)
		MaxActuationPoint = 0.5,
		duration = 0.7,
		Density = 0.012,
		ElementCap = 80,
	},
	[4] = { -- ULTRA
		MaxActuationPoint = 0.3,
		duration = 0.7,
		Density = 0.007,
		ElementCap = 120,
	},
	[5] = { -- ULTRA HIGH
		MaxActuationPoint = 0.2,
		duration = 0.8,
		Density = 0.005,
		ElementCap = 150,
	},
}

local function createTrailElement()
	local tex = UIParent:CreateTexture(nil)
	tex:SetTexture(TEX_TRAIL)
	tex:SetBlendMode("ADD")
	tex:SetSize(35, 35)

	local ag = tex:CreateAnimationGroup()
	ag:SetScript("OnFinished", function(self)
		local t = self:GetParent()
		t:Hide()
		trailPool[#trailPool + 1] = t
		activeCount = activeCount - 1
	end)
	local fade = ag:CreateAnimation("Alpha")
	fade:SetFromAlpha(1)
	fade:SetToAlpha(0)

	tex.anim = ag
	tex.fade = fade

	return tex
end

local function ensureTrailPool()
	local total = activeCount + #trailPool
	if total >= ElementCap then return end
	for _ = 1, (ElementCap - total) do
		local tex = createTrailElement()
		tex:Hide()
		trailPool[#trailPool + 1] = tex
	end
end

local function applyPreset(presetName)
	local preset = trailPresets[presetName]
	if not preset then return end
	MaxActuationPoint = preset.MaxActuationPoint
	MaxActuationPointSq = MaxActuationPoint * MaxActuationPoint
	duration = preset.duration
	Density = preset.Density
	ElementCap = preset.ElementCap
	currentPreset = presetName

	if addon.db and addon.db["mouseTrailEnabled"] then ensureTrailPool() end
end
addon.Mouse.functions.applyPreset = applyPreset

local timeAccumulator = 0

local function isRingWanted(db, inCombat, rightClickActive)
	if not db or not db["mouseRingEnabled"] then return false end
	if db["mouseRingOnlyInCombat"] and not inCombat then return false end
	if db["mouseRingOnlyOnRightClick"] and not rightClickActive then return false end
	return true
end

local function getTrailColor()
	if addon.db["mouseTrailUseClassColor"] then
		if not classR then
			local class = playerClass or (UnitClass and select(2, UnitClass("player")))
			if class then playerClass = class end
			if class and GetClassColor then
				classR, classG, classB = GetClassColor(class)
			end
		end
		if classR then return classR, classG, classB, 1 end
		return 1, 1, 1, 1
	end
	local c = addon.db["mouseTrailColor"]
	if c then return c.r, c.g, c.b, c.a or 1 end
	return 1, 1, 1, 1
end

local function getRingColor()
	if addon.db["mouseRingUseClassColor"] then
		if not classR then
			local class = playerClass or (UnitClass and select(2, UnitClass("player")))
			if class then playerClass = class end
			if class and GetClassColor then
				classR, classG, classB = GetClassColor(class)
			end
		end
		if classR then return classR, classG, classB, 1 end
		return 1, 1, 1, 1
	end
	local c = addon.db["mouseRingColor"]
	if c then return c.r, c.g, c.b, c.a or 1 end
	return 1, 1, 1, 1
end

local function getCombatOverrideColor()
	local c = addon.db["mouseRingCombatOverrideColor"]
	if c then return c.r, c.g, c.b, c.a or 1 end
	return 1, 0.2, 0.2, 1
end

local function getCombatOverlayColor()
	local c = addon.db["mouseRingCombatOverlayColor"]
	if c then return c.r, c.g, c.b, c.a or 1 end
	return 1, 0.2, 0.2, 0.6
end

local function ensureCombatOverlay(frame)
	local overlay = frame.combatOverlay
	if overlay then return overlay end
	overlay = frame:CreateTexture(nil, "BACKGROUND")
	overlay:SetTexture(TEX_MOUSE)
	overlay:SetBlendMode("ADD")
	overlay:SetPoint("CENTER", frame, "CENTER", 0, 0)
	overlay:SetDrawLayer("BACKGROUND", -1)
	frame.combatOverlay = overlay
	return overlay
end

local function shouldShowCastProgress(db) return db and db["mouseRingCastProgress"] == true end

local function shouldShowGCDProgress(db) return db and db["mouseRingGCDProgress"] == true end

local function normalizeProgressStyle(value)
	if value == PROGRESS_STYLE_RING then return PROGRESS_STYLE_RING end
	return PROGRESS_STYLE_DOT
end

local function isRingProgressStyle(db) return normalizeProgressStyle(db and db["mouseRingProgressStyle"]) == PROGRESS_STYLE_RING end

local function isSwipeEdgeEnabled(db) return not (db and db["mouseRingProgressShowEdge"] == false) end

local function getProgressHideMultiplier(db)
	local pct = tonumber(db and db["mouseRingProgressHideDuringSwipe"])
	if pct == nil then pct = 35 end
	if pct < 0 then pct = 0 end
	if pct > 100 then pct = 100 end
	return pct / 100
end

local function normalizeGCDProgressMode(value)
	if value == "ELAPSED" then return "ELAPSED" end
	return "REMAINING"
end

local function colorFromTable(color, fallbackR, fallbackG, fallbackB, fallbackA)
	if type(color) == "table" then return color.r or color[1] or fallbackR, color.g or color[2] or fallbackG, color.b or color[3] or fallbackB, color.a or color[4] or fallbackA end
	return fallbackR, fallbackG, fallbackB, fallbackA
end

local function ensureProgressIndicators(frame)
	local castTick = frame.castTick
	if not castTick then
		castTick = frame:CreateTexture(nil, "OVERLAY", nil, 3)
		castTick:SetTexture(TEX_DOT)
		castTick:SetBlendMode("ADD")
		castTick:Hide()
		frame.castTick = castTick
	end

	local gcdTick = frame.gcdTick
	if not gcdTick then
		gcdTick = frame:CreateTexture(nil, "OVERLAY", nil, 2)
		gcdTick:SetTexture(TEX_DOT)
		gcdTick:SetBlendMode("ADD")
		gcdTick:Hide()
		frame.gcdTick = gcdTick
	end

	return castTick, gcdTick
end

local function createSwipeIndicator(parent, levelOffset)
	local swipe = CreateFrame("Cooldown", nil, parent, "CooldownFrameTemplate")
	swipe:ClearAllPoints()
	swipe:SetPoint("CENTER", parent, "CENTER", 0, 0)
	swipe:SetDrawSwipe(true)
	swipe:SetDrawEdge(true)
	if swipe.SetUseCircularEdge then swipe:SetUseCircularEdge(true) end
	swipe:SetHideCountdownNumbers(true)
	if swipe.SetDrawBling then swipe:SetDrawBling(false) end
	if swipe.SetSwipeTexture then pcall(swipe.SetSwipeTexture, swipe, TEX_MOUSE) end
	swipe:SetFrameStrata("TOOLTIP")
	if swipe.SetFrameLevel and parent.GetFrameLevel then swipe:SetFrameLevel((parent:GetFrameLevel() or 0) + (levelOffset or 1)) end
	swipe:Hide()
	return swipe
end

local function ensureSwipeIndicators(frame)
	if not frame.castSwipe then frame.castSwipe = createSwipeIndicator(frame, 6) end
	if not frame.gcdSwipe then frame.gcdSwipe = createSwipeIndicator(frame, 5) end
	return frame.castSwipe, frame.gcdSwipe
end

local function applySwipeEdgeSetting(frame, enabled)
	if not frame then return end
	local castSwipe, gcdSwipe = ensureSwipeIndicators(frame)
	if castSwipe and castSwipe.SetDrawEdge and castSwipe._eqolDrawEdge ~= enabled then
		castSwipe:SetDrawEdge(enabled)
		castSwipe._eqolDrawEdge = enabled
	end
	if gcdSwipe and gcdSwipe.SetDrawEdge and gcdSwipe._eqolDrawEdge ~= enabled then
		gcdSwipe:SetDrawEdge(enabled)
		gcdSwipe._eqolDrawEdge = enabled
	end
end

local function hideSwipeIndicators(frame)
	if not frame then return end
	if frame.castSwipe then
		frame.castSwipe:Hide()
		frame.castSwipe._eqolActive = nil
	end
	if frame.gcdSwipe then
		frame.gcdSwipe:Hide()
		frame.gcdSwipe._eqolActive = nil
	end
end

local function applyRingAlphaMultiplier(frame, multiplier)
	if not frame or not frame.texture1 then return end
	if frame._eqolAppliedRingAlphaMultiplier == multiplier then return end
	local base = frame._eqolRingBaseColor
	if not base then return end
	frame.texture1:SetVertexColor(base[1], base[2], base[3], base[4] * multiplier)
	frame._eqolAppliedRingAlphaMultiplier = multiplier
end

local function hideProgressIndicators(frame)
	if not frame then return end
	if frame.castTick then frame.castTick:Hide() end
	if frame.gcdTick then frame.gcdTick:Hide() end
	hideSwipeIndicators(frame)
	applyRingAlphaMultiplier(frame, 1)
end

local function updateProgressIndicatorLayout(frame, ringSize)
	if not frame then return end
	local castTick, gcdTick = ensureProgressIndicators(frame)
	local castSwipe, gcdSwipe = ensureSwipeIndicators(frame)
	local size = tonumber(ringSize) or 70
	if size < 20 then size = 20 end
	local castTickSize = math.max(5, math.floor((size * 0.14) + 0.5))
	local gcdTickSize = math.max(4, math.floor((castTickSize * 0.8) + 0.5))
	local outerRadius = math.max(4, (size * 0.5) - (castTickSize * 0.5) - 1)
	local innerRadius = outerRadius
	if shouldShowCastProgress(addon.db) and shouldShowGCDProgress(addon.db) then innerRadius = math.max(2, outerRadius - math.max(gcdTickSize + 1, math.floor((size * 0.12) + 0.5))) end
	castTick:SetSize(castTickSize, castTickSize)
	gcdTick:SetSize(gcdTickSize, gcdTickSize)
	frame.castTickRadius = outerRadius
	frame.gcdTickRadius = innerRadius

	local castSwipeSize = size
	local gcdSwipeSize = size
	if shouldShowCastProgress(addon.db) and shouldShowGCDProgress(addon.db) then gcdSwipeSize = math.max(18, math.floor((size * 0.86) + 0.5)) end
	castSwipe:SetSize(castSwipeSize, castSwipeSize)
	gcdSwipe:SetSize(gcdSwipeSize, gcdSwipeSize)
	castSwipe:ClearAllPoints()
	castSwipe:SetPoint("CENTER", frame, "CENTER", 0, 0)
	gcdSwipe:ClearAllPoints()
	gcdSwipe:SetPoint("CENTER", frame, "CENTER", 0, 0)
	applySwipeEdgeSetting(frame, isSwipeEdgeEnabled(addon.db))
end

local function setIndicatorProgress(frame, texture, progress, radius)
	if not frame or not texture then return end
	if progress < 0 then progress = 0 end
	if progress > 1 then progress = 1 end
	local angle = HALF_PI - (progress * TWO_PI)
	texture:ClearAllPoints()
	texture:SetPoint("CENTER", frame, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function getCastProgressColor()
	local db = addon.db or {}
	local c = db["mouseRingCastProgressColor"]
	if c then return colorFromTable(c, 1, 1, 1, 1) end
	return getRingColor()
end

local function getGCDProgressColor()
	local db = addon.db or {}
	return colorFromTable(db["mouseRingGCDProgressColor"], 1, 0.82, 0.2, 1)
end

local function stopCastProgress() castInfo = nil end

local function stopGCDProgress()
	gcdActive = nil
	gcdStart = nil
	gcdDuration = nil
	gcdRate = nil
end

local function shouldIgnoreCastFail(castGUID, spellId)
	if UnitChannelInfo then
		local channelName = UnitChannelInfo(PLAYER_UNIT)
		if channelName then return true end
	end
	local info = castInfo
	if not info then return false end
	if info.castGUID and castGUID then
		if not (issecretvalue and (issecretvalue(info.castGUID) or issecretvalue(castGUID))) and info.castGUID ~= castGUID then return true end
	end
	if info.spellId and spellId and info.castGUID then
		if not (issecretvalue and (issecretvalue(info.spellId) or issecretvalue(spellId))) and info.spellId ~= spellId then return true end
	end
	return false
end

local function setCastInfoFromUnit()
	local name, text, texture, startTimeMS, endTimeMS, _, _, spellId, isEmpowered, numEmpowerStages = UnitChannelInfo(PLAYER_UNIT)
	local isChannel = true
	local castGUID
	if not name then
		name, text, texture, startTimeMS, endTimeMS, _, castGUID, _, spellId = UnitCastingInfo(PLAYER_UNIT)
		isChannel = false
		isEmpowered = nil
		numEmpowerStages = nil
	end
	if not name then
		stopCastProgress()
		return
	end

	local isEmpoweredCast = isChannel and (issecretvalue and not issecretvalue(isEmpowered)) and isEmpowered and numEmpowerStages and numEmpowerStages > 0
	if isEmpoweredCast and startTimeMS and endTimeMS and (not issecretvalue or (not issecretvalue(startTimeMS) and not issecretvalue(endTimeMS))) then
		local UFHelper = addon.Aura and addon.Aura.UFHelper
		local totalMs = UFHelper and UFHelper.getEmpoweredChannelDurationMilliseconds and UFHelper.getEmpoweredChannelDurationMilliseconds(PLAYER_UNIT)
		if totalMs and totalMs > 0 and (not issecretvalue or not issecretvalue(totalMs)) then
			endTimeMS = startTimeMS + totalMs
		else
			local hold = UFHelper and UFHelper.getEmpowerHoldMilliseconds and UFHelper.getEmpowerHoldMilliseconds(PLAYER_UNIT)
			if hold and (not issecretvalue or not issecretvalue(hold)) then endTimeMS = endTimeMS + hold end
		end
	end

	if issecretvalue and ((startTimeMS and issecretvalue(startTimeMS)) or (endTimeMS and issecretvalue(endTimeMS))) then
		stopCastProgress()
		return
	end
	local castDuration = (endTimeMS or 0) - (startTimeMS or 0)
	if not castDuration or castDuration <= 0 then
		stopCastProgress()
		return
	end

	castInfo = {
		name = text or name,
		texture = texture,
		startTime = startTimeMS,
		endTime = endTimeMS,
		isChannel = isChannel,
		isEmpowered = isEmpowered,
		numEmpowerStages = numEmpowerStages,
		castGUID = castGUID,
		spellId = spellId,
	}
end

local function updateGCDProgressState()
	if not GetSpellCooldownInfo then
		stopGCDProgress()
		return
	end

	local start, durationValue, enabled, modRate
	local info, info2, info3, info4 = GetSpellCooldownInfo(GCD_SPELL_ID)
	if type(info) == "table" then
		start = info.startTime
		durationValue = info.duration
		enabled = info.isEnabled
		modRate = info.modRate or 1
	else
		start, durationValue, enabled, modRate = info, info2, info3, info4
	end
	if not enabled or not durationValue or durationValue <= 0 or not start or start <= 0 then
		stopGCDProgress()
		return
	end

	gcdActive = true
	gcdStart = start
	gcdDuration = durationValue
	gcdRate = modRate or 1
end

local function syncRingProgressState()
	local db = addon.db
	if not db or db["mouseRingEnabled"] ~= true then
		stopCastProgress()
		stopGCDProgress()
		hideProgressIndicators(addon.mousePointer)
		return
	end
	if shouldShowCastProgress(db) then
		setCastInfoFromUnit()
	else
		stopCastProgress()
	end
	if shouldShowGCDProgress(db) then
		updateGCDProgressState()
	else
		stopGCDProgress()
	end
end
addon.Mouse.functions.syncRingProgressState = syncRingProgressState

local function getCastProgressValue(nowMs)
	local info = castInfo
	if not info then return nil end
	if not info.startTime or not info.endTime then
		stopCastProgress()
		return nil
	end
	if issecretvalue and (issecretvalue(info.startTime) or issecretvalue(info.endTime)) then
		stopCastProgress()
		return nil
	end

	local startMs = info.startTime or 0
	local endMs = info.endTime or 0
	local durationMs = endMs - startMs
	if not durationMs or durationMs <= 0 then
		stopCastProgress()
		return nil
	end
	if nowMs >= endMs then
		stopCastProgress()
		return nil
	end

	local elapsedMs
	if info.isEmpowered then
		elapsedMs = nowMs - startMs
	else
		elapsedMs = info.isChannel and (endMs - nowMs) or (nowMs - startMs)
	end
	if elapsedMs < 0 then elapsedMs = 0 end
	local progress = elapsedMs / durationMs
	if progress < 0 then progress = 0 end
	if progress > 1 then progress = 1 end
	return progress, info
end

local function getGCDProgressValue(now)
	if not gcdActive then return nil end
	local start = gcdStart
	local durationValue = gcdDuration
	if not start or not durationValue or durationValue <= 0 then
		stopGCDProgress()
		return nil
	end
	local rate = gcdRate or 1
	local elapsed = (now - start) * rate
	if elapsed >= durationValue then
		stopGCDProgress()
		return nil
	end
	local progress = elapsed / durationValue
	if progress < 0 then progress = 0 end
	if progress > 1 then progress = 1 end
	if normalizeGCDProgressMode(addon.db and addon.db["mouseRingGCDProgressMode"]) ~= "ELAPSED" then progress = 1 - progress end
	return progress
end

local function setSwipeIndicatorState(indicator, active, startTime, durationValue, modRate, reverse, r, g, b, a)
	if not indicator then return false end
	if not active then
		if indicator:IsShown() then indicator:Hide() end
		indicator._eqolActive = nil
		return false
	end

	reverse = reverse and true or false
	if indicator.SetReverse and indicator._eqolReverse ~= reverse then
		indicator:SetReverse(reverse)
		indicator._eqolReverse = reverse
	end

	if indicator.SetSwipeColor then
		local lastR, lastG, lastB, lastA = indicator._eqolColorR, indicator._eqolColorG, indicator._eqolColorB, indicator._eqolColorA
		if lastR ~= r or lastG ~= g or lastB ~= b or lastA ~= a then
			indicator:SetSwipeColor(r, g, b, a)
			indicator._eqolColorR, indicator._eqolColorG, indicator._eqolColorB, indicator._eqolColorA = r, g, b, a
		end
	end

	local normalizedRate = tonumber(modRate) or 1
	local needsCooldown = indicator._eqolActive ~= true or indicator._eqolStart ~= startTime or indicator._eqolDuration ~= durationValue or indicator._eqolRate ~= normalizedRate

	if needsCooldown and indicator.SetCooldown then
		if normalizedRate ~= 1 then
			indicator:SetCooldown(startTime, durationValue, normalizedRate)
		else
			indicator:SetCooldown(startTime, durationValue)
		end
		indicator._eqolStart = startTime
		indicator._eqolDuration = durationValue
		indicator._eqolRate = normalizedRate
	end

	indicator._eqolActive = true
	if not indicator:IsShown() then indicator:Show() end
	return true
end

local function updateRingProgressIndicators()
	local db = addon.db
	local frame = addon.mousePointer
	if not db or not frame or not db["mouseRingEnabled"] then
		hideProgressIndicators(frame)
		return
	end
	local castEnabled = shouldShowCastProgress(db)
	local gcdEnabled = shouldShowGCDProgress(db)
	if not castEnabled and not gcdEnabled then
		hideProgressIndicators(frame)
		return
	end

	local now = GetTime and GetTime() or 0
	local nowMs = now * 1000
	local ringStyle = isRingProgressStyle(db)
	local swipeVisible = false

	if ringStyle then
		local castSwipe, gcdSwipe = ensureSwipeIndicators(frame)
		applySwipeEdgeSetting(frame, isSwipeEdgeEnabled(db))
		if frame.castTick then frame.castTick:Hide() end
		if frame.gcdTick then frame.gcdTick:Hide() end

		if castEnabled then
			local progress, info = getCastProgressValue(nowMs)
			if progress ~= nil and info and info.startTime and info.endTime then
				local castDuration = (info.endTime - info.startTime) / 1000
				local castStart = info.startTime / 1000
				if castDuration and castDuration > 0 then
					local r, g, b, a = getCastProgressColor()
					local castReverse = (info.isEmpowered == true) or (info.isChannel ~= true)
					local castActive = setSwipeIndicatorState(castSwipe, true, castStart, castDuration, 1, castReverse, r, g, b, a)
					if castActive then swipeVisible = true end
				else
					setSwipeIndicatorState(castSwipe, false)
				end
			else
				setSwipeIndicatorState(castSwipe, false)
			end
		else
			setSwipeIndicatorState(castSwipe, false)
		end

		if gcdEnabled then
			local progress = getGCDProgressValue(now)
			if progress ~= nil and gcdStart and gcdDuration and gcdDuration > 0 then
				local r, g, b, a = getGCDProgressColor()
				local reverse = normalizeGCDProgressMode(db["mouseRingGCDProgressMode"]) == "ELAPSED"
				local gcdShown = setSwipeIndicatorState(gcdSwipe, true, gcdStart, gcdDuration, gcdRate, reverse, r, g, b, a)
				if gcdShown then swipeVisible = true end
			else
				setSwipeIndicatorState(gcdSwipe, false)
			end
		else
			setSwipeIndicatorState(gcdSwipe, false)
		end
	else
		ensureProgressIndicators(frame)
		hideSwipeIndicators(frame)

		if castEnabled then
			local progress = getCastProgressValue(nowMs)
			if progress ~= nil then
				local r, g, b, a = getCastProgressColor()
				frame.castTick:SetVertexColor(r, g, b, a)
				setIndicatorProgress(frame, frame.castTick, progress, frame.castTickRadius or 0)
				frame.castTick:Show()
			else
				frame.castTick:Hide()
			end
		elseif frame.castTick then
			frame.castTick:Hide()
		end

		if gcdEnabled then
			local progress = getGCDProgressValue(now)
			if progress ~= nil then
				local r, g, b, a = getGCDProgressColor()
				frame.gcdTick:SetVertexColor(r, g, b, a)
				setIndicatorProgress(frame, frame.gcdTick, progress, frame.gcdTickRadius or 0)
				frame.gcdTick:Show()
			else
				frame.gcdTick:Hide()
			end
		elseif frame.gcdTick then
			frame.gcdTick:Hide()
		end
	end

	if ringStyle and swipeVisible then
		applyRingAlphaMultiplier(frame, 1 - getProgressHideMultiplier(db))
	else
		applyRingAlphaMultiplier(frame, 1)
	end
end
addon.Mouse.functions.updateRingProgressIndicators = updateRingProgressIndicators

local function markRingStyleDirty() ringStyleDirty = true end
addon.Mouse.functions.markRingStyleDirty = markRingStyleDirty

local function applyRingStyle(inCombat)
	if not addon.db or not addon.mousePointer or not addon.mousePointer.texture1 then return end
	local db = addon.db
	local ringFrame = addon.mousePointer
	local combatActive = inCombat and true or false

	local size = db["mouseRingSize"] or 70
	local r, g, b, a = getRingColor()

	if combatActive and db["mouseRingCombatOverride"] then
		size = db["mouseRingCombatOverrideSize"] or size
		r, g, b, a = getCombatOverrideColor()
	end

	ringFrame._eqolRingBaseColor = ringFrame._eqolRingBaseColor or {}
	ringFrame._eqolRingBaseColor[1] = r
	ringFrame._eqolRingBaseColor[2] = g
	ringFrame._eqolRingBaseColor[3] = b
	ringFrame._eqolRingBaseColor[4] = a
	ringFrame._eqolAppliedRingAlphaMultiplier = nil
	ringFrame.texture1:SetSize(size, size)
	ringFrame.texture1:SetVertexColor(r, g, b, a)
	updateProgressIndicatorLayout(ringFrame, size)

	if combatActive and db["mouseRingCombatOverlay"] then
		local overlay = ensureCombatOverlay(ringFrame)
		local overlaySize = db["mouseRingCombatOverlaySize"] or size
		local orr, org, orb, ora = getCombatOverlayColor()
		overlay:SetSize(overlaySize, overlaySize)
		overlay:SetVertexColor(orr, org, orb, ora)
		overlay:Show()
	elseif ringFrame.combatOverlay then
		ringFrame.combatOverlay:Hide()
	end
end
addon.Mouse.functions.applyRingStyle = applyRingStyle

local function refreshRingStyle(inCombat)
	ringStyleDirty = true
	if not addon.mousePointer then return end
	if inCombat == nil and UnitAffectingCombat then inCombat = UnitAffectingCombat("player") and true or false end
	applyRingStyle(inCombat)
	updateRingProgressIndicators()
	ringStyleDirty = false
	lastRingCombat = inCombat and true or false
end
addon.Mouse.functions.refreshRingStyle = refreshRingStyle

local function UpdateMouseTrail(delta, cursorX, cursorY, effectiveScale)
	-- Delta = Zeit seit letztem Frame

	-- Ersten Maus-Frame sauber initialisieren
	if PresentCursorX == nil then
		PresentCursorX, PresentCursorY = cursorX, cursorY
		return -- Startposition gesetzt
	end

	-- Zeit hochzählen
	timeAccumulator = timeAccumulator + delta

	-- Aktuelle Mausposition holen, Distanz ermitteln
	PastCursorX, PastCursorY = PresentCursorX, PresentCursorY
	PresentCursorX, PresentCursorY = cursorX, cursorY

	local dx = PresentCursorX - PastCursorX
	local dy = PresentCursorY - PastCursorY
	local distanceSq = dx * dx + dy * dy

	-- Neues Trail-Element anlegen?
	if timeAccumulator >= Density and distanceSq >= MaxActuationPointSq then
		timeAccumulator = timeAccumulator - Density

		if activeCount < ElementCap and #trailPool > 0 then
			local element = trailPool[#trailPool]
			trailPool[#trailPool] = nil
			activeCount = activeCount + 1

			element:SetPoint("CENTER", UIParent, "BOTTOMLEFT", PresentCursorX / effectiveScale, PresentCursorY / effectiveScale)

			local r, g, b, a = getTrailColor()
			element:SetVertexColor(r, g, b, a)

			element.fade:SetDuration(duration)
			element.anim:Stop()
			element.anim:Play()
			element:Show()
		end
	end
end

local function createMouseRing(inCombat)
	if addon.mousePointer then
		addon.mousePointer:Show()
		if addon.Mouse.functions.refreshRingStyle then addon.Mouse.functions.refreshRingStyle(inCombat) end
		updateRingProgressIndicators()
		return
	end

	local imageFrame = _G[RING_FRAME_NAME]
	if not imageFrame then
		imageFrame = CreateFrame("Frame", RING_FRAME_NAME, UIParent, "BackdropTemplate")
		imageFrame:SetSize(120, 120)
		imageFrame:SetBackdropColor(0, 0, 0, 0)
		imageFrame:SetFrameStrata("TOOLTIP")
	end

	local texture1 = imageFrame.texture1
	if not texture1 then
		texture1 = imageFrame:CreateTexture(nil, "BACKGROUND")
		texture1:SetTexture(TEX_MOUSE)
		texture1:SetPoint("CENTER", imageFrame, "CENTER", 0, 0)
		imageFrame.texture1 = texture1
	end
	ensureProgressIndicators(imageFrame)

	if addon.db["mouseRingHideDot"] then
		if imageFrame.dot then imageFrame.dot:Hide() end
	else
		local dot = imageFrame.dot
		if not dot then
			dot = imageFrame:CreateTexture(nil, "BACKGROUND")
			dot:SetTexture(TEX_DOT)
			dot:SetSize(10, 10)
			dot:SetPoint("CENTER", imageFrame, "CENTER", 0, 0)
			imageFrame.dot = dot
		end
		dot:Show()
	end

	addon.mousePointer = imageFrame
	if addon.Mouse.functions.refreshRingStyle then addon.Mouse.functions.refreshRingStyle(inCombat) end
	updateRingProgressIndicators()
	imageFrame:Show()
end
addon.Mouse.functions.createMouseRing = createMouseRing

local function removeMouseRing()
	if addon.mousePointer then
		hideProgressIndicators(addon.mousePointer)
		addon.mousePointer:Hide()
	end
end
addon.Mouse.functions.removeMouseRing = removeMouseRing

local function updateRunnerState()
	if not addon.mouseTrailRunner then return end
	local db = addon.db
	local shouldRun = db and (db["mouseRingEnabled"] or db["mouseTrailEnabled"])
	if shouldRun then
		if addon.mouseTrailRunner:GetScript("OnUpdate") == nil then addon.mouseTrailRunner:SetScript("OnUpdate", addon.Mouse.functions.runMouseRunner) end
	elseif addon.mouseTrailRunner:GetScript("OnUpdate") ~= nil then
		addon.mouseTrailRunner:SetScript("OnUpdate", nil)
	end
end
addon.Mouse.functions.updateRunnerState = updateRunnerState

local function refreshRingVisibility()
	local db = addon.db
	if not db then return false end
	local ringOnly = db["mouseRingOnlyInCombat"]
	local combatOverride = db["mouseRingCombatOverride"]
	local combatOverlay = db["mouseRingCombatOverlay"]
	local inCombat = false
	if ringOnly or combatOverride or combatOverlay then inCombat = UnitAffectingCombat and UnitAffectingCombat("player") and true or false end
	local rightClickActive = db["mouseRingOnlyOnRightClick"] and IsMouseButtonDown and IsMouseButtonDown("RightButton")
	local ringWanted = isRingWanted(db, inCombat, rightClickActive)

	if ringWanted then
		if not addon.mousePointer then createMouseRing(inCombat) end
		if addon.mousePointer and not addon.mousePointer:IsShown() then addon.mousePointer:Show() end
		if ringStyleDirty or lastRingCombat ~= inCombat then
			applyRingStyle(inCombat)
			ringStyleDirty = false
			lastRingCombat = inCombat
		end
		updateRingProgressIndicators()
	elseif addon.mousePointer and addon.mousePointer:IsShown() then
		hideProgressIndicators(addon.mousePointer)
		addon.mousePointer:Hide()
	end

	return ringWanted
end
addon.Mouse.functions.refreshRingVisibility = refreshRingVisibility

function addon.Mouse.functions.InitState()
	local db = addon.db
	if not db then return end
	syncRingProgressState()
	refreshRingVisibility()
	if db["mouseTrailEnabled"] then applyPreset(db["mouseTrailDensity"]) end
	updateRunnerState()
end

local function handleProgressEvent(event, unit, ...)
	if event == "SPELL_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_COOLDOWN" then
		if addon.db and addon.db["mouseRingEnabled"] and shouldShowGCDProgress(addon.db) then
			updateGCDProgressState()
		else
			stopGCDProgress()
		end
		return
	end

	if not addon.db or addon.db["mouseRingEnabled"] ~= true or not shouldShowCastProgress(addon.db) then
		stopCastProgress()
		return
	end
	if unit ~= PLAYER_UNIT then return end

	if
		event == "UNIT_SPELLCAST_START"
		or event == "UNIT_SPELLCAST_CHANNEL_START"
		or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
		or event == "UNIT_SPELLCAST_EMPOWER_START"
		or event == "UNIT_SPELLCAST_EMPOWER_UPDATE"
		or event == "UNIT_SPELLCAST_DELAYED"
	then
		setCastInfoFromUnit()
	elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
		local castGUID, spellId = ...
		if not shouldIgnoreCastFail(castGUID, spellId) then stopCastProgress() end
	elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_EMPOWER_STOP" then
		stopCastProgress()
	end
end

-- Manage visibility of the ring based on combat state
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED") -- enter combat
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED") -- leave combat
eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
eventFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", PLAYER_UNIT)
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", PLAYER_UNIT)
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", PLAYER_UNIT)
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", PLAYER_UNIT)
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", PLAYER_UNIT)
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", PLAYER_UNIT)
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", PLAYER_UNIT)
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", PLAYER_UNIT)
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", PLAYER_UNIT)
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_UPDATE", PLAYER_UNIT)
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", PLAYER_UNIT)
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", PLAYER_UNIT)
eventFrame:SetScript("OnEvent", function(_, event, unit, ...)
	if not addon.db then return end
	if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
		syncRingProgressState()
		refreshRingVisibility()
		return
	end
	if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
		refreshRingVisibility()
		return
	end
	handleProgressEvent(event, unit, ...)
end)

-- Shared runner for ring + trail updates
if not addon.mouseTrailRunner then
	local runner = CreateFrame("Frame")
	addon.Mouse.functions.runMouseRunner = function(self, delta)
		local db = addon.db
		if not db then
			self:SetScript("OnUpdate", nil)
			return
		end
		if not db["mouseRingEnabled"] and not db["mouseTrailEnabled"] then
			self:SetScript("OnUpdate", nil)
			return
		end
		local ringOnly = db["mouseRingOnlyInCombat"]
		local trailOnly = db["mouseTrailOnlyInCombat"]
		local rightClickOnly = db["mouseRingOnlyOnRightClick"]
		local combatOverride = db["mouseRingCombatOverride"]
		local combatOverlay = db["mouseRingCombatOverlay"]
		local inCombat = false
		if ringOnly or trailOnly or combatOverride or combatOverlay then inCombat = UnitAffectingCombat and UnitAffectingCombat("player") and true or false end
		local rightClickActive = rightClickOnly and IsMouseButtonDown and IsMouseButtonDown("RightButton")
		local ringWanted = isRingWanted(db, inCombat, rightClickActive)
		local trailWanted = db["mouseTrailEnabled"] and (not trailOnly or inCombat)
		if trailWanted and currentPreset ~= db["mouseTrailDensity"] then applyPreset(db["mouseTrailDensity"]) end
		if trailWanted and not lastTrailWanted then
			ensureTrailPool()
			PresentCursorX, PresentCursorY = nil, nil
			timeAccumulator = 0
		end
		lastTrailWanted = trailWanted

		if ringWanted then
			if not addon.mousePointer then createMouseRing(inCombat) end
			if addon.mousePointer and not addon.mousePointer:IsShown() then addon.mousePointer:Show() end
			if ringStyleDirty or lastRingCombat ~= inCombat then
				applyRingStyle(inCombat)
				ringStyleDirty = false
				lastRingCombat = inCombat
			end
		elseif addon.mousePointer and addon.mousePointer:IsShown() then
			hideProgressIndicators(addon.mousePointer)
			addon.mousePointer:Hide()
		end

		if not ringWanted and not trailWanted then return end
		local x, y = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		if ringWanted and addon.mousePointer and addon.mousePointer:IsShown() then
			addon.mousePointer:ClearAllPoints()
			addon.mousePointer:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
			updateRingProgressIndicators()
		end
		if trailWanted then UpdateMouseTrail(delta, x, y, scale) end
	end
	addon.mouseTrailRunner = runner
	updateRunnerState()
end
