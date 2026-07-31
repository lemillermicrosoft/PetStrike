# Changelog

## v0.2.0 - 2026-07-31

- Mouseover-first pet attack: `/petstrike` sends the pet at `mouseover` if it's alive and hostile, falling back to `target`. Routed through a `SecureActionButtonTemplate` (`PetStrikeAttackButton`) so it works in combat lockdown and via `/click PetStrikeAttackButton` macros.
- Throttled "no valid target" chat message (max once per second).
- Auto-Growl option (SavedVar `autoGrowl`, default off; spell ID 2649, silent when unlearned or on cooldown).
- Auto-return + follow (SavedVar `autoFollow`, default on): tracks last attack GUID and issues `PetFollow()` on `UNIT_DIED` when no new valid target exists.
- Pet status HUD (`PetStrike_HUD.lua`): pet name, HP bar with %, happiness, current mode. Draggable when unlocked, position saved, hides when no pet, throttled ~4Hz.
- Keybindings: `PETSTRIKE_ATTACK` and `PETSTRIKE_STOP` under the PetStrike header in Key Bindings.
- Slash subcommands: `growl on|off`, `follow on|off`, `hud on|off|unlock|lock|reset`, `help`.

## v0.1.0 - 2026-07-31

- Initial scaffold. Loads in-game, prints hello on `/petstrike`.
