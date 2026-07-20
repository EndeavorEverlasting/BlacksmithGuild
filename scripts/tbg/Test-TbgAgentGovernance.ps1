[CmdletBinding()]
param(
    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
$RepoRoot = [IO.Path]::GetFullPath($RepoRoot)

$govPath = Join-Path $RepoRoot 'AGENTS.md'
$failures = New-Object System.Collections.ArrayList

Write-Host "--- TBG Agent Governance Validator ---" -ForegroundColor Cyan
Write-Host "Repo: $RepoRoot" -ForegroundColor Cyan
Write-Host "Governance: $govPath" -ForegroundColor Cyan
Write-Host ""

# Must exist
if (-not (Test-Path -LiteralPath $govPath -PathType Leaf)) {
    $failures.Add("Governance file missing: $govPath") | Out-Null
    Write-Host "BLOCKED" -ForegroundColor Red
    exit 1
}

$text = Get-Content -LiteralPath $govPath -Raw -Encoding UTF8
$lines = $text -split "`n"

# Must be compact (≤ 110 lines)
if ($lines.Count -gt 110) {
    $failures.Add("Governance file is $($lines.Count) lines; maximum is 110.") | Out-Null
}

# Required sections
$requiredSections = @(
    'Agent Operating Principles',
    'Instruction Precedence',
    'Sprint Declaration',
    'Completion Standard',
    'Forbidden Behaviors',
    'PowerShell Governance',
    'Standard Process Detection',
    'Entry Sequence',
    'Runtime Safety',
    'Proof Discipline',
    'Lane Router',
    'Current-State Pointers',
    'Completion Report'
)

foreach ($section in $requiredSections) {
    $pattern = [regex]::Escape($section)
    if ($text -notmatch "##\s+\d+\.\s+$pattern" -and $text -notmatch "##\s+$pattern") {
        $failures.Add("Missing required section: $section") | Out-Null
    }
}

# Required content patterns
$requiredPatterns = @{
    'pwsh authority'    = 'pwsh'
    'process detection' = 'Get-BannerlordProcessDetection'
    'proof ladder'      = 'contract -> harness -> static test -> build'
    'completion items'  = 'commit SHA'
    'forbidden: ack'    = 'Acknowledgment without mutation'
    'forbidden: reimpl' = 'Reimplementing existing utilities'
}

foreach ($key in $requiredPatterns.Keys) {
    if ($text -notmatch [regex]::Escape($requiredPatterns[$key])) {
        $failures.Add("Governance is missing required content: $key") | Out-Null
    }
}

# Report
if ($failures.Count -gt 0) {
    Write-Host "FAILURES:" -ForegroundColor Red
    foreach ($f in $failures) {
        Write-Host "  - $f" -ForegroundColor Red
    }
    Write-Host "Governance: FAIL ($($failures.Count) issues)" -ForegroundColor Red
    exit 1
}

Write-Host "All required sections present. All required content patterns matched." -ForegroundColor Green
Write-Host "Governance: PASS" -ForegroundColor Green
