<#
.SYNOPSIS
    Repo-owned workflow runner for Blacksmith Guild product proofs.

.DESCRIPTION
    This script is intentionally compact and artifact-driven. It runs a named workflow,
    then emits artifacts/latest/<workflow>.result.json for AI handoff and PR review.

    The first supported workflow is route-visible-start.

    This is not a generic collector. It summarizes product behavior.
#>
param(
    [ValidateSet('route-visible-start')]
    [string]$Workflow = 'route-visible-start',

    [string]$TargetSettlement = 'Quyaz',

    [string]$BannerlordRoot = 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord',

    [switch]$SummarizeOnly,

    [switch]$VerboseLogs
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot

$latestDir = Join-Path $repoRoot 'artifacts\latest'
New-Item -ItemType Directory -Force -Path $latestDir | Out-Null

$resultPath = Join-Path $latestDir "$Workflow.result.json"
$startedAtUtc = (Get-Date).ToUniversalTime().ToString('o')

function Write-ResultJson {
    param([object]$Object)
    $Object | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resultPath -Encoding UTF8
}

function Read-JsonOrNull {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try { return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
    catch { return $null }
}

function Get-Value {
    param(
        [object]$Object,
        [string[]]$Path,
        $Default = $null
    )

    $current = $Object
    foreach ($part in $Path) {
        if ($null -eq $current) { return $Default }
        $property = $current.PSObject.Properties[$part]
        if ($null -eq $property) { return $Default }
        $current = $property.Value
    }

    if ($null -eq $current) { return $Default }
    return $current
}

function Convert-ToBool {
    param($Value)
    if ($Value -is [bool]) { return $Value }
    if ($null -eq $Value) { return $false }
    return [System.Convert]::ToBoolean($Value)
}

function Find-InstalledDll {
    param([string]$Root)

    $candidates = @(
        (Join-Path $Root 'Modules\BlacksmithGuild\bin\Win64_Shipping_Client\BlacksmithGuild.dll'),
        (Join-Path $Root 'Modules\BlacksmithGuild\bin\Gaming.Desktop.x64_Shipping_Client\BlacksmithGuild.dll')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            $item = Get-Item -LiteralPath $candidate
            return [ordered]@{
                path = $item.FullName
                lastWrite = $item.LastWriteTimeUtc.ToString('o')
                size = $item.Length
            }
        }
    }

    return [ordered]@{ path = $null; lastWrite = $null; size = $null }
}

function Get-BranchName {
    try { return (git branch --show-current).Trim() } catch { return $null }
}

function Get-CommitSha {
    try { return (git rev-parse --short HEAD).Trim() } catch { return $null }
}

function New-BaseResult {
    param([string]$Phase = 'stop')

    return [ordered]@{
        workflow = $Workflow
        commit = Get-CommitSha
        branch = Get-BranchName
        targetSettlement = $TargetSettlement
        startedAtUtc = $startedAtUtc
        finishedAtUtc = $null
        verdict = 'FAIL'
        phase = $Phase
        blockedReason = $null
        nextPatchHint = $null
        installedDll = Find-InstalledDll -Root $BannerlordRoot
        runtime = [ordered]@{
            statusFound = $false
            campaignReady = $false
            mapStateActive = $false
            safeToExecuteTravel = $false
            timePaused = $null
            targetSettlement = $null
            nextPlannedBranch = $null
            nextActionReason = $null
        }
        route = [ordered]@{
            certFound = $false
            certPath = $null
            destinationSettlement = $null
            targetSettlementId = $null
            travelCommandIssued = $false
            routeStarted = $false
            runtimeProofClaim = $null
            blockedReason = $null
            state = $null
        }
        files = [ordered]@{
            status = Join-Path $BannerlordRoot 'BlacksmithGuild_Status.json'
            routeCert = Join-Path $BannerlordRoot 'BlacksmithGuild_MapTradeRouteCert.json'
            legacyMapTradeCert = Join-Path $BannerlordRoot 'BlacksmithGuild_MapTradeCert.json'
            commandAck = Join-Path $BannerlordRoot 'BlacksmithGuild_CommandAck.json'
            phaseLog = Join-Path $BannerlordRoot 'BlacksmithGuild_Phase1.log'
        }
        tool = [ordered]@{
            forgeStopExitCode = $null
            forgeRebootExitCode = $null
            note = $null
        }
    }
}

function Add-RuntimeSummary {
    param([hashtable]$Result)

    $status = Read-JsonOrNull -Path $Result.files.status
    if ($null -ne $status) {
        $Result.runtime.statusFound = $true
        $Result.runtime.campaignReady = Convert-ToBool (Get-Value $status @('campaignReady') $false)
        $Result.runtime.mapStateActive = Convert-ToBool (Get-Value $status @('session','mapStateActive') (Get-Value $status @('stateMachine','isMapStateActive') $false))
        $Result.runtime.safeToExecuteTravel = Convert-ToBool (Get-Value $status @('stateMachine','safeToExecuteTravel') $false)
        $Result.runtime.timePaused = Get-Value $status @('session','timePaused') $null
        $Result.runtime.targetSettlement = Get-Value $status @('recursiveBranchState','targetSettlement') $null
        $Result.runtime.nextPlannedBranch = Get-Value $status @('recursiveBranchState','nextPlannedBranch') $null
        $Result.runtime.nextActionReason = Get-Value $status @('recursiveBranchState','nextActionReason') $null
    }

    $routeCertPath = $Result.files.routeCert
    $cert = Read-JsonOrNull -Path $routeCertPath
    if ($null -eq $cert) {
        $routeCertPath = $Result.files.legacyMapTradeCert
        $cert = Read-JsonOrNull -Path $routeCertPath
    }

    if ($null -ne $cert) {
        $Result.route.certFound = $true
        $Result.route.certPath = $routeCertPath
        $Result.route.destinationSettlement = Get-Value $cert @('destinationSettlement') (Get-Value $cert @('mission','targetSettlementName') $null)
        $Result.route.targetSettlementId = Get-Value $cert @('targetSettlementId') $null
        $Result.route.state = Get-Value $cert @('state') $null
        $Result.route.runtimeProofClaim = Get-Value $cert @('runtimeProofClaim') (Get-Value $cert @('routeClockEvidence','runtimeProofClaim') $null)
        $Result.route.blockedReason = Get-Value $cert @('blockedReason') $null

        $explicitTravelCommandIssued = Get-Value $cert @('travelCommandIssued') $null
        $explicitRouteStarted = Get-Value $cert @('routeStarted') $null
        $state = [string]$Result.route.state
        $steps = @(Get-Value $cert @('steps') @())
        $hasTravelStep = @($steps | Where-Object { [string]$_ -like 'TravelToTarget:*' }).Count -gt 0

        $Result.route.travelCommandIssued = if ($null -ne $explicitTravelCommandIssued) {
            Convert-ToBool $explicitTravelCommandIssued
        } else {
            $state -in @('TravelToTarget','WaitForArrival','EnterSettlement','ExecuteTrade','ForgeHandoff','Complete') -or $hasTravelStep
        }

        $Result.route.routeStarted = if ($null -ne $explicitRouteStarted) {
            Convert-ToBool $explicitRouteStarted
        } else {
            $Result.route.travelCommandIssued
        }
    }
}

function Set-ResultVerdict {
    param([hashtable]$Result)

    if (-not $Result.runtime.statusFound) {
        $Result.verdict = 'BLOCKED'
        $Result.phase = 'map-ready'
        $Result.blockedReason = 'status file missing'
        $Result.nextPatchHint = 'Launch/map-ready workflow did not produce BlacksmithGuild_Status.json. Fix launch or wait phase before route logic.'
        return
    }

    if (-not $Result.runtime.campaignReady) {
        $Result.verdict = 'BLOCKED'
        $Result.phase = 'map-ready'
        $Result.blockedReason = 'campaignReady is false'
        $Result.nextPatchHint = 'Inspect campaign lifecycle and map-ready gating.'
        return
    }

    if (-not $Result.runtime.mapStateActive) {
        $Result.verdict = 'BLOCKED'
        $Result.phase = 'map-ready'
        $Result.blockedReason = 'mapStateActive is false'
        $Result.nextPatchHint = 'Game reached a non-map surface. Fix surface transition or launch target.'
        return
    }

    if (-not $Result.runtime.safeToExecuteTravel) {
        $Result.verdict = 'BLOCKED'
        $Result.phase = 'runtime-action'
        $Result.blockedReason = 'safeToExecuteTravel is false'
        $Result.nextPatchHint = 'Inspect GameSessionState and travel safety classifier.'
        return
    }

    if ($Result.runtime.nextPlannedBranch -ne 'travel') {
        $Result.verdict = 'BLOCKED'
        $Result.phase = 'runtime-action'
        $Result.blockedReason = 'nextPlannedBranch is not travel'
        $Result.nextPatchHint = 'Inspect recursive branch selector and route council target emission.'
        return
    }

    if ([string]::IsNullOrWhiteSpace([string]$Result.runtime.targetSettlement)) {
        $Result.verdict = 'BLOCKED'
        $Result.phase = 'runtime-action'
        $Result.blockedReason = 'targetSettlement missing'
        $Result.nextPatchHint = 'Inspect route council or branch state target emission.'
        return
    }

    if (-not $Result.route.certFound) {
        $Result.verdict = 'BLOCKED'
        $Result.phase = 'runtime-action'
        $Result.blockedReason = 'route cert missing after map-ready'
        $Result.nextPatchHint = 'In-mod route executor did not start or did not write a route cert. Inspect MapTradeAutonomousService.OnCampaignTick.'
        return
    }

    if (-not $Result.route.travelCommandIssued) {
        $Result.verdict = 'BLOCKED'
        $Result.phase = 'runtime-action'
        $Result.blockedReason = 'travelCommandIssued is false'
        $Result.nextPatchHint = 'Movement driver did not accept the command. Inspect CampaignMapMovementHelper.TryMoveToSettlement.'
        return
    }

    if (-not $Result.route.routeStarted) {
        $Result.verdict = 'BLOCKED'
        $Result.phase = 'runtime-action'
        $Result.blockedReason = 'routeStarted is false'
        $Result.nextPatchHint = 'Cert exists, but route service did not claim start. Inspect route cert model and writer.'
        return
    }

    $Result.verdict = 'PASS'
    $Result.phase = 'done'
    $Result.blockedReason = $null
    $Result.nextPatchHint = 'Route start accepted. Next proof can measure destination progression or arrival.'
}

$result = New-BaseResult -Phase 'stop'

try {
    if (-not $SummarizeOnly) {
        $env:FORGE_NO_PAUSE = '1'
        $env:FORGE_STOP_CHOICE = 'F'

        Write-Host '== TBG WORKFLOW: stop game =='
        cmd /c .\ForgeStop.cmd force
        $result.tool.forgeStopExitCode = $LASTEXITCODE

        Write-Host '== TBG WORKFLOW: launch route-visible-start path =='
        $result.phase = 'launch'
        Write-ResultJson $result

        cmd /c .\ForgeReboot.cmd -MaxIterations 1 -LaunchIntent continue -ActionTimeoutClass long_distance_travel
        $result.tool.forgeRebootExitCode = $LASTEXITCODE
    }
    else {
        $result.tool.note = 'SummarizeOnly enabled. No stop/build/install/launch was run.'
    }

    $result.phase = 'summarize'
    $result.installedDll = Find-InstalledDll -Root $BannerlordRoot
    Add-RuntimeSummary -Result $result
    Set-ResultVerdict -Result $result
    $result.finishedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    Write-ResultJson $result

    Write-Host "TBG workflow verdict: $($result.verdict)"
    if ($result.blockedReason) { Write-Host "Blocked: $($result.blockedReason)" }
    Write-Host "Result: $resultPath"

    if ($result.verdict -eq 'PASS') { exit 0 }
    if ($result.verdict -eq 'BLOCKED') { exit 2 }
    exit 1
}
catch {
    $result.verdict = 'FAIL'
    $result.blockedReason = $_.Exception.Message
    $result.nextPatchHint = 'Fix the workflow runner or environment before patching route runtime behavior.'
    $result.finishedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    Write-ResultJson $result
    Write-Host "TBG workflow failed: $($result.blockedReason)" -ForegroundColor Red
    Write-Host "Result: $resultPath"
    exit 1
}
