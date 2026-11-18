--[[ Righteous Fury Alerter ----------------------------------------------------

  Shows a big icon with "RIGHTEOUS FURY OFF!" while the paladin buff
  Righteous Fury (spell 25780) is missing, in and out of combat.

  It stays quiet out in the open world while you are not in combat; it warns
  during fights and anywhere inside an instance (dungeon, raid, BG).

  Why this works in combat: while auras are "secret" (in combat on this
  client) aura *names* cannot be read, but the client still answers
  C_UnitAuras.GetUnitAuraBySpellID() for a spell ID. This addon asks for
  spell 25780 by ID first and only falls back to name/index scanning when
  that API does not exist.

  Slash commands:
    /rfa         toggle the debug line
    /rfa move    unlock the icon so you can drag it (again to lock)
    /rfa test    flash the icon for 5 seconds
    /rfa reset   put the icon back at screen centre
    /rfa sound   toggle the sound alert

  Original addon: "Righteous Fury Remember" by mddmz
  (https://www.curseforge.com/wow/addons/righteousfuryremember, project 1801419),
  which installed as the RighteousFuryAlerter folder. This is a rewrite: same
  idea and same folder name, spell-ID based presence instead of name matching.
  MIT licensed, 2026 Felippe Burk. See CREDITS.md and LICENSE.

---------------------------------------------------------------------------- ]]

local RF_SPELL_ID = 25780
local RF_ICON     = "Interface\\Icons\\Spell_Holy_SealOfFury"
local RF_NAMES    = {
  ["Righteous Fury"] = true,
  ["Fúria Íntegra"]  = true,
  ["Furia Integra"]  = true,
}

------------------------------------------------------------------------------
-- Saved settings
------------------------------------------------------------------------------

local defaults = {
  point      = "CENTER",
  x          = 0,
  y          = 120,
  size       = 96,
  sound      = true,
  soundEvery = 5,
  unlocked   = false,
}

RFA_DB = type(RFA_DB) == "table" and RFA_DB or {}
for key, value in pairs(defaults) do
  if RFA_DB[key] == nil then
    RFA_DB[key] = value
  end
end

-- Never start a session in drag mode: a forgotten unlock would leave a
-- permanent icon on screen.
RFA_DB.unlocked = false

local function db()
  return RFA_DB
end

------------------------------------------------------------------------------
-- Frames
------------------------------------------------------------------------------

local alert = CreateFrame("Frame", "RFA_AlertFrame", UIParent)
alert:SetSize(db().size, db().size)
alert:SetMovable(true)
alert:SetClampedToScreen(true)
alert:SetFrameStrata("HIGH")
alert:EnableMouse(false)
alert:RegisterForDrag("LeftButton")
alert:Hide()

local border = alert:CreateTexture(nil, "BACKGROUND")
border:SetPoint("TOPLEFT", alert, "TOPLEFT", -4, 4)
border:SetPoint("BOTTOMRIGHT", alert, "BOTTOMRIGHT", 4, -4)
border:SetColorTexture(0.95, 0.05, 0.05, 0.85)

local icon = alert:CreateTexture(nil, "ARTWORK")
icon:SetAllPoints(alert)
icon:SetTexture(RF_ICON)
icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

local label = alert:CreateFontString(nil, "OVERLAY")
do
  local font, _, flags = GameFontNormalLarge:GetFont()
  label:SetFont(font or STANDARD_TEXT_FONT, 20, flags or "OUTLINE")
end
label:SetTextColor(1, 0.15, 0.15)
label:SetPoint("TOP", alert, "BOTTOM", 0, -4)

local ALERT_TEXT = "RIGHTEOUS FURY OFF!"
label:SetText(ALERT_TEXT)

local function ApplyPosition()
  alert:ClearAllPoints()
  alert:SetPoint(db().point or "CENTER", UIParent, db().point or "CENTER", db().x or 0, db().y or 0)
end
ApplyPosition()

local function ApplyUnlockState()
  local unlocked = db().unlocked
  alert:EnableMouse(unlocked)
  label:SetText(unlocked and "DRAG ME" or ALERT_TEXT)
end
ApplyUnlockState()

alert:SetScript("OnDragStart", function(self)
  if db().unlocked then
    self:StartMoving()
  end
end)

alert:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local point, _, _, x, y = self:GetPoint(1)
  db().point, db().x, db().y = point or "CENTER", x or 0, y or 0
end)

------------------------------------------------------------------------------
-- Reading the buff
--
-- Each helper returns true (buff is there), false (it is not), or nil when
-- the client refuses to answer.
------------------------------------------------------------------------------

local issecret = type(issecretvalue) == "function" and issecretvalue or function() return false end

local CUA = C_UnitAuras
local GetPlayerAuraBySpellID = CUA and CUA.GetPlayerAuraBySpellID
local GetUnitAuraBySpellID   = CUA and CUA.GetUnitAuraBySpellID
local GetAuraDataByIndex     = CUA and CUA.GetAuraDataByIndex
local FindAuraBySpellId      = AuraUtil and AuraUtil.FindAuraBySpellId

