<#
.SYNOPSIS
  Priority engine: land-survive-purchase-travel-sell order against a live or
  read-only game session. Validates preconditions, detects stale surfaces, and
  dispatches the highest-priority autonomous command.

.DESCRIPTION
  Reads Phase1.log or regent evidence to detect the current campaign surface.
  Applies the priority formula: land, survive, purchase, travel, sell.
  Dispatches one decision and records the result.

  Safety rules:
  - Branch verification: after any git checkout, confirms branch matches expected.
  - Regent staleness: if CampaignRuntimeRegent age > 60 s, falls back to Phase1.log.
  - Campaign map readiness: uses Phase1.log surface=map_surface.*mapReady=true.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Land','Survive','Purchase','Travel','Sell')]
    [string]$Priority,

    [string]$RepoRoot = '',
    [string]$PhaseLogPath = 'BlacksmithGuild_Phase1.log',
    [string]$RegentPath = 'BlacksmithGuild_RuntimeRegent.json',
    [string]$CommandInboxPath = 'BlacksmithGuild_CommandInbox.json',
    [string]$OutputPath = 'artifacts/latest/priority-engine/priority-engine.result.json',
    [int]$RegentStalenessSeconds = 60,
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}
if (-not [IO.Path]::IsPathRooted($PhaseLogPath)) {
    $PhaseLogPath = Join-Path $RepoRoot $PhaseLogPath
}
if (-not [IO.Path]::IsPathRooted($RegentPath)) {
    $RegentPath = Join-Path $RepoRoot $RegentPath
}
if (-not [IO.Path]::IsPathRooted($CommandInboxPath)) {
    $CommandInboxPath = Join-Path $RepoRoot $CommandInboxPath
}
if (-not [IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $RepoRoot $OutputPath
}

$result = [ordered]@{
    schema = 'tbg.priority-engine.result.v1'
    timestamp = [DateTime]::UtcNow.ToString('o')
    priority = $Priority
    branch = ''
    surface = ''
    phase = ''
    surfaceSource = ''
    regentStale = $false
    settled = $false
    commandDispatched = $false
    decisionRecorded = $false
    events = [System.Collections.Generic.List[string]]::new()
}

function Add-Event([string]$Message) {
    $timestamp = [DateTime]::UtcNow.ToString('HH:mm:ss')
    $entry = "[$timestamp] $Message"
    $result.events.Add($entry)
    Write-Host $entry
}

function Test-FileFreshness([string]$FilePath, [int]$MaxAgeSeconds) {
    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { return $false }
    $age = [DateTime]::UtcNow - [IO.File]::GetLastWriteTimeUtc($FilePath)
    return $age.TotalSeconds -le $MaxAgeSeconds
}

function Get-ExpectedBranch {
    $manifestPath = Join-Path $RepoRoot '.tbg/harness/manifest.json'
    if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
        try {
            $m = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
            if ($m.repo -and $m.repo.activeBranch) { return $m.repo.activeBranch }
        } catch {}
    }
    return ''
}

function Confirm-Branch {
    $actual = $null
    try {
        $actual = git -C $RepoRoot rev-parse --abbrev-ref HEAD 2>$null
    } catch {}
    if ([string]::IsNullOrWhiteSpace($actual)) { return $true }
    $result.branch = $actual

    $expected = Get-ExpectedBranch
    if ([string]::IsNullOrWhiteSpace($expected)) { return $true }

    if ($actual -ne $expected) {
        Add-Event "BRANCH MISMATCH: expected=$expected actual=$actual"
        return $false
    }
    Add-Event "Branch verified: $actual"
    return $true
}

