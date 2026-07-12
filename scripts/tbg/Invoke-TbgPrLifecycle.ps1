[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 2147483647)]
    [int]$PrNumber,

    [string]$Repository = $env:GITHUB_REPOSITORY,
    [string]$ContractPath = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) '.tbg\workflows\pr-lifecycle-automation.contract.json'),
    [string]$PrJsonPath = '',
    [string]$ChecksJsonPath = '',
    [string]$ReviewThreadsJsonPath = '',
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

function Invoke-GhCommand {
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

    return [pscustomobject][ordered]@{
        exitCode = $exitCode
        text = (($output | Out-String).Trim())
        arguments = @($Arguments)
    }
}

function Invoke-GhText {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [int[]]$AllowedExitCodes = @(0)
    )

    $result = Invoke-GhCommand -Arguments $Arguments
    if ($AllowedExitCodes -notcontains $result.exitCode) {
        throw ('gh {0} returned exit code {1}: {2}' -f ($Arguments -join ' '), $result.exitCode, $result.text)
    }
    return [string]$result.text
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

function Get-LivePr {
    param([Parameter(Mandatory = $true)][int]$Number)

    $text = Invoke-GhText -Arguments @(
        'pr', 'view', [string]$Number,
        '--repo', $Repository,
        '--json', 'number,state,isDraft,headRefOid,url,labels,baseRefName,headRefName,mergeable,mergeStateStatus,reviewDecision,isCrossRepository,createdAt,mergedAt'
    )
    return ($text | ConvertFrom-Json)
}

if (-not (Test-Path -LiteralPath $ContractPath)) {
    throw "PR lifecycle contract not found: $ContractPath"
}
$contract = Read-JsonFile -Path $ContractPath
$requiredWorkflowNames = @($contract.requiredWorkflowNames | ForEach-Object { [string]$_ })
$conditionalRequiredWorkflowNames = @($contract.conditionalRequiredWorkflowNames | ForEach-Object { [string]$_ })
$draftHoldLabel = [string]$contract.draftControl.holdLabel
$mergeControl = $contract.mergeControl
$mergeHoldLabel = [string]$mergeControl.holdLabel
$legacyOptInLabel = [string]$mergeControl.legacyOptInLabel
$stackedOptInLabel = [string]$mergeControl.stackedOptInLabel
$forkOptInLabel = [string]$mergeControl.forkOptInLabel
$defaultBaseBranch = [string]$mergeControl.defaultBaseBranch
$effectiveAfterUtc = [DateTimeOffset]::Parse([string]$mergeControl.effectiveAfterUtc)

