# PetStrike — PLAN

## Vision

A no-fuss hunter utility for TBC Classic 2.5.6: one keybind or macro sends your pet to the right target every time. Mouseover if it's a valid hostile, current target otherwise, nothing if neither. Small, fast, no config bloat.

## Scope (MVP)

1. **Mouseover-first pet attack.** `/petstrike` (and a reusable macro snippet) sends the pet to attack `mouseover` if it exists, is alive, hostile, and attackable; otherwise falls back to `target`; otherwise no-op with a subtle message.
2. **Auto-Growl option.** Toggle to also cast Growl on the chosen target if off cooldown (opt-in, off by default).
3. **Auto-return + follow.** Optional: if the previously-attacked target is dead/gone and no new valid target exists, issue Pet Follow so the pet doesn't wander.
4. **Pet status HUD.** Small movable frame showing pet name, HP%, happiness, and current mode (attacking / following / passive). Hides out of combat if empty.
5. **Stop-attack keybind.** Bindable action to force Pet Follow immediately — panic button for pulls gone wrong.

## Technical Tasks

- Slash command + `SecureActionButtonTemplate` macro for pet attack (must be secure since it commands pets in combat).
- Unit validation helpers: `UnitExists`, `UnitIsDead`, `UnitCanAttack`, `UnitIsEnemy`.
- Growl detection via `GetSpellCooldown` / spellbook scan (localization-safe via spell ID where possible).
- SavedVariables: `enabled`, `autoGrowl`, `autoFollow`, `hudPos`, `hudEnabled`.
- HUD frame with `OnUpdate` throttled to ~4Hz.
- Keybinding header + localized binding names.

## QA

- Test with an active pet (Beast Mastery, Marksman, Survival hunter).
- Test mouseover on friendly, dead, out-of-range, and neutral units — should fall back cleanly.
- Verify secure action works in combat lockdown.
- Test with no pet summoned — must not error.
- Verify SavedVariables persist across `/reload` and logout.

## Post-MVP

- Focus-target support (`/petstrike focus`).
- Per-pet remembered mode.
- Sound/flash cue when stop-attack triggers.
- Integrate with other hunter addons if requests come in.

## Deliverables

- `PetStrike.toc`, `PetStrike.lua`, optional `PetStrike_HUD.lua`.
- README with install + macro examples.
- CurseForge + GitHub release wired via existing `!addon` pipeline.
