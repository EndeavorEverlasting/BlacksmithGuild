# Offline contract verifier for short-timeout test doctrine.
# This verifier intentionally checks the doctrine and known offline verifier surfaces.
# It does not claim every long runtime wait has been refactored yet.
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]

function Read-RepoText {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        $failures.Add("missing file: $RelativePath") | Out-Null
        return ''
    }
    return Get-Content -LiteralPath $path -Raw
}

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Needle,
        [string]$Why = ''
    )
    $text = Read-RepoText -RelativePath $RelativePath
    if ($text.IndexOf($Needle, [System.StringComparison]::Ordinal) -lt 0) {
        $suffix = if ($Why) { " ($Why)" } else { '' }
        $failures.Add("$RelativePath missing '$Needle'$suffix") | Out-Null
    }
}

$doc = 'docs\handoff\test-timeout-contract.md'

Assert-Contains $doc '# Test Timeout Contract' 'timeout doctrine doc must exist'
Assert-Contains $doc '<= 30 seconds' 'offline target must be centered around 30 seconds'
Assert-Contains $doc 'Most offline tests and contract verifiers should complete within 30 seconds.' 'core rule must be explicit'
Assert-Contains $doc 'Longer waits require an explicit runtime reason and a named classification.' 'long waits must be justified'
Assert-Contains $doc 'DefaultOfflineTimeoutSeconds = 30' 'centralized offline timeout constant must be recommended'
Assert-Contains $doc 'Start-Sleep -Seconds 60' 'bad long-sleep example must remain visible'
Assert-Contains $doc 'live runtime proof' 'live-runtime exception must be named'
Assert-Contains $doc 'visible mechanics proof' 'visible proof exception must be named'
Assert-Contains $doc 'A test should fail with a useful classification before it makes the user wait.' 'fail-fast principle must be explicit'
Assert-Contains $doc 'scripts/verify-test-timeout-contract.ps1' 'doc must name this verifier'

# Existing offline verifiers should remain simple source/doc checks, not live runtime launchers.
foreach ($offlineVerifier in @(
    'scripts\verify-post-attach-actionability-contract.ps1',
    'scripts\verify-governor-operator-harness-contract.ps1',
    'scripts\verify-regent-route-horse-contract.ps1',
    'scripts\test-powershell-utf8-bom-contract.ps1'
)) {
    $text = Read-RepoText -RelativePath $offlineVerifier
    if ($text.IndexOf('Start-Process', [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        $failures.Add("$offlineVerifier must not start external processes in an offline contract verifier") | Out-Null
    }
    if ($text.IndexOf('Run-Governor-Ensure-DevSave', [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        $failures.Add("$offlineVerifier must not bootstrap live dev saves") | Out-Null
    }
    if ($text.IndexOf('Run-Governor-Disposable-Smoke', [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        $failures.Add("$offlineVerifier must not run live governor smoke") | Out-Null
    }
}

# This verifier is deliberately a doctrine/guardrail check. A later implementation pass can add
# deeper token scanning once long waits are migrated or annotated.
Assert-Contains $doc 'The goal is not to make every runtime action short. The goal is to make offline tests short and runtime waits honest.' 'boundary must avoid naive timeout cuts'

if ($failures.Count -gt 0) {
    Write-Host "FAIL: test timeout contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: test timeout contract verified.' -ForegroundColor Green
exit 0
