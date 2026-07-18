<#
.SYNOPSIS
Readiness trigger: watches Phase1.log for campaign map readiness,
then auto-dispatches a command and collects evidence.
#>
param(
    [string]$Command = 'RunAutonomousVisibleTradeRouteNow',
    [int]$ReadyTimeoutSec = 120,
    [int]$AckTimeoutSec = 120,
    [int]$PollMs = 2000,
    [string]$BannerlordRoot = 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord',
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$phase1Path = Join-Path $BannerlordRoot 'BlacksmithGuild_Phase1.log'
$inboxPath = Join-Path $BannerlordRoot 'BlacksmithGuild_CommandInbox.json'
$ackMatch = "consumed sequence=(\d+) command=${Command}"

$events = [System.Collections.Generic.List[string]]::new()
$startedAt = Get-Date

function Write-Event($msg) {
    $ts = [DateTime]::UtcNow.ToString('o')
    $entry = "[${ts}] ${msg}"
    Write-Host $entry
    $events.Add($entry)
}

Write-Event "TRIGGER START command=$Command pollMs=$PollMs readyTimeout=${ReadyTimeoutSec}s ackTimeout=${AckTimeoutSec}s"

# Phase 1: wait for campaign map readiness
Write-Event "PHASE 1: waiting for campaign map readiness..."
$readyDeadline = $startedAt.AddSeconds($ReadyTimeoutSec)
$mapReady = $false
$lastSurface = ''
$lastSyncSeq = 0

while ((Get-Date) -lt $readyDeadline) {
    if (-not (Test-Path -LiteralPath $phase1Path -PathType Leaf)) {
        Start-Sleep -Milliseconds $PollMs
        continue
    }
    $tail = Get-Content -LiteralPath $phase1Path -Tail 30 -Encoding UTF8

    # Detect campaign map readiness
    $readiness = $tail | Where-Object { $_ -match 'surface=map_surface.*mapReady=true.*sessionReady=true' }
    $phase = $tail | Where-Object { $_ -match '\[TBG STATUS\] snapshot phase=' }
    $campaignTick = $tail | Where-Object { $_ -match 'CampaignTick.*stage=ok' }

    if ($readiness) {
        $mapReady = $true
        $lastSurface = 'map_surface'
        Write-Event "MAP READY: $($readiness | Select-Object -Last 1)"
        break
    }
    if ($phase -and -not $mapReady) {
        $lastSurface = ($phase | Select-Object -Last 1 | Out-String).Trim()
        if ($lastSurface -match 'phase=MapPaused') { Write-Event "SURFACE: MapPaused - waiting for mapReady" }
        else { Write-Event "SURFACE: $lastSurface" }
    }

    Start-Sleep -Milliseconds $PollMs
}

if (-not $mapReady) {
    Write-Event "READINESS TIMEOUT after $ReadyTimeoutSec`s. Last surface: $lastSurface"
    $result = [pscustomobject]@{ verdict = 'TIMEOUT'; phase = 'readiness'; lastSurface = $lastSurface }
    if ($PassThru) { Write-Output $result }
    exit 1
}

# Phase 2: dispatch command
Write-Event "PHASE 2: dispatching command $Command"

$lastAckSeq = 0
$ackMatch = 'consumed sequence=(\d+)'
$acks = Select-String -LiteralPath $phase1Path -Pattern $ackMatch -Encoding UTF8
if ($acks) {
    $lastMatch = $acks[$acks.Count - 1]
    $lastAckSeq = [int]$lastMatch.Matches.Groups[1].Value
    Write-Event "Last consumed sequence: $lastAckSeq"
}

$newSeq = $lastAckSeq + 1
$inbox = @{ sequence = $newSeq; command = $Command; source = 'Test-TbgReadinessTrigger.ps1' }
$inbox | ConvertTo-Json | Set-Content -LiteralPath $inboxPath -Encoding UTF8
$dispatchTime = Get-Date
Write-Event "DISPATCHED: sequence=$newSeq command=$Command"

# Phase 3: wait for ACK
Write-Event "PHASE 3: waiting for command ACK (sequence=$newSeq)..."
$ackDeadline = $dispatchTime.AddSeconds($AckTimeoutSec)
$acked = $false
$ackResult = ''

while ((Get-Date) -lt $ackDeadline) {
    if (Test-Path -LiteralPath $phase1Path -PathType Leaf) {
        $tail = Get-Content -LiteralPath $phase1Path -Tail 20 -Encoding UTF8
        $ackLine = $tail | Where-Object { $_ -match "consumed sequence=${newSeq}" }
        if ($ackLine) {
            $acked = $true
            $ackResult = ($ackLine | Select-Object -Last 1)
            Write-Event "ACK RECEIVED: $ackResult"
            break
        }
        # Check for phase transitions
        $tradeStep = $tail | Where-Object { $_ -match 'ExecuteTrade|TravelToTarget|EnterSettlement|BuyPackAnimal' }
        if ($tradeStep) {
            Write-Event "TRADE PROGRESS: $($tradeStep | Select-Object -Last 1)"
        }
        # Check for crash
        $heartbeat = $tail | Where-Object { $_ -match 'CampaignTick|SyncForgeStatus' } | Select-Object -Last 1
        if (-not $heartbeat) {
            # possible stale
        }
    }
    Start-Sleep -Milliseconds $PollMs
}

# Phase 4: collect evidence
Write-Event "PHASE 4: collecting evidence"
$phase1Tail = $null
if (Test-Path -LiteralPath $phase1Path -PathType Leaf) {
    $phase1Tail = Get-Content -LiteralPath $phase1Path -Tail 30 -Encoding UTF8
}
$runtimeRegentPath = Join-Path $BannerlordRoot 'BlacksmithGuild_RuntimeRegent.json'
$regentContent = $null
if (Test-Path -LiteralPath $runtimeRegentPath -PathType Leaf) {
    $regentContent = Get-Content -LiteralPath $runtimeRegentPath -Raw -Encoding UTF8
}

Write-Event "ACKED: $acked  RESULT: $ackResult"

$result = [pscustomobject]@{
    schema = 'tbg.readiness-trigger.v1'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    command = $Command
    sequence = $newSeq
    verdict = if ($acked) { 'ACK' } else { 'NO_ACK' }
    mapReady = $mapReady
    acked = $acked
    ackDetail = $ackResult
    lastConsumedSeq = $lastAckSeq
    dispatchTime = $dispatchTime.ToString('o')
    phase1Tail = ($phase1Tail -join "`n")
    runtimeRegent = $regentContent
    events = $events.ToArray()
}

Write-Event "TRIGGER COMPLETE: verdict=$($result.verdict) acked=$acked"

if ($acked) {
    Write-Host "Verdict: ACK - command consumed" -ForegroundColor Green
} else {
    Write-Host "Verdict: NO_ACK - command not consumed within ${AckTimeoutSec}s" -ForegroundColor Red
}

$outputPath = Join-Path $RepoRoot 'artifacts\latest\readiness-trigger.result.json'
$result | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $outputPath -Encoding UTF8
Write-Host "Output: $outputPath"

if ($PassThru) { Write-Output $result }
exit $(if ($acked) { 0 } else { 1 })
