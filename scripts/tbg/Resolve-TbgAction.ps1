[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$EventType,
    [Parameter(Mandatory = $true)][string]$SourceKind,
    [Parameter(Mandatory = $true)][string]$SourceId,
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

$catalogPath = Resolve-TbgRepoPath '.tbg/state/provider-catalog.json'
$catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json

function Get-TbgRiskClass {
    param([string]$EventT, [string]$SourceK)
    switch -Wildcard ($EventT) {
        'git.state.captured' { return 'static' }
        'pr.lifecycle.result' { return 'static' }
        'build.result' { return 'static' }
        'validator.result' { return 'static' }
        'hygiene.report' { return 'static' }
        'artifact.*' { return 'local_read_write' }
        'chat.packet' { return 'static' }
        'skill.routed' { return 'static' }
        'user.request' { return 'static' }
        'command.*' { return 'runtime_write' }
        'runtime.*' { return 'runtime_read' }
        'launcher.*' { return 'runtime_write' }
        default { return 'static' }
    }
}

$riskClass = Get-TbgRiskClass -EventT $EventType -SourceK $SourceKind

$timestamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$random = -join ((1..6) | ForEach-Object { '{0:x}' -f (Get-Random -Minimum 0 -Maximum 16) })
$actionId = "action-${timestamp}-${random}"

$matchingProvider = $null
foreach ($p in @($catalog.providers)) {
    if ($p.id -eq 'provider:universal-intake-governor') { continue }
    if ($p.riskClasses -contains $riskClass -or @($p.riskClasses).Count -eq 0) {
        $matchingProvider = $p
        break
    }
}

if ($null -ne $matchingProvider) {
    $action = [ordered]@{
        schema = 'TbgAction.v1'
        id = $actionId
        sourceEventId = "evt-${timestamp}-${random}"
        status = 'authorized'
        riskClass = $riskClass
        provider = $matchingProvider.id
        terminalStates = @('completed', 'failed', 'blocked')
        producedUtc = [DateTime]::UtcNow.ToString('o')
    }
    $action | ConvertTo-Json -Depth 10 | Write-Output
}
else {
    $gapId = "gap-${timestamp}-${random}"
    $gap = [ordered]@{
        schema = 'TbgCapabilityGap.v1'
        id = "gap:$gapId"
        requestedBy = "source:${SourceKind}:${SourceId}"
        missingCapabilities = @("capability-for-${EventType}")
        nearestProviders = @()
        owner = 'provider:universal-intake-governor'
        status = 'OPEN'
        blocking = $true
        acceptanceNeeded = @('provider registered', 'input/output schemas registered', 'validator registered')
        producedUtc = [DateTime]::UtcNow.ToString('o')
    }
    $action = [ordered]@{
        schema = 'TbgAction.v1'
        id = $actionId
        sourceEventId = "evt-${timestamp}-${random}"
        status = 'blocked'
        riskClass = $riskClass
        provider = 'provider:universal-intake-governor'
        requiredAuthorization = "No provider found for risk class '$riskClass' and event type '$EventType'. Capability gap created."
        terminalStates = @('completed', 'failed', 'blocked')
        error = "Capability gap: $gapId"
        producedUtc = [DateTime]::UtcNow.ToString('o')
    }
    $gap | ConvertTo-Json -Depth 10 | Write-Output
    $action | ConvertTo-Json -Depth 10 | Write-Output
}
