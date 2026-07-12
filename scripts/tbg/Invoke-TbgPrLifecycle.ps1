[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 2147483647)]
    [int]$PrNumber,

    [string]$Repository = $env:GITHUB_REPOSITORY,
    [string]$ContractPath = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) '.tbg\workflows\pr-lifecycle-automation.contract.json'),
    [string]$PrJsonPath = '',
    [string]$ChecksJsonPath = '',
    [string]$OutputPath = '',
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PropertyValue {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name,
        $DefaultValue = $null
    )

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) { return $DefaultValue }
    return $property.Value
}

function Invoke-GhText {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [int[]]$AllowedExitCodes = @(0)
    )

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
    if ($AllowedExitCodes -notcontains $exitCode) {
        throw ('gh {0} returned exit code {1}: {2}' -f ($Arguments -join ' '), $exitCode, $text)
    }
    return $text
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Convert-ToCheckBucket {
    param([Parameter(Mandatory = $true)]$Check)

    $bucket = [string](Get-PropertyValue -InputObject $Check -Name 'bucket' -DefaultValue '')
    if (-not [string]::IsNullOrWhiteSpace($bucket)) {
        return $bucket.ToLowerInvariant()
    }

    $state = ([string](Get-PropertyValue -InputObject $Check -Name 'state' -DefaultValue '')).ToUpperInvariant()
    if ($state -in @('SUCCESS', 'NEUTRAL')) { return 'pass' }
    if ($state -in @('SKIPPED', 'STALE')) { return 'skipping' }
    if ($state -in @('PENDING', 'QUEUED', 'IN_PROGRESS', 'EXPECTED', 'WAITING', 'REQUESTED')) { return 'pending' }
    if ($state -in @('CANCELLED', 'CANCELED')) { return 'cancel' }
    return 'fail'
}

if (-not (Test-Path -LiteralPath $ContractPath)) {
    throw "PR lifecycle contract not found: $ContractPath"
}
$contract = Read-JsonFile -Path $ContractPath
$requiredWorkflowNames = @($contract.requiredWorkflowNames | ForEach-Object { [string]$_ })
$holdLabel = [string]$contract.draftControl.holdLabel

if (-not [string]::IsNullOrWhiteSpace($PrJsonPath)) {
    $pr = Read-JsonFile -Path $PrJsonPath
} else {
    if ([string]::IsNullOrWhiteSpace($Repository)) {
        throw 'Repository is required outside GitHub Actions. Supply -Repository owner/name.'
    }
    $prText = Invoke-GhText -Arguments @(
        'pr', 'view', [string]$PrNumber,
        '--repo', $Repository,
        '--json', 'number,state,isDraft,headRefOid,url,labels'
    )
    $pr = $prText | ConvertFrom-Json
}

if (-not [string]::IsNullOrWhiteSpace($ChecksJsonPath)) {
    $checks = @((Read-JsonFile -Path $ChecksJsonPath))
} else {
    $checksText = Invoke-GhText -Arguments @(
        'pr', 'checks', [string]$PrNumber,
        '--repo', $Repository,
        '--json', 'name,state,workflow,bucket,description,link'
    ) -AllowedExitCodes @(0, 1, 8)

    if ([string]::IsNullOrWhiteSpace($checksText) -or -not $checksText.TrimStart().StartsWith('[')) {
        $checks = @()
    } else {
        $checks = @($checksText | ConvertFrom-Json)
    }
}

$labels = @()
foreach ($label in @((Get-PropertyValue -InputObject $pr -Name 'labels' -DefaultValue @()))) {
    if ($label -is [string]) {
        $labels += [string]$label
    } else {
        $labels += [string](Get-PropertyValue -InputObject $label -Name 'name' -DefaultValue '')
    }
}

$requiredChecks = [System.Collections.Generic.List[object]]::new()
$advisoryChecks = [System.Collections.Generic.List[object]]::new()
foreach ($check in $checks) {
    $workflow = [string](Get-PropertyValue -InputObject $check -Name 'workflow' -DefaultValue '')
    $name = [string](Get-PropertyValue -InputObject $check -Name 'name' -DefaultValue '')
    $bucket = Convert-ToCheckBucket -Check $check
    $row = [pscustomobject][ordered]@{
        workflow = $workflow
        name = $name
        bucket = $bucket
        state = [string](Get-PropertyValue -InputObject $check -Name 'state' -DefaultValue '')
        link = [string](Get-PropertyValue -InputObject $check -Name 'link' -DefaultValue '')
    }

    if ($requiredWorkflowNames -contains $workflow) {
        $requiredChecks.Add($row) | Out-Null
    } else {
        $advisoryChecks.Add($row) | Out-Null
    }
}

