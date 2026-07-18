[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][hashtable]$Event,
    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$object = [ordered]@{
    schema = 'TbgWorkItem.v1'
    id = "work-item:$($Event.eventId -replace 'evt-', '')"
    objective = "objective:$($Event.eventId -replace 'evt-', '')"
    status = if ($Event.payload.disposition) { $Event.payload.disposition } elseif ($Event.eventType -eq 'action.completed') { 'completed' } else { 'blocked' }
    requestedCapabilities = @()
    preconditions = @()
    ownedPaths = @()
    forbiddenPaths = @()
    expectedOutputs = @()
    sourceEventId = $Event.eventId
    producedUtc = [DateTime]::UtcNow.ToString('o')
}

$object | ConvertTo-Json -Depth 10 | Write-Output
