local addonName, addon = ...

local LSM = LibStub("LibSharedMedia-3.0")
local effectPath = "Interface\\AddOns\\" .. addonName .. "\\Sounds\\Effects\\"
local voiceoverPath = "Interface\\AddOns\\" .. addonName .. "\\Sounds\\Voiceovers\\"

-- Soundeffects
LSM:Register("sound", "For the Horde", effectPath .. "bloodlust.ogg")
LSM:Register("sound", "EQOL: Bite", effectPath .. "cartoonbite.ogg")
LSM:Register("sound", "EQOL: Punch", effectPath .. "gamingpunch.ogg")

-- Voiceovers
LSM:Register("sound", "EQOL: Adds", voiceoverPath .. "Adds.ogg")
LSM:Register("sound", "EQOL: Add", voiceoverPath .. "Add.ogg")
LSM:Register("sound", "EQOL: AoE", voiceoverPath .. "AoE.ogg")
LSM:Register("sound", "EQOL: Assist", voiceoverPath .. "Assist.ogg")
LSM:Register("sound", "EQOL: Avoid", voiceoverPath .. "Avoid.ogg")
LSM:Register("sound", "EQOL: Bait", voiceoverPath .. "Bait.ogg")
LSM:Register("sound", "EQOL: Bleed", voiceoverPath .. "Bleed.ogg")
LSM:Register("sound", "EQOL: CC", voiceoverPath .. "CC.ogg")
LSM:Register("sound", "EQOL: Charge", voiceoverPath .. "Charge.ogg")
LSM:Register("sound", "EQOL: Clear", voiceoverPath .. "Clear.ogg")
LSM:Register("sound", "EQOL: Dance", voiceoverPath .. "Dance.ogg")
LSM:Register("sound", "EQOL: Debuff", voiceoverPath .. "Debuff.ogg")
LSM:Register("sound", "EQOL: Decurse", voiceoverPath .. "Decurse.ogg")
LSM:Register("sound", "EQOL: Defensive", voiceoverPath .. "Defensive.ogg")
LSM:Register("sound", "EQOL: Dispell", voiceoverPath .. "Dispell.ogg")
LSM:Register("sound", "EQOL: Dot", voiceoverPath .. "Dot.ogg")
LSM:Register("sound", "EQOL: Don't move", voiceoverPath .. "Don't move.ogg")
LSM:Register("sound", "EQOL: Drop", voiceoverPath .. "Drop.ogg")
LSM:Register("sound", "EQOL: Enrage", voiceoverPath .. "Enrage.ogg")
LSM:Register("sound", "EQOL: Enter", voiceoverPath .. "Enter.ogg")
LSM:Register("sound", "EQOL: Feet", voiceoverPath .. "Feet.ogg")
LSM:Register("sound", "EQOL: Fixate", voiceoverPath .. "Fixate.ogg")
LSM:Register("sound", "EQOL: Focus", voiceoverPath .. "Focus.ogg")
LSM:Register("sound", "EQOL: Frontal", voiceoverPath .. "Frontal.ogg")
LSM:Register("sound", "EQOL: Hide", voiceoverPath .. "Hide.ogg")
LSM:Register("sound", "EQOL: Immunity", voiceoverPath .. "Immunity.ogg")
LSM:Register("sound", "EQOL: Intermission", voiceoverPath .. "Intermission.ogg")
LSM:Register("sound", "EQOL: Interrupt", voiceoverPath .. "Interrupt.ogg")
LSM:Register("sound", "EQOL: Invis", voiceoverPath .. "Invis.ogg")
LSM:Register("sound", "EQOL: Jump", voiceoverPath .. "Jump.ogg")
LSM:Register("sound", "EQOL: Knock", voiceoverPath .. "Knock.ogg")
LSM:Register("sound", "EQOL: Move", voiceoverPath .. "Move.ogg")
LSM:Register("sound", "EQOL: Pull", voiceoverPath .. "Pull.ogg")
LSM:Register("sound", "EQOL: Reflect", voiceoverPath .. "Reflect.ogg")
LSM:Register("sound", "EQOL: Root", voiceoverPath .. "Root.ogg")
LSM:Register("sound", "EQOL: Soak", voiceoverPath .. "Soak.ogg")
LSM:Register("sound", "EQOL: Soon", voiceoverPath .. "Soon.ogg")
LSM:Register("sound", "EQOL: Spread", voiceoverPath .. "Spread.ogg")
LSM:Register("sound", "EQOL: Stack", voiceoverPath .. "Stack.ogg")
LSM:Register("sound", "EQOL: Stopcast", voiceoverPath .. "Stopcast.ogg")
LSM:Register("sound", "EQOL: Stun", voiceoverPath .. "Stun.ogg")
LSM:Register("sound", "EQOL: Targeted", voiceoverPath .. "Targeted.ogg")
LSM:Register("sound", "EQOL: Turn", voiceoverPath .. "Turn.ogg")
LSM:Register("sound", "EQOL: Use", voiceoverPath .. "Use.ogg")


LSM:Register("sound", "EQOL: |cFF000000|rAMZ |T237510:16|t", voiceoverPath .. "AMZ.ogg")

LSM:Register("sound", "EQOL: |cFF000000|rDarkness |T1305154:16|t", voiceoverPath .. "Darkness.ogg")

LSM:Register("sound", "EQOL: |cFF000000|rBarkskin |T572025:16|t", voiceoverPath .. "Barkskin.ogg")
LSM:Register("sound", "EQOL: |cFF000000|rIronbark |T463283:16|t", voiceoverPath .. "Ironbark.ogg")
LSM:Register("sound", "EQOL: |cFF000000|rRoar |T463283:16|t", voiceoverPath .. "Roar.ogg")

LSM:Register("sound", "EQOL: |cFF000000|rTime Dilation |T4622478:16|t", voiceoverPath .. "Time Dilation.ogg")

LSM:Register("sound", "EQOL: |cFF000000|rChi-Ji |T877514:16|t", voiceoverPath .. "Chi-Ji.ogg")
LSM:Register("sound", "EQOL: |cFF000000|rCocoon |T627485:16|t", voiceoverPath .. "Cocoon.ogg")

LSM:Register("sound", "EQOL: |cFF000000|rAutumn |T3636843:16|t", voiceoverPath .. "Autumn.ogg")
LSM:Register("sound", "EQOL: |cFF000000|rDevotion Aura |T135893:16|t", voiceoverPath .. "Devotion Aura.ogg")
LSM:Register("sound", "EQOL: |cFF000000|rSac |T135966:16|t", voiceoverPath .. "Sac.ogg")

LSM:Register("sound", "EQOL: |cFF000000|rBarrier |T253400:16|t", voiceoverPath .. "Barrier.ogg")
LSM:Register("sound", "EQOL: |cFF000000|rGuardian Spirit |T237542:16|t", voiceoverPath .. "Guardian Spirit.ogg")

LSM:Register("sound", "EQOL: |cFF000000|rAscendence |T135791:16|t", voiceoverPath .. "Ascendence.ogg")

LSM:Register("sound", "EQOL: |cFF000000|rStoneform |T136225:16|t", voiceoverPath .. "Stoneform.ogg")
