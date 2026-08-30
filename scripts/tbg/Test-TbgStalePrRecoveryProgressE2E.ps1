[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$OutputRoot = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}
$RepoRoot = [IO.Path]::GetFullPath($RepoRoot)

$validatorPath = Join-Path $RepoRoot 'scripts/tbg/Test-TbgStalePrRecoveryProgress.ps1'
if (-not (Test-Path -LiteralPath $validatorPath -PathType Leaf)) {
    throw "Canonical stale PR progress validator is missing: $validatorPath"
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $RepoRoot '.local/tbg-e2e-runs/stale-pr-recovery-progress'
}
elseif (-not [IO.Path]::IsPathRooted($OutputRoot)) {
    $OutputRoot = Join-Path $RepoRoot $OutputRoot
}
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

& $validatorPath

$resultPath = Join-Path $OutputRoot 'validation-result.json'
[ordered]@{
    schema = 'tbg.e2e-stale-pr-recovery-progress-result.v1'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    status = 'PASS'
    proofLevel = 'static test'
    validator = 'scripts/tbg/Test-TbgStalePrRecoveryProgress.ps1'
    repository = 'EndeavorEverlasting/BlacksmithGuild'
    claims = @(
        'stale PR recovery ledger matches the canonical plan',
        'terminal dispositions remain evidence-backed',
        'tracked dashboard counts match the canonical ledger'
    )
    claimsNotMade = @(
        'runtime proof',
        'gameplay proof',
        'branch replay completion beyond recorded ledger state'
    )
} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resultPath -Encoding UTF8

Write-Host "PASS: stale PR recovery progress is bound into the composed E2E interface. Result: $resultPath"
