# Agent Orchestration Map

## Purpose

This page preserves the orchestration diagram that prompted the Blacksmith Guild workflow-contract work.

The map shows a multi-agent development flow:

```text
Exploration agents
  Explore agent 1
  Explore agent 2
  Explore agent 3
        |
        v
Plan
  writes plan.md
        |
        v
Implement
  writes report.md
        |
        v
Code review agents
  Review agent 1 - security
  Review agent 2 - correctness
  Review agent 3 - simplify
        |
        v
Done
  Open PR
```

The framing text from the image is:

```text
Orchestrating coding agent sessions
Orchestrating many focused coding agents together to accomplish a larger task
The AI Layer shapes every session - rules, skills, hooks, sub-agents apply throughout
```

## Blacksmith Guild interpretation

For this repo, the map means:

```text
Exploration = inspect repo state, runtime artifacts, and prior PRs without patching blindly.
Plan = write a repo-owned plan or workflow contract.
Implement = patch the exact blocker, not a generic validator ritual.
Review = split security/correctness/simplification review lanes.
Done = open or update a PR with product-shaped acceptance criteria.
```

## Guardrail consequence

This map is why the repo now needs:

```text
AGENTS.md root coordination rules
docs/architecture/agent-workflow-contracts.md
docs/architecture/local-worktree-sprint-contract.md
docs/handoff/runtime-stop-guardrails.md
docs/architecture/campaign-activity-ledger.md
.tbg/workflows/*.contract.json
scripts/tbg/* preflight and verifier scripts
```

The key product doctrine is:

```text
The repo owns the loop.
The AI handles uncertainty.
The user should see behavior.
```

## Original image payload

The exact uploaded screenshot is stored as a base64 payload in:

```text
docs/assets/agent-orchestration-map.png.base64
```

Decode it with:

```powershell
$bytes = [Convert]::FromBase64String((Get-Content -LiteralPath "docs\assets\agent-orchestration-map.png.base64" -Raw))
[IO.File]::WriteAllBytes("docs\assets\agent-orchestration-map.png", $bytes)
```

A future local commit can replace the base64 payload with a normal binary PNG if the active toolchain supports binary file writes.
