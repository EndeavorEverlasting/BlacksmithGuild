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
        [Parameter(Mandatory = $true)][bool]$IsDraft,
        [string[]]$Labels = @(),
        [Parameter(Mandatory = $true)][object[]]$Checks,
        [Parameter(Mandatory = $true)][string]$ExpectedAction
    )

    $caseRoot = Join-Path $tempRoot $Name
    New-Item -ItemType Directory -Force -Path $caseRoot | Out-Null
    $prPath = Join-Path $caseRoot 'pr.json'
    $checksPath = Join-Path $caseRoot 'checks.json'
    $resultPath = Join-Path $caseRoot 'result.json'

    [ordered]@{
        number = 77
        state = 'OPEN'
        isDraft = $IsDraft
        headRefOid = '0123456789abcdef'
        url = 'https://example.invalid/pr/77'
        labels = @($Labels | ForEach-Object { [ordered]@{ name = $_ } })
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $prPath -Encoding UTF8

    @($Checks) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $checksPath -Encoding UTF8

    [void](& $controller `
        -PrNumber 77 `
        -Repository 'EndeavorEverlasting/BlacksmithGuild' `
        -ContractPath $contract `
        -PrJsonPath $prPath `
        -ChecksJsonPath $checksPath `
        -OutputPath $resultPath `
        -DryRun)

    $result = Get-Content -LiteralPath $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Equal -Actual $result.action -Expected $ExpectedAction -Message ("Case $Name returned the wrong action.")
    Assert-Equal -Actual @($result.forbiddenActionsExecuted).Count -Expected 0 -Message ("Case $Name reported a forbidden action.")
    return $result
}

try {
    if (-not (Test-Path -LiteralPath $controller)) { throw 'Lifecycle controller is missing.' }
    if (-not (Test-Path -LiteralPath $contract)) { throw 'Lifecycle contract is missing.' }
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

    $neutralPasses = @(
        (New-Check -Workflow 'Governor Contracts' -Name 'Governor contract verifiers' -Bucket 'pass'),
        (New-Check -Workflow 'Harness Policy Reports' -Name 'Static harness policy report' -Bucket 'pass'),
        (New-Check -Workflow 'Hostile Escape Contracts' -Name 'Pure hostile geometry contracts' -Bucket 'pass')
    )

    $promoted = Invoke-Case -Name 'advisory-platform-failures' -IsDraft $true -Checks @(
        $neutralPasses +
        (New-Check -Workflow 'Platform Game Advisory' -Name 'Windows PowerShell 5.1 installed-game validation' -Bucket 'fail') +
        (New-Check -Workflow 'Platform Game Advisory' -Name 'Linux installed-game runtime proof' -Bucket 'pending')
    ) -ExpectedAction 'ready_promoted'
    Assert-Equal -Actual @($promoted.requiredChecks).Count -Expected 3 -Message 'Platform-neutral required check count is wrong.'
    Assert-Equal -Actual @($promoted.advisoryChecks).Count -Expected 2 -Message 'Advisory platform check count is wrong.'
    Assert-Equal -Actual $promoted.advisoryNotSuccessfulCount -Expected 2 -Message 'Advisory failures should be reported without blocking.'

    [void](Invoke-Case -Name 'required-failure' -IsDraft $true -Checks @(
        (New-Check -Workflow 'Governor Contracts' -Name 'Governor contract verifiers' -Bucket 'fail'),
        (New-Check -Workflow 'Harness Policy Reports' -Name 'Static harness policy report' -Bucket 'pass'),
        (New-Check -Workflow 'Hostile Escape Contracts' -Name 'Pure hostile geometry contracts' -Bucket 'pass')
    ) -ExpectedAction 'waiting_required_checks')

    [void](Invoke-Case -Name 'missing-required-workflow' -IsDraft $true -Checks @(
        (New-Check -Workflow 'Governor Contracts' -Name 'Governor contract verifiers' -Bucket 'pass'),
        (New-Check -Workflow 'Harness Policy Reports' -Name 'Static harness policy report' -Bucket 'pass')
    ) -ExpectedAction 'waiting_required_workflows')

    [void](Invoke-Case -Name 'explicit-hold' -IsDraft $true -Labels @('pr-lifecycle:hold-draft') -Checks $neutralPasses -ExpectedAction 'held_draft')
    [void](Invoke-Case -Name 'already-ready' -IsDraft $false -Checks $neutralPasses -ExpectedAction 'already_ready')

    Write-Host 'PASS: PR lifecycle automation promotes green drafts, reports advisory OS/game checks, honors explicit holds, and waits for required platform-neutral workflows.' -ForegroundColor Green
    exit 0
} catch {
    Write-Host ('FAIL: PR lifecycle automation test: {0}' -f $_.Exception.Message) -ForegroundColor Red
    exit 1
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
