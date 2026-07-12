param(
    [string]$ExpectedHead = $null,
    [int]$AttachTimeoutSec = 600,
    [int]$ProofTimeoutSec = 180,
    [int]$PollIntervalMs = 500,
    [switch]$SkipBuild,
    [switch]$SkipLaunch,
    [switch]$SkipSaveBackup,
    [string]$EvidenceRoot = $null
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $repoRoot
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')

$runId = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss-fff')
if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) {
    $EvidenceRoot = Join-Path $repoRoot 'artifacts\maptrade-branch-autostart-proof'
}
$runDir = Join-Path $EvidenceRoot $runId
$resultPath = Join-Path $runDir 'result.json'
New-Item -ItemType Directory -Force -Path $runDir | Out-Null

function Read-JsonSafe {
    param([Parameter(Mandatory = $true)][string]$Path)

    for ($attempt = 1; $attempt -le 5; $attempt++) {
        try {
            if (Test-Path -LiteralPath $Path) {
                return Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            }
        } catch {
            Start-Sleep -Milliseconds (100 * $attempt)
        }
    }

    return $null
}

function Get-FirstExistingPath {
    param([string[]]$Candidates)
    return @($Candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1)[0]
}

function Invoke-ForgeCommandChecked {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [int]$TimeoutSec = 45
    )

    & (Join-Path $repoRoot 'forge.ps1') -Command $Command -Wait -TimeoutSec $TimeoutSec
    if ($LASTEXITCODE -ne 0) {
        throw "Forge command failed: $Command (exit $LASTEXITCODE)"
    }
}

function Get-GameProcesses {
    $names = @('Bannerlord', 'Bannerlord.Native', 'TaleWorlds.MountAndBlade', 'TaleWorlds.MountAndBlade.Launcher')
    $items = @()
    foreach ($name in $names) {
        $items += @(Get-Process -Name $name -ErrorAction SilentlyContinue)
    }
    return @($items | Sort-Object Id -Unique)
}

function Save-Result {
    param([Parameter(Mandatory = $true)]$Value)
    $json = $Value | ConvertTo-Json -Depth 30
    $encoding = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($resultPath, $json, $encoding)
}

$branch = (git branch --show-current).Trim()
$head = (git rev-parse HEAD).Trim()
$status = @(git status --porcelain)
$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot
$docsRoot = Join-Path $env:USERPROFILE 'Documents\Mount and Blade II Bannerlord'
$statusPath = $null
$certPath = Join-Path $bannerlordRoot 'BlacksmithGuild_MapTradeCert.json'
$startedAtUtc = (Get-Date).ToUniversalTime()
$modeCommandStartedUtc = $null
$target = $null
$surface = $null
$cert = $null
$cleanup = [ordered]@{ attempted = $false; manualCommandPassed = $false; terminalState = $null }
$checks = [ordered]@{
    exactHead = $false
    cleanWorktree = $false
    buildPassed = $false
    installedDllHashMatches = $false
    settlementMenuReady = $false
    recursiveTravelTargetReady = $false
    targetedAutomationCommandPassed = $false
    freshCert = $false
    exactAutostartSource = $false
    exactTarget = $false
    authorityAutomation = $false
    routeStarted = $false
    sameTickReturnObserved = $false
    sameTickHoldAbsent = $false
    movementObserved = $false
    positivePartyDistance = $false
    runtimeProofClaim = $false
    manualCleanupPassed = $false
}
$failureClass = $null
$failureDetail = $null
$localDllPath = Join-Path $repoRoot 'Module\BlacksmithGuild\bin\Win64_Shipping_Client\BlacksmithGuild.dll'
$installedDllPath = Join-Path $bannerlordRoot 'Modules\BlacksmithGuild\bin\Win64_Shipping_Client\BlacksmithGuild.dll'
$localDllHash = $null
$installedDllHash = $null

