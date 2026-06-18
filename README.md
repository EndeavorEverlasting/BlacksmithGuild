# The Blacksmith Guild

A Mount & Blade II: Bannerlord mod focused on economy pressure, institutional mechanics, faction incentives, and repeatable test scenarios.

Math before hammer.

## Sprint sequencing

Build/install loop first. Certification evidence second. Dev-tool safety third. Skill points fourth. Recommendations fifth (stub shipped; real recipes gated).

| Order | Sprint | Purpose | Status |
|-------|--------|---------|--------|
| 1 | **000A** | Certify in-game load / gold / hotkey chain | **Certified** |
| 2 | **000B** | Fluid Steam dev loop | **Complete** |
| 3 | **001 / 001B** | Dev command harness + focus-aware cert | **Certified** |
| 3u | **001U / Fix / Debug** | In-game hotkey feedback + trace | **Live certified** (2026-06-18) |
| 4 | **002** | Progression harness + F7 status | **Live certified** (2026-06-18) |
| 5 | **003 / 003B** | Treasury Delta Watch | **003B shipped** — F10 retest pending |
| 6 | **003C** | Quick Forge Start (dev save + auto sandbox character) | **Shipped** |
| 7 | **004A** | Report formatting / readable log surfaces | **Shipped** |
| 8 | **004B** | Stub recommendation model (`RankForgeCandidates`) | **Shipped** — live cert pending |
| 9 | **005A** | Candidate source boundary + real scaffold + stub fallback | **Shipped** |
| 10 | **005B** | Doctrine dev commands | **Shipped** |

## Current Dev Status

| Item | Status |
|------|--------|
| Module version | **v0.0.7** |
| Sprint 004A report formatting | **Shipped** — structured F7 / Treasury / cert blocks |
| Sprint 004B stub recommendations | **Shipped** — live cert pending — [docs/sprint-004-live-results.md](docs/sprint-004-live-results.md) |
| Sprint 005A source boundary | **Shipped** — `IForgeCandidateSource`, real scaffold, stub fallback |
| Sprint 005B doctrine commands | **Shipped** — `SetForgeDoctrine*` via file inbox |
| Sprint 001U hotkeys (F7–F11) | **Live certified** (2026-06-18) — [docs/sprint-001u-live-results.md](docs/sprint-001u-live-results.md) |
| Combat Log | Press **Enter** on campaign map to scroll F7–F11 messages |
| Sprint 002 progression | **Live certified** (2026-06-18) — [docs/sprint-002-live-results.md](docs/sprint-002-live-results.md) |
| Sprint 003 Treasury Watch | **003B shipped** — [docs/sprint-003-live-results.md](docs/sprint-003-live-results.md); use **F10** for delta testing |
| Dev loop | `Forge.cmd` (build only) or **`ForgeAndLaunch.cmd`** (build + launcher on clean PASS) |
| Quick start | Load **`BlacksmithGuild_DevStart.sav`** — see [docs/dev-disposable-save.md](docs/dev-disposable-save.md) |

## Current focus

**Live cert Sprint 004B** — `.\forge.ps1 -Command RankForgeCandidates -Wait` → F7 → update [docs/sprint-004-live-results.md](docs/sprint-004-live-results.md).

**Live cert 003B retest** — F10 fast-forward 3–5 days, F7, `TreasurySnapshotNow`, inspect JSON.

**Daily dev** — load **`BlacksmithGuild_DevStart.sav`** (~30s to map). See [docs/dev-disposable-save.md](docs/dev-disposable-save.md).

**Sprint 005C+** — real Bannerlord recipe reads (gated on 004B + 003B live cert PASS).

> **Surfaces:** [docs/in-game-surfaces.md](docs/in-game-surfaces.md) — lower-left message feed (F7–F11), `TBG READY` gate, Windows toast (forge install only), file logs. **Not** the cheat console for shortcuts.

## Two environments: IDE vs game

| Where | Shortcut | Purpose |
|-------|----------|---------|
| **Cursor / VS Code** (repo open, editor focused) | `Ctrl+Shift+B` | **Build + Install** — runs `dotnet build -c Release` via [`.vscode/tasks.json`](.vscode/tasks.json); auto-copies to `Modules/BlacksmithGuild` |
| **Terminal** (repo root) | same as build command below | Equivalent to `Ctrl+Shift+B` if you do not use the IDE |
| **Bannerlord** (campaign map, mod ON) | `F7`–`F11` | Dev commands (F7 = status summary) |
| **Bannerlord** (campaign map, mod ON) | `Ctrl+Alt+S` / `X` / `C` / `L` / `D` / `F` | Progression + legacy dev commands |

Rule: **build in the editor or terminal; test in the game.**

## Dev commands (in-game — campaign map only)

