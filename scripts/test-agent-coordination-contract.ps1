# Offline structure check for root coordination and Window Delta Doctrine.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([string]$Message)
    $failures.Add($Message) | Out-Null
    Write-Host "FAIL: $Message" -ForegroundColor Red
}

function Get-RepoText {
    param([string]$RelativePath)
    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        Add-Failure "Missing required file: $RelativePath"
        return $null
    }
    return Get-Content -LiteralPath $path -Raw
}

function Require-Match {
    param(
        [string]$Label,
        [AllowNull()][string]$Text,
        [string]$Pattern
    )
    if ($null -eq $Text) { return }
    if ($Text -notmatch $Pattern) {
        Add-Failure "$Label missing pattern: $Pattern"
    } else {
        Write-Host "PASS: $Label" -ForegroundColor Green
    }
}

$agents = Get-RepoText 'AGENTS.md'
$contract = Get-RepoText 'docs/handoff/agent-coordination-contract.md'
$windowDoctrine = Get-RepoText 'docs/control/logs/open/window-delta-doctrine.md'
$autonomousTarget = Get-RepoText 'docs/control/logs/open/autonomous-assist-session-target.md'

Require-Match 'AGENTS defines Agent A' $agents 'Agent A\s*=\s*Cert\s*/\s*Evidence\s*/\s*Git\s*/\s*PR judgment'
Require-Match 'AGENTS defines Agent B' $agents 'Agent B\s*=\s*Runtime\s*/\s*Readiness\s*/\s*Gameplay state truth'
Require-Match 'AGENTS defines Agent C' $agents 'Agent C\s*=\s*External runner\s*/\s*launcher\s*/\s*lifecycle\s*/\s*window classifier'
Require-Match 'AGENTS defines Agent D' $agents 'Agent D\s*=\s*Docs\s*/\s*atlas\s*/\s*routing board'
Require-Match 'AGENTS runner evidence ownership' $agents 'Runner owns evidence capture'

foreach ($snapshot in @('S0', 'S1', 'S2', 'S3')) {
    Require-Match "Window Delta Doctrine mentions $snapshot" $windowDoctrine "\b$snapshot\b"
}
Require-Match 'Window Delta Doctrine S1 to S2 primary' $windowDoctrine 'S1\s*(?:->|→)\s*S2[\s\S]{0,120}primary launcher-selection method'
Require-Match 'Window Delta Doctrine global fallback' $windowDoctrine 'Global scan is fallback only'

Require-Match 'Autonomous target rejects manual log harvesting' $autonomousTarget 'manual log harvesting'
Require-Match 'Autonomous target no hotkey preferred path' $autonomousTarget 'preferred path requires no hotkey|without hotkey|no hotkey'
Require-Match 'Coordination contract exists and names branch map' $contract 'Current branch map'

Write-Host ''
if ($failures.Count -gt 0) {
    Write-Host "Agent coordination contract: FAIL ($($failures.Count) issue(s))" -ForegroundColor Red
    exit 1
}

Write-Host 'Agent coordination contract: PASS' -ForegroundColor Green
exit 0
