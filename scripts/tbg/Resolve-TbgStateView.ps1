[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SkillId,
    [string]$RepoRoot
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

$envelopePath = Resolve-TbgRepoPath 'artifacts/latest/state/tbg-state-envelope.json'
if (-not (Test-Path -LiteralPath $envelopePath -PathType Leaf)) {
    throw "State envelope not found at $envelopePath. Run New-TbgStateEnvelope.ps1 first."
}

$envelope = Get-Content -LiteralPath $envelopePath -Raw | ConvertFrom-Json
$viewsDir = Resolve-TbgRepoPath 'artifacts/latest/state/views'
New-Item -ItemType Directory -Force -Path $viewsDir | Out-Null

$manifestPath = Resolve-TbgRepoPath '.tbg/skills/manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$skill = $manifest.skills | Where-Object { $_.id -eq $SkillId }
if (-not $skill) {
    throw "Skill '$SkillId' not found in manifest."
}

$proofCeiling = [string]$skill.proofCeiling

$relevantEvidence = @()
$relevantClaims = @()
$objectiveRefs = @()
$readyWorkItems = @()

if ($envelope.objectRefs.evidence) {
    foreach ($eId in $envelope.objectRefs.evidence) {
        $eFile = Join-Path (Resolve-TbgRepoPath 'artifacts/state/objects/evidence') (($eId -replace '[:/\\]', '_') + '.json')
        if (Test-Path -LiteralPath $eFile -PathType Leaf) {
            $relevantEvidence += $eId
        }
    }
}

if ($envelope.objectRefs.claims) {
    foreach ($cId in $envelope.objectRefs.claims) {
        $cFile = Join-Path (Resolve-TbgRepoPath 'artifacts/state/objects/claims') (($cId -replace '[:/\\]', '_') + '.json')
        if (Test-Path -LiteralPath $cFile -PathType Leaf) {
            $cObj = Get-Content -LiteralPath $cFile -Raw | ConvertFrom-Json
            if ($cObj.status -eq 'supported') {
                $relevantClaims += $cId
            }
        }
    }
}

if ($envelope.objectRefs.objectives) {
    $objectiveRefs = @($envelope.objectRefs.objectives)
}

if ($envelope.objectRefs.workItems) {
    foreach ($wiId in $envelope.objectRefs.workItems) {
        $wiFile = Join-Path (Resolve-TbgRepoPath 'artifacts/state/objects/work-items') (($wiId -replace '[:/\\]', '_') + '.json')
        if (Test-Path -LiteralPath $wiFile -PathType Leaf) {
            $wiObj = Get-Content -LiteralPath $wiFile -Raw | ConvertFrom-Json
            if ($wiObj.status -eq 'ready') {
                $readyWorkItems += $wiId
            }
        }
    }
}

$view = [ordered]@{
    schema = 'TbgStateView.v1'
    viewId = $SkillId
    sourceEnvelope = $envelope.envelopeId
    objectiveRefs = $objectiveRefs
    readyWorkItems = $readyWorkItems
    activeConstraints = @($envelope.activeConstraints)
    relevantEvidence = $relevantEvidence
    relevantClaims = $relevantClaims
    resources = @()
    proofCeiling = $proofCeiling
    generatedUtc = [DateTime]::UtcNow.ToString('o')
}

$viewPath = Join-Path $viewsDir "$SkillId.json"
$view | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $viewPath -Encoding UTF8

Write-Host "State view for skill '$SkillId': $viewPath"
Write-Host "  source envelope: $($envelope.envelopeId)"
Write-Host "  proof ceiling: $proofCeiling"
Write-Host "  ready work items: $($readyWorkItems.Count)"
Write-Host "  active constraints: $($envelope.activeConstraints.Count)"
