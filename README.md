# PetStrike

A lightweight hunter pet utility for **WoW TBC Classic 2.5.6**. One command — `/petstrike` — sends your pet to attack your **mouseover** target if it's a valid hostile, and falls back to your **current target** otherwise. No more accidental pet-attacks on nothing, no more fumbling with target-swap macros.

Requested via Discord by **sclapernia (airbmac2113)**.

## Features (planned MVP)

- Mouseover-first pet attack with clean fallback to current target.
- Optional auto-Growl on the chosen target.
- Optional auto-return + follow when no valid target exists.
- Small pet-status HUD (HP%, happiness, mode).
- Bindable stop-attack panic button.

Current release (`v0.1.0`) is scaffold-only — loads in-game, prints hello on `/petstrike`. Real logic ships in follow-up feature PRs.

## Install

1. Download the latest release from [GitHub Releases](https://github.com/lemillermicrosoft/PetStrike/releases) or CurseForge (once wired).
2. Extract into `World of Warcraft\_anniversary_\Interface\AddOns\PetStrike\`.
3. `/reload` in game.

## Macro example (once MVP ships)

```
#showtooltip
/petstrike
```

Bind that macro to a key and forget about it.

## Repo

<https://github.com/lemillermicrosoft/PetStrike>