if (-not [string]::IsNullOrWhiteSpace($PrJsonPath)) {
    $pr = Read-JsonFile -Path $PrJsonPath
} else {
    if ([string]::IsNullOrWhiteSpace($Repository)) {
        throw 'Repository is required outside GitHub Actions. Supply -Repository owner/name.'
    }
    $pr = Get-LivePr -Number $PrNumber
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

if (-not [string]::IsNullOrWhiteSpace($ReviewThreadsJsonPath)) {
    $reviewThreadPayload = Read-JsonFile -Path $ReviewThreadsJsonPath
} else {
    $repositoryParts = @($Repository -split '/', 2)
    if ($repositoryParts.Count -ne 2) { throw "Repository must be owner/name: $Repository" }
    $query = 'query($owner:String!,$name:String!,$number:Int!){repository(owner:$owner,name:$name){pullRequest(number:$number){reviewThreads(first:100){nodes{isResolved}pageInfo{hasNextPage}}}}}'
    $threadText = Invoke-GhText -Arguments @(
        'api', 'graphql',
        '-f', "query=$query",
        '-f', ("owner={0}" -f $repositoryParts[0]),
        '-f', ("name={0}" -f $repositoryParts[1]),
        '-F', ("number={0}" -f $PrNumber)
    )
    $reviewThreadPayload = $threadText | ConvertFrom-Json
}

$reviewThreadRoot = $reviewThreadPayload
if ($null -ne $reviewThreadPayload.PSObject.Properties['data']) {
    $reviewThreadRoot = $reviewThreadPayload.data.repository.pullRequest.reviewThreads
}
$reviewThreadNodes = @((Get-PropertyValue -InputObject $reviewThreadRoot -Name 'nodes' -DefaultValue @()))
$reviewThreadPageInfo = Get-PropertyValue -InputObject $reviewThreadRoot -Name 'pageInfo' -DefaultValue ([pscustomobject]@{ hasNextPage = $false })
$reviewThreadsIncomplete = [bool](Get-PropertyValue -InputObject $reviewThreadPageInfo -Name 'hasNextPage' -DefaultValue $false)
$unresolvedReviewThreads = @($reviewThreadNodes | Where-Object { -not [bool](Get-PropertyValue -InputObject $_ -Name 'isResolved' -DefaultValue $false) })

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

    if (($requiredWorkflowNames -contains $workflow) -or ($conditionalRequiredWorkflowNames -contains $workflow)) {
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
$headSha = [string](Get-PropertyValue -InputObject $pr -Name 'headRefOid' -DefaultValue '')
$baseRefName = [string](Get-PropertyValue -InputObject $pr -Name 'baseRefName' -DefaultValue '')
$mergeable = ([string](Get-PropertyValue -InputObject $pr -Name 'mergeable' -DefaultValue 'UNKNOWN')).ToUpperInvariant()
$mergeStateStatus = ([string](Get-PropertyValue -InputObject $pr -Name 'mergeStateStatus' -DefaultValue 'UNKNOWN')).ToUpperInvariant()
$reviewDecision = ([string](Get-PropertyValue -InputObject $pr -Name 'reviewDecision' -DefaultValue '')).ToUpperInvariant()
$isCrossRepository = [bool](Get-PropertyValue -InputObject $pr -Name 'isCrossRepository' -DefaultValue $false)
$createdAtText = [string](Get-PropertyValue -InputObject $pr -Name 'createdAt' -DefaultValue '')
$mergedAtText = [string](Get-PropertyValue -InputObject $pr -Name 'mergedAt' -DefaultValue '')
$isDraftHeld = $labels -contains $draftHoldLabel
$isMergeHeld = $labels -contains $mergeHoldLabel
$isLegacyOptedIn = $labels -contains $legacyOptInLabel
$isStackedOptedIn = $labels -contains $stackedOptInLabel
$isForkOptedIn = $labels -contains $forkOptInLabel
$isLegacy = $false
if (-not [string]::IsNullOrWhiteSpace($createdAtText)) {
    $isLegacy = ([DateTimeOffset]::Parse($createdAtText) -lt $effectiveAfterUtc)
}

$action = ''
$reason = ''
$mergeAttempt = [ordered]@{
    attempted = $false
    mode = ''
    exitCode = $null
    output = ''
}

if ($state -eq 'MERGED' -or -not [string]::IsNullOrWhiteSpace($mergedAtText)) {
    $action = 'already_merged'
    $reason = 'The pull request is already merged.'
} elseif ($state -ne 'OPEN') {
    $action = 'closed_noop'
    $reason = 'The pull request is not open.'
} elseif ($isDraft -and $isDraftHeld) {
    $action = 'held_draft'
    $reason = ('The pull request carries the explicit draft hold label "{0}".' -f $draftHoldLabel)
} elseif ($missingRequiredWorkflows.Count -gt 0) {
    $action = 'waiting_required_workflows'
    $reason = ('Always-required workflow checks are not present yet: {0}.' -f ($missingRequiredWorkflows -join ', '))
} elseif ($requiredNotSuccessful.Count -gt 0) {
    $action = 'waiting_required_checks'
    $reason = ('One or more required or present conditional checks are not successful: {0}.' -f (($requiredNotSuccessful | ForEach-Object { '{0}/{1}={2}' -f $_.workflow, $_.name, $_.bucket }) -join '; '))
} elseif ($isDraft) {
    $action = 'ready_promoted'
    $reason = 'All required evidence passed; the draft is eligible for automatic ready-for-review promotion.'
    if (-not $DryRun) {
        [void](Invoke-GhText -Arguments @('pr', 'ready', [string]$PrNumber, '--repo', $Repository))
    }
} elseif ($isMergeHeld) {
    $action = 'held_merge'
    $reason = ('The pull request carries the explicit merge hold label "{0}".' -f $mergeHoldLabel)
} elseif ($isLegacy -and -not $isLegacyOptedIn) {
    $action = 'blocked_legacy_pr'
    $reason = ('The pull request predates the automatic-merge policy. Add "{0}" only after current evidence is reviewed.' -f $legacyOptInLabel)
} elseif ($baseRefName -ne $defaultBaseBranch -and -not $isStackedOptedIn) {
    $action = 'blocked_non_default_base'
    $reason = ('The pull request targets "{0}" instead of "{1}". Add "{2}" only when the stacked merge is intentional.' -f $baseRefName, $defaultBaseBranch, $stackedOptInLabel)
} elseif ($isCrossRepository -and -not $isForkOptedIn) {
    $action = 'blocked_cross_repository'
    $reason = ('Cross-repository pull requests require the explicit "{0}" label before automatic merge.' -f $forkOptInLabel)
} elseif ([string]::IsNullOrWhiteSpace($headSha) -or $mergeable -ne 'MERGEABLE') {
    $action = 'waiting_mergeable'
    $reason = ('GitHub mergeability is "{0}" and the inspected head is "{1}".' -f $mergeable, $headSha)
} elseif ($mergeStateStatus -in @('DIRTY', 'DRAFT', 'UNKNOWN', 'BEHIND')) {
    $action = 'waiting_merge_state'
    $reason = ('GitHub merge state "{0}" is not eligible for automatic merge.' -f $mergeStateStatus)
} elseif ($reviewDecision -in @('CHANGES_REQUESTED', 'REVIEW_REQUIRED')) {
    $action = 'waiting_review'
    $reason = ('GitHub review decision is "{0}".' -f $reviewDecision)
} elseif ($reviewThreadsIncomplete -or $unresolvedReviewThreads.Count -gt 0) {
    $action = 'waiting_review_threads'
    $reason = ('Review-thread inspection complete={0}; unresolved thread count={1}.' -f (-not $reviewThreadsIncomplete), $unresolvedReviewThreads.Count)
} elseif ($DryRun) {
    $action = 'merge_eligible'
    $reason = 'The exact head passed the deterministic merge gate. Dry-run mode did not mutate the pull request.'
} else {
    $mergeAttempt.attempted = $true
    $mergeAttempt.mode = 'auto'
    $autoResult = Invoke-GhCommand -Arguments @(
        'pr', 'merge', [string]$PrNumber,
        '--repo', $Repository,
        '--squash', '--auto',
        '--match-head-commit', $headSha
    )
    $mergeAttempt.exitCode = $autoResult.exitCode
    $mergeAttempt.output = $autoResult.text

    if ($autoResult.exitCode -eq 0) {
        $postPr = Get-LivePr -Number $PrNumber
        $postState = ([string](Get-PropertyValue -InputObject $postPr -Name 'state' -DefaultValue '')).ToUpperInvariant()
        if ($postState -eq 'MERGED') {
            $action = 'merged'
            $reason = 'GitHub accepted and completed the exact-head squash merge.'
        } else {
            $action = 'auto_merge_enabled'
            $reason = 'GitHub accepted exact-head auto-merge and will complete it when repository rules permit.'
        }
    } elseif ($mergeStateStatus -in @('CLEAN', 'UNSTABLE', 'HAS_HOOKS')) {
        $mergeAttempt.mode = 'direct_fallback'
        $directResult = Invoke-GhCommand -Arguments @(
            'pr', 'merge', [string]$PrNumber,
            '--repo', $Repository,
            '--squash',
            '--match-head-commit', $headSha
        )
        $mergeAttempt.exitCode = $directResult.exitCode
        $mergeAttempt.output = $directResult.text
        if ($directResult.exitCode -eq 0) {
            $action = 'merged'
            $reason = 'Repository auto-merge was unavailable, but GitHub accepted the deterministic direct exact-head squash merge.'
        } else {
            $action = 'merge_blocked_by_github'
            $reason = ('GitHub rejected both automatic and direct exact-head merge. Server output: {0}' -f $directResult.text)
        }
    } else {
        $action = 'merge_blocked_by_github'
        $reason = ('GitHub rejected auto-merge and merge state "{0}" does not permit direct fallback. Server output: {1}' -f $mergeStateStatus, $autoResult.text)
    }
}

$result = [ordered]@{
    schema = 'TbgPrLifecycleResult.v2'
    repository = $Repository
    prNumber = [int](Get-PropertyValue -InputObject $pr -Name 'number' -DefaultValue $PrNumber)
    url = [string](Get-PropertyValue -InputObject $pr -Name 'url' -DefaultValue '')
    headSha = $headSha
    baseRefName = $baseRefName
    action = $action
    dryRun = [bool]$DryRun
    reason = $reason
    requiredWorkflowNames = $requiredWorkflowNames
    conditionalRequiredWorkflowNames = $conditionalRequiredWorkflowNames
    missingRequiredWorkflows = $missingRequiredWorkflows
    requiredChecks = @($requiredChecks.ToArray())
    advisoryChecks = @($advisoryChecks.ToArray())
    advisoryNotSuccessfulCount = $advisoryNotSuccessful.Count
    draftHoldPresent = $isDraftHeld
    mergeHoldPresent = $isMergeHeld
    mergeable = $mergeable
    mergeStateStatus = $mergeStateStatus
    reviewDecision = $reviewDecision
    unresolvedReviewThreadCount = $unresolvedReviewThreads.Count
    reviewThreadsInspectionComplete = (-not $reviewThreadsIncomplete)
    mergeAttempt = $mergeAttempt
    forbiddenActionsExecuted = @()
}
$resultJson = $result | ConvertTo-Json -Depth 12

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
        ('- Exact head: `{0}`' -f $headSha),
        ('- Action: `{0}`' -f $action),
        ('- Required checks: {0}' -f $requiredChecks.Count),
        ('- Advisory checks: {0}' -f $advisoryChecks.Count),
        ('- Advisory checks not successful: {0}' -f $advisoryNotSuccessful.Count),
        ('- Unresolved review threads: {0}' -f $unresolvedReviewThreads.Count),
        ('- Reason: {0}' -f $reason),
        '',
        'Installed-game, launcher, live-runtime, and OS-specific game-backed validation is advisory by default.'
    ) | Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Encoding UTF8
}

Write-Output $resultJson
