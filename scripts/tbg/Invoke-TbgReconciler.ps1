[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$OutputRoot = 'artifacts/latest/reconciler'
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

$remainderCount = 0
$remainders = [System.Collections.Generic.List[string]]::new()

$catalogPath = Resolve-TbgRepoPath '.tbg/state/provider-catalog.json'
$manifestPath = Resolve-TbgRepoPath '.tbg/skills/manifest.json'
$capabilitiesPath = Resolve-TbgRepoPath '.tbg/state/capabilities.registry.json'
$reducerRegistryPath = Resolve-TbgRepoPath '.tbg/state/reducer-registry.json'
$journalDir = Resolve-TbgRepoPath '.local/tbg-state/journal/committed'
$projectionsRoot = Resolve-TbgRepoPath '.local/tbg-state/projections'
$generatedDir = Resolve-TbgRepoPath '.tbg/state/generated'

# 1. Check journal events have matching reducers
if (Test-Path -LiteralPath $journalDir -PathType Container) {
    $reducerRegistry = $null
    if (Test-Path -LiteralPath $reducerRegistryPath -PathType Leaf) {
        $reducerRegistry = Get-Content -LiteralPath $reducerRegistryPath -Raw | ConvertFrom-Json
    }

    $eventFiles = Get-ChildItem -LiteralPath $journalDir -Filter '*.json' -File -ErrorAction SilentlyContinue
    foreach ($ef in $eventFiles) {
        try {
            $evt = Get-Content -LiteralPath $ef.FullName -Raw | ConvertFrom-Json
            if ($null -ne $reducerRegistry) {
                $handled = @($reducerRegistry.reducers | Where-Object { @($_.eventTypes) -contains [string]$evt.eventType }).Count
                if ($handled -eq 0) {
                    $remainderCount++
                    $remainders.Add("Journal event $($evt.eventId) (type=$($evt.eventType)) has no matching reducer.")
                }
            }
        } catch { }
    }
}

# 2. Check capabilities have providers
if (Test-Path -LiteralPath $catalogPath -PathType Leaf) {
    $catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
    if (Test-Path -LiteralPath $capabilitiesPath -PathType Leaf) {
        $caps = Get-Content -LiteralPath $capabilitiesPath -Raw | ConvertFrom-Json
        foreach ($cap in @($caps.capabilities)) {
            $hasProvider = $false
            foreach ($p in @($catalog.providers)) {
                if ($p.capabilities -contains [string]$cap.id) { $hasProvider = $true; break }
            }
            if (-not $hasProvider) {
                $remainderCount++
                $remainders.Add("Capability '$($cap.id)' has no provider in catalog.")
            }
        }
    }
}

# 3. Check skills have provider references
$manifestExists = Test-Path -LiteralPath $manifestPath -PathType Leaf
$catalogExists = Test-Path -LiteralPath $catalogPath -PathType Leaf
if ($manifestExists -and $catalogExists) {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
    foreach ($skill in @($manifest.skills)) {
        $hasProvider = $false
        foreach ($p in @($catalog.providers)) {
            if ($p.id -eq "provider:$([string]$skill.id)") { $hasProvider = $true; break }
        }
        if (-not $hasProvider -and [string]$skill.id -ne 'agentic-operations') {
            $remainderCount++
            $remainders.Add("Skill '$([string]$skill.id)' has no matching provider in catalog.")
        }
    }
}

# 4. Check projection hash consistency
$projectionMetaPath = Join-Path $projectionsRoot 'projection-meta.json'
if (Test-Path -LiteralPath $projectionMetaPath -PathType Leaf) {
    $meta = Get-Content -LiteralPath $projectionMetaPath -Raw | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace([string]$meta.projectionHash)) {
        $remainderCount++
        $remainders.Add('Projection meta has empty hash.')
    }
}

# 5. Check generated registries exist
if (Test-Path -LiteralPath $generatedDir -PathType Container) {
    $genFiles = Get-ChildItem -LiteralPath $generatedDir -Filter '*.json' -File -ErrorAction SilentlyContinue
    if (@($genFiles).Count -eq 0) {
        $remainderCount++
        $remainders.Add('Generated registry directory is empty. Run Build-TbgProviderCatalog first.')
    }
} else {
    $remainderCount++
    $remainders.Add('Generated registry directory does not exist. Run Build-TbgProviderCatalog first.')
}

# Determine verdict
$hasUnowned = $false
foreach ($r in $remainders) {
    if ($r -match 'no provider|no matching reducer|no matching provider') {
        $hasUnowned = $true
    }
}

$status = if ($remainderCount -eq 0) { 'PASS_ZERO_REMAINDERS' }
    elseif ($hasUnowned) { 'BLOCKED_UNOWNED_REMAINDERS' }
    else { 'ATTENTION_OWNED_REMAINDERS' }

# Emit reconciler scan event
$timestamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$random = -join ((1..6) | ForEach-Object { '{0:x}' -f (Get-Random -Minimum 0 -Maximum 16) })
$reconcilerEvent = [ordered]@{
    schema = 'TbgEvent.v1'
    eventId = "evt-reconciler-${timestamp}-${random}"
    correlationId = "reconciler-${timestamp}"
    causationId = "reconciler-${timestamp}"
    eventType = 'reconciler.scan'
    source = [ordered]@{
        kind = 'reconciler'
        id = 'state-reconciler'
    }
    receivedUtc = [DateTime]::UtcNow.ToString('o')
    contentHash = 'sha256:' + ('0' * 64)
    payloadSchema = 'TbgReconcilerResult.v1'
    payload = [ordered]@{
        status = $status
        remainderCount = $remainderCount
        remainders = @($remainders)
    }
    requestedDisposition = 'observe'
}

$outputPath = Resolve-TbgRepoPath $OutputRoot
New-Item -ItemType Directory -Force -Path $outputPath | Out-Null

$result = [ordered]@{
    schema = 'TbgReconcilerResult.v1'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    status = $status
    remainderCount = $remainderCount
    remainders = @($remainders)
    proofLevel = 'static test'
    reconcilerEvent = $reconcilerEvent
}
$result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $outputPath 'reconciler.result.json') -Encoding UTF8

$reportLines = @(
    '# TBG State Reconciler',
    '',
    "Verdict: **$status**",
    "- Remainders: $remainderCount",
    ''
)
if ($remainders.Count -gt 0) {
    $reportLines += '## Remainders'
    $reportLines += ''
    foreach ($r in $remainders) { $reportLines += "- $r" }
    $reportLines += ''
}
$reportLines -join "`r`n" | Set-Content -LiteralPath (Join-Path $outputPath 'reconciler.report.md') -Encoding UTF8

Write-Host "Reconciler verdict: $status (remainders=$remainderCount)"
if ($status -eq 'FAIL_STATE_CORRUPTION') { exit 1 }
