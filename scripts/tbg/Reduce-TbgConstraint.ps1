[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][hashtable]$Event,
    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$object = [ordered]@{
    schema = 'TbgConstraint.v1'
    id = "constraint:$($Event.eventId -replace 'evt-', '')"
    appliesWhen = @{ always = $true }
    rule = if ($Event.payload.rule) { $Event.payload.rule } else { "Constraint from $($Event.eventType)" }
    authority = $Event.source.id
    severity = if ($Event.payload.severity) { $Event.payload.severity } else { 'blocking' }
    scope = @('contract', 'harness', 'static test')
    status = 'active'
    sourceEventId = $Event.eventId
    producedUtc = [DateTime]::UtcNow.ToString('o')
}

$object | ConvertTo-Json -Depth 10 | Write-Output
