# Agent Orchestration Map

## Purpose

This page preserves the orchestration diagram that prompted the Blacksmith Guild workflow-contract work.

Repo-renderable SVG version:

```text
docs/assets/agent-orchestration-map.svg
```

The SVG is a faithful repo-native recreation of the map from the uploaded screenshot, with the same flow and labels.

## Map flow

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

## Binary screenshot note

The uploaded screenshot itself was available in chat as a binary PNG. The GitHub connector path used for this PR supports UTF-8 file creation, so this PR commits a repo-native SVG recreation rather than the original binary PNG.

A future local commit from a normal git worktree can add the exact PNG asset directly if desired:

```text
docs/assets/agent-orchestration-map.png
```
