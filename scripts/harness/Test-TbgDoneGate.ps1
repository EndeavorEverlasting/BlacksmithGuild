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

function Invoke-CaptureWithExitCode {
    param([string]$FileName, [string[]]$Arguments)
    try {
        $output = & $FileName @Arguments 2>&1
        $code = $LASTEXITCODE
        return @{ ExitCode = $code; Output = ($output -join "`n").Trim() }
    } catch {
        return @{ ExitCode = 999; Output = $_.Exception.Message }
    }
}

$repoRoot = Find-TbgRepoRoot
$contractPath = Join-Path $repoRoot (".tbg/workflows/" + $ContractId + ".contract.json")
$findings = @()
$missing = @()
$blocked = $false

if (Test-Path -LiteralPath $contractPath) {
    $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
    $findings += "contract-ok:$ContractId"
    foreach ($artifact in @($contract.requiredArtifacts)) {
        $artifactPath = Join-Path $repoRoot $artifact
        if (Test-Path -LiteralPath $artifactPath) {
            try {
                Get-Content -LiteralPath $artifactPath -Raw | ConvertFrom-Json | Out-Null
                $findings += "artifact-json-ok:$artifact"
            } catch {
                $missing += "artifact-invalid-json:$artifact"
            }
        } else {
            $missing += "artifact-missing:$artifact"
        }
    }
} else {
    $missing += "contract-missing:$ContractId"
}

Push-Location $repoRoot
try {
    $diffCheck = Invoke-CaptureWithExitCode -FileName "git" -Arguments @("diff", "--check")
    if ($diffCheck.ExitCode -eq 0) { $findings += "git-diff-check-ok" } else { $blocked = $true; $missing += "git-diff-check-failed" }

    $status = Invoke-CaptureWithExitCode -FileName "git" -Arguments @("status", "--short")
    if ($status.ExitCode -eq 0) { $findings += "git-status-read-ok" } else { $blocked = $true; $missing += "git-status-failed" }
} finally {
    Pop-Location
}

$state = "ready"
$verdict = "harness_done_gate_pass"
if ($missing.Count -gt 0 -or $blocked) {
    $state = "blocked_by_policy"
    $verdict = "harness_done_gate_blocked"
}

$result = New-Object psobject -Property @{
    schema = "tbg.harness.result.v1"
    action = "TestDoneGate"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    repoRoot = $repoRoot
    branch = "unknown"
    contractId = $ContractId
    status = $state
    verdict = $verdict
    findings = @($findings)
    missingPrereqs = @($missing)
    forbiddenScopeTouched = $false
    artifacts = @("artifacts/latest/done-gate.result.json")
}

$artifactDir = Join-Path $repoRoot "artifacts/latest"
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
$result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $artifactDir "done-gate.result.json") -Encoding UTF8
$result | ConvertTo-Json -Depth 20

if ($verdict -eq "harness_done_gate_blocked") { exit 2 }
