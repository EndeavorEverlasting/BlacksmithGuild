# Operator documentation index contract helpers.
# Stub/contract layer only. Future docs verifier should use this to ensure the
# operator can find the project control surfaces without chat archaeology.

function Get-TbgRequiredOperatorDocs {
    return @(
        'docs/operator/local-iteration-time-budget.md',
        'docs/operator/local-iteration-gap-register.md',
        'docs/operator/remaining-product-gap-register.md',
        'docs/operator/reboot-iteration-doctrine.md',
        'docs/operator/harness-engine-wiring.md'
    )
}

function Get-TbgOperatorDocIndexPath {
    param([string]$RepoRoot = $null)
    if ([string]::IsNullOrWhiteSpace($RepoRoot)) { $RepoRoot = Split-Path -Parent $PSScriptRoot }
    return Join-Path $RepoRoot 'docs\operator\README.md'
}

function Test-TbgOperatorDocIndexCoverage {
    param(
        [string]$RepoRoot = $null,
        [string]$IndexPath = $null
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) { $RepoRoot = Split-Path -Parent $PSScriptRoot }
    if ([string]::IsNullOrWhiteSpace($IndexPath)) { $IndexPath = Get-TbgOperatorDocIndexPath -RepoRoot $RepoRoot }
    if (-not (Test-Path -LiteralPath $IndexPath)) { return $false }

    $raw = Get-Content -LiteralPath $IndexPath -Raw
    foreach ($doc in @(Get-TbgRequiredOperatorDocs)) {
        $relative = $doc -replace '^docs/operator/', ''
        if ($raw -notmatch [regex]::Escape($relative)) { return $false }
    }
    return $true
}

function Assert-TbgOperatorDocIndexCoverage {
    param(
        [string]$RepoRoot = $null,
        [string]$IndexPath = $null
    )

    if (-not (Test-TbgOperatorDocIndexCoverage -RepoRoot $RepoRoot -IndexPath $IndexPath)) {
        throw 'operator docs index missing required documentation links'
    }
    return $true
}

function New-TbgOperatorDocIndexMarkdown {
    param([string[]]$Docs = $(Get-TbgRequiredOperatorDocs))

    $lines = @('# Operator Documentation Index','', 'This index is the operator-facing map for local iteration, evidence, and product doctrine.', '')
    foreach ($doc in @($Docs)) {
        $name = Split-Path -Leaf $doc
        $lines += "- [$name]($name)"
    }
    return ($lines -join [Environment]::NewLine)
}

function Write-TbgOperatorDocIndex {
    param(
        [string]$RepoRoot = $null,
        [string]$Path = $null
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) { $RepoRoot = Split-Path -Parent $PSScriptRoot }
    if ([string]::IsNullOrWhiteSpace($Path)) { $Path = Get-TbgOperatorDocIndexPath -RepoRoot $RepoRoot }
    $markdown = New-TbgOperatorDocIndexMarkdown
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    Set-Content -LiteralPath $Path -Value $markdown -Encoding UTF8
    return $Path
}
