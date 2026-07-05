# Execute the repo-resident Agent Feedback stop hook.
# This hook is repo-only: it runs cheap guardrails, writes feedback/remediation JSON, archives logs,
# and reports proof boundaries for the next agent sprint. It does not run live certs.

param(
    [switch]$FailOnBlocking,
    [switch]$SkipPlanner,
    [switch]$NoPlannerScripts,
    [string]$ArtifactRoot = $null
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $ArtifactRoot) {
    $ArtifactRoot = Join-Path $repoRoot 'artifacts\agent-stop-hook'
}

$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
$artifactDir = Join-Path $ArtifactRoot $timestamp
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null

$stepResults = New-Object System.Collections.Generic.List[object]

function Convert-ToRepoRelativePath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }

    $fullRoot = [System.IO.Path]::GetFullPath($repoRoot).TrimEnd('\', '/')
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if ($fullPath.StartsWith($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $fullPath.Substring($fullRoot.Length).TrimStart('\', '/')
    }

    return $Path
}

function New-SafeStepName {
    param([Parameter(Mandatory = $true)][string]$Name)
    return ($Name -replace '[^A-Za-z0-9_.-]', '_')
}

function Write-StepLog {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$CommandText,
        [Parameter(Mandatory = $true)][int]$ExitCode,
        [Parameter(Mandatory = $true)][string]$OutputText
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("step=$Name") | Out-Null
    $lines.Add("generatedUtc=$((Get-Date).ToUniversalTime().ToString('o'))") | Out-Null
    $lines.Add("exitCode=$ExitCode") | Out-Null
    $lines.Add('command:') | Out-Null
    $lines.Add($CommandText) | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('output:') | Out-Null
    if ([string]::IsNullOrEmpty($OutputText)) {
        $lines.Add('<no output>') | Out-Null
    } else {
        $lines.Add($OutputText) | Out-Null
    }

    Set-Content -LiteralPath $Path -Value ($lines -join "`r`n") -Encoding UTF8
}

function Invoke-StopHookStep {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$CommandText,
        [Parameter(Mandatory = $true)][scriptblock]$ScriptBlock,
        [switch]$Optional
    )

    $safeName = New-SafeStepName -Name $Name
    $logPath = Join-Path $artifactDir ("$safeName.log")
    $outputText = ''
    $exitCode = 0

    try {
        $global:LASTEXITCODE = 0
        $output = & $ScriptBlock 2>&1
        $outputText = (($output | ForEach-Object { [string]$_ }) -join "`n")
        if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            $exitCode = [int]$LASTEXITCODE
        } else {
            $exitCode = 0
        }
    } catch {
        $exitCode = 1
        $outputText = $_.Exception.Message
    }

    Write-StepLog -Path $logPath -Name $Name -CommandText $CommandText -ExitCode $exitCode -OutputText $outputText

    $result = [pscustomobject][ordered]@{
        name = $Name
        optional = [bool]$Optional
        exitCode = $exitCode
        ok = ($exitCode -eq 0 -or [bool]$Optional)
        logPath = (Convert-ToRepoRelativePath -Path $logPath)
    }
    $stepResults.Add($result) | Out-Null

    if ($exitCode -eq 0) {
        Write-Host ("PASS {0}" -f $Name) -ForegroundColor Green
    } elseif ($Optional) {
        Write-Host ("SKIP/NOTE {0} exit={1}" -f $Name, $exitCode) -ForegroundColor Yellow
    } else {
        Write-Host ("FAIL {0} exit={1}" -f $Name, $exitCode) -ForegroundColor Red
    }

    return $result
}