-- Anything the client marks as secret may not be inspected. Every read below
-- is wrapped as a whole, so a restricted answer simply becomes "unknown".
local function Ask(read)
  local ok, aura = pcall(read)
  if not ok then
    return nil
  end
  local okCheck, present = pcall(function()
    if aura then
      return true
    end
    return false
  end)
  if okCheck then
    return present
  end
  return nil
end

local function ByUnitSpellID()
  if not GetUnitAuraBySpellID then
    return nil
  end
  return Ask(function() return GetUnitAuraBySpellID("player", RF_SPELL_ID) end)
end

local function ByPlayerSpellID()
  if not GetPlayerAuraBySpellID then
    return nil
  end
  return Ask(function() return GetPlayerAuraBySpellID(RF_SPELL_ID) end)
end

local function ByAuraUtilSpellID()
  if not FindAuraBySpellId then
    return nil
  end
  return Ask(function() return FindAuraBySpellId(RF_SPELL_ID, "player") end)
end

local function ByIndex()
  if not GetAuraDataByIndex then
    return nil
  end

  local ok, result = pcall(function()
    for i = 1, 40 do
      local aura = GetAuraDataByIndex("player", i, "HELPFUL")
      if not aura then
        return false
      end

      if issecret(aura) or issecret(aura.name) or issecret(aura.spellId) then
        return nil
      end

      if aura.spellId == RF_SPELL_ID or RF_NAMES[aura.name] == true then
        return true
      end
    end
    return false
  end)

  if ok then
    return result
  end
  return nil
end

local function ByLegacyUnitBuff()
  if type(UnitBuff) ~= "function" then
    return nil
  end

  local ok, result = pcall(function()
    for i = 1, 40 do
      local name, _, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
      if name == nil then
        return false
      end
      if issecret(name) or issecret(spellId) then
        return nil
      end
      if spellId == RF_SPELL_ID or RF_NAMES[name] == true then
        return true
      end
    end
    return false
  end)

  if ok then
    return result
  end
  return nil
end

-- After a zone or instance change the client briefly reports an empty aura
-- list; that must not be mistaken for "the buff is gone".
local settleUntil = 0

local function Restricted()
  local locked = false

  -- Two separate protected calls: if one of them throws, the other still runs.
  pcall(function()
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
      locked = true
    end
  end)

  pcall(function()
    if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then
      locked = true
    end
  end)

  return locked
end

-- While auras are locked down, "no such aura" can simply mean "you are not
-- allowed to look" and that is exactly what made name based reminders fire in
-- combat while the buff was up. A positive answer is always trustworthy, so
-- once a locked-down combat has produced one from GetUnitAuraBySpellID we
-- know that call still answers, and only then do we believe a negative one.
local trustedWhileLocked = false

local probe = { locked = false, unit = nil, player = nil, util = nil, index = nil, legacy = nil, present = nil }

local function Probe()
  local locked = Restricted()
  if not locked then
    trustedWhileLocked = false
  end

  local unit   = ByUnitSpellID()
  local player = locked and nil or ByPlayerSpellID()
  local util   = locked and nil or ByAuraUtilSpellID()
  local index  = locked and nil or ByIndex()
  local legacy = locked and nil or ByLegacyUnitBuff()

  local present
  if unit ~= nil then
    if not locked then
      present = unit
    elseif unit == true then
      trustedWhileLocked = true
      present = true
    elseif trustedWhileLocked then
      present = false
    end
  elseif player ~= nil then
    present = player
  elseif util ~= nil then
    present = util
  elseif index ~= nil then
    present = index
  elseif legacy ~= nil then
    present = legacy
  end

  probe.locked, probe.unit, probe.player = locked, unit, player
  probe.util, probe.index, probe.legacy, probe.present = util, index, legacy, present

  -- Just zoned in: hold off on "missing" until the client settled.
  if present == false and GetTime() < settleUntil then
    present = nil
    probe.present = nil
  end

  return present
end

local function IsFuryPresent()
  return Probe()
end

------------------------------------------------------------------------------
-- State / display
------------------------------------------------------------------------------

local lastKnownPresent = true   -- assumed until the client says otherwise
local showing          = false
local shownAt          = 0
local soundAt          = 0
local debugOn          = false
local debugPresent     = nil
local debugShown       = nil
local testUntil        = 0

local function IsPaladin()
  local _, class = UnitClass("player")
  return class == "PALADIN"
end

local function CanWatch()
  return IsPaladin() and not UnitIsDeadOrGhost("player")
end

-- Out in the open world and out of combat the warning stays quiet: it is only
-- meant for fights and for instances (where you are expected to keep it up).
local function SuppressedOutOfCombat()
  local inInstance = false
  pcall(function()
    inInstance = IsInInstance() and true or false
  end)
  if inInstance then
    return false
  end

  local inCombat = false
  pcall(function()
    inCombat = InCombatLockdown() and true or false
  end)
  return not inCombat
end

