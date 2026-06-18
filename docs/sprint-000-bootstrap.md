# Sprint 000: Light the Forge

## Goal

Prove the Bannerlord module loads, shows a visible confirmation, runs the existing fake forge advisor smoke test, and executes one controlled dev scenario (`RichPlayerEconomyTest`).

## Scope delivered

- `BlacksmithGuildCampaignBehavior` registered on campaign start
- Forge-lit load message: `[The Blacksmith Guild] Mod loaded. The forge is lit.`
- `DevTools/` harness: `DebugLogger`, `DevCommandRegistry`, `TestScenarioRunner`, `EconomyTestScenarios`
- `RichPlayerEconomyTest` adds 100,000 gold on first daily tick and logs before/after
- `ForgeAdvisorSmokeTest` preserved as regression smoke test
- Module version bumped to `v0.0.2`

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
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release

Copy-Item -Recurse -Force `
  ".\Module\BlacksmithGuild" `
  "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\Modules\BlacksmithGuild"
```

See [test-plan.md](test-plan.md) for acceptance steps.
