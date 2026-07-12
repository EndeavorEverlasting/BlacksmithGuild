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

function ConvertTo-TbgEvidenceUtc {
    param(
        $InputObject,
        [string]$PropertyName = 'observedAtUtc'
    )

    $value = [string](Get-TbgObjectProperty -InputObject $InputObject -Name $PropertyName -Default '')
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $null
    }

    $parsed = [datetime]::MinValue
    if (-not [datetime]::TryParse(
            $value,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::RoundtripKind,
            [ref]$parsed)) {
        return $null
    }

    return $parsed.ToUniversalTime()
}

function Get-TbgEngineModes {
    param($AuthorityEvidence)

    $result = [ordered]@{}
    $engines = Get-TbgObjectProperty -InputObject $AuthorityEvidence -Name 'engines'
    if ($null -eq $engines) {
        return $result
    }

    foreach ($property in @($engines.PSObject.Properties)) {
        $mode = Get-TbgObjectProperty -InputObject $property.Value -Name 'mode'
        if ($null -ne $mode) {
            $result[$property.Name] = [string]$mode
        }
    }

    return $result
}

function Test-TbgSameNonMapTradeModes {
    param(
        $Baseline,
        $Candidate
    )

    $baselineModes = Get-TbgEngineModes -AuthorityEvidence $Baseline
    $candidateModes = Get-TbgEngineModes -AuthorityEvidence $Candidate
    $baselineNames = @($baselineModes.Keys | Where-Object { $_ -ne 'MapTrade' } | Sort-Object)
    $candidateNames = @($candidateModes.Keys | Where-Object { $_ -ne 'MapTrade' } | Sort-Object)
    if (($baselineNames -join '|') -ne ($candidateNames -join '|')) {
        return $false
    }

    foreach ($name in $baselineNames) {
        if (-not [string]::Equals(
                [string]$baselineModes[$name],
                [string]$candidateModes[$name],
                [System.StringComparison]::Ordinal)) {
            return $false
        }
    }

    return $true
}

