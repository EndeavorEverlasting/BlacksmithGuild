$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$doc = Join-Path $repoRoot 'docs\operator\surface-ownership-governance.md'
$manifest = Join-Path $repoRoot 'docs\handoff\surface-ownership.manifest.json'
$classifier = Join-Path $repoRoot 'scripts\reboot-context-classifier.ps1'
$test = Join-Path $repoRoot 'scripts\test-reboot-context-classifier.ps1'

if (-not (Test-Path -LiteralPath $doc)) {
    throw 'Missing docs/operator/surface-ownership-governance.md'
}
if (-not (Test-Path -LiteralPath $manifest)) {
    throw 'Missing docs/handoff/surface-ownership.manifest.json'
}
if (-not (Test-Path -LiteralPath $classifier)) {
    throw 'Missing scripts/reboot-context-classifier.ps1'
}
if (-not (Test-Path -LiteralPath $test)) {
    throw 'Missing scripts/test-reboot-context-classifier.ps1'
}

$json = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
if ([int]$json.normalActionTimeoutSec -gt 30) {
    throw 'surface ownership normalActionTimeoutSec must not exceed 30'
}
if ([int]$json.repeatThreshold -lt 2) {
    throw 'surface ownership repeatThreshold must be >= 2'
}
if ($json.movementDoctrine.partyMovedDistanceZeroIsSoleNoMovementProof -ne $false) {
    throw 'movement doctrine must reject partyMovedDistance == 0 as sole no-movement proof'
}
if ($json.movementDoctrine.movementShouldUseDiscreteCheckpointEvidence -ne $true) {
    throw 'movement doctrine must require discrete/checkpoint movement evidence'
}
if ($json.movementDoctrine.routeIntentIsMovementProof -ne $false) {
    throw 'route intent must not be treated as movement proof'
}
if ($json.movementDoctrine.attachReadinessIsGameplayProof -ne $false) {
    throw 'attach readiness must not be treated as gameplay proof'
}

$groups = @($json.surfaceGroups | ForEach-Object { $_.surfaceGroup })
foreach ($required in @('outside_town','inside_town','interruption_recovery','launcher_attach','evidence_staleness')) {
    if ($groups -notcontains $required) {
        throw "surface-ownership manifest missing surfaceGroup=$required"
    }
}

foreach ($group in @($json.surfaceGroups)) {
    foreach ($field in @('surfaceGroup','owner','stableGapOwner','nextPatchLane','surfaces','owns','doesNotOwn','proofRequirements')) {
        if (-not $group.PSObject.Properties.Name.Contains($field)) {
            throw "surface group $($group.surfaceGroup) missing field $field"
        }
    }
}

$handoffs = @($json.handoffs | ForEach-Object { $_.contractId })
foreach ($required in @('handoff.outside_to_inside','handoff.inside_to_outside','stable_gap.surface_owner_routing','movement.discrete_checkpoint_proof')) {
    if ($handoffs -notcontains $required) {
        throw "surface-ownership manifest missing handoff contractId=$required"
    }
}

$docText = Get-Content -LiteralPath $doc -Raw
foreach ($needle in @(
    'The one-click harness coordinates.',
    'Surface engines decide.',
    'Stable gaps route ownership.',
    'partyMovedDistance == 0 alone is not proof that movement did not occur',
    'outside_town',
    'inside_town',
    'interruption_recovery',
    'launcher_attach',
    'evidence_staleness'
)) {
    if ($docText -notmatch [regex]::Escape($needle)) {
        throw "surface ownership doc missing doctrine needle: $needle"
    }
}

$classifierText = Get-Content -LiteralPath $classifier -Raw
foreach ($needle in @(
    'Get-RebootSurfaceOwnershipManifest',
    'ConvertTo-RebootSurfaceKey',
    'Resolve-RebootSurfaceOwnership',
    'surfaceGroup',
    'surfaceOwner',
    'stableGapOwner',
    'nextPatchLane',
    'legacyLikelyOwner'
)) {
    if ($classifierText -notmatch [regex]::Escape($needle)) {
        throw "reboot classifier missing surface ownership needle: $needle"
    }
}

$testText = Get-Content -LiteralPath $test -Raw
foreach ($needle in @(
    'Resolve-RebootSurfaceOwnership',
    'Expected campaign_map to route to outside_town',
    'Expected settlement_menu to route to inside_town',
    'Expected foreground loss to route to interruption_recovery',
    'Expected stale evidence to route to evidence_staleness',
    'likelyOwner should route through stableGapOwner'
)) {
    if ($testText -notmatch [regex]::Escape($needle)) {
        throw "reboot classifier test missing surface ownership needle: $needle"
    }
}

Write-Host 'PASS: surface ownership governance contract verified.'
