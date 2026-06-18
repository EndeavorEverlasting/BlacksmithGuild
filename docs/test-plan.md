# Test Plan

## Sprint sequencing

Build/install loop first. Certification evidence second. Dev-tool safety third. Skill points fourth. Recommendations later.

| Order | Sprint | Purpose | Status |
|-------|--------|---------|--------|
| 1 | **000A** | Certify in-game load / gold / hotkey chain (Tests 1–3) | In progress |
| 2 | **000B** | Fluid Steam dev loop (`dotnet build` auto-install, Steam Play) | Complete |
| 3 | **001** | Dev command harness (visible, repeatable, safe) | In progress |
| 4 | **002** | Stoke the Apprentice — skill-point / progression harness | Scaffolded (docs + source; hotkeys not wired) |
| 5 | **003+** | Recommendation system | Later |

> **Breadcrumb:** `Ctrl+Alt+S` is reserved for Sprint 002. Primary dev keys are `F8`–`F11`; `Ctrl+Alt+L/D/F` are legacy fallbacks.

## Two environments: IDE vs game

| Where | Shortcut | Purpose |
|-------|----------|---------|
| **Cursor / VS Code** (repo open) | `Ctrl+Shift+B` | Build + Install (`dotnet build -c Release`; auto-install) |
| **Terminal** (repo root) | `dotnet build ... -c Release` | Same as `Ctrl+Shift+B` without the IDE |
| **Bannerlord** (campaign map) | `F8` / `F9` / `F10` / `F11` | Primary in-game dev commands |
| **Bannerlord** (campaign map) | `Ctrl+Alt+L` / `D` / `F` | Legacy dev command fallbacks |
| **Terminal** (repo root) | `.\forge.ps1 -Command <name>` | File-based command inbox |

Rule: **build in the editor or terminal; test in the game.**

---

## Normal startup behavior (Sprint 000B)

The Blacksmith Guild is a normal Bannerlord module.

Once it is installed under `Modules/BlacksmithGuild`, the Bannerlord launcher (via Steam Play) decides which mods load. Launcher checkboxes are saved in `Documents\Mount and Blade II Bannerlord\Configs\LauncherData.xml`. **Scripts never force-enable the mod** — your launcher selection is authoritative.

There is no separate "start mod" command.

### Daily play (default)

1. **Steam → Play** (launcher opens with your saved mod checkboxes).
2. For dev testing: confirm **The Blacksmith Guild** is checked. For legacy saves: leave it **unchecked**.
3. Click **Play**, then load a throwaway campaign (mod ON) or legacy save (mod OFF).
4. Confirm the log contains (when mod is checked):

```text
[The Blacksmith Guild] Mod loaded. The forge is lit.
```

The dev hotkeys only matter after the mod has loaded on the campaign map.

### After code changes

1. `dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release` (auto-installs to `Modules/BlacksmithGuild`).
   - **In Cursor / VS Code:** `Ctrl+Shift+B` runs the same command (not in Bannerlord).
2. **Steam → Play**.

### When to use forge instead

Use `.\forge.ps1` or `LaunchForge.cmd` for first install, save backup, log scan (`-Check`), or diagnostics (`-CollectDiagnostics`). Use `.\forge.ps1 -Launch` only when you explicitly want build + install + open the launcher.

Do **not** require forge for daily play.

---

## Skill harness runway (Sprint 002 — docs only)

Next gameplay-dev target: **Sprint 002 — Stoke the Apprentice**.

- **Reserved hotkey:** `Ctrl+Alt+S` (not wired; do not test yet)
- **Planned:** capture before/after hero progression snapshot; add controlled Smithing XP; log PASS/FAIL; explicit save-safety
- **Out of scope for Sprint 000B:** skill mutation, focus/attribute adds, recommendations, UI

Entry criteria for Sprint 002: Sprint 000B complete, Sprint 000A Tests 2–3 PASS in log, Sprint 001 dev-tool safety done.

---

## Sprint 001 verification — Dev command harness

Proves commands are visible, repeatable, and safe on a **disposable campaign**.

### Paths

- **Log:** `C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Phase1.log`
- **Status JSON:** `C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Status.json`
- **Command inbox:** `C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_CommandInbox.json`

### Canonical certification (file inbox — focus not required)

Campaign loaded on map (paused OK). From repo — **alt-tab welcome**:

```powershell
.\forge.ps1 -Certify -Wait
```

Or step-by-step:

```powershell
.\forge.ps1 -Command ListScenarios -Wait
.\forge.ps1 -Command AdvanceOneDay -Wait
.\forge.ps1 -Command ToggleFastForward -Wait
.\forge.ps1 -Command ToggleFastForward -Wait
.\forge.ps1 -Command RichPlayerEconomyTest -Wait
```

Verify without closing game:

```powershell
.\forge.ps1 -Check -SkipInstall
```

Expect `certification.overall: PASS` in status JSON.

