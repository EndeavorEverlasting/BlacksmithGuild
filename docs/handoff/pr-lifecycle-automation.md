# Pull Request Lifecycle Automation

## Purpose

Routine pull-request lifecycle work belongs to the repo and its agents, not to repeated operator terminal handoffs.

The repository automatically:

1. inspects the current pull-request state;
2. inspects checks for the exact head;
3. distinguishes always-required, conditional-required, and advisory validation;
4. inspects review decisions and unresolved review threads;
5. promotes an eligible draft to ready for review;
6. requests or performs an exact-head squash merge when the deterministic merge gate passes;
7. writes machine-readable and English evidence for the decision.

The executable policy is:

```text
.tbg/workflows/pr-lifecycle-automation.contract.json
```

The controller is:

```text
scripts/tbg/Invoke-TbgPrLifecycle.ps1
```

The GitHub workflow is:

```text
.github/workflows/pr-lifecycle-automation.yml
```

## Default lifecycle rule

Agents and workflows must not ask the operator to run routine PR queries, readiness transitions, or eligible merges when the connected GitHub surface can perform them safely.

Automated actions include:

```text
check inspection
workflow conclusion inspection
PR metadata refresh
review and review-thread inspection
ready-for-review promotion
exact-head squash merge
lifecycle result artifacts and reports
```

Human terminal interaction is not itself a safety gate. Concrete evidence failures are the gate.

## Required validation model

### Always-required workflows

These repo-owned platform-neutral workflows must be present and successful:

```text
Governor Contracts
Harness Policy Reports
```

### Conditional-required workflows

These platform-neutral workflows block when they run, but their absence must not deadlock a PR that does not match their path or scope filters:

```text
Hostile Escape Contracts
```

### Advisory workflows

Unlisted external checks and platform/game-backed workflows are reported but do not block automatic readiness or merge by default.

A draft PR is promoted when all always-required workflows pass and every conditional-required workflow that is present also passes.

An intentionally unfinished PR can remain draft by adding:

```text
pr-lifecycle:hold-draft
```

## Deterministic automatic merge gate

A ready PR may merge automatically without a separate operator command when all of the following are true:

```text
state = OPEN
isDraft = false
exact inspected head SHA is still current
always-required workflows are present and successful
present conditional-required workflows are successful
no pr-lifecycle:hold-merge label
mergeable = MERGEABLE
merge state is not DIRTY, DRAFT, UNKNOWN, or BEHIND
review decision is not REVIEW_REQUIRED or CHANGES_REQUESTED
all inspected review threads are resolved
review-thread pagination is complete
base is main, unless stacked merge is explicitly opted in
head is from the same repository, unless fork merge is explicitly opted in
PR is newer than the policy effective date, unless legacy merge is explicitly opted in
GitHub repository rules accept auto-merge or direct exact-head merge
```

The merge method is always:

```text
squash
```

The controller always supplies:

```text
--match-head-commit <inspected-head-sha>
```

This prevents a merge after a concurrent push changes the reviewed head.

The controller first requests GitHub auto-merge so branch protection, rulesets, and merge queues remain authoritative. If repository auto-merge is unavailable and GitHub reports a clean eligible state, it attempts a direct exact-head squash merge. GitHub may still reject the merge; that becomes `merge_blocked_by_github`, not a request for the operator to repeat the same command.

## Smart blockers and opt-ins

### Explicit holds

```text
pr-lifecycle:hold-draft
pr-lifecycle:hold-merge
```

### Legacy PR protection

PRs created before the policy effective date are not silently swept into automatic merge. After current evidence is reviewed, an old PR may opt in with:

```text
pr-lifecycle:auto-merge-legacy
```

### Stacked PR protection

A PR targeting a branch other than `main` is blocked by default. An intentional stacked merge may opt in with:

```text
pr-lifecycle:auto-merge-stacked
```

### Fork protection

Cross-repository PRs are blocked from automatic merge by default. A deliberately trusted fork PR may opt in with:

```text
pr-lifecycle:auto-merge-fork
```

Labels are policy inputs, not substitutes for passing checks, clean mergeability, resolved reviews, or exact-head matching.

## Cross-platform development rule

BlacksmithGuild development must stay modular across operating systems.

Required readiness and merge evidence should come from platform-neutral surfaces whenever practical:

