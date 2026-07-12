# Launcher Validation Workhorse

## Purpose

`Run-LauncherValidationWorkhorse.cmd` turns the recurring launcher test ritual into one repo-owned local workhorse. It synchronizes safely, runs the relevant launcher validators, stops stale Bannerlord processes through the repo-owned stop script, launches through the fast frontdoor, and writes both machine-readable evidence and a syntactic-English handoff.

The workhorse exists so an operator does not have to paste a long command chain, raw process output, launcher logs, and screenshots into every chat before an agent can understand what happened.

## Command

```powershell
.\Run-LauncherValidationWorkhorse.cmd
```

Optional validation-only run:

```powershell
.\Run-LauncherValidationWorkhorse.cmd -NoLaunch
```

Optional alternate PLAY run:

```powershell
.\Run-LauncherValidationWorkhorse.cmd -LaunchIntent play
```

## Safe synchronization and concurrent worktrees

Concurrent work in other worktrees and branches is expected and supported.

The workhorse operates only on the worktree from which it is launched. It:

1. verifies the current branch;
2. stops if the current worktree contains local changes;
3. fetches `origin --prune`;
4. compares the local sprint branch with its remote branch;
5. stops if local commits would be overwritten or the branch has diverged;
6. uses only `git merge --ff-only` when the local branch is safely behind.

It **does not reset or discard local work**. It does not run `git reset --hard`, `git clean`, force push, branch deletion, or PR merge. Other worktrees are not mutated.

## Workhorse sequence

```text
repo and branch check
-> local-change preservation gate
-> fetch and safe fast-forward
-> fast-frontdoor contract verifier
-> dependency-CAUTION doctrine verifier
-> clickable command surface verifier
-> process snapshot before stop
-> repo-owned force-stop step
-> process snapshot after stop
-> ForgeContinue.cmd or Forge.cmd
-> import launcher-frontdoor result
-> process snapshot after launch
-> terminal result and handoff
```

## Syntactic-English progress

Every important state is recorded as a complete English sentence rather than an isolated token or opaque status code.

Example:

```text
[2026-07-12T08:40:00.0000000Z] STARTED: The workhorse started fetching the remote repository and pruning stale remote references.
[2026-07-12T08:40:01.0000000Z] PASSED: The workhorse fetched the remote repository and pruned stale remote references successfully.
[2026-07-12T08:40:02.0000000Z] PASSED: The validator "scripts\verify-fast-launcher-frontdoor.ps1" passed.
[2026-07-12T08:40:10.0000000Z] INFO: The process snapshot found TaleWorlds.MountAndBlade.Launcher with process identifier 1234 and with the window title "M&B II: Bannerlord".
```

The same events are written as JSONL using schema:

```text
TbgSyntacticEnglishProgressEvent.v1
```

## Generated artifacts

Each run writes ignored local evidence beneath:

```text
artifacts/latest/launcher-validation-workhorse/<run-id>/
```

The run folder contains:

```text
progress.log
events.jsonl
handoff.md
result.json
steps/*.log
before-stop.processes.json
after-stop.processes.json
after-launch.processes.json
launcher-frontdoor.result.json when available
```

Stable latest pointers are also written:

```text
artifacts/latest/launcher-validation-workhorse.progress.log
artifacts/latest/launcher-validation-workhorse.handoff.md
artifacts/latest/launcher-validation-workhorse.result.json
```

The result schema is:

```text
TbgLauncherValidationWorkhorse.v1
```

## Handoff doctrine

The handoff is designed for the next local agent. It records:

- repository root;
- expected and observed branch;
- current commit;
- launch intent;
- terminal state and reason;
- duration;
- each command and validator result;
- process snapshots;
- launcher frontdoor evidence path;
- artifacts to inspect first;
- risks and proof boundaries;
- exact rerun command.

A launcher handoff does not prove movement or trading. It also does not prove campaign readiness, arrival, command acknowledgement, or live runtime success.

## Terminal states

Examples include:

```text
blocked_wrong_branch
blocked_dirty_worktree
blocked_local_commits
blocked_fast_forward
failed_static_validation
failed_force_stop
validation_only_complete
launcher_dead_end
launcher_handoff_observed
workhorse_exception
```

Each terminal state produces the progress log, JSONL event stream, result JSON, and English handoff before the process exits whenever possible.
