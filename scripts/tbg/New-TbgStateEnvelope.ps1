[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-TbgRepoPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    Join-Path $RepoRoot ($RelativePath -replace '/', [IO.Path]::DirectorySeparatorChar)
}

$objectStore = Resolve-TbgRepoPath 'artifacts/state/objects'
$envelopeDir = Resolve-TbgRepoPath 'artifacts/latest/state'
New-Item -ItemType Directory -Force -Path $envelopeDir | Out-Null

$gitHead = (git -C $RepoRoot rev-parse HEAD).Trim()
$gitBranch = (git -C $RepoRoot branch --show-current).Trim()

$timestamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$random = -join ((1..6) | ForEach-Object { '{0:x}' -f (Get-Random -Minimum 0 -Maximum 16) })
$envelopeId = "state-${timestamp}-${random}"

function Collect-ObjectIds {
    param([string]$SubDir, [string]$Pattern)
    $dir = Join-Path $objectStore $SubDir
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { return @() }
    $files = Get-ChildItem -LiteralPath $dir -Filter '*.json' -File
    $ids = @()
    foreach ($f in $files) {
        try {
            $obj = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json
            $ids += [string]$obj.id
        } catch {
            Write-Warning "Skipping malformed file: $($f.FullName)"
        }
    }
    return $ids
}

$obsIds = @(Collect-ObjectIds 'observations')
$evidenceIds = @(Collect-ObjectIds 'evidence')
$claimIds = @(Collect-ObjectIds 'claims')
$constraintIds = @(Collect-ObjectIds 'constraints')
$objectiveIds = @(Collect-ObjectIds 'objectives')
$workItemIds = @(Collect-ObjectIds 'work-items')
$capabilityIds = @(Collect-ObjectIds 'capabilities')

$activeConstraints = @()
foreach ($cId in $constraintIds) {
    $cFile = Join-Path (Join-Path $objectStore 'constraints') ($cId -replace '[:/\\]', '_') + '.json'
    if (Test-Path -LiteralPath $cFile -PathType Leaf) {
        $cObj = Get-Content -LiteralPath $cFile -Raw | ConvertFrom-Json
        if ($cObj.status -eq 'active' -or (-not $cObj.PSObject.Properties.Name -contains 'status')) {
            $activeConstraints += $cId
        }
    }
}

$currentObjective = $null
foreach ($oId in $objectiveIds) {
    $oFile = Join-Path (Join-Path $objectStore 'objectives') ($oId -replace '[:/\\]', '_') + '.json'
    if (Test-Path -LiteralPath $oFile -PathType Leaf) {
        $oObj = Get-Content -LiteralPath $oFile -Raw | ConvertFrom-Json
        if ($oObj.status -eq 'active') {
            $currentObjective = $oId
            break
        }
    }
}

$readyWorkItems = @()
foreach ($wiId in $workItemIds) {
    $wiFile = Join-Path (Join-Path $objectStore 'work-items') ($wiId -replace '[:/\\]', '_') + '.json'
    if (Test-Path -LiteralPath $wiFile -PathType Leaf) {
        $wiObj = Get-Content -LiteralPath $wiFile -Raw | ConvertFrom-Json
        if ($wiObj.status -eq 'ready') {
            $readyWorkItems += $wiId
        }
    }
}

$blockers = @()
foreach ($wiId in @($readyWorkItems)) {
    $wiFile = Join-Path (Join-Path $objectStore 'work-items') ($wiId -replace '[:/\\]', '_') + '.json'
    if (Test-Path -LiteralPath $wiFile -PathType Leaf) {
        $wiObj = Get-Content -LiteralPath $wiFile -Raw | ConvertFrom-Json
        if ($wiObj.PSObject.Properties.Name -contains 'blockedBy') {
            $blocked = @($wiObj.blockedBy)
            if ($blocked.Count -gt 0) {
                $blockers += $blocked
            }
        }
    }
}

$readyArr = @($readyWorkItems)
$blockersArr = @($blockers)
$terminalStatus = if ($blockersArr.Count -gt 0) { 'BLOCKED' }
    elseif ($readyArr.Count -gt 0) { 'READY_FOR_ROUTING' }
    else { 'READY_FOR_ROUTING' }

$nextDecision = if ($readyArr.Count -gt 0) { "select from $($readyArr.Count) ready work items" }
    else { 'no work items registered' }

$envelope = [ordered]@{
    schema = 'TbgStateEnvelope.v1'
    envelopeId = $envelopeId
    repo = [ordered]@{
        remote = 'EndeavorEverlasting/BlacksmithGuild'
        head = $gitHead
        branch = $gitBranch
    }
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    previousEnvelope = $null
    objectRefs = [ordered]@{
        observations = $obsIds
        constraints = $constraintIds
        objectives = $objectiveIds
        workItems = $workItemIds
        evidence = $evidenceIds
        claims = $claimIds
        capabilities = $capabilityIds
        resources = @()
        decisions = @()
    }
    activeConstraints = $activeConstraints
    currentObjective = $currentObjective
    terminalState = [ordered]@{
        status = $terminalStatus
        blockers = $blockers
        nextDecision = $nextDecision
    }
}

$envelopePath = Join-Path $envelopeDir 'tbg-state-envelope.json'
$envelope | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $envelopePath -Encoding UTF8

$reportLines = @(
    '# TBG State Envelope',
    '',
    "Envelope **$envelopeId** generated at $($envelope.generatedUtc).",
    '',
    "- Repo head: $($gitHead.Substring(0,12)) on **$gitBranch**",
    "- Observations: $($obsIds.Count)",
    "- Evidence records: $($evidenceIds.Count)",
    "- Claims: $($claimIds.Count)",
    "- Active constraints: $($activeConstraints.Count)",
    "- Objectives: $($objectiveIds.Count)",
    "- Work items: $($workItemIds.Count) ($($readyWorkItems.Count) ready)",
    "- Capabilities: $($capabilityIds.Count)",
    "- Terminal status: **$terminalStatus**",
    "- Next decision: $nextDecision",
    ''
)
if ($blockers.Count -gt 0) {
    $reportLines += '## Blockers'
    $reportLines += ''
    foreach ($b in $blockers) {
        $reportLines += "- $b"
    }
    $reportLines += ''
}
$reportLines -join "`r`n" | Set-Content -LiteralPath (Join-Path $envelopeDir 'tbg-state-envelope.report.md') -Encoding UTF8

Write-Host "State envelope: $envelopeId"
Write-Host "Terminal status: $terminalStatus"
Write-Host "Objects: obs=$($obsIds.Count) evidence=$($evidenceIds.Count) claims=$($claimIds.Count) constraints=$($activeConstraints.Count) objectives=$($objectiveIds.Count) workItems=$($workItemIds.Count) capabilities=$($capabilityIds.Count)"
Write-Host "Envelope: $envelopePath"
