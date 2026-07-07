# TBG MCP Symbol Smoke Prompt

```text
[TBG | Sprint 037B | MCP/LSP Symbol Smoke]
```

## Mission

Use MCP/LSP symbol-level navigation to answer targeted repo questions with definitions, references, and failure states.

## Required targets

Answer:

```text
Where is MapTradeAutonomousService defined?
Where is StartRouteNow defined?
Who calls StartRouteNow?
Where is CampaignMapReadyOrchestrator defined?
Where is _activeReport assigned, read, and cleared?
Where are hotkeys registered?
Where is command inbox parsing handled?
```

## Required artifact

```text
artifacts/latest/mcp-symbol-smoke.result.json
```

## Required failure states

Use specific failure states:

```text
mcp_tool_missing
lsp_project_not_loaded
symbol_not_found
symbol_navigation_ready
```

Do not collapse these into vague failure.

## Forbidden scope

No game launch. No ForgeReboot. No command inbox writes. No save mutation. No runtime automation.
