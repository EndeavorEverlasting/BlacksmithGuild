# Sprint 006D — QuickStart v1.4.6 Character Creation Hotfix — Live Certification

## Verdict

**Code shipped** — live cert pending (New Campaign → SandBox on v1.4.6.115628)

## Scope

Fix New Campaign SandBox bootstrap on **Bannerlord v1.4.6** where 006C intro skip worked but character creation automation failed:

- DIY `SandboxCharacterCreationContent` intercept removed (type gone on v1.4.6)
- Vanilla `LaunchSandboxCharacterCreation` runs; Poll auto-advances stages
- Culture stage: `SetSelectedCulture` + `ApplyCulture`
- Narrative stage: `OnNarrativeMenuOptionSelected` (single-arg) instead of legacy `RunConsequence`
- False "setup stalled at OnLoadFinished" notices removed

## What shipped

| Piece | Location | Behavior |
|-------|----------|----------|
| Vanilla launch | `AutoCharacterCreationPatches.cs` | Observe-only prefix on `LaunchSandboxCharacterCreation`; no DIY CreateState |
| Poll stage engine | `CampaignSetupStateTracker.cs` | `TryAdvanceCurrentCreationStage(dt)` each tick; culture retry; 5s stall timer |
| v1.4.6 reflection | `CharacterCreationReflection.cs` | `ApplyCulture`, `TrySkipCultureStage`, narrative API binding probe |
| Tick dt | `SubModule.cs` | `CampaignSetupStateTracker.Poll(dt)` |

## Root cause (006C FAIL on v1.4.6)

Phase1.log evidence:

```text
[TBG QUICKSTART] OnLoadFinished: could not create character creation content — vanilla path.
[TBG QUICKSTART] stage handler failed at CharacterCreationNarrativeStage: Parameter count mismatch.
```

- `SandBox.SandboxCharacterCreationContent` removed; DIY `CreateState` path dead
- Poll detected culture stage but never ran stage handlers on vanilla path
- Narrative API changed to single-arg `OnNarrativeMenuOptionSelected`

## Live cert protocol

### Path A — New Campaign bootstrap (primary)

```text
Close Bannerlord → Forge.cmd → New Campaign → SandBox
```

**PASS if:**

- Intro cutscene skipped (006C regression)
- Culture auto-selected; trait panel populates without click
- No manual clicks through character creation
- Map ready + `TBG READY` within ~60s
- Phase1.log: `using vanilla character creation launch; Poll will auto-advance stages`
- Phase1.log: `culture=found narrative=OnNarrativeMenuOptionSelected`
- No `Parameter count mismatch`; no false `setup stalled at OnLoadFinished`

### Path B — Continue regression

```text
Forge.cmd → Continue → TBG DEVSAVE / TBG READY
```

## Output files to analyze

```text
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\
  BlacksmithGuild_Phase1.log
  BlacksmithGuild_Status.json
```

Key log lines:

```text
[TBG QUICKSTART] API probe: ... culture=found narrative=OnNarrativeMenuOptionSelected
[TBG QUICKSTART] using vanilla character creation launch; Poll will auto-advance stages.
[TBG QUICKSTART] transition: CharacterCreation(CharacterCreationCultureStage) -> CharacterCreation(...)
```

## Known gaps (post-006D)

| Gap | Detail |
|-----|--------|
| **Live cert not run** | PASS requires user Phase1.log + in-game evidence |
| **Tutorial skip** | Not implemented — user expectation documented for future sprint |
| **Main-menu automation** | Play → New Campaign → SandBox still manual clicks |
| **Story Mode** | Correctly blocked |
| **006B profile cert** | Still pending separately |

## Risks

| Risk | Mitigation |
|------|------------|
| `ApplyCulture` timing | Culture stage retries each Poll tick until cultures load |
| Double `NextStage` | Per-sub-stage `_lastHandledCreationSubStage` guard |
| Older game builds | Legacy `RunConsequence` 3-arg fallback retained |

## Failure classification

| Symptom | Likely cause |
|---------|--------------|
| Empty culture traits | Old DLL or `ApplyCulture` probe missing — check Phase1.log |
| Still on culture after 5s | `setup stalled at CharacterCreation/CharacterCreationCultureStage` in log |
| Narrative crash | `narrative=missing` in API probe — game update drift |
| Back to main menu | Narrative handler still failing — check for Parameter count mismatch |
