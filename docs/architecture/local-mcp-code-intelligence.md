# Local MCP Code Intelligence

```text
[TBG | Sprint 037A/037B | MCP Code Intelligence | branch: sprint/037a-local-agent-harness]
```

## Purpose

MCP gives coding agents a tool surface for local context. For this repo, the first approved use case is symbol-aware code navigation through an LSP-backed MCP server.

## Doctrine

MCP is sight, not hands.

Use it for:

- go to definition
- find references
- diagnostics
- bounded repo context
- workflow contract lookup
- latest artifact lookup

Do not use Sprint 037A MCP surfaces for:

- game launch
- launcher clicks
- command inbox writes
- save mutation
- build/install/runtime proof

## Phases

| Sprint | Scope | Verdict |
|---|---|---|
| 037A | Harness, policies, examples, stubs | Scaffold only |
| 037B | LSP/MCP readiness and symbol smoke | Prove code intelligence |
| 037C | TBG domain MCP read-only server | Expose contracts, artifacts, logs |
| Later | Gated action tools | Only after read-only tools prove useful |

## Symbol smoke targets

Sprint 037B should answer these without broad grep dumps:

- Where is `MapTradeAutonomousService` defined?
- Where is `StartRouteNow` defined?
- Who calls `StartRouteNow`?
- Where is `CampaignMapReadyOrchestrator` defined?
- Where is `_activeReport` assigned, read, and cleared?
- Where are hotkeys registered?
- Where are command inbox commands parsed?

## Expected artifacts

```text
artifacts/latest/mcp-readiness.result.json
artifacts/latest/mcp-symbol-smoke.result.json
```

Failure states must be precise:

```text
mcp_tool_missing
lsp_project_not_loaded
symbol_not_found
mcp_symbol_navigation_ready
```

The difference matters. A missing tool is not a bad symbol. A bad symbol is not a failed project load. Mush loses.
