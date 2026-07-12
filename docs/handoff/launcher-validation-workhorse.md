# Launcher Validation Workhorse

## Purpose

`Run-LauncherValidationWorkhorse.cmd` turns the recurring launcher test ritual into one repo-owned local workhorse. The root wrapper now starts a persistent supervisor, which selects a safe workspace mode and then runs the strict leaf workhorse.

The workhorse exists so an operator does not have to paste a long command chain, raw process output, launcher logs, screenshots, worktree state, and retry history into every chat before an agent can understand what happened.

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

Optional strategy overrides:

```powershell
.\Run-LauncherValidationWorkhorse.cmd -WorkspaceStrategy current-first
.\Run-LauncherValidationWorkhorse.cmd -WorkspaceStrategy remote-first
.\Run-LauncherValidationWorkhorse.cmd -WorkspaceStrategy local-snapshot
```

Default strategy:

```text
auto
```

## Multimodal persistence

The supervisor treats ordinary concurrency states as inputs to a bounded decision tree, not as automatic terminal failures.

The four workspace modes are:

| Mode | When it is used | What it protects |
|---|---|---|
| `current_synced` | Current worktree is on the expected branch, clean, and aligned with the remote branch, or can receive a safe fast-forward. | Fastest path with no extra worktree. |
| `current_local_commits` | Current worktree is clean and ahead of the remote branch with unpublished committed work. | Tests the local committed state without resetting, rebasing, or discarding it. |
| `isolated_remote` | Current worktree is dirty, on another branch, diverged, or otherwise unsafe for direct execution while the remote ref is available. | Preserves all current work and runs from a fresh sibling worktree at the remote sprint head. |
| `isolated_local_snapshot` | Remote fetch/ref is unavailable, isolated remote creation fails, or a final committed-state fallback is needed. | Runs from the current committed `HEAD` in a fresh sibling worktree without including uncommitted changes. |

### Dirty does not mean stop

A dirty source worktree is recorded, preserved, and bypassed. The supervisor creates an isolated remote worktree and continues there when possible.

### Unpublished commits do not mean stop

A clean worktree that is ahead of the remote branch enters `current_local_commits`. The supervisor runs the local committed state with synchronization disabled. It does not rewrite or push those commits.

### Divergence does not mean stop

A diverged branch triggers `isolated_remote`. The source worktree remains untouched while the supervisor runs the fetched or cached remote head in a sibling worktree.

### Wrong branch does not mean stop

Starting from `main`, another feature branch, or a coordination worktree triggers `isolated_remote` rather than a branch switch in the source worktree.

### Remote failure does not immediately mean stop

Fetch is attempted twice by default. If it still fails, the supervisor tries a cached `origin/<branch>` reference. If no usable remote reference exists, it retains `isolated_local_snapshot` as the final committed-state fallback.

### Isolated-worktree creation retries

Each isolated mode receives two creation attempts. After the first failure, the supervisor runs the safe metadata-only command:

```text
git worktree prune
```

It then tries a different sibling path. It does not remove an existing live worktree or delete a branch.

## Safe synchronization and concurrent worktrees

Concurrent work in other worktrees and branches is expected and supported.

The supervisor:

1. records the source branch, head, and dirty paths;
2. fetches `origin --prune` with bounded retries;
3. compares the source commit with the expected remote branch;
4. uses a safe fast-forward only when the current worktree is clean, correctly based, and behind without local commits;
5. otherwise adjusts to another workspace mode;
6. invokes the strict leaf workhorse inside the selected execution root;
7. changes modes again only for workspace-related blocked states;
8. stops on a clear semantic dead end after the launcher/frontdoor and leaf workhorse have exhausted their own bounded retries.

The supervisor and leaf workhorse **do not reset or discard local work**. They do not run `git reset --hard`, `git clean`, `git stash`, force push, save deletion, destructive branch deletion, or PR merge.

## Supervisor and leaf relationship

