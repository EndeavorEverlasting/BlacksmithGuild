# Save/profile safety contract helpers.
# Stub/contract layer only. Future live mutation runs should emit preflight save
# safety classifications before mutating gameplay.

function New-TbgSaveSafetyClassification {
    param(
        [string]$SaveName = $null,
        [ValidateSet('unknown','disposable','personal','cert','unsafe')]
        [string]$SaveClass = 'unknown',
        [bool]$MutatingActionsAllowed = $false,
        [bool]$BackupKnown = $false,
        [bool]$OperatorConfirmationRequired = $true,
        [string]$Reason = 'stub classification'
    )

    return [pscustomobject]@{
        schemaVersion = 1
        saveName = $SaveName
        saveClass = $SaveClass
        mutatingActionsAllowed = [bool]$MutatingActionsAllowed
        backupKnown = [bool]$BackupKnown
        operatorConfirmationRequired = [bool]$OperatorConfirmationRequired
        reason = $Reason
        classifiedUtc = (Get-Date).ToUniversalTime().ToString('o')
    }
}

function Test-TbgSaveSafetyAllowsMutation {
    param([object]$Classification)

    if (-not $Classification) { return $false }
    if ($Classification.mutatingActionsAllowed -ne $true) { return $false }
    if ([string]$Classification.saveClass -in @('unsafe','unknown')) { return $false }
    if ($Classification.operatorConfirmationRequired -eq $true -and [string]$Classification.saveClass -ne 'disposable') { return $false }
    return $true
}

function Assert-TbgSaveSafetyForMutation {
    param([object]$Classification)

    if (-not (Test-TbgSaveSafetyAllowsMutation -Classification $Classification)) {
        throw "save safety does not allow mutation: $($Classification | ConvertTo-Json -Compress -Depth 6)"
    }
    return $true
}

function Write-TbgSaveSafetyClassification {
    param(
        [object]$Classification,
        [string]$Path
    )

    if (-not $Classification) { throw 'save safety classification missing' }
    if ($Path) {
        $dir = Split-Path -Parent $Path
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        $Classification | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
    }
    return $Classification
}
