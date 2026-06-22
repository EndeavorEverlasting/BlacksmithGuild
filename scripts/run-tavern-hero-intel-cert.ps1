# Tier 1 tavern hero intel cert — optional autoloop launch + navigation + AnalyzeTavernHeroes.
param(
    [ValidateSet('AutoLoop', 'Manual')]
    [string]$Mode = 'Manual',

    [switch]$Launch,

    [int]$ReadyTimeoutSec = 900,

    [int]$CommandTimeoutSec = 120
)

$ErrorActionPreference = 'Stop'

function Wait-TbgReadyExtended {
    param(
        [Parameter(Mandatory = $true)][string]$BannerlordRoot,
        [int]$TimeoutSec = 900
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if (Test-Phase1TbgReady -BannerlordRoot $BannerlordRoot) {
            return $true
        }

        Start-Sleep -Seconds 5
    }

    return $false
}

function Get-StatusJson {
    param([string]$BannerlordRoot)

    $path = Join-Path $BannerlordRoot 'BlacksmithGuild_Status.json'
    if (-not (Test-Path -LiteralPath $path)) {
        return $null
    }

    try {
        return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Assert-ManualGate {
    param(
        [string]$Label,
        [scriptblock]$Predicate
    )

    if (& $Predicate) {
        return $true
    }

    Write-Host "MANUAL GATE: $Label" -ForegroundColor Yellow
    Write-Host 'Fix game state, then re-run this script with -Mode Manual or -Launch for autoloop.' -ForegroundColor DarkGray
    return $false
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot
. (Join-Path $PSScriptRoot 'forge-status.ps1')

$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot
$intelPath = Join-Path $bannerlordRoot 'BlacksmithGuild_TavernHeroIntel.json'
$phase1Path = Join-Path $bannerlordRoot 'BlacksmithGuild_Phase1.log'

Write-Host ''
Write-Host '=== Tavern Hero Intel Cert (Tier 1) ===' -ForegroundColor Cyan
Write-Host "Mode:   $Mode"
Write-Host "Repo:   $repoRoot"
Write-Host "Game:   $bannerlordRoot"
Write-Host ''

& (Join-Path $PSScriptRoot 'write-agent-iteration-config.ps1') -Mode $Mode -BannerlordRoot $bannerlordRoot | Out-Null

if ($Launch -or $Mode -eq 'AutoLoop') {
    & (Join-Path $PSScriptRoot 'forge-stop.ps1') | Out-Null
    & (Join-Path $repoRoot 'forge.ps1') -Launch -LaunchIntent continue -SkipSaveBackup
    if (-not (Wait-TbgReadyExtended -BannerlordRoot $bannerlordRoot -TimeoutSec $ReadyTimeoutSec)) {
        Write-Host 'FAIL: TBG READY not observed.' -ForegroundColor Red
        exit 1
    }
}

Clear-StaleMutationCommandInbox -BannerlordRoot $bannerlordRoot | Out-Null

$status = Get-StatusJson -BannerlordRoot $bannerlordRoot
if ($Mode -eq 'Manual') {
    if (-not (Assert-ManualGate -Label 'campaign map or settlement interior required' -Predicate {
            $status -and ($status.session.canPollFileInbox -eq $true)
        })) { exit 2 }
}

if ($Mode -eq 'AutoLoop') {
    Write-Host '[auto] AutoTravelChoice1 (if needed)' -ForegroundColor Yellow
    Send-ForgeCommand -CommandName 'AutoTravelChoice1' -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec $CommandTimeoutSec | Out-Null
    Start-Sleep -Seconds 3

    Write-Host '[auto] NavigateToSettlementTavernNow' -ForegroundColor Yellow
    Send-ForgeCommand -CommandName 'NavigateToSettlementTavernNow' -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec $CommandTimeoutSec | Out-Null
} elseif ($Mode -eq 'Manual') {
    $status = Get-StatusJson -BannerlordRoot $bannerlordRoot
    if (-not (Assert-ManualGate -Label 'enter town and tavern before AnalyzeTavernHeroes' -Predicate {
            $status -and ($status.session.tavernReady -eq $true -or $status.session.settlementReady -eq $true)
        })) {
        Write-Host 'Hint: from map at town, run NavigateToSettlementTavernNow after entering settlement boundary.' -ForegroundColor DarkGray
    }
}

Write-Host '[cert] AnalyzeTavernHeroes' -ForegroundColor Yellow
Send-ForgeCommand -CommandName 'AnalyzeTavernHeroes' -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec $CommandTimeoutSec | Out-Null

if (-not (Test-Path -LiteralPath $intelPath)) {
    Write-Host 'FAIL: BlacksmithGuild_TavernHeroIntel.json not written.' -ForegroundColor Red
    exit 1
}

$intel = Get-Content -LiteralPath $intelPath -Raw | ConvertFrom-Json
$verdict = 'FAIL'
$detail = 'Intel JSON missing expected read-only fields.'

if ($intel.readOnly -eq $true -and $intel.mutationApplied -eq $false) {
    $verdict = 'PASS'
    $detail = "candidates=$($intel.candidates.Count) verdict=$($intel.verdict)"
}

Write-Host ''
Write-Host "Tier 1 ${verdict}: $detail" -ForegroundColor $(if ($verdict -eq 'PASS') { 'Green' } else { 'Red' })
if (Test-Path -LiteralPath $phase1Path) {
    Write-Host "Phase1: $phase1Path"
}
Write-Host "JSON:   $intelPath"

if ($verdict -ne 'PASS') { exit 1 }
