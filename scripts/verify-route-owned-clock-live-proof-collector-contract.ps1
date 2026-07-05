# Offline contract verifier for route-owned clock live proof collector.

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]

function Read-RepoText {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        $failures.Add("missing file: $RelativePath") | Out-Null
        return ""
    }
    return Get-Content -LiteralPath $path -Raw
}

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Needle,
        [string]$Why = ""
    )

    $text = Read-RepoText -RelativePath $RelativePath
    if ($text.IndexOf($Needle, [System.StringComparison]::Ordinal) -lt 0) {
        $suffix = if ($Why) { " ($Why)" } else { "" }
        $failures.Add("$RelativePath missing '$Needle'$suffix") | Out-Null
    }
}

function Assert-Matches {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $text = Read-RepoText -RelativePath $RelativePath
    if ($text -notmatch $Pattern) {
        $failures.Add("$RelativePath missing $Label") | Out-Null
    }
}

$collector = "scripts\collect-route-owned-clock-live-proof.ps1"

Assert-Contains -RelativePath $collector -Needle "TbgRouteOwnedClockLiveProof.v1" -Why "collector must emit schema"
Assert-Contains -RelativePath $collector -Needle "BlacksmithGuild_RouteOwnedClockLiveProof.json" -Why "collector must write route proof summary"
Assert-Contains -RelativePath $collector -Needle "BlacksmithGuild_AgentIterationConfig.json" -Why "collector must inspect runtime config"
Assert-Contains -RelativePath $collector -Needle "BlacksmithGuild_MapTradeCert.json" -Why "collector must inspect map trade cert"
Assert-Contains -RelativePath $collector -Needle "routeClockEvidence" -Why "collector must inspect route clock evidence"
Assert-Contains -RelativePath $collector -Needle "runtimeProofClaim" -Why "collector must enforce movement claim boundary"
Assert-Contains -RelativePath $collector -Needle "AgentAutoMapTradeRoute" -Why "collector must inspect route trigger"
Assert-Contains -RelativePath $collector -Needle "MapTradeAutonomousService" -Why "collector must inspect service evidence"
Assert-Contains -RelativePath $collector -Needle "StartRouteNow" -Why "collector must inspect route start evidence"
Assert-Contains -RelativePath $collector -Needle "movementObserved" -Why "collector must inspect movement observation signals"
Assert-Contains -RelativePath $collector -Needle "partyMovedDistance" -Why "collector must inspect movement distance signal"
Assert-Contains -RelativePath $collector -Needle "Supply values for the following parameters" -Why "collector must detect interactive prompt blocker"
Assert-Contains -RelativePath $collector -Needle "allowedClaims" -Why "collector must emit allowed claims"
Assert-Contains -RelativePath $collector -Needle "forbiddenClaims" -Why "collector must emit forbidden claims"
Assert-Contains -RelativePath $collector -Needle "Do not claim movement proof" -Why "collector must prevent route ACK overclaim"
Assert-Contains -RelativePath $collector -Needle "runtime_blocked" -Why "collector must classify runtime blockers"
Assert-Contains -RelativePath $collector -Needle "invalid_overclaim" -Why "collector must reject unsupported runtimeProofClaim"
Assert-Contains -RelativePath $collector -Needle "route_checkpoint_reached" -Why "collector must classify cert checkpoint"
Assert-Matches -RelativePath $collector -Pattern "(?m)^\s*param\(" -Label "param block"
Assert-Contains -RelativePath $collector -Needle '[string]$BannerlordRoot' -Why 'BannerlordRoot parameter'
Assert-Contains -RelativePath $collector -Needle '[int]$FreshMinutes' -Why 'FreshMinutes parameter'
Assert-Contains -RelativePath $collector -Needle '[switch]$NoWrite' -Why 'NoWrite parameter'

$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $repoRoot $collector),
    [ref]$tokens,
    [ref]$errors
) | Out-Null

if ($errors.Count -gt 0) {
    foreach ($error in $errors) {
        $failures.Add("parse error: $($error.Message)") | Out-Null
    }
}

if ($failures.Count -gt 0) {
    Write-Host "FAIL: route-owned clock proof collector contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "PASS: route-owned clock proof collector contract verified." -ForegroundColor Green
exit 0
