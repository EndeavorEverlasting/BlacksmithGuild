# Source Tree Agent Rules

```text
[TBG | Source Rules | scope: src]
```

## Purpose

Source edits affect the mod. Treat this tree as higher risk than docs or harness policy.

## Rules

- Prefer symbol-aware lookup before editing C#.
- Identify class, method, and call-site targets before changing behavior.
- Keep runtime behavior changes out of MCP/harness infrastructure sprints.
- Do not mix gameplay changes with harness/tooling changes.
- Any runtime-facing change needs build evidence and, when applicable, game evidence.

## Before editing source

Name:

- target class or service
- target method or field
- expected behavior change
- tests or runtime proof required

## Forbidden in harness-only sprints

- command inbox behavior changes
- hotkey behavior changes
- save/game mutation changes
- launcher automation changes
- gameplay economy changes
