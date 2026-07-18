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
