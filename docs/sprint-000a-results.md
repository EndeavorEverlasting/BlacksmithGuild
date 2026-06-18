# Sprint 000A Results — Prove the Forge

**Module:** `BlacksmithGuild` v0.0.3  
**Sprint goal:** Bannerlord loads the mod, shows confirmation, runs smoke + gold test.

## One-click commands

From repo root:

```powershell
.\forge.ps1 -Launch    # build, install, open launcher
.\forge.ps1 -Check     # build, install, scan log for PASS
```

Or:

```powershell
.\scripts\install-mod.ps1 -Launch -CheckLog
```

**Critical:** enable **The Blacksmith Guild** in the launcher mod list before loading a save.

---

## Acceptance checklist

| Check | Expected | Status |
|-------|----------|--------|
| Build | `dotnet build` succeeds | Agent PASS |
| Install | `Modules/BlacksmithGuild` has xml + **both** Client and wEditor DLLs | Agent PASS |
| Launcher | Mod appears; checkbox enabled | **User** |
| Campaign start | Forge-lit + advisor messages | **User** |
| Daily tick | `RichPlayerEconomyTest` runs once | **User** |
| Gold delta | +100,000 exactly | **User** |
| Log file | `BlacksmithGuild_Phase1.log` with PASS | **User** |
| Save reload | Test save loads cleanly | **User** |

Report line after in-game session:

```text
First PASS or failure: _______________________________________________
```

---

## Known gaps

| Gap | Impact | Next sprint |
|-----|--------|-------------|
| No manual test trigger | Must wait for daily tick to re-run gold test | Sprint 001 |
| `DevCommandRegistry` is stub only | Cannot list/run scenarios on demand | Sprint 001 |
| No `DevToolsEnabled` gate | Dev behavior always active when mod loaded | Sprint 001 |
| In-game log prefix | `[TBG TEST]` lines show as `BlacksmithGuild: [TBG TEST]` in UI | Cosmetic; file log is raw |
| Fake advisor only | No real smithing data | Phase 1B (`NEXT_STEPS.md`) |
| Log path discovery | `BasePath.Name` varies by install | Use `forge.ps1 -Check` to find log |
| wEditor bin folder | Fixed v0.0.3 — both shipping folders required | Documented in README troubleshooting |

---

## Risks

| Risk | Mitigation |
|------|------------|
| Mod checkbox not enabled | README + install script reminder; most common miss |
| Wrong Bannerlord install path | `GameFolder` in `BlacksmithGuild.csproj` must match Steam path |
| wEditor DLL missing (pre-v0.0.3) | Run `.\forge.ps1`; verify both `bin/Win64_Shipping_*` folders have DLL |
| DLL/game version mismatch | Rebuild after game updates; references are local TaleWorlds DLLs |
| Silent log write failure | `GuildLog` swallows file errors; check in-game messages if log missing |
| Old save without mod history | Fine — mod runs on load if enabled; advance 1 day for gold test |
| `Program Files` copy needs admin | Run PowerShell as Administrator if copy fails |

---

## Targets (files to analyze after a session)

| File | Purpose |
|------|---------|
| `BlacksmithGuild_Phase1.log` | Primary acceptance evidence (`[TBG TEST] PASS`, gold before/after) |
| `Documents\Mount and Blade II Bannerlord\Configs\LauncherData.xml` | Confirms mod enabled in launcher |
| `Modules\BlacksmithGuild\SubModule.xml` | Installed version and dependencies |
| `Modules\BlacksmithGuild\bin\Win64_Shipping_Client\BlacksmithGuild.dll` | Installed Client build |
| `Modules\BlacksmithGuild\bin\Win64_Shipping_wEditor\BlacksmithGuild.dll` | Installed wEditor build (required for some launch paths) |
| Bannerlord `rgl_log_*.txt` (if crash) | Load failures / DLL mismatch |

Typical log locations:

```text
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Phase1.log
%USERPROFILE%\Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Phase1.log
```

---

## Sprint 001 gate

Blocked until all user checklist rows are **PASS**.

Sprint 001 scope: **Manual Test Control** — hotkey trigger, optional auto daily-tick, scenario list. No economy features yet.
