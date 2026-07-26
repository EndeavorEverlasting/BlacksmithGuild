<#
.SYNOPSIS
Classifies every on-disk Bannerlord save against the tracked disposable-save registry and
policy, and (optionally) creates + pins a fresh TBG-owned disposable save so automation runs
do not require a new sprint each time.

Writes a machine-local classification artifact (never mutates non-disposable saves). With
-CreateOwned it clones the canonical disposable save into a timestamped
BlacksmithGuild_Disposable_<utc>.sav and sets it as the active pin.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [switch]$CreateOwned,
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
function Log($m) { $e = '[{0}] {1}' -f ([DateTime]::UtcNow.ToString('HH:mm:ss')), $m; Write-Host $e; $events.Add($e) | Out-Null }

Log 'DISPOSABLE-SAVE REGISTRY UPDATE'

$registryPath = Join-Path $RepoRoot '.tbg\state\disposable-save.registry.json'
$registry = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json
$patterns = @(Get-GovernorDisposableSavePatterns -RepoRoot $RepoRoot)
$supportedPrefix = [string]$registry.compatibility.supportedGameVersionPrefix

function Get-Cohort([string]$name) {
    foreach ($c in $registry.cohorts) {
        foreach ($m in @($c.match)) { if ($name -like $m) { return $c } }
    }
    return $null
}

# 1. Classify every save under the tracked save roots (read-only).
$classified = New-Object System.Collections.Generic.List[object]
foreach ($root in @(Get-GovernorSaveRoots -RepoRoot $RepoRoot)) {
    foreach ($file in @(Get-ChildItem -LiteralPath $root -Filter '*.sav' -File -ErrorAction SilentlyContinue)) {
        $disposable = $false
        foreach ($p in $patterns) { if ($file.Name -like $p) { $disposable = $true; break } }
        $cohort = Get-Cohort $file.Name
        $classification = if ($cohort) { [string]$cohort.classification } elseif ($disposable) { 'Disposable' } else { 'NonDisposable' }
        $classified.Add([pscustomobject][ordered]@{
            name = $file.Name
            root = $root
            classification = $classification
            cohortId = if ($cohort) { [string]$cohort.id } else { $null }
            lastWriteUtc = $file.LastWriteTimeUtc.ToString('o')
            mutationEligible = ($classification -eq 'Disposable')
        }) | Out-Null
    }
}
$disposableCount = @($classified | Where-Object { $_.classification -eq 'Disposable' }).Count
Log "Classified $($classified.Count) save(s): $disposableCount disposable, $($classified.Count - $disposableCount) non-disposable."

# 2. Optionally create + pin a fresh TBG-owned disposable save (clone of canonical/latest disposable).
$createdSave = $null
$pinned = $null
if ($CreateOwned) {
    $source = @(Get-GovernorDisposableSaveCandidates -RepoRoot $RepoRoot) | Select-Object -First 1
    if (-not $source) {
        Log 'BLOCKED: no existing disposable save to clone as the owned baseline.'
    } else {
        $nativeRoot = Get-GovernorNativeSaveRoot
        if (-not (Test-Path -LiteralPath $nativeRoot)) { New-Item -ItemType Directory -Force -Path $nativeRoot | Out-Null }
        $stamp = [DateTime]::UtcNow.ToString('yyyyMMddHHmmss')
        $leaf = '{0}{1}.sav' -f [string]$registry.ownedCanonical.createPrefix, $stamp
        $dest = Join-Path $nativeRoot $leaf
        Copy-Item -LiteralPath $source.FullName -Destination $dest -Force
        $createdSave = Get-Item -LiteralPath $dest
        Log "Created owned disposable save: $leaf (cloned from $($source.Name))"
        $pinned = Set-GovernorActiveDisposableSavePin -SaveFile $createdSave -RepoRoot $RepoRoot -Reason 'agent-owned disposable save (Update-TbgDisposableSaveRegistry -CreateOwned)'
        Log "Pinned active disposable save: $($pinned.leafName)"
    }
}

# 3. Write the machine-local classification artifact (never a tracked save mutation).
$outDir = Join-Path $RepoRoot 'artifacts\latest'
if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
$outPath = Join-Path $outDir 'disposable-save-classification.result.json'
$createdOwnedSave = if ($createdSave) { [string]$createdSave.Name } else { $null }
$activePinLeaf = if ($pinned) { [string]$pinned.leafName } else { $null }
$result = [pscustomobject][ordered]@{
    schema = 'TbgDisposableSaveClassificationResult.v1'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    registry = '.tbg/state/disposable-save.registry.json'
    supportedGameVersionPrefix = $supportedPrefix
    disposableCount = $disposableCount
    nonDisposableCount = ($classified.Count - $disposableCount)
    createdOwnedSave = $createdOwnedSave
    activePin = $activePinLeaf
    saves = $classified.ToArray()
    events = $events.ToArray()
}
$result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $outPath -Encoding UTF8
Log "Output: $outPath"

if ($PassThru) { Write-Output ([pscustomobject]$result) }
