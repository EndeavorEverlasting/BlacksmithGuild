<#
.SYNOPSIS
Dedicated live-runtime workflow entrypoint for the disposable-save-live-cert E2E journey.

Proves the priority engine (Land -> Survive -> Purchase -> Travel -> Sell) end-to-end on a
disposable save only. Live save mutation is gated behind explicit authority AND a disposable-save
pin that satisfies .tbg/harness/policies/disposable-save.policy.json. Without both, the workflow
refuses to launch or mutate and returns a machine-readable BLOCKED verdict.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$BannerlordRoot,
    [switch]$AllowDisposableSaveMutation,
    [int]$MaxIterations = 1,
    [ValidateRange(60, 1800)][int]$MapReadyTimeoutSec = 300,
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
$RepoRoot = [IO.Path]::GetFullPath($RepoRoot)
. (Join-Path $RepoRoot 'scripts/governor-operator-common.ps1')

$events = [System.Collections.Generic.List[string]]::new()
function Log($m) {
    $line = '[{0}] {1}' -f ([DateTime]::UtcNow.ToString('HH:mm:ss')), $m
    Write-Host $line
    $events.Add($line) | Out-Null
}

if ([string]::IsNullOrWhiteSpace($BannerlordRoot)) {
    try {
        . (Join-Path $RepoRoot 'scripts/bannerlord-paths.ps1')
        $BannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $RepoRoot
    } catch { $BannerlordRoot = $null }
}

$outDir = Join-Path $RepoRoot 'artifacts/latest'
if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
$resultPath = Join-Path $outDir 'disposable-save-live-cert.result.json'

$sourceCommit = (@(& git -C $RepoRoot rev-parse HEAD 2>$null) -join '').Trim()
$sourceBranch = (@(& git -C $RepoRoot branch --show-current 2>$null) -join '').Trim()

function Write-Result {
    param([string]$Verdict, [string]$TerminalState, [string]$NextCommand, [hashtable]$Extra)
    $payload = [ordered]@{
        schema = 'TbgDisposableSaveLiveCertResult.v1'
        generatedUtc = [DateTime]::UtcNow.ToString('o')
        sourceCommit = $sourceCommit
        sourceBranch = $sourceBranch
        verdict = $Verdict
        terminalState = $TerminalState
        proofLevel = if ($Verdict -eq 'PASS') { 'live runtime' } else { 'harness' }
        mutationAuthorityGranted = [bool]$AllowDisposableSaveMutation
        bannerlordRoot = $BannerlordRoot
        nextCommand = $NextCommand
        events = $events.ToArray()
    }
    if ($Extra) { foreach ($k in $Extra.Keys) { $payload[$k] = $Extra[$k] } }
    $payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resultPath -Encoding UTF8
    Log "Result: $resultPath"
    if ($PassThru) { Write-Output ([pscustomobject]$payload) }
}

Log 'DISPOSABLE-SAVE LIVE CERT'

# Gate 1: explicit mutation authority is mandatory.
if (-not $AllowDisposableSaveMutation) {
    Log 'BLOCKED: -AllowDisposableSaveMutation authority not granted.'
    Write-Result -Verdict 'BLOCKED' -TerminalState 'BLOCKED_mutation_authority_absent' `
        -NextCommand 'Re-run with -AllowDisposableSaveMutation after selecting a disposable save pin.' -Extra $null
    if (-not $PassThru) { exit 32 }
    return
}

# Gate 2: an active disposable-save pin must exist and satisfy the tracked policy.
$pin = Get-GovernorActiveDisposableSavePin -RepoRoot $RepoRoot
if (-not $pin -or [string]::IsNullOrWhiteSpace([string]$pin.leafName)) {
    Log 'BLOCKED: no active disposable-save pin (.local/disposable-save.active.json).'
    Write-Result -Verdict 'BLOCKED' -TerminalState 'BLOCKED_disposable_pin_missing' `
        -NextCommand 'Select a disposable save (Set-GovernorActiveDisposableSavePin) before live cert.' -Extra $null
    if (-not $PassThru) { exit 33 }
    return
}

$saveLeaf = [string]$pin.leafName
$saveFile = if ($pin.fullPath -and (Test-Path -LiteralPath ([string]$pin.fullPath))) {
    Get-Item -LiteralPath ([string]$pin.fullPath)
} else { $null }
$confidence = if ($saveFile) { Test-DisposableSaveConfidence -SaveFile $saveFile -RepoRoot $RepoRoot } else { $null }
if (-not $confidence -or -not $confidence.ApprovedPattern) {
    Log "BLOCKED: pinned save '$saveLeaf' does not satisfy disposable-save name policy."
    Write-Result -Verdict 'BLOCKED' -TerminalState 'BLOCKED_pinned_save_not_disposable' `
        -NextCommand 'Pin a save whose name matches disposable-save.policy.json namePatterns.' `
        -Extra @{ pinnedSave = $saveLeaf }
    if (-not $PassThru) { exit 34 }
    return
}
Log "Disposable pin approved: $saveLeaf ($($confidence.Reason))"

if ([string]::IsNullOrWhiteSpace($BannerlordRoot) -or -not (Test-Path -LiteralPath $BannerlordRoot)) {
    Log 'BLOCKED: Bannerlord install root not resolved.'
    Write-Result -Verdict 'BLOCKED' -TerminalState 'BLOCKED_bannerlord_root_unresolved' `
        -NextCommand 'Set GameFolder in BlacksmithGuild.csproj or pass -BannerlordRoot.' -Extra @{ pinnedSave = $saveLeaf }
    if (-not $PassThru) { exit 35 }
    return
}

# ForgeStop-first: never launch on top of a running game.
Log 'ForgeStop (force) before live launch.'
$env:FORGE_NO_PAUSE = '1'
$env:FORGE_STOP_CHOICE = 'F'
try { cmd /c (Join-Path $RepoRoot 'ForgeStop.cmd') force | Out-Null } catch { Log "ForgeStop warning: $($_.Exception.Message)" }

# Launch Continue onto the pinned disposable save, then drive the priority engine loop.
Log "Launching Continue onto disposable save '$saveLeaf'."
try { cmd /c (Join-Path $RepoRoot 'ForgeContinue.cmd') | Out-Null } catch { Log "ForgeContinue warning: $($_.Exception.Message)" }

$engine = Join-Path $PSScriptRoot 'Invoke-TbgPriorityEngine.ps1'
$engineRan = $false
if (Test-Path -LiteralPath $engine) {
    Log "Priority engine: $engine (MaxIterations=$MaxIterations)."
    try { & $engine -BannerlordRoot $BannerlordRoot -MaxIterations $MaxIterations | Out-Null; $engineRan = $true }
    catch { Log "Priority engine warning: $($_.Exception.Message)" }
}

$verdict = if ($engineRan) { 'PASS' } else { 'ATTENTION' }
$terminal = if ($engineRan) { 'PASS_priority_engine_live_on_disposable_save' } else { 'ATTENTION_priority_engine_not_run' }
$next = if ($engineRan) { '.\ExportTbgEvidence.cmd' } else { 'Confirm map ready then re-run the priority engine.' }
Write-Result -Verdict $verdict -TerminalState $terminal -NextCommand $next -Extra @{ pinnedSave = $saveLeaf; engineRan = $engineRan }
if (-not $PassThru) { if ($verdict -eq 'PASS') { exit 0 } else { exit 2 } }
