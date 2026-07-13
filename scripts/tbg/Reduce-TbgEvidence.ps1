[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][hashtable]$Event,
    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$object = [ordered]@{
    schema = 'TbgEvidenceRecord.v1'
    id = "evidence:$($Event.eventId)"
    subject = if ($Event.payload.subject) { $Event.payload.subject } else { $Event.eventType }
    statement = if ($Event.payload.statement) { $Event.payload.statement } else { "Evidence from $($Event.eventType)" }
    proofLevel = if ($Event.payload.proofLevel) { $Event.payload.proofLevel } else { 'contract' }
    sourceEventId = $Event.eventId
    producedUtc = [DateTime]::UtcNow.ToString('o')
}

$object | ConvertTo-Json -Depth 10 | Write-Output
