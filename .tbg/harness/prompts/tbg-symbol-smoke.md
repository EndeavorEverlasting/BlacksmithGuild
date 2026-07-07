# TBG MCP Symbol Smoke Prompt

```text
[TBG | Sprint 037B | MCP/LSP Symbol Smoke]
```

## Mission

Use MCP/LSP symbol-level navigation to answer targeted repo questions with definitions, references, and failure states.

The repo-owned smoke command is:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\mcp\Test-TbgMcpSymbolSmoke.ps1 -ContractId "mcp-symbol-smoke" -TimeoutSeconds 120
```

Do not replace the smoke with broad `rg` answers. Targeted source anchors may be used only to drive MCP/LSP requests. The artifact must show whether MCP tools were available, whether the C# LSP/project loaded, whether direct `csharp-ls` fallback was used, and what each symbol query returned.

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

Only claim live symbol navigation when every required query is `symbol_navigation_ready` in `artifacts/latest/mcp-symbol-smoke.result.json`. If direct LSP fallback supplied the proof, say so and keep the MCP bridge workspace state visible.

## Forbidden scope

No game launch. No ForgeReboot. No command inbox writes. No save mutation. No runtime automation.
