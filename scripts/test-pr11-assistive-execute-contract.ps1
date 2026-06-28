# Targeted regression for durable movement proof in PR11 assistive execute contract.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'pr11-assistive-execute-contract.ps1')

function Assert-DurableMovement {
    param(
        [object]$ExecutionJson,
        [bool]$Expected,
        [string]$Name
    )
    $actual = Test-Pr11DurableMovementObserved -ExecutionJson $ExecutionJson
    if ([bool]$actual -ne [bool]$Expected) {
        throw "$Name expected durable movement=$Expected got $actual"
    }
}

Assert-DurableMovement -Name 'zero-distance metric disagreement' -Expected $true -ExecutionJson ([pscustomobject]@{
    partyMovedDistance = 0
    movementMetricDisagreement = $true
    movementCheckpointObserved = $true
    movementProofClassification = 'MovementMetricDisagreement'
})

Assert-DurableMovement -Name 'zero-distance checkpoint observed' -Expected $true -ExecutionJson ([pscustomobject]@{
    partyMovedDistance = 0
    movementMetricDisagreement = $false
    movementCheckpointObserved = $true
    movementProofClassification = 'MovementCheckpointObserved'
})

Assert-DurableMovement -Name 'zero-distance indeterminate negative' -Expected $false -ExecutionJson ([pscustomobject]@{
    partyMovedDistance = 0
    movementMetricDisagreement = $false
    movementCheckpointObserved = $false
    movementProofClassification = 'MovementObservationIndeterminate'
})

Assert-DurableMovement -Name 'zero-distance fair-window not observed negative' -Expected $false -ExecutionJson ([pscustomobject]@{
    partyMovedDistance = 0
    movementMetricDisagreement = $false
    movementCheckpointObserved = $false
    movementProofClassification = 'MovementNotObservedAfterFairWindow'
})

Write-Host 'PASS pr11 durable movement proof regression' -ForegroundColor Green
exit 0