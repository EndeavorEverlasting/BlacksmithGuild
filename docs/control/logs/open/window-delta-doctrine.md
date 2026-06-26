# Window Delta Doctrine

This doctrine codifies the required launcher-selection method. It complements the Ortysia live cert landmark in [`docs/handoff/ortysia-live-cert-landmark.md`](../../handoff/ortysia-live-cert-landmark.md) — PID/window authority and movement PASS rules live there; this doc defines the S0–S3 snapshot model and candidate priority.

## Hard doctrine

- Do not start by globally crawling every window.
- First compare pre-launch and post-launch windows.
- Use the new or materially changed window as the primary launcher candidate.
- Global scan is fallback only.

## Snapshot model

```text
S0 = before Forge/build/deploy        # audit only
S1 = after build/deploy, pre-launch   # authoritative launch baseline
S2 = after launch request             # delta candidate source
S3 = after Play/Continue handoff      # survival/attach verification
```

## Critical rule

S1 -> S2 window delta is the primary launcher-selection method. S0 must not be used as the main delta baseline because build/deploy creates noise.

## Required artifacts

- `window-snapshot-S1-pre-launch.json`
- `window-snapshot-S2-post-launch.json`
- `window-delta-candidates.json`
- `chosen-launch-window.json`
- `launch-selection.json`

## Candidate priority

1. new HWND after S1
2. new PID after S1
3. process path contains Bannerlord / TaleWorlds / launcher
4. visible top-level window
5. stable rectangle for 2 polls
6. UIA contains Play or Continue
7. foreground or recently activated

## Penalize or block

- old unchanged windows from S1
- generic Steam chrome
- Safe Mode counted as Play/Continue menu
- title-only match
- coordinate-only guess
- multiple tied candidates
- low confidence

## Timer rule

Play/Continue timer starts only when Play/Continue menu is visible. It does not start on Safe Mode, blank launcher shell, generic launcher chrome, or Steam overlay.
