# SoloRaidTargetIcons (community-extended)

Vanilla WoW 1.12.1 / Turtle WoW addon. Lets you place raid target icons
through the default Blizzard UI while playing solo.

This is a fork of [refaim/SoloRaidTargetIcons](https://github.com/refaim/SoloRaidTargetIcons)
(MIT). The original does one thing well: fake a party locally so the stock
raid-icon dropdown appears while soloing, then mark the target client-side
via SuperWoW. This build keeps that exactly, and adds the pieces below.

## What you actually gain over the original addon

**1. You're no longer locked to SuperWoW.**
The original addon *only* works if SuperWoW is installed -- no SuperWoW, no
solo marking, full stop. This build also recognizes the
[brues-code nampower fork (v4.6.1+)](https://github.com/brues-code/nampower)
as a second, independent backend, since that fork ships its own client-local
raid marker table (`SetLocalRaidTargetIndex` / `GetRaidTargets`). If you
already run that nampower build for its spell-queuing benefits, solo marking
now works out of the box -- one less mod you need to install just for this.
If you happen to have both, SuperWoW is used first and nampower is the
fallback, so nothing changes for existing SuperWoW users.

**2. It tells you when marking *won't* work, instead of silently failing.**
The original addon has no self-diagnosis: if SuperWoW isn't loaded, or isn't
loaded yet when the addon initializes, marking just quietly doesn't work and
you're left guessing why. Run `/srti` and you get a plain readout of exactly
which backend (if any) is active, plus a specific warning if nampower's
`NP_EnableLocalSetRaidTarget` cvar has been switched off -- a setting that
would otherwise silently break local marking for that backend.

**3. Solo mark-cycling, if you also run UnitXP_SP3.**
This is new functionality the original didn't have at all: `/srti next` and
`/srti prev` tab your target through your own solo raid marks (via
UnitXP_SP3's `nextMarkedEnemyInCycle`). In a group this kind of cycling is
built into raid-frame addons; solo, there was previously no way to do it --
you had to alt-tab or manually re-target each marked mob.

**4. Slightly more robust SuperWoW detection.**
The original checked `SetAutoloot ~= nil`, a function name generic enough
that another addon could coincidentally define it and produce a false
positive. This build checks `SUPERWOW_VERSION`, the global SuperWoW
specifically documents for addon detection.

**5. Everything else is checked, not guessed.**
ClassicAPI and VanillaHelpers are also detected and reported by `/srti`,
so if you're troubleshooting a "why isn't this working" question, you can
see your whole relevant addon/DLL stack at a glance instead of checking
each one manually. (Neither currently adds functionality here -- see the
table below for why.)

## Side-by-side

| | Original addon | This build |
|---|---|---|
| Works with SuperWoW | Yes | Yes |
| Works with only the brues-code nampower fork (no SuperWoW) | No | Yes |
| Tells you why marking isn't working | No | Yes, via `/srti` |
| Cycle-target through your own solo marks | No | Yes, via `/srti next`/`prev` (needs UnitXP_SP3) |
| SuperWoW detection method | `SetAutoloot ~= nil` | `SUPERWOW_VERSION ~= nil` |

## Requirements

You need **one** of these two as a local-marking backend -- without either,
solo marking is impossible and `/srti` will say so:

- [SuperWoW](https://github.com/balakethelock/SuperWoW/wiki) -- same as
  upstream. `SetRaidTarget(unit, index, true)` writes a client-only mark.
- [nampower, brues-code fork (v4.6.1+)](https://github.com/brues-code/nampower)
  -- **not** namreeb's original (see table below). Uses its own local marker
  table and the `NP_EnableLocalSetRaidTarget` cvar (default on).

## Optional companion mods

| Mod | What this addon does with it |
|---|---|
| [UnitXP_SP3](https://codeberg.org/konaka/UnitXP_SP3/wiki) | Powers `/srti next` / `/srti prev` via `UnitXP("target", "nextMarkedEnemyInCycle")`. |
| [ClassicAPI](https://github.com/brues-code/ClassicAPI) | Detected and reported by `/srti` only -- nothing it backports is raid-icon related. |
| [VanillaHelpers](https://github.com/isfir/VanillaHelpers) | Detected and reported by `/srti` only -- it's a textures/models/file-IO library, no overlap with this addon's job. |
| [nampower, namreeb's original](https://github.com/namreeb/nampower) | **Not integrated, and can't be.** Pure client-binary latency patch, no Lua API at all. A different project from the brues-code fork above -- same name, unrelated scope. |

## Commands

- `/srti` -- status: which backend is active, which optional mods are
  detected, and any warnings.
- `/srti next` / `/srti prev` -- cycle your target between your own marked
  enemies (requires UnitXP_SP3).