### Optional hotkey sequence (requires game focus)

```text
F8 → F9 → F10 → F10 → F11
```

### File inbox sequence (optional)

With campaign loaded:

```powershell
.\forge.ps1 -Command ListScenarios
.\forge.ps1 -Command AdvanceOneDay
.\forge.ps1 -Command ToggleFastForward
.\forge.ps1 -Command RichPlayerEconomyTest
```

### Check hierarchy

1. `BlacksmithGuild_Status.json` — `lastCommand`, `goldTest.passed`, readiness flags
2. `BlacksmithGuild_Phase1.log` — confirms details
3. In-game toast — human visibility (`TBG HOTKEY: ... fired`)

Run `.\forge.ps1 -Check` after an in-game session.

**Do not test `Ctrl+Alt+S`** — reserved for Sprint 002.

---

## Sprint 000B verification (build/install loop)

Proves build/install loop only — **not** character mutation.

1. `dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release`
2. Confirm DLLs under `Modules/BlacksmithGuild/bin/Win64_Shipping_Client` and `.../Win64_Shipping_wEditor`
3. **Steam → Play** (mod checked ON)
4. Disposable campaign → confirm forge-lit log line
5. Confirm `BlacksmithGuild_Phase1.log` exists after load

---

## Save safety

Live saves: `Documents\Mount and Blade II Bannerlord\Game Saves\`

Backups: `Documents\Mount and Blade II Bannerlord\BlacksmithGuild_SaveBackups\`

- **Legacy saves:** disable **The Blacksmith Guild** in the launcher before loading (confirmed working).
- **Mod testing:** use a **new disposable campaign** with the mod enabled.
- **Auto-backup:** every `forge.ps1` run backs up only new/changed `.sav` files.
- **Verify:** `.\forge.ps1 -VerifySaves` — statuses `SAFE`, `UNBACKED`, or `CHANGED_SINCE_BACKUP`.
- **Restore:** manual copy from backup folder to `Game Saves\` (never auto-restore).

---

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

Known patterns the collector scans for:

- missing beard tag / `has missing beard tag`
- Craftingpieces, Perks, Traits, BuildingTypes, Policies
- BasicCharacterObject / Assertion Failed
- Module mismatch

Sprint 000A must use a **new disposable campaign**. Dev hotkeys may be blocked if preflight detects broken data state.

### Certification test flow (after diagnostics land)

```text
1. Steam → Play             (launcher respects saved mod checkboxes)
2. New disposable campaign  (mod ON for 000A certification)
3. Legacy save play         (mod OFF — separate session)
4. If crash → CollectDiagnostics.cmd
5. If load → check [TBG PREFLIGHT] lines in BlacksmithGuild_Phase1.log
6. If preflight PASS → Ctrl+Alt+D
7. On failure → bring diagnostic-summary.txt
8. Verify saves anytime → .\forge.ps1 -VerifySaves
```

---

## Test 1: Launcher Detection

**Purpose:** Confirm Bannerlord recognizes `BlacksmithGuild` as a module.

**Steps:**

1. Build and install (first time or after dependency changes):

   ```powershell
   dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
   ```

   Release builds auto-copy to `Bannerlord/Modules/BlacksmithGuild` (both `bin/` folders). Or use `.\forge.ps1` / `LaunchForge.cmd` for full verify + optional launcher.

2. **Steam → Play** (or open the Bannerlord launcher).
3. Find **The Blacksmith Guild** in the mod list and enable it (once — launcher remembers).

**Expected:**

- Mod appears and can be checked.
- No launcher crash or dependency error.

**Fail:**

- Mod missing, launcher crash, or dependency load failure.

**Failure A2 — wEditor DLL missing:**

```text
Cannot find: ...\Modules\BlacksmithGuild\bin\Win64_Shipping_wEditor\BlacksmithGuild.dll
```

- **Cause:** DLL only in `Win64_Shipping_Client` (pre-v0.0.3 build, or manual build without post-build copy).
- **Fix:** Run `.\forge.ps1` from repo root. Verify both paths exist under `Modules/BlacksmithGuild/bin/`.

---

## Test 2: Campaign Load

**Purpose:** Confirm the module does not crash campaign startup and prints load confirmation.

**Steps:**

1. Enable **The Blacksmith Guild** in the launcher.
2. Start a **new disposable** sandbox campaign (do not use an old save for 000A certification).
3. Wait until the campaign map loads.

**Expected in-game messages:**

```text
[The Blacksmith Guild] Mod loaded. The forge is lit.
BlacksmithGuild: campaign detected. Running Phase 1 fake forge advisor.
BlacksmithGuild: Top fake candidate: Long Warblade | Score 11250 | ...
```

After MainHero is available (first daily tick or F9/F11):

```text
[TBG PREFLIGHT] Starting game data preflight.
[TBG PREFLIGHT] Result: Pass
```

**Expected log file:** `BlacksmithGuild_Phase1.log` near the Bannerlord base path.

**Fail:**

- No load message, crash on campaign start, or missing log file.

---

## Test 3: Rich Player Economy Test

**Purpose:** Confirm mod-side scripts can generate a controlled test value via explicit command.

**Steps:**

1. Load a **fresh disposable** campaign with the mod enabled.
2. Wait until campaign map loads and MainHero is available (preflight runs on first ready tick).
3. On the campaign map, press **F11** (or `.\forge.ps1 -Command RichPlayerEconomyTest` with campaign loaded).
4. Observe in-game toast, `BlacksmithGuild_Status.json`, and `BlacksmithGuild_Phase1.log`.
5. Open the clan finance / hero gold UI and note player gold.
6. Save the game and reload to confirm the save is still valid.

**Optional — advance day:** Press **F9** (or `Ctrl+Alt+D` legacy) to fire one daily tick.

**Optional — fast-forward:** Press **F10** twice (or `Ctrl+Alt+F` legacy) to toggle ON/OFF.

**Optional — list commands:** Press **F8** (or `Ctrl+Alt+L` legacy).

**Expected output:**

```text
TBG HOTKEY: RichPlayerEconomyTest fired
[TBG TEST] MUTATION COMMAND: RichPlayerEconomyTest
[TBG TEST] Use disposable campaign only.
[TBG TEST] Scenario: RichPlayerEconomyTest
[TBG TEST] Gold before: <starting gold>
[TBG TEST] Gold added: 100,000
[TBG TEST] Gold after: <starting gold + 100,000>
[TBG TEST] PASS
```

**Expected status JSON (`goldTest`):**

```json
"goldTest": { "ran": true, "passed": true, "delta": 100000 }
```

**Pass:**

- Gold increases by exactly 100,000.
- Debug output shows before/after values.
- No crash; save remains loadable.

**Fail:**

- Gold unchanged, unpredictable delta, crash, save corruption, or no diagnostic output.

---

## Test 4: Smithing Progression Test (Sprint 002)

**Status:** **Pending** — source scaffolded; `Ctrl+Alt+S` reserved but **not wired**. Use Sprint 001 harness (F8–F11) for certification.

**Purpose:** Confirm mod-side scripts can modify player character progression safely (Sprint 002).

**Steps (when hotkey is wired):**

1. `dotnet build -c Release` (auto-installs) or `.\forge.ps1`
2. **Steam → Play** with **The Blacksmith Guild** checked
3. Load a **new disposable** campaign
4. On the campaign map, press **Ctrl+Alt+S** (reserved — not active yet)
5. Check `BlacksmithGuild_Phase1.log`

**Current certification instead:**

1. Disposable campaign (mod ON)
2. **F8** — list registered commands (expect four)
3. **F9** — advance one day
4. **F10** — toggle fast-forward ON/OFF
5. **F11** — run gold test explicitly
6. Check `BlacksmithGuild_Status.json` then `BlacksmithGuild_Phase1.log`

**Expected output:**

```text
[TBG TEST] Scenario: RichSmithingProgressionTest
[TBG TEST] Smithing before smithing skill level: <value>
[TBG TEST] Smithing before smithing XP: <value>
[TBG TEST] Smithing XP added: 10,000
[TBG TEST] Smithing focus added: 3
[TBG TEST] Smithing after smithing XP: <value>
[TBG TEST] Smithing after smithing focus: <value>
[TBG TEST] PASS
```

Note: Bannerlord maps smithing readiness to the **Crafting** skill (`DefaultSkills.Crafting`).

**Pass:**

- No crash.
- Smithing progression changes by the expected amount or logs a clear partial result.
- Save remains loadable after saving and reloading.

**Fail:**

- MainHero is null.
- No progression changes.
- Crash, save corruption, or silent failure with no diagnostic output.

---

## Notes

- Bannerlord may load mods from `Win64_Shipping_Client` or `Win64_Shipping_wEditor` depending on launcher path — both folders must contain `BlacksmithGuild.dll` (v0.0.3+).
- **Primary dev keys:** F8 = `ListScenarios`, F9 = `AdvanceOneDay`, F10 = `ToggleFastForward`, F11 = `RichPlayerEconomyTest`.
- **Legacy fallbacks:** `Ctrl+Alt+L/D/F` map to the same commands (no F11 legacy).
- Risky commands are blocked when readiness/preflight is FAIL. `ListScenarios` is always safe.
- `RichPlayerEconomyTest` is an explicit mutation command (F11 or file inbox). Optional auto-run on daily tick remains configurable via `AutoRunGoldTestOnDailyTick`.
- `RichSmithingProgressionTest` is **not wired** (Sprint 002) — `Ctrl+Alt+S` is reserved.
- `forge.ps1 -Check` reads in-game `BlacksmithGuild_Status.json` first, then confirms log details.
