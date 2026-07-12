# Verifies dependency-CAUTION handling for both the legacy modal wrapper and the root fast frontdoor.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]

function Read-RepoText {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        $failures.Add("missing file: $RelativePath") | Out-Null
        return ''
    }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8
}

function Need {
    param([string]$Path, [string]$Needle, [string]$Why = '')
    $text = Read-RepoText $Path
    if ($text.IndexOf($Needle, [StringComparison]::Ordinal) -lt 0) {
        $suffix = if ($Why) { " ($Why)" } else { '' }
        $failures.Add("$Path missing '$Needle'$suffix") | Out-Null
    }
}

function Forbid {
    param([string]$Path, [string]$Needle, [string]$Why = '')
    $text = Read-RepoText $Path
    if ($text.IndexOf($Needle, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
        $suffix = if ($Why) { " ($Why)" } else { '' }
        $failures.Add("$Path contains forbidden '$Needle'$suffix") | Out-Null
    }
}

function NeedBefore {
    param([string]$Path, [string]$First, [string]$Second, [string]$Why = '')
    $text = Read-RepoText $Path
    $firstIndex = $text.IndexOf($First, [StringComparison]::Ordinal)
    $secondIndex = $text.IndexOf($Second, [StringComparison]::Ordinal)
    if ($firstIndex -lt 0 -or $secondIndex -lt 0 -or $firstIndex -ge $secondIndex) {
        $suffix = if ($Why) { " ($Why)" } else { '' }
        $failures.Add("$Path must place '$First' before '$Second'$suffix") | Out-Null
    }
}

$doc = 'docs\handoff\launcher-dependency-caution-handoff-doctrine.md'
$legacyWrapper = 'scripts\launcher-modal-aware-context-nav.ps1'
$legacyRecovery = 'scripts\launcher-recovery-policy.ps1'
$fastFrontdoor = 'scripts\launcher-fast-frontdoor.ps1'
$diagnostics = 'scripts\invoke-collect-diagnostics.ps1'
$workflow = '.tbg\workflows\continue-visible-trade-cycle.contract.json'
$continueCoordinator = 'scripts\run-forge-continue-campaign.ps1'
$visibleRunner = 'scripts\run-tbg-visible-trade-cycle.ps1'
$launchOperator = 'scripts\invoke-forge-launch-operator.ps1'

foreach ($needle in @(
    '# Launcher Dependency Caution Handoff Doctrine',
    'dependency_mismatch_caution_modal',
    'confirm_dependency_caution',
    'defaultAction=confirm',
    'The CAUTION dialog is an overlay on the existing launcher state.',
    'Closing the CAUTION dialog or choosing **Cancel** returns to the underlying PLAY / CONTINUE menu.',
    'confirm before retry',
    'never cancel dependency caution',
    'retry only when Confirm fails or Confirm does not produce a game handoff',
    'A force-close retry must never be scheduled merely because the CAUTION overlay is present.',
    'Confirming the caution dialog proves only this',
    'Silent fallback is not allowed.'
)) { Need $doc $needle 'dependency caution doctrine' }

foreach ($needle in @(
    'Get-TbgDependencyCautionCandidate',
    'Invoke-TbgDependencyCautionConfirm',
    'Wait-TbgModalGameHandoff',
    'dependency_caution_modal_detected',
    'CLICK_DEPENDENCY_CAUTION_RESULT result=confirm_dispatched',
    'defaultAction=confirm',
    'dependencyMismatchHandled=true',
    'runtimeProofClaim=false'
)) { Need $legacyWrapper $needle 'legacy wrapper must retain Confirm-first compatibility' }
Forbid $legacyWrapper 'defaultAction=cancel' 'dependency CAUTION must not default to Cancel'
NeedBefore $legacyWrapper 'Invoke-TbgDependencyCautionConfirm -Candidate $candidate -ExpectedPid $expectedPid' "Invoke-TbgRecoveryForFailure -FailureClass 'dependency_caution_confirm_failed'" 'Confirm must precede legacy recovery'

foreach ($needle in @(
    'TbgLauncherRecovery.v1',
    'BlacksmithGuild_LauncherRecovery.json',
    'Stop-TbgLauncherProcessFamilyForRetry',
    'MaxRecoveryRetries = 1',
    'LAUNCH_STATE=launcher_recovery_dead_end',
    'sameFailureAsPrevious',
    'runtimeProofClaim = $false'
)) { Need $legacyRecovery $needle 'legacy recovery remains bounded' }

foreach ($needle in @(
    'TbgLauncherFastFrontdoor.v1',
    'TotalBudgetSec = 30',
    'PhaseBudgetSec = 5',
    'MaxAttempts = 2',
    'SetProcessDPIAware',
    'LAUNCH_STATE=dependency_caution_modal_detected',
    'action=confirm',
    'cancelAction=forbidden',
    'launcher_menu_returned_after_confirm',
    'Stop-TbgLauncherFamily',
    'fast_retry_scheduled',
    'launcher_recovery_dead_end',
    'artifacts\latest\launcher-frontdoor',
    'launch-tail.log',
    'runtimeProofClaim = $false'
)) { Need $fastFrontdoor $needle 'root fast frontdoor contract' }
Forbid $fastFrontdoor 'defaultAction=cancel' 'fast root frontdoor must never choose Cancel'
Forbid $fastFrontdoor 'TimeoutSec = 60' 'root launcher phases are capped at five seconds'
NeedBefore $fastFrontdoor "Click-LauncherFraction -Window `$window -XFraction 0.55 -YFraction 0.88 -Label 'dependency_caution_confirm'" 'LAUNCH_STATE=fast_retry_scheduled' 'Confirm must precede force-close retry'
NeedBefore $fastFrontdoor 'Wait-GameUntil -Deadline $attemptDeadline' 'LAUNCH_STATE=fast_retry_scheduled' 'post-Confirm game handoff wait must precede retry'

foreach ($needle in @('launcher-fast-frontdoor.ps1', '-LaunchManual', '-TotalBudgetSec 30', '-PhaseBudgetSec 5', '-MaxAttempts 2')) {
    Need 'Forge.cmd' $needle 'Forge play root command must retain the direct fast state machine'
}
Forbid 'Forge.cmd' 'launcher-frozen-context-nav.ps1' 'root command must not bypass into frozen navigator'
Forbid 'Forge.cmd' 'launcher-modal-aware-context-nav.ps1' 'root command must not invoke the legacy wrapper directly'

Need 'ForgeContinue.cmd' 'run-forge-continue-campaign.ps1' 'Continue root command must delegate to the campaign coordinator'
Need $continueCoordinator 'run-tbg-visible-trade-cycle.ps1' 'campaign coordinator must retain the exact-save visible-trade certifier'
Need $visibleRunner 'invoke-forge-launch-operator.ps1' 'visible-trade certifier must delegate launcher ownership'
foreach ($needle in @('LaunchManual = $true', 'launcher-fast-frontdoor.ps1', '-TotalBudgetSec 30', '-PhaseBudgetSec 5', '-MaxAttempts 2')) {
    Need $launchOperator $needle 'Continue delegation must retain the fast state machine and bounded budgets'
}
Forbid $launchOperator 'launcher-frozen-context-nav.ps1' 'Continue operator must not bypass into frozen navigator'
Forbid $launchOperator 'launcher-modal-aware-context-nav.ps1' 'Continue operator must not invoke the legacy wrapper directly'

foreach ($needle in @(
    'BlacksmithGuild_LauncherRecovery.json',
    'BlacksmithGuild_Diagnostics',
    "Join-Path `$latestBundle.FullName 'status'",
    'Added launcher recovery evidence'
)) { Need $diagnostics $needle 'diagnostics must retain legacy recovery evidence' }

foreach ($needle in @(
    'dependencyMismatchCaution',
    'dependency_mismatch_caution_modal',
    'confirm',
    'dependencyMismatchHandled=true',
    'loadingHandoffIsNotRuntimeProof'
)) { Need $workflow $needle 'visible-trade workflow launcher policy' }

if ($failures.Count -gt 0) {
    Write-Host "FAIL: launcher dependency caution doctrine has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: dependency CAUTION is Confirm-first, Cancel-forbidden, five-second phased, one-retry bounded, and evidence-retaining.' -ForegroundColor Green
exit 0
