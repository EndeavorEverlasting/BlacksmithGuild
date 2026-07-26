<#
.SYNOPSIS
Dedicated live-runtime entrypoint for the disposable-save priority-engine certificate.

The workflow is fail-closed. It requires explicit disposable-save mutation authority, a pinned
save matching the tracked disposable policy, and PASS_SAVE_VERSION_EXACT from the canonical
save-compatibility gate before any launcher or priority-engine action is attempted.

It deliberately does not force-stop Bannerlord. Runtime ownership/inactive-session enforcement
remains the launcher-lifecycle authority; an active or ambiguous session must be resolved there.
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
. (Join-Path $RepoRoot 'scripts/bannerlord-paths.ps1')

$artifactRegistryPath = Join-Path $RepoRoot '.tbg\harness\disposable-save-artifacts.registry.json'
$saveCompatibilityScript = Join-Path $RepoRoot 'scripts\tbg\Invoke-TbgSaveCompatibility.ps1'
if (-not (Test-Path -LiteralPath $artifactRegistryPath -PathType Leaf)) { throw "Artifact registry missing: $artifactRegistryPath" }
if (-not (Test-Path -LiteralPath $saveCompatibilityScript -PathType Leaf)) { throw "Save compatibility entrypoint missing: $saveCompatibilityScript" }
$artifactRegistry = Get-Content -LiteralPath $artifactRegistryPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
$latestRoot = Join-Path $RepoRoot ([string]$artifactRegistry.latestRoot -replace '/', [IO.Path]::DirectorySeparatorChar)
if (-not (Test-Path -LiteralPath $latestRoot -PathType Container)) { New-Item -ItemType Directory -Force -Path $latestRoot | Out-Null }
$resultPath = Join-Path $latestRoot 'disposable-save-live-cert.result.json'

$events = [System.Collections.Generic.List[string]]::new()
function Add-Event([string]$Message) {
    $line = '[{0}] {1}' -f ([DateTime]::UtcNow.ToString('HH:mm:ss')), $Message
    Write-Host $line
    $events.Add($line) | Out-Null
}

$sourceCommit = (@(& git -C $RepoRoot rev-parse HEAD 2>$null) -join '').Trim()
$sourceBranch = (@(& git -C $RepoRoot branch --show-current 2>$null) -join '').Trim()

function Write-Result {
    param(
        [Parameter(Mandatory = $true)][string]$Verdict,
        [Parameter(Mandatory = $true)][string]$TerminalState,
        [string]$PinnedSave,
        [string]$SaveCompatibilityState,
        [string]$NextCommand,
        [hashtable]$Extra
    )
    $payload = [ordered]@{
        schema = 'TbgDisposableSaveLiveCertResult.v1'
        generatedUtc = [DateTime]::UtcNow.ToString('o')
        sourceCommit = $sourceCommit
        sourceBranch = $sourceBranch
        verdict = $Verdict
        terminalState = $TerminalState
        proofLevel = if ($Verdict -eq 'PASS') { 'live runtime' } else { 'harness' }
        mutationAuthorityGranted = [bool]$AllowDisposableSaveMutation
        pinnedSave = $PinnedSave
        saveCompatibilityState = $SaveCompatibilityState
        bannerlordRoot = $BannerlordRoot
        nextCommand = $NextCommand
        events = @($events.ToArray())
    }
    if ($Extra) { foreach ($key in $Extra.Keys) { $payload[$key] = $Extra[$key] } }
    $payload | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resultPath -Encoding UTF8
    Add-Event "Result: $resultPath"
    if ($PassThru) { [pscustomobject]$payload }
}

Add-Event 'DISPOSABLE-SAVE LIVE CERT'

if (-not $AllowDisposableSaveMutation) {
    Add-Event 'BLOCKED: explicit disposable-save mutation authority absent.'
    Write-Result -Verdict 'BLOCKED' -TerminalState 'BLOCKED_mutation_authority_absent' `
        -PinnedSave $null -SaveCompatibilityState $null `
        -NextCommand 'Re-run only after explicitly authorizing disposable-save mutation.' -Extra $null
    if (-not $PassThru) { exit 32 }
    return
}

