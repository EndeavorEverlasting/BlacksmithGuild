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
    foreach ($name in @('Governor Contracts', 'Harness Policy Reports')) {
        Assert-Condition -Condition (@($contract.requiredWorkflowNames) -contains $name) -Message ("Always-required workflow is missing from the contract: $name")
    }
    Assert-Condition -Condition (@($contract.conditionalRequiredWorkflowNames) -contains 'Hostile Escape Contracts') -Message 'Path-scoped Hostile Escape Contracts must be conditional-required.'

    $advisoryText = (($contract.advisoryValidation | ConvertTo-Json -Depth 8) + ' ' + $doc).ToLowerInvariant()
    foreach ($term in @('installed-game', 'windows', 'linux', 'modular', 'advisory')) {
        Assert-Condition -Condition ($advisoryText.Contains($term)) -Message ("OS/game advisory doctrine is missing term: $term")
    }

    $forbiddenText = (@($contract.forbiddenActions) -join ' ').ToLowerInvariant()
    foreach ($term in @('merge', 'close', 'delete a branch', 'force-push')) {
        Assert-Condition -Condition ($forbiddenText.Contains($term)) -Message ("Forbidden lifecycle action is not explicit: $term")
    }

    Assert-Condition -Condition ($controller -match "'pr',\s*'ready'") -Message 'Controller does not implement ready-for-review promotion.'
    Assert-Condition -Condition ($controller -match 'requiredWorkflowNames') -Message 'Controller does not classify repo-owned required workflows.'
    Assert-Condition -Condition ($controller -match 'conditionalRequiredWorkflowNames') -Message 'Controller does not classify path-scoped conditional workflows.'
    Assert-Condition -Condition ($controller -match 'advisoryChecks') -Message 'Controller does not preserve advisory check reporting.'
    foreach ($forbiddenPattern in @(
        "'pr',\s*'(merge|close)'",
        '(?im)\bgh\s+pr\s+(merge|close)\b',
        '(?im)\bgit\s+push\b',
        '(?im)\bgit\s+commit\b',
        '(?im)\bgit\s+branch\s+-D\b',
        '(?im)\bgit\s+push\s+--force\b'
    )) {
        Assert-Condition -Condition ($controller -notmatch $forbiddenPattern) -Message ("Controller contains a forbidden lifecycle command matching: $forbiddenPattern")
    }

    Assert-Condition -Condition ($workflow -match '(?m)^\s*pull-requests:\s*write\s*$') -Message 'Lifecycle workflow needs pull-request write permission.'
    Assert-Condition -Condition ($workflow -match '(?m)^\s*contents:\s*read\s*$') -Message 'Lifecycle workflow must keep contents read-only.'
    Assert-Condition -Condition ($workflow -notmatch '(?m)^\s*contents:\s*write\s*$') -Message 'Lifecycle workflow must not receive contents write permission.'
    Assert-Condition -Condition ($workflow -match 'pull_request_target') -Message 'Lifecycle workflow must use the trusted default-branch pull_request_target path.'
    Assert-Condition -Condition ($workflow -match 'workflow_run') -Message 'Lifecycle workflow must react to repo-owned workflow completion.'
    Assert-Condition -Condition ($workflow -match 'Invoke-TbgPrLifecycle.ps1') -Message 'Lifecycle workflow does not invoke the controller.'

    Assert-Condition -Condition ($test -match 'advisory-platform-failures') -Message 'Regression does not cover failing advisory platform checks.'
    Assert-Condition -Condition ($test -match 'conditional-workflow-absent') -Message 'Regression does not cover an absent path-scoped workflow.'
    Assert-Condition -Condition ($test -match 'conditional-workflow-failure') -Message 'Regression does not cover a failing present path-scoped workflow.'
    Assert-Condition -Condition ($test -match 'Windows PowerShell 5.1 installed-game validation') -Message 'Regression does not cover Windows installed-game advisory validation.'
    Assert-Condition -Condition ($test -match 'Linux installed-game runtime proof') -Message 'Regression does not cover Linux installed-game advisory validation.'
    Assert-Condition -Condition ($doc -match 'pr-lifecycle:hold-draft') -Message 'Lifecycle documentation does not explain the explicit hold label.'

    Write-Host 'PASS: repository-wide PR lifecycle automation is bounded, cross-platform, conditional-workflow aware, advisory for installed-game validation, and incapable of merge or close actions.' -ForegroundColor Green
    exit 0
} catch {
    Write-Host ('FAIL: PR lifecycle automation verifier: {0}' -f $_.Exception.Message) -ForegroundColor Red
    exit 1
}
