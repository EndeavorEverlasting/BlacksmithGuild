# TBG Local Agent Harness

## Context banner

```text
[TBG | Sprint 037A | Local Agent Harness Foundation | branch: sprint/037a-local-agent-harness]
```

This document codifies the local-agent harness for The Blacksmith Guild. The harness exists so future AI coding sessions can enter the repo, identify the current sprint, obey repo-specific boundaries, use MCP/LSP for code intelligence, and leave behind evidence without touching runtime surfaces by accident.

## Scope

Sprint 037A is infrastructure only.

Allowed:

- Harness contracts and policies under `.tbg/`.
- Readiness, policy, workflow, done-gate, and template scripts under `scripts/harness/`.
- Example MCP and hook configuration only.
- Documentation and handoff material.

Forbidden:

- Launching Bannerlord.
- Running `ForgeReboot.cmd`.
- Clicking or automating the launcher.
- Writing command inbox files.
- Mutating saves.
- Modifying gameplay behavior.
- Committing real local secrets, tokens, or personal machine config.

## Model

The harness is split into five layers.

| Layer | Role |
|---|---|
| Contracts | Define sprint scope, allowed changes, forbidden changes, validation commands, and required artifacts. |
| Policies | Decide command, file, runtime, and evidence safety. |
| Scripts | Enforce contracts and produce machine-readable evidence. |
| Adapters | Let Claude Code hooks, MCP clients, Cursor, and future agents call the same repo-native checks. |
| Reporting | Resolve one effective context and produce linked English and machine artifacts without duplicating policy claims. |

The repo harness is intentionally not tied to one AI client. Claude Code hooks, Cursor MCP config, and a future domain MCP server should all call the same PowerShell scripts and read the same JSON contracts.

## Doctrine

MCP is sight, not hands.

Use MCP/LSP to locate symbols, references, diagnostics, and repo context. Use existing repo scripts for build, install, and runtime proof. Runtime claims still require runtime artifacts.

The harness must make three things obvious:

1. What battlefield the agent is on.
2. What the agent is forbidden to touch.
3. What evidence proves completion.

## Result envelope

All result-producing scripts should write JSON with this shape:

```json
{
  "schema": "tbg.harness.result.v1",
  "action": "TestReadiness",
  "timestampUtc": "2026-07-06T00:00:00Z",
  "repoRoot": "C:\\repo\\BlacksmithGuild",
  "branch": "sprint/037a-local-agent-harness",
  "contractId": "local-mcp-code-intelligence",
  "status": "ready",
  "verdict": "harness_readiness_ready",
  "findings": [],
  "missingPrereqs": [],
  "forbiddenScopeTouched": false,
  "artifacts": [],
  "effectivePolicy": {},
  "englishSummary": "The readiness result is ready under the active effective policy."
}
```

`effectivePolicy` is resolved from executable contracts and policies; it is not a hand-written summary. Result scripts retain JSON on standard output for machine adapters and write an English-first Markdown companion. See `docs/architecture/effective-policy-english-reports.md` for the renderer, workspace decision, and handoff contracts.

## Readiness vs proof

Readiness evidence proves that the harness exists and can reason about the repo. It does not prove Bannerlord runtime behavior.

Runtime evidence still belongs to the existing game-facing proof loop.

## Reuse pattern

To emulate this harness in another app:

1. Copy the `.tbg/harness` pattern under an app-specific slug.
2. Copy `scripts/harness` and rename the prefix.
3. Define the app's protected files and forbidden runtime commands.
4. Define workflow contracts before any agent edits code.
5. Emit artifacts under `artifacts/latest` or an app-equivalent folder.

No magic. No fog machine. Just contracts, guards, and evidence.
