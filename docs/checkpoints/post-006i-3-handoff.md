# BlacksmithGuild — Active Checkpoint After 006I-3

## Repo state

| Field | Value |
|-------|-------|
| Path | `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild` |
| Remote | `https://github.com/EndeavorEverlasting/BlacksmithGuild.git` |
| Branch | `main` |
| HEAD | `3cdbdd3` |
| Version | `v0.0.11` |
| Working tree | Clean |
| Remote sync | 7 commits ahead of `origin/main` |
| Push | HOLD until user explicitly requests |
| Open PRs | None |

## Current verdict

Sprint **006I-3** is:

**SHIPPED — RE-CERT PENDING**

Do not mark PASS yet.

## Sprint status

| Sprint | Status |
|--------|--------|
| 006H | LIVE CERT PASS. Do not regress narrative/bootstrap. |
| 006I hotfix | Partial PASS. Disarm fix and count=1 OnActivate skip confirmed. |
| 006I-2 | SHIPPED. Layer A handoff cert pending. |
| 006I-3 | SHIPPED. Re-cert PENDING. |
| 005E economics | NEXT. Gated on 006I cert PASS. |

## Latest cert state (2026-06-19)

**PARTIAL**

| Path / Layer | Result | Evidence |
|--------------|--------|----------|
| Path A bootstrap | PARTIAL PASS | Screenshot: TBG READY, Summer 1 1084, Danustica, ForgeQuartermasterWarlord ~01:22 |
| Path B culture Back | FAIL | Back/Escape from culture caused full cutscene replay |
| Path C quit | FAIL | Quit required Task Manager |
| Layer A launcher | INCONCLUSIVE | Pasted Launch.log stale; timeout 00:59:24, no `handoff:` |
| Layer B in-game | PARTIAL | Screenshot success ~01:22; pasted Phase1 stale with count=2 loop at 00:57 |

## What shipped in 006I-3

**Commit:** `3cdbdd3`

**Primary file:** `src/BlacksmithGuild/DevTools/QuickStart/SandboxCampaignIntroSkip.cs`

1. **Forward one-shot guard** — `_forwardIntroSkipDone` set after count=1 forward skip; prevents second forward skip from replaying intro after Options.

2. **Narrow skip gate** — Blocks CleanAndPushState skip during Options or post-forward character creation; allows `CharacterCreationCultureStage` so culture Back can still use intro skip.

3. **Phase lag fix** — `GetCurrentCreationSubStage()` reads live creation state instead of stale tracker phase.

4. **Quit guard** — No intro skip when phase is Complete or active state is InitialState; counters reset on `Game.End`.

5. **Logging** — Expected useful line: `intro skip blocked: CleanAndPushState (subStage=...)`

## Prior fixes that must not be reverted

| Commit | Changes |
|--------|---------|
| `3758335` | `IsForwardLaunchInProgress`; `GameState.OnActivate` patch |
| `6fb5825` | `launcher-auto-nav.ps1` stable handoff; 3-poll handoff; crash reporter immediate handoff; `handoff: <reason>` logging |

## Required next action

User must close Bannerlord completely, then run:

```powershell
Get-Process Bannerlord, TaleWorlds.MountAndBlade.Launcher -ErrorAction SilentlyContinue

cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
.\Forge.cmd
```

After Path A bootstrap and manual Path B/C checks, collect:

```powershell
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Phase1.log" -Tail 120
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Launch.log" -Tail 60
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Status.json" -Tail 100
```

## PASS requirements after re-cert

006I-3 can be marked PASS only if fresh evidence shows:

- Launch.log contains `handoff:`
- Launch.log does not contain `launcher-auto-nav timed out`
- Phase1.log contains `intro skip: campaign video via OnActivate (count=1)`
- Phase1.log reaches `TBG READY: campaign map ready`
- No forward-bootstrap `CleanAndPushState (count=2)` before TBG READY
- No Options → Culture/Narrative restart
- Path B culture Back/Escape does not replay the full cutscene
- Path C pause and quit exits cleanly without Task Manager

### Expected acceptable line

During Options/post-forward protection:

```text
intro skip blocked: CleanAndPushState
```

### FAIL signatures

Treat as failures unless clearly after valid culture Back test:

```text
launcher-auto-nav timed out
intro skip: campaign video via CleanAndPushState (count=2)
Options -> Culture
Options -> Narrative
bootstrap disarmed: returned to main menu
```

**Path B exception:** `count=2+` after intentional culture Back may be expected.

## Analysis response shape

When fresh logs are pasted, answer exactly:

```text
Verdict:
Layer A:
Layer B:
Path A:
Path B:
Path C:
PASS/FAIL:
Smallest next fix:
Exact evidence lines:
```

## Scope lock

Do not:

- Start 005E
- Touch forge economics
- Bump version
- Push remote
- Mark 006I-3 PASS without fresh A/B/C evidence
- Rewrite launcher automation
- Revert 006H narrative fixes
- Revert 006I/006I-2 intro skip and launcher fixes

## After PASS only

1. Update [docs/sprint-006i-live-results.md](../sprint-006i-live-results.md) to LIVE CERT PASS
2. Update [NEXT_STEPS.md](../../NEXT_STEPS.md) to unblock 005E
3. Keep version bump as user decision
4. Push only if user requests
5. Begin 005E only by creating `docs/plans/005e-*.plan.md` first

## Git hygiene

- Docs-only checkpoint edits do not require code changes
- DLL install blocked if Bannerlord running — close game before `.\Forge.cmd`
- Never force-push `main`
