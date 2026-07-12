[CmdletBinding()]
param(
    [string]$Repository = $env:GITHUB_REPOSITORY,
    [string]$ControllerPath = (Join-Path $PSScriptRoot 'Invoke-TbgPrLifecycle.ps1'),
    [string]$OutputDirectory = (Join-Path ([IO.Path]::GetTempPath()) 'tbg-pr-lifecycle-sweep'),
    [int[]]$PrNumbers = @(),
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-GhText {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $global:LASTEXITCODE = 0
        $output = & gh @Arguments 2>&1
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    $text = (($output | Out-String).Trim())
    if ($exitCode -ne 0) {
        throw ('gh {0} returned exit code {1}: {2}' -f ($Arguments -join ' '), $exitCode, $text)
    }
    return $text
}

if ([string]::IsNullOrWhiteSpace($Repository)) {
    throw 'Repository is required. Supply owner/name or set GITHUB_REPOSITORY.'
}
if (-not (Test-Path -LiteralPath $ControllerPath)) {
    throw "Lifecycle controller not found: $ControllerPath"
}

$resolvedNumbers = @($PrNumbers | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
if ($resolvedNumbers.Count -eq 0) {
    $numberText = Invoke-GhText -Arguments @(
        'pr', 'list',
        '--repo', $Repository,
        '--state', 'open',
        '--limit', '200',
        '--json', 'number',
        '--jq', '.[].number'
    )
    $resolvedNumbers = @(
        $numberText -split '\r?\n' |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -match '^\d+$' } |
            ForEach-Object { [int]$_ } |
            Sort-Object -Unique
    )
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$results = [System.Collections.Generic.List[object]]::new()
$failures = [System.Collections.Generic.List[object]]::new()

foreach ($number in $resolvedNumbers) {
    $resultPath = Join-Path $OutputDirectory ("pr-{0}.json" -f $number)
    try {
        $invokeArguments = @{
            PrNumber = $number
            Repository = $Repository
            OutputPath = $resultPath
        }
        if ($DryRun) { $invokeArguments.DryRun = $true }
        [void](& $ControllerPath @invokeArguments)

        if (-not (Test-Path -LiteralPath $resultPath)) {
            throw "Lifecycle controller did not write $resultPath."
        }
        $result = Get-Content -LiteralPath $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $results.Add($result) | Out-Null
    } catch {
        $failures.Add([pscustomobject][ordered]@{
            prNumber = $number
            message = $_.Exception.Message
        }) | Out-Null
    }
}

$actionCounts = [ordered]@{}
foreach ($result in $results) {
    $action = [string]$result.action
    if (-not $actionCounts.Contains($action)) { $actionCounts[$action] = 0 }
    $actionCounts[$action] = [int]$actionCounts[$action] + 1
}

$summary = [ordered]@{
    schema = 'TbgPrLifecycleSweepResult.v1'
    repository = $Repository
    generatedUtc = [DateTimeOffset]::UtcNow.ToString('o')
    dryRun = [bool]$DryRun
    inspectedPrNumbers = @($resolvedNumbers)
    resultCount = $results.Count
    failureCount = $failures.Count
    actionCounts = $actionCounts
    results = @($results.ToArray())
    failures = @($failures.ToArray())
}
$summaryPath = Join-Path $OutputDirectory 'pr-lifecycle-sweep-result.json'
$summaryJson = $summary | ConvertTo-Json -Depth 12
$summaryJson | Set-Content -LiteralPath $summaryPath -Encoding UTF8

if ($failures.Count -gt 0) {
    throw ('Lifecycle sweep recorded {0} failure(s). See {1}.' -f $failures.Count, $summaryPath)
}

Write-Output $summaryJson
