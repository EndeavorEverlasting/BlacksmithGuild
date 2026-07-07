# MCP/LSP Symbol Smoke Setup

```text
[TBG | Sprint 037B | MCP/LSP Symbol Smoke Setup | branch: sprint/037b-mcp-symbol-smoke]
```

## Purpose

Sprint 037B proves read-only C# symbol navigation through LSP-backed tooling. The preferred path is the `csharp-lsp-mcp` bridge. When that bridge is installed but cannot load the project, the smoke may use the repo-owned direct `csharp-ls` fallback so the artifact can distinguish bridge failure from LSP symbol readiness.

This is code-intelligence work only. It must not launch Bannerlord, run `ForgeReboot.cmd`, click the launcher, write command inbox files, mutate saves, or change runtime behavior.

## Repo smoke command

Run from repo root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\mcp\Test-TbgMcpReadiness.ps1 -ContractId "mcp-symbol-smoke"
powershell -ExecutionPolicy Bypass -File scripts\mcp\Test-TbgMcpSymbolSmoke.ps1 -ContractId "mcp-symbol-smoke" -TimeoutSeconds 120
```

Expected output artifact:

```text
artifacts/latest/mcp-symbol-smoke.result.json
```

## Local tool setup

The smoke checks `PATH` first, then the ignored local tool folder:

```text
.local/mcp-tools
```

Local install path:

```powershell
New-Item -ItemType Directory -Force .local\mcp-tools
dotnet tool install csharplspmcp --tool-path .local\mcp-tools
dotnet tool install csharp-ls --tool-path .local\mcp-tools
```

Global `csharp-ls` also works:

```powershell
dotnet tool install --global csharp-ls
```

## Workspace path

The MCP bridge is tried with ordered workspace candidates:

```text
src\BlacksmithGuild
repo root
```

If both fail, `scripts/mcp/Invoke-TbgCsharpLsSymbolSmoke.js` starts `csharp-ls` directly in `src\BlacksmithGuild`, answers LSP server-to-client setup requests, opens the target C# files, and runs definition/reference requests.

## Terminal states

The artifact must use one of these states for the overall verdict and for each query:

```text
mcp_tool_missing
lsp_project_not_loaded
symbol_not_found
symbol_navigation_ready
```

`symbol_navigation_ready` is only allowed when the artifact contains usable LSP locations for every required query. If the direct fallback supplied those locations, the artifact must also record the MCP bridge workspace failure instead of hiding it.

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

On the current 037B validation machine, `csharp-lsp-mcp` exposes the expected C# tools but `csharp_set_workspace` returns:

```text
code=-32603; message=An error occurred.
```

The direct `csharp-ls` fallback proves live symbol navigation with `csharp-ls` 0.16.0.0. Treat the bridge failure as a follow-up integration gap, not as runtime/gameplay evidence.
