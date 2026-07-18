# Companion/stamina handling contract helpers.
# Stub/contract layer only. Future smithing audit should explain companion
# eligibility, smithy visibility, and usable stamina.

function New-TbgCompanionStaminaEntry {
    param(
        [string]$HeroName,
        [bool]$InParty = $false,
        [bool]$EligibleForSmithing = $false,
        [bool]$VisibleInSmithy = $false,
        [double]$Stamina = 0,
        [string]$BlockedReason = $null
    )

    return [pscustomobject]@{
        heroName = $HeroName
        inParty = [bool]$InParty
        eligibleForSmithing = [bool]$EligibleForSmithing
        visibleInSmithy = [bool]$VisibleInSmithy
        stamina = $Stamina
        blockedReason = $BlockedReason
    }
}

function New-TbgCompanionStaminaAudit {
    param(
        [object]$MainHero = $null,
        [object[]]$Companions = @(),
        [string]$SmithyContext = $null
    )

    return [pscustomobject]@{
        schemaVersion = 1
        mainHero = $MainHero
        companions = @($Companions)
        smithyContext = $SmithyContext
        generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    }
}

function Test-TbgCompanionStaminaAuditExplainsAvailability {
    param([object]$Audit)

    if (-not $Audit) { return $false }
    if (-not $Audit.mainHero) { return $false }
    foreach ($companion in @($Audit.companions)) {
        if ([string]::IsNullOrWhiteSpace([string]$companion.heroName)) { return $false }
        if ($companion.visibleInSmithy -ne $true -and [string]::IsNullOrWhiteSpace([string]$companion.blockedReason)) { return $false }
    }
    return $true
}

function Assert-TbgCompanionStaminaAuditExplainsAvailability {
    param([object]$Audit)

    if (-not (Test-TbgCompanionStaminaAuditExplainsAvailability -Audit $Audit)) {
        throw 'companion stamina audit must include main hero and explain each unavailable companion'
    }
    return $true
}
