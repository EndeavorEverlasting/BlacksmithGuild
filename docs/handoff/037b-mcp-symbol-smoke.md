# Sprint 037B MCP/LSP Symbol Smoke Handoff

```text
[TBG | Sprint 037B | MCP/LSP Symbol Smoke | branch: sprint/037b-mcp-symbol-smoke]
```

## Completed

Sprint 037B replaces the previous symbol-smoke stub with a repo-owned MCP JSON-RPC smoke harness.

Added or updated:

- `scripts/mcp/Test-TbgMcpSymbolSmoke.ps1`
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
5. Runs the required symbol questions only if the MCP bridge and C# LSP project load succeed.
6. Writes `artifacts/latest/mcp-symbol-smoke.result.json`.

## Latest local result

The local validation worktree is:

```text
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-037a-validation
```

Latest validated state from PR #40:

```text
csharp-ls install: success with csharp-ls 0.16.0.0
mcp readiness: ready / mcp_readiness_ready
mcp symbol smoke with -TimeoutSeconds 120: missing_prereqs / symbol_not_found
done gate: ready / harness_done_gate_pass
git diff --check: exit 0
git status --short: clean
```

Confirmed tools:

```text
mcp-tool-ok:csharp-lsp-mcp
lsp-tool-ok:csharp-ls
csharp-ls path: C:\Users\Cheex\.dotnet\tools\csharp-ls.exe
mcp-tool-listed:csharp_set_workspace
mcp-tool-listed:csharp_definition
mcp-tool-listed:csharp_references
mcp-tool-listed:csharp_symbols
```

## Current blocker

`csharp_set_workspace` schema says `path` is the path to the solution/project directory.

Observed probes showed:

```text
workspace root: JSON-RPC error -32603 / An error occurred
workspace project file: Error: Directory does not exist: ...\src\BlacksmithGuild\BlacksmithGuild.csproj
definition with content: JSON-RPC error -32603 / An error occurred
definition without content: tool error text
symbols query: tool error text
symbols file: JSON-RPC error -32603 / An error occurred
```

Therefore the next implementation target is to make the smoke try this workspace path first:

```text
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-037a-validation\src\BlacksmithGuild
```

The branch now includes:

```text
scripts/mcp/Get-TbgMcpWorkspaceCandidates.ps1
```

which reports `src\BlacksmithGuild` as the preferred C# workspace directory and `repo root` as a fallback.

## Acceptance

Do not claim live navigation until `artifacts/latest/mcp-symbol-smoke.result.json` reports every required query as:

```text
symbol_navigation_ready
```

Current honest blocked verdict is:

```text
status = missing_prereqs
verdict = symbol_not_found
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

## Next implementation patch

Patch `scripts/mcp/Test-TbgMcpSymbolSmoke.ps1` so line currently equivalent to:

```powershell
Invoke-McpTool -Name "csharp_set_workspace" -Arguments @{ path = $repoRoot }
```

becomes ordered workspace attempts:

```powershell
$workspaceCandidates = @(
    (Join-Path $repoRoot "src/BlacksmithGuild"),
    $repoRoot
)

foreach ($workspacePath in $workspaceCandidates) {
    $workspaceResponse = Invoke-McpTool -Process $process -NextId ([ref]$nextId) -Name "csharp_set_workspace" -Arguments @{ path = $workspacePath } -TimeoutMilliseconds $timeoutMs
    if ($workspaceResponse.PSObject.Properties.Name -notcontains "error") {
        $selectedWorkspacePath = $workspacePath
        break
    }
}
```

Then record the selected workspace path in the result JSON under `tools.workspacePath` or `workspace.selectedPath`.
