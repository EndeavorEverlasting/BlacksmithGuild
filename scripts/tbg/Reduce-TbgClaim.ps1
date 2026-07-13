[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][hashtable]$Event,
    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$object = [ordered]@{
    schema = 'TbgClaim.v1'
    id = "claim:$($Event.eventId)"
    statement = if ($Event.payload.statement) { $Event.payload.statement } else { "Claim from $($Event.eventType)" }
    supportingEvidence = @("evidence:$($Event.eventId)")
    proofLevel = if ($Event.payload.proofLevel) { $Event.payload.proofLevel } else { 'contract' }
    status = 'active'
    sourceEventId = $Event.eventId
    producedUtc = [DateTime]::UtcNow.ToString('o')
}

$object | ConvertTo-Json -Depth 10 | Write-Output
