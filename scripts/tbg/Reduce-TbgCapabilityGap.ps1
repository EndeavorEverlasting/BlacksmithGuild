[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][hashtable]$Event,
    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$object = [ordered]@{
    schema = 'TbgWorkItem.v1'
    id = "work-item:gap-$($Event.eventId -replace 'evt-', '')"
    objective = "objective:$($Event.eventId -replace 'evt-', '')"
    status = 'blocked'
    requestedCapabilities = if ($Event.payload.missingCapabilities) { @($Event.payload.missingCapabilities) } else { @() }
    preconditions = @()
    ownedPaths = @()
    forbiddenPaths = @()
    expectedOutputs = @('provider registered', 'capability validated')
    blockedBy = @('no provider found')
    sourceEventId = $Event.eventId
    producedUtc = [DateTime]::UtcNow.ToString('o')
}

$object | ConvertTo-Json -Depth 10 | Write-Output
