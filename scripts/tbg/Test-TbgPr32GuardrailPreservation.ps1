[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$OutputRoot = 'artifacts/latest/pr32-guardrail-preservation'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}
$RepoRoot = [IO.Path]::GetFullPath($RepoRoot)
if (-not [IO.Path]::IsPathRooted($OutputRoot)) {
    $OutputRoot = Join-Path $RepoRoot $OutputRoot
}

$failures = [System.Collections.Generic.List[string]]::new()
$passes = 0
function Add-Check([bool]$Condition, [string]$Name, [string]$Message = 'required preservation evidence missing') {
    if ($Condition) {
        $script:passes++
        Write-Host "[PASS] $Name" -ForegroundColor Green
    }
    else {
        $script:failures.Add("${Name}: $Message") | Out-Null
        Write-Host "[FAIL] $Name - $Message" -ForegroundColor Red
    }
}
function RepoPath([string]$Relative) { Join-Path $RepoRoot ($Relative -replace '/', [IO.Path]::DirectorySeparatorChar) }
function ReadText([string]$Relative) {
    $path = RepoPath $Relative
    Add-Check (Test-Path -LiteralPath $path -PathType Leaf) "file/$Relative"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return '' }
    return Get-Content -LiteralPath $path -Raw
}
function ReadJson([string]$Relative) {
    $raw = ReadText $Relative
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    try { return $raw | ConvertFrom-Json -ErrorAction Stop }
    catch { $script:failures.Add("json/${Relative}: $($_.Exception.Message)") | Out-Null; return $null }
}
function RequireText([string]$Label, [string]$Text, [string]$Needle) {
    Add-Check ($Text.Contains($Needle)) $Label "missing '$Needle'"
}

$matrixPath = 'docs/handoff/pr32-guardrail-preservation-matrix-20260829.md'
$doctrinePath = 'docs/harness-doctrine.md'
$policyPath = '.tbg/harness/policies/harness-doctrine.policy.json'
$e2eContractPath = '.tbg/workflows/end-to-end-validation.contract.json'
$stateContractPath = '.tbg/workflows/state-envelope.contract.json'
$governorHandoffPath = 'docs/handoff/governor-activity-handoff-contract.md'
$continuityPath = '.tbg/workflows/launcher-to-campaign-event-continuity.contract.json'
$checkpointWorkflowPath = '.github/workflows/checkpoint-discipline.yml'
$bomValidatorPath = 'scripts/test-powershell-utf8-bom-contract.ps1'

$matrix = ReadText $matrixPath
$doctrine = ReadText $doctrinePath
$policy = ReadJson $policyPath
$e2e = ReadJson $e2eContractPath
$state = ReadJson $stateContractPath
$governor = ReadText $governorHandoffPath
[void](ReadJson $continuityPath)
[void](ReadText $checkpointWorkflowPath)
[void](ReadText $bomValidatorPath)

foreach ($needle in @(
    'PR #32 is a parts bin, not a merge candidate.',
    'default-guardrails.md` | **superseded**',
    'proof-claim-discipline.md` | **superseded**',
    'runtime-contamination-doctrine.md` | **superseded by stronger lifecycle contracts**',
    'campaign-action-evidence-schema.md` | **concept retained; proposed parallel artifact rejected**',
    'Do **not** revive `BlacksmithGuild_CampaignActionEvidence.json` as a second generic authority.',
    'PR #28, #29, #30, or #31',
    'Do not hand-edit `docs/handoff/stale-pr-cherry-pick-progress.md`'
)) {
    RequireText "matrix/$needle" $matrix $needle
}

RequireText 'doctrine/proof-ladder' $doctrine 'contract -> harness -> static test -> build -> launcher -> command ACK -> behavior observed -> live runtime'
RequireText 'doctrine/checkpoint-boundary' $doctrine 'a checkpoint, process presence, command ACK, launcher handoff, or a sanitized evidence capsule does not prove product behavior or live runtime completion'
RequireText 'doctrine/launcher-boundary' $doctrine 'Launcher handoff is not campaign readiness.'
RequireText 'doctrine/readiness-authority' $doctrine 'readiness cascade grants no gameplay authority'
RequireText 'doctrine/handoff-proof' $doctrine 'ACK alone is not completion.'

