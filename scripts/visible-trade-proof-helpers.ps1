# Minimal helpers for visible-trade proof coordinator on current main.
# Replaces PR #43-only cycle-contract / bannerlord-paths SHA helpers without
# importing the obsolete launcher-validation stack.

Set-StrictMode -Version Latest

function Test-TbgObjectProperty {
    param(
        $InputObject,
        [Parameter(Mandatory = $true)][string]$Name
    )

    return $null -ne $InputObject -and $null -ne $InputObject.PSObject.Properties[$Name]
}

function Get-TbgObjectProperty {
    param(
        $InputObject,
        [Parameter(Mandatory = $true)][string]$Name,
        $Default = $null
    )

    if (-not (Test-TbgObjectProperty -InputObject $InputObject -Name $Name)) {
        return $Default
    }

    return $InputObject.$Name
}

function Get-TbgFileSha256 {
    param([Parameter(Mandatory = $true)][string]$LiteralPath)

    $stream = [System.IO.File]::OpenRead($LiteralPath)
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace('-', '')
    } finally {
        $algorithm.Dispose()
        $stream.Dispose()
    }
}

function ConvertFrom-TbgMapPosition {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $numberPattern = '[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?'
    $match = [regex]::Match(
        $Value,
        "(?i)\bX\s*:\s*(?<x>$numberPattern)[^\r\n]*?\bY\s*:\s*(?<y>$numberPattern)")
    if (-not $match.Success) {
        return $null
    }

    $styles = [System.Globalization.NumberStyles]::Float
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    [double]$x = 0
    [double]$y = 0
    if (-not [double]::TryParse($match.Groups['x'].Value, $styles, $culture, [ref]$x) `
        -or -not [double]::TryParse($match.Groups['y'].Value, $styles, $culture, [ref]$y)) {
        return $null
    }

    return [pscustomobject][ordered]@{
        x = $x
        y = $y
    }
}

function Get-TbgMapPositionDistance {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$StartPosition,

        [AllowNull()]
        [AllowEmptyString()]
        [string]$EndPosition
    )

    $start = ConvertFrom-TbgMapPosition -Value $StartPosition
    $end = ConvertFrom-TbgMapPosition -Value $EndPosition
    if ($null -eq $start -or $null -eq $end) {
        return $null
    }

    $xDelta = [double]$end.x - [double]$start.x
    $yDelta = [double]$end.y - [double]$start.y
    return [Math]::Sqrt(($xDelta * $xDelta) + ($yDelta * $yDelta))
}

function Test-TbgMapTradeCertLineage {
    param(
        $Cert,
        [Parameter(Mandatory = $true)]
        [datetime]$NotBeforeUtc
    )

    if ($null -eq $Cert) {
        return $false
    }

    $source = [string](Get-TbgObjectProperty $Cert 'source' '')
    if ($source -notmatch '^governor:[0-9a-fA-F]{32}$') {
        return $false
    }

    $dateStyles = [System.Globalization.DateTimeStyles]::AssumeUniversal `
        -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $minimumUtc = $NotBeforeUtc.ToUniversalTime()
    foreach ($field in @('startedAtUtc', 'generatedUtc')) {
        $rawTimestamp = [string](Get-TbgObjectProperty $Cert $field '')
        [datetimeoffset]$parsedTimestamp = [datetimeoffset]::MinValue
        if (-not [datetimeoffset]::TryParse(
                $rawTimestamp,
                $culture,
                $dateStyles,
                [ref]$parsedTimestamp)) {
            return $false
        }
        if ($parsedTimestamp.UtcDateTime -lt $minimumUtc) {
            return $false
        }
    }

    return $true
}

function Test-TbgMapTradeCertTerminalState {
    param($Cert)

    $state = [string](Get-TbgObjectProperty $Cert 'state' '')
    return $state -in @('Complete', 'Blocked', 'Aborted', 'Failed')
}

function Test-TbgMapTradeCertPairCorrelation {
    param(
        $RouteCert,
        $TradeCert
    )

    if ($null -eq $RouteCert -or $null -eq $TradeCert) {
        return $false
    }

    $routeSource = [string](Get-TbgObjectProperty $RouteCert 'source' '')
    $tradeSource = [string](Get-TbgObjectProperty $TradeCert 'source' '')
    $routeStartedAt = [string](Get-TbgObjectProperty $RouteCert 'startedAtUtc' '')
    $tradeStartedAt = [string](Get-TbgObjectProperty $TradeCert 'startedAtUtc' '')
    if ([string]::IsNullOrWhiteSpace($routeSource) `
        -or -not [string]::Equals($routeSource, $tradeSource, [StringComparison]::Ordinal) `
        -or [string]::IsNullOrWhiteSpace($routeStartedAt) `
        -or -not [string]::Equals($routeStartedAt, $tradeStartedAt, [StringComparison]::Ordinal)) {
        return $false
    }

    $routeTargetId = [string](Get-TbgObjectProperty $RouteCert 'targetSettlementId' '')
    $tradeTargetId = [string](Get-TbgObjectProperty $TradeCert 'targetSettlementId' '')
    $routeDestination = [string](Get-TbgObjectProperty $RouteCert 'destinationSettlement' '')
    $tradeDestination = [string](Get-TbgObjectProperty $TradeCert 'destinationSettlement' '')
    $targetIdMatches = -not [string]::IsNullOrWhiteSpace($routeTargetId) `
        -and [string]::Equals($routeTargetId, $tradeTargetId, [StringComparison]::Ordinal)
    $destinationMatches = -not [string]::IsNullOrWhiteSpace($routeDestination) `
        -and [string]::Equals($routeDestination, $tradeDestination, [StringComparison]::Ordinal)

    return $targetIdMatches -or $destinationMatches
}

function Test-TbgSaveIdentityEvidence {
    param(
        $Identity,
        [Parameter(Mandatory = $true)]
        [string[]]$AllowedSaveIds,
        [Parameter(Mandatory = $true)]
        [string]$CommandId,
        [Parameter(Mandatory = $true)]
        [string]$RunId,
        [Parameter(Mandatory = $true)]
        [string]$CorrelationId,
        [Parameter(Mandatory = $true)]
        [int]$ProcessId,
        [Parameter(Mandatory = $true)]
        [datetime]$NotBeforeUtc
    )

    if ($null -eq $Identity `
        -or [string](Get-TbgObjectProperty $Identity 'schemaVersion' '') -ne 'TbgSaveIdentity.v2' `
        -or [string](Get-TbgObjectProperty $Identity 'source' '') -ne 'ReportSaveIdentityNow' `
        -or [string](Get-TbgObjectProperty $Identity 'commandId' '') -ne $CommandId `
        -or [string](Get-TbgObjectProperty $Identity 'runId' '') -ne $RunId `
        -or [string](Get-TbgObjectProperty $Identity 'correlationId' '') -ne $CorrelationId `
        -or [int](Get-TbgObjectProperty $Identity 'processId' 0) -ne $ProcessId `
        -or -not [bool](Get-TbgObjectProperty $Identity 'identityVerified' $false) `
        -or -not [bool](Get-TbgObjectProperty $Identity 'devSaveLoadUsed' $false) `
        -or -not [bool](Get-TbgObjectProperty $Identity 'explicitLoadObserved' $false) `
        -or -not [bool](Get-TbgObjectProperty $Identity 'campaignReady' $false)) {
        return $false
    }

    $loadedSaveId = [string](Get-TbgObjectProperty $Identity 'loadedSaveId' '')
    $activeSaveSlotName = [string](Get-TbgObjectProperty $Identity 'activeSaveSlotName' '')
    if ([string]::IsNullOrWhiteSpace($loadedSaveId) `
        -or -not [string]::Equals(
            $loadedSaveId,
            $activeSaveSlotName,
            [StringComparison]::OrdinalIgnoreCase)) {
        return $false
    }

    $allowed = @($AllowedSaveIds | Where-Object {
        [string]::Equals(
            $loadedSaveId,
            [string]$_,
            [StringComparison]::OrdinalIgnoreCase)
    })
    if ($allowed.Count -eq 0) {
        return $false
    }

    $observedAtRaw = [string](Get-TbgObjectProperty $Identity 'observedAtUtc' '')
    $dateStyles = [System.Globalization.DateTimeStyles]::AssumeUniversal `
        -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal
    [datetimeoffset]$observedAt = [datetimeoffset]::MinValue
    if (-not [datetimeoffset]::TryParse(
            $observedAtRaw,
            [System.Globalization.CultureInfo]::InvariantCulture,
            $dateStyles,
            [ref]$observedAt)) {
        return $false
    }

    return $observedAt.UtcDateTime -ge $NotBeforeUtc.ToUniversalTime()
}
