# Harness Script Rules

```text
[TBG | Harness Script Rules | scope: scripts/harness]
```

## Purpose

Harness scripts are the common API for hooks, MCP tools, and future local agents.

## Required result envelope

Result-producing scripts should emit:

```json
{
  "schema": "tbg.harness.result.v1",
  "action": "ActionName",
  "timestampUtc": "...",
  "repoRoot": "...",
  "branch": "...",
  "contractId": "...",
  "status": "ready|missing_prereqs|blocked_by_policy|repo_invalid",
  "verdict": "specific_machine_readable_verdict",
  "findings": [],
  "missingPrereqs": [],
  "forbiddenScopeTouched": false,
  "artifacts": []
}
```

## Rules

- Policies are source-of-truth.
- Hooks must call harness scripts instead of duplicating policy logic.
- Do not add runtime side effects here.
- Prefer specific verdicts over broad pass/fail.
- Distinguish missing tool, invalid repo, blocked command, and missing evidence.
