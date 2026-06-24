# PR #8 Cherry-Pick Bridge for F7 Agents

This document exists because PR #8 contains useful coordination ideas **and** dangerous script stubs. Agents must treat PR #8 as source material, not truth. Cherry-pick deliberately. No wholesale merge while the F7 gate is RED.

## Status of this bridge

This is a doc-only coordination bridge for the F7 recovery sprint. It does not certify PR #7 or PR #8. It exists to keep Agents A, B, and C from replacing working recovery code with Codex-generated stubs while still allowing safe salvage of good documentation, grep-guard, and coordination ideas.

Core rule:

```text
PR #8 is a parts bin. Do not install the painted cardboard engine.
```

## How agents must use this document

At the start of every PR #8 salvage sprint:

1. Read this file before touching code.
2. Identify your lane: A, B, or C.
3. Cherry-pick only the categories owned by your lane.
4. Reject stubs, reduced implementations, and any code that weakens evidence requirements.
5. Update the coordination doc before handing off.
6. Leave a clean repo state or explain every remaining modified/untracked file.

If PR #8 and PR #7 disagree, PR #7 live recovery behavior wins unless a manifest-backed failure proves otherwise.

## Current topology

| PR | Branch | Role | Merge posture |
|---|---|---|---|
| PR #7 | `fix/f7-gate-stability` -> `main` | Runtime F7 stabilization and live gate recovery | Do not merge until true F7 PASS manifest. |
| PR #8 | `codex/stabilize-f7-launch-tooling-and-open-pr` -> `main` | Codex tooling/docs overlay | Do not merge as-is. Salvage by cherry-pick or retarget into PR #7. |

## Why PR #8 is not safe wholesale

PR #8 adds good coordination material, but it also adds script files that can replace working recovery tooling with stubs. The key example is `scripts/run-f7-gate-continue.ps1`: PR #8 introduces it as a small wrapper that logs the hook mask and exits `0` even when it does not launch Continue, wait for map-ready, poll the stability window, or write a manifest.

That violates the core rule:

```text
No manifest, no medal.
Exit 0 without evidence is forgery.
```

## Cherry-pick policy

Agents may salvage PR #8 content only by category.

| Category | Default action | Owner | Notes |
|---|---|---|---|
| Coordination docs | Cherry-pick ideas, not stale tables | A/B | Preserve PR #7 live state and current agent board. |
| Launch/load playbook | Cherry-pick wording after owner review | B | Fix owner labels before accepting. Launcher failures are C; post-map-ready is B. |
| Em-dash convention | Cherry-pick if helper usage remains intact | B/C | Keep canonical ready line `Blacksmith Guild — Ready:`. |
| `verify-log-grep-patterns.ps1` | Salvage concept, expand scope before accepting | B | Must scan root wrappers plus `scripts/`. |
| `bannerlord-paths.ps1` helpers | Compare against PR #7 before accepting | B/C | Do not replace richer existing helpers with a smaller Codex version. |
| `write-launch-log.ps1` | Do not accept as-is | C | Must preserve caller `$ErrorActionPreference` and respect mutex acquisition. |
| `run-f7-gate-continue.ps1` | Do not accept as-is | C/A | Must be real gate or fail-closed nonzero. |
| `run-agent-a-f7-bisect.ps1` | Do not accept as-is | A/C | Default must be end-to-end, not silent `-SkipLaunch`. |
| Evidence summary JSON | Accept as summary only | A | Summary is not proof; manifests are proof. |
| `Run-F7GateContinue.cmd` | Do not promote until wrapper safety is proven | C | Direct PowerShell is primary until wrapper forwarding/encoding is validated. |

## Stub rejection checklist

Reject any PR #8 code if any answer is yes:

| Question | Reject if yes |
|---|---|
| Does it replace a richer PR #7 implementation with a smaller wrapper? | Yes. |
| Can it return exit `0` without writing or validating manifest evidence? | Yes. |
| Does it hide child command failures behind an overall success result? | Yes. |
| Does it require an already-running game unless the mode name says attach existing game? | Yes. |
| Does it mutate caller/global shell state when dot-sourced? | Yes. |
| Does it write shared logs without confirming lock ownership? | Yes. |
| Does it narrow grep/path handling compared to PR #7 helpers? | Yes. |
| Does it make docs say the wrapper is safe before Agent C proves it? | Yes. |

## Agent ownership while cherry-picking

### Agent A: gatekeeper / evidence

Agent A may cherry-pick:

- `docs/evidence/live-cert/f7-bisect-summary.json` concepts
- coordination doc message-log entries
- merge-gate language
- PR status tables

Agent A must reject:

- any exit `0` without a gate manifest
- any bisect summary that records child failures but returns overall success
- any evidence path that does not exist locally after pull
- any merge posture that treats PR #8 as F7 certification

