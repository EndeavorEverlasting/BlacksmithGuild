# 006I-4 Plan — Quit-to-Main-Menu Intro Replay Loop

## Status

PLANNING ONLY.

This is the next stabilization sprint if 006I-3 re-cert still fails Path C.

| Gate | Status |
|------|--------|
| 006I-3 implementation | SHIPPED |
| 006I-3 re-cert | PENDING |
| Path C quit | FAIL in latest user session |
| 006I-4 implementation | NOT STARTED |
| 005E economics | BLOCKED |

## Problem

The user cannot quit cleanly to main menu during/after the bootstrap campaign path.

Observed behavior:

```text
Pause / quit / return toward main menu
→ campaign intro plays again
→ user cannot get past it
→ user must use Task Manager
```

This blocks clean live certification.

It also makes daily testing painful because every failed quit can trap the game in the intro replay path.

## Latest cert context

From the 2026-06-19 006I-3 session:

```text
Verdict: PARTIAL
Path A: PARTIAL PASS — screenshot showed TBG READY on campaign map
Path B: FAIL — Back/Escape from culture triggered cutscene
Path C: FAIL — quit required Task Manager
Layer A: INCONCLUSIVE from stale Launch.log
Layer B: PARTIAL from mixed screenshot/log evidence
```

Known stale fail evidence from prior logs:

```text
intro skip: campaign video via OnActivate (count=1)
intro skip: campaign video via CleanAndPushState (count=2)
Options -> Culture -> narrative restart
timeout: launcher window not found
```

006I-3 attempted to fix this by adding:

```text
_forwardIntroSkipDone
narrow CleanAndPushState blocking
live creation substage read
Complete / InitialState quit guard
Game.End counter reset
```

But Path C still needs live re-cert.

## Current working sprint posture

Until Path C is fixed, work should use a survival workflow.

Do not rely on quit-to-main-menu.

Recommended testing posture:

```text
Close Bannerlord completely before each cert run.
Use Forge.cmd for fresh bootstrap cert.
Use Task Manager only as emergency cleanup.
Avoid chaining multiple cert paths in the same running process unless the specific path requires it.
Treat every quit/restart attempt as potentially contaminated until logs prove otherwise.
```

## Sprint goal

Fix the quit-to-main-menu intro replay loop without regressing:

* Path A zero-click bootstrap to map
* 006H narrative auto-advance
* 006I forward intro skip count=1
* 006I-2 launcher handoff
* Path B culture Back behavior

The goal is not to create a new launcher architecture or broad intro system.

The goal is narrow:

```text
When the player quits from campaign/map/menu teardown, the mod must not replay or force the campaign intro.
```

## Suspected failure class

Likely issue family:

```text
Intro skip hooks still respond during teardown, quit, or main-menu transition.
The mod mistakes quit/menu cleanup for forward bootstrap.
The campaign intro skip path fires during a state change that is not the original new campaign launch.
```

Specific candidates to inspect:

```text
SandboxCampaignIntroSkip.cs
CampaignSetupStateTracker.cs
GameState.OnActivate patch
CleanAndPushState postfix
Game.End / GameStateManager teardown behavior
InitialState / main menu transition detection
Launch intent lifecycle
Bootstrap disarm timing
```

## Investigation checklist

Before coding, collect fresh logs after a re-cert attempt:

```powershell
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Phase1.log" -Tail 150
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Launch.log" -Tail 80
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Status.json" -Tail 100
```

Look for:

```text
intro skip:
CleanAndPushState
OnActivate
Game.End
InitialState
Complete
returned to main menu
campaign_intro
CharacterCreationCultureStage
Options
TBG READY
```

## Required logging if implementation is needed

If current logs are insufficient, add narrow diagnostic logging only.

Log every intro-skip decision with:

```text
hook=<OnActivate/CleanAndPushState>
state=<current game state type>
phase=<CampaignSetupStateTracker.Phase>
subStage=<current creation substage if any>
forwardDone=<true/false>
launchIntent=<play/continue/none>
isBootstrap=<true/false>
decision=<allow/block>
reason=<plain reason>
```

Desired log example:

```text
[TBG QUICKSTART] intro skip blocked: hook=CleanAndPushState state=InitialState phase=Complete forwardDone=true reason=quit/main-menu transition
```

## Guard doctrine

A safe guard should distinguish:

### Allowed

```text
Initial forward bootstrap campaign intro
Culture Back / Escape recovery if explicitly in culture stage
```

### Blocked

```text
After TBG READY
After Phase Complete
During InitialState
During Game.End
During quit-to-main-menu
During post-forward Options cleanup
When no active play launch intent exists
When forward intro skip already completed
```

## Acceptance criteria

006I-4 passes only if fresh evidence shows:

### Path A

```text
Forge.cmd
→ launcher handoff
→ OnActivate intro skip count=1
→ character creation advances
→ TBG READY
```

Required:

```text
handoff:
intro skip: campaign video via OnActivate (count=1)
TBG READY: campaign map ready
no CleanAndPushState count=2 before TBG READY
```

### Path B

```text
Culture stage
→ Back/Escape
→ no full cutscene replay
→ recover or return safely
```

Required:

```text
No full campaign_intro replay
No task-manager cleanup
No permanent stuck intro
```

### Path C

```text
Campaign map
→ pause
→ quit / return to menu
→ exits cleanly
```

Required:

```text
No campaign intro replay
No forced character creation restart
No Task Manager required
No endless video/cutscene trap
```

## Fail signatures

```text
intro skip: campaign video via CleanAndPushState (count=2) before TBG READY
campaign_intro after TBG READY
Options -> Culture after map reached
quit causes intro replay
quit requires Task Manager
launcher-auto-nav timed out
```

## Smallest next fix strategy

Do not rewrite.

Prefer the smallest guard that prevents intro skip hooks from firing outside the original forward bootstrap window.

Likely fix shape:

```text
Once TBG READY or Phase Complete occurs:
- disable all intro skip hooks
- clear forward launch state
- ignore CleanAndPushState and OnActivate intro triggers
- allow only a fresh Forge.cmd launch intent to re-arm bootstrap
```

If needed, add a named latch such as:

```text
_bootstrapIntroSkipArmed
```

But only if current flags are insufficient.

## Out of scope

Do not touch:

```text
005E economics
smithing
inventory
gold
orders
stamina automation
launcher rewrite
profile system
tutorial skip
Story Mode
module version bump
```

## Definition of done

```text
- This plan exists under docs/plans/
- NEXT_STEPS.md links to it as the likely next stabilization sprint if Path C remains failing
- 006I remains pending until re-cert passes
- 005E remains blocked
- No implementation code is changed by this planning commit
```