$missingRequiredWorkflows = @()
foreach ($requiredWorkflow in $requiredWorkflowNames) {
    if (@($requiredChecks | Where-Object { $_.workflow -eq $requiredWorkflow }).Count -eq 0) {
        $missingRequiredWorkflows += $requiredWorkflow
    }
}

$requiredNotSuccessful = @($requiredChecks | Where-Object { $_.bucket -notin @('pass', 'skipping') })
$advisoryNotSuccessful = @($advisoryChecks | Where-Object { $_.bucket -notin @('pass', 'skipping') })
$state = ([string](Get-PropertyValue -InputObject $pr -Name 'state' -DefaultValue '')).ToUpperInvariant()
$isDraft = [bool](Get-PropertyValue -InputObject $pr -Name 'isDraft' -DefaultValue $false)
$isHeld = $labels -contains $holdLabel
$action = ''
$reason = ''

if ($state -ne 'OPEN') {
    $action = 'closed_noop'
    $reason = 'The pull request is not open.'
} elseif (-not $isDraft) {
    $action = 'already_ready'
    $reason = 'The pull request is already ready for review.'
} elseif ($isHeld) {
    $action = 'held_draft'
    $reason = ('The pull request carries the explicit hold label "{0}".' -f $holdLabel)
} elseif ($missingRequiredWorkflows.Count -gt 0) {
    $action = 'waiting_required_workflows'
    $reason = ('Required workflow checks are not present yet: {0}.' -f ($missingRequiredWorkflows -join ', '))
} elseif ($requiredNotSuccessful.Count -gt 0) {
    $action = 'waiting_required_checks'
    $reason = ('One or more required checks are not successful: {0}.' -f (($requiredNotSuccessful | ForEach-Object { '{0}/{1}={2}' -f $_.workflow, $_.name, $_.bucket }) -join '; '))
} else {
    $action = 'ready_promoted'
    $reason = 'All required platform-neutral workflows passed; advisory platform and game-backed checks do not block readiness.'
    if (-not $DryRun) {
        [void](Invoke-GhText -Arguments @('pr', 'ready', [string]$PrNumber, '--repo', $Repository))
    }
}

$result = [ordered]@{
    schema = 'TbgPrLifecycleResult.v1'
    repository = $Repository
    prNumber = [int](Get-PropertyValue -InputObject $pr -Name 'number' -DefaultValue $PrNumber)
    url = [string](Get-PropertyValue -InputObject $pr -Name 'url' -DefaultValue '')
    headSha = [string](Get-PropertyValue -InputObject $pr -Name 'headRefOid' -DefaultValue '')
    action = $action
    dryRun = [bool]$DryRun
    reason = $reason
    requiredWorkflowNames = $requiredWorkflowNames
    missingRequiredWorkflows = $missingRequiredWorkflows
    requiredChecks = @($requiredChecks.ToArray())
    advisoryChecks = @($advisoryChecks.ToArray())
    advisoryNotSuccessfulCount = $advisoryNotSuccessful.Count
    holdLabelPresent = $isHeld
    forbiddenActionsExecuted = @()
}
$resultJson = $result | ConvertTo-Json -Depth 10

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $parent = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $resultJson | Set-Content -LiteralPath $OutputPath -Encoding UTF8
}

if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_STEP_SUMMARY)) {
    @(
        '## PR lifecycle automation',
        '',
        ('- PR: #{0}' -f $PrNumber),
        ('- Action: `{0}`' -f $action),
        ('- Required checks: {0}' -f $requiredChecks.Count),
        ('- Advisory checks: {0}' -f $advisoryChecks.Count),
        ('- Advisory checks not successful: {0}' -f $advisoryNotSuccessful.Count),
        ('- Reason: {0}' -f $reason),
        '',
        'Installed-game, launcher, live-runtime, and OS-specific game-backed validation is advisory by default.'
    ) | Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Encoding UTF8
}

Write-Output $resultJson
