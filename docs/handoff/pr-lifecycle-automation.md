# Pull Request Lifecycle Automation

## Purpose

Routine pull-request lifecycle work belongs to the repo and its agents, not to repeated operator terminal handoffs.

The repository should automatically:

1. inspect the current pull-request state;
2. inspect current checks for the exact head;
3. distinguish required platform-neutral validation from advisory platform/game validation;
4. mark an eligible draft pull request ready for review;
5. report what happened without merging or closing anything.

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

Agents and workflows must not ask the operator to run routine read-only or reversible commands when the connected GitHub surface can perform them.

Examples that should be automated:

```text
check inspection
workflow conclusion inspection
PR metadata refresh
ready-for-review promotion
review-state reporting
```

The automatic ready gate uses these repo-owned platform-neutral workflows:

```text
Governor Contracts
Harness Policy Reports
Hostile Escape Contracts
```

A draft PR is promoted when all three workflows have reported successful or skipped checks for the current head.

An intentionally unfinished PR can remain draft by adding:

```text
pr-lifecycle:hold-draft
```

The hold label is an explicit opt-out. Absence of the label means the repo may promote the PR automatically when the required workflows pass.

## Cross-platform development rule

BlacksmithGuild development must stay modular across operating systems.

Required readiness and merge-policy evidence should come from platform-neutral surfaces whenever practical:

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
platform-neutral validation = required readiness evidence
installed-game or OS-specific validation = advisory evidence
```

Game-backed validation must live in a separately named advisory workflow. Do not place it in a required workflow whose overall completion controls automatic readiness.

## Actions this automation never performs

The lifecycle workflow has read-only repository-content permission and pull-request write permission only.

It never:

```text
merges a PR
closes a PR
deletes a branch
commits or pushes source changes
force-pushes
rewrites history
runs untrusted PR code with a write-capable token
claims launcher, gameplay, or runtime proof
```

Merges, closure, force operations, branch deletion, and unrelated repository mutation remain explicit terminal decisions.

A scoped sprint that already authorizes code changes still owns its normal commit and push obligation. The lifecycle automation does not replace implementation work and does not invent unrelated write authority.

## Local dry-run validation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tbg\Test-TbgPrLifecycleAutomation.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tbg\Verify-TbgPrLifecycleAutomation.ps1
```

Inspect a real PR without changing its state:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tbg\Invoke-TbgPrLifecycle.ps1 `
  -PrNumber 52 `
  -Repository EndeavorEverlasting/BlacksmithGuild `
  -DryRun
```

The controller writes `TbgPrLifecycleResult.v1` JSON and records required checks, advisory checks, missing workflows, and the selected lifecycle action.

## Proof boundary

Automatic promotion proves only that the configured platform-neutral workflows passed and that the PR state was updated.

It does not prove:

- every branch-protection requirement;
- an installed-game run;
- launcher handoff;
- campaign readiness;
- command acknowledgement;
- movement, arrival, trade, or gameplay behavior;
- live runtime success.
