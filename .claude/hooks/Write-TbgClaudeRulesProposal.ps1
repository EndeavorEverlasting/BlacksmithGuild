Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "../..")
$writer = Join-Path $repoRoot "scripts/harness/Write-TbgClaudeRulesProposal.ps1"
& $writer -ContractId "local-mcp-code-intelligence"
