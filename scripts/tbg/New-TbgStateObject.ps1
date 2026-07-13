[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('observation','evidence','claim','constraint','objective','work-item','capability')][string]$ObjectType,
    [string]$RepoRoot,
    [string]$Id,
    [string]$Subject,
    [string]$Predicate,
    [string]$Value,
    [string]$Statement,
    [string]$Status,
    [string]$Supersedes,
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

function Resolve-TbgRepoPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    Join-Path $RepoRoot ($RelativePath -replace '/', [IO.Path]::DirectorySeparatorChar)
}

$objectStore = Resolve-TbgRepoPath 'artifacts/state/objects'
$subDir = switch ($ObjectType) {
    'observation'  { 'observations' }
    'evidence'     { 'evidence' }
    'claim'        { 'claims' }
    'constraint'   { 'constraints' }
    'objective'    { 'objectives' }
    'work-item'    { 'work-items' }
    'capability'   { 'capabilities' }
}
$outDir = Join-Path $objectStore $subDir
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$schemaMap = @{
    'observation' = 'TbgObservation.v1'
    'evidence'    = 'TbgEvidenceRecord.v1'
    'claim'       = 'TbgClaim.v1'
    'constraint'  = 'TbgConstraint.v1'
    'objective'   = 'TbgObjective.v1'
    'work-item'   = 'TbgWorkItem.v1'
    'capability'  = 'TbgCapability.v1'
}

$timestamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$random = -join ((1..6) | ForEach-Object { '{0:x}' -f (Get-Random -Minimum 0 -Maximum 16) })

$generatedId = if ($Id) { $Id } else { "${ObjectType}:${timestamp}-${random}" }

$object = [ordered]@{
    schema = $schemaMap[$ObjectType]
    id = $generatedId
    producedUtc = [DateTime]::UtcNow.ToString('o')
}

if ($Subject) { $object.subject = $Subject }
if ($Predicate) { $object.predicate = $Predicate }
if ($Value) { $object.value = $Value }
if ($Statement) { $object.statement = $Statement }
if ($Status) { $object.status = $Status }
if ($Supersedes) { $object.supersedes = $Supersedes }

$safeName = ($generatedId -replace '[:/\\]', '_') + '.json'
$outPath = Join-Path $outDir $safeName
$object | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $outPath -Encoding UTF8

Write-Host "Created $ObjectType object: $generatedId"
Write-Host "Path: $outPath"

if ($PassThru) {
    $object
}
