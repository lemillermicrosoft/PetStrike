-- PetStrike.lua
-- Minimal scaffold. Real logic (mouseover pet attack, fallback, HUD, keybinds)
-- lands via follow-up feature PRs.

local ADDON_NAME = ...
local PetStrike = {}
_G.PetStrike = PetStrike

PetStrikeDB = PetStrikeDB or {}

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        PetStrikeDB.version = "0.1.0"
    elseif event == "PLAYER_LOGIN" then
        print("|cff33ff99PetStrike|r loaded. Try /petstrike")
    end
end)

SLASH_PETSTRIKE1 = "/petstrike"
SlashCmdList["PETSTRIKE"] = function(msg)
    print("|cff33ff99PetStrike|r v0.1.0 — scaffold only. Mouseover pet-attack logic coming soon.")
end
