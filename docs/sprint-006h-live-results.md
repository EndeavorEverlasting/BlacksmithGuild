# Sprint 006H — Family Stall Recovery — Live Certification

## Verdict

**Code shipped** — live cert pending (Forge.cmd zero-click through Family + subsequent narrative menus)

## Scope

Fix post-006G Family stall where selection registered but Next stayed gray:

- `StringId` is a **field** on v1.4.6 `NarrativeMenu` / `NarrativeMenuOption` (not property)
- `SelectedOptions` keys are `NarrativeMenu` **object references** — use `ReferenceEquals`, not string ids
- Call `StartNarrativeStage()` once before first selection
- Gate narrative on culture selected
- Recovery ladder: `TrySwitchToNextMenu` → manual `OutputMenuId` + `set CurrentMenu` → clear stale selection + re-select
- Fix `ManagerNextStagePostfix` to resolve `CharacterCreationState` from manager `_state`

**Out of scope:** profile-aware picks, tutorial skip, UI automation, SubModule version bump.

## What shipped

| Piece | Location | Behavior |
|-------|----------|----------|
| `GetStringId` field-first | `CharacterCreationReflection.cs` | Real menu ids in logs (`empire_family`) |
| Reference-equality selection check | `CharacterCreationReflection.cs` | `IsCurrentMenuSelected` uses `ReferenceEquals` on dictionary keys |
| Narrative init | `CharacterCreationReflection.cs` | `StartNarrativeStage()` once; culture gate |
| Stall recovery | `CharacterCreationReflection.cs` | Manual advance + re-select on `switchToNextMenu=false` |
| Postfix state fix | `AutoCharacterCreationPatches.cs` | `_state` field instead of `GameLoadingState` |

## Root cause (006G live FAIL)

006G fixed OnCondition and found 6 suitable options, but stalled after one selection:

```text
[TBG QUICKSTART] narrative auto-selected menu=NarrativeMenu option=NarrativeMenuOption (suitable=6)
[TBG QUICKSTART] narrative advanced to next menu (TrySwitchToNextMenu)
[TBG QUICKSTART] narrative stall detail: currentMenu=NarrativeMenu suitableCount=0 selectedCount=1 switchToNextMenu=false
```

Broken `GetMenuId` (property-only) + string matching on `Dictionary<NarrativeMenu, NarrativeMenuOption>` caused false "already selected" trap with no recovery.

## Live cert protocol

**Precondition:** Close Bannerlord completely.

```text
Forge.cmd  (zero-click)
```

### PASS signals — `BlacksmithGuild_Phase1.log`

```text
[TBG QUICKSTART] API probe: ... startNarrativeStage=found getNarrativeMenuWithId=found ...
[TBG QUICKSTART] narrative stage initialized
[TBG QUICKSTART] culture auto-selected: ...
[TBG QUICKSTART] narrative auto-selected menu=empire_family option=... (suitable=6)
[TBG QUICKSTART] narrative advanced to next menu (TrySwitchToNextMenu)
... (repeat per narrative question)
[TBG QUICKSTART] setup complete
TBG READY
```

**Must NOT see:**

- `menu=NarrativeMenu option=NarrativeMenuOption` (type-name fallback)
- `selectedCount=1 switchToNextMenu=false` followed by 5s stall on Family
- Idle Family screen with gray Next

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

Key lines: `narrative stage initialized`, `narrative auto-selected menu=empire_family`, `narrative advanced to next menu`, stall detail with real StringIds

## Known gaps (explicit)

| Gap | Notes |
|-----|--------|
| Profile-aware narrative picks | First valid option |
| Tutorial skip | Out of scope |
| Story Mode | Blocked |
| Manual `set_CurrentMenu` UI desync | Fallback only; prefer engine `TrySwitchToNextMenu` |

## Risks

| Risk | Mitigation |
|------|------------|
| `StartNarrativeStage` clears selections | Call once before first select; re-select after clear |
| Double culture apply | Culture gate before narrative; postfix uses correct state |
| Manual advance desyncs UI | Logged separately; engine path preferred |

## Cert record (fill after live run)

| Path | Result | Date | Notes |
|------|--------|------|-------|
| A — Forge.cmd bootstrap (full map) | **PENDING** | | 006H stall recovery |
| B — ForgeContinue.cmd regression | **PENDING** | | Should be unaffected |
| 006G narrative API fix | **FAIL** | 2026-06-19 | StringId field + SelectedOptions ref-eq + stall trap |
