-- PetStrike_HUD.lua
-- Small movable pet-status HUD. Throttled ~4Hz. Hides when no pet.

local PetStrike = _G.PetStrike
if not PetStrike then return end

local HUD = {}
PetStrike.HUD = HUD

local THROTTLE = 0.25 -- 4Hz
local COLOR    = { 0.20, 1.00, 0.60 } -- IconTexture green-ish

local frame, nameFS, modeFS, hpBar, hpFS, happyFS

local function SavedPos()
    return PetStrikeDB.hudPos or { point = "CENTER", x = 0, y = -140 }
end

local function SavePos()
    local p = frame:GetPoint(1)
    local point, _, _, x, y = frame:GetPoint(1)
    PetStrikeDB.hudPos = { point = point or "CENTER", x = x or 0, y = y or 0 }
end

local function BuildFrame()
    if frame then return end
    frame = CreateFrame("Frame", "PetStrikeHUDFrame", UIParent, "BackdropTemplate")
    frame:SetSize(180, 46)
    local pos = SavedPos()
    frame:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or -140)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        frame:SetBackdropColor(0, 0, 0, 0.55)
        frame:SetBackdropBorderColor(COLOR[1], COLOR[2], COLOR[3], 0.9)
    end

    -- Draggable when unlocked.
    frame:SetMovable(true)
    frame:EnableMouse(false)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) if not PetStrikeDB.hudLocked then self:StartMoving() end end)
    frame:SetScript("OnDragStop",  function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint(1)
        PetStrikeDB.hudPos = { point = point or "CENTER", x = x or 0, y = y or 0 }
    end)

    nameFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameFS:SetPoint("TOPLEFT", 8, -6)
    nameFS:SetTextColor(COLOR[1], COLOR[2], COLOR[3])

    happyFS = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    happyFS:SetPoint("TOPRIGHT", -8, -6)

    hpBar = CreateFrame("StatusBar", nil, frame)
    hpBar:SetPoint("BOTTOMLEFT", 8, 18)
    hpBar:SetPoint("BOTTOMRIGHT", -8, 18)
    hpBar:SetHeight(10)
    hpBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    hpBar:SetStatusBarColor(COLOR[1], COLOR[2], COLOR[3])
    hpBar:SetMinMaxValues(0, 1)
    hpBar:SetValue(1)

    hpFS = hpBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hpFS:SetPoint("CENTER", hpBar, "CENTER")

    modeFS = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    modeFS:SetPoint("BOTTOMLEFT", 8, 4)

    frame:Hide()
end

local function CurrentMode()
    if not UnitExists("pet") then return "Idle" end
    if UnitIsDead("pet") then return "Dead" end
    -- PetHasActionBar / GetPetActionInfo could refine this; keep it cheap.
    if UnitAffectingCombat("pet") then return "Attacking" end
    return "Following"
end

local function HappyText()
    if type(GetPetHappiness) ~= "function" then return "" end
    local h = GetPetHappiness()
    if h == 3 then return "|cff33ff33:)|r"
    elseif h == 2 then return "|cffffff33:|||r"
    elseif h == 1 then return "|cffff3333:(|r"
    else return "" end
end

local acc = 0
local function OnUpdate(self, elapsed)
    acc = acc + elapsed
    if acc < THROTTLE then return end
    acc = 0

    if not PetStrikeDB.hudEnabled then
        if frame:IsShown() then frame:Hide() end
        return
    end

    if not UnitExists("pet") then
        if frame:IsShown() then frame:Hide() end
        return
    end
    if not frame:IsShown() then frame:Show() end

    nameFS:SetText(UnitName("pet") or "Pet")
    local hp, hpMax = UnitHealth("pet"), UnitHealthMax("pet")
    if hpMax and hpMax > 0 then
        hpBar:SetMinMaxValues(0, hpMax)
        hpBar:SetValue(hp)
        hpFS:SetText(string.format("%d%%", math.floor((hp / hpMax) * 100 + 0.5)))
    else
        hpBar:SetValue(0)
        hpFS:SetText("--")
    end
    happyFS:SetText(HappyText())
    modeFS:SetText(CurrentMode())
end

local function ApplyLock()
    if not frame then return end
    if PetStrikeDB.hudLocked then
        frame:EnableMouse(false)
        if frame.SetBackdropBorderColor then
            frame:SetBackdropBorderColor(COLOR[1], COLOR[2], COLOR[3], 0.9)
        end
    else
        frame:EnableMouse(true)
        if frame.SetBackdropBorderColor then
            frame:SetBackdropBorderColor(1, 0.8, 0.2, 1)
        end
    end
end

function HUD.HandleCommand(arg)
    arg = (arg or ""):lower()
    BuildFrame()
    if arg == "on" then
        PetStrikeDB.hudEnabled = true
        PetStrike.Say("HUD: on")
    elseif arg == "off" then
        PetStrikeDB.hudEnabled = false
        frame:Hide()
        PetStrike.Say("HUD: off")
    elseif arg == "unlock" then
        PetStrikeDB.hudLocked = false
        ApplyLock()
        PetStrike.Say("HUD: unlocked (drag to move)")
    elseif arg == "lock" then
        PetStrikeDB.hudLocked = true
        ApplyLock()
        PetStrike.Say("HUD: locked")
    elseif arg == "reset" then
        PetStrikeDB.hudPos = { point = "CENTER", x = 0, y = -140 }
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, -140)
        PetStrike.Say("HUD: position reset")
    else
        PetStrike.Say("HUD: " .. (PetStrikeDB.hudEnabled and "on" or "off") ..
            " / " .. (PetStrikeDB.hudLocked and "locked" or "unlocked"))
        print("  /petstrike hud on|off|unlock|lock|reset")
    end
end

-- Init on PLAYER_LOGIN so SavedVars are ready.
local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:RegisterEvent("PLAYER_LOGOUT")
init:RegisterEvent("UNIT_PET")
init:RegisterEvent("PET_UI_UPDATE")
init:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        BuildFrame()
        ApplyLock()
        frame:SetScript("OnUpdate", OnUpdate)
    elseif event == "PLAYER_LOGOUT" then
        -- SavedVars auto-persist; nothing to do.
    end
end)
