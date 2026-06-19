# BlacksmithGuild — Active Checkpoint After 006I-4 Path C PASS

## Repo state

| Field | Value |
|-------|-------|
| Path | `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild` |
| Remote | `https://github.com/EndeavorEverlasting/BlacksmithGuild.git` |
| Branch | `main` |
| Rollback anchor | `57f6062` — tag `006i-4-path-c-pass` |
| Version | `v0.0.11` |
| Remote sync | 10 commits ahead of `origin/main` |
| Push | HOLD until user explicitly requests |
| Open PRs | None |

## Rollback

```powershell
git checkout 006i-4-path-c-pass
```

## Current verdict

Sprint **006I** overall: **RE-CERT PARTIAL**

| Path / Layer | Result | Evidence |
|--------------|--------|----------|
| Path A — bootstrap | **PASS** | Phase1 ~02:32:04 — count=1 OnActivate, Options block, TBG READY |
| Path B — culture Back | **PENDING** | Not re-certified after 006I-4 |
| Path C — quit to menu | **USER PASS** | User confirmed 2026-06-19; `decision=block reason=intent already consumed` |
| Continue load | **FAIL** | LaunchForge → Continue → Module Mismatch → GameLoadingState hang 5+ min |
| Layer A handoff | **PENDING** | Launcher timeout — no `handoff:` in some sessions |

## What shipped in 006I-4

**Commit:** `57f6062` — Fix quit-to-menu intro replay guard diagnostics

- Clear intent memory after consume; block menu auto-select when intent consumed or bootstrap completed (play only)
- Permanent post-READY disarm latch
- Diagnostic logging for main menu intent decisions

**User-confirmed Path C PASS:** quit clean, no intro replay, no Task Manager.

## Active blocker (006I-5)

LaunchForge → Continue → Module Mismatch (manual Yes) → infinite `GameLoadingState` loading screen.

- No Module Mismatch automation in `launcher-auto-nav.ps1` (pre-006I-5)
- Status.json stuck: `activeState=GameLoadingState`, `setupPhase=Complete`, stale `campaignReady=true`

## Next sprint

See [docs/plans/006i-5-continue-module-mismatch-load.plan.md](../plans/006i-5-continue-module-mismatch-load.plan.md):

1. UIA auto-click Module Mismatch Yes
2. `LaunchForgeContinue.cmd` entrypoint
3. Loading stall watchdog (180s C# log + script terminate)
4. Re-test load path matrix; then Path B culture Back

## Output files to analyze

```text
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Phase1.log
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Launch.log
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Status.json
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Forge.log
```

## Scope lock

Do not:

- Start 005E
- Bump version
- Push remote (unless user requests)
- Revert 006I-4 quit fix (`57f6062` / tag `006i-4-path-c-pass`)
