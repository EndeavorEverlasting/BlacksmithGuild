<#
.SYNOPSIS
Classifies Bannerlord saves against the tracked disposable-save cohorts and the canonical
read-only save-compatibility harness. With -CreateOwned, clones only an already exact-version,
automation-eligible disposable save, reclassifies the new bytes, and pins the clone only after
the post-create gate passes.

The updater never mutates a non-disposable save and never treats a filename as version proof.
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

$registryPath = Join-Path $RepoRoot '.tbg\state\disposable-save.registry.json'
$gameRegistryPath = Join-Path $RepoRoot '.tbg\state\game-compatibility.registry.json'
$saveCompatibilityScript = Join-Path $RepoRoot 'scripts\tbg\Invoke-TbgSaveCompatibility.ps1'
$artifactRegistryPath = Join-Path $RepoRoot '.tbg\harness\disposable-save-artifacts.registry.json'

foreach ($required in @($registryPath, $gameRegistryPath, $saveCompatibilityScript, $artifactRegistryPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required disposable-save authority missing: $required"
    }
}

$registry = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
$gameRegistry = Get-Content -LiteralPath $gameRegistryPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
$artifactRegistry = Get-Content -LiteralPath $artifactRegistryPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
$policyPatterns = @(Get-GovernorDisposableSavePatterns -RepoRoot $RepoRoot)
$supportedPrefix = [string]$gameRegistry.repoSupportedBuild.gameVersionPrefix

if ([string]::IsNullOrWhiteSpace($supportedPrefix)) {
    throw 'game-compatibility.registry.json does not declare repoSupportedBuild.gameVersionPrefix.'
}

$events = [System.Collections.Generic.List[string]]::new()
function Add-Event([string]$Message) {
    $line = '[{0}] {1}' -f ([DateTime]::UtcNow.ToString('HH:mm:ss')), $Message
    Write-Host $line
    $events.Add($line) | Out-Null
}

function Get-Cohort([string]$LeafName) {
    foreach ($cohort in @($registry.cohorts)) {
        foreach ($pattern in @($cohort.match)) {
            if ($LeafName -like [string]$pattern) {
                return $cohort
            }
        }
    }
    return $null
}

function Test-DisposablePattern([string]$LeafName) {
    foreach ($pattern in $policyPatterns) {
        if ($LeafName -like [string]$pattern) { return $true }
    }
    return $false
}

Add-Event 'DISPOSABLE-SAVE REGISTRY UPDATE'

# Canonical read-only version/role classifier. This is the authority for exact save/game
# compatibility; this updater only adds durable cohort semantics and owned-save lifecycle.
$catalog = & $saveCompatibilityScript `
    -Mode catalog `
    -RepoRoot $RepoRoot `
    -NoExit `
    -PassThru

if ($null -eq $catalog) {
    throw 'Save compatibility classifier returned no result.'
}

$classified = [System.Collections.Generic.List[object]]::new()
foreach ($record in @($catalog.saveRecords)) {
    $leafName = [string]$record.leafName
    $cohort = Get-Cohort -LeafName $leafName
    $patternDisposable = Test-DisposablePattern -LeafName $leafName
    $classification = if ($cohort) {
        [string]$cohort.classification
    }
    elseif ($patternDisposable) {
        'Disposable'
    }
    else {
        'NonDisposable'
    }

    $mutationEligible = ($classification -eq 'Disposable') `
        -and ([bool]$record.autoLoadEligible) `
        -and ([string]$record.terminalState -eq 'PASS_SAVE_VERSION_EXACT')

    $classified.Add([pscustomobject][ordered]@{
        name = $leafName
        classification = $classification
        cohortId = if ($cohort) { [string]$cohort.id } else { $null }
        role = [string]$record.role
        parsedSaveVersion = [string]$record.parsedSaveVersion
        compatibility = [string]$record.compatibility
        compatibilityState = [string]$record.terminalState
        sha256 = [string]$record.sha256
        length = $record.length
        lastWriteUtc = [string]$record.lastWriteUtc
        mutationEligible = [bool]$mutationEligible
        localPath = [string]$record.path
    }) | Out-Null
}

$disposableCount = @($classified | Where-Object { $_.classification -eq 'Disposable' }).Count
$mutationEligibleCount = @($classified | Where-Object { $_.mutationEligible -eq $true }).Count
Add-Event "Classified $($classified.Count) save(s): $disposableCount disposable; $mutationEligibleCount exact-version mutation eligible."

$createdOwnedSave = $null
$activePin = $null
$createState = 'NOT_REQUESTED'

