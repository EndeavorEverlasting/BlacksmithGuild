# MCP Script Rules

```text
[TBG | MCP Script Rules | scope: scripts/mcp]
```

## Purpose

MCP scripts expose local code-intelligence and repo-context surfaces to agents.

## Rules

- Read-only first.
- Do not launch the game.
- Do not write command inbox files.
- Do not mutate saves.
- Do not claim live symbol navigation unless the MCP/LSP smoke test proves it.
- Distinguish `mcp_tool_missing`, `lsp_project_not_loaded`, `symbol_not_found`, and `symbol_navigation_ready`.

## Sprint split

- Sprint 037A: examples and stubs.
- Sprint 037B: live LSP/MCP symbol smoke.
- Sprint 037C: read-only TBG domain MCP server.

## Output paths

```text
artifacts/latest/mcp-readiness.result.json
artifacts/latest/mcp-symbol-smoke.result.json
```
