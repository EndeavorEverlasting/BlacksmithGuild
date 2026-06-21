# TBG Evidence Snapshot

Generated (UTC): 2026-06-21T00:27:42.4855515Z
Game root: C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord
Copied files: 6
Missing files: BlacksmithGuild_CommandSurface.json, BlacksmithGuild_GuildLoopReport.json, BlacksmithGuild_SmithingRestPlan.json

## Session

| Field | Value |
|-------|-------|
| Phase | MapPaused |
| Map ready | True |
| Last command | RunGuildLoopNow (Success) |

## Commands (from CommandSurface)

_CommandSurface.json missing. Press F8 on map or run ListScenarios via inbox._

## Market action plan

- Enter Danustica: buy Felt @ 309 (stock 5)
- Ride to Husn Fulq (50.9u): sell @ 1133 (+824)
- Sell Hardwood x5 @ Onira 86 (+77)

## Forge

| Field | Value |
|-------|-------|
| Source | Real / real |
| Fallback | False |
| Top craft | Javelin |

## Material gap

- Charcoal: need 2, have 0

## Smithing crew (top actions)

- [1]  | RefineCharcoal | hardwood→charcoal x2
- [2]  | CraftRanked | Javelin

## Guild action plan

- : refine hardwoodâ†’charcoal x2 at smithy (stamina 150/150; hardwood 5)
- Charcoal: need more â†’  refine 2 hardwoodâ†’charcoal (hardwood 5)
- Enter smithy: craft Javelin (net +29500)
- Sell Javelin at next town (~29500) or keep for orders â€” advisory only

## Stage C safe action

- executed: False; blockedReason: hardwood shortage (have 0, need 1); charcoal 0->0

## Stage D rest plan

| Field | Value |
|-------|-------|
| Exposed in CommandSurface | False |
| Recommendation | missing (run RunSmithingRestPlanNow) |
| Reason | n/a |

## Re-export

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
.\ExportTbgEvidence.cmd
```

