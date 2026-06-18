# Next Steps

Math before hammer.

---

## Repo state (handoff for next chat)

| Field | Value |
|-------|-------|
| Branch | `main` |
| Version | `v0.0.4` |
| Sprint 001 | **Implemented** — manual smithing progression dev scenario (`Ctrl+Alt+S`); needs in-game PASS |
| Sprint 000A | **Blocked** — game data errors on some loads; disposable campaign + mod ON for cert |
| Save safety | Incremental backup on every `forge.ps1` run; `.\forge.ps1 -VerifySaves` |
| Legacy saves | Load with **mod OFF** (confirmed working) |

**Next: in-game PASS for Test 4, then Phase 2 recommendation design (Issue 3).**

---

## Approach (next feature)

1. **Use the repo’s existing dev-command spine.** `DevCommandRegistry`, `DevCommandRunner`, hotkeys, and test scenarios already exist. Do not bypass that. Add skill progression through the same machinery.
2. **Do not keep stacking daily-tick hacks.** Gold injection on daily tick was fine for Sprint 000; skill-point testing must be **manually triggered and repeatable**.
3. **Treat “skill points” precisely.** Bannerlord has skill XP, focus points, attribute points, and direct skill-level effects. Do not lump them together.
4. **Build recommendation logic later on top of the same test data.** Graduate `ForgeAdvisor` from fake candidates into real recommendation models (Phase 2).

---

## Sprint 001: Stoke the Apprentice

**Subtitle:** Controlled character progression test harness

### Goal

Add controlled dev commands that modify the player’s smithing readiness for testing:

- Add Smithing XP
- Add focus to Smithing
- Add Endurance attribute support
- Log before / after values
- Avoid save corruption
- Keep everything behind `DevToolsConfig.DevToolsEnabled`

### New files

```text
src/BlacksmithGuild/DevTools/
  CharacterProgressionTestScenarios.cs
  CharacterProgressionSnapshot.cs
```

Optional later: `HeroProgressionDevTools.cs`

### New dev commands (`DevCommandRegistry`)

```csharp
public const string RichSmithingProgressionTestName = "RichSmithingProgressionTest";
public const string AddSmithingXpCommand = "AddSmithingXp";
public const string AddSmithingFocusCommand = "AddSmithingFocus";
public const string AddEnduranceAttributeCommand = "AddEnduranceAttribute";
```

Register in `RegisteredCommands` beside gold, time, and list commands.

### New hotkeys (`BlacksmithGuildCampaignBehavior`)

| Hotkey | Action |
|--------|--------|
| `Ctrl+Alt+S` | Run `RichSmithingProgressionTest` |
| `Ctrl+Alt+X` | Add Smithing XP only |
| `Ctrl+Alt+C` | Add Smithing focus only |

Existing hotkeys unchanged: `Ctrl+Alt+D` / `F` / `L`.

**Do not auto-run progression test on daily tick.** Keep gold test behavior unchanged.

### Core scenario

`CharacterProgressionTestScenarios.RunRichSmithingProgressionTest()`:

1. Get `Hero.MainHero` — FAIL if null
2. Capture before snapshot (`CharacterProgressionSnapshot`): gold, Smithing level/XP, Smithing focus, Endurance, unspent focus/attribute points (log `unavailable` if API missing)
3. Apply conservative deltas:
   - Smithing XP: `10_000`
   - Smithing focus: `3`
   - Endurance attribute: `1` (only if needed)
4. Capture after snapshot
5. Log before / after via `DebugLogger.Test(...)`
6. `PASS` only if expected values changed; else `FAIL` with explanation

### Files to touch

- `src/BlacksmithGuild/DevTools/CharacterProgressionSnapshot.cs` (new)
- `src/BlacksmithGuild/DevTools/CharacterProgressionTestScenarios.cs` (new)
- `src/BlacksmithGuild/DevTools/DevCommandRegistry.cs`
- `src/BlacksmithGuild/DevTools/DevCommandRunner.cs`
- `src/BlacksmithGuild/Behaviors/BlacksmithGuildCampaignBehavior.cs`
- `docs/test-plan.md` — add **Test 4: Smithing Progression Test**

### Hard constraints

- Do not remove `RichPlayerEconomyTest`
- Do not break `Ctrl+Alt+D` / `F` / `L`
- No UI yet
- Dev-tool gated; respect preflight safety gates
- Explicit logs over silent success
- Use compile-safe Bannerlord APIs (`HeroDeveloper`, skill objects) — inspect TaleWorlds refs if names differ

### Acceptance

- `dotnet build` Release succeeds
- `.\forge.ps1 -Check` still works
- Campaign loads (disposable save, mod ON)
- `Ctrl+Alt+S` runs scenario; log shows before / after
- Save remains loadable after save/reload

### Test 4 (add to `docs/test-plan.md`)