```text
Run-LauncherValidationWorkhorse.cmd
-> scripts/run-launcher-validation-supervisor.ps1
-> workspace mode selection
-> scripts/run-launcher-validation-workhorse.ps1
-> validators
-> process snapshots
-> repo-owned stop
-> ForgeContinue.cmd or Forge.cmd
-> launcher frontdoor evidence
-> leaf result and handoff
-> supervisor result and handoff
```

The strict leaf workhorse may still report states such as `blocked_dirty_worktree` or `blocked_local_commits`. Those states are no longer automatically terminal at the root command surface. The supervisor interprets them as recoverable workspace states and tries another safe mode.

Failures such as `failed_static_validation`, `failed_force_stop`, or `launcher_dead_end` are semantic failures rather than workspace selection problems. The supervisor preserves the evidence and ends clearly instead of rerunning the same broken behavior through every worktree.

## Workhorse sequence

```text
repo and branch inspection
-> bounded fetch retry
-> workspace candidate construction
-> current mode or sibling-worktree preparation
-> strict leaf workhorse
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
[2026-07-12T09:00:00.0000000Z] STARTED: The multimodal launcher-validation supervisor started and will adapt workspace modes instead of treating common concurrency states as terminal failures.
[2026-07-12T09:00:01.0000000Z] INFO: The supervisor found branch "main" at commit abc123 with 4 local status entries.
[2026-07-12T09:00:01.1000000Z] ADJUSTED: The supervisor selected workspace mode candidate "isolated_remote" because the source worktree has local changes, so the supervisor will preserve them and use an isolated remote worktree.
[2026-07-12T09:00:03.0000000Z] PASSED: The supervisor created an isolated worktree on a local worker branch.
```

The supervisor event schema is:

```text
TbgLauncherValidationSupervisorEvent.v1
```

The leaf event schema remains:

```text
TbgSyntacticEnglishProgressEvent.v1
```

## Generated artifacts

Supervisor artifacts:

```text
artifacts/latest/launcher-validation-supervisor/<run-id>/progress.log
artifacts/latest/launcher-validation-supervisor/<run-id>/events.jsonl
artifacts/latest/launcher-validation-supervisor/<run-id>/handoff.md
artifacts/latest/launcher-validation-supervisor/<run-id>/result.json
artifacts/latest/launcher-validation-supervisor/<run-id>/steps/*.log
artifacts/latest/launcher-validation-supervisor.progress.log
artifacts/latest/launcher-validation-supervisor.handoff.md
artifacts/latest/launcher-validation-supervisor.result.json
```

Supervisor result schema:

```text
TbgLauncherValidationSupervisor.v1
```

The result records:

- source worktree state;
- ahead/behind counts;
- fetch result;
- candidate order;
- each workspace mode attempted;
- isolated worktree path and local worker branch;
- leaf exit code and terminal state;
- selected mode;
- execution root and commit;
- artifacts and proof boundaries.

Leaf artifacts remain:

```text
artifacts/latest/launcher-validation-workhorse/<run-id>/progress.log
artifacts/latest/launcher-validation-workhorse/<run-id>/events.jsonl
artifacts/latest/launcher-validation-workhorse/<run-id>/handoff.md
artifacts/latest/launcher-validation-workhorse/<run-id>/result.json
artifacts/latest/launcher-validation-workhorse/<run-id>/steps/*.log
artifacts/latest/launcher-validation-workhorse.progress.log
artifacts/latest/launcher-validation-workhorse.handoff.md
artifacts/latest/launcher-validation-workhorse.result.json
```

Leaf result schema:

```text
TbgLauncherValidationWorkhorse.v1
```

When the leaf runs in an isolated worktree, the supervisor copies the stable leaf progress, result, and handoff into the supervisor run folder and records the isolated source paths.

## Terminal states

Supervisor examples:

```text
supervisor_complete
clear_semantic_dead_end
workspace_modes_exhausted
supervisor_exception
```

Leaf examples:

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

A launcher handoff does not prove movement or trading. It also does not prove campaign readiness, arrival, command acknowledgement, or live runtime success.
