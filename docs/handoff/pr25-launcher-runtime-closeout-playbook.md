# PR 25 Launcher Runtime Closeout Playbook

## Purpose

PR 25 is not finished by a launcher click alone. The closeout proof must show the full handoff from the launcher to a live campaign runtime surface, then at least one real in-game command path that is consumed by the mod.

This document preserves the runtime lessons from the PR 25 proof sprint so future agents do not rediscover the same failure modes.

## Required proof chain

A valid PR 25 proof should show:

1. `ForgeContinue.cmd` builds and installs when Bannerlord is not running.
2. Frozen launcher context selects the real launcher window.
3. CONTINUE click invalidates the frozen launcher target.
4. Post-invalidation handoff watch detects either Safe Mode or the game host.
5. Safe Mode is declined with the No path, preferably `Alt+N`.
6. Post-Safe-Mode handoff watch waits long enough for the same-process Singleplayer host.
7. Same-process Singleplayer host is treated as game spawned.
8. Post-handoff readiness observes the campaign map.
9. Runtime status comes from the Steam game root, not stale Documents install status.
10. A real in-game command is accepted and acknowledged by the mod.

## Same-process host rule

Bannerlord v1.4.6 can run Singleplayer under the launcher process:

```text
ProcessName: TaleWorlds.MountAndBlade.Launcher
WindowTitle: Mount and Blade II Bannerlord - Singleplayer PID: <pid> - Win64_Shipping_Client...
```

There may be no separate `Bannerlord.exe` process.

Therefore, launcher proof code must not rely only on:

```powershell
Get-Process -Name 'Bannerlord'
```

`Test-GameSpawned` must also accept the Singleplayer title on `TaleWorlds.MountAndBlade.Launcher`.

## Already-running game rule

`ForgeContinue.cmd` should not try to click CONTINUE against an already-running Singleplayer game window.

If the frozen target title is already Singleplayer, classify it directly:

```text
LAUNCH_STATE=already_running_game
classification=already_running_game
reason=continue_target_is_live_singleplayer_host
```

Then stop with operator action:

```text
Bannerlord Singleplayer is already running; close it before ForgeContinue.
```

This is not a launcher failure. It is a preflight state mismatch.

## Safe Mode handoff timing

A 15 second post-Safe-Mode decline watch can be too short. The observed failure was:

```text
CLICK_SAFE_MODE_RESULT result=decline_dispatched method=alt_n
LAUNCH_STATE=post_safe_mode_decline_handoff_watch waiting_for=game_spawned budgetMs=15000
CLICK_VERIFY_RESULT postSafeModeDeclineResult=game_not_spawned
operator_action_required reason=safe_mode_declined_but_game_not_spawned
```

The game continued loading after that window. A better closeout target is a 60 second bounded handoff watch:

```text
safeModeDeclineHandoffBudgetMs = 60000
```

This remains bounded, but gives the same-process host enough time to transition to Singleplayer.

## Runtime truth locations

The Steam game root is the runtime truth source:

```text
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord
```

Important runtime files:

```text
BlacksmithGuild_Launch.log
BlacksmithGuild_Phase1.log
BlacksmithGuild_Status.json
BlacksmithGuild_RuntimeLifecycle.json
BlacksmithGuild_RuntimeRegent.json
BlacksmithGuild_CommandAck.json
BlacksmithGuild_CommandSurface.json
```

The Documents status file can show install workflow status and may be stale for runtime proof:

```text
C:\Users\Cheex\Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Status.json
```

Do not use Documents status as authoritative runtime evidence unless the specific proof is about install status.

## Evidence collection rule

Evidence collectors must tolerate locked JSON files while the game is running. Do not abort the whole evidence bundle because one file is temporarily locked.

Recommended behavior:

1. Try to read the file.
2. Retry briefly.
3. If still locked, write `LOCKED: <path>` into the bundle.
4. Continue collecting the rest of the files.

## Runtime command proof rule

Command acknowledgement proves command consumption. It does not prove gameplay execution.

For PR 25, an acceptable runtime command proof should include:

```text
Command inbox written
Command ack returned Success
Status shows campaignReady=true
Session canPollFileInbox=true
Session canAcceptAssistiveCommand=true
LastCommand shows the command name and sequence
```

For travel automation specifically, command ack is not enough. Route assignment is a checkpoint, not terminal movement proof. See `auto-travel-clock-resume-doctrine.md` for the route-owned clock resume doctrine.

## Validation gates before commit

Before committing launcher fixes, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-launcher-safe-mode-doctrine.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-launcher-window-context-contract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-powershell-utf8-bom-contract.ps1
git diff --check
git status --short
```

Do not stage `artifacts/` unless evidence files are intentionally being committed.

## Merge bar

The closeout commit should not be merged until the proof chain shows:

1. Safe Mode decline dispatch worked.
2. Same-process Singleplayer host was recognized as game spawned.
3. Campaign map readiness was observed after launcher handoff.
4. Runtime command surface accepted and acknowledged at least one real in-game command.
5. Already-running Singleplayer is classified cleanly instead of mis-clicked as launcher CONTINUE.
