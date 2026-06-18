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
2. Start a new sandbox campaign (or load an existing save).
3. Wait until the campaign map loads.

**Expected in-game messages:**

```text
[The Blacksmith Guild] Mod loaded. The forge is lit.
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

1. Load a campaign with the mod enabled (Test 2).
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

## Notes

- Bannerlord may load mods from `Win64_Shipping_Client` or `Win64_Shipping_wEditor` depending on launcher path — both folders must contain `BlacksmithGuild.dll` (v0.0.3+).
- **Ctrl+Alt+D** fires `CampaignEventDispatcher.DailyTick()` for instant dev testing; **Ctrl+Alt+F** toggles fast-forward.
- `RichPlayerEconomyTest` also runs **once** on the first natural `DailyTickEvent` if `AutoRunGoldTestOnDailyTick` is enabled.
- Future sprints will add manual triggers through `DevCommandRegistry`.
