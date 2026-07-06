# Orchestration Map Guardrails

## Purpose

The orchestration map is not a decorative screenshot.

It is the repo-owned model for how larger Blacksmith Guild development work should be split, planned, implemented, reviewed, and opened as a PR.

## Canonical files

```text
docs/architecture/agent-orchestration-map.md
docs/assets/agent-orchestration-map.mmd
docs/assets/agent-orchestration-map.mir.json
docs/assets/agent-orchestration-map.svg
```

## Source of truth order

1. Mermaid diagram: editable source of truth.
2. MIR JSON: machine-readable representation.
3. SVG: presentation-layer rendering.
4. Markdown page: explanation and repo interpretation.

## Required flow

```text
Explore agent 1, 2, and 3
Plan - writes plan.md
Implement - writes report.md
Review agent 1 - security
Review agent 2 - correctness
Review agent 3 - simplify
Done - Open PR
```

## Required artifacts

The diagram must continue to represent these handoff artifacts:

```text
plan.md
report.md
Open PR
```

## Blacksmith Guild interpretation

```text
Exploration = inspect repo state, runtime artifacts, and prior PRs without patching blindly.
Plan = write a repo-owned plan or workflow contract.
Implement = patch the exact blocker, not a generic validator ritual.
Review = split security, correctness, and simplification review lanes.
Done = open or update a PR with product-shaped acceptance criteria.
```

## Change rule

If the orchestration model changes, update all of these together:

```text
docs/assets/agent-orchestration-map.mmd
docs/assets/agent-orchestration-map.mir.json
docs/assets/agent-orchestration-map.svg
docs/architecture/agent-orchestration-map.md
scripts/tbg/Verify-TbgWorktreeStopGuardrails.ps1
```

Do not update only the screenshot or SVG.

Do not leave changes to this model in chat.

Do not make the diagram impossible to edit. Mermaid remains the canonical form.
