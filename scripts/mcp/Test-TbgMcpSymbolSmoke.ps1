param(
    [string]$ContractId = "local-mcp-code-intelligence"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Find-TbgRepoRoot {
    $cursor = (Get-Location).Path
    while ($true) {
        if (Test-Path -LiteralPath (Join-Path $cursor ".tbg/harness/manifest.json")) { return $cursor }
        $parent = Split-Path -Parent $cursor
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $cursor) { throw "Could not locate repo root." }
        $cursor = $parent
    }
}

$repoRoot = Find-TbgRepoRoot
$symbols = @(
    "MapTradeAutonomousService",
    "StartRouteNow",
    "CampaignMapReadyOrchestrator",
    "_activeReport",
    "DevCommandBus",
    "BlacksmithGuild_CommandInbox"
)

$queries = @()
foreach ($symbol in $symbols) {
    $queries += New-Object psobject -Property @{
        symbol = $symbol
        status = "not_run"
        note = "Sprint 037B will replace this stub with live MCP/LSP symbol lookup."
    }
}

$result = New-Object psobject -Property @{
    schema = "tbg.harness.result.v1"
    action = "TestMcpSymbolSmoke"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    repoRoot = $repoRoot
    branch = "unknown"
    contractId = $ContractId
    status = "missing_prereqs"
    verdict = "mcp_symbol_smoke_stub_only"
    findings = @("Stub committed in Sprint 037A. Implement live LSP calls in Sprint 037B.")
    missingPrereqs = @("live-mcp-lsp-integration")
    forbiddenScopeTouched = $false
    artifacts = @("artifacts/latest/mcp-symbol-smoke.result.json")
    queries = @($queries)
}

$artifactDir = Join-Path $repoRoot "artifacts/latest"
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
$result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $artifactDir "mcp-symbol-smoke.result.json") -Encoding UTF8
$result | ConvertTo-Json -Depth 20
