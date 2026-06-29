# Smoke test for local iteration/product doctrine contract stubs.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'time-budget-contract.ps1')
. (Join-Path $PSScriptRoot 'evidence-pointer-contract.ps1')
. (Join-Path $PSScriptRoot 'gap-coverage-contract.ps1')
. (Join-Path $PSScriptRoot 'product-gap-contract.ps1')
. (Join-Path $PSScriptRoot 'doctrine-contract.ps1')

$requiredFunctions = @(
    'Get-TbgTimeBudget',
    'Test-TbgLongWaitAllowed',
    'Assert-TbgNormalTimeout',
    'Write-TbgTimeBudgetViolation',
    'Invoke-TbgTimedStep',
    'Get-TbgEvidencePointerPath',
    'Write-TbgLatestEvidencePointer',
    'Read-TbgLatestEvidencePointer',
    'Test-TbgLatestEvidencePointer',
    'Get-TbgLocalIterationGapCatalog',
    'New-TbgGapCoverageMatrix',
    'Assert-TbgGapCoverageMatrix',
    'ConvertTo-TbgGapCoverageMarkdown',
    'Write-TbgGapCoverageReport',
    'Get-TbgRemainingProductGapCatalog',
    'New-TbgProductGapImpactNotes',
    'Assert-TbgProductGapImpactNotes',
    'ConvertTo-TbgProductGapImpactMarkdown',
    'Write-TbgProductGapImpactReport',
    'Get-TbgDoctrineContractCatalog',
    'New-TbgDoctrineContractMatrix',
    'Assert-TbgDoctrineContractMatrix',
    'Write-TbgDoctrineContractReport'
)

foreach ($fn in $requiredFunctions) {
    if (-not (Get-Command $fn -ErrorAction SilentlyContinue)) {
        throw "missing contract stub function: $fn"
    }
}

$normal = Get-TbgTimeBudget -ActionClass normal -RequestedTimeoutSec 30
if ($normal.longWaitException -or $normal.timeBudgetSec -ne 30) { throw 'normal budget contract failed' }

$travel = Get-TbgTimeBudget -ActionClass travel_between_settlements -RequestedTimeoutSec 180
if (-not $travel.longWaitException -or $travel.timeBudgetSec -ne 180) { throw 'travel long-wait budget contract failed' }

try {
    Assert-TbgNormalTimeout -TimeoutSec 600 -ActionClass normal -Context 'smoke-test' | Out-Null
    throw 'normal 600s timeout should have failed'
} catch {
    if ($_.Exception.Message -notmatch 'time budget violation') { throw }
}

$gapMatrix = New-TbgGapCoverageMatrix
Assert-TbgGapCoverageMatrix -Matrix $gapMatrix | Out-Null

$productNotes = New-TbgProductGapImpactNotes
Assert-TbgProductGapImpactNotes -Notes $productNotes | Out-Null

$doctrineMatrix = New-TbgDoctrineContractMatrix
Assert-TbgDoctrineContractMatrix -Matrix $doctrineMatrix | Out-Null

Write-Host 'PASS local iteration contract stub smoke test'
exit 0
