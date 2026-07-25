[CmdletBinding()]
param(
    [string]$RepoRoot = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

. (Join-Path $PSScriptRoot 'Test-TbgLiveRuntimeProofAdmission.ps1') -ExportReducerOnly

$failures = New-Object System.Collections.Generic.List[string]
$passes = 0

function Add-TestPass([string]$Message) {
    $script:passes++
    Write-Host "PASS: ${Message}" -ForegroundColor Green
}
function Add-TestFail([string]$Message) {
    $script:failures.Add($Message) | Out-Null
    Write-Host "FAIL: ${Message}" -ForegroundColor Red
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("tbg-proof-packet-test-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

try {
    $generatorScript = Join-Path $PSScriptRoot 'New-TbgGovernorLiveProofPacket.ps1'
    if (-not (Test-Path -LiteralPath $generatorScript -PathType Leaf)) {
        throw "Missing generator script: ${generatorScript}"
    }

    $nowUtc = [datetime]::UtcNow

    # Case 1: Complete valid packet -> PASS_LIVE_RUNTIME
    $c1Dir = Join-Path $tempRoot 'case1_valid'
    New-Item -ItemType Directory -Force -Path $c1Dir | Out-Null

    [ordered]@{
        sessionId = '20260725-180000'
        testStartUtc = $nowUtc.AddMinutes(-3).ToString('o')
        bootstrapUsed = $false
        skipLaunch = $false
        mode = 'live_fresh_launch'
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c1Dir 'governor-smoke-summary.json') -Encoding UTF8

    [ordered]@{
        sessionId = '20260725-180000'
        processId = 1234
        hwnd = 5678
        launchActionDispatched = $true
        actionDispatchedUtc = $nowUtc.AddMinutes(-2).ToString('o')
        mode = 'LaunchSetup'
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c1Dir 'launcher-window-context.json') -Encoding UTF8

    [ordered]@{
        sessionId = '20260725-180000'
        processId = 9999
        processName = 'Bannerlord'
        updatedAt = $nowUtc.AddSeconds(-10).ToString('o')
        campaignReady = $true
        campaignReadyUtc = $nowUtc.AddMinutes(-2).ToString('o')
        session = [ordered]@{ canPollFileInbox = $true }
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $c1Dir 'BlacksmithGuild_Status.json') -Encoding UTF8

    [ordered]@{
        sessionId = '20260725-180000'
        commandId = 'cmd-100'
        commandName = 'RunCampaignGovernorCycleNow'
        requestUtc = $nowUtc.AddMinutes(-1).ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c1Dir 'command-request.json') -Encoding UTF8

    [ordered]@{
        sessionId = '20260725-180000'
        commandId = 'cmd-100'
        commandName = 'RunCampaignGovernorCycleNow'
        ackUtc = $nowUtc.AddSeconds(-50).ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c1Dir 'command-ack.json') -Encoding UTF8

    [ordered]@{
        sessionId = '20260725-180000'
        cycleId = 'cycle-100'
        selectedBranch = 'main'
        selectedReason = 'valid'
        generatedUtc = $nowUtc.AddSeconds(-30).ToString('o')
        allowed = $false
        latestActivityResult = [ordered]@{ narrativeDetails = 'ok'; handoffTrail = @('t'); mutationApplied = $false }
        proposedActivity = [ordered]@{ inputs = @{}; expectedOutputs = @{}; handoffTrail = @('t') }
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $c1Dir 'BlacksmithGuild_CampaignGovernorDecision.json') -Encoding UTF8

    $pkt1Path = & $generatorScript -SessionDir $c1Dir -RepoRoot $RepoRoot
    $pkt1 = Get-Content -LiteralPath $pkt1Path -Raw | ConvertFrom-Json
    $adm1 = Resolve-LiveProofAdmission $pkt1
    if ($adm1.terminalState -eq 'PASS_LIVE_RUNTIME') { Add-TestPass 'Case 1: complete valid packet -> PASS_LIVE_RUNTIME' }
    else { Add-TestFail "Case 1 failed: got $($adm1.terminalState)" }

    # Case 2: SkipLaunch -> BLOCKED_LIVE_MODE_SKIP_LAUNCH
    $c2Dir = Join-Path $tempRoot 'case2_skip_launch'
    New-Item -ItemType Directory -Force -Path $c2Dir | Out-Null
    [ordered]@{
        sessionId = '20260725-180001'
        testStartUtc = $nowUtc.AddMinutes(-2).ToString('o')
        skipLaunch = $true
        mode = 'live_fresh_launch'
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c2Dir 'governor-smoke-summary.json') -Encoding UTF8

    $pkt2Path = & $generatorScript -SessionDir $c2Dir -RepoRoot $RepoRoot
    $pkt2 = Get-Content -LiteralPath $pkt2Path -Raw | ConvertFrom-Json
    $adm2 = Resolve-LiveProofAdmission $pkt2
    if ($adm2.terminalState -eq 'BLOCKED_LIVE_MODE_SKIP_LAUNCH') { Add-TestPass 'Case 2: SkipLaunch -> BLOCKED_LIVE_MODE_SKIP_LAUNCH' }
    else { Add-TestFail "Case 2 failed: got $($adm2.terminalState)" }

    # Case 3: PID/HWND present but no launch action evidence -> FAIL_LAUNCH_ACTION_NOT_DISPATCHED
    $c3Dir = Join-Path $tempRoot 'case3_no_action'
    New-Item -ItemType Directory -Force -Path $c3Dir | Out-Null
    [ordered]@{
        sessionId = '20260725-180002'
        testStartUtc = $nowUtc.AddMinutes(-2).ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c3Dir 'governor-smoke-summary.json') -Encoding UTF8

    [ordered]@{
        sessionId = '20260725-180002'
        processId = 1234
        hwnd = 5678
        # launchActionDispatched intentionally missing/false
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c3Dir 'launcher-window-context.json') -Encoding UTF8

    $pkt3Path = & $generatorScript -SessionDir $c3Dir -RepoRoot $RepoRoot
    $pkt3 = Get-Content -LiteralPath $pkt3Path -Raw | ConvertFrom-Json
    $adm3 = Resolve-LiveProofAdmission $pkt3
    if ($adm3.terminalState -eq 'FAIL_LAUNCH_ACTION_NOT_DISPATCHED') { Add-TestPass 'Case 3: PID/HWND present without action -> FAIL_LAUNCH_ACTION_NOT_DISPATCHED' }
    else { Add-TestFail "Case 3 failed: got $($adm3.terminalState)" }

    # Case 4: Action dispatched, game not spawned -> FAIL_GAME_PROCESS_NOT_OBSERVED
    $c4Dir = Join-Path $tempRoot 'case4_no_game'
    New-Item -ItemType Directory -Force -Path $c4Dir | Out-Null
    [ordered]@{
        sessionId = '20260725-180003'
        testStartUtc = $nowUtc.AddMinutes(-2).ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c4Dir 'governor-smoke-summary.json') -Encoding UTF8

    [ordered]@{
        sessionId = '20260725-180003'
        processId = 1234
        hwnd = 5678
        launchActionDispatched = $true
        actionDispatchedUtc = $nowUtc.AddMinutes(-1).ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c4Dir 'launcher-window-context.json') -Encoding UTF8

    $pkt4Path = & $generatorScript -SessionDir $c4Dir -RepoRoot $RepoRoot
    $pkt4 = Get-Content -LiteralPath $pkt4Path -Raw | ConvertFrom-Json
    $adm4 = Resolve-LiveProofAdmission $pkt4
    if ($adm4.terminalState -eq 'FAIL_GAME_PROCESS_NOT_OBSERVED') { Add-TestPass 'Case 4: Action dispatched but game not spawned -> FAIL_GAME_PROCESS_NOT_OBSERVED' }
    else { Add-TestFail "Case 4 failed: got $($adm4.terminalState)" }

    # Case 5: Stale game process from prior run -> FAIL_GAME_PROCESS_NOT_OBSERVED
    $c5Dir = Join-Path $tempRoot 'case5_stale_game'
    New-Item -ItemType Directory -Force -Path $c5Dir | Out-Null
    [ordered]@{
        sessionId = '20260725-180004'
        testStartUtc = $nowUtc.AddMinutes(-2).ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c5Dir 'governor-smoke-summary.json') -Encoding UTF8

    [ordered]@{
        sessionId = '20260725-180004'
        processId = 1234
        hwnd = 5678
        launchActionDispatched = $true
        actionDispatchedUtc = $nowUtc.AddMinutes(-1).ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c5Dir 'launcher-window-context.json') -Encoding UTF8

    [ordered]@{
        sessionId = '20260725-180004'
        processId = 9999
        processName = 'Bannerlord'
        updatedAt = $nowUtc.AddDays(-1).ToString('o') # STALE
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c5Dir 'BlacksmithGuild_Status.json') -Encoding UTF8

    $pkt5Path = & $generatorScript -SessionDir $c5Dir -RepoRoot $RepoRoot
    $pkt5 = Get-Content -LiteralPath $pkt5Path -Raw | ConvertFrom-Json
    $adm5 = Resolve-LiveProofAdmission $pkt5
    if ($adm5.terminalState -eq 'FAIL_GAME_PROCESS_NOT_OBSERVED') { Add-TestPass 'Case 5: Stale game process -> FAIL_GAME_PROCESS_NOT_OBSERVED' }
    else { Add-TestFail "Case 5 failed: got $($adm5.terminalState)" }

    # Case 6: Partial campaign readiness (only campaignReady=true) -> FAIL_CAMPAIGN_NOT_READY
    $c6Dir = Join-Path $tempRoot 'case6_partial_readiness'
    New-Item -ItemType Directory -Force -Path $c6Dir | Out-Null
    [ordered]@{
        sessionId = '20260725-180005'
        testStartUtc = $nowUtc.AddMinutes(-3).ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c6Dir 'governor-smoke-summary.json') -Encoding UTF8

    [ordered]@{
        sessionId = '20260725-180005'
        processId = 1234
        hwnd = 5678
        launchActionDispatched = $true
        actionDispatchedUtc = $nowUtc.AddMinutes(-2).ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c6Dir 'launcher-window-context.json') -Encoding UTF8

    [ordered]@{
        sessionId = '20260725-180005'
        processId = 9999
        processName = 'Bannerlord'
        updatedAt = $nowUtc.AddSeconds(-10).ToString('o')
        campaignReady = $true
        # canPollFileInbox missing/false
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c6Dir 'BlacksmithGuild_Status.json') -Encoding UTF8

    $pkt6Path = & $generatorScript -SessionDir $c6Dir -RepoRoot $RepoRoot
    $pkt6 = Get-Content -LiteralPath $pkt6Path -Raw | ConvertFrom-Json
    $adm6 = Resolve-LiveProofAdmission $pkt6
    if ($adm6.terminalState -eq 'FAIL_CAMPAIGN_NOT_READY') { Add-TestPass 'Case 6: Only campaignReady=true -> FAIL_CAMPAIGN_NOT_READY' }
    else { Add-TestFail "Case 6 failed: got $($adm6.terminalState)" }

    # Case 7: Campaign stability under 60 seconds -> FAIL_CAMPAIGN_NOT_READY
    $c7Dir = Join-Path $tempRoot 'case7_unstable'
    New-Item -ItemType Directory -Force -Path $c7Dir | Out-Null
    [ordered]@{
        sessionId = '20260725-180006'
        testStartUtc = $nowUtc.AddSeconds(-30).ToString('o') # test started 30s ago (< 60s)
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c7Dir 'governor-smoke-summary.json') -Encoding UTF8

    [ordered]@{
        sessionId = '20260725-180006'
        processId = 1234
        hwnd = 5678
        launchActionDispatched = $true
        actionDispatchedUtc = $nowUtc.AddSeconds(-25).ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c7Dir 'launcher-window-context.json') -Encoding UTF8

    [ordered]@{
        sessionId = '20260725-180006'
        processId = 9999
        processName = 'Bannerlord'
        updatedAt = $nowUtc.AddSeconds(-5).ToString('o')
        campaignReady = $true
        campaignReadyUtc = $nowUtc.AddSeconds(-10).ToString('o') # ready only 5s ago
        session = [ordered]@{ canPollFileInbox = $true }
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $c7Dir 'BlacksmithGuild_Status.json') -Encoding UTF8

    $pkt7Path = & $generatorScript -SessionDir $c7Dir -RepoRoot $RepoRoot
    $pkt7 = Get-Content -LiteralPath $pkt7Path -Raw | ConvertFrom-Json
    $adm7 = Resolve-LiveProofAdmission $pkt7
    if ($adm7.terminalState -eq 'FAIL_CAMPAIGN_NOT_READY') { Add-TestPass 'Case 7: Stability < 60s -> FAIL_CAMPAIGN_NOT_READY' }
    else { Add-TestFail "Case 7 failed: got $($adm7.terminalState)" }

    # Case 8: Command ACK without command request -> FAIL_COMMAND_NOT_ISSUED
    $c8Dir = Join-Path $tempRoot 'case8_no_cmd_req'
    New-Item -ItemType Directory -Force -Path $c8Dir | Out-Null
    [ordered]@{
        sessionId = '20260725-180007'
        testStartUtc = $nowUtc.AddMinutes(-3).ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c8Dir 'governor-smoke-summary.json') -Encoding UTF8

    [ordered]@{
        sessionId = '20260725-180007'
        processId = 1234
        hwnd = 5678
        launchActionDispatched = $true
        actionDispatchedUtc = $nowUtc.AddMinutes(-2).ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c8Dir 'launcher-window-context.json') -Encoding UTF8

    [ordered]@{
        sessionId = '20260725-180007'
        processId = 9999
        processName = 'Bannerlord'
        updatedAt = $nowUtc.AddSeconds(-10).ToString('o')
        campaignReady = $true
        campaignReadyUtc = $nowUtc.AddMinutes(-2).ToString('o')
        session = [ordered]@{ canPollFileInbox = $true }
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $c8Dir 'BlacksmithGuild_Status.json') -Encoding UTF8

    # command-request.json missing

    $pkt8Path = & $generatorScript -SessionDir $c8Dir -RepoRoot $RepoRoot
    $pkt8 = Get-Content -LiteralPath $pkt8Path -Raw | ConvertFrom-Json
    $adm8 = Resolve-LiveProofAdmission $pkt8
    if ($adm8.terminalState -eq 'FAIL_COMMAND_NOT_ISSUED') { Add-TestPass 'Case 8: Missing command request -> FAIL_COMMAND_NOT_ISSUED' }
    else { Add-TestFail "Case 8 failed: got $($adm8.terminalState)" }

    # Case 9: Cross-run session mismatch -> FAIL_CORRELATION_MISMATCH
    $c9Dir = Join-Path $tempRoot 'case9_mismatch'
    New-Item -ItemType Directory -Force -Path $c9Dir | Out-Null
    [ordered]@{
        sessionId = 'session-AAA'
        testStartUtc = $nowUtc.AddMinutes(-3).ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c9Dir 'governor-smoke-summary.json') -Encoding UTF8

    [ordered]@{
        sessionId = 'session-AAA'
        processId = 1234
        hwnd = 5678
        launchActionDispatched = $true
        actionDispatchedUtc = $nowUtc.AddMinutes(-2).ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c9Dir 'launcher-window-context.json') -Encoding UTF8

    [ordered]@{
        sessionId = 'session-AAA'
        processId = 9999
        processName = 'Bannerlord'
        updatedAt = $nowUtc.AddSeconds(-10).ToString('o')
        campaignReady = $true
        campaignReadyUtc = $nowUtc.AddMinutes(-2).ToString('o')
        session = [ordered]@{ canPollFileInbox = $true }
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $c9Dir 'BlacksmithGuild_Status.json') -Encoding UTF8

    [ordered]@{
        sessionId = 'session-AAA'
        commandId = 'cmd-999'
        commandName = 'RunCampaignGovernorCycleNow'
        requestUtc = $nowUtc.AddMinutes(-1).ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c9Dir 'command-request.json') -Encoding UTF8

    [ordered]@{
        sessionId = 'session-AAA'
        commandId = 'cmd-999'
        commandName = 'RunCampaignGovernorCycleNow'
        ackUtc = $nowUtc.AddSeconds(-50).ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c9Dir 'command-ack.json') -Encoding UTF8

    [ordered]@{
        sessionId = 'session-BBB' # Mismatched decision session ID!
        cycleId = 'cycle-999'
        selectedBranch = 'main'
        selectedReason = 'mismatch_test'
        generatedUtc = $nowUtc.AddSeconds(-30).ToString('o')
        allowed = $false
        latestActivityResult = [ordered]@{ narrativeDetails = 'ok'; handoffTrail = @('t'); mutationApplied = $false }
        proposedActivity = [ordered]@{ inputs = @{}; expectedOutputs = @{}; handoffTrail = @('t') }
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $c9Dir 'BlacksmithGuild_CampaignGovernorDecision.json') -Encoding UTF8

    $pkt9Path = & $generatorScript -SessionDir $c9Dir -RepoRoot $RepoRoot
    $pkt9 = Get-Content -LiteralPath $pkt9Path -Raw | ConvertFrom-Json
    $adm9 = Resolve-LiveProofAdmission $pkt9
    if ($adm9.terminalState -eq 'FAIL_CORRELATION_MISMATCH') { Add-TestPass 'Case 9: Mismatched decision session ID -> FAIL_CORRELATION_MISMATCH' }
    else { Add-TestFail "Case 9 failed: got $($adm9.terminalState)" }

    # Case 10: Contradictory state (gameProcessObserved=false, campaignAttached=false) -> FAIL_GAME_PROCESS_NOT_OBSERVED
    $c10Case = [pscustomobject][ordered]@{
        mode = 'live_fresh_launch'
        skipLaunch = $false
        launchRequested = $true
        launchAttempted = $true
        launcherProcessObserved = $true
        launcherHwndObserved = $true
        launchActionDispatched = $true
        gameProcessObserved = $false
        campaignAttached = $false
    }
    $adm10 = Resolve-LiveProofAdmission $c10Case
    if ($adm10.terminalState -eq 'FAIL_GAME_PROCESS_NOT_OBSERVED') { Add-TestPass 'Case 10: Contradictory state (game=false, attach=false) -> FAIL_GAME_PROCESS_NOT_OBSERVED' }
    else { Add-TestFail "Case 10 failed: got $($adm10.terminalState)" }

    # Case 11: Final Sentinel Execution Marker
    Add-TestPass 'Case 11: Final sentinel execution marker reached'

} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "`nGovernor proof packet unit tests: $passes passed, $($failures.Count) failed" -ForegroundColor $(if ($failures.Count -eq 0) { 'Green' } else { 'Red' })
if ($failures.Count -gt 0) { exit 1 }
exit 0