local function Refresh()
  local now = GetTime()

  if not CanWatch() then
    if showing then
      alert:Hide()
      showing = false
    end
    return
  end

  local present = IsFuryPresent()
  if present ~= nil then
    lastKnownPresent = present
  end

  local missing = not lastKnownPresent
  if missing and SuppressedOutOfCombat() then
    missing = false
  end
  local shouldShow = missing or db().unlocked or now < testUntil

  if debugOn and (present ~= debugPresent or shouldShow ~= debugShown) then
    debugPresent, debugShown = present, shouldShow
    print(("|cff33ff99RFA|r present=%s missing=%s shown=%s"):format(
      tostring(present), tostring(missing), tostring(shouldShow)))
  end

  if shouldShow then
    if not showing then
      showing = true
      shownAt = now
      soundAt = 0
      alert:Show()
    end
  elseif showing then
    showing = false
    alert:Hide()
  end
end

local events = CreateFrame("Frame")
for _, event in ipairs({
  "PLAYER_LOGIN",
  "PLAYER_ENTERING_WORLD",
  "PLAYER_REGEN_ENABLED",
  "PLAYER_REGEN_DISABLED",
  "SPELLS_CHANGED",
  "PLAYER_SPECIALIZATION_CHANGED",
  "PLAYER_DEAD",
  "PLAYER_ALIVE",
  "PLAYER_UNGHOST",
  "UNIT_AURA",
  "UNIT_FLAGS",
  "ZONE_CHANGED_NEW_AREA",
}) do
  events:RegisterEvent(event)
end

events:SetScript("OnEvent", function(_, event, unit)
  if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    -- The aura list is empty for a moment while the zone loads.
    settleUntil = GetTime() + 3
  end
  if (event == "UNIT_AURA" or event == "UNIT_FLAGS") and unit and unit ~= "player" then
    return
  end
  Refresh()
end)

local accumulator = 0

-- The tick lives on the (always shown) event frame, because OnUpdate does not
-- run on hidden frames and the alert itself is hidden most of the time.
events:SetScript("OnUpdate", function(_, elapsed)
  -- Pulse the icon while it is up.
  if showing then
    local t = GetTime()
    icon:SetAlpha(0.55 + 0.45 * math.abs(math.sin(t * 4)))

    if db().sound and not db().unlocked and t > shownAt + 1.5 then
      if t >= soundAt then
        soundAt = t + (tonumber(db().soundEvery) or 5)
        pcall(PlaySound, 8959)
      end
    end
  end

  -- Cheap poll so a missed event can never leave a stale state.
  accumulator = accumulator + elapsed
  if accumulator >= 0.4 then
    accumulator = 0
    Refresh()
  end
end)

------------------------------------------------------------------------------
-- Slash command
------------------------------------------------------------------------------

local function Describe(value)
  if value == true then
    return "present"
  end
  if value == false then
    return "absent"
  end
  return "unknown"
end

local function PrintStatus()
  print(("|cff33ff99RFA|r RF %s | locked %s | unit %s | player %s | aurautil %s | index %s | buff %s | trusted %s | last %s | zone %s | quiet %s"):format(
    Describe(probe.present),
    tostring(probe.locked),
    Describe(probe.unit),
    Describe(probe.player),
    Describe(probe.util),
    Describe(probe.index),
    Describe(probe.legacy),
    tostring(trustedWhileLocked),
    lastKnownPresent and "present" or "missing",
    tostring(GetRealZoneText and GetRealZoneText() or "?"),
    tostring(SuppressedOutOfCombat())))
end

SLASH_RIGHTEOUSFURYALERTER1 = "/rfa"
SlashCmdList["RIGHTEOUSFURYALERTER"] = function(message)
  local command = (message or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

  if command == "" then
    PrintStatus()
  elseif command == "debug" then
    debugOn = not debugOn
    debugPresent, debugShown = nil, nil
    print(("|cff33ff99RFA|r debug %s (prints only when the state changes)"):format(debugOn and "on" or "off"))
  elseif command == "move" then
    db().unlocked = not db().unlocked
    ApplyUnlockState()
    if db().unlocked then
      alert:Show()
      showing = true
      shownAt = GetTime()
      print("|cff33ff99RFA|r drag the icon where you want it, then /rfa move to lock it.")
    else
      print("|cff33ff99RFA|r locked.")
      Refresh()
    end
  elseif command == "test" then
    testUntil = GetTime() + 5
    alert:Show()
    showing = true
    shownAt = GetTime()
    soundAt = GetTime() + 1.5
    print("|cff33ff99RFA|r test shown for 5 seconds.")
  elseif command == "reset" then
    db().point, db().x, db().y = "CENTER", 0, 120
    ApplyPosition()
    print("|cff33ff99RFA|r position reset.")
  elseif command == "sound" then
    db().sound = not db().sound
    print(("|cff33ff99RFA|r sound %s"):format(db().sound and "on" or "off"))
  else
    print("|cff33ff99RFA|r commands: /rfa, /rfa debug, /rfa move, /rfa test, /rfa reset, /rfa sound")
  end
end
