# Offline regression for fix_false_game_spawn_feed3f96, exercising the REAL runtime logic that
# the autonomous-assist unit tests cover only via mock detection objects:
#   Fix 1 - deploy-written Status.json / CrashContext.json must NOT signal a running game via
#           Get-BannerlordProcessDetection, and Phase1.log freshness is gated launch-relative.
#   Fix 3 - Clear-TbgStalePrelaunchRuntimeArtifacts rotates stale runtime artifacts to *.bak.
#   Fix 4 - a RuntimeLifecycle heartbeat older than the session start is not read as a crash.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'f7-launch-contract.ps1')
. (Join-Path $PSScriptRoot 'process-lifecycle-authority.ps1')

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "ASSERT FAILED: $Message" }
}

$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot
$tmpStatus = Join-Path $env:TEMP "f7-false-spawn-status-$([guid]::NewGuid().ToString('N')).json"
$tmpCrash = Join-Path $env:TEMP "f7-false-spawn-crash-$([guid]::NewGuid().ToString('N')).json"
$tmpPhase1 = Join-Path $env:TEMP "f7-false-spawn-phase1-$([guid]::NewGuid().ToString('N')).log"
$missing = Join-Path $env:TEMP "f7-false-spawn-missing-$([guid]::NewGuid().ToString('N')).none"

# ---------- Fix 1: Status.json freshness must not produce a running-game signal ----------
try {
    Set-Content -LiteralPath $tmpStatus -Value '{"stateMachine":"deploy"}' -Encoding UTF8
    (Get-Item -LiteralPath $tmpStatus).LastWriteTimeUtc = (Get-Date).ToUniversalTime()

    $script:BannerlordProcessDetectionCache = $null
    $script:BannerlordProcessDetectionCacheUtc = [datetime]::MinValue
    $det = Get-BannerlordProcessDetection -BannerlordRoot $bannerlordRoot `
        -Phase1Path $missing -StatusPath $tmpStatus -CrashContextPath $missing -CacheSec 0

    Assert-True ($det.statusJsonFresh -eq $true) 'fresh Status.json should still report statusJsonFresh=true'
    Assert-True ($det.gameProcessDetectionMethod -ne 'status_json_fresh') `
        'Status.json freshness must not set detection method status_json_fresh'
    Assert-True ($det.gameAliveConfidence -ne 'process_detection_uncertain') `
        'Status.json freshness must not produce process_detection_uncertain confidence'
    if (@($det.gameProcessCandidates).Count -eq 0) {
        Assert-True ($det.gameProcessRunning -eq $false) `
            'fresh Status.json with no real process must yield gameProcessRunning=false'
    }
} finally {
    Remove-Item -LiteralPath $tmpStatus -Force -ErrorAction SilentlyContinue
}

