# MCP/LSP Symbol Smoke Setup

```text
[TBG | Sprint 037B | MCP/LSP Symbol Smoke Setup | branch: sprint/037b-mcp-symbol-smoke]
```

## Purpose

Sprint 037B proves read-only C# symbol navigation through an MCP bridge backed by a C# language server.

This is code-intelligence work only. It must not launch Bannerlord, run `ForgeReboot.cmd`, click the launcher, write command inbox files, mutate saves, or change runtime behavior.

## Repo smoke command

Run from repo root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\mcp\Test-TbgMcpReadiness.ps1 -ContractId "mcp-symbol-smoke"
powershell -ExecutionPolicy Bypass -File scripts\mcp\Test-TbgMcpSymbolSmoke.ps1 -ContractId "mcp-symbol-smoke"
```

Expected output artifact:

```text
artifacts/latest/mcp-symbol-smoke.result.json
```

## Local tool setup

The current repo smoke knows how to use the `csharp-lsp-mcp` command. It checks `PATH` first, then the ignored local tool folder:

```text
.local/mcp-tools
```

Local install path:

```powershell
New-Item -ItemType Directory -Force .local\mcp-tools
dotnet tool install csharplspmcp --tool-path .local\mcp-tools
dotnet tool install csharp-ls --tool-path .local\mcp-tools
```

The MCP bridge starts, lists C# tools, and then calls `csharp_set_workspace`. If `csharp-ls` is missing or cannot start, the smoke must return `lsp_project_not_loaded`.

## Terminal states

The artifact must use one of these states for the overall verdict and for each query:

```text
mcp_tool_missing
lsp_project_not_loaded
symbol_not_found
symbol_navigation_ready
```

`symbol_navigation_ready` is only allowed after MCP tool calls return usable responses for every required query.

## Required questions

```text
Where is MapTradeAutonomousService defined?
Where is StartRouteNow defined?
Who calls StartRouteNow?
Where is CampaignMapReadyOrchestrator defined?
Where is _activeReport assigned, read, and cleared?
Where are hotkeys registered?
Where is command inbox parsing handled?
```

## Observed local caveat

On the initial 037B validation machine, `csharplspmcp` installed into `.local/mcp-tools` and exposed `csharp-lsp-mcp.exe`, but `csharp-ls` failed to install as a dotnet tool with a missing `DotnetToolSettings.xml` package metadata error. In that state, the correct smoke verdict is `lsp_project_not_loaded`, not `symbol_navigation_ready`.
