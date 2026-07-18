# Agentic Toolchain Sprint Map

```text
[TBG | Agentic Operations Adoption | PR #45 | branch: docs/agent-skills-stale-pr-cherry-pick]
```

## Context

- Repo: `EndeavorEverlasting/BlacksmithGuild`
- Owned scope: agent rules, skills, workflow contracts, architecture, handoff, PR/toolchain adoption order
- Forbidden scope: runtime source edits, Bannerlord launch, ForgeReboot, command inbox/save mutation, gameplay claims, destructive cleanup, external tool installation
- Current-truth sources: GitHub PR metadata, files committed on the PR #45 branch, merged PR #46 relay state
- Stale-but-useful sources: operator-supplied external-tool descriptions and historic worktree/artifact snapshots
- Risk: external tool behavior and local worktree state must be reverified before installation, release, or deletion

## Rewarding sprint decision

The next high-value implementation sprint is the **Agentic Runtime Closeout Harness**, not another repository map.

It should combine three maintained seams:

1. PR #46's compact local status relay;
2. PR #45's skill, compendium, and agent-operations contracts;
3. PR #43's exact-head unattended route proof target.

The result should be a TBG AXI command that can state repo/PR/worktree/proof status, run the bounded proof workflow, emit compact evidence, and identify the next stale stack without requiring the operator to paste long terminal transcripts or manually certify routine steps.

## Current PR actions

| PR | Role | Action |
|---|---|---|
| #43 | route/operator-control runtime lane | Finish through exact-head unattended proof; merge when its required proof level passes. |
| #44 | remote-evidence repo-floor map | Preserve any unique inventory, then supersede/close if PR #45 and current status tooling cover it. Do not keep a redundant map open indefinitely. |
| #45 | agent rules, skills, compendium, and operations doctrine | Merge after JSON/static/check validation; this is the maintained doctrine lane. |
| #46 | local agent status relay | Merged; use as the compatibility foundation for TBG AXI. |
| #5-#38 legacy set | stale and stacked mixed-value work | Classify, replay selected value onto current main, validate, then close with replacement or rejection rationale. |

## Implementation sequence

### 1. Close the doctrine lane

- Parse every `.tbg` JSON file.
- Run `git diff --check origin/main...HEAD`.
- Verify PR #45 checks.
- Merge PR #45 when green.

### 2. Close the current runtime lane

- Run the exact-head route proof through the authorized harness.
- Verify built/installed/loaded assembly identity.
- Require fresh command correlation and numeric movement evidence.
- Verify Manual/hold cleanup.
- Merge PR #43 when its declared proof boundary passes.

### 3. Implement TBG AXI

- Retain `ForgeAgentStatus.cmd` compatibility.
- Add `status`, `prs`, `worktrees`, `packet`, `proof`, and `next`.
- Default to bounded fields and stable exit codes.
- Include proof level, freshness, and one next command.

### 4. Adopt external operations in inspection mode

- Verify Firstmate and Treehouse upstream outside BlacksmithGuild.
- Allocate one read-only or docs-only worktree lease.
- Confirm the coordinator reads `AGENTS.md`, one narrow skill, one workflow contract, and the compact packet.
- Do not vendor the tool or use the pilot to claim runtime proof.

### 5. Replay one stale stack

- Start with the worker/governor handoff or agent-feedback/guardrail stack because it directly improves engine cohesion and agent-verifiable closeout.
- Inventory every unique commit, hunk, test, doc, and artifact reference.
- Replay narrowly onto current `main`.
- Validate and close the source PRs with provenance.

## Worktree lease migration

| Lease | Required retention decision |
|---|---|
| route/operator proof | keep through exact-head proof and PR merge |
| docs/skills | release after PR #45 merge and clean status |
| relay/support | release after merged #46 state is present on main |
| stale replay | release after provenance and old-PR disposition |
| launcher evidence | archive with manifest, size, head, restore path, and reason before release |

## Validation for this map

```powershell
Get-ChildItem .tbg -Recurse -File -Filter *.json | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json | Out-Null }
git diff --check origin/main...HEAD
git status --short
gh pr checks 45 --repo EndeavorEverlasting/BlacksmithGuild
```

## Exact next command

```powershell
Set-Location "C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild"; git fetch origin; gh pr checkout 45; Get-ChildItem .tbg -Recurse -File -Filter *.json | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json | Out-Null }; git diff --check origin/main...HEAD; gh pr checks 45 --repo EndeavorEverlasting/BlacksmithGuild
```
