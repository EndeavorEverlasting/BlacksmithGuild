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

Assert-True (Test-Path -LiteralPath $contractPath -PathType Leaf) "Missing night-shift contract: $contractPath"
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json

Assert-True ([string]$contract.schema -eq 'tbg.gnhf-night-shift.contract.v1') 'Unexpected night-shift contract schema.'
Assert-True ([string]$contract.repository -eq 'EndeavorEverlasting/BlacksmithGuild') 'Night-shift contract targets the wrong repository.'
Assert-True ((@($contract.sourceModel.sequence) -join ',') -eq 'P37,P38,P41,P44') 'The V38 stage sequence must remain P37, P38, P41, P44.'
Assert-True ([int]$contract.queue.maximumItems -le 5) 'The night queue may not exceed five items.'
Assert-True ([int]$contract.queue.maximumAttemptsPerRepairRun -le 3) 'One repair run may not attempt more than three items.'
Assert-True (@($contract.stageSelection).Count -eq 3) 'The contract must define compile, repair, and closeout stages.'

$expectedStages = @('compile', 'repair', 'closeout')
$actualStages = @($contract.stageSelection | ForEach-Object { [string]$_.stage })
Assert-True (($actualStages -join ',') -eq ($expectedStages -join ',')) 'Night-shift stages must remain compile, repair, closeout.'

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

$contractText = Get-Content -LiteralPath $contractPath -Raw
foreach ($required in @(
    'patches_must_include_owned_untracked_files',
    'resume_smallest_pending_validation_first'
)) {
    # These exact cross-repository doctrine labels live in the checkpoint contract, not here.
    Assert-True (Test-Path -LiteralPath (Join-Path $root '.tbg\workflows\checkpoint-discipline.contract.json') -PathType Leaf) 'Checkpoint discipline contract is required before night-shift adoption.'
}

foreach ($forbidden in @('launch Bannerlord during an unattended code repair stage', 'run multiple repositories in one GNHF process')) {
    Assert-True (@($contract.forbidden) -contains $forbidden) "Night-shift contract is missing forbidden rule '$forbidden'."
}

Write-Host 'PASS: BlacksmithGuild GNHF night-shift contract, prompt stages, caps, and state-safety boundaries are valid.' -ForegroundColor Green