if ($policy) {
    Add-Check ([string]$policy.schema -eq 'tbg.harness-doctrine.policy.v1') 'policy/schema'
    Add-Check ([bool]$policy.launcherSelection.backgroundSafeByDefault) 'policy/background-safe'
    Add-Check ([bool]$policy.launcherSelection.mouseIndependentByDefault) 'policy/mouse-independent'
    Add-Check ([bool]$policy.launcherSelection.postActionTransitionVerificationRequired) 'policy/transition-verification'
    Add-Check ($policy.launcherToCampaignContinuity.readinessCascadeGrantsGameplayAuthority -eq $false) 'policy/readiness-no-gameplay-authority'
    Add-Check ([bool]$policy.campaignAssistOperatingModel.phaseAndPriorityChangesRequireCorrelatedHandoff) 'policy/correlated-handoff'
    Add-Check ([bool]$policy.campaignAssistOperatingModel.handoffAcknowledgementIsNotCompletion) 'policy/ack-not-completion'
}

if ($e2e) {
    $proofOrder = @($e2e.proofOrder | ForEach-Object { [string]$_ })
    Add-Check (($proofOrder -join '|') -eq 'contract|harness|static test|build|launcher|command ACK|behavior observed|live runtime') 'e2e/proof-order'
}

if ($state) {
    $families = @($state.objectFamilies | ForEach-Object { [string]$_ })
    foreach ($family in @('observation','evidence','claim','constraint','objective','work-item','capability')) {
        Add-Check ($families -contains $family) "state/family/$family"
    }
    $forbidden = @($state.forbiddenScope | ForEach-Object { [string]$_ }) -join "`n"
    Add-Check ($forbidden.Contains('claim launcher, behavior, or live runtime proof from envelope validation')) 'state/no-proof-inflation'
}

RequireText 'governor/local-checkpoint-boundary' $governor 'An engine may prove a local checkpoint.'
RequireText 'governor/governor-interpretation' $governor 'Only the governor may decide what that checkpoint means for the recursive campaign cycle.'
foreach ($needle in @('gold before/after','inventory before/after','stamina before/after','roster before/after','Any checkpoint produced final PASS')) {
    RequireText "governor/$needle" $governor $needle
}

$staleParallelPaths = @(
    'docs/handoff/default-guardrails.md',
    'docs/handoff/guardrail-map.manifest.json',
    'docs/handoff/proof-claim-discipline.md',
    'docs/handoff/runtime-contamination-doctrine.md',
    'docs/handoff/campaign-action-evidence-schema.md',
    'scripts/verify-default-guardrails-contract.ps1'
)
foreach ($relative in $staleParallelPaths) {
    Add-Check (-not (Test-Path -LiteralPath (RepoPath $relative))) "parallel-authority-absent/$relative" 'stale PR #32 surface must not be revived on current main'
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$status = if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL' }
$result = [ordered]@{
    schema = 'tbg.pr32-guardrail-preservation-result.v1'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    status = $status
    sourcePr = 32
    sourceHead = 'd004aead5b482005bf03e77e8b181a11680b6f46'
    preservationMatrix = $matrixPath
    passes = $passes
    failures = @($failures)
    proofLevel = 'static test'
    claimsNotMade = @('runtime proof','gameplay proof','canonical stale-PR terminal disposition')
}
$result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $OutputRoot 'validation-result.json') -Encoding UTF8

Write-Host "Result: $passes passed / $($failures.Count) failed"
if ($failures.Count -gt 0) { throw ($failures -join [Environment]::NewLine) }
Write-Host 'PASS: PR #32 guardrail intent is mapped to maintained current-main authorities without reviving parallel guardrail or evidence ownership.' -ForegroundColor Green
