# Smoke test for local iteration/product doctrine contract stubs.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'time-budget-contract.ps1')
. (Join-Path $PSScriptRoot 'evidence-pointer-contract.ps1')
. (Join-Path $PSScriptRoot 'gap-coverage-contract.ps1')
. (Join-Path $PSScriptRoot 'product-gap-contract.ps1')
. (Join-Path $PSScriptRoot 'doctrine-contract.ps1')
. (Join-Path $PSScriptRoot 'command-surface-contract.ps1')
. (Join-Path $PSScriptRoot 'mutation-proof-contract.ps1')
. (Join-Path $PSScriptRoot 'save-safety-contract.ps1')
. (Join-Path $PSScriptRoot 'route-risk-contract.ps1')
. (Join-Path $PSScriptRoot 'operator-doc-index-contract.ps1')
. (Join-Path $PSScriptRoot 'guild-loop-report-contract.ps1')
. (Join-Path $PSScriptRoot 'smithing-batch-contract.ps1')
. (Join-Path $PSScriptRoot 'trading-batch-contract.ps1')
. (Join-Path $PSScriptRoot 'character-build-contract.ps1')
. (Join-Path $PSScriptRoot 'companion-stamina-contract.ps1')

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
    'Write-TbgDoctrineContractReport',
    'Get-TbgCommandSurfaceCatalog',
    'Test-TbgCommandSurfaceEntry',
    'Assert-TbgCommandSurfaceGovernance',
    'ConvertTo-TbgCommandSurfaceMarkdown',
    'Write-TbgCommandSurfaceReport',
    'New-TbgMutationProofRecord',
    'Test-TbgMutationProofComplete',
    'Assert-TbgMutationProofNotFake',
    'Write-TbgMutationProofReport',
    'New-TbgSaveSafetyClassification',
    'Test-TbgSaveSafetyAllowsMutation',
    'Assert-TbgSaveSafetyForMutation',
    'Write-TbgSaveSafetyClassification',
    'New-TbgRouteRiskAssessment',
    'Test-TbgRouteRiskAllowsTravel',
    'Assert-TbgRouteRiskBeforeTravel',
    'Write-TbgRouteRiskAssessment',
    'Get-TbgRequiredOperatorDocs',
    'Get-TbgOperatorDocIndexPath',
    'Test-TbgOperatorDocIndexCoverage',
    'Assert-TbgOperatorDocIndexCoverage',
    'New-TbgOperatorDocIndexMarkdown',
    'Write-TbgOperatorDocIndex',
    'New-TbgGuildLoopReport',
    'Test-TbgGuildLoopReportComplete',
    'Assert-TbgGuildLoopReportComplete',
    'Write-TbgGuildLoopReport',
    'New-TbgSmithingBatchPlan',
    'New-TbgSmithingBatchResult',
    'Test-TbgSmithingBatchResultProven',
    'Assert-TbgSmithingBatchResultProven',
    'New-TbgTradingBatchPlan',
    'New-TbgTradingBatchResult',
    'Test-TbgTradingBatchResultProvenOrBlocked',
    'Assert-TbgTradingBatchResultProvenOrBlocked',
    'Get-TbgCharacterBuildPresetCatalog',
    'Get-TbgCharacterBuildPreset',
    'New-TbgCharacterBuildDecisionEvidence',
    'Test-TbgCharacterBuildMatchesPreset',
    'Assert-TbgCharacterBuildMatchesPreset',
    'New-TbgCompanionStaminaEntry',
    'New-TbgCompanionStaminaAudit',
    'Test-TbgCompanionStaminaAuditExplainsAvailability',
    'Assert-TbgCompanionStaminaAuditExplainsAvailability'
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

Assert-TbgCommandSurfaceGovernance -Catalog (Get-TbgCommandSurfaceCatalog) | Out-Null

$mutation = New-TbgMutationProofRecord -ActionName 'smoke' -MutationType 'inventory' `
    -ActionRequested:$true -ActionAccepted:$true -BeforeState @{ count = 1 } -AfterState @{ count = 2 } `
    -Delta @{ count = 1 } -FakeGameplayDelta:$false
Assert-TbgMutationProofNotFake -Record $mutation | Out-Null

$save = New-TbgSaveSafetyClassification -SaveName 'DisposableSmoke' -SaveClass disposable `
    -MutatingActionsAllowed:$true -OperatorConfirmationRequired:$false -Reason 'smoke test disposable save'
Assert-TbgSaveSafetyForMutation -Classification $save | Out-Null

$route = New-TbgRouteRiskAssessment -Destination 'Onira' -RiskLevel low -Reason 'smoke test'
Assert-TbgRouteRiskBeforeTravel -Assessment $route | Out-Null

$guildReport = New-TbgGuildLoopReport -Location 'Onira' -NextAction 'smoke' -SourceArtifacts @('artifact.json')
Assert-TbgGuildLoopReportComplete -Report $guildReport | Out-Null

$smithPlan = New-TbgSmithingBatchPlan -ActionType 'refine' -StaminaBefore @{ main = 100 } -MaterialReservesBefore @{ hardwood = 2 }
$smithResult = New-TbgSmithingBatchResult -Plan $smithPlan -StaminaAfter @{ main = 94 } -MaterialReservesAfter @{ charcoal = 1 } -Delta @{ stamina = -6 } -FakeGameplayDelta:$false
Assert-TbgSmithingBatchResultProven -Result $smithResult | Out-Null

$tradePlan = New-TbgTradingBatchPlan -Town 'Onira' -ItemName 'Hardwood' -TradeAction buy -InventoryBefore @{ hardwood = 0 } -GoldBefore @{ denars = 1000 }
$tradeResult = New-TbgTradingBatchResult -Plan $tradePlan -InventoryAfter @{ hardwood = 1 } -GoldAfter @{ denars = 974 } -Delta @{ hardwood = 1; denars = -26 } -FakeGameplayDelta:$false
Assert-TbgTradingBatchResultProvenOrBlocked -Result $tradeResult | Out-Null

$buildEvidence = New-TbgCharacterBuildDecisionEvidence -CultureId 'aserai' -Decisions @(@{ step = 'culture'; value = 'aserai' })
Assert-TbgCharacterBuildMatchesPreset -Evidence $buildEvidence | Out-Null

$companionAudit = New-TbgCompanionStaminaAudit -MainHero (New-TbgCompanionStaminaEntry -HeroName 'Main' -InParty:$true -EligibleForSmithing:$true -VisibleInSmithy:$true -Stamina 100) `
    -Companions @((New-TbgCompanionStaminaEntry -HeroName 'Companion' -InParty:$true -EligibleForSmithing:$false -VisibleInSmithy:$false -BlockedReason 'not visible in smithy'))
Assert-TbgCompanionStaminaAuditExplainsAvailability -Audit $companionAudit | Out-Null

Write-Host 'PASS local iteration contract stub smoke test'
exit 0
