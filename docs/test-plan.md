# Test Plan — Sprint 000

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
1. LaunchForge.cmd          (auto-backs up changed saves first)
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

1. Build and install (recommended — populates both bin folders and opens the launcher):

   ```powershell
   .\forge.ps1 -Launch
   ```

   Or double-click `LaunchForge.cmd`.

   Build/install only (no launcher):

   ```powershell
   .\forge.ps1
   ```

   Or manually:

   ```powershell
   dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
   ```

2. Copy `Module/BlacksmithGuild` into `Bannerlord/Modules/BlacksmithGuild` (must include `bin/Win64_Shipping_Client` **and** `bin/Win64_Shipping_wEditor`).
3. Open the Bannerlord launcher.
4. Find **The Blacksmith Guild** in the mod list and enable it.

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
[TBG PREFLIGHT] Starting game data preflight.
[TBG PREFLIGHT] Result: PASS
BlacksmithGuild: campaign detected. Running Phase 1 fake forge advisor.
BlacksmithGuild: Top fake candidate: Long Warblade | Score 11250 | ...
```

**Expected log file:** `BlacksmithGuild_Phase1.log` near the Bannerlord base path.

**Fail:**

- No load message, crash on campaign start, or missing log file.

---

## Test 3: Rich Player Economy Test

**Purpose:** Confirm mod-side scripts can generate a controlled test value.

**Steps:**

1. Load a campaign with the mod enabled and preflight PASS (Test 2).
2. On the campaign map, press **Ctrl+Alt+D** to fire one daily tick instantly (or wait one in-game day).
3. Observe in-game messages and/or `BlacksmithGuild_Phase1.log`.
4. Open the clan finance / hero gold UI and note player gold.
5. Save the game and reload to confirm the save is still valid.

**Optional — fast-forward:** Press **Ctrl+Alt+F** to start unstoppable fast-forward; press **Ctrl+Alt+F** again to stop.

**Optional — list commands:** Press **Ctrl+Alt+L** to print registered dev commands.

**Expected output:**

```text
[TBG TEST] Scenario: RichPlayerEconomyTest
[TBG TEST] Gold before: <starting gold>
[TBG TEST] Gold added: 100,000
[TBG TEST] Gold after: <starting gold + 100,000>
[TBG TEST] PASS
```

**Pass:**

- Gold increases by exactly 100,000.
- Debug output shows before/after values.
- No crash; save remains loadable.

**Fail:**

- Gold unchanged, unpredictable delta, crash, save corruption, or no diagnostic output.

---

## Test 4: Smithing Progression Test

**Purpose:** Confirm mod-side scripts can modify player character progression safely.

**Steps:**

1. Build and install:

   ```powershell
   .\forge.ps1
   ```

2. Enable **The Blacksmith Guild** in the Bannerlord launcher.
3. Load a **new disposable** campaign.
4. On the campaign map, press **Ctrl+Alt+S**.
5. Check `BlacksmithGuild_Phase1.log`.

**Optional granular commands:**

- **Ctrl+Alt+X** — add Smithing XP only
- **Ctrl+Alt+C** — add Smithing focus only

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
- **Ctrl+Alt+D** fires `CampaignEventDispatcher.DailyTick()` for instant dev testing; **Ctrl+Alt+F** toggles fast-forward. Both are blocked when preflight is FAIL.
- `RichPlayerEconomyTest` also runs **once** on the first natural `DailyTickEvent` if `AutoRunGoldTestOnDailyTick` is enabled (also blocked on preflight FAIL).
- `RichSmithingProgressionTest` is **manual only** (`Ctrl+Alt+S`); it does not run on daily tick.
