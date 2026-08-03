-- PetStrike.lua
-- Mouseover-first pet-attack helper for TBC Classic 2.5.6.
-- Core module: SavedVars, secure action button, unit resolution, slash commands,
-- auto-Growl, auto-return-follow. HUD lives in PetStrike_HUD.lua.

local ADDON_NAME = ...
local PetStrike = {}
_G.PetStrike = PetStrike

-- SavedVars (populated on ADDON_LOADED).
PetStrikeDB = PetStrikeDB or {}

local GROWL_SPELL_ID = 2649
local NO_TARGET_THROTTLE = 1.0 -- seconds

local PREFIX = "|cff33ff99PetStrike|r"
local function Say(msg)
    print(PREFIX .. ": " .. msg)
end

local function ApplyDefaults()
    if PetStrikeDB.autoGrowl  == nil then PetStrikeDB.autoGrowl  = false end
    if PetStrikeDB.autoFollow == nil then PetStrikeDB.autoFollow = true  end
    if PetStrikeDB.hudEnabled == nil then PetStrikeDB.hudEnabled = true  end
    if PetStrikeDB.hudLocked  == nil then PetStrikeDB.hudLocked  = true  end
    PetStrikeDB.hudPos = PetStrikeDB.hudPos or { point = "CENTER", x = 0, y = -140 }
    PetStrikeDB.version = "0.2.0"
end

------------------------------------------------------------
-- Unit resolution
------------------------------------------------------------

local function IsValidHostile(unit)
    if not unit or not UnitExists(unit) then return false end
    if UnitIsDead(unit) then return false end
    if not UnitCanAttack("player", unit) then return false end
    return true
end

-- Returns the unit id ("mouseover" or "target") to send the pet at, or nil.
local function ResolveTargetUnit()
    if IsValidHostile("mouseover") then return "mouseover" end
    if IsValidHostile("target")    then return "target"    end
    return nil
end
PetStrike.ResolveTargetUnit = ResolveTargetUnit

------------------------------------------------------------
-- No-target throttle
------------------------------------------------------------

local lastNoTarget = 0
local function ComplainNoTarget()
    local now = GetTime()
    if now - lastNoTarget >= NO_TARGET_THROTTLE then
        lastNoTarget = now
        Say("no valid target.")
    end
end

------------------------------------------------------------
-- Growl (auto-cast on strike)
------------------------------------------------------------

local function TryCastGrowl()
    if not PetStrikeDB.autoGrowl then return end
    if not HasPetSpells() then return end
    -- Guard: pet must exist and be alive.
    if not UnitExists("pet") or UnitIsDead("pet") then return end
    -- Silently skip if the pet doesn't know Growl.
    local name = GetSpellInfo(GROWL_SPELL_ID)
    if not name then return end
    local start, duration = GetSpellCooldown(GROWL_SPELL_ID)
    if start and duration and duration > 1.5 and (start + duration - GetTime()) > 0 then
        return -- on cooldown
    end
    -- CastSpellByID is protected for player casts, but Growl is a pet spell so we
    -- funnel through the standard pet cast path.
    if type(CastSpellByID) == "function" then
        pcall(CastSpellByID, GROWL_SPELL_ID)
    else
        pcall(CastSpellByName, name)
    end
end

------------------------------------------------------------
-- Auto-return-follow tracking
------------------------------------------------------------

local lastAttackGUID

local function RememberAttackGUID(unit)
    if unit and UnitExists(unit) then
        lastAttackGUID = UnitGUID(unit)
    else
        lastAttackGUID = nil
    end
end

local function MaybeAutoFollow(deadGUID)
    if not PetStrikeDB.autoFollow then return end
    if not lastAttackGUID or deadGUID ~= lastAttackGUID then return end
    lastAttackGUID = nil
    -- If a new valid target is present, don't yank the pet.
    if ResolveTargetUnit() then return end
    if not (UnitExists("pet") and not UnitIsDead("pet")) then return end
    -- PetFollow is protected in combat; defer to PLAYER_REGEN_ENABLED.
    if InCombatLockdown() then
        pendingFollow = true
    else
        pcall(PetFollow)
    end
end

------------------------------------------------------------
-- Secure attack button
------------------------------------------------------------

-- SecureActionButtonTemplate with a static macrotext. The keybind is bound
-- directly to this button via Bindings.xml ("CLICK PetStrikeAttackButton:LeftButton"),
-- so the hardware keypress drives the secure path with no Lua taint. Do NOT call
-- attackBtn:Click() from insecure code paths in combat — that taints and produces
-- the "action blocked" popup.
local attackBtn = CreateFrame("Button", "PetStrikeAttackButton", UIParent, "SecureActionButtonTemplate")
attackBtn:RegisterForClicks("AnyUp", "AnyDown")
attackBtn:SetAttribute("type", "macro")
attackBtn:SetAttribute("macrotext",
    "/petattack [@mouseover,harm,nodead,exists]\n" ..
    "/petattack [@target,harm,nodead,exists]")
