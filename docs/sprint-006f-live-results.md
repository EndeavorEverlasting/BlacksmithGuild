# Sprint 006F — Narrative Menu Sprint-Through — Live Certification

## Verdict

**FAIL** — live cert blocked on Family screen (OnCondition invoked without manager; no TrySwitchToNextMenu)

Superseded by [sprint-006g-live-results.md](sprint-006g-live-results.md).

## Scope

Fix character creation stall on **Choose your Family** and subsequent narrative menus:

- Incremental `TryAdvanceNarrativeMenu` — one menu per Poll tick, first valid option
- Per-tick retry for narrative (like culture stage)
- Bool-based advance gate — only mark progress when handler returns true
- Narrative stall diagnostics (menu index, option count, invoke error)

**Out of scope:** profile-aware narrative picks, tutorial skip, face customization.

## What shipped

| Piece | Location | Behavior |
|-------|----------|----------|
| Incremental narrative | `CharacterCreationReflection.cs` | `TryAdvanceNarrativeMenu` uses `CurrentMenuIndex` (fallback: tracked count) |
| Safe NextStage | `CharacterCreationReflection.cs` | `TryNextStage` with inner-exception logging |
| Poll retry gate | `CampaignSetupStateTracker.cs` | Culture + narrative retry every tick; simple stages one-shot `NextStage` |
| Stall diagnostics | Both | `narrative stall detail: menu=N optionCount=...` on 5s stall |

## Root cause (Family screen stall)

- `SkipNarrativeStage` blasted all menu indices in one tick; visible menu is one at a time
- Poll engine marked narrative as advanced after one failed attempt (`advanced = true` unconditionally)
- No narrative failure logging

## Live cert protocol

**Precondition:** Close Bannerlord.

```text
Forge.cmd  (zero-click)
```

### PASS signals — `BlacksmithGuild_Phase1.log`

```text
[TBG QUICKSTART] culture auto-selected: ...
[TBG QUICKSTART] narrative auto-selected menu=0 option=...
[TBG QUICKSTART] narrative auto-selected menu=1 option=...
[TBG QUICKSTART] transition: CharacterCreation(...) -> MapState
[TBG QUICKSTART] setup complete
TBG READY
```

**Must NOT see:** idle on Family screen; `stage stalled for 5s at CharacterCreationNarrativeStage`

### On FAIL

Paste Phase1.log tail (~40 lines). No per-menu screenshots required unless stage name is unknown.

```powershell
.\forge.ps1 -CollectDiagnostics
```

## Output files to analyze

```text
<Bannerlord install root>\BlacksmithGuild_Phase1.log
Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Phase1.log
Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Status.json
```

## Known gaps (explicit)

| Gap | Notes |
|-----|--------|
| Profile-aware narrative picks | Deferred — first valid option for sprint |
| Tutorial skip | Out of scope |
| Face customization | `NextStage` only — no appearance tuning |
| Story Mode | Still blocked |
| `CurrentMenuIndex` API drift | Probe logs `currentMenuIndex=found|missing`; fallback tracked count |

## Risks

| Risk | Mitigation |
|------|------------|
| `OnNarrativeMenuOptionSelected` throws | Catch + log inner exception; retry next tick |
| Double `NextStage` on simple stages | `_simpleStagePendingAdvance` one-shot per sub-stage |
| Wrong option affects skills | Acceptable for sprint; profiles later |
| Menu index property missing | Tracked `_narrativeMenusCompleted` fallback |

## Cert record (fill after live run)

| Path | Result | Date | Notes |
|------|--------|------|-------|
| A — Forge.cmd bootstrap (full map) | **FAIL** | 2026-06-19 | `menu=0 no valid option (36 total) menuCount=6`; stalled 5s at CharacterCreationNarrativeStage |
| B — ForgeContinue.cmd regression | **PENDING** | | Should be unaffected |
| 006E launch funnel | **PARTIAL PASS** | 2026-06-18 | PLAY, Safe Mode, culture, face reached Family |
