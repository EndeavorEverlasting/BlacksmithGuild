# Skill: stale-pr-cherry-pick

Use this skill when recovering useful work from stale, conflicted, superseded, or stacked PRs.

This skill exists because stale PRs are often valuable. They may contain useful tests, docs, contracts, evidence references, or focused source changes even when the original branch is no longer safe to merge.

## Use when

- A PR is old, behind, conflicted, or partly superseded.
- A branch has useful commits but the base is stale.
- A previous map says `replay`, `salvage`, `selectively port`, or `reconstruct from current main`.
- The repo needs a replacement PR instead of blind delete/squash.
- The operator needs to know whether the stale-branch recovery program is actually finished.

## Do not use when

- The PR is current, clean, and intentionally stacked on an active foundation.
- The sprint owns live runtime proof.
- The operator explicitly ordered branch or PR deletion after proof.
- You are trying to use the stale PR head as a general base.

## Read first

1. `AGENTS.md`
2. `.tbg/workflows/stale-pr-cherry-pick.contract.json`
3. `.tbg/workflows/stale-pr-recovery-automation.contract.json`
4. `.tbg/plans/stale-pr-recovery-20260712/manifest.json`
5. `.tbg/plans/stale-pr-recovery-20260712/progress.json`
6. `docs/handoff/stale-pr-cherry-pick-progress.md`
7. `docs/handoff/20260712-post-pr59-repo-floor-map.md`
8. The source PR body, changed files, commits, and checks.
9. Any current workflow contract that now owns the same behavior.

## Operator status surface

Run:

```powershell
.\ForgeStalePrProgress.cmd status
```

The tracked dashboard is:

```text
docs/handoff/stale-pr-cherry-pick-progress.md
```

The canonical machine-readable state is:

```text
.tbg/plans/stale-pr-recovery-20260712/progress.json
```

The process is not complete merely because replacement PRs exist. The dashboard may report `COMPLETE` only when every planned source PR has a terminal evidence-backed disposition.

## Owned scope

- PR classification.
- Commit and changed-path inventory.
- Unique value extraction.
- Replacement branch planning.
- Selective cherry-pick or hunk/path replay guidance.
- Validation and supersession notes.
- Per-PR progress-ledger updates.
- Generated Markdown progress reporting.
- Aggregate completion calculation.

## Forbidden scope

- Blind merge of stale PR heads.
- Blind squash of stale stacks.
- Blind PR, branch, worktree, or evidence deletion.
- Runtime proof claims from stale artifacts.
- Treating review-bot success as build, harness, or runtime proof.
- Collapsing proof levels while replaying old runtime code.
- Marking `replacement_pr_open` as complete.
- Recording a terminal status without a disposition and evidence.

## Cherry-pick approach

1. **Map the source.** Record PR number, head SHA, base, changed files, commits, checks, conflict state, and current overlap.
2. **Classify value.** Mark each item as keep, superseded, reject, or needs-owner-review.
3. **Pick a safe base.** Prefer current `origin/main` unless the active workflow contract names a current foundation branch.
4. **Replay narrowly.** Use `git cherry-pick -x <sha>` only for clean, coherent commits. Use path or hunk replay when only part of a stale commit remains valid.
5. **Preserve attribution.** Replacement PRs must reference the original PRs and commits that contributed value.
6. **Validate in current context.** Run targeted validators and `git diff --check`; run builds only when the lane requires them and runtime preconditions are safe.
7. **Record progress.** Update the source PR entry through `ForgeStalePrProgress.cmd set` after meaningful state changes.
8. **Supersede deliberately.** Close old PRs only after the replacement PR, rejection reason, or retention decision is recorded.
9. **Recheck the aggregate gate.** Run `ForgeStalePrProgress.cmd status` and inspect the Markdown dashboard before claiming the recovery program is complete.

## Progress statuses

Non-terminal statuses:

```text
not_started
replacement_pr_open
replay_in_progress
validation_pending
disposition_pending
blocked_dependency
blocked_runtime_proof
```

Terminal completion statuses:

```text
replayed_and_merged
superseded_recorded
rejected_recorded
historical_retained
```

A terminal update requires a written disposition and one or more evidence references.

## Done gate

A stale-PR recovery is complete only when:

- the source PR has a written classification;
- selected deltas are replayed onto a safe base or an exact blocker is recorded;
- stale evidence is preserved as history and not reused as new PASS;
- validation has run or skipped checks are named with exact later commands;
- the old PR disposition is recorded without destructive cleanup by assumption;
- the canonical progress ledger records a terminal evidence-backed status;
- the generated Markdown dashboard agrees with the ledger;
- the aggregate dashboard reports `COMPLETE` only after every planned source PR is terminal.

## Validation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tbg\Test-TbgStalePrRecovery.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tbg\Test-TbgStalePrRecoveryProgress.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-powershell-utf8-bom-contract.ps1
git diff --check
```

## Common traps

- `CLEAN` or `MERGEABLE` does not mean dependency-complete.
- A stale runtime artifact may explain history but cannot prove the current branch.
- A branch name matching an old feature does not prove it contains the latest safe implementation.
- Review-bot green is not mod build proof.
- Route start is not movement, arrival, trade, or visible UI proof.
- An open replacement PR is progress, not completion.
- Closing a source PR without recording the disposition does not satisfy the recovery gate.