-- Kept off-screen (rather than :Hide()) so bindings still resolve.
attackBtn:ClearAllPoints()
attackBtn:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
attackBtn:SetSize(1, 1)
attackBtn:SetAlpha(0)

-- PostClick fires after the secure command runs — safe place to do auxiliary
-- work (GUID tracking, no-target complaint). Growl is deferred to non-combat.
attackBtn:SetScript("PostClick", function()
    local unit = ResolveTargetUnit()
    if unit then
        RememberAttackGUID(unit)
        if not InCombatLockdown() then
            TryCastGrowl()
        end
    else
        ComplainNoTarget()
    end
end)

PetStrike.AttackButton = attackBtn

------------------------------------------------------------
-- Slash commands
------------------------------------------------------------

local function PrintHelp()
    Say("commands:")
    print("  /petstrike                   - send pet at mouseover, fallback to target")
    print("  /petstrike growl  on|off     - toggle auto-Growl (spell " .. GROWL_SPELL_ID .. ")")
    print("  /petstrike follow on|off     - toggle auto-return-follow")
    print("  /petstrike hud on|off|unlock|lock|reset")
    print("  /petstrike help              - show this help")
    print("  Macro: /click PetStrikeAttackButton")
end

local function ToggleArg(name, key, arg)
    if arg == "on" then
        PetStrikeDB[key] = true
        Say(name .. ": on")
    elseif arg == "off" then
        PetStrikeDB[key] = false
        Say(name .. ": off")
    else
        Say(name .. ": " .. (PetStrikeDB[key] and "on" or "off") .. " (use on|off)")
    end
end

SLASH_PETSTRIKE1 = "/petstrike"
SlashCmdList["PETSTRIKE"] = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower() or ""
    rest = rest and rest:lower() or ""

    if cmd == "" then
        -- Route through the secure button. Only safe to Click() from Lua when
        -- OUT of combat; in combat, insecure Click() taints and gets blocked.
        -- Users should bind the key directly (Bindings.xml "CLICK PetStrikeAttackButton")
        -- so hardware keypresses work in combat without going through Lua.
        if InCombatLockdown() then
            Say("in combat — bind a key to 'Send pet at mouseover/target' in Key Bindings for combat use.")
        else
            attackBtn:Click()
        end
        return
    elseif cmd == "help" or cmd == "?" then
        PrintHelp()
    elseif cmd == "growl" then
        ToggleArg("auto-Growl", "autoGrowl", rest)
    elseif cmd == "follow" then
        ToggleArg("auto-follow", "autoFollow", rest)
    elseif cmd == "hud" then
        if PetStrike.HUD and PetStrike.HUD.HandleCommand then
            PetStrike.HUD.HandleCommand(rest)
        else
            Say("HUD module not loaded.")
        end
    else
        Say("unknown command '" .. cmd .. "'. Try /petstrike help")
    end
end

------------------------------------------------------------
-- Keybinding
------------------------------------------------------------

BINDING_HEADER_PETSTRIKE                                = "PetStrike"
BINDING_NAME_PETSTRIKE_STOP                             = "Stop pet (Follow)"
_G["BINDING_NAME_CLICK PetStrikeAttackButton:LeftButton"] = "Send pet at mouseover/target"

local pendingFollow = false

function PetStrike_Stop()
    if not (UnitExists("pet") and not UnitIsDead("pet")) then return end
    if InCombatLockdown() then
        pendingFollow = true
        Say("stop queued — will follow when out of combat.")
    else
        pcall(PetFollow)
        lastAttackGUID = nil
    end
end

------------------------------------------------------------
-- Event plumbing
------------------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_LOGOUT")
f:RegisterEvent("UNIT_DIED")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")

f:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            ApplyDefaults()
        end
    elseif event == "PLAYER_LOGIN" then
        Say("v" .. (PetStrikeDB.version or "?") .. " loaded. /petstrike help")
    elseif event == "UNIT_DIED" then
        -- Older API path (may or may not fire on Classic; belt+suspenders).
        local destGUID = select(6, ...) -- unreliable; prefer CLEU below
        if destGUID then MaybeAutoFollow(destGUID) end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        -- Classic-friendly signature: CombatLogGetCurrentEventInfo.
        if type(CombatLogGetCurrentEventInfo) == "function" then
            local _, subevent, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
            if subevent == "UNIT_DIED" and destGUID then
                MaybeAutoFollow(destGUID)
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Combat ended: run any deferred protected calls.
        if pendingFollow then
            pendingFollow = false
            if UnitExists("pet") and not UnitIsDead("pet") then
                pcall(PetFollow)
            end
            lastAttackGUID = nil
        end
    end
end)

PetStrike.IsValidHostile = IsValidHostile
PetStrike.Say = Say