Dev commands are invoked through a **command bus** (`DevCommandBus`). Hotkeys and file inbox are input adapters — not the architecture itself.

### Primary hotkeys

| Hotkey | Command | Action |
|--------|---------|--------|
| F7 | `ShowForgeStatus` | Read-only status verdict (cert, session, last command) |
| F8 | `ListScenarios` | List registered dev commands in log |
| F9 | `AdvanceOneDay` | Fire one daily tick instantly |
| F10 | `ToggleFastForward` | Toggle unstoppable fast-forward on/off |
| F11 | `RichPlayerEconomyTest` | Run gold mutation test (disposable campaign only) |
| Ctrl+Alt+S | `RichSmithingProgressionTest` | Smithing XP/focus/endurance test |
| Ctrl+Alt+X | `AddSmithingXp` | Add smithing XP only |
| Ctrl+Alt+C | `AddSmithingFocus` | Add smithing focus only |

Press **Enter** on the campaign map to scroll the notice log after F7/F8. Wait for **`TBG READY: campaign map ready. Press F8 for commands.`** before certifying F9–F11. **Close open campaign panels** (Training Field, settlement menus) if F-keys appear silent — or use **Ctrl+Alt+7–1** fallbacks. See [docs/in-game-surfaces.md](docs/in-game-surfaces.md).

**F7/F8** are diagnostic/help keys. **F9/F10/F11** are risky dev keys and may be blocked when a map menu is open (`TBG … BLOCKED: map menu open — close panel first.`).

If there is no visible response, check `BlacksmithGuild_Phase1.log` for `[TBG HOTKEY TRACE]` and `[TBG COMMAND TRACE]` lines.

Risky commands (F9–F11, Ctrl+Alt mutations) are also blocked until the campaign map is stable (`MapState`, no active mission).

Gold test is **manual F11 only** — auto-run on DailyTick is disabled by default.

### Legacy hotkeys (fallback)

| Hotkey | Command |
|--------|---------|
| Ctrl+Alt+L | `ListScenarios` |
| Ctrl+Alt+D | `AdvanceOneDay` |
| Ctrl+Alt+F | `ToggleFastForward` |

**Menu fallback (when F-keys swallowed):** Ctrl+Alt+7 (status), Ctrl+Alt+8 (commands), Ctrl+Alt+9 (daily tick), Ctrl+Alt+0 (fast-forward), Ctrl+Alt+1 (gold test).

Each hotkey shows visible in-game feedback in the **message feed** (lower-left log) via `InGameNotice` — request/result/block lines per key. File inbox commands use explicit result lines (e.g. `TBG SUCCESS: Gold test PASS, +100000.`) or file-only detail for non-user-facing commands.

### File-based command inbox (primary certification path)

While a campaign is loaded, the mod polls the inbox every **0.5s** via `OnApplicationTick` — **works when paused or alt-tabbed** (focus not required):

```text
<Bannerlord install>\BlacksmithGuild_CommandInbox.json
```

```powershell
.\forge.ps1 -Certify -Wait              # Sprint 001 (6 checks); alt-tab OK
.\forge.ps1 -CertifyProgression -Wait   # Sprint 002 (4 checks); alt-tab OK
.\forge.ps1 -Command ShowForgeStatus -Wait
.\forge.ps1 -Command RankForgeCandidates -Wait
.\forge.ps1 -Command TreasurySnapshotNow -Wait
.\forge.ps1 -Command SetForgeCandidateSourceReal -Wait
.\forge.ps1 -Command SetForgeDoctrineRareMetalConservation -Wait
.\forge.ps1 -Check -SkipInstall         # read status only; game may stay open
```

Hotkeys (F7–F11, Ctrl+Alt) require game focus on the campaign map.

### Live status JSON

After each command, the mod writes:

```text
<Bannerlord install>\BlacksmithGuild_Status.json
```

Includes `certification` (Sprint 001) and `certification002` (Sprint 002) blocks with explicit `overall` values.

`forge.ps1 -Check` reads status JSON first, then confirms log details.

## What it does not do yet

- Read real smithing recipes from Bannerlord crafting APIs (005A scaffold returns empty; stub oracle + fallback only)
- Player-facing recommendation UI
- Full treasury explanation engine
- UI automation or Harmony patches *(Sprint 003C adds dev-only Harmony for sandbox character skip)*
- Full economy model or faction systems
- Recommendation engine (Phase 2)

## Folder layout

