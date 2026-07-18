# Smithing batch contract helpers.
# Stub/contract layer only. Future smithing loops should use these shapes to
# prove real stamina/material mutation without cheating.

function New-TbgSmithingBatchPlan {
    param(
        [string]$ActionType,
        [string]$HeroName = $null,
        [object]$StaminaBefore = $null,
        [object]$MaterialReservesBefore = $null,
        [string]$Reason = $null,
        [int]$MaxActions = 1
    )

    return [pscustomobject]@{
        schemaVersion = 1
        actionType = $ActionType
        heroName = $HeroName
        staminaBefore = $StaminaBefore
        materialReservesBefore = $MaterialReservesBefore
        reason = $Reason
        maxActions = $MaxActions
        generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    }
}

function New-TbgSmithingBatchResult {
    param(
        [object]$Plan,
        [object]$StaminaAfter = $null,
        [object]$MaterialReservesAfter = $null,
        [object]$Delta = $null,
        [bool]$FakeGameplayDelta = $false,
        [string]$EvidenceArtifact = $null
    )

    return [pscustomobject]@{
        schemaVersion = 1
        plan = $Plan
        staminaAfter = $StaminaAfter
        materialReservesAfter = $MaterialReservesAfter
        delta = $Delta
        fakeGameplayDelta = [bool]$FakeGameplayDelta
        evidenceArtifact = $EvidenceArtifact
        generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    }
}

function Test-TbgSmithingBatchResultProven {
    param([object]$Result)

    if (-not $Result -or -not $Result.plan) { return $false }
    if ([string]::IsNullOrWhiteSpace([string]$Result.plan.actionType)) { return $false }
    if ($null -eq $Result.plan.staminaBefore) { return $false }
    if ($null -eq $Result.staminaAfter) { return $false }
    if ($null -eq $Result.delta) { return $false }
    if ($Result.fakeGameplayDelta -eq $true) { return $false }
    return $true
}

function Assert-TbgSmithingBatchResultProven {
    param([object]$Result)

    if (-not (Test-TbgSmithingBatchResultProven -Result $Result)) {
        throw 'smithing batch result not proven: before/after/delta evidence required and fakeGameplayDelta must be false'
    }
    return $true
}