- contracts and schema validation;
- static tests;
- unit tests;
- cross-platform builds;
- policy and architecture verifiers;
- platform adapters tested independently from game installation.

Installed-game validation is useful but advisory by default, regardless of operating system.

This includes:

- Windows systems with Bannerlord installed;
- Linux systems capable of running Bannerlord;
- launcher handoff checks;
- live runtime checks;
- gameplay behavior observation;
- Windows PowerShell 5.1 compatibility checks that require a Windows runner.

A Windows runner is not the product architecture. A Linux game host is not the product architecture. Platform-specific runners are adapters and evidence producers around a modular core.

Therefore:

```text
platform-neutral validation = required readiness and merge evidence
installed-game or OS-specific validation = advisory evidence
```

Game-backed validation must live in a separately named advisory workflow. Do not place it in an always-required workflow whose overall completion controls automatic readiness or merge.

A path-scoped platform-neutral verifier may be conditional-required. It must block when present, while its absence remains a valid state for unrelated changes.

## Evidence and artifacts

Every lifecycle run writes:

```text
pr-lifecycle-result.json
```

Schema:

```text
TbgPrLifecycleResult.v2
```

The GitHub workflow uploads it as:

```text
pr-lifecycle-<pr-number>-<workflow-run-id>
```

Retention is 14 days. The workflow step summary also records:

- PR number;
- exact head SHA;
- selected lifecycle action;
- required and advisory check counts;
- advisory failures or pending checks;
- unresolved review-thread count;
- merge attempt mode and GitHub result;
- English reason for the terminal state.

These artifacts distinguish evidence from confidence and prevent terminal scrollback from becoming the only record.

## Actions this automation never performs

The lifecycle workflow uses the trusted default-branch controller. It does not checkout or execute untrusted PR-head code with its write-capable token.

It never:

```text
closes a PR without a separate closure disposition
deletes a branch
commits or pushes source changes
force-pushes
rewrites history
merges a head other than the inspected exact head
uses an administrative branch-protection bypass
claims launcher, gameplay, or runtime proof
```

A scoped sprint that authorizes code changes still owns its commit and push obligation. This lifecycle controller owns PR state and eligible merge, not implementation.

## Local dry-run validation

Cross-platform PowerShell 7 validation:

```powershell
pwsh -NoProfile -File scripts/tbg/Test-TbgPrLifecycleAutomation.ps1
pwsh -NoProfile -File scripts/tbg/Verify-TbgPrLifecycleAutomation.ps1
```

Optional Windows PowerShell 5.1 compatibility validation:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\tbg\Test-TbgPrLifecycleAutomation.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\tbg\Verify-TbgPrLifecycleAutomation.ps1
```

Inspect a real PR without changing its state:

```powershell
pwsh -NoProfile -File scripts/tbg/Invoke-TbgPrLifecycle.ps1 `
  -PrNumber 53 `
  -Repository EndeavorEverlasting/BlacksmithGuild `
  -DryRun
```

## Safe parallel work

Parallel-safe lanes after this workflow lands:

- advisory Windows game-backed validation workflow;
- advisory Linux game-backed validation workflow;
- branch-protection and ruleset alignment;
- stale-PR classification and explicit legacy opt-ins;
- PR closure disposition automation as a separate policy.

Collision risks:

- edits to `.github/workflows/pr-lifecycle-automation.yml`;
- edits to `.tbg/workflows/pr-lifecycle-automation.contract.json`;
- edits to `scripts/tbg/Invoke-TbgPrLifecycle.ps1`;
- changing workflow names without updating the contract and regression fixtures.

## Next inspection paths

```text
.github/workflows/pr-lifecycle-automation.yml
.github/workflows/governor-contracts.yml
.tbg/workflows/pr-lifecycle-automation.contract.json
scripts/tbg/Invoke-TbgPrLifecycle.ps1
scripts/tbg/Test-TbgPrLifecycleAutomation.ps1
scripts/tbg/Verify-TbgPrLifecycleAutomation.ps1
docs/handoff/pr-lifecycle-automation.md
```

## Proof boundary

Automatic merge proves that the configured platform-neutral checks, mergeability, review state, review threads, exact-head guard, and GitHub repository rules accepted the merge.

It does not prove:

- an installed-game run;
- launcher handoff;
- campaign readiness;
- command acknowledgement;
- movement, arrival, trade, or gameplay behavior;
- live runtime success.
