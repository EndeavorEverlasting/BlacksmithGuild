# Non-cheat mutation proof contract helpers.
# Stub/contract layer only. Mutating gameplay actions should eventually emit
# records shaped like this contract.

function New-TbgMutationProofRecord {
    param(
        [string]$ActionName,
        [string]$MutationType,
        [object]$BeforeState = $null,
        [object]$AfterState = $null,
        [object]$Delta = $null,
        [bool]$ActionRequested = $false,
        [bool]$ActionAccepted = $false,
        [bool]$FakeGameplayDelta = $false,
        [string]$EvidenceArtifact = $null
    )

    return [pscustomobject]@{
        schemaVersion = 1
        actionName = $ActionName
        mutationType = $MutationType
        actionRequested = [bool]$ActionRequested
        actionAccepted = [bool]$ActionAccepted
        beforeState = $BeforeState
        afterState = $AfterState
        delta = $Delta
        fakeGameplayDelta = [bool]$FakeGameplayDelta
        evidenceArtifact = $EvidenceArtifact
        generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    }
}

function Test-TbgMutationProofComplete {
    param([object]$Record)

    if (-not $Record) { return $false }
    if ([string]::IsNullOrWhiteSpace([string]$Record.actionName)) { return $false }
    if ([string]::IsNullOrWhiteSpace([string]$Record.mutationType)) { return $false }
    if ($Record.actionRequested -ne $true) { return $false }
    if ($Record.actionAccepted -ne $true) { return $false }
    if ($null -eq $Record.beforeState) { return $false }
    if ($null -eq $Record.afterState) { return $false }
    if ($null -eq $Record.delta) { return $false }
    return $true
}

function Assert-TbgMutationProofNotFake {
    param([object]$Record)

    if (-not (Test-TbgMutationProofComplete -Record $Record)) {
        throw 'mutation proof incomplete: before/action/after/delta evidence required'
    }
    if ($Record.fakeGameplayDelta -eq $true) {
        throw 'mutation proof cannot count fakeGameplayDelta=true as product proof'
    }
    return $true
}

function Write-TbgMutationProofReport {
    param(
        [object]$Record,
        [string]$Path
    )

    Assert-TbgMutationProofNotFake -Record $Record | Out-Null
    if ($Path) {
        $dir = Split-Path -Parent $Path
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        $Record | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8
    }
    return $Record
}
