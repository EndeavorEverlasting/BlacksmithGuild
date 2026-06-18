# Sprint 003C — QuickStart Automation Fix — Live Certification

## Verdict

**LIVE CERT PASS** — Continue path, 2026-06-18 (session 19:16 UTC)

## What shipped

| Piece | Location | Behavior |
|-------|----------|----------|
| API fix | `DevTools/QuickStart/CharacterCreationReflection.cs` | `CharacterCreationManager` (not broken `State.NextStage`) |
| Patch hardening | `DevTools/QuickStart/AutoCharacterCreationPatches.cs` | Independent patches; no null-target abort |
| Dev save auto-load | `DevTools/QuickStart/DevSaveAutoLoader.cs` | `MBGameManager.StartNewGame` → load `BlacksmithGuild_DevStart*.sav` |
| Dev save resolver | `DevTools/QuickStart/DevSaveResolver.cs` | Finds latest prefixed dev save |
| Continue pinning | `scripts/pin-dev-save.ps1` | Bumps dev save mtime so launcher **Continue** picks it |
| Forge launcher | `Forge.cmd` | Build + install + open launcher (`-Launch`) |
| Truthful notices | `CampaignSetupStateTracker.cs` | `TBG DEVSAVE` vs `TBG QUICKSTART` |

## Live cert evidence (2026-06-18)

| Check | Result |
|-------|--------|
| Path | **Continue** (dev save pinned) |
| DLL | `dllUtc=2026-06-18T23:16:10` (new build loaded) |
| API probe | `manager=found nextStage=found` |
| Patches | `OnLoadFinished=OK NextStage=OK StartNewGame=OK` |
| Map ready | `TBG READY` on campaign map |

## Live cert protocol (regression)

1. Close Bannerlord completely
2. `Forge.cmd` (build + install + launcher)
3. **Path A — dev save exists:** Click **Continue** → expect `TBG DEVSAVE: map ready (...)` under ~30s
4. **Path B — no dev save:** **Play → SandBox** → expect auto character creation (no manual clicks) → `TBG QUICKSTART: sandbox character auto-applied.`
5. Check Phase1.log for:

```text
[TBG QUICKSTART] API probe: state=found manager=found nextStage=found
[TBG QUICKSTART] patches: OnLoadFinished=OK NextStage=OK StartNewGame=OK
```

**Must NOT see:** `patch apply failed: Null method`

## PASS criteria

| Check | Expected |
|-------|----------|
| Build | `dotnet build -c Release` succeeds |
| Patches | Log shows `OnLoadFinished=OK` and `NextStage=OK` |
| Continue | Loads dev save without Load Game UI |
| SandBox (no save) | Auto-advances culture/face/narrative/review |
| Map ready | `TBG READY` within ~60s |
| Notice truth | Dev save → `TBG DEVSAVE`; new sandbox → `TBG QUICKSTART` |

## Output files to analyze

```text
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\
  BlacksmithGuild_Phase1.log          ← QUICKSTART lines, patch status
  BlacksmithGuild_Status.json         ← quickStart.setupPhase, session.phase

Documents\Mount and Blade II Bannerlord\Game Saves\Native\
  BlacksmithGuild_DevStart*.sav       ← Continue target
```

## Known gaps (post-003C)

| Gap | Detail |
|-----|--------|
| **Story Mode** | Correctly blocked — no automation |
| **F10 safety guards** | Backlog — use F9 / TreasurySnapshotNow for cert |
| **Date-stamped save naming** | `BlacksmithGuild_DevStart*.sav` works; dated rename script optional |
| **SandBox auto-character** | Not re-certified this session (Continue path only) |

## Risks

| Risk | Mitigation |
|------|------------|
| Game API drift | API probe log on startup |
| Direct save load skips SandBoxSaveHelper checks | Fallback path uses `MBSaveLoad.LoadSaveGameData` |
| Continue loads wrong save | `pin-dev-save.ps1` runs on every Forge install |

## Failure classification

| Symptom | Likely cause |
|---------|--------------|
| Still manual character creation | Old DLL — close game, `Forge.cmd`, verify install |
| `patch apply failed` | Pre-`cf257a9` build |
| Continue loads wrong campaign | No `BlacksmithGuild_DevStart*.sav` — bootstrap once via SandBox |
| `StartNewGame=SKIP` | Dev save auto-load disabled or no save found |
