[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True {
    param([bool]$Condition, [Parameter(Mandatory = $true)][string]$Message)
    if (-not $Condition) { throw $Message }
}

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$contractPath = Join-Path $root '.tbg\workflows\gnhf-night-shift.contract.json'
$checkpointPath = Join-Path $root '.tbg\workflows\checkpoint-discipline.contract.json'

Assert-True (Test-Path -LiteralPath $contractPath -PathType Leaf) "Missing night-shift contract: $contractPath"
Assert-True (Test-Path -LiteralPath $checkpointPath -PathType Leaf) 'Checkpoint discipline contract is required before night-shift adoption.'
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
$checkpointText = Get-Content -LiteralPath $checkpointPath -Raw

Assert-True ([string]$contract.schema -eq 'tbg.gnhf-night-shift.contract.v1') 'Unexpected night-shift contract schema.'
Assert-True ([string]$contract.repository -eq 'EndeavorEverlasting/BlacksmithGuild') 'Night-shift contract targets the wrong repository.'
Assert-True ((@($contract.sourceModel.sequence) -join ',') -eq 'P37,P38,P41,P44') 'The V38 stage sequence must remain P37, P38, P41, P44.'
Assert-True ([int]$contract.queue.maximumItems -le 5) 'The night queue may not exceed five items.'
Assert-True ([int]$contract.queue.maximumAttemptsPerRepairRun -le 3) 'One repair run may not attempt more than three items.'
Assert-True (@($contract.stageSelection).Count -eq 4) 'The contract must define night, compile, repair, and closeout stages.'

$expectedStages = @('night', 'compile', 'repair', 'closeout')
$actualStages = @($contract.stageSelection | ForEach-Object { [string]$_.stage })
Assert-True (($actualStages -join ',') -eq ($expectedStages -join ',')) 'Night-shift stages must remain night, compile, repair, closeout.'

foreach ($stage in @($contract.stageSelection)) {
    Assert-True ([int]$stage.maxIterations -gt 0) "Stage '$($stage.stage)' requires a positive iteration cap."
    Assert-True ([int]$stage.maxTokens -gt 0) "Stage '$($stage.stage)' requires a positive token cap."
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$stage.stopWhen)) "Stage '$($stage.stage)' requires an observable stop condition."

    $promptPath = Join-Path $root (([string]$stage.promptPath) -replace '/', [IO.Path]::DirectorySeparatorChar)
    Assert-True (Test-Path -LiteralPath $promptPath -PathType Leaf) "Missing stage prompt: $($stage.promptPath)"
    $prompt = Get-Content -LiteralPath $promptPath -Raw

    foreach ($required in @('Repo:', 'Sprint:', 'Lane:', 'Owned scope:', 'Forbidden scope:', 'Objective:', 'Validation:', 'Proof ceiling:')) {
        Assert-True ($prompt.Contains($required)) "Prompt '$($stage.promptPath)' is missing '$required'."
    }

    Assert-True ($prompt -notmatch '(?im)^\s*gnhf\s') "Prompt '$($stage.promptPath)' must remain an objective payload; AgentSwitchboard owns launch flags."
    Assert-True ($prompt -notmatch '(?i)--push|force-push|reset --hard|git clean') "Prompt '$($stage.promptPath)' contains a forbidden destructive or automatic-push instruction."
}

$nightStage = @($contract.stageSelection | Where-Object { [string]$_.stage -eq 'night' } | Select-Object -First 1)
Assert-True ($nightStage.Count -eq 1) 'The one-click night stage is missing.'
$nightPromptPath = Join-Path $root (([string]$nightStage[0].promptPath) -replace '/', [IO.Path]::DirectorySeparatorChar)
$nightPrompt = Get-Content -LiteralPath $nightPromptPath -Raw
foreach ($required in @(
    'P38 queue checkpoint',
    'commit this queue/report checkpoint before repairing code',
    'P41 state-safe repair',
    'one coherent commit per completed or evidence-blocked item',
    'P44 closeout',
    'Do not start another queue item',
    'P37 spawn proof is owned by AgentSwitchboard'
)) {
    Assert-True ($nightPrompt.Contains($required)) "The one-click night prompt is missing ordered-chain rule '$required'."
}
Assert-True ([int]$nightStage[0].maxIterations -le 10) 'The one-click night stage exceeds the V38 overnight iteration ceiling.'
Assert-True ([int]$nightStage[0].maxTokens -le 1000000) 'The one-click night stage exceeds the bounded token ceiling.'

foreach ($required in @('patches_must_include_owned_untracked_files', 'resume_smallest_pending_validation_first')) {
    Assert-True ($checkpointText.Contains($required)) "Checkpoint discipline contract is missing '$required'."
}

foreach ($forbidden in @('launch Bannerlord during an unattended code repair stage', 'run multiple repositories in one GNHF process')) {
    Assert-True (@($contract.forbidden) -contains $forbidden) "Night-shift contract is missing forbidden rule '$forbidden'."
}

Write-Host 'PASS: BlacksmithGuild GNHF night shift performs the V38 queue, repair, and closeout chain in one bounded worktree process.' -ForegroundColor Green
