# Repo Hygiene Execution Sprint

## Purpose

This runbook turns repo-floor hygiene from a report-only activity into a bounded repository change that can be validated, committed, pushed, and reviewed without crossing into feature or runtime work.

## Context resolution

When a hygiene request contains a blank, stale, or placeholder repo path, sprint name, scope, or plan path, resolve the missing value from repository evidence instead of stopping immediately.

Use this precedence order:

1. Explicit repository and branch named in the current handoff.
2. Current checkout remote, branch, and recent commits.
3. Open pull requests and their base/head relationships.
4. Existing repo-floor maps and handoff documents.
5. The default branch as the safe base for a new isolated hygiene branch.

Record any inferred value in the final sprint summary. Do not infer runtime success, gameplay state, or evidence disposability.

## Minimum safe preflight

Run only enough preflight to avoid damaging existing work:

```powershell
git status --short
git branch --show-current
git log --oneline --decorate -5
```

If the current worktree is dirty or conflicted and the hygiene sprint does not clearly own those files, create a sibling worktree from the selected safe base. Do not reset, abort, clean, or overwrite the primary checkout merely to obtain a clean status.

## Required repository movement

After preflight, perform one of these actions:

1. Add or improve a tracked hygiene contract, validator, sprint map, cleanup ledger, or handoff document.
2. Prove that the requested hygiene behavior is already present in committed files and that its checks pass.
3. Stop at an exact access or safety blocker and provide the smallest applicable patch or file content.

Default to tracked repository movement. A plan-only response is not completion when write access and safe scope are available.

## Owned change types

- Repo, PR, branch, and worktree inventory contracts.
- Safe-base and sibling-worktree decision rules.
- Cleanup candidate ledgers that distinguish candidates from approved deletions.
- Static validators for hygiene documents, manifests, and contracts.
- Handoff documents that preserve exact blockers and commands.
- Ignore-rule corrections for reproducible machine-local clutter, when evidence retention rules are unaffected.

## Forbidden change types

- Feature or gameplay implementation.
- Runtime source changes.
- Bannerlord launch or ForgeReboot execution.
- Command inbox or save mutation.
- Runtime or gameplay proof claims.
- Broad refactors.
- Branch, worktree, PR, artifact, or evidence deletion without reachability and retention proof.
- Converting real behavior into a stub to satisfy a check.

## Cleanup proof gates

A branch is a deletion candidate only when all of the following are true:

- it is not checked out in any worktree;
- its intended commits are reachable from the permanent target branch;
- it has no unique unpushed commits;
- it is not referenced as an active PR base or head;
- the exact branch name and proof command are recorded before deletion.

A generated or ignored path is a deletion candidate only when all of the following are true:

- it is reproducible;
- it contains no unique runtime evidence, crash evidence, or operator notes;
- its producer and regeneration command are known;
- its removal does not violate an evidence-retention contract.

Candidate classification is not deletion approval.

## Validation order

Run the strongest practical checks available in this order:

1. Targeted validator for the changed hygiene surface.
2. JSON or manifest parsing where applicable.
3. `git diff --check`.
4. Repository policy or documentation checks.
5. Build checks only when the changed files can affect build inputs.

For documentation-only hygiene changes, do not run Bannerlord, ForgeReboot, or gameplay validation. State the exact skipped command only when it would be relevant to a later implementation sprint.

## Commit and review contract

Before committing:

```powershell
git diff --check
git status --short
git diff --stat
git diff
```

Then stage only owned files, commit with a bounded message, push the hygiene branch, and open or update a pull request targeting the selected safe base.

The PR description must state:

- resolved repo, branch, sprint, and scope;
- files changed;
- validation run;
- checks intentionally skipped;
- cleanup candidates that were not deleted;
- remaining local-only verification gaps.

## Completion gate

The sprint is complete only when the final report contains one of:

- a commit SHA and pushed branch or PR;
- proof that the requested behavior already exists and passes checks;
- an exact blocker plus a smallest safe patch or file content.

A rewritten prompt, plan-only response, or next-agent handoff is not a completed execution sprint.
