# Test Plan

## Sprint sequencing

Build/install loop first. Certification evidence second. Dev-tool safety third. Skill points fourth. Recommendations later.

| Order | Sprint | Purpose | Status |
|-------|--------|---------|--------|
| 1 | **000A** | Certify in-game load / gold / hotkey chain (Tests 1–3) | **Certified** |
| 2 | **000B** | Fluid Steam dev loop (`dotnet build` auto-install, Steam Play) | Complete |
| 3 | **001 / 001B** | Dev command harness + focus-aware cert | **Certified** |
| 4 | **002** | Stoke the Apprentice — progression harness + F7 status | **Code complete — certify in-game** |
| 5 | **003** | Treasury Delta Watch | **003B shipped** — F10 retest |
| 5c | **003C** | Quick Forge Start (dev save + auto character) | **Shipped** |
| 6 | **004A** | Report formatting | **Shipped** |
| 7 | **004B** | Stub recommendations | **Shipped** — live cert pending |
| 8 | **005A** | Candidate source boundary + real scaffold | **Shipped** |
| 9 | **005B** | Doctrine dev commands | **Shipped** |
| 10 | **005C+** | Real recipe enumeration | **Gated** — 004B + 003B live cert |

> **Surfaces:** [in-game-surfaces.md](in-game-surfaces.md) — **Enter** notice log, **Alt+`** console, **F7–F11** dev keys.

## Two environments: IDE vs game

| Where | Shortcut | Purpose |
|-------|----------|---------|
| **Cursor / VS Code** (repo open) | `Ctrl+Shift+B` | Build + Install (`dotnet build -c Release`; auto-install) |
| **Terminal** (repo root) | `dotnet build ... -c Release` | Same as `Ctrl+Shift+B` without the IDE |
| **Bannerlord** (campaign map) | `F7`–`F11` | Dev commands (F7 = status) |
| **Bannerlord** (campaign map) | `Ctrl+Alt+S` / `X` / `C` / `L` / `D` / `F` | Progression + legacy |
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
3. Click **Play**, then **Load** `BlacksmithGuild_DevStart.sav` (preferred — see [dev-disposable-save.md](dev-disposable-save.md)) or a throwaway campaign.
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

## Sprint 002 — Progression harness (code complete — certify in-game)

- **Hotkeys:** `Ctrl+Alt+S` (full test), `Ctrl+Alt+X` (XP), `Ctrl+Alt+C` (focus); `AddEnduranceAttribute` via inbox only
- **F7:** `ShowForgeStatus` — read-only verdict card
- **Cert:** `.\forge.ps1 -CertifyProgression -Wait` → expect `certification002.overall: PASS` (4/4)

Entry criteria: Sprint 001 certified (`certification.overall: PASS`).

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

**Status:** **Live certified** (2026-06-18, v0.0.5)

**Evidence:** [docs/sprint-002-live-results.md](sprint-002-live-results.md)

**Purpose:** Confirm mod-side scripts can modify player character progression safely.

### Canonical certification (file inbox — focus not required)

```powershell
.\forge.ps1 -CertifyProgression -Wait
.\forge.ps1 -Check -SkipInstall
```

Expect `certification002.overall: PASS` (4/4) and `progressionTest.passed: true`.

Commands run: `RichSmithingProgressionTest`, `AddSmithingXp`, `AddSmithingFocus`, `AddEnduranceAttribute`.

### Optional hotkey path (game focused)

1. Disposable campaign (mod ON)
2. **Ctrl+Alt+S** on campaign map
3. **F7** for status summary (press **Enter** to scroll notice log)
4. Check `BlacksmithGuild_Phase1.log`

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

## Sprint 001U Live Hotkey Certification

**Status:** **Live certified** (2026-06-18, v0.0.5)

**Evidence:** [docs/sprint-001u-live-results.md](sprint-001u-live-results.md)

### Preconditions

- Disposable campaign, mod ON
- Plain campaign map, paused
- Wait for `TBG READY: campaign map ready. Press F8 for commands.`
- Close open panels (Training Field, settlement menus) — they may swallow F-keys
- Press **Enter** to expand the Combat Log before judging visibility

### Test sequence

1. **F8** — list dev commands
2. **F7** — status verdict card
3. **F9** — advance one day (`DailyTick fired`)
4. **F10** — fast-forward ON, then **F10** again OFF
5. **F11** — gold test PASS (+100,000); repeat **F11** once

### PASS criteria

- Each hotkey produces in-game notice and `[TBG COMMAND TRACE] ... result=Success` in Phase1.log
- F11 increases gold by 100,000 per press; no auto gold on daily tick
- `goldTest.passed: true` in Bannerlord-root `BlacksmithGuild_Status.json`

### Caveat

If F-keys are silent but Ctrl+Alt+7–1 work, an open panel is swallowing keys. Close the panel and retest.

---

## Sprint 003C — Quick Forge Start

**Status:** **Shipped** — dev save workflow + optional auto sandbox character creation

**Doc:** [dev-disposable-save.md](dev-disposable-save.md)

### Phase 1 — Dev save load (primary daily path)

**One-time:** copy disposable save to:

```text
Documents\Mount and Blade II Bannerlord\Game Saves\Native\BlacksmithGuild_DevStart.sav
```

**Verify:**

1. `Forge.cmd` → launcher → **Load** `BlacksmithGuild_DevStart.sav`
2. Map ready in ~30s — no character creation screens
3. `TBG READY: campaign map ready. Press F8 for commands.`
4. **F7** — status summary

### Phase 2 — Auto New Campaign (dev flag on)

`DevToolsConfig.AutoSkipCharacterCreation = true` (default in dev builds).

1. New **Sandbox** (not Story Mode), mod ON
2. No manual character-creation clicks
3. Phase1.log: `[TBG QUICKSTART] transition:` lines through creation stages
4. Notice: `TBG QUICKSTART: default character applied.`
5. Then `TBG READY`

### PASS criteria

| Phase | Evidence |
|-------|----------|
| 1 | Load save → map → `TBG READY` → F7 under 30s |
| 2 | New Sandbox → log transitions → QUICKSTART notice → `TBG READY` |

### Output files

- `BlacksmithGuild_Phase1.log` — `[TBG QUICKSTART]` transitions
- `BlacksmithGuild_Status.json` — `quickStart.setupPhase`, `quickStart.activeState`

### Fallback

If Phase 2 patch fails after game update: use Phase 1 dev save only; external QuickStart mod optional.

---

## Sprint 003 Treasury Delta Watch (003B)

**Status:** **Machinery certified** — 003B hardening shipped; **F10 retest** for deltas

**Evidence:** [docs/sprint-003-live-results.md](sprint-003-live-results.md)

### Important: F9 vs F10

| Key | Use for |
|-----|---------|
| **F9** | DailyTick harness (Sprint 001U) — does **not** advance campaign calendar |
| **F10** | Real in-game days — use for treasury delta testing |
| **TreasurySnapshotNow** | Manual snapshot via `.\forge.ps1 -Command TreasurySnapshotNow -Wait` |

### Preconditions

- Disposable save, mod ON, `TBG READY`
- Close Bannerlord before `Forge.cmd` to install 003B DLL

### Verify sequence

1. Load disposable save
2. **F10 ON** → 3–5 in-game days → **F10 OFF**
3. **F7** — `TBG TREASURY: watch=active gen=N ...`
4. `.\forge.ps1 -Command TreasurySnapshotNow -Wait`
5. Inspect `BlacksmithGuild_TreasuryWatch.json` — `snapshotGeneration`, `latestSnapshots[]`

### PASS criteria

- `snapshotGeneration` increments; JSON + F7 reflect cached state
- Zero deltas OK on stable economy if machinery proven
- Suspicious/Critical notices only when thresholds exceeded

---

## Sprint 004B — Stub recommendations (live cert pending)

### Protocol

```powershell
Forge.cmd   # game closed
# Load BlacksmithGuild_DevStart.sav → TBG READY
.\forge.ps1 -Command RankForgeCandidates -Wait
# F7 in game
```

### PASS criteria

- `BlacksmithGuild_ForgeRecommendations.json` exists; top = Long Warblade, finalScore 11250, source stub
- Phase1.log: `TBG REPORT: FORGE RECOMMENDATIONS`
- F7: compact `TBG FORGE:` line
- Update [sprint-004-live-results.md](sprint-004-live-results.md)

**Gate:** Do not call 004 done until live evidence recorded.

---

## Sprint 005A/005B — Source boundary + doctrine (code shipped; live cert pending)

### Protocol

```powershell
.\forge.ps1 -Command SetForgeCandidateSourceStub -Wait
.\forge.ps1 -Command RankForgeCandidates -Wait
.\forge.ps1 -Command SetForgeCandidateSourceReal -Wait
.\forge.ps1 -Command RankForgeCandidates -Wait   # expect stub-fallback
.\forge.ps1 -Command SetForgeDoctrineRareMetalConservation -Wait
.\forge.ps1 -Command RankForgeCandidates -Wait
.\forge.ps1 -Command ShowForgeDoctrine -Wait
```

### PASS criteria (005A)

- Default stub rank unchanged (Long Warblade 11250 under ProfitForge)
- Real source request → JSON `fallbackUsed=true`, `source=stub-fallback`, Phase1.log `[WARN]`
- JSON includes `sourceKind`, `sourceStatus`, `candidateCount`

### PASS criteria (005B)

- `SetForgeDoctrineRareMetalConservation` changes ranking vs ProfitForge (stub oracle)
- `ShowForgeDoctrine` prints active doctrine in notice log

**Gate for 005C real recipes:** 004B live cert PASS + 003B treasury retest PASS.

See [sprint-005-live-results.md](sprint-005-live-results.md).

---

## Notes

- Bannerlord may load mods from `Win64_Shipping_Client` or `Win64_Shipping_wEditor` depending on launcher path — both folders must contain `BlacksmithGuild.dll`.
- **Primary dev keys:** F7 = `ShowForgeStatus`, F8 = `ListScenarios`, F9 = `AdvanceOneDay`, F10 = `ToggleFastForward`, F11 = `RichPlayerEconomyTest`.
- **Progression:** `Ctrl+Alt+S` = `RichSmithingProgressionTest`, `Ctrl+Alt+X/C` = XP/focus only.
- **Legacy fallbacks:** `Ctrl+Alt+L/D/F` map to list/day/fast-forward.
- **Notice log:** press **Enter** on campaign map to scroll messages (see [in-game-surfaces.md](in-game-surfaces.md)).
- Risky commands blocked when preflight FAIL. `ListScenarios` and `ShowForgeStatus` are always safe.
- `forge.ps1 -Check` reads in-game status JSON first; `engine_integrity` ignores preflight disclaimer lines.
