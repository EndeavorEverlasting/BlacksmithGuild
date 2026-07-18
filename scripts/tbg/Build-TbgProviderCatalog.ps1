[CmdletBinding()]
param(
    [string]$RepoRoot,
    [switch]$CheckDrift
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

$errors = [System.Collections.Generic.List[string]]::new()

$catalogPath = Resolve-TbgRepoPath '.tbg/state/provider-catalog.json'
$manifestPath = Resolve-TbgRepoPath '.tbg/skills/manifest.json'
$capabilitiesPath = Resolve-TbgRepoPath '.tbg/state/capabilities.registry.json'
$generatedDir = Resolve-TbgRepoPath '.tbg/state/generated'
New-Item -ItemType Directory -Force -Path $generatedDir | Out-Null

$catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$capabilities = Get-Content -LiteralPath $capabilitiesPath -Raw | ConvertFrom-Json

foreach ($cap in @($capabilities.capabilities)) {
    $hasProvider = $false
    foreach ($p in @($catalog.providers)) {
        if ($p.capabilities -contains [string]$cap.id) {
            $hasProvider = $true
            break
        }
    }
    if (-not $hasProvider) {
        $errors.Add("Capability '$($cap.id)' has no provider in the catalog.")
    }
}

$skillIds = @($manifest.skills | ForEach-Object { [string]$_.id })
$providerSkillIds = @($catalog.providers | Where-Object { $_.type -eq 'skill' } | ForEach-Object { $_.id -replace '^provider:', '' })
foreach ($sid in $skillIds) {
    $hasCapability = $false
    foreach ($p in @($catalog.providers)) {
        if ($p.id -eq "provider:$sid" -and @($p.capabilities).Count -gt 0) {
            $hasCapability = $true
            break
        }
    }
}

$genCapabilities = [ordered]@{
    schema = 'TbgCapabilitiesRegistry.v1'
    repo = 'EndeavorEverlasting/BlacksmithGuild'
    description = 'Generated from provider catalog. Do not edit directly.'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    capabilities = @()
}
foreach ($p in @($catalog.providers)) {
    foreach ($capId in @($p.capabilities)) {
            $providerName = $p.id -replace '^provider:', ''
            $providedByRef = if ($p.type -eq 'skill') { "skill:$providerName" } else { $p.id }
            $genCapabilities.capabilities += [ordered]@{
                id = $capId
                providedBy = @($providedByRef)
            consumes = $p.inputSchemas
            produces = $p.outputSchemas
            maxProofLevel = $p.maxProofLevel
            riskClasses = $p.riskClasses
            authorityRequirements = $p.authorityRequirements
        }
    }
}

$genCapPath = Join-Path $generatedDir 'capabilities.registry.json'
$genCapabilities | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $genCapPath -Encoding UTF8

$skillCapMap = [ordered]@{
    schema = 'TbgSkillCapabilityMap.v1'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    mappings = @()
}
foreach ($p in @($catalog.providers | Where-Object { $_.type -eq 'skill' })) {
    $skillCapMap.mappings += [ordered]@{
        skillId = $p.id -replace '^provider:', ''
        providerId = $p.id
        capabilities = @($p.capabilities)
    }
}
$skillCapMap | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $generatedDir 'skill-capability-map.json') -Encoding UTF8

$workflowCapMap = [ordered]@{
    schema = 'TbgWorkflowCapabilityMap.v1'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    mappings = @()
}
$workflowCapMap | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $generatedDir 'workflow-capability-map.json') -Encoding UTF8

if ($CheckDrift) {
    $existingCapPath = $capabilitiesPath
    if (Test-Path -LiteralPath $existingCapPath -PathType Leaf) {
        $existing = Get-Content -LiteralPath $existingCapPath -Raw | ConvertFrom-Json
        $existingCapIds = @($existing.capabilities | ForEach-Object { [string]$_.id } | Sort-Object)
        $generatedCapIds = @($genCapabilities.capabilities | ForEach-Object { [string]$_.id } | Sort-Object)
        if ($existingCapIds.Count -ne $generatedCapIds.Count) {
            $errors.Add("Generated capabilities count ($($generatedCapIds.Count)) differs from committed ($($existingCapIds.Count)).")
        } else {
            for ($i = 0; $i -lt $existingCapIds.Count; $i++) {
                if ($existingCapIds[$i] -ne $generatedCapIds[$i]) {
                    $errors.Add("Capability ID mismatch at position ${i}: committed='$($existingCapIds[$i])' vs generated='$($generatedCapIds[$i])'.")
                    break
                }
            }
        }
    }
}

$status = if ($errors.Count -eq 0) { 'PASS_ZERO_REMAINDERS' } else { 'FAIL_REGISTRY_DRIFT' }
Write-Host "Provider catalog validation: $status (errors=$($errors.Count))"
if ($errors.Count -gt 0) {
    foreach ($e in $errors) { Write-Host "  ERROR: $e" }
    exit 1
}
