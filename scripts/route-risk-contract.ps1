# Route/advisory risk contract helpers.
# Stub/contract layer only. RouteCouncil/Governor decisions should eventually
# emit this shape before travel execution.

function New-TbgRouteRiskAssessment {
    param(
        [string]$Destination,
        [string]$Reason = $null,
        [ValidateSet('unknown','low','medium','high','blocked')]
        [string]$RiskLevel = 'unknown',
        [string]$KnownRisk = $null,
        [string]$FallbackDestination = $null,
        [bool]$ShouldHold = $false,
        [string]$HoldReason = $null
    )

    return [pscustomobject]@{
        schemaVersion = 1
        destination = $Destination
        reason = $Reason
        riskLevel = $RiskLevel
        knownRisk = $KnownRisk
        fallbackDestination = $FallbackDestination
        shouldHold = [bool]$ShouldHold
        holdReason = $HoldReason
        generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    }
}

function Test-TbgRouteRiskAllowsTravel {
    param([object]$Assessment)

    if (-not $Assessment) { return $false }
    if ([string]::IsNullOrWhiteSpace([string]$Assessment.destination)) { return $false }
    if ($Assessment.shouldHold -eq $true) { return $false }
    if ([string]$Assessment.riskLevel -eq 'blocked') { return $false }
    return $true
}

function Assert-TbgRouteRiskBeforeTravel {
    param([object]$Assessment)

    if (-not (Test-TbgRouteRiskAllowsTravel -Assessment $Assessment)) {
        throw "route risk assessment does not allow travel: $($Assessment | ConvertTo-Json -Compress -Depth 6)"
    }
    return $true
}

function Write-TbgRouteRiskAssessment {
    param(
        [object]$Assessment,
        [string]$Path
    )

    if (-not $Assessment) { throw 'route risk assessment missing' }
    if ($Path) {
        $dir = Split-Path -Parent $Path
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        $Assessment | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
    }
    return $Assessment
}