**Steps:** `.\forge.ps1` → enable mod → load campaign → `Ctrl+Alt+S` on campaign map → check `BlacksmithGuild_Phase1.log`

**Expected log:**

```text
[TBG TEST] Scenario: RichSmithingProgressionTest
[TBG TEST] Smithing before: <value>
[TBG TEST] Smithing XP added: 10,000
[TBG TEST] Smithing after: <value>
[TBG TEST] Smithing focus before: <value>
[TBG TEST] Smithing focus after: <value>
[TBG TEST] PASS
```

---

## Cursor prompt (paste next session)

```text
Repo: EndeavorEverlasting/BlacksmithGuild

Implement Sprint 001: Stoke the Apprentice.

Goal:
Add a controlled character progression dev scenario for Mount & Blade II: Bannerlord that can modify the player hero’s smithing readiness for testing.

Existing architecture:
- Dev commands: src/BlacksmithGuild/DevTools/DevCommandRegistry.cs
- Execution: src/BlacksmithGuild/DevTools/DevCommandRunner.cs
- Hotkeys: src/BlacksmithGuild/Behaviors/BlacksmithGuildCampaignBehavior.cs
- Economy test pattern: src/BlacksmithGuild/DevTools/EconomyTestScenarios.cs
- Logging: DebugLogger.Test(...)

Required changes:
1. Add CharacterProgressionSnapshot.cs — before/after MainHero progression capture
2. Add CharacterProgressionTestScenarios.cs — RichSmithingProgressionTest (XP 10k, focus 3, Endurance 1)
3. Update DevCommandRegistry — register RichSmithingProgressionTest + AddSmithingXp/Focus/Endurance constants
4. Update DevCommandRunner — route scenario; safe cases for granular commands if implemented
5. Update BlacksmithGuildCampaignBehavior — Ctrl+Alt+S (and X/C if in scope); no daily-tick auto-run
6. Update docs/test-plan.md — Test 4

Hard constraints:
- Keep RichPlayerEconomyTest and existing hotkeys
- No UI; dev-gated; preflight gates respected
- dotnet build + forge.ps1 -Check must pass

See NEXT_STEPS.md for full spec.
```

---

## GitHub issues to create (separate tickets)

### Issue 1 — Sprint 001: Controlled smithing progression dev scenario

- `CharacterProgressionTestScenarios.cs`, `CharacterProgressionSnapshot.cs`
- Register `RichSmithingProgressionTest`, hotkey `Ctrl+Alt+S`
- Before/after logs, PASS/FAIL, test plan update

### Issue 2 — Granular dev commands

- `AddSmithingXp`, `AddSmithingFocus`, `AddEnduranceAttribute`
- Hotkeys `Ctrl+Alt+X`, `Ctrl+Alt+C` (optional same sprint or follow-up)
- Each logs before/after; unknown commands fail safely

### Issue 3 — Design forge recommendation data model (Phase 2)

- Expand `ForgeCandidate`, add `PlayerForgeState`, `RecommendationScoreBreakdown`
- Preserve fake smoke test; deterministic ranking

### Issue 4 — Doctrine-aware advisor scoring pass (Phase 2)

- Tunable weights for `CashCrisis`, `RareMetalConservation`, `ProfitForge`, `UnlockGrinder`, `WarArsenal`, `MaterialAlchemist`, `CommissionHunter`
- Same candidates rank differently per doctrine; output explains winner

---

## Phase 2: Recommendation system (after Sprint 001)

**Goal:** Forge advisor with teeth — answer what to craft, smelt, buy, sell, or grind next given hero, materials, unlocks, economy, doctrine.

### Layers

1. **Doctrine** — existing `ForgeDoctrine` enums; replace placeholder bonuses with tunable weights
2. **Candidate model** — expand `ForgeCandidate` (`ActionType`, `UnlockPotential`, `SkillXpPotential`, `TimeCost`, `Reason`, etc.)
3. **Game-state reader** — `GameState/PlayerForgeState.cs`, `PlayerForgeStateReader.cs` (mock unreadable fields at first)
4. **Scoring engine** — weighted sum: profit, unlock, XP, scarcity, time, risk, doctrineBonus
5. **Output** — logs only first (`[TBG ADVISOR] Top recommendation: ...`); UI later

**Not before Sprint 001 PASS.**

---

## Phase 1B / 1C (unchanged, after 000A + 001)

### Phase 1B: Manual real candidate ranker (v0.1.1)

- Bump version in `SubModule.xml`
- Hard-coded real weapon rows from manual forge testing
- Branch: `feature/phase-1b-manual-candidates`

### Phase 1C: Read current selected forge design

- `TaleWorlds.Core.Crafting`, `WeaponDesign`, `DefaultSmithingModel`

---

## Stern verdict

**Next action for next chat:** Create GitHub Issue 1, then run the Sprint 001 Cursor prompt above.

Prove character progression mutation is safe **before** building the recommendation engine.
