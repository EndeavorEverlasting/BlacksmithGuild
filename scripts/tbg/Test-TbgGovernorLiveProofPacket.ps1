[CmdletBinding()]
param(
    [string]$RepoRoot = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

. (Join-Path $PSScriptRoot 'Test-TbgLiveRuntimeProofAdmission.ps1')

$failures = New-Object System.Collections.Generic.List[string]
$passes = 0

function Add-TestPass([string]$Message) {
    $script:passes++
    Write-Host "PASS: $Message" -ForegroundColor Green
}
function Add-TestFail([string]$Message) {
    $script:failures.Add($Message) | Out-Null
    Write-Host "FAIL: $Message" -ForegroundColor Red
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("tbg-proof-packet-test-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

try {
    $generatorScript = Join-Path $PSScriptRoot 'New-TbgGovernorLiveProofPacket.ps1'
    if (-not (Test-Path -LiteralPath $generatorScript -PathType Leaf)) {
        throw "Missing generator script: $generatorScript"
    }

    $nowUtc = [datetime]::UtcNow

    # Case 1: Complete valid packet -> expect PASS_LIVE_RUNTIME
    $c1Dir = Join-Path $tempRoot 'case1_valid'
    New-Item -ItemType Directory -Force -Path $c1Dir | Out-Null

    [ordered]@{
        sessionId = '20260725-150000'
        testStartUtc = $nowUtc.AddMinutes(-2).ToString('o')
        bootstrapUsed = $false
        skipLaunch = $false
        mode = 'live_fresh_launch'
        cycleId = 'cycle-123'
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c1Dir 'governor-smoke-summary.json') -Encoding UTF8

    [ordered]@{
        processId = 1234
        hwnd = 5678
        launchActionDispatched = $true
        mode = 'LaunchSetup'
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c1Dir 'launcher-window-context.json') -Encoding UTF8

    [ordered]@{
        processId = 9999
        updatedAt = $nowUtc.AddMinutes(-1).ToString('o')
        campaignReady = $true
        lastCommandAck = 'RunCampaignGovernorCycleNow'
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c1Dir 'BlacksmithGuild_Status.json') -Encoding UTF8

    [ordered]@{
        cycleId = 'cycle-123'
        selectedBranch = 'main'
        selectedReason = 'test'
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

    # Case 2: SkipLaunch -> expect BLOCKED_LIVE_MODE_SKIP_LAUNCH
    $c2Dir = Join-Path $tempRoot 'case2_skip_launch'
    New-Item -ItemType Directory -Force -Path $c2Dir | Out-Null
    [ordered]@{
        sessionId = '20260725-150001'
        testStartUtc = $nowUtc.AddMinutes(-2).ToString('o')
        skipLaunch = $true
        mode = 'live_fresh_launch'
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c2Dir 'governor-smoke-summary.json') -Encoding UTF8

    $pkt2Path = & $generatorScript -SessionDir $c2Dir -RepoRoot $RepoRoot
    $pkt2 = Get-Content -LiteralPath $pkt2Path -Raw | ConvertFrom-Json
    $adm2 = Resolve-LiveProofAdmission $pkt2
    if ($adm2.terminalState -eq 'BLOCKED_LIVE_MODE_SKIP_LAUNCH') { Add-TestPass 'Case 2: SkipLaunch -> BLOCKED_LIVE_MODE_SKIP_LAUNCH' }
    else { Add-TestFail "Case 2 failed: got $($adm2.terminalState)" }

    # Case 3: Missing launcher HWND -> expect FAIL_LAUNCHER_HWND_NOT_BOUND
    $c3Dir = Join-Path $tempRoot 'case3_no_hwnd'
    New-Item -ItemType Directory -Force -Path $c3Dir | Out-Null
    [ordered]@{
        sessionId = '20260725-150002'
        testStartUtc = $nowUtc.AddMinutes(-2).ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c3Dir 'governor-smoke-summary.json') -Encoding UTF8

    [ordered]@{
        processId = 1234
        hwnd = 0
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c3Dir 'launcher-window-context.json') -Encoding UTF8

    $pkt3Path = & $generatorScript -SessionDir $c3Dir -RepoRoot $RepoRoot
    $pkt3 = Get-Content -LiteralPath $pkt3Path -Raw | ConvertFrom-Json
    $adm3 = Resolve-LiveProofAdmission $pkt3
    if ($adm3.terminalState -eq 'FAIL_LAUNCHER_HWND_NOT_BOUND') { Add-TestPass 'Case 3: missing HWND -> FAIL_LAUNCHER_HWND_NOT_BOUND' }
    else { Add-TestFail "Case 3 failed: got $($adm3.terminalState)" }

    # Case 4: Game process not observed -> expect FAIL_GAME_PROCESS_NOT_OBSERVED
    $c4Dir = Join-Path $tempRoot 'case4_no_game'
    New-Item -ItemType Directory -Force -Path $c4Dir | Out-Null
    [ordered]@{
        sessionId = '20260725-150003'
        testStartUtc = $nowUtc.AddMinutes(-2).ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c4Dir 'governor-smoke-summary.json') -Encoding UTF8

    [ordered]@{
        processId = 1234
        hwnd = 5678
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c4Dir 'launcher-window-context.json') -Encoding UTF8

    $pkt4Path = & $generatorScript -SessionDir $c4Dir -RepoRoot $RepoRoot
    $pkt4 = Get-Content -LiteralPath $pkt4Path -Raw | ConvertFrom-Json
    $adm4 = Resolve-LiveProofAdmission $pkt4
    if ($adm4.terminalState -eq 'FAIL_GAME_PROCESS_NOT_OBSERVED') { Add-TestPass 'Case 4: game not spawned -> FAIL_GAME_PROCESS_NOT_OBSERVED' }
    else { Add-TestFail "Case 4 failed: got $($adm4.terminalState)" }

    # Case 5: ACK without decision -> expect FAIL_BEHAVIOR_NOT_OBSERVED
    $c5Dir = Join-Path $tempRoot 'case5_ack_no_decision'
    New-Item -ItemType Directory -Force -Path $c5Dir | Out-Null
    [ordered]@{
        sessionId = '20260725-150004'
        testStartUtc = $nowUtc.AddMinutes(-2).ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c5Dir 'governor-smoke-summary.json') -Encoding UTF8

    [ordered]@{
        processId = 1234
        hwnd = 5678
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c5Dir 'launcher-window-context.json') -Encoding UTF8

    [ordered]@{
        processId = 9999
        updatedAt = $nowUtc.AddMinutes(-1).ToString('o')
        campaignReady = $true
        lastCommandAck = 'RunCampaignGovernorCycleNow'
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c5Dir 'BlacksmithGuild_Status.json') -Encoding UTF8

    $pkt5Path = & $generatorScript -SessionDir $c5Dir -RepoRoot $RepoRoot
    $pkt5 = Get-Content -LiteralPath $pkt5Path -Raw | ConvertFrom-Json
    $adm5 = Resolve-LiveProofAdmission $pkt5
    if ($adm5.terminalState -eq 'FAIL_BEHAVIOR_NOT_OBSERVED') { Add-TestPass 'Case 5: ACK without decision -> FAIL_BEHAVIOR_NOT_OBSERVED' }
    else { Add-TestFail "Case 5 failed: got $($adm5.terminalState)" }

    # Case 6: Stale decision artifact -> expect FAIL_STALE_EVIDENCE
    $c6Dir = Join-Path $tempRoot 'case6_stale_decision'
    New-Item -ItemType Directory -Force -Path $c6Dir | Out-Null
    [ordered]@{
        sessionId = '20260725-150005'
        testStartUtc = $nowUtc.AddMinutes(-2).ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c6Dir 'governor-smoke-summary.json') -Encoding UTF8

    [ordered]@{
        processId = 1234
        hwnd = 5678
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c6Dir 'launcher-window-context.json') -Encoding UTF8

    [ordered]@{
        processId = 9999
        updatedAt = $nowUtc.AddMinutes(-1).ToString('o')
        campaignReady = $true
        lastCommandAck = 'RunCampaignGovernorCycleNow'
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c6Dir 'BlacksmithGuild_Status.json') -Encoding UTF8

    [ordered]@{
        cycleId = 'cycle-old'
        selectedBranch = 'main'
        selectedReason = 'test'
        generatedUtc = $nowUtc.AddDays(-1).ToString('o') # STALE
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $c6Dir 'BlacksmithGuild_CampaignGovernorDecision.json') -Encoding UTF8

    $pkt6Path = & $generatorScript -SessionDir $c6Dir -RepoRoot $RepoRoot
    $pkt6 = Get-Content -LiteralPath $pkt6Path -Raw | ConvertFrom-Json
    $adm6 = Resolve-LiveProofAdmission $pkt6
    if ($adm6.terminalState -eq 'FAIL_STALE_EVIDENCE' -or $adm6.terminalState -eq 'FAIL_BEHAVIOR_NOT_OBSERVED') { Add-TestPass 'Case 6: stale decision -> FAIL_STALE_EVIDENCE/FAIL_BEHAVIOR_NOT_OBSERVED' }
    else { Add-TestFail "Case 6 failed: got $($adm6.terminalState)" }

} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "`nGovernor proof packet unit tests: $passes passed, $($failures.Count) failed" -ForegroundColor $(if ($failures.Count -eq 0) { 'Green' } else { 'Red' })
if ($failures.Count -gt 0) { exit 1 }
exit 0