Agent A next useful action after C/B land fixes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-f7-gate-continue.ps1 -HookMask 0x00 -TimeoutSeconds 120 -StableSeconds 10
```

Only run that after Agent C says the runner is real or fail-closed.

### Agent B: docs / grep / post-map-ready analysis

Agent B may cherry-pick:

- em-dash convention wording
- launch/load stage taxonomy
- docs pointers into control/coordination files
- grep guard concept
- PR #8 wording that clarifies PLAY vs CONTINUE

Agent B must fix before accepting:

- wrong ownership labels in playbook tables
- `TBG READY` shorthand presented as canonical current ready line
- verifier scope limited only to `scripts/`
- docs that say wrapper is safe while runner says direct PowerShell only
- stale PR #8 tables that overwrite PR #7 live state

Agent B owns the runtime interpretation after trustworthy evidence shows:

```text
MapReady / tbg_ready observed, then Bannerlord dies before 60s stability.
```

That is post-map-ready survival, not launcher automation.

### Agent C: runner / launcher scripts

Agent C may cherry-pick:

- wrapper argument ideas
- mutex/logging concepts
- command help strings
- fail-closed semantics

Agent C must not accept stubs.

Runner contract:

```text
exit 0 = real F7 PASS with manifest
exit 1 = build/launch/tooling failure
exit 2 = F7/game failure or timeout
```

**2026-06-22 status:** Real 723-line runner on `fix/f7-gate-stability` @ `2ad1d45`+; PR #8 16-line stub rejected. CONTINUE hwnd fix landed (hit-test `launcher_ok`, coord skip, 30s verify).

`run-f7-gate-continue.ps1` must either run the real gate or fail closed. No third option.

`write-launch-log.ps1` must:

- save and restore caller `$ErrorActionPreference`
- check `WaitOne()` before writing
- never release a mutex it did not acquire
- never corrupt the shared launch log during concurrent agents

`run-agent-a-f7-bisect.ps1` must:

- default to end-to-end launch per mask
- require explicit attach mode before `-SkipLaunch`
- return nonzero if any child mask fails
- write or reference per-mask manifests

## Safe merge strategies

### Preferred strategy

Retarget or stack PR #8 into PR #7:

```text
PR #8 -> fix/f7-gate-stability
PR #7 -> main only after F7 PASS
```

This keeps F7 tooling and docs in the recovery branch until the gate is stable.

### Acceptable strategy

Cherry-pick safe pieces from PR #8 into `fix/f7-gate-stability`, then close PR #8 as superseded.

### Avoid

Do not merge PR #8 directly into `main` while it contains runner/bisect stubs or unproven wrapper guidance.

## Required checks before any PR #8 content is accepted

```powershell
git status
git log -1 --oneline

dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release

powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-log-grep-patterns.ps1

powershell -NoProfile -Command "[scriptblock]::Create((Get-Content -Raw scripts\run-f7-gate-continue.ps1)) | Out-Null"
powershell -NoProfile -Command "[scriptblock]::Create((Get-Content -Raw scripts\run-agent-a-f7-bisect.ps1)) | Out-Null"
powershell -NoProfile -Command "[scriptblock]::Create((Get-Content -Raw scripts\write-launch-log.ps1)) | Out-Null"
```

If the runner is intentionally fail-closed, the parse check can pass while the smoke run exits `1`. That is acceptable. A fake `0` is not.

## Parallel work protocol

| Agent | May proceed while others work? | Constraint |
|---|---|---|
| A | Yes, as reviewer/gatekeeper | Do not run F7 until C clears runner safety. |
| B | Yes | Do not edit C-owned runner/logging scripts. |
| C | Yes | Do not edit B-owned docs except command snippets that describe changed behavior. |

Only one agent may hold the automation/game lock at a time. Do not run `ForgeContinue`, `Run-F7GateContinue`, `Run-LauncherNavNow`, or game-launching smoke tests while another lock is active.

## Final review checklist

Before marking PR #8 content safe, answer these:

| Question | Required answer |
|---|---|
| Can `run-f7-gate-continue.ps1` exit `0` without manifest? | No. |
| Does bisect default depend on a pre-existing game session? | No. |
| Does log writing mutate caller global state? | No. |
| Does mutex writing verify lock ownership? | Yes. |
| Does grep guard scan root wrappers? | Yes. |
| Do docs agree on direct PowerShell vs wrapper status? | Yes. |
| Does the coordination doc preserve PR #7 live state? | Yes. |
| Are evidence summaries treated as summaries, not proof? | Yes. |

## Suggested coordination message

```text
Agent <A/B/C> -> all:
Reviewed PR #8 through pr8-cherry-pick-bridge.md. Cherry-picked: <items>. Rejected: <items>. Runner status: <real gate / fail-closed / still unsafe>. Docs status: <aligned / still contradictory>. Evidence status: <manifest paths or none>. Next owner: <agent>.
```

## Judge rule

PR #8 is a parts bin. Do not install the painted cardboard engine.