```text
BlacksmithGuild/
  Forge.cmd                 <- double-click: build + install (daily dev loop)
  ForgeAndLaunch.cmd        <- build + install + open launcher on clean PASS only
  ForgeWatch.cmd            <- double-click: auto rebuild on source changes
  LaunchForge.cmd           <- first install / explicit: build + install + open launcher
  CollectDiagnostics.cmd    <- double-click: collect crash/log diagnostic bundle
  BackupSaves.cmd           <- double-click: incremental save backup
  forge.ps1                 <- install, backup, diagnostics, log scan, -Watch
  .vscode/
    tasks.json              <- Cursor/VS Code only: Ctrl+Shift+B = Build + Install (not in Bannerlord)
  docs/
    dev-disposable-save.md
    in-game-surfaces.md
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
3. Click **Play**, **Load** `BlacksmithGuild_DevStart.sav` (preferred) or a throwaway campaign
4. Confirm the log contains (when mod is checked):

```text
[The Blacksmith Guild] Mod loaded. The forge is lit.
```

### After code changes

```powershell
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
```

Release builds auto-install to `Modules/BlacksmithGuild` and write `BlacksmithGuild_PendingReload.json`. **Restart Bannerlord** to load a new DLL — there is no hot reload. While Bannerlord is running, the loaded Client DLL is **locked**; install may be **blocked** until you close the game.

**Double-click:** `Forge.cmd` (build + install, window stays open). **Close Bannerlord first** for a reliable install. **`ForgeAndLaunch.cmd`** — same build/install, then opens the Bannerlord launcher only on clean PASS (not if install blocked or game running). **First install / explicit launcher:** `LaunchForge.cmd`. **Auto rebuild:** `ForgeWatch.cmd` or `.\forge.ps1 -Watch` (can build while the game is open; install may block until you close Bannerlord).

## One-step clean launch

Use:

```text
ForgeAndLaunch.cmd
```

This builds, installs, verifies, and opens the Bannerlord launcher only if Forge finishes with a clean PASS (`overall: PASS` and install step PASS).

If install is BLOCKED because Bannerlord is running, it will not launch. Close Bannerlord and run `Forge.cmd` again.

**In Cursor / VS Code:** `Ctrl+Shift+B` (Build + Install task). Optional background task: **Forge Watch**. **Not in Bannerlord.**

If Bannerlord is running when a build completes, you may get a blocked-install notice (`TBG RELOAD: … close Bannerlord …`) or, after a successful install with the game still open, `reload=pending` on **F7**.

## Skill harness runway (Sprint 002 — not implemented)

Next gameplay-dev target after 000A evidence and Sprint 001 dev-tool safety:

**Sprint 002 — Stoke the Apprentice** — smithing/progression dev harness.

| Item | Purpose |
|------|---------|
| Reserved hotkey | `Ctrl+Alt+S` (not wired today) |
| `RichSmithingProgressionTest` | Main skill/progression scenario |
| Before/after snapshot | Prove actual hero progression change |
| Controlled Smithing XP | First mutation target |
| Focus / attribute support | Later, if compile-safe |
| PASS/FAIL logging | No silent magic |

This patch does **not** implement skill points. It prepares the build/play loop for fast repetition when Sprint 002 lands.

## Forge tooling (install, backup, diagnostics)

From repo root:

```powershell
.\forge.ps1                  # build + install (+ auto save backup)
.\forge.ps1 -Launch          # build, install, open launcher (first install / explicit)
.\forge.ps1 -Watch           # auto rebuild on .cs / SubModule.xml changes
.\forge.ps1 -Check           # build, install, scan status JSON + log
.\forge.ps1 -Command RichPlayerEconomyTest  # write command to in-game inbox
.\forge.ps1 -CollectDiagnostics  # collect crash/log bundle after a failure
.\forge.ps1 -VerifySaves         # read-only check: live saves vs backups
.\forge.ps1 -BackupSaves         # incremental save backup only
.\forge.ps1 -SkipSaveBackup      # opt out of automatic backup on any run
```

Double-click **`Forge.cmd`** for the daily build+install loop. **`ForgeAndLaunch.cmd`** when you want build+install and the launcher opened on clean PASS. **`LaunchForge.cmd`** when you always want the launcher after build. **`ForgeWatch.cmd`** for watch mode.

Every `forge.ps1` run **auto-backs up changed saves** unless `-SkipSaveBackup` is set. Watch mode backs up on the first rebuild only. For daily play you do not need forge — only after code changes or when running diagnostics/backups.

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

See [docs/test-plan.md](docs/test-plan.md) for full steps. Quick checklist (Sprint 002):

1. Launcher shows **The Blacksmith Guild** (v0.0.6)
2. Campaign loads with forge-lit message and fake advisor output
3. **F7** shows status summary in notice log (press **Enter** to scroll)
4. **F8** lists nine registered commands
5. **F9** / **F10** advance day and toggle fast-forward
6. **F11** runs gold test; **Ctrl+Alt+S** runs progression test on disposable campaign
7. `.\forge.ps1 -CertifyProgression -Wait` → `certification002.overall: PASS`

## License

TBD
