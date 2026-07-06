param(
    [string]$ContractId = "local-mcp-code-intelligence"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Find-TbgRepoRoot {
    $cursor = (Get-Location).Path
    while ($true) {
        $marker = Join-Path $cursor ".tbg/harness/manifest.json"
        if (Test-Path -LiteralPath $marker) { return $cursor }
        $parent = Split-Path -Parent $cursor
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $cursor) { throw "Could not locate repo root." }
        $cursor = $parent
    }
}

$repoRoot = Find-TbgRepoRoot
$contractPath = Join-Path $repoRoot (".tbg/workflows/" + $ContractId + ".contract.json")
$findings = @()
$missing = @()

if (Test-Path -LiteralPath $contractPath) {
    $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
    $findings += "contract-ok:$ContractId"
    foreach ($artifact in @($contract.requiredArtifacts)) {
        if (Test-Path -LiteralPath (Join-Path $repoRoot $artifact)) {
            $findings += "artifact-ok:$artifact"
        } else {
            $missing += "artifact-missing:$artifact"
        }
    }
} else {
    $missing += "contract-missing:$ContractId"
}

$status = "ready"
$verdict = "workflow_gate_ready"
if ($missing.Count -gt 0) {
    $status = "missing_prereqs"
    $verdict = "workflow_gate_missing_prereqs"
}

$result = New-Object psobject -Property @{
    schema = "tbg.harness.result.v1"
    action = "TestWorkflowGate"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    repoRoot = $repoRoot
    branch = "unknown"
    contractId = $ContractId
    status = $status
    verdict = $verdict
    findings = @($findings)
    missingPrereqs = @($missing)
    forbiddenScopeTouched = $false
    artifacts = @("artifacts/latest/workflow-gate.result.json")
}

$artifactDir = Join-Path $repoRoot "artifacts/latest"
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
$result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $artifactDir "workflow-gate.result.json") -Encoding UTF8
$result | ConvertTo-Json -Depth 20