function Detect-Surface {
    $regentAge = -1
    if (Test-Path -LiteralPath $RegentPath -PathType Leaf) {
        $regentAge = ([DateTime]::UtcNow - [IO.File]::GetLastWriteTimeUtc($RegentPath)).TotalSeconds
    }

    if ($regentAge -ge 0 -and $regentAge -le $RegentStalenessSeconds) {
        try {
            $regent = Get-Content -LiteralPath $RegentPath -Raw | ConvertFrom-Json
            $result.surface = [string]$regent.surface
            $result.phase = [string]$regent.phase
            $result.surfaceSource = 'regent'
            $result.regentStale = $false
            Add-Event "Surface from regent (age=${regentAge}s): surface=$($result.surface) phase=$($result.phase)"
            return
        } catch {
            Add-Event "Regent parse failed, falling back to Phase1.log"
        }
    }

    if ($regentAge -gt $RegentStalenessSeconds) {
        $result.regentStale = $true
        Add-Event "Regent stale (age=${regentAge}s > ${RegentStalenessSeconds}s threshold), falling back to Phase1.log"
    }

    $result.surfaceSource = 'phase1log'
    if (-not (Test-Path -LiteralPath $PhaseLogPath -PathType Leaf)) {
        Add-Event "Phase1.log not found at $PhaseLogPath"
        $result.surface = 'unknown'
        $result.phase = 'unknown'
        return
    }

    $raw = Get-Content -LiteralPath $PhaseLogPath -Raw -ErrorAction SilentlyContinue
    if ($null -eq $raw) {
        $result.surface = 'unknown'
        $result.phase = 'unknown'
        Add-Event "Phase1.log read failed"
        return
    }

    if ($raw -match 'surface=map_surface.*mapReady=true') {
        $result.surface = 'campaign_map'
        $result.phase = $Matches[0]
        Add-Event "Campaign map ready (Phase1.log): $($Matches[0])"
    } elseif ($raw -match 'surface=(\S+)') {
        $result.surface = $Matches[1]
        $result.phase = 'detected'
        Add-Event "Surface from Phase1.log: $($result.surface)"
    } else {
        $result.surface = 'unknown'
        $result.phase = 'undetected'
        Add-Event "No surface detected in Phase1.log"
    }

    if ($raw -match 'settlementEntered=(\w+)') {
        $result.settled = $Matches[1] -eq 'true'
        Add-Event "Settlement entered: $($result.settled)"
    }
}

function Write-Command {
    if ($WhatIf) {
        Add-Event "WHATIF: would write $Priority command to inbox"
        $result.commandDispatched = $true
        return
    }

    $inbox = @{
        command = switch ($Priority) {
            'Land'     { 'LandAtNearestSettlement' }
            'Survive'  { 'BuySurvivalGoods' }
            'Purchase' { 'RunAutonomousBuyOrder' }
            'Travel'   { 'RunAutonomousVisibleTradeRouteNow' }
            'Sell'     { 'SellInventorySurplus' }
        }
        mode = 'Autonomous'
        dispatchedAt = [DateTime]::UtcNow.ToString('o')
    }

    try {
        $inbox | ConvertTo-Json -Depth 2 | Set-Content -LiteralPath $CommandInboxPath -Encoding UTF8
        $result.commandDispatched = $true
        Add-Event "Command dispatched: $($inbox.command)"
    } catch {
        Add-Event "FAILED to write command inbox: $($_.Exception.Message)"
    }
}

Write-Host "=== TBG Priority Engine ==="
Add-Event "PRIORITY ENGINE START - $Priority"

$branchOk = Confirm-Branch
if (-not $branchOk) {
    Add-Event "ABORT: branch mismatch"
    $null = New-Item -Path (Split-Path $OutputPath -Parent) -ItemType Directory -Force -ErrorAction SilentlyContinue
    $result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    exit 1
}

Detect-Surface

if ($result.surface -eq 'campaign_map' -or $result.surface -eq 'MapPaused') {
    Write-Command
    $result.decisionRecorded = $true
    Add-Event "DECISION: $Priority command dispatched for surface=$($result.surface)"
} else {
    Add-Event "SKIP: surface=$($result.surface) does not accept priority commands"
}

$null = New-Item -Path (Split-Path $OutputPath -Parent) -ItemType Directory -Force -ErrorAction SilentlyContinue
$result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $OutputPath -Encoding UTF8

Write-Host "`nPriority engine complete: $($result.surface) | $($result.priority) | dispatched=$($result.commandDispatched)"
exit 0
