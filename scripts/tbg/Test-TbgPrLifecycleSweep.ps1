Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('tbg-pr-lifecycle-sweep-test-' + [Guid]::NewGuid().ToString('N'))
$sweep = Join-Path $PSScriptRoot 'Invoke-TbgPrLifecycleSweep.ps1'
$stub = Join-Path $tempRoot 'stub-controller.ps1'
$outputRoot = Join-Path $tempRoot 'output'

function Assert-Equal {
    param($Actual, $Expected, [string]$Message)
    if ($Actual -ne $Expected) {
        throw ('{0} Expected "{1}" but observed "{2}".' -f $Message, $Expected, $Actual)
    }
}

try {
    if (-not (Test-Path -LiteralPath $sweep)) { throw 'Lifecycle sweep script is missing.' }
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

    @'
param(
    [int]$PrNumber,
    [string]$Repository,
    [string]$OutputPath,
    [switch]$DryRun
)
$action = if ($PrNumber -eq 11) { 'merge_eligible' } else { 'waiting_required_checks' }
[ordered]@{
    schema = 'TbgPrLifecycleResult.v2'
    repository = $Repository
    prNumber = $PrNumber
    action = $action
    dryRun = [bool]$DryRun
    forbiddenActionsExecuted = @()
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
'@ | Set-Content -LiteralPath $stub -Encoding UTF8

    [void](& $sweep `
        -Repository 'EndeavorEverlasting/BlacksmithGuild' `
        -ControllerPath $stub `
        -OutputDirectory $outputRoot `
        -PrNumbers @(12, 11, 11) `
        -DryRun)

    $summaryPath = Join-Path $outputRoot 'pr-lifecycle-sweep-result.json'
    if (-not (Test-Path -LiteralPath $summaryPath)) { throw 'Sweep summary was not written.' }
    $summary = Get-Content -LiteralPath $summaryPath -Raw -Encoding UTF8 | ConvertFrom-Json

    Assert-Equal -Actual $summary.schema -Expected 'TbgPrLifecycleSweepResult.v1' -Message 'Sweep schema is wrong.'
    Assert-Equal -Actual $summary.resultCount -Expected 2 -Message 'Sweep did not deduplicate PR numbers.'
    Assert-Equal -Actual $summary.failureCount -Expected 0 -Message 'Sweep reported unexpected failures.'
    Assert-Equal -Actual @($summary.inspectedPrNumbers).Count -Expected 2 -Message 'Inspected PR count is wrong.'
    Assert-Equal -Actual $summary.inspectedPrNumbers[0] -Expected 11 -Message 'PR numbers were not sorted.'
    Assert-Equal -Actual $summary.inspectedPrNumbers[1] -Expected 12 -Message 'PR numbers were not sorted.'
    Assert-Equal -Actual $summary.actionCounts.merge_eligible -Expected 1 -Message 'Merge-eligible action count is wrong.'
    Assert-Equal -Actual $summary.actionCounts.waiting_required_checks -Expected 1 -Message 'Waiting action count is wrong.'

    foreach ($number in @(11, 12)) {
        $resultPath = Join-Path $outputRoot ("pr-{0}.json" -f $number)
        if (-not (Test-Path -LiteralPath $resultPath)) { throw "Missing per-PR lifecycle result: $resultPath" }
        $result = Get-Content -LiteralPath $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-Equal -Actual ([bool]$result.dryRun) -Expected $true -Message "PR $number did not receive dry-run mode."
    }

    Write-Host 'PASS: lifecycle sweep deduplicates open PRs, invokes the bounded controller, preserves per-PR artifacts, and writes an aggregate action report.' -ForegroundColor Green
    exit 0
} catch {
    Write-Host ('FAIL: PR lifecycle sweep test: {0}' -f $_.Exception.Message) -ForegroundColor Red
    exit 1
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
