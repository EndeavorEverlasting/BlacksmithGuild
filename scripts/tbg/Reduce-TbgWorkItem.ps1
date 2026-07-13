[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][hashtable]$Event,
    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$wiStatus = switch ([string]$Event.eventType) {
    'user.request' { 'received' }
    'work.item.created' { 'received' }
    'work.item.transitioned' { if ($Event.payload.status) { $Event.payload.status } else { 'received' } }
    default { 'received' }
}

$object = [ordered]@{
    schema = 'TbgWorkItem.v1'
    id = "work-item:$($Event.eventId -replace 'evt-', '')"
    objective = "objective:$($Event.eventId -replace 'evt-', '')"
    status = $wiStatus
    requestedCapabilities = if ($Event.payload.requestedCapabilities) { @($Event.payload.requestedCapabilities) } else { @() }
    preconditions = @()
    ownedPaths = @()
    forbiddenPaths = @()
    expectedOutputs = if ($Event.payload.expectedOutputs) { @($Event.payload.expectedOutputs) } else { @() }
    sourceEventId = $Event.eventId
    producedUtc = [DateTime]::UtcNow.ToString('o')
}

$object | ConvertTo-Json -Depth 10 | Write-Output
