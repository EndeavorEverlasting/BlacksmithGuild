---
name: 006I-3 Narrow Skip Gate + Quit Guard
overview: "006I-2 live cert PARTIAL: Path A reaches TBG READY but Path B culture Back replays cutscene; Path C quit hangs. Narrow creation gate to block Options re-push while allowing Culture Back; add quit lifecycle guards."
todos:
  - id: narrow-creation-gate
    content: Narrow CleanAndPushState gate; allow CharacterCreationCultureStage Back skip
    status: completed
  - id: one-shot-forward-skip
    content: Add _forwardIntroSkipDone + direct subStage read for Phase poll lag
    status: completed
  - id: quit-teardown-guard
    content: Block intro skip when Phase Complete or InitialState; reset counters on Game.End
    status: completed
  - id: recert-user-run
    content: User closes Bannerlord, runs .\Forge.cmd, re-tests Paths A/B/C
    status: pending
  - id: docs-partial-cert
    content: Record PARTIAL cert from 2026-06-19 session; fix .\Forge.cmd in docs
    status: completed
  - id: docs-checkpoint
    content: Create post-006i-3-handoff.md active checkpoint
    status: completed
isProject: false
---

# Sprint 006I-3 — Narrow Skip Gate + Quit Guard

## Verdict (pre-fix cert, 2026-06-19)

**PARTIAL** — Path A map bootstrap works (screenshot TBG READY ~01:22); Path B FAIL (cutscene on culture Back/Escape); Path C FAIL (quit requires Task Manager).

## Root causes

1. **006I-2 blanket `Phase == CharacterCreation` block** also blocked legitimate culture-Back intro skip.
2. **Phase poll lag** — `CleanAndPushState` ran before `Poll()` updated Phase, allowing count=2 at Options.
3. **Quit teardown** — intro skip could fire after disarm or during `InitialState` return.

## Shipped (006I-3)

| Piece | Behavior |
|-------|----------|
| `_forwardIntroSkipDone` | Set after count=1; blocks further CleanAndPushState skips except CultureStage |
| `GetCurrentCreationSubStage()` | Direct read from CharacterCreationState (fixes Phase lag) |
| `ShouldBlockCleanAndPushIntroSkip()` | Block Options + post-forward creation; allow Culture Back |
| `ShouldBlockOnActivateIntroSkip()` | Same narrow rule for OnActivate |
| Quit guards | Skip disabled when Phase Complete or activeState InitialState |
| `GameEndPrefix` | Resets skip counters on game end |

## Re-cert

Checkpoint: [docs/checkpoints/post-006i-3-handoff.md](../checkpoints/post-006i-3-handoff.md)

Close Bannerlord, then:

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
.\Forge.cmd
```
