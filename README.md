# The Blacksmith Guild

A Mount & Blade II: Bannerlord mod focused on economy pressure, institutional mechanics, faction incentives, and repeatable test scenarios.

Math before hammer.

## Sprint sequencing

Build/install loop first. Certification evidence second. Dev-tool safety third. Skill points fourth. Recommendations later.

| Order | Sprint | Purpose | Status |
|-------|--------|---------|--------|
| 1 | **000A** | Certify in-game load / gold / hotkey chain | In progress |
| 2 | **000B** | Fluid Steam dev loop | **Complete** |
| 3 | **001** | Dev tool safety and repeatability | Next |
| 4 | **002** | Skill-point / progression harness | Scaffolded |
| 5 | **003+** | Recommendation system | Later |

## Current focus

**Sprint 000A** — certify Tests 1–3 on a disposable campaign (`Ctrl+Alt+D` / `F` / `L`).

> **Breadcrumb:** `Ctrl+Alt+S` is reserved for the future smithing/progression dev command (Sprint 002). Only `Ctrl+Alt+D` / `F` / `L` are wired today.

## Dev hotkeys (campaign map)

PowerShell cannot advance in-game time — use these keys after loading a campaign:

| Hotkey | Wired | Action |
|--------|-------|--------|
| Ctrl+Alt+D | Yes | Fire one daily tick instantly (`AdvanceOneDay`) |
| Ctrl+Alt+F | Yes | Toggle unstoppable fast-forward on/off |
| Ctrl+Alt+L | Yes | List registered dev commands in log/messages |
| Ctrl+Alt+S | **Reserved** | Sprint 002: future smithing/progression dev command |

## What it does not do yet

- Read real smithing recipes
- UI automation or Harmony patches
- Full economy model or faction systems
- Recommendation engine (Phase 2)

## Folder layout

```text
BlacksmithGuild/
  LaunchForge.cmd           <- first install / explicit: build + install + open launcher
  CollectDiagnostics.cmd    <- double-click: collect crash/log diagnostic bundle
  BackupSaves.cmd           <- double-click: incremental save backup
  forge.ps1                 <- install, backup, diagnostics, log scan
  .vscode/
    tasks.json              <- default build task (Ctrl+Shift+B): Release + auto-install
  docs/
    sprint-000-bootstrap.md
    sprint-000a-results.md
    test-plan.md
  scripts/
    install-mod.ps1
    collect-diagnostics.ps1
    backup-saves.ps1
    verify-saves.ps1
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

Once installed under `Modules/BlacksmithGuild`, **Steam → Play** opens the Bannerlord launcher with your saved mod checkboxes (`LauncherData.xml`). Checked mods load automatically — no separate start command. Scripts never force-enable the mod.

### Daily play

1. **Steam → Play**
2. **The Blacksmith Guild** checked for dev / disposable campaigns; **unchecked** for legacy saves
3. Click **Play**, load a campaign
4. Confirm the log contains (when mod is checked):

```text
[The Blacksmith Guild] Mod loaded. The forge is lit.
```

### After code changes

```powershell
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
```

Release builds auto-install to `Modules/BlacksmithGuild`. Then **Steam → Play**.

In Cursor/VS Code: **Ctrl+Shift+B** runs the default **Build + Install** task (`.vscode/tasks.json`).

## Forge tooling (install, backup, diagnostics)

From repo root:

```powershell
.\forge.ps1 -Launch    # build, install, open launcher (first install / explicit)
.\forge.ps1 -Check     # build, install, scan log for [TBG TEST] PASS
.\forge.ps1 -CollectDiagnostics  # collect crash/log bundle after a failure
.\forge.ps1 -VerifySaves         # read-only check: live saves vs backups
.\forge.ps1 -BackupSaves         # incremental save backup only
.\forge.ps1 -SkipSaveBackup      # opt out of automatic backup on any run
```

Every `forge.ps1` run **auto-backs up changed saves** unless `-SkipSaveBackup` is set. For daily play you do not need forge — only after code changes (`dotnet build`) or when running diagnostics/backups.

## Save safety

Your live saves stay in:

```text
Documents\Mount and Blade II Bannerlord\Game Saves\
```

The repo **never deletes or modifies** save files. Incremental backups go to:

```text
Documents\Mount and Blade II Bannerlord\BlacksmithGuild_SaveBackups\
```

| Rule | Why |
|------|-----|
| **Legacy saves → mod OFF** | Confirmed: old saves load when BlacksmithGuild is disabled |
| **Sprint 000A tests → new disposable campaign, mod ON** | Avoid module/data mismatch |
| **Auto-backup on every forge run** | Only copies new/changed `.sav` files (SHA256 manifest) |

Verify backups:

```powershell
.\forge.ps1 -VerifySaves
```

**Manual restore** (if ever needed):

1. Close Bannerlord
2. Copy a timestamped `.sav` from `BlacksmithGuild_SaveBackups\<save name>\` → `Game Saves\`
3. Launch with **The Blacksmith Guild disabled** for legacy campaigns

For first install, double-click `LaunchForge.cmd` (build, install, open launcher). Daily play uses Steam.

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

`dotnet build -c Release` auto-installs to `Modules/BlacksmithGuild` and populates both `bin/` folders. Use `.\forge.ps1` when you also need save backup, log scan, or dependency verify.

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

See [docs/test-plan.md](docs/test-plan.md) for full steps. Quick checklist (Sprint 000A):

1. Launcher shows **The Blacksmith Guild**
2. Campaign loads with forge-lit message and fake advisor output
3. **Ctrl+Alt+D** (or one daily tick) → `RichPlayerEconomyTest` adds 100,000 gold and prints `PASS`
4. **Ctrl+Alt+L** lists four registered commands (`Ctrl+Alt+S` reserved for Sprint 002)

## License

TBD