if ($CreateOwned) {
    $sourceRecord = @(
        $classified |
            Where-Object { $_.mutationEligible -eq $true -and -not [string]::IsNullOrWhiteSpace([string]$_.localPath) } |
            Sort-Object @{ Expression = { if ($_.name -eq [string]$registry.ownedCanonical.leafName) { 0 } else { 1 } } }, name |
            Select-Object -First 1
    )

    if ($sourceRecord.Count -eq 0) {
        $createState = 'BLOCKED_NO_EXACT_VERSION_DISPOSABLE_SOURCE'
        Add-Event 'BLOCKED: no exact-version automation-eligible disposable save is available to clone.'
    }
    elseif (-not (Test-Path -LiteralPath ([string]$sourceRecord[0].localPath) -PathType Leaf)) {
        $createState = 'BLOCKED_SOURCE_SAVE_NOT_FOUND'
        Add-Event "BLOCKED: selected disposable source no longer exists: $($sourceRecord[0].name)"
    }
    else {
        $nativeRoot = Get-GovernorNativeSaveRoot
        if (-not (Test-Path -LiteralPath $nativeRoot -PathType Container)) {
            New-Item -ItemType Directory -Force -Path $nativeRoot | Out-Null
        }

        $stamp = [DateTime]::UtcNow.ToString('yyyyMMddHHmmss')
        $leaf = '{0}{1}.sav' -f [string]$registry.ownedCanonical.createPrefix, $stamp
        $destination = Join-Path $nativeRoot $leaf
        Copy-Item -LiteralPath ([string]$sourceRecord[0].localPath) -Destination $destination -ErrorAction Stop
        Add-Event "Created TBG-owned disposable clone: $leaf from $($sourceRecord[0].name)."

        # New saves are never assumed compatible merely because we created them. Re-read the
        # actual bytes through the canonical gate before any active pin is written.
        $postCreate = & $saveCompatibilityScript `
            -Mode gate `
            -TargetSavePath $destination `
            -GameVersion ([string]$catalog.gameVersion) `
            -RepoRoot $RepoRoot `
            -NoExit `
            -PassThru

        $postRecord = @($postCreate.saveRecords | Where-Object { $_.path -eq $destination } | Select-Object -First 1)
        $postEligible = $postCreate.targetGateTerminalState -eq 'PASS_SAVE_VERSION_EXACT' `
            -and $postRecord.Count -eq 1 `
            -and [bool]$postRecord[0].autoLoadEligible `
            -and (Test-DisposablePattern -LeafName $leaf)

        if (-not $postEligible) {
            $createState = 'BLOCKED_POST_CREATE_RECLASSIFICATION'
            Remove-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue
            Add-Event "BLOCKED: post-create save compatibility gate rejected $leaf; owned clone removed and no pin written."
        }
        else {
            $created = Get-Item -LiteralPath $destination
            $pin = Set-GovernorActiveDisposableSavePin `
                -SaveFile $created `
                -RepoRoot $RepoRoot `
                -Reason 'TBG-owned disposable clone; exact save-version gate passed after creation'
            $createdOwnedSave = [string]$created.Name
            $activePin = [string]$pin.leafName
            $createState = 'PASS_OWNED_DISPOSABLE_CREATED_AND_PINNED'
            Add-Event "Pinned exact-version TBG-owned disposable save: $activePin"
        }
    }
}

$latestRoot = Join-Path $RepoRoot ([string]$artifactRegistry.latestRoot -replace '/', [IO.Path]::DirectorySeparatorChar)
if (-not (Test-Path -LiteralPath $latestRoot -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $latestRoot | Out-Null
}
$resultPath = Join-Path $latestRoot 'disposable-save-classification.result.json'
$reportPath = Join-Path $latestRoot 'disposable-save-classification.report.md'

$terminalState = if ($CreateOwned -and $createState -like 'BLOCKED_*') {
    $createState
}
elseif ($CreateOwned) {
    $createState
}
else {
    'PASS_DISPOSABLE_SAVE_CATALOG_CLASSIFIED'
}

$result = [pscustomobject][ordered]@{
    schema = 'TbgDisposableSaveClassificationResult.v1'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    terminalState = $terminalState
    registry = '.tbg/state/disposable-save.registry.json'
    saveCompatibilityResult = [string]$catalog.evidencePaths.result
    gameVersion = [string]$catalog.gameVersion
    supportedGameVersionPrefix = $supportedPrefix
    disposableCount = $disposableCount
    mutationEligibleCount = $mutationEligibleCount
    createdOwnedSave = $createdOwnedSave
    activePin = $activePin
    createState = $createState
    saves = @($classified.ToArray())
    events = @($events.ToArray())
    proofCeiling = 'real-file read-only save classification; optional TBG-owned clone + post-create exact-version reclassification'
}
$result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resultPath -Encoding UTF8

$report = [System.Collections.Generic.List[string]]::new()
$report.Add('# Disposable save classification') | Out-Null
$report.Add('') | Out-Null
$report.Add(('- Terminal state: `{0}`' -f $terminalState)) | Out-Null
$report.Add(('- Game version: `{0}`' -f $catalog.gameVersion)) | Out-Null
$report.Add(('- Supported game-version family: `{0}`' -f $supportedPrefix)) | Out-Null
$report.Add(('- Disposable saves: `{0}`' -f $disposableCount)) | Out-Null
$report.Add(('- Mutation eligible: `{0}`' -f $mutationEligibleCount)) | Out-Null
$report.Add(('- Create state: `{0}`' -f $createState)) | Out-Null
$report.Add(('- Proof ceiling: `{0}`' -f $result.proofCeiling)) | Out-Null
$report.Add('') | Out-Null
$report.Add('## Saves') | Out-Null
foreach ($save in @($classified.ToArray())) {
    $report.Add(('- `{0}`: cohort=`{1}` version=`{2}` state=`{3}` mutationEligible=`{4}`' -f $save.name, $save.cohortId, $save.parsedSaveVersion, $save.compatibilityState, $save.mutationEligible)) | Out-Null
}
$report | Set-Content -LiteralPath $reportPath -Encoding UTF8

Write-Host "Disposable-save state: $terminalState"
Write-Host "Result: $resultPath"
Write-Host "Report: $reportPath"

if ($PassThru) { $result }
elseif ($terminalState -like 'BLOCKED_*') { exit 3 }
else { exit 0 }
