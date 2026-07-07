# Sprint 037B MCP/LSP Symbol Smoke Handoff

```text
[TBG | Sprint 037B | MCP/LSP Symbol Smoke | branch: sprint/037b-mcp-symbol-smoke]
```

## Completed

Sprint 037B replaces the previous symbol-smoke stub with a repo-owned MCP JSON-RPC smoke harness.

Added or updated:

- `scripts/mcp/Test-TbgMcpSymbolSmoke.ps1`
- `scripts/mcp/Test-TbgMcpReadiness.ps1`
- `.tbg/workflows/mcp-symbol-smoke.contract.json`
- `.tbg/harness/prompts/tbg-symbol-smoke.md`
- `docs/architecture/mcp-lsp-symbol-smoke-setup.md`
- `docs/architecture/local-mcp-code-intelligence.md`

## Smoke behavior

The smoke:

1. Locates `csharp-lsp-mcp` from `PATH` or `.local/mcp-tools`.
2. Starts the MCP server over newline-delimited JSON-RPC.
3. Calls `initialize`, `tools/list`, and `csharp_set_workspace`.
4. Runs the seven required symbol questions only if the MCP bridge and C# LSP project load succeed.
5. Writes `artifacts/latest/mcp-symbol-smoke.result.json`.

## Current local result

The MCP bridge can be installed locally:

```powershell
dotnet tool install csharplspmcp --tool-path .local\mcp-tools
```

On this machine, `csharp-ls` did not install successfully through `dotnet tool install`, so the expected current verdict is:

```text
lsp_project_not_loaded
```

Do not claim live navigation until the artifact reports every query as:

```text
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
powershell -ExecutionPolicy Bypass -File scripts\mcp\Test-TbgMcpReadiness.ps1 -ContractId "mcp-symbol-smoke"
powershell -ExecutionPolicy Bypass -File scripts\mcp\Test-TbgMcpSymbolSmoke.ps1 -ContractId "mcp-symbol-smoke"
git diff --check
git status --short
```

Expected artifact:

```text
artifacts/latest/mcp-symbol-smoke.result.json
```

## Next command

```powershell
dotnet tool install csharp-ls --tool-path .local\mcp-tools
```

If NuGet still reports missing `DotnetToolSettings.xml`, resolve the C# LSP installation path first, then rerun the symbol smoke.
