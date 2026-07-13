[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ObjectPath,
    [Parameter(Mandatory = $true)][string]$SupersedesId,
    [string]$NewStatus,
    [string]$RepoRoot,
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Get-Location).Path
}

if (-not (Test-Path -LiteralPath $ObjectPath -PathType Leaf)) {
    throw "Object file not found: $ObjectPath"
}

$existing = Get-Content -LiteralPath $ObjectPath -Raw | ConvertFrom-Json

$objectType = switch ([string]$existing.schema) {
    'TbgObservation.v1'  { 'observation' }
    'TbgEvidenceRecord.v1' { 'evidence' }
    'TbgClaim.v1'        { 'claim' }
    'TbgConstraint.v1'   { 'constraint' }
    'TbgObjective.v1'    { 'objective' }
    'TbgWorkItem.v1'     { 'work-item' }
    'TbgCapability.v1'   { 'capability' }
    default { throw "Unknown schema: $($existing.schema)" }
}

$subDir = switch ($objectType) {
    'observation'  { 'observations' }
    'evidence'     { 'evidence' }
    'claim'        { 'claims' }
    'constraint'   { 'constraints' }
    'objective'    { 'objectives' }
    'work-item'    { 'work-items' }
    'capability'   { 'capabilities' }
}

$timestamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$random = -join ((1..6) | ForEach-Object { '{0:x}' -f (Get-Random -Minimum 0 -Maximum 16) })
$newId = "${objectType}:${timestamp}-${random}"

$newObject = $existing.PSObject.Copy()
$newObject.id = $newId
$newObject.supersedes = $SupersedesId
$newObject.producedUtc = [DateTime]::UtcNow.ToString('o')

if ($NewStatus) {
    $newObject.status = $NewStatus
}

$version = if ($existing.PSObject.Properties.Name -contains 'version') { [int]$existing.version } else { 1 }
$newObject.version = $version + 1

$objectStore = Join-Path $RepoRoot 'artifacts/state/objects'
$outDir = Join-Path $objectStore $subDir
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$safeName = ($newId -replace '[:/\\]', '_') + '.json'
$outPath = Join-Path $outDir $safeName
$newObject | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $outPath -Encoding UTF8

Write-Host "Superseded $SupersedesId with $newId"
Write-Host "Path: $outPath"

if ($PassThru) {
    $newObject
}
