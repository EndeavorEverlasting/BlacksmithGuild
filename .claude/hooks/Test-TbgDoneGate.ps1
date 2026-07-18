Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "../..")
$doneGate = Join-Path $repoRoot "scripts/harness/Test-TbgDoneGate.ps1"
& $doneGate -ContractId "local-mcp-code-intelligence"
