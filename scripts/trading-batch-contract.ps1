# Trading batch contract helpers.
# Stub/contract layer only. Future trading loops should prove real inventory/gold
# mutation or write a clear blocked-trade reason.

function New-TbgTradingBatchPlan {
    param(
        [string]$Town,
        [string]$ItemName,
        [ValidateSet('buy','sell','unknown')]
        [string]$TradeAction = 'unknown',
        [double]$ExpectedPrice = 0,
        [string]$Reason = $null,
        [object]$InventoryBefore = $null,
        [object]$GoldBefore = $null
    )

    return [pscustomobject]@{
        schemaVersion = 1
        town = $Town
        itemName = $ItemName
        tradeAction = $TradeAction
        expectedPrice = $ExpectedPrice
        reason = $Reason
        inventoryBefore = $InventoryBefore
        goldBefore = $GoldBefore
        generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    }
}

function New-TbgTradingBatchResult {
    param(
        [object]$Plan,
        [object]$InventoryAfter = $null,
        [object]$GoldAfter = $null,
        [object]$Delta = $null,
        [string]$BlockedReason = $null,
        [bool]$FakeGameplayDelta = $false,
        [string]$EvidenceArtifact = $null
    )

    return [pscustomobject]@{
        schemaVersion = 1
        plan = $Plan
        inventoryAfter = $InventoryAfter
        goldAfter = $GoldAfter
        delta = $Delta
        blockedReason = $BlockedReason
        fakeGameplayDelta = [bool]$FakeGameplayDelta
        evidenceArtifact = $EvidenceArtifact
        generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    }
}

function Test-TbgTradingBatchResultProvenOrBlocked {
    param([object]$Result)

    if (-not $Result -or -not $Result.plan) { return $false }
    if (-not [string]::IsNullOrWhiteSpace([string]$Result.blockedReason)) { return $true }
    if ($null -eq $Result.plan.inventoryBefore -or $null -eq $Result.inventoryAfter) { return $false }
    if ($null -eq $Result.plan.goldBefore -or $null -eq $Result.goldAfter) { return $false }
    if ($null -eq $Result.delta) { return $false }
    if ($Result.fakeGameplayDelta -eq $true) { return $false }
    return $true
}

function Assert-TbgTradingBatchResultProvenOrBlocked {
    param([object]$Result)

    if (-not (Test-TbgTradingBatchResultProvenOrBlocked -Result $Result)) {
        throw 'trading batch result not proven or blocked: inventory/gold before-after delta or blockedReason required'
    }
    return $true
}
