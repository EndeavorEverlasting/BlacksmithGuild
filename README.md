# The Blacksmith Guild

A Mount & Blade II: Bannerlord mod focused on economy pressure, institutional mechanics, faction incentives, and repeatable test scenarios.

Math before hammer.

## Current Sprint

**Sprint 000: Light the Forge** — bootstrap the module and prove the dev/test harness runs inside a campaign.

## First Test Goal

Load the module, enter campaign, and run a controlled economy test scenario (`RichPlayerEconomyTest`).

## What Sprint 000 does

- Appears in the Bannerlord launcher as **The Blacksmith Guild** (`BlacksmithGuild`, v0.0.3)
- Displays `[The Blacksmith Guild] Mod loaded. The forge is lit.` on campaign start
- Registers `BlacksmithGuildCampaignBehavior` for dev/test scenarios
- Runs fake forge advisor ranking (regression smoke test)
- Runs `RichPlayerEconomyTest` on first daily tick (+100,000 gold with before/after logging)
- Writes log lines to `BlacksmithGuild_Phase1.log` near the Bannerlord base path

## What it does not do yet

- Read real smithing recipes
- Manual/key dev command triggers
- UI automation or Harmony patches
- Full economy model or faction systems

## Folder layout

```text
BlacksmithGuild/
  forge.ps1                 <- one-click build + install (+ optional launcher/log)
  docs/
    sprint-000-bootstrap.md
    sprint-000a-results.md
    test-plan.md
  scripts/
    install-mod.ps1
    verify-sprint-000a.ps1
  Module/
    BlacksmithGuild/
      SubModule.xml
      bin/
        Win64_Shipping_Client/
          BlacksmithGuild.dll   <- primary build output (not committed)
        Win64_Shipping_wEditor/
          BlacksmithGuild.dll   <- post-build copy, same DLL (not committed)
  src/
    BlacksmithGuild/
      BlacksmithGuild.csproj
      SubModule.cs
      GuildLog.cs
      ForgeAdvisorSmokeTest.cs
      ForgeAdvisor.cs
      ForgeCandidate.cs
      ForgeDoctrine.cs
      MaterialReservePolicy.cs
      Behaviors/
        BlacksmithGuildCampaignBehavior.cs
      DevTools/
        DebugLogger.cs
        DevCommandRegistry.cs
        TestScenarioRunner.cs
        EconomyTestScenarios.cs
```

## Prerequisites

- Mount & Blade II: Bannerlord installed (default Steam path below)
- .NET SDK (for `dotnet build`)

## One-click dev workflow

From repo root:

```powershell
.\forge.ps1 -Launch    # build, install, open launcher
.\forge.ps1 -Check     # build, install, scan log for [TBG TEST] PASS
```

**Enable "The Blacksmith Guild" in the launcher** before loading a save.

See [docs/sprint-000a-results.md](docs/sprint-000a-results.md) for acceptance checklist, gaps, and log file locations.

## Build (manual)

```powershell
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
```

Output lands at:

```text
Module/BlacksmithGuild/bin/Win64_Shipping_Client/BlacksmithGuild.dll
Module/BlacksmithGuild/bin/Win64_Shipping_wEditor/BlacksmithGuild.dll   <- copied on build
```

Prefer `.\forge.ps1` over raw `dotnet build` — it ensures both folders are populated before install.

If Bannerlord is not at the default Steam path, edit `GameFolder` in `src/BlacksmithGuild/BlacksmithGuild.csproj`.

Default path:

```text
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord
```

## Install

Use the one-click workflow (recommended):

```powershell
.\forge.ps1
```

Or copy the **module folder** (not the repo root) into Bannerlord's `Modules` directory. The full `bin/` tree must include **both** `Win64_Shipping_Client` and `Win64_Shipping_wEditor`:

```powershell
Copy-Item -Recurse -Force `
  ".\Module\BlacksmithGuild" `
  "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\Modules\BlacksmithGuild"
```

Admin rights may be required for `Program Files (x86)`.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Cannot find ... Win64_Shipping_wEditor\BlacksmithGuild.dll` | Run `.\forge.ps1` — build copies DLL to both bin folders (fixed in v0.0.3) |
| Mod not in launcher | Confirm `Modules/BlacksmithGuild/SubModule.xml` exists; rebuild and recopy |
| No in-game messages | Enable **The Blacksmith Guild** checkbox in the launcher before loading a save |
| Build fails (missing TaleWorlds DLLs) | Set `GameFolder` in `BlacksmithGuild.csproj` to your Steam install path |

## Acceptance tests

See [docs/test-plan.md](docs/test-plan.md) for full steps. Quick checklist:

1. Launcher shows **The Blacksmith Guild**
2. Campaign loads with forge-lit message and fake advisor output
3. After one daily tick, `RichPlayerEconomyTest` adds 100,000 gold and prints `PASS`

## License

TBD
