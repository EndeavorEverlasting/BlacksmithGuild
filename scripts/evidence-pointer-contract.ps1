# Latest evidence pointer contract helpers.
# Stub/contract layer only. These helpers create small JSON pointers so future
# agents can find the latest local evidence without asking the operator for logs.

function Get-TbgEvidencePointerPath {
    param(
        [ValidateSet('reboot','validation','live-cert')]
        [string]$Kind,
        [string]$RepoRoot = $null
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = Split-Path -Parent $PSScriptRoot
    }

    $fileName = switch ($Kind) {
        'reboot' { 'latest-reboot.json' }
        'validation' { 'latest-validation.json' }
        'live-cert' { 'latest-live-cert.json' }
    }

    return Join-Path (Join-Path $RepoRoot 'docs\evidence') $fileName
}

function Write-TbgLatestEvidencePointer {
    param(
        [ValidateSet('reboot','validation','live-cert')]
        [string]$Kind,
        [string]$EvidenceDir,
        [string]$SummaryPath = $null,
        [string]$Classification = 'unknown',
        [string]$LikelyOwner = 'unknown',
        [bool]$UserActionNeeded = $false,
        [string]$RepoRoot = $null
    )

    $path = Get-TbgEvidencePointerPath -Kind $Kind -RepoRoot $RepoRoot
    $dir = Split-Path -Parent $path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

    $payload = [ordered]@{
        schemaVersion = 1
        kind = $Kind
        classification = $Classification
        latestEvidenceDir = $EvidenceDir
        summaryPath = $SummaryPath
        likelyOwner = $LikelyOwner
        userActionNeeded = [bool]$UserActionNeeded
        updatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    }

    $payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $path -Encoding UTF8
    return [pscustomobject]@{ path = $path; pointer = [pscustomobject]$payload }
}

function Read-TbgLatestEvidencePointer {
    param(
        [ValidateSet('reboot','validation','live-cert')]
        [string]$Kind,
        [string]$RepoRoot = $null
    )

    $path = Get-TbgEvidencePointerPath -Kind $Kind -RepoRoot $RepoRoot
    if (-not (Test-Path -LiteralPath $path)) {
        return [pscustomobject]@{ path = $path; exists = $false; pointer = $null }
    }

    try {
        return [pscustomobject]@{ path = $path; exists = $true; pointer = (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json) }
    } catch {
        return [pscustomobject]@{ path = $path; exists = $true; pointer = $null; error = $_.Exception.Message }
    }
}

function Test-TbgLatestEvidencePointer {
    param(
        [ValidateSet('reboot','validation','live-cert')]
        [string]$Kind,
        [string]$RepoRoot = $null
    )

    $read = Read-TbgLatestEvidencePointer -Kind $Kind -RepoRoot $RepoRoot
    if (-not $read.exists -or -not $read.pointer) { return $false }
    $evidenceDir = [string]$read.pointer.latestEvidenceDir
    if ([string]::IsNullOrWhiteSpace($evidenceDir)) { return $false }
    return (Test-Path -LiteralPath $evidenceDir)
}
