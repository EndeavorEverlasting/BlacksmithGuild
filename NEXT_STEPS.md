# Next Steps

Math before hammer.

---

## Sprint sequencing

Build/install loop first. Certification evidence second. Dev-tool safety third. Skill points fourth. Recommendations later.

| Order | Sprint | Purpose | Status |
|-------|--------|---------|--------|
| 1 | **000A** | Certify in-game load / gold / hotkey chain (Tests 1–3) | In progress |
| 2 | **000B** | Fluid Steam dev loop (`dotnet build` auto-install, Steam Play) | **Complete** |
| 3 | **001** | Dev command harness (visible, repeatable, safe) | **Code complete — certify in-game** |
| 3b | **001B** | Focus-aware inbox poll, explicit certification status, `-Certify -Wait` | **Code complete — certify in-game** |
| 4 | **002** | Stoke the Apprentice — skill-point / progression harness | Scaffolded (docs + source; hotkeys not wired) |
| 5 | **003+** | Recommendation system | Later |

> **Breadcrumb:** `Ctrl+Alt+S` is reserved for the future smithing/progression dev command (Sprint 002).

---

## Repo state (handoff for next chat)

| Field | Value |
|-------|-------|
| Branch | `main` |
| Version | `v0.0.4` |
| Sprint 000B | **Complete** — Release auto-install, Steam Play docs, `.vscode/tasks.json` |
| Sprint 000A | **In progress** — certify Tests 2–3 on disposable campaign |
| Sprint 001 | **Code complete** — `DevCommandBus`, F8–F11, file inbox, live status JSON; needs in-game PASS |
| Sprint 001B | **Code complete** — app-tick inbox poll (alt-tab OK), `certification` block in status JSON, `forge.ps1 -Certify -Wait`, `-Check -SkipInstall` |
| Sprint 002 | **Scaffolded** — progression source files exist; hotkeys **not wired** |
| Dev loop | **Steam Play** daily; `dotnet build -c Release` auto-installs; launcher checkboxes = mod ON/OFF |
| Save safety | Incremental backup on every `forge.ps1` run; `.\forge.ps1 -VerifySaves` |
| Legacy saves | Load with **mod OFF** in launcher (confirmed working) |

**Next: In-game certification — load disposable campaign, run `.\forge.ps1 -Certify -Wait` (alt-tab OK), then `.\forge.ps1 -Check -SkipInstall`; expect `certification.overall: PASS`. Hotkeys (F8–F11) remain focus-dependent. Then Sprint 002 wires `Ctrl+Alt+S`.**

### Sprint entry gates (do not skip)

| Sprint | Enter when | Do not start if |
|--------|------------|-----------------|
| **001** Dev tool safety | 000B complete; 000A Tests 2–3 PASS in log | Preflight/crash unresolved; still using `LaunchForge` for daily play |
| **002** Stoke the Apprentice | 001 complete; dev hotkeys reliable under preflight | 000A not certified; trying to add recommendations or forge economy |
| **003+** Recommendations | 002 PASS in log; progression mutation proven safe | Skill harness not wired or untested |

---

## Approach (next feature)

1. **Use the repo’s existing dev-command spine.** `DevCommandRegistry`, `DevCommandRunner`, hotkeys, and test scenarios already exist. Do not bypass that. Add skill progression through the same machinery.
2. **Do not keep stacking daily-tick hacks.** Gold injection on daily tick was fine for Sprint 000; skill-point testing must be **manually triggered and repeatable**.
3. **Treat “skill points” precisely.** Bannerlord has skill XP, focus points, attribute points, and direct skill-level effects. Do not lump them together.
4. **Build recommendation logic later on top of the same test data.** Graduate `ForgeAdvisor` from fake candidates into real recommendation models (Phase 2).

---

## Sprint 001: Dev command harness (code complete — certify in-game)

**Delivered:**

- `DevCommandBus` — command received/started/result/blocked logging
- `GameReadinessService` — deferred preflight when MainHero ready
- `DevHotkeyHandler` — F8–F11 primary; Ctrl+Alt+L/D/F legacy; edge debounce
- `DevCommandFileInbox` + `forge.ps1 -Command <name>`
- Live `BlacksmithGuild_Status.json` after each command
- F11 = explicit `RichPlayerEconomyTest` (decoupled from F9)

**Certification sequence (primary):** Load disposable campaign → `.\forge.ps1 -Certify -Wait` → `.\forge.ps1 -Check -SkipInstall`.

**Certification sequence (manual / hotkeys):** F8 → F9 → F10 ×2 → F11 on disposable campaign (game window focused). Run `.\forge.ps1 -Check -SkipInstall`.

**Do not wire `Ctrl+Alt+S`** — reserved for Sprint 002.

---

## Sprint 001B: Focus-aware certification (code complete — certify in-game)

**Delivered:**

- `GameSessionState` — session phase, `canPollFileInbox` / `canPollHotkeys`
- `CertificationTracker` — explicit checks (`forge_lit`, `preflight_pass`, `list_commands`, `advance_one_day`, `toggle_fast_forward` ×2, `gold_test`); overall `NOT_STARTED` / `WARMUP` / `IN_PROGRESS` / `PASS` / `FAIL` / `BLOCKED`
- `OnApplicationTick` polls file inbox every 0.5s (focus-independent)
- `BlacksmithGuild_CommandAck.json` for `-Wait` command completion
- `forge.ps1 -Certify`, `-Wait`, `-SkipInstall`, `-TimeoutSec`
- wEditor DLL copy failure → WARN (launcher lock); Client DLL sufficient for Steam Play

