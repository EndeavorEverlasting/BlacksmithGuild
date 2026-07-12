Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$contractPath = Join-Path $repoRoot '.tbg\workflows\pr-lifecycle-automation.contract.json'
$controllerPath = Join-Path $PSScriptRoot 'Invoke-TbgPrLifecycle.ps1'
$testPath = Join-Path $PSScriptRoot 'Test-TbgPrLifecycleAutomation.ps1'
$workflowPath = Join-Path $repoRoot '.github\workflows\pr-lifecycle-automation.yml'
$docPath = Join-Path $repoRoot 'docs\handoff\pr-lifecycle-automation.md'

function Assert-Condition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

try {
    foreach ($path in @($contractPath, $controllerPath, $testPath, $workflowPath, $docPath)) {
        Assert-Condition -Condition (Test-Path -LiteralPath $path) -Message ("Required lifecycle file is missing: $path")
    }

    $contract = Get-Content -LiteralPath $contractPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $controller = Get-Content -LiteralPath $controllerPath -Raw -Encoding UTF8
    $test = Get-Content -LiteralPath $testPath -Raw -Encoding UTF8
    $workflow = Get-Content -LiteralPath $workflowPath -Raw -Encoding UTF8
    $doc = Get-Content -LiteralPath $docPath -Raw -Encoding UTF8

    Assert-Condition -Condition ($contract.id -eq 'pr-lifecycle-automation') -Message 'Lifecycle contract id is incorrect.'
    Assert-Condition -Condition ($contract.schemaVersion -eq 'TbgWorkflowContract.v2') -Message 'Lifecycle contract schema was not raised for merge automation.'
    Assert-Condition -Condition (@($contract.requiredWorkflowNames).Count -ge 2) -Message 'Lifecycle contract must name always-required workflows.'
    Assert-Condition -Condition (@($contract.conditionalRequiredWorkflowNames).Count -ge 1) -Message 'Lifecycle contract must support conditional-required workflows.'
    foreach ($name in @('Governor Contracts', 'Harness Policy Reports')) {
        Assert-Condition -Condition (@($contract.requiredWorkflowNames) -contains $name) -Message ("Always-required workflow is missing from the contract: $name")
    }
    Assert-Condition -Condition (@($contract.conditionalRequiredWorkflowNames) -contains 'Hostile Escape Contracts') -Message 'Hostile Escape Contracts must remain conditional-required.'

    Assert-Condition -Condition ([bool]$contract.mergeControl.automaticMerge) -Message 'Automatic merge is not enabled in the executable contract.'
    Assert-Condition -Condition ([bool]$contract.mergeControl.exactHeadRequired) -Message 'Exact-head merge is not required.'
    Assert-Condition -Condition ($contract.mergeControl.method -eq 'squash') -Message 'Merge method must be squash.'
    foreach ($label in @('pr-lifecycle:hold-draft', 'pr-lifecycle:hold-merge', 'pr-lifecycle:auto-merge-legacy', 'pr-lifecycle:auto-merge-stacked', 'pr-lifecycle:auto-merge-fork')) {
        $policyText = (($contract | ConvertTo-Json -Depth 10) + ' ' + $workflow + ' ' + $doc)
        Assert-Condition -Condition ($policyText.Contains($label)) -Message ("Lifecycle-control label is missing: $label")
    }

    $advisoryText = (($contract.advisoryValidation | ConvertTo-Json -Depth 8) + ' ' + $doc).ToLowerInvariant()
    foreach ($term in @('installed-game', 'windows', 'linux', 'modular', 'advisory')) {
        Assert-Condition -Condition ($advisoryText.Contains($term)) -Message ("OS/game advisory doctrine is missing term: $term")
    }

    $forbiddenText = (@($contract.forbiddenActions) -join ' ').ToLowerInvariant()
    foreach ($term in @('close', 'delete a branch', 'force-push', 'different head', 'untrusted')) {
        Assert-Condition -Condition ($forbiddenText.Contains($term)) -Message ("Forbidden lifecycle action is not explicit: $term")
    }

    Assert-Condition -Condition ($controller -match "'pr',\s*'ready'") -Message 'Controller does not implement ready-for-review promotion.'
    Assert-Condition -Condition ($controller -match "'pr',\s*'merge'") -Message 'Controller does not implement automatic merge.'
    Assert-Condition -Condition ($controller -match "'--match-head-commit'") -Message 'Controller does not enforce exact-head merge.'
    Assert-Condition -Condition ($controller -match "'--auto'") -Message 'Controller does not ask GitHub to enforce auto-merge rules first.'
    Assert-Condition -Condition ($controller -match "'--squash'") -Message 'Controller does not enforce squash merge.'
    Assert-Condition -Condition ($controller -match 'reviewThreads') -Message 'Controller does not inspect review threads.'
    Assert-Condition -Condition ($controller -match 'conditionalRequiredWorkflowNames') -Message 'Controller does not classify conditional-required workflows.'
    Assert-Condition -Condition ($controller -match 'advisoryChecks') -Message 'Controller does not preserve advisory check reporting.'

    foreach ($forbiddenPattern in @(
        "'pr',\s*'close'",
        '(?im)\bgh\s+pr\s+close\b',
        '(?im)\bgit\s+push\b',
        '(?im)\bgit\s+commit\b',
        '(?im)\bgit\s+branch\s+-D\b',
        '(?im)\bgit\s+push\s+--force\b',
        '(?im)\bgh\s+pr\s+merge\b[^\r\n]*--admin\b'
    )) {
        Assert-Condition -Condition ($controller -notmatch $forbiddenPattern) -Message ("Controller contains a forbidden lifecycle command matching: $forbiddenPattern")
    }

    Assert-Condition -Condition ($workflow -match '(?m)^\s*pull-requests:\s*write\s*$') -Message 'Lifecycle workflow needs pull-request write permission.'
    Assert-Condition -Condition ($workflow -match '(?m)^\s*contents:\s*write\s*$') -Message 'Lifecycle workflow needs contents write permission for GitHub merge.'
    Assert-Condition -Condition ($workflow -match '(?m)^\s*issues:\s*write\s*$') -Message 'Lifecycle workflow needs issues write permission to bootstrap policy labels.'
    Assert-Condition -Condition ($workflow -match 'pull_request_target') -Message 'Lifecycle workflow must use the trusted default-branch pull_request_target path.'
    Assert-Condition -Condition ($workflow -match 'workflow_run') -Message 'Lifecycle workflow must react to repo-owned workflow completion.'
    Assert-Condition -Condition ($workflow -match 'pull_request_review') -Message 'Lifecycle workflow must react to review-state changes.'
    Assert-Condition -Condition ($workflow -match 'pull_request_review_thread') -Message 'Lifecycle workflow must react to review-thread resolution.'
    Assert-Condition -Condition ($workflow -match 'Invoke-TbgPrLifecycle.ps1') -Message 'Lifecycle workflow does not invoke the controller.'
    Assert-Condition -Condition ($workflow -match 'actions/upload-artifact@v4') -Message 'Lifecycle workflow does not publish its result artifact.'
    Assert-Condition -Condition ($workflow -match 'repository.default_branch') -Message 'Lifecycle workflow does not checkout the trusted default branch.'
    Assert-Condition -Condition ($workflow -notmatch '(?m)^\s*ref:\s*\$\{\{\s*github\.event\.pull_request\.head') -Message 'Lifecycle workflow must not checkout untrusted PR head code with a write token.'
    Assert-Condition -Condition ($workflow -match 'Ensure lifecycle control labels') -Message 'Lifecycle workflow does not bootstrap control labels.'
    Assert-Condition -Condition ($workflow -match '(?im)\bgh\s+label\s+create\b') -Message 'Lifecycle workflow does not create lifecycle labels through GitHub.'
    Assert-Condition -Condition ($workflow.Contains('--force')) -Message 'Lifecycle label bootstrap must be idempotent.'

    foreach ($caseName in @(
        'ready-exact-head-merge-eligible',
        'legacy-pr-blocked',
        'stacked-pr-blocked',
        'fork-pr-blocked',
        'conflicting-pr',
        'review-required',
        'unresolved-review-thread'
    )) {
        Assert-Condition -Condition ($test.Contains($caseName)) -Message ("Regression case is missing: $caseName")
    }
    Assert-Condition -Condition ($test -match 'Windows installed-game validation') -Message 'Regression does not cover Windows installed-game advisory validation.'
    Assert-Condition -Condition ($test -match 'Linux installed-game runtime proof') -Message 'Regression does not cover Linux installed-game advisory validation.'
    Assert-Condition -Condition ($doc -match 'pr-lifecycle:hold-merge') -Message 'Lifecycle documentation does not explain the merge hold label.'
    Assert-Condition -Condition ($doc -match 'exact-head') -Message 'Lifecycle documentation does not explain exact-head merge.'

    Write-Host 'PASS: lifecycle automation uses deterministic exact-head blockers, bootstraps its control labels, preserves cross-platform advisory validation, publishes evidence, and cannot close, force, rewrite, or delete.' -ForegroundColor Green
    exit 0
} catch {
    Write-Host ('FAIL: PR lifecycle automation verifier: {0}' -f $_.Exception.Message) -ForegroundColor Red
    exit 1
}