$pin = Get-GovernorActiveDisposableSavePin -RepoRoot $RepoRoot
if (-not $pin -or [string]::IsNullOrWhiteSpace([string]$pin.leafName)) {
    Add-Event 'BLOCKED: active disposable-save pin missing.'
    Write-Result -Verdict 'BLOCKED' -TerminalState 'BLOCKED_disposable_pin_missing' `
        -PinnedSave $null -SaveCompatibilityState $null `
        -NextCommand '.\scripts\tbg\Update-TbgDisposableSaveRegistry.ps1 -CreateOwned' -Extra $null
    if (-not $PassThru) { exit 33 }
    return
}

$saveLeaf = [string]$pin.leafName
$savePath = [string]$pin.fullPath
if ([string]::IsNullOrWhiteSpace($savePath) -or -not (Test-Path -LiteralPath $savePath -PathType Leaf)) {
    Add-Event "BLOCKED: pinned save file missing: $saveLeaf"
    Write-Result -Verdict 'BLOCKED' -TerminalState 'BLOCKED_pinned_save_missing' `
        -PinnedSave $saveLeaf -SaveCompatibilityState 'BLOCKED_SAVE_NOT_FOUND' `
        -NextCommand '.\scripts\tbg\Update-TbgDisposableSaveRegistry.ps1 -CreateOwned' -Extra $null
    if (-not $PassThru) { exit 34 }
    return
}

$saveFile = Get-Item -LiteralPath $savePath
$confidence = Test-DisposableSaveConfidence -SaveFile $saveFile -RepoRoot $RepoRoot
if (-not $confidence -or -not $confidence.ApprovedPattern) {
    Add-Event "BLOCKED: pinned save '$saveLeaf' does not satisfy disposable-save policy."
    Write-Result -Verdict 'BLOCKED' -TerminalState 'BLOCKED_pinned_save_not_disposable' `
        -PinnedSave $saveLeaf -SaveCompatibilityState $null `
        -NextCommand '.\scripts\tbg\Update-TbgDisposableSaveRegistry.ps1 -CreateOwned' -Extra $null
    if (-not $PassThru) { exit 35 }
    return
}

# Exact version/role gate. Filename classification never overrides this result.
$saveGate = & $saveCompatibilityScript `
    -Mode gate `
    -TargetSavePath $saveFile.FullName `
    -RepoRoot $RepoRoot `
    -NoExit `
    -PassThru

$gateState = if ($saveGate) { [string]$saveGate.targetGateTerminalState } else { 'BLOCKED_SAVE_COMPATIBILITY_RESULT_MISSING' }
$gateRecord = if ($saveGate) { @($saveGate.saveRecords | Where-Object { $_.path -eq $saveFile.FullName } | Select-Object -First 1) } else { @() }
$gateEligible = $gateState -eq 'PASS_SAVE_VERSION_EXACT' -and $gateRecord.Count -eq 1 -and [bool]$gateRecord[0].autoLoadEligible
if (-not $gateEligible) {
    Add-Event "BLOCKED: canonical save compatibility gate rejected '$saveLeaf' as $gateState."
    Write-Result -Verdict 'BLOCKED' -TerminalState 'BLOCKED_save_compatibility_gate' `
        -PinnedSave $saveLeaf -SaveCompatibilityState $gateState `
        -NextCommand '.\ForgeSaveCompatibility.cmd' `
        -Extra @{ saveCompatibilityResult = if ($saveGate) { [string]$saveGate.evidencePaths.result } else { $null } }
    if (-not $PassThru) { exit 36 }
    return
}
Add-Event "Exact save compatibility gate PASS: $saveLeaf ($gateState)."

if ([string]::IsNullOrWhiteSpace($BannerlordRoot)) {
    try { $BannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $RepoRoot }
    catch { $BannerlordRoot = $null }
}
if ([string]::IsNullOrWhiteSpace($BannerlordRoot) -or -not (Test-Path -LiteralPath $BannerlordRoot -PathType Container)) {
    Add-Event 'BLOCKED: Bannerlord install root not resolved.'
    Write-Result -Verdict 'BLOCKED' -TerminalState 'BLOCKED_bannerlord_root_unresolved' `
        -PinnedSave $saveLeaf -SaveCompatibilityState $gateState `
        -NextCommand 'Resolve the canonical Bannerlord install root, then rerun this workflow.' -Extra $null
    if (-not $PassThru) { exit 37 }
    return
}

