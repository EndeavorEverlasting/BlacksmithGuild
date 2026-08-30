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
$pr32ValidatorPath = Join-Path $RepoRoot 'scripts/tbg/Test-TbgPr32GuardrailPreservation.ps1'
foreach ($requiredValidator in @($validatorPath, $pr32ValidatorPath)) {
    if (-not (Test-Path -LiteralPath $requiredValidator -PathType Leaf)) {
        throw "Required stale PR recovery validator is missing: $requiredValidator"
    }
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
& $pr32ValidatorPath -RepoRoot $RepoRoot -OutputRoot (Join-Path $OutputRoot 'pr32-guardrail-preservation')

$resultPath = Join-Path $OutputRoot 'validation-result.json'
[ordered]@{
    schema = 'tbg.e2e-stale-pr-recovery-progress-result.v1'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    status = 'PASS'
    proofLevel = 'static test'
    validators = @(
        'scripts/tbg/Test-TbgStalePrRecoveryProgress.ps1',
        'scripts/tbg/Test-TbgPr32GuardrailPreservation.ps1'
    )
    repository = 'EndeavorEverlasting/BlacksmithGuild'
    claims = @(
        'stale PR recovery ledger matches the canonical plan',
        'terminal dispositions remain evidence-backed',
        'tracked dashboard counts match the canonical ledger',
        'PR #32 guardrail intent maps to maintained current-main authorities without reviving stale parallel authority'
    )
    claimsNotMade = @(
        'runtime proof',
        'gameplay proof',
        'branch replay completion beyond recorded ledger state',
        'canonical PR #32 terminal disposition before the registered progress producer records it'
    )
} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resultPath -Encoding UTF8

Write-Host "PASS: stale PR recovery progress and PR #32 guardrail preservation are bound into the composed E2E interface. Result: $resultPath"