function Invoke-PowerShellFileStep {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [string[]]$Arguments = @(),
        [switch]$Optional
    )

    $scriptPath = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        $logPath = Join-Path $artifactDir ("$(New-SafeStepName -Name $Name).log")
        Write-StepLog -Path $logPath -Name $Name -CommandText $RelativePath -ExitCode 127 -OutputText "Missing script: $RelativePath"

        $result = [pscustomobject][ordered]@{
            name = $Name
            optional = [bool]$Optional
            exitCode = 127
            ok = [bool]$Optional
            logPath = (Convert-ToRepoRelativePath -Path $logPath)
        }
        $stepResults.Add($result) | Out-Null

        if ($Optional) {
            Write-Host ("SKIP {0}: missing {1}" -f $Name, $RelativePath) -ForegroundColor Yellow
        } else {
            Write-Host ("FAIL {0}: missing {1}" -f $Name, $RelativePath) -ForegroundColor Red
        }

        return $result
    }

    $displayCommand = 'powershell -NoProfile -ExecutionPolicy Bypass -File ' + $RelativePath
    if ($Arguments.Count -gt 0) {
        $displayCommand = $displayCommand + ' ' + ($Arguments -join ' ')
    }

    return Invoke-StopHookStep -Name $Name -CommandText $displayCommand -Optional:$Optional -ScriptBlock {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments
    }
}

function Read-JsonFileSafe {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        return Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    } catch {
        return $null
    }
}

Set-Location $repoRoot

Write-Host ("Agent stop hook archive: {0}" -f (Convert-ToRepoRelativePath -Path $artifactDir)) -ForegroundColor Cyan

Invoke-StopHookStep -Name 'git-diff-check' -CommandText 'git diff --check' -ScriptBlock {
    & git -C $repoRoot diff --check
} | Out-Null

Invoke-PowerShellFileStep -Name 'verify-agent-feedback-harness-contract' -RelativePath 'scripts\verify-agent-feedback-harness-contract.ps1' | Out-Null
Invoke-PowerShellFileStep -Name 'verify-agent-feedback-writer-contract' -RelativePath 'scripts\verify-agent-feedback-writer-contract.ps1' | Out-Null
Invoke-PowerShellFileStep -Name 'verify-agent-remediation-planner-contract' -RelativePath 'scripts\verify-agent-remediation-planner-contract.ps1' | Out-Null
Invoke-PowerShellFileStep -Name 'verify-agent-stop-hook-contract' -RelativePath 'scripts\verify-agent-stop-hook-contract.ps1' | Out-Null
Invoke-PowerShellFileStep -Name 'test-powershell-utf8-bom-contract' -RelativePath 'scripts\test-powershell-utf8-bom-contract.ps1' | Out-Null

$feedbackPath = Join-Path $repoRoot 'BlacksmithGuild_AgentFeedback.json'
$remediationPlanPath = Join-Path $repoRoot 'BlacksmithGuild_AgentRemediationPlan.json'

Invoke-PowerShellFileStep -Name 'write-agent-feedback-summary' -RelativePath 'scripts\write-agent-feedback-summary.ps1' -Arguments @('-OutputPath', $feedbackPath) | Out-Null

$plannerExists = Test-Path -LiteralPath (Join-Path $repoRoot 'scripts\write-agent-remediation-plan.ps1')
if (-not $SkipPlanner -and $plannerExists) {
    $plannerArtifactRoot = Join-Path $artifactDir 'remediation'
    $plannerArgs = @('-FeedbackPath', $feedbackPath, '-OutputPath', $remediationPlanPath, '-ArtifactRoot', $plannerArtifactRoot)
    if ($NoPlannerScripts) {
        $plannerArgs += '-NoScripts'
    }

    Invoke-PowerShellFileStep -Name 'write-agent-remediation-plan' -RelativePath 'scripts\write-agent-remediation-plan.ps1' -Arguments $plannerArgs | Out-Null
} elseif ($SkipPlanner) {
    Invoke-StopHookStep -Name 'write-agent-remediation-plan' -CommandText 'skipped by -SkipPlanner' -Optional -ScriptBlock {
        Write-Host 'Skipped remediation planner by request.'
    } | Out-Null
} else {
    Invoke-StopHookStep -Name 'write-agent-remediation-plan' -CommandText 'missing optional planner script' -Optional -ScriptBlock {
        Write-Host 'Planner script is not available on this branch.'
    } | Out-Null
}