# Do not force-stop an existing session here. The canonical launcher path owns runtime-context
# admission and must fail closed if build/install/launch cannot proceed safely.
$forge = Join-Path $RepoRoot 'forge.ps1'
$writeIntent = Join-Path $RepoRoot 'scripts\write-launch-intent.ps1'
$launcherNav = Join-Path $RepoRoot 'scripts\launcher-frozen-context-nav.ps1'
foreach ($required in @($forge, $writeIntent, $launcherNav)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        Add-Event "BLOCKED: launcher component missing: $required"
        Write-Result -Verdict 'BLOCKED' -TerminalState 'BLOCKED_launcher_component_missing' `
            -PinnedSave $saveLeaf -SaveCompatibilityState $gateState `
            -NextCommand '.\ForgeContinue.cmd' -Extra @{ missingComponent = $required }
        if (-not $PassThru) { exit 38 }
        return
    }
}

Add-Event "Launching canonical Continue path for exact-version disposable save '$saveLeaf'."
& $forge -Launch -LaunchIntent continue -LaunchManual
if ($LASTEXITCODE -ne 0) {
    Add-Event "BLOCKED: forge launch/build admission exited $LASTEXITCODE."
    Write-Result -Verdict 'BLOCKED' -TerminalState 'BLOCKED_launcher_admission_failed' `
        -PinnedSave $saveLeaf -SaveCompatibilityState $gateState `
        -NextCommand '.\ForgeContinue.cmd' -Extra @{ launcherExitCode = $LASTEXITCODE }
    if (-not $PassThru) { exit 39 }
    return
}

& $writeIntent -LaunchIntent continue -BannerlordRoot $BannerlordRoot
if ($LASTEXITCODE -ne 0) {
    Write-Result -Verdict 'BLOCKED' -TerminalState 'BLOCKED_launch_intent_failed' `
        -PinnedSave $saveLeaf -SaveCompatibilityState $gateState `
        -NextCommand '.\ForgeContinue.cmd' -Extra @{ launcherExitCode = $LASTEXITCODE }
    if (-not $PassThru) { exit 40 }
    return
}

& $launcherNav `
    -LaunchIntent play `
    -BannerlordRoot $BannerlordRoot `
    -LauncherContextPath (Join-Path $BannerlordRoot 'launcher-window-context.json') `
    -PollMs 250 `
    -LaunchSetup `
    -AllowFocusSteal
if ($LASTEXITCODE -ne 0) {
    Add-Event "BLOCKED: launcher navigation exited $LASTEXITCODE."
    Write-Result -Verdict 'BLOCKED' -TerminalState 'BLOCKED_launcher_navigation_failed' `
        -PinnedSave $saveLeaf -SaveCompatibilityState $gateState `
        -NextCommand '.\ForgeContinue.cmd' -Extra @{ launcherExitCode = $LASTEXITCODE }
    if (-not $PassThru) { exit 41 }
    return
}

$engine = Join-Path $PSScriptRoot 'Invoke-TbgPriorityEngine.ps1'
if (-not (Test-Path -LiteralPath $engine -PathType Leaf)) {
    Write-Result -Verdict 'BLOCKED' -TerminalState 'BLOCKED_priority_engine_missing' `
        -PinnedSave $saveLeaf -SaveCompatibilityState $gateState `
        -NextCommand 'Restore scripts/tbg/Invoke-TbgPriorityEngine.ps1 before live certification.' -Extra $null
    if (-not $PassThru) { exit 42 }
    return
}

Add-Event "Priority engine live-cert run begins (MaxIterations=$MaxIterations, MapReadyTimeoutSec=$MapReadyTimeoutSec)."
try {
    & $engine -BannerlordRoot $BannerlordRoot -MaxIterations $MaxIterations -MapReadyTimeoutSec $MapReadyTimeoutSec | Out-Null
    $engineExit = $LASTEXITCODE
}
catch {
    Add-Event "Priority engine exception: $($_.Exception.Message)"
    $engineExit = 1
}

if ($engineExit -ne 0) {
    Write-Result -Verdict 'ATTENTION' -TerminalState 'ATTENTION_priority_engine_not_proven' `
        -PinnedSave $saveLeaf -SaveCompatibilityState $gateState `
        -NextCommand '.\ExportTbgEvidence.cmd' -Extra @{ priorityEngineExitCode = $engineExit }
    if (-not $PassThru) { exit 2 }
    return
}

Write-Result -Verdict 'PASS' -TerminalState 'PASS_priority_engine_live_on_exact_version_disposable_save' `
    -PinnedSave $saveLeaf -SaveCompatibilityState $gateState `
    -NextCommand '.\ExportTbgEvidence.cmd' -Extra @{ priorityEngineExitCode = 0 }
if (-not $PassThru) { exit 0 }
