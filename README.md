# The Blacksmith Guild

A Mount & Blade II: Bannerlord mod focused on economy pressure, institutional mechanics, faction incentives, and repeatable test scenarios.

Math before hammer.

## Current Sprint

**Sprint 000: Light the Forge** — bootstrap the module and prove the dev/test harness runs inside a campaign.

## First Test Goal

Load the module, enter campaign, and run a controlled economy test scenario (`RichPlayerEconomyTest`).

## What Sprint 000 does

- Appears in the Bannerlord launcher as **The Blacksmith Guild** (`BlacksmithGuild`, v0.0.2)
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
          BlacksmithGuild.dll   <- build output (not committed)
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
```

If Bannerlord is not at the default Steam path, edit `GameFolder` in `src/BlacksmithGuild/BlacksmithGuild.csproj`.

Default path:

```text
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord
```

## Install

Copy the **module folder** (not the repo root) into Bannerlord's `Modules` directory:

```powershell
Copy-Item -Recurse -Force `
  ".\Module\BlacksmithGuild" `
  "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\Modules\BlacksmithGuild"
```

Admin rights may be required for `Program Files (x86)`.

## Acceptance tests

See [docs/test-plan.md](docs/test-plan.md) for full steps. Quick checklist:

1. Launcher shows **The Blacksmith Guild**
2. Campaign loads with forge-lit message and fake advisor output
3. After one daily tick, `RichPlayerEconomyTest` adds 100,000 gold and prints `PASS`

## License

TBD