$feedback = Read-JsonFileSafe -Path $feedbackPath
$plan = Read-JsonFileSafe -Path $remediationPlanPath

$archivedFeedbackPath = $null
$archivedPlanPath = $null

if (Test-Path -LiteralPath $feedbackPath) {
    $archivedFeedbackPath = Join-Path $artifactDir 'BlacksmithGuild_AgentFeedback.json'
    Copy-Item -LiteralPath $feedbackPath -Destination $archivedFeedbackPath -Force
}

if (-not $SkipPlanner -and (Test-Path -LiteralPath $remediationPlanPath)) {
    $archivedPlanPath = Join-Path $artifactDir 'BlacksmithGuild_AgentRemediationPlan.json'
    Copy-Item -LiteralPath $remediationPlanPath -Destination $archivedPlanPath -Force
}

if ($feedback -and $feedback.classification) {
    $classification = [ordered]@{
        state = [string]$feedback.classification.state
        confidence = [string]$feedback.classification.confidence
        reason = [string]$feedback.classification.reason
    }
} else {
    $classificationState = 'unclassified'
    $feedbackStep = $stepResults | Where-Object { $_.name -eq 'write-agent-feedback-summary' } | Select-Object -First 1
    if ($feedbackStep -and -not $feedbackStep.ok) {
        $classificationState = 'contract_fail'
    }

    $classification = [ordered]@{
        state = $classificationState
        confidence = 'low'
        reason = 'Agent feedback file was not available or could not be parsed.'
    }
}

$failedSteps = @($stepResults | Where-Object { -not $_.ok })
$blockingClassificationStates = @('runtime_blocked', 'unsafe_surface', 'contract_fail')
$blocking = ($failedSteps.Count -gt 0 -or $blockingClassificationStates -contains $classification.state)

$patchCandidateCount = 0
if ($plan -and $plan.patchCandidates) {
    $patchCandidateCount = @($plan.patchCandidates).Count
}

$nextAction = 'Read AgentStopHookSummary.json, then inspect AgentFeedback and remediation plan before choosing the next bounded sprint.'
if ($feedback -and $feedback.nextSprint -and $feedback.nextSprint.title) {
    $nextAction = [string]$feedback.nextSprint.title
} elseif ($patchCandidateCount -gt 0) {
    $nextAction = 'Inspect remediation plan patch candidates before inventing a separate fix.'
}

$summaryPath = Join-Path $artifactDir 'AgentStopHookSummary.json'
$summary = [pscustomobject][ordered]@{
    schema = 'TbgAgentStopHookSummary.v1'
    generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    artifactDir = (Convert-ToRepoRelativePath -Path $artifactDir)
    classification = $classification
    blocking = [bool]$blocking
    failedSteps = @($failedSteps)
    feedbackPath = (Convert-ToRepoRelativePath -Path $archivedFeedbackPath)
    remediationPlanPath = (Convert-ToRepoRelativePath -Path $archivedPlanPath)
    patchCandidateCount = [int]$patchCandidateCount
    nextAction = $nextAction
    requiredAgentReport = @(
        'branch',
        'head SHA',
        'classification',
        'allowed claims',
        'forbidden claims',
        'blockers',
        'remediation plan path',
        'next action',
        'validation commands'
    )
}

$summary | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

Write-Host ''
Write-Host ('AgentStopHook classification: {0} confidence={1}' -f $classification.state, $classification.confidence) -ForegroundColor Cyan
Write-Host ('Blocking: {0}' -f $blocking) -ForegroundColor Cyan
Write-Host ('Failed steps: {0}' -f $failedSteps.Count) -ForegroundColor Cyan
Write-Host ('Patch candidates: {0}' -f $patchCandidateCount) -ForegroundColor Cyan
Write-Host ('Summary: {0}' -f (Convert-ToRepoRelativePath -Path $summaryPath)) -ForegroundColor Green
Write-Host ('Next action: {0}' -f $nextAction) -ForegroundColor Cyan

if ($blocking -and $FailOnBlocking) {
    exit 1
}

exit 0
