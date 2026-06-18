# The Blacksmith Guild

A Mount & Blade II: Bannerlord mod focused on economy pressure, institutional mechanics, faction incentives, and repeatable test scenarios.

Math before hammer.

## Current Sprint

**Sprint 000: Light the Forge** — bootstrap the module and prove the dev/test harness runs inside a campaign.

## First Test Goal

Load the module, enter campaign, and run a controlled economy test scenario (`RichPlayerEconomyTest`).

## What Sprint 000 does

- Appears in the Bannerlord launcher as **The Blacksmith Guild** (`BlacksmithGuild`, v0.0.4)
- Displays `[The Blacksmith Guild] Mod loaded. The forge is lit.` on campaign start
- Registers `BlacksmithGuildCampaignBehavior` for dev/test scenarios
- Runs fake forge advisor ranking (regression smoke test)
- Runs `RichPlayerEconomyTest` on first daily tick (+100,000 gold with before/after logging)
- **Dev hotkeys** on campaign map (see below)
- Writes log lines to `BlacksmithGuild_Phase1.log` near the Bannerlord base path

## Dev hotkeys (campaign map)

PowerShell cannot advance in-game time — use these keys after loading a campaign:

| Hotkey | Action |
|--------|--------|
| Ctrl+Alt+D | Fire one daily tick instantly (`AdvanceOneDay`) |
| Ctrl+Alt+F | Toggle unstoppable fast-forward on/off |
| Ctrl+Alt+L | List registered dev commands in log/messages |

## What it does not do yet

- Read real smithing recipes
- Manual/key dev command triggers
- UI automation or Harmony patches
- Full economy model or faction systems

## Folder layout

```text
BlacksmithGuild/
  LaunchForge.cmd           <- double-click: build + install + open launcher
  CollectDiagnostics.cmd    <- double-click: collect crash/log diagnostic bundle
  forge.ps1                 <- one-click build + install (+ optional launcher/log)
  docs/
    sprint-000-bootstrap.md
    sprint-000a-results.md
    test-plan.md
  scripts/
    install-mod.ps1
    collect-diagnostics.ps1
    forge-status.ps1
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
      ForgeStatus.cs
      ForgeAdvisorSmokeTest.cs
      ForgeAdvisor.cs
      ForgeCandidate.cs
      ForgeDoctrine.cs
      MaterialReservePolicy.cs
      Behaviors/
        BlacksmithGuildCampaignBehavior.cs
      DevTools/
        DevToolsConfig.cs
        GameDataPreflight.cs
        DevCommandRunner.cs
        DebugLogger.cs
        DevCommandRegistry.cs
        TestScenarioRunner.cs
        EconomyTestScenarios.cs
        TimeDevTools.cs
```

## Prerequisites

- Mount & Blade II: Bannerlord installed (default Steam path below)
- .NET SDK (for `dotnet build`)

## Normal startup behavior

The Blacksmith Guild is a normal Bannerlord module.

Once it is installed under `Modules/BlacksmithGuild` and checked in the Bannerlord launcher, Bannerlord loads it automatically when the game starts.

There is no separate "start mod" command.

Expected flow:

1. Double-click `LaunchForge.cmd` or run `.\forge.ps1 -Launch`.
2. In the Bannerlord launcher, confirm **The Blacksmith Guild** is checked.
3. Click **Play**.
4. Load a throwaway campaign save or start a campaign.
5. Confirm the log contains:

```text
[The Blacksmith Guild] Mod loaded. The forge is lit.
```

The dev hotkeys only matter after the mod has loaded on the campaign map.

## One-click dev workflow

From repo root:

```powershell
.\forge.ps1 -Launch    # build, install, open launcher
.\forge.ps1 -Check     # build, install, scan log for [TBG TEST] PASS
.\forge.ps1 -CollectDiagnostics  # collect crash/log bundle after a failure
```

Or double-click `LaunchForge.cmd` to build, install, and open the launcher.

`.\forge.ps1 -Check` prints per-step and per-test statuses (PASS / FAIL / PENDING / BLOCKED).

Status and log files (dev/test output goes to file, not in-game OK dialogs):

```text
Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Status.json
Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Forge.log
Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Phase1.log
```

Engine ASSERT dialogs (Abort/Retry/Ignore) are not controlled by this mod. After a crash, run diagnostics instead of clicking through dialogs.

## Crash and data-load diagnostics

If Bannerlord crashes or shows missing-list/object errors, do not paste screenshots as the main evidence.

Run:

```powershell
.\forge.ps1 -CollectDiagnostics
```

or double-click `CollectDiagnostics.cmd`.

Then share:

- `diagnostic-summary.txt`
- the tail of `BlacksmithGuild_Phase1.log`
- the generated diagnostic zip if needed

Output is written to:

```text
Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Diagnostics\<timestamp>\
```

Known patterns the collector scans for:

- missing beard tag / `has missing beard tag`
- Craftingpieces, Perks, Traits, BuildingTypes, Policies
- BasicCharacterObject / Assertion Failed
- Module mismatch

If the game ASSERTs before campaign loads (for example `lord_1_48_3 has missing beard tag!`), in-game preflight will not run — use the collector instead.

Sprint 000A must be tested on a **new disposable campaign**. Old saves or module mismatches are not valid certification evidence. Dev hotkeys may be blocked if preflight detects broken data state.

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
