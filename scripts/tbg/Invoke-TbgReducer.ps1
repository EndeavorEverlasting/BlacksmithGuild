[CmdletBinding()]
param(
    [string]$RepoRoot,
    [switch]$Rebuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Get-Location).Path
}

function Resolve-TbgRepoPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    Join-Path $RepoRoot ($RelativePath -replace '/', [IO.Path]::DirectorySeparatorChar)
}

$journalRoot = Resolve-TbgRepoPath '.local/tbg-state/journal'
$committedDir = Join-Path $journalRoot 'committed'
$projectionsRoot = Resolve-TbgRepoPath '.local/tbg-state/projections'
$processedPath = Join-Path $projectionsRoot 'processed-events.json'
$reducerRegistryPath = Resolve-TbgRepoPath '.tbg/state/reducer-registry.json'

if (-not (Test-Path -LiteralPath $committedDir -PathType Container)) {
    Write-Warning 'No journal committed directory found. Nothing to reduce.'
    return
}

if ($Rebuild -and (Test-Path -LiteralPath $projectionsRoot -PathType Container)) {
    Remove-Item -LiteralPath $projectionsRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $projectionsRoot | Out-Null

$reducerRegistry = Get-Content -LiteralPath $reducerRegistryPath -Raw | ConvertFrom-Json
$eventFiles = @(Get-ChildItem -LiteralPath $committedDir -Filter '*.json' -File | Sort-Object Name)
$processed = @{}
if ((Test-Path -LiteralPath $processedPath -PathType Leaf) -and -not $Rebuild) {
    $processed = @{}
    $processedObj = Get-Content -LiteralPath $processedPath -Raw | ConvertFrom-Json
    $processedObj.PSObject.Properties | ForEach-Object { $processed[$_.Name] = $_.Value }
}

$reducerEventMap = @{}
foreach ($r in $reducerRegistry.reducers) {
    foreach ($et in $r.eventTypes) {
        if (-not $reducerEventMap.ContainsKey($et)) { $reducerEventMap[$et] = @() }
        $reducerEventMap[$et] += $r
    }
}

$eventsProcessed = 0
$objectsProduced = 0

foreach ($ef in $eventFiles) {
    $evt = Get-Content -LiteralPath $ef.FullName -Raw | ConvertFrom-Json
    $eid = [string]$evt.eventId
    if ($processed.ContainsKey($eid)) { continue }

    $eventType = [string]$evt.eventType
    $matchingReducers = @()
    if ($reducerEventMap.ContainsKey($eventType)) {
        $matchingReducers = @($reducerEventMap[$eventType])
    }

    foreach ($r in $matchingReducers) {
        $reducerDir = Join-Path $projectionsRoot ($r.id -replace '[:/\\]', '_')
        New-Item -ItemType Directory -Force -Path $reducerDir | Out-Null

        $objectType = $r.producedObjectTypes[0]
        $objId = "${objectType}:${eid}"

        $obj = [ordered]@{
            schema = $objectType
            id = $objId
            sourceEventId = $eid
            sourceEventType = $eventType
            sourceCorrelationId = $evt.correlationId
            receivedUtc = $evt.receivedUtc
            payload = $evt.payload
        }

        $safeName = ($objId -replace '[:/\\]', '_') + '.json'
        $outPath = Join-Path $reducerDir $safeName
        $obj | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $outPath -Encoding UTF8
        $objectsProduced++
    }

    $processed[$eid] = $true
    $eventsProcessed++
}

$processed | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $processedPath -Encoding UTF8

$allProjectionFiles = Get-ChildItem -LiteralPath $projectionsRoot -Recurse -Filter '*.json' -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notin @('processed-events.json', 'projection-meta.json') }
$hashBuilder = [System.Text.StringBuilder]::new()
foreach ($pf in ($allProjectionFiles | Sort-Object FullName)) {
    [void]$hashBuilder.Append((Get-Content -LiteralPath $pf.FullName -Raw))
}
$sha = [System.Security.Cryptography.SHA256]::Create()
$combinedBytes = [System.Text.Encoding]::UTF8.GetBytes($hashBuilder.ToString())
$projectionHash = 'sha256:' + [BitConverter]::ToString($sha.ComputeHash($combinedBytes)).Replace('-', '').ToLower()

$meta = [ordered]@{
    schema = 'TbgProjectionMeta.v1'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    eventsProcessed = $eventsProcessed
    objectsProduced = $objectsProduced
    projectionHash = $projectionHash
    rebuildMode = $Rebuild.IsPresent
}
$meta | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $projectionsRoot 'projection-meta.json') -Encoding UTF8

Write-Host "Reducer complete: events=$eventsProcessed, objects=$objectsProduced, hash=$projectionHash, rebuild=$($Rebuild.IsPresent)"