# ---------- Fix 1: CrashContext.json freshness must not produce a running-game signal ----------
try {
    Set-Content -LiteralPath $tmpCrash -Value '{"crash":"old"}' -Encoding UTF8
    (Get-Item -LiteralPath $tmpCrash).LastWriteTimeUtc = (Get-Date).ToUniversalTime()

    $script:BannerlordProcessDetectionCache = $null
    $script:BannerlordProcessDetectionCacheUtc = [datetime]::MinValue
    $det = Get-BannerlordProcessDetection -BannerlordRoot $bannerlordRoot `
        -Phase1Path $missing -StatusPath $missing -CrashContextPath $tmpCrash -CacheSec 0

    Assert-True ($det.crashContextFresh -eq $true) 'fresh CrashContext.json should report crashContextFresh=true'
    Assert-True ($det.gameProcessDetectionMethod -ne 'crash_context_fresh') `
        'CrashContext.json freshness must not set detection method crash_context_fresh'
    if (@($det.gameProcessCandidates).Count -eq 0) {
        Assert-True ($det.gameProcessRunning -eq $false) `
            'fresh CrashContext.json with no real process must yield gameProcessRunning=false'
    }
} finally {
    Remove-Item -LiteralPath $tmpCrash -Force -ErrorAction SilentlyContinue
}

# ---------- Fix 1: Phase1 freshness gated relative to launch start ----------
try {
    Set-Content -LiteralPath $tmpPhase1 -Value '[TBG TRACE] offline false-spawn probe' -Encoding UTF8
    (Get-Item -LiteralPath $tmpPhase1).LastWriteTimeUtc = (Get-Date).ToUniversalTime()

    # Launch started in the FUTURE relative to the Phase1 write => Phase1 is a prior-run log.
    $script:BannerlordProcessDetectionCache = $null
    $script:BannerlordProcessDetectionCacheUtc = [datetime]::MinValue
    $detFuture = Get-BannerlordProcessDetection -BannerlordRoot $bannerlordRoot `
        -Phase1Path $tmpPhase1 -StatusPath $missing -CrashContextPath $missing -CacheSec 0 `
        -LaunchStartedAtUtc ((Get-Date).ToUniversalTime().AddSeconds(60))
    Assert-True ($detFuture.gameAliveConfidence -ne 'phase1_active') `
        'Phase1 older than launch start must not yield phase1_active'

    # Launch started in the PAST => fresh Phase1 is a valid weak signal (legacy behavior preserved).
    $script:BannerlordProcessDetectionCache = $null
    $script:BannerlordProcessDetectionCacheUtc = [datetime]::MinValue
    $detPast = Get-BannerlordProcessDetection -BannerlordRoot $bannerlordRoot `
        -Phase1Path $tmpPhase1 -StatusPath $missing -CrashContextPath $missing -CacheSec 0 `
        -LaunchStartedAtUtc ((Get-Date).ToUniversalTime().AddSeconds(-60))
    if (@($detPast.gameProcessCandidates).Count -eq 0) {
        Assert-True ($detPast.gameAliveConfidence -eq 'phase1_active') `
            'fresh Phase1 after launch start must yield phase1_active (legacy weak signal preserved)'
    }
} finally {
    Remove-Item -LiteralPath $tmpPhase1 -Force -ErrorAction SilentlyContinue
}

# ---------- Fix 3: preflight rotates stale runtime artifacts ----------
# Isolate the docs-root candidate (Get-BannerlordDocsRoot uses USERPROFILE) so the test never
# touches real Documents\Mount and Blade II Bannerlord artifacts.
$isoProfile = Join-Path $env:TEMP "f7-false-spawn-profile-$([guid]::NewGuid().ToString('N'))"
$tmpRoot = Join-Path $env:TEMP "f7-false-spawn-root-$([guid]::NewGuid().ToString('N'))"
$savedProfile = $env:USERPROFILE
New-Item -ItemType Directory -Force -Path $isoProfile | Out-Null
New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null
try {
    $env:USERPROFILE = $isoProfile
    $artifacts = @(
        'BlacksmithGuild_Phase1.log',
        'BlacksmithGuild_Status.json',
        'BlacksmithGuild_RuntimeLifecycle.json',
        'BlacksmithGuild_CrashContext.json'
    )
    foreach ($a in $artifacts) {
        Set-Content -LiteralPath (Join-Path $tmpRoot $a) -Value 'stale-prior-run' -Encoding UTF8
    }
    $rotated = Clear-TbgStalePrelaunchRuntimeArtifacts -BannerlordRoot $tmpRoot -Timestamp 'testts'
    foreach ($a in $artifacts) {
        $orig = Join-Path $tmpRoot $a
        Assert-True (-not (Test-Path -LiteralPath $orig)) "stale artifact $a should be rotated away"
        Assert-True (Test-Path -LiteralPath "$orig.prelaunch-testts.bak") "rotated backup for $a should exist"
    }
    Assert-True (@($rotated).Count -eq $artifacts.Count) 'all four stale artifacts should be reported rotated'
} finally {
    $env:USERPROFILE = $savedProfile
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $isoProfile -Recurse -Force -ErrorAction SilentlyContinue
}

# ---------- Fix 4: heartbeat older than session start is not a crash ----------
$script:TbgCancelRequested = $false
$script:TbgProcessLifecycle = [ordered]@{
    sessionAuthorityMode = 'UserSession'
    startedAtUtc = (Get-Date).ToUniversalTime().AddSeconds(-600).ToString('o')
    intentionalTerminations = @()
    launchSelection = $null
}
$detGone = [pscustomobject]@{ gameProcessRunning = $false }

$rtStale = [pscustomobject]@{
    parseOk = $true
    lastHeartbeatUtc = (Get-Date).ToUniversalTime().AddDays(-1)
    gracefulShutdownObserved = $false
    lastCommandStartedAtUtc = $null
    lastCommandFinishedAtUtc = $null
}
$clsStale = Invoke-TbgTerminationClassification -BannerlordRoot $bannerlordRoot -CyclePhase 'loading' `
    -Detection $detGone -RuntimeLifecycle $rtStale
Assert-True ($clsStale.classification -ne 'crash_or_unexpected_exit') `
    "prior-session heartbeat must not classify as crash; got $($clsStale.classification)"
Assert-True ($clsStale.classification -eq 'process_disappeared_during_loading') `
    "prior-session heartbeat during loading should fall through to live fast-fail; got $($clsStale.classification)"

# Control: a stale-but-in-session heartbeat IS still a crash signal.
$rtInSession = [pscustomobject]@{
    parseOk = $true
    lastHeartbeatUtc = (Get-Date).ToUniversalTime().AddSeconds(-120)
    gracefulShutdownObserved = $false
    lastCommandStartedAtUtc = $null
    lastCommandFinishedAtUtc = $null
}
$clsCrash = Invoke-TbgTerminationClassification -BannerlordRoot $bannerlordRoot -CyclePhase 'loading' `
    -Detection $detGone -RuntimeLifecycle $rtInSession
Assert-True ($clsCrash.classification -eq 'crash_or_unexpected_exit') `
    "in-session stale heartbeat should remain crash_or_unexpected_exit; got $($clsCrash.classification)"

$script:TbgProcessLifecycle = $null

Write-Host 'PASS offline false-spawn regression feed3f96 (fixes 1, 3, 4 real-logic)'