function Test-TbgVisibleTradeCycleEvidence {
    param(
        [Parameter(Mandatory = $true)]$Request,
        $SaveIdentity,
        $AuthorityBefore,
        $AuthorityAutomation,
        $RuntimeEvidence,
        $AuthorityManual,
        [string]$ExpectedAssemblySha256
    )

    $runId = [string](Get-TbgObjectProperty -InputObject $Request -Name 'runId' -Default '')
    $headSha = [string](Get-TbgObjectProperty -InputObject $Request -Name 'headSha' -Default '')
    $requestedSaveId = [string](Get-TbgObjectProperty -InputObject $Request -Name 'requestedSaveId' -Default '')
    $requestUtc = ConvertTo-TbgEvidenceUtc -InputObject $Request -PropertyName 'createdAtUtc'
    if ([string]::IsNullOrWhiteSpace($ExpectedAssemblySha256)) {
        $ExpectedAssemblySha256 = [string](Get-TbgObjectProperty -InputObject $Request -Name 'expectedAssemblySha256' -Default '')
    }

    $checks = [ordered]@{}
    $checks.requestCorrelated = -not [string]::IsNullOrWhiteSpace($runId) `
        -and -not [string]::IsNullOrWhiteSpace($headSha) `
        -and -not [string]::IsNullOrWhiteSpace($requestedSaveId) `
        -and $null -ne $requestUtc

    $saveUtc = ConvertTo-TbgEvidenceUtc -InputObject $SaveIdentity
    $checks.saveEvidenceFresh = $null -ne $saveUtc -and $null -ne $requestUtc -and $saveUtc -ge $requestUtc
    $checks.saveRunMatches = [string](Get-TbgObjectProperty -InputObject $SaveIdentity -Name 'runId' -Default '') -eq $runId
    $checks.saveHeadMatches = [string](Get-TbgObjectProperty -InputObject $SaveIdentity -Name 'headSha' -Default '') -eq $headSha
    $checks.requestedSaveMatches = [string](Get-TbgObjectProperty -InputObject $SaveIdentity -Name 'requestedSaveId' -Default '') -eq $requestedSaveId
    $checks.loadedSaveMatches = [string](Get-TbgObjectProperty -InputObject $SaveIdentity -Name 'loadedSaveId' -Default '') -eq $requestedSaveId
    $checks.activeSaveSlotMatches = [string](Get-TbgObjectProperty -InputObject $SaveIdentity -Name 'activeSaveSlotName' -Default '') -eq $requestedSaveId
    $checks.saveIdentityVerified = (Get-TbgObjectProperty -InputObject $SaveIdentity -Name 'identityVerified' -Default $false) -eq $true
    $runtimeSessionId = [string](Get-TbgObjectProperty -InputObject $SaveIdentity -Name 'runtimeSessionId' -Default '')
    $checks.saveRuntimeSessionPresent = -not [string]::IsNullOrWhiteSpace($runtimeSessionId)
    $checks.loadedAssemblyMatches = -not [string]::IsNullOrWhiteSpace($ExpectedAssemblySha256) `
        -and [string]::Equals(
            [string](Get-TbgObjectProperty -InputObject $SaveIdentity -Name 'loadedAssemblySha256' -Default ''),
            $ExpectedAssemblySha256,
            [System.StringComparison]::OrdinalIgnoreCase)

    $beforeModes = Get-TbgEngineModes -AuthorityEvidence $AuthorityBefore
    $automationModes = Get-TbgEngineModes -AuthorityEvidence $AuthorityAutomation
    $manualModes = Get-TbgEngineModes -AuthorityEvidence $AuthorityManual
    $authorityBeforeUtc = ConvertTo-TbgEvidenceUtc -InputObject $AuthorityBefore -PropertyName 'updatedAtUtc'
    $authorityAutomationUtc = ConvertTo-TbgEvidenceUtc -InputObject $AuthorityAutomation -PropertyName 'updatedAtUtc'
    $authorityManualUtc = ConvertTo-TbgEvidenceUtc -InputObject $AuthorityManual -PropertyName 'updatedAtUtc'

    $checks.authorityBaselineFresh = $null -ne $authorityBeforeUtc -and $null -ne $saveUtc -and $authorityBeforeUtc -ge $saveUtc
    $checks.authorityBaselineCorrelated = [string](Get-TbgObjectProperty -InputObject $AuthorityBefore -Name 'runId' -Default '') -eq $runId `
        -and [string](Get-TbgObjectProperty -InputObject $AuthorityBefore -Name 'headSha' -Default '') -eq $headSha `
        -and [string](Get-TbgObjectProperty -InputObject $AuthorityBefore -Name 'runtimeSessionId' -Default '') -eq $runtimeSessionId `
        -and $beforeModes.Contains('MapTrade')
    $checks.mapTradeAutomationFresh = $null -ne $authorityAutomationUtc `
        -and $null -ne $authorityBeforeUtc `
        -and $authorityAutomationUtc -ge $authorityBeforeUtc
    $checks.mapTradeAutomationCorrelated = [string](Get-TbgObjectProperty -InputObject $AuthorityAutomation -Name 'runId' -Default '') -eq $runId `
        -and [string](Get-TbgObjectProperty -InputObject $AuthorityAutomation -Name 'headSha' -Default '') -eq $headSha `
        -and [string](Get-TbgObjectProperty -InputObject $AuthorityAutomation -Name 'runtimeSessionId' -Default '') -eq $runtimeSessionId `
        -and [string](Get-TbgObjectProperty -InputObject $AuthorityAutomation -Name 'source' -Default '') -eq 'SetMapTradeAutomation'
    $checks.mapTradeOnlyAutomation = $automationModes.Contains('MapTrade') `
        -and [string]$automationModes['MapTrade'] -eq 'Automation' `
        -and (Test-TbgSameNonMapTradeModes -Baseline $AuthorityBefore -Candidate $AuthorityAutomation)

    $runtimeUtc = ConvertTo-TbgEvidenceUtc -InputObject $RuntimeEvidence -PropertyName 'generatedAtUtc'
    $route = Get-TbgObjectProperty -InputObject $RuntimeEvidence -Name 'route'
    $trade = Get-TbgObjectProperty -InputObject $RuntimeEvidence -Name 'tradeExecution'
    $surface = Get-TbgObjectProperty -InputObject $RuntimeEvidence -Name 'tradeSurface'
    $checks.runtimeFresh = $null -ne $runtimeUtc -and $null -ne $authorityAutomationUtc -and $runtimeUtc -ge $authorityAutomationUtc
    $checks.runtimeCorrelated = [string](Get-TbgObjectProperty -InputObject $RuntimeEvidence -Name 'runId' -Default '') -eq $runId `
        -and [string](Get-TbgObjectProperty -InputObject $RuntimeEvidence -Name 'headSha' -Default '') -eq $headSha `
        -and [string](Get-TbgObjectProperty -InputObject $RuntimeEvidence -Name 'runtimeSessionId' -Default '') -eq $runtimeSessionId `
        -and [string]::Equals(
            [string](Get-TbgObjectProperty -InputObject $RuntimeEvidence -Name 'loadedAssemblySha256' -Default ''),
            $ExpectedAssemblySha256,
            [System.StringComparison]::OrdinalIgnoreCase)
    $checks.runtimeTerminal = (Get-TbgObjectProperty -InputObject $RuntimeEvidence -Name 'terminal' -Default $false) -eq $true `
        -and [string](Get-TbgObjectProperty -InputObject $RuntimeEvidence -Name 'state' -Default '') -eq 'Complete' `
        -and (Get-TbgObjectProperty -InputObject $RuntimeEvidence -Name 'pass' -Default $false) -eq $true

    $target = [string](Get-TbgObjectProperty -InputObject $route -Name 'targetSettlement' -Default '')
    $arrived = [string](Get-TbgObjectProperty -InputObject $route -Name 'arrivedSettlement' -Default '')
    $checks.routeStarted = (Get-TbgObjectProperty -InputObject $route -Name 'started' -Default $false) -eq $true
    $checks.movementObserved = (Get-TbgObjectProperty -InputObject $route -Name 'movementObserved' -Default $false) -eq $true `
        -and [double](Get-TbgObjectProperty -InputObject $route -Name 'partyMovedDistance' -Default 0) -gt 0
    $checks.arrivalObserved = (Get-TbgObjectProperty -InputObject $route -Name 'arrivalObserved' -Default $false) -eq $true `
        -and -not [string]::IsNullOrWhiteSpace($target) `
        -and [string]::Equals($target, $arrived, [System.StringComparison]::Ordinal)

    $hasTradeFields = $null -ne $trade `
        -and (Test-TbgObjectProperty -InputObject $trade -Name 'goldBefore') `
        -and (Test-TbgObjectProperty -InputObject $trade -Name 'goldAfter') `
        -and (Test-TbgObjectProperty -InputObject $trade -Name 'goldDelta') `
        -and (Test-TbgObjectProperty -InputObject $trade -Name 'inventoryBefore') `
        -and (Test-TbgObjectProperty -InputObject $trade -Name 'inventoryAfter') `
        -and (Test-TbgObjectProperty -InputObject $trade -Name 'inventoryDelta')
    $goldBefore = [int](Get-TbgObjectProperty -InputObject $trade -Name 'goldBefore' -Default 0)
    $goldAfter = [int](Get-TbgObjectProperty -InputObject $trade -Name 'goldAfter' -Default 0)
    $goldDelta = [int](Get-TbgObjectProperty -InputObject $trade -Name 'goldDelta' -Default 0)
    $inventoryBefore = [int](Get-TbgObjectProperty -InputObject $trade -Name 'inventoryBefore' -Default 0)
    $inventoryAfter = [int](Get-TbgObjectProperty -InputObject $trade -Name 'inventoryAfter' -Default 0)
    $inventoryDelta = [int](Get-TbgObjectProperty -InputObject $trade -Name 'inventoryDelta' -Default 0)
    $checks.tradeDeltaArithmetic = $hasTradeFields `
        -and ($goldAfter - $goldBefore) -eq $goldDelta `
        -and ($inventoryAfter - $inventoryBefore) -eq $inventoryDelta
    $checks.realBuyDelta = $hasTradeFields `
        -and (Get-TbgObjectProperty -InputObject $trade -Name 'fakeGameplayDelta' -Default $true) -eq $false `
        -and (Get-TbgObjectProperty -InputObject $trade -Name 'mutationApplied' -Default $false) -eq $true `
        -and $goldDelta -lt 0 `
        -and $inventoryDelta -gt 0 `
        -and [int](Get-TbgObjectProperty -InputObject $trade -Name 'quantityBought' -Default 0) -gt 0 `
        -and -not [string]::IsNullOrWhiteSpace([string](Get-TbgObjectProperty -InputObject $trade -Name 'itemId' -Default ''))

    $surfaceName = [string](Get-TbgObjectProperty -InputObject $surface -Name 'surface' -Default '')
    $activeState = [string](Get-TbgObjectProperty -InputObject $surface -Name 'activeState' -Default '')
    $surfaceUtc = ConvertTo-TbgEvidenceUtc -InputObject $surface -PropertyName 'openedAtUtc'
    $surfaceKindValid = $surfaceName -in @('Inventory', 'Trade') `
        -or ([string]::Equals($surfaceName, 'trading', [System.StringComparison]::OrdinalIgnoreCase) `
            -and $activeState.IndexOf('Inventory', [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
    $checks.tradeSurfaceVisible = (Get-TbgObjectProperty -InputObject $surface -Name 'visible' -Default $false) -eq $true `
        -and $surfaceKindValid `
        -and $null -ne $surfaceUtc `
        -and $null -ne $requestUtc `
        -and $surfaceUtc -ge $requestUtc `
        -and [string](Get-TbgObjectProperty -InputObject $surface -Name 'settlement' -Default '') -eq $arrived

    $checks.manualCleanupFresh = $null -ne $authorityManualUtc `
        -and $null -ne $runtimeUtc `
        -and $authorityManualUtc -ge $runtimeUtc
    $checks.manualCleanupCorrelated = [string](Get-TbgObjectProperty -InputObject $AuthorityManual -Name 'runId' -Default '') -eq $runId `
        -and [string](Get-TbgObjectProperty -InputObject $AuthorityManual -Name 'headSha' -Default '') -eq $headSha `
        -and [string](Get-TbgObjectProperty -InputObject $AuthorityManual -Name 'runtimeSessionId' -Default '') -eq $runtimeSessionId `
        -and [string](Get-TbgObjectProperty -InputObject $AuthorityManual -Name 'source' -Default '') -eq 'SetMapTradeManual'
    $checks.manualCleanupProven = $manualModes.Contains('MapTrade') `
        -and [string]$manualModes['MapTrade'] -eq 'Manual' `
        -and (Test-TbgSameNonMapTradeModes -Baseline $AuthorityBefore -Candidate $AuthorityManual)

    $failureMap = [ordered]@{
        requestCorrelated = 'FAILED_preflight'
        saveEvidenceFresh = 'BLOCKED_save_identity'
        saveRunMatches = 'BLOCKED_save_identity'
        saveHeadMatches = 'BLOCKED_save_identity'
        requestedSaveMatches = 'BLOCKED_save_identity'
        loadedSaveMatches = 'BLOCKED_save_identity'
        activeSaveSlotMatches = 'BLOCKED_save_identity'
        saveIdentityVerified = 'BLOCKED_save_identity'
        saveRuntimeSessionPresent = 'BLOCKED_save_identity'
        loadedAssemblyMatches = 'BLOCKED_save_identity'
        authorityBaselineFresh = 'BLOCKED_engine_authority'
        authorityBaselineCorrelated = 'BLOCKED_engine_authority'
        mapTradeAutomationFresh = 'BLOCKED_engine_authority'
        mapTradeAutomationCorrelated = 'BLOCKED_engine_authority'
        mapTradeOnlyAutomation = 'BLOCKED_engine_authority'
        runtimeFresh = 'FAILED_runtime'
        runtimeCorrelated = 'FAILED_runtime'
        runtimeTerminal = 'FAILED_runtime'
        routeStarted = 'BLOCKED_route_start'
        movementObserved = 'BLOCKED_movement'
        arrivalObserved = 'BLOCKED_arrival'
        tradeDeltaArithmetic = 'BLOCKED_trade_delta'
        realBuyDelta = 'BLOCKED_trade_delta'
        tradeSurfaceVisible = 'BLOCKED_trade_visibility'
        manualCleanupFresh = 'BLOCKED_manual_cleanup'
        manualCleanupCorrelated = 'BLOCKED_manual_cleanup'
        manualCleanupProven = 'BLOCKED_manual_cleanup'
    }

    $failures = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
    $terminalState = if ($failures.Count -eq 0) {
        'PASS_visible_trade_cycle'
    } else {
        [string]$failureMap[$failures[0]]
    }

    return [PSCustomObject]@{
        pass = $failures.Count -eq 0
        terminalState = $terminalState
        checks = $checks
        failures = $failures
    }
}
