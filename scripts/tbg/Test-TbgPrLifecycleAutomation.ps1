Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$controller = Join-Path $PSScriptRoot 'Invoke-TbgPrLifecycle.ps1'
$contract = Join-Path $repoRoot '.tbg\workflows\pr-lifecycle-automation.contract.json'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('tbg-pr-lifecycle-test-' + [Guid]::NewGuid().ToString('N'))

function Assert-Equal {
    param($Actual, $Expected, [string]$Message)
    if ($Actual -ne $Expected) {
        throw ('{0} Expected "{1}" but observed "{2}".' -f $Message, $Expected, $Actual)
    }
}

function New-Check {
    param([string]$Workflow, [string]$Name, [string]$Bucket)
    return [pscustomobject][ordered]@{
        workflow = $Workflow
        name = $Name
        bucket = $Bucket
        state = if ($Bucket -eq 'pass') { 'SUCCESS' } elseif ($Bucket -eq 'pending') { 'PENDING' } else { 'FAILURE' }
        description = ''
        link = ''
    }
}

function Invoke-Case {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [bool]$IsDraft = $false,
        [string[]]$Labels = @(),
        [Parameter(Mandatory = $true)][object[]]$Checks,
        [string]$BaseRefName = 'main',
        [string]$Mergeable = 'MERGEABLE',
        [string]$MergeStateStatus = 'CLEAN',
        [string]$ReviewDecision = '',
        [bool]$IsCrossRepository = $false,
        [string]$CreatedAt = '2026-07-13T00:00:00Z',
        [int]$UnresolvedReviewThreads = 0,
        [bool]$ReviewThreadsHaveNextPage = $false,
        [Parameter(Mandatory = $true)][string]$ExpectedAction
    )

    $caseRoot = Join-Path $tempRoot $Name
    New-Item -ItemType Directory -Force -Path $caseRoot | Out-Null
    $prPath = Join-Path $caseRoot 'pr.json'
    $checksPath = Join-Path $caseRoot 'checks.json'
    $threadsPath = Join-Path $caseRoot 'review-threads.json'
    $resultPath = Join-Path $caseRoot 'result.json'

    [ordered]@{
        number = 77
        state = 'OPEN'
        isDraft = $IsDraft
        headRefOid = '0123456789abcdef0123456789abcdef01234567'
        url = 'https://example.invalid/pr/77'
        labels = @($Labels | ForEach-Object { [ordered]@{ name = $_ } })
        baseRefName = $BaseRefName
        headRefName = 'feat/example'
        mergeable = $Mergeable
        mergeStateStatus = $MergeStateStatus
        reviewDecision = $ReviewDecision
        isCrossRepository = $IsCrossRepository
        createdAt = $CreatedAt
        mergedAt = $null
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $prPath -Encoding UTF8

    @($Checks) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $checksPath -Encoding UTF8

    $nodes = @()
    for ($index = 0; $index -lt $UnresolvedReviewThreads; $index++) {
        $nodes += [ordered]@{ isResolved = $false }
    }
    [ordered]@{
        nodes = $nodes
        pageInfo = [ordered]@{ hasNextPage = $ReviewThreadsHaveNextPage }
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $threadsPath -Encoding UTF8

    [void](& $controller `
        -PrNumber 77 `
        -Repository 'EndeavorEverlasting/BlacksmithGuild' `
        -ContractPath $contract `
        -PrJsonPath $prPath `
        -ChecksJsonPath $checksPath `
        -ReviewThreadsJsonPath $threadsPath `
        -OutputPath $resultPath `
        -DryRun)

    $result = Get-Content -LiteralPath $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Equal -Actual $result.action -Expected $ExpectedAction -Message ("Case $Name returned the wrong action.")
    Assert-Equal -Actual @($result.forbiddenActionsExecuted).Count -Expected 0 -Message ("Case $Name reported a forbidden action.")
    Assert-Equal -Actual ([bool]$result.mergeAttempt.attempted) -Expected $false -Message ("Case $Name attempted a live merge during dry-run.")
    return $result
}

try {
    if (-not (Test-Path -LiteralPath $controller)) { throw 'Lifecycle controller is missing.' }
    if (-not (Test-Path -LiteralPath $contract)) { throw 'Lifecycle contract is missing.' }
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

    $alwaysRequiredPasses = @(
        (New-Check -Workflow 'Governor Contracts' -Name 'Governor contract verifiers' -Bucket 'pass'),
        (New-Check -Workflow 'Harness Policy Reports' -Name 'Static harness policy report' -Bucket 'pass')
    )
    $conditionalPass = New-Check -Workflow 'Hostile Escape Contracts' -Name 'Pure hostile geometry contracts' -Bucket 'pass'

    $promoted = Invoke-Case -Name 'draft-promotion-with-advisory-platform-failures' -IsDraft $true -Checks @(
        $alwaysRequiredPasses +
        $conditionalPass +
        (New-Check -Workflow 'Platform Game Advisory' -Name 'Windows installed-game validation' -Bucket 'fail') +
        (New-Check -Workflow 'Platform Game Advisory' -Name 'Linux installed-game runtime proof' -Bucket 'pending')
    ) -ExpectedAction 'ready_promoted'
    Assert-Equal -Actual @($promoted.requiredChecks).Count -Expected 3 -Message 'Required and present conditional check count is wrong.'
    Assert-Equal -Actual @($promoted.advisoryChecks).Count -Expected 2 -Message 'Advisory platform check count is wrong.'
    Assert-Equal -Actual $promoted.advisoryNotSuccessfulCount -Expected 2 -Message 'Advisory failures should be reported without blocking.'

    $mergeEligible = Invoke-Case -Name 'ready-exact-head-merge-eligible' -Checks @(
        $alwaysRequiredPasses +
        (New-Check -Workflow 'Platform Game Advisory' -Name 'Windows installed-game validation' -Bucket 'fail')
    ) -ExpectedAction 'merge_eligible'
    Assert-Equal -Actual $mergeEligible.headSha -Expected '0123456789abcdef0123456789abcdef01234567' -Message 'Exact head was not preserved.'

    [void](Invoke-Case -Name 'conditional-workflow-absent' -Checks $alwaysRequiredPasses -ExpectedAction 'merge_eligible')

    [void](Invoke-Case -Name 'conditional-workflow-failure' -Checks @(
        $alwaysRequiredPasses +
        (New-Check -Workflow 'Hostile Escape Contracts' -Name 'Pure hostile geometry contracts' -Bucket 'fail')
    ) -ExpectedAction 'waiting_required_checks')

    [void](Invoke-Case -Name 'required-failure' -Checks @(
        (New-Check -Workflow 'Governor Contracts' -Name 'Governor contract verifiers' -Bucket 'fail'),
        (New-Check -Workflow 'Harness Policy Reports' -Name 'Static harness policy report' -Bucket 'pass')
    ) -ExpectedAction 'waiting_required_checks')

    [void](Invoke-Case -Name 'missing-always-required-workflow' -Checks @(
        (New-Check -Workflow 'Governor Contracts' -Name 'Governor contract verifiers' -Bucket 'pass')
    ) -ExpectedAction 'waiting_required_workflows')

    [void](Invoke-Case -Name 'explicit-draft-hold' -IsDraft $true -Labels @('pr-lifecycle:hold-draft') -Checks $alwaysRequiredPasses -ExpectedAction 'held_draft')
    [void](Invoke-Case -Name 'explicit-merge-hold' -Labels @('pr-lifecycle:hold-merge') -Checks $alwaysRequiredPasses -ExpectedAction 'held_merge')

    [void](Invoke-Case -Name 'legacy-pr-blocked' -CreatedAt '2026-07-01T00:00:00Z' -Checks $alwaysRequiredPasses -ExpectedAction 'blocked_legacy_pr')
    [void](Invoke-Case -Name 'legacy-pr-opted-in' -CreatedAt '2026-07-01T00:00:00Z' -Labels @('pr-lifecycle:auto-merge-legacy') -Checks $alwaysRequiredPasses -ExpectedAction 'merge_eligible')

    [void](Invoke-Case -Name 'stacked-pr-blocked' -BaseRefName 'feature-parent' -Checks $alwaysRequiredPasses -ExpectedAction 'blocked_non_default_base')
    [void](Invoke-Case -Name 'stacked-pr-opted-in' -BaseRefName 'feature-parent' -Labels @('pr-lifecycle:auto-merge-stacked') -Checks $alwaysRequiredPasses -ExpectedAction 'merge_eligible')

    [void](Invoke-Case -Name 'fork-pr-blocked' -IsCrossRepository $true -Checks $alwaysRequiredPasses -ExpectedAction 'blocked_cross_repository')
    [void](Invoke-Case -Name 'fork-pr-opted-in' -IsCrossRepository $true -Labels @('pr-lifecycle:auto-merge-fork') -Checks $alwaysRequiredPasses -ExpectedAction 'merge_eligible')

    [void](Invoke-Case -Name 'conflicting-pr' -Mergeable 'CONFLICTING' -Checks $alwaysRequiredPasses -ExpectedAction 'waiting_mergeable')
    [void](Invoke-Case -Name 'behind-pr' -MergeStateStatus 'BEHIND' -Checks $alwaysRequiredPasses -ExpectedAction 'waiting_merge_state')
    [void](Invoke-Case -Name 'review-required' -ReviewDecision 'REVIEW_REQUIRED' -Checks $alwaysRequiredPasses -ExpectedAction 'waiting_review')
    [void](Invoke-Case -Name 'changes-requested' -ReviewDecision 'CHANGES_REQUESTED' -Checks $alwaysRequiredPasses -ExpectedAction 'waiting_review')
    [void](Invoke-Case -Name 'unresolved-review-thread' -UnresolvedReviewThreads 1 -Checks $alwaysRequiredPasses -ExpectedAction 'waiting_review_threads')
    [void](Invoke-Case -Name 'review-thread-pagination-incomplete' -ReviewThreadsHaveNextPage $true -Checks $alwaysRequiredPasses -ExpectedAction 'waiting_review_threads')

    Write-Host 'PASS: PR lifecycle automation promotes drafts and permits exact-head merge only after deterministic check, base, age, fork, conflict, review, and thread blockers pass.' -ForegroundColor Green
    exit 0
} catch {
    Write-Host ('FAIL: PR lifecycle automation test: {0}' -f $_.Exception.Message) -ForegroundColor Red
    exit 1
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