try {
    if ($ExpectedHead -and -not [string]::Equals($head, $ExpectedHead, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "wrong_head expected=$ExpectedHead actual=$head"
    }
    $checks.exactHead = $true

    if ($status.Count -gt 0) {
        throw "dirty_worktree: $($status -join '; ')"
    }
    $checks.cleanWorktree = $true

    if (-not $SkipBuild) {
        if (@(Get-GameProcesses).Count -gt 0) {
            throw 'preexisting_game_process_before_build'
        }

        & dotnet build (Join-Path $repoRoot 'src\BlacksmithGuild\BlacksmithGuild.csproj') -c Release
        if ($LASTEXITCODE -ne 0) { throw "release_build_failed exit=$LASTEXITCODE" }
        & (Join-Path $PSScriptRoot 'install-mod.ps1')
        if ($LASTEXITCODE -ne 0) { throw "install_failed exit=$LASTEXITCODE" }
    }
    $checks.buildPassed = $true

    if (-not (Test-Path -LiteralPath $localDllPath)) { throw "local_dll_missing:$localDllPath" }
    if (-not (Test-Path -LiteralPath $installedDllPath)) { throw "installed_dll_missing:$installedDllPath" }
    $localDllHash = (Get-FileHash -LiteralPath $localDllPath -Algorithm SHA256).Hash
    $installedDllHash = (Get-FileHash -LiteralPath $installedDllPath -Algorithm SHA256).Hash
    if (-not [string]::Equals($localDllHash, $installedDllHash, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "installed_dll_hash_mismatch local=$localDllHash installed=$installedDllHash"
    }
    $checks.installedDllHashMatches = $true

    if (-not $SkipLaunch) {
        $launchArgs = @{
            LaunchIntent = 'continue'
            RepoRoot = $repoRoot
            TimeoutSec = $AttachTimeoutSec
        }
        if ($SkipSaveBackup) { $launchArgs.SkipSaveBackup = $true }
        & (Join-Path $PSScriptRoot 'invoke-forge-launch-operator.ps1') @launchArgs
        if ($LASTEXITCODE -ne 0) { throw "continue_launch_failed exit=$LASTEXITCODE" }
    } elseif (@(Get-GameProcesses).Count -eq 0) {
        throw 'skip_launch_requested_but_game_not_running'
    }

    $attachDeadline = (Get-Date).AddSeconds($AttachTimeoutSec)
    while ((Get-Date) -lt $attachDeadline) {
        $statusPath = Get-FirstExistingPath -Candidates @(
            (Join-Path $bannerlordRoot 'BlacksmithGuild_Status.json'),
            (Join-Path $docsRoot 'BlacksmithGuild_Status.json')
        )
        if ($statusPath) {
            $runtimeStatus = Read-JsonSafe -Path $statusPath
            if ($runtimeStatus) {
                $surface = [string]$runtimeStatus.stateMachine.gameplaySurface
                $recursive = $runtimeStatus.recursiveBranchState
                $candidateTarget = [string]$recursive.targetSettlement
                $currentName = [string]$runtimeStatus.stateMachine.settlementName
                $ready = $surface -eq 'settlement_menu' `
                    -and $recursive.safeToExecuteTravel -eq $true `
                    -and [string]$recursive.nextPlannedBranch -eq 'travel' `
                    -and -not [string]::IsNullOrWhiteSpace($candidateTarget) `
                    -and -not [string]::Equals($candidateTarget, $currentName, [System.StringComparison]::OrdinalIgnoreCase)
                if ($ready) {
                    $target = $candidateTarget
                    $checks.settlementMenuReady = $true
                    $checks.recursiveTravelTargetReady = $true
                    break
                }
            }
        }
        Start-Sleep -Milliseconds ([Math]::Max(250, $PollIntervalMs))
    }

    if (-not $checks.recursiveTravelTargetReady) {
        throw "town_menu_recursive_target_not_ready surface=$surface status=$statusPath"
    }

    $baselineCertWriteUtc = if (Test-Path -LiteralPath $certPath) {
        (Get-Item -LiteralPath $certPath).LastWriteTimeUtc
    } else {
        [datetime]::MinValue
    }

    $modeCommandStartedUtc = (Get-Date).ToUniversalTime()
    Invoke-ForgeCommandChecked -Command 'SetMapTradeAutomation' -TimeoutSec 45
    $checks.targetedAutomationCommandPassed = $true

    $proofDeadline = (Get-Date).AddSeconds($ProofTimeoutSec)
    while ((Get-Date) -lt $proofDeadline) {
        if (Test-Path -LiteralPath $certPath) {
            $certItem = Get-Item -LiteralPath $certPath
            if ($certItem.LastWriteTimeUtc -gt $baselineCertWriteUtc -and $certItem.LastWriteTimeUtc -ge $modeCommandStartedUtc) {
                $candidate = Read-JsonSafe -Path $certPath
                if ($candidate) {
                    $cert = $candidate
                    $checks.freshCert = $true
                    $checks.exactAutostartSource = [string]$cert.source -eq 'campaign_tick_recursive_branch_travel'
                    $checks.exactTarget = [string]$cert.destinationSettlement -eq $target `
                        -or [string]$cert.mission.targetSettlementName -eq $target
                    $checks.authorityAutomation = [string]$cert.routeClockEvidence.authorityMode -eq 'Automation'
                    $checks.routeStarted = $cert.routeStarted -eq $true -and $cert.travelCommandIssued -eq $true
                    $checks.sameTickReturnObserved = $cert.autoStartTickReturnObserved -eq $true
                    $checks.sameTickHoldAbsent = $cert.sameTickHoldObserved -eq $false
                    $checks.movementObserved = $cert.movementObserved -eq $true
                    $checks.positivePartyDistance = [double]$cert.partyMovedDistance -gt 0
                    $checks.runtimeProofClaim = $cert.routeClockEvidence.runtimeProofClaim -eq $true

                    $required = @(
                        $checks.exactAutostartSource,
                        $checks.exactTarget,
                        $checks.authorityAutomation,
                        $checks.routeStarted,
                        $checks.sameTickReturnObserved,
                        $checks.sameTickHoldAbsent,
                        $checks.movementObserved,
                        $checks.positivePartyDistance,
                        $checks.runtimeProofClaim
                    )
                    if (@($required | Where-Object { -not $_ }).Count -eq 0) { break }
                }
            }
        }
        Start-Sleep -Milliseconds ([Math]::Max(250, $PollIntervalMs))
    }

    $proofFailures = @($checks.GetEnumerator() | Where-Object {
        $_.Key -notin @('manualCleanupPassed') -and $_.Value -ne $true
    } | ForEach-Object { $_.Key })
    if ($proofFailures.Count -gt 0) {
        throw "proof_checks_failed:$($proofFailures -join ',')"
    }
}
catch {
    $failureDetail = $_.Exception.Message
    $failureClass = ([string]$failureDetail -split '[: ]')[0]
}
finally {
    $cleanup.attempted = $true
    try {
        if (@(Get-GameProcesses).Count -gt 0) {
            Invoke-ForgeCommandChecked -Command 'SetMapTradeManual' -TimeoutSec 45
            $cleanup.manualCommandPassed = $true
            Start-Sleep -Milliseconds 750
            try { Invoke-ForgeCommandChecked -Command 'ShowMapTradeRouteStatus' -TimeoutSec 30 } catch { }
            $terminalCert = Read-JsonSafe -Path $certPath
            $cleanup.terminalState = [string]$terminalCert.state
        } else {
            $cleanup.terminalState = 'game_not_running'
        }
    } catch {
        $cleanup.error = $_.Exception.Message
    }
    $checks.manualCleanupPassed = $cleanup.manualCommandPassed -eq $true
}

$proofPassed = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true }).Count -eq 0
if (-not $proofPassed -and -not $failureClass) {
    $failureClass = 'terminal_checks_failed'
    $failureDetail = 'One or more required proof or cleanup checks did not pass.'
}

$result = [ordered]@{
    schemaVersion = 'TbgMapTradeBranchAutostartProof.v1'
    runId = $runId
    startedAtUtc = $startedAtUtc.ToString('o')
    endedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    repo = 'EndeavorEverlasting/BlacksmithGuild'
    branch = $branch
    headSha = $head
    worktreeStatus = @($status)
    bannerlordRoot = $bannerlordRoot
    statusPath = $statusPath
    certPath = $certPath
    localDllPath = $localDllPath
    installedDllPath = $installedDllPath
    localDllSha256 = $localDllHash
    installedDllSha256 = $installedDllHash
    gameplaySurface = $surface
    recursiveTarget = $target
    targetedModeCommand = 'SetMapTradeAutomation'
    terminalModeCommand = 'SetMapTradeManual'
    checks = $checks
    cleanup = $cleanup
    passFail = if ($proofPassed) { 'PASS' } else { 'FAIL' }
    failureClass = $failureClass
    failureDetail = $failureDetail
    allowedClaims = if ($proofPassed) {
        @('Exact recursive-branch MapTrade autostart returned before same-tick menu hold and produced positive party movement from the tested DLL/head.')
    } else {
        @('The runner completed with a terminal classification; inspect individual checks.')
    }
    forbiddenClaims = if ($proofPassed) {
        @('This does not prove named-save identity, arrival, trade completion, or visible marketplace UI.')
    } else {
        @('Do not claim exact-path MapTrade movement PASS.', 'Do not substitute historical evidence for failed fresh checks.')
    }
    cert = $cert
}
Save-Result -Value $result

Write-Host "MapTrade branch autostart proof: $($result.passFail)"
Write-Host "result: $resultPath"
if (-not $proofPassed) {
    Write-Host "failure: $failureClass - $failureDetail" -ForegroundColor Red
    exit 2
}

exit 0