---

## Sprint 002: Skill-point / progression harness

**Subtitle:** Controlled character progression test harness (was "Stoke the Apprentice")

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

| Hotkey | Status | Action |
|--------|--------|--------|
| `Ctrl+Alt+D` | **Wired** | `AdvanceOneDay` |
| `Ctrl+Alt+F` | **Wired** | `ToggleFastForward` |
| `Ctrl+Alt+L` | **Wired** | `ListScenarios` |
| `Ctrl+Alt+S` | **Reserved — not wired** | Sprint 002: `RichSmithingProgressionTest` |
| `Ctrl+Alt+X` | **Reserved — not wired** | Future: `AddSmithingXp` only |
| `Ctrl+Alt+C` | **Reserved — not wired** | Future: `AddSmithingFocus` only |

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
- `Ctrl+Alt+D` / `F` / `L` work on campaign map; `Ctrl+Alt+L` lists four registered commands
- Wire `Ctrl+Alt+S` and register progression commands — **not done yet**
- Save remains loadable after save/reload

### Test 4 (add to `docs/test-plan.md`) — **pending hotkey wiring**

**Steps (future):** `dotnet build -c Release` → Steam Play → mod ON → disposable campaign → `Ctrl+Alt+S` on campaign map → check `BlacksmithGuild_Phase1.log`

**Current certification:** use Tests 2–3 with `Ctrl+Alt+D` / `F` / `L` instead.

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

Implement Sprint 002: Skill-point / progression harness.

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
5. Update BlacksmithGuildCampaignBehavior — wire Ctrl+Alt+S (and X/C if in scope); no daily-tick auto-run — **S/X/C reserved, not wired yet**
6. Update docs/test-plan.md — Test 4

Hard constraints:
- Keep RichPlayerEconomyTest and existing hotkeys
- No UI; dev-gated; preflight gates respected
- dotnet build + forge.ps1 -Check must pass

See NEXT_STEPS.md for full spec.
```

---

## GitHub issues to create (separate tickets)

### Issue 1 — Sprint 001: Dev tool safety and repeatability

- Fix preflight NRE / timing
- Harden `Ctrl+Alt+D` / `F` / `L` under WARN/FAIL
- Expand `forge.ps1 -Check` test coverage

### Issue 2 — Sprint 002: Controlled smithing progression dev scenario

- Wire `CharacterProgressionTestScenarios.cs`, register commands, hotkey `Ctrl+Alt+S`
- Before/after logs, PASS/FAIL, Test 4 in test plan

### Issue 3 — Sprint 002 follow-up: Granular dev commands

- `AddSmithingXp`, `AddSmithingFocus`, `AddEnduranceAttribute`
- Hotkeys `Ctrl+Alt+X`, `Ctrl+Alt+C` (optional same sprint or follow-up)
- Each logs before/after; unknown commands fail safely

### Issue 4 — Sprint 003+: Design forge recommendation data model

- Expand `ForgeCandidate`, add `PlayerForgeState`, `RecommendationScoreBreakdown`
- Preserve fake smoke test; deterministic ranking

### Issue 5 — Sprint 003+: Doctrine-aware advisor scoring pass

- Tunable weights for `CashCrisis`, `RareMetalConservation`, `ProfitForge`, `UnlockGrinder`, `WarArsenal`, `MaterialAlchemist`, `CommissionHunter`
- Same candidates rank differently per doctrine; output explains winner

---

## Sprint 003+: Recommendation system

**Goal:** Forge advisor with teeth — answer what to craft, smelt, buy, sell, or grind next given hero, materials, unlocks, economy, doctrine.

### Layers

1. **Doctrine** — existing `ForgeDoctrine` enums; replace placeholder bonuses with tunable weights
2. **Candidate model** — expand `ForgeCandidate` (`ActionType`, `UnlockPotential`, `SkillXpPotential`, `TimeCost`, `Reason`, etc.)
3. **Game-state reader** — `GameState/PlayerForgeState.cs`, `PlayerForgeStateReader.cs` (mock unreadable fields at first)
4. **Scoring engine** — weighted sum: profit, unlock, XP, scarcity, time, risk, doctrineBonus
5. **Output** — logs only first (`[TBG ADVISOR] Top recommendation: ...`); UI later

**Not before Sprint 002 PASS.**

---

## Phase 1B / 1C (after 000A + 001 + 002)

### Phase 1B: Manual real candidate ranker (v0.1.1)

- Bump version in `SubModule.xml`
- Hard-coded real weapon rows from manual forge testing
- Branch: `feature/phase-1b-manual-candidates`

### Phase 1C: Read current selected forge design

- `TaleWorlds.Core.Crafting`, `WeaponDesign`, `DefaultSmithingModel`

---

## Stern verdict

**Next action for next chat:** Sprint 000A in-game PASS (Tests 2–3), then Sprint 001 dev tool safety. Wire `Ctrl+Alt+S` in Sprint 002 only.
