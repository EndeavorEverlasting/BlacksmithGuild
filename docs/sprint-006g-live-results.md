# Sprint 006G — Family / Narrative Menu API Fix — Live Certification

## Verdict

**FAIL** — selection registered (`selectedCount=1`) but Family Next stayed gray; stall trap on `switchToNextMenu=false`.

Superseded by [sprint-006h-live-results.md](sprint-006h-live-results.md).

## Scope

Fix character creation stall on **Choose your Family** caused by incorrect v1.4.6 API usage:

- `OnCondition(CharacterCreationManager)` — pass manager, not null
- `GetSuitableNarrativeMenuOptions()` — current-menu options (6), not all menus (36)
- `OnNarrativeMenuOptionSelected(option)` + `TrySwitchToNextMenu()` — select then advance like clicking Next
- Split `CurrentMenu` (NarrativeMenu) from `CurrentMenuIndex` (int)

**Out of scope:** profile-aware narrative picks, tutorial skip, UI automation, SubModule version bump.

## What shipped

| Piece | Location | Behavior |
|-------|----------|----------|
| Suitable options API | `CharacterCreationReflection.cs` | `GetSuitableNarrativeMenuOptions()` with fallback chain |
| Manager-aware conditions | `CharacterCreationReflection.cs` | `IsOptionAvailable(option, manager)` |
| Menu advance | `CharacterCreationReflection.cs` | `TrySwitchToNextMenu()` after selection or when menu already selected |
| SelectedOptions probe | `CharacterCreationReflection.cs` | Skip re-select when current menu already in dictionary |
| Stall diagnostics | `CharacterCreationReflection.cs` | `currentMenu=... suitableCount=... onConditionFailures=...` |

## Root cause (006F live FAIL)

006F reached narrative but all 36 options failed `OnCondition` because it was invoked with zero arguments:

```text
[TBG QUICKSTART] culture auto-selected: Empire (count=6)
[TBG QUICKSTART] narrative stall detail: menu=0 no valid option (36 total) menuCount=6
[TBG QUICKSTART] stage stalled for 5s at CharacterCreationNarrativeStage.
```

Also never called `TrySwitchToNextMenu()` — equivalent to leaving Next gray on Family screen.

## Live cert protocol

**Precondition:** Close Bannerlord.

```text
Forge.cmd  (zero-click)
```

### PASS signals — `BlacksmithGuild_Phase1.log`

```text
[TBG QUICKSTART] API probe: ... suitableOptions=found trySwitchToNextMenu=found currentMenu=found ...
[TBG QUICKSTART] culture auto-selected: ...
[TBG QUICKSTART] narrative auto-selected menu=empire_family option=... (suitable=6)
[TBG QUICKSTART] narrative advanced to next menu (TrySwitchToNextMenu)
... (repeat per narrative question)
[TBG QUICKSTART] transition: CharacterCreation(CharacterCreationNarrativeStage) -> CharacterCreation(...)
[TBG QUICKSTART] setup complete
TBG READY
```

**Must NOT see:** `no valid option (36 total)`; idle on Family with gray Next

### On FAIL

Paste Phase1.log tail (~40 lines).

```powershell
.\forge.ps1 -CollectDiagnostics
```

## Output files to analyze

```text
<Bannerlord install root>\BlacksmithGuild_Phase1.log
Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Phase1.log
Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Status.json
```

Key lines: `narrative auto-selected`, `narrative advanced to next menu`, `narrative stall detail`

## Known gaps (explicit)

| Gap | Notes |
|-----|--------|
| Profile-aware narrative picks | Still first valid option |
| Tutorial skip | Out of scope |
| `GetSuitableNarrativeMenuOptions` missing on older builds | Fallback chain retained |
| Face customization | `NextStage` only — no appearance tuning |
| Story Mode | Still blocked |

## Risks

| Risk | Mitigation |
|------|------------|
| `TrySwitchToNextMenu` false before all menus done | Compare `SelectedOptions.Count` vs `CharacterCreationMenuCount` |
| Double `NextStage` | Only call when `TrySwitchToNextMenu` false AND all menus selected |
| API rename on future game patch | Probe + fallback chain |

## Cert record (fill after live run)

| Path | Result | Date | Notes |
|------|--------|------|-------|
| A — Forge.cmd bootstrap (full map) | **FAIL** | 2026-06-19 | `menu=NarrativeMenu selectedCount=1 switchToNextMenu=false`; Family gray Next |
| B — ForgeContinue.cmd regression | **PENDING** | | Should be unaffected |
| 006F narrative sprint | **FAIL** | 2026-06-19 | OnCondition(null) + no TrySwitchToNextMenu |
