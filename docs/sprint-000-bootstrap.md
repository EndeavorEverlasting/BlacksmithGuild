# Sprint 000: Light the Forge

## Goal

Prove the Bannerlord module loads, shows a visible confirmation, runs the existing fake forge advisor smoke test, and executes one controlled dev scenario (`RichPlayerEconomyTest`).

## Scope delivered

- `BlacksmithGuildCampaignBehavior` registered on campaign start
- Forge-lit load message: `[The Blacksmith Guild] Mod loaded. The forge is lit.`
- `DevTools/` harness: `DebugLogger`, `DevCommandRegistry`, `TestScenarioRunner`, `EconomyTestScenarios`
- `RichPlayerEconomyTest` adds 100,000 gold on first daily tick and logs before/after
- `ForgeAdvisorSmokeTest` preserved as regression smoke test
- Dual-bin DLL layout: `Win64_Shipping_Client` + `Win64_Shipping_wEditor` (v0.0.3)
- Module version bumped to `v0.0.3`

## Deferred

- Manual/key triggers via `DevCommandRegistry` (stub registers scenario names only)
- Real smithing data (Phase 1B in `NEXT_STEPS.md`)
- Economy model, factions, UI, Harmony patches

## Module identity (unchanged)

| Field | Value |
|-------|-------|
| Display name | The Blacksmith Guild |
| Module ID | `BlacksmithGuild` |
| DLL | `BlacksmithGuild.dll` |
| Namespace | `BlacksmithGuild` |

## Build and install

```powershell
.\forge.ps1
```

Build output (both required for Bannerlord to load):

```text
Module/BlacksmithGuild/bin/Win64_Shipping_Client/BlacksmithGuild.dll
Module/BlacksmithGuild/bin/Win64_Shipping_wEditor/BlacksmithGuild.dll
```

See [test-plan.md](test-plan.md) for acceptance steps.
