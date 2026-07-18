[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][hashtable]$Event,
    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$object = [ordered]@{
    schema = 'TbgObservation.v1'
    id = "observation:$($Event.eventId)"
    subject = if ($Event.payload.subject) { $Event.payload.subject } else { $Event.eventType }
    predicate = if ($Event.payload.predicate) { $Event.payload.predicate } else { 'observed' }
    value = if ($Event.payload.value) { $Event.payload.value } else { ($Event.payload | ConvertTo-Json -Compress) }
    sourceEventId = $Event.eventId
    producedUtc = [DateTime]::UtcNow.ToString('o')
}

$object | ConvertTo-Json -Depth 10 | Write-Output
