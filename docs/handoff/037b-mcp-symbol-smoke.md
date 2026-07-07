# Sprint 037B MCP/LSP Symbol Smoke Handoff

```text
[TBG | Sprint 037B | MCP/LSP Symbol Smoke | branch: sprint/037b-mcp-symbol-smoke]
```

## Completed

Sprint 037B now runs live symbol navigation for the required C# questions and writes:

```text
artifacts/latest/mcp-symbol-smoke.result.json
```

The smoke still starts the `csharp-lsp-mcp` bridge, lists its tools, and records `csharp_set_workspace` attempts. On the current validation machine the bridge returns JSON-RPC `-32603` for both workspace candidates, so the smoke records that blocker and then uses the repo-owned direct `csharp-ls` fallback to prove symbol navigation through LSP.

Updated:

- `scripts/mcp/Test-TbgMcpSymbolSmoke.ps1`
- `scripts/mcp/Invoke-TbgCsharpLsSymbolSmoke.js`
- `scripts/mcp/Test-TbgMcpReadiness.ps1`
- `scripts/mcp/Get-TbgMcpWorkspaceCandidates.ps1`
- `.tbg/workflows/mcp-symbol-smoke.contract.json`
- `.tbg/harness/prompts/tbg-symbol-smoke.md`
- `docs/architecture/mcp-lsp-symbol-smoke-setup.md`
- `docs/architecture/local-mcp-code-intelligence.md`

## Smoke behavior

The smoke:

1. Locates `csharp-lsp-mcp` from `PATH` or `.local/mcp-tools`.
2. Locates `csharp-ls` from `PATH` or `.local/mcp-tools`.
3. Starts the MCP server over newline-delimited JSON-RPC.
4. Calls `initialize`, `tools/list`, and `csharp_set_workspace`.
5. Tries `src/BlacksmithGuild` first, then repo root.
6. If the bridge workspace load succeeds, runs the required MCP symbol questions.
7. If the bridge workspace load fails but `csharp-ls` is available, starts `csharp-ls` directly through LSP framing and runs the required symbol questions.
8. Writes `artifacts/latest/mcp-symbol-smoke.result.json` with both bridge evidence and direct LSP proof.

## Latest local result

Validation worktree:

```text
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-037a-validation
```

Latest local artifact:

```text
status = ready
verdict = symbol_navigation_ready
finding = lsp-direct-fallback:symbol_navigation_ready
```

All required queries are `symbol_navigation_ready`:

```text
Where is MapTradeAutonomousService defined?
Where is StartRouteNow defined?
Who calls StartRouteNow?
Where is CampaignMapReadyOrchestrator defined?
Where is _activeReport assigned, read, and cleared?
Where are hotkeys registered?
Where is command inbox parsing handled?
```

Confirmed tools:

```text
mcp-tool-ok:csharp-lsp-mcp
lsp-tool-ok:csharp-ls
csharp-ls version: 0.16.0.0
mcp-tool-listed:csharp_set_workspace
mcp-tool-listed:csharp_definition
mcp-tool-listed:csharp_references
mcp-tool-listed:csharp_symbols
```

## Known bridge gap

The MCP bridge is present, but `csharp_set_workspace` still fails locally:

```text
workspace role: csharp_project_directory
workspace path: src\BlacksmithGuild
response: code=-32603; message=An error occurred.

workspace role: repo_root_fallback
workspace path: repo root
response: code=-32603; message=An error occurred.
```

Direct `csharp-ls` succeeds because the helper answers server-to-client LSP requests during initialization. Keep this distinction in final claims: live LSP symbol navigation is proven; MCP bridge workspace navigation remains a follow-up gap.

## Acceptance

Only claim live symbol navigation when `artifacts/latest/mcp-symbol-smoke.result.json` reports every required query as:

```text
symbol_navigation_ready
```

The result must use only these terminal states:

```text
mcp_tool_missing
lsp_project_not_loaded
symbol_not_found
symbol_navigation_ready
```

## Forbidden scope

- Do not launch Bannerlord.
- Do not run `ForgeReboot.cmd`.
- Do not click the launcher.
- Do not write command inbox files.
- Do not mutate saves.
- Do not modify gameplay behavior.
- Do not touch runtime route code unless a new explicit runtime contract is created.

## Validation

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\mcp\Get-TbgMcpWorkspaceCandidates.ps1
powershell -ExecutionPolicy Bypass -File scripts\mcp\Test-TbgMcpReadiness.ps1 -ContractId "mcp-symbol-smoke"
powershell -ExecutionPolicy Bypass -File scripts\mcp\Test-TbgMcpSymbolSmoke.ps1 -ContractId "mcp-symbol-smoke" -TimeoutSeconds 120
powershell -ExecutionPolicy Bypass -File scripts\harness\Test-TbgDoneGate.ps1 -ContractId "mcp-symbol-smoke"
git diff --check
git status --short
```

Expected artifacts:

```text
artifacts/latest/mcp-readiness.result.json
artifacts/latest/mcp-symbol-smoke.result.json
artifacts/latest/done-gate.result.json
```

## Next target

Fix or replace the external `csharp-lsp-mcp` bridge workspace initialization so `csharp_set_workspace` reaches the same ready state currently proven by direct `csharp-ls`.
