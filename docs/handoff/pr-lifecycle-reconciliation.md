# PR Lifecycle Reconciliation Recovery

## Purpose

The PR lifecycle controller must not depend on one event delivery or an operator repeating `gh pr checks`, `gh pr ready`, or `gh pr merge`.

The merged recovery loop is:

```text
PR event or workflow completion
  -> trusted default-branch lifecycle workflow
  -> exact-head evidence inspection
  -> bounded lifecycle action
  -> per-PR JSON artifact
  -> scheduled sweep if an event was missed
```

## Recovery paths

### Scheduled sweep

Every ten minutes, the trusted lifecycle workflow enumerates all open pull requests and invokes the bounded controller for each one.

```text
scripts/tbg/Invoke-TbgPrLifecycleSweep.ps1
```

The sweep deduplicates PR numbers, preserves one result file per PR, and writes:

```text
pr-lifecycle-sweep-result.json
```

Schema:

```text
TbgPrLifecycleSweepResult.v1
```

### Immediate reconciliation comment

A PR comment containing exactly:

```text
/reconcile-pr-lifecycle
```

requests an immediate lifecycle pass for that PR. The comment is a trigger, not merge authorization. The normal exact-head, checks, review, conflict, base, age, fork, and hold blockers still apply.

### Workflow association fallback

When a completed workflow cannot be associated with one pull request, the lifecycle workflow performs an open-PR sweep instead of ending as a silent no-op.

## Control labels

The trusted workflow creates or refreshes these labels idempotently:

```text
pr-lifecycle:hold-draft
pr-lifecycle:hold-merge
pr-lifecycle:auto-merge-legacy
pr-lifecycle:auto-merge-stacked
pr-lifecycle:auto-merge-fork
```

Labels do not bypass required checks, exact-head matching, mergeability, reviews, or GitHub repository rules.

## Cross-platform boundary

Windows, Linux, and other installed-game hosts remain advisory evidence producers. The universal readiness and merge gate uses platform-neutral contracts, static tests, unit tests, builds where supported, and policy or architecture verifiers.

## Proof target

This documentation change is the canary for the merged recovery loop:

1. open the PR as draft;
2. let required platform-neutral workflows pass;
3. trigger `/reconcile-pr-lifecycle` without a manual readiness or merge command;
4. observe automatic draft promotion;
5. observe a second lifecycle pass exact-head squash merge the PR;
6. retain the lifecycle JSON artifact and PR timeline as evidence.

No Bannerlord launch, installed-game run, save mutation, branch deletion, force operation, or manual merge command belongs to this proof.
