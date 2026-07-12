[CmdletBinding()]
param(
    [ValidateSet('0', 'A', 'B', 'C', 'D1', 'D2', 'D3', 'E', 'F', 'all')]
    [string]$Wave = '0',
    [ValidateRange(0, 999999)]
    [int]$PrNumber = 0,
    [string]$PlanPath = '.tbg/plans/stale-pr-recovery-20260712/manifest.json',
    [string]$OutputDirectory = 'artifacts/latest/stale-pr-recovery',
    [switch]$LocalFloorVerified
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-TbgValue {
    param([AllowNull()][object]$Object, [Parameter(Mandatory = $true)][string]$Name, [AllowNull()][object]$Default = $null)
    if ($null -eq $Object) { return $Default }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { return $Default }
    return $property.Value
}

function ConvertTo-TbgWords {
    param([AllowNull()][object]$Value)
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return 'unspecified' }
    return (($text -replace '[_-]+', ' ') -replace '\s+', ' ').Trim()
}

function ConvertTo-TbgQuotedList {
    param([AllowNull()][object[]]$Values)
    $items = @($Values | ForEach-Object { "'$_'" })
    if ($items.Count -eq 0) { return 'no named items' }
    if ($items.Count -eq 1) { return $items[0] }
    return (($items[0..($items.Count - 2)] -join ', ') + ', and ' + $items[-1])
}

function Add-TbgInstruction {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$List,
        [Parameter(Mandatory = $true)][string]$Stage,
        [Parameter(Mandatory = $true)][string]$Subject,
        [Parameter(Mandatory = $true)][string]$Verb,
        [Parameter(Mandatory = $true)][string]$Object,
        [string]$Condition = '',
        [string]$Evidence = '',
        [string]$Command = '',
        [Parameter(Mandatory = $true)][string]$Sentence
    )

    $completeSentence = $Sentence.Trim()
    if ($completeSentence -notmatch '[.!?]$') { $completeSentence += '.' }
    $List.Add([pscustomobject][ordered]@{
        schema = 'TbgSyntacticEnglishInstruction.v1'
        sequence = $List.Count + 1
        stage = $Stage
        subject = $Subject
        verb = $Verb
        object = $Object
        condition = $Condition
        evidence = $Evidence
        command = $Command
        sentence = $completeSentence
    })
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$resolvedPlanPath = if ([System.IO.Path]::IsPathRooted($PlanPath)) { $PlanPath } else { Join-Path $repoRoot $PlanPath }
$contractRelative = '.tbg/workflows/stale-pr-recovery-automation.contract.json'
$contractPath = Join-Path $repoRoot $contractRelative
if (-not (Test-Path -LiteralPath $resolvedPlanPath -PathType Leaf)) { throw "The stale PR recovery plan is missing: $resolvedPlanPath" }
if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) { throw "The stale PR recovery automation contract is missing: $contractPath" }

$plan = Get-Content -LiteralPath $resolvedPlanPath -Raw | ConvertFrom-Json
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
$allWaves = @($plan.waves)
$allEntries = @($plan.entries)
$selectedWaves = @()
$selectedEntries = @()

if ($PrNumber -gt 0) {
    $selectedEntries = @($allEntries | Where-Object { [int]$_.pr -eq $PrNumber })
    $selectedWaves = @($allWaves | Where-Object { @($_.targets) -contains $PrNumber })
}
elseif ($Wave -eq 'all') {
    $selectedWaves = $allWaves
    $selectedEntries = $allEntries
}
else {
    $selectedWaves = @($allWaves | Where-Object { [string]$_.id -eq $Wave })
    $targetNumbers = @($selectedWaves | ForEach-Object { @($_.targets) })
    $selectedEntries = @($allEntries | Where-Object { $targetNumbers -contains [int]$_.pr })
}

$selectedLabel = if ($PrNumber -gt 0) { "PR #$PrNumber" } elseif ($Wave -eq 'all') { 'all recovery waves' } else { "Wave $Wave" }
$instructions = New-Object System.Collections.Generic.List[object]
Add-TbgInstruction -List $instructions -Stage 'request' -Subject 'The stale PR recovery harness' -Verb 'must render' -Object $selectedLabel -Condition 'before any recovery agent changes a source branch' -Evidence $PlanPath -Command ".\ForgeStalePrRecovery.cmd -Wave $Wave" -Sentence "The stale PR recovery harness must render $selectedLabel from '$PlanPath' before any recovery agent changes a source branch."

foreach ($command in @($plan.localProof.commands)) {
    Add-TbgInstruction -List $instructions -Stage 'evidence' -Subject 'The coordinator' -Verb 'must run' -Object ([string]$command) -Condition 'before the local floor can be marked verified' -Evidence 'the command output must identify the current repository state' -Command ([string]$command) -Sentence "The coordinator must run '$command' before the local floor can be marked verified, and the coordinator must retain the command output as repository-state evidence."
}

Add-TbgInstruction -List $instructions -Stage 'action' -Subject 'The coordinator' -Verb 'must preserve' -Object 'the primary checkout and every attached evidence worktree' -Condition 'when status, conflict, operation, ownership, or retention evidence is unresolved' -Evidence 'the repository hygiene report and worktree inventory' -Sentence 'The coordinator must preserve the primary checkout and every attached evidence worktree when status, conflict, operation, ownership, or retention evidence is unresolved.'

if ($selectedWaves.Count -eq 0 -and $PrNumber -gt 0) {
    Add-TbgInstruction -List $instructions -Stage 'bounded_plan' -Subject 'The coordinator' -Verb 'must block' -Object "PR #$PrNumber" -Condition 'because the committed recovery plan does not contain that pull request' -Evidence $PlanPath -Sentence "The coordinator must block PR #$PrNumber because the committed recovery plan does not contain that pull request."
}
else {
    foreach ($selectedWave in $selectedWaves) {
        $targets = @($selectedWave.targets)
        $targetText = if ($targets.Count -eq 0) { 'the local repository floor' } else { ($targets | ForEach-Object { "PR #$_" }) -join ', ' }
        $parallel = @(Get-TbgValue -Object $selectedWave -Name 'parallelWith' -Default @())
        $blockedBy = @(Get-TbgValue -Object $selectedWave -Name 'blockedBy' -Default @())
        $parallelSentence = if ($parallel.Count -gt 0) { " The wave may run beside Wave $($parallel -join ' and Wave ') only when each lane owns a separate worktree." } else { '' }
        $dependencySentence = if ($blockedBy.Count -gt 0) { " The coordinator must keep the wave blocked until PR $($blockedBy -join ' and PR ') receives a recorded disposition." } else { '' }
        Add-TbgInstruction -List $instructions -Stage 'bounded_plan' -Subject 'The coordinator' -Verb 'must bound' -Object "Wave $($selectedWave.id)" -Condition "to $targetText" -Evidence "wave name: $($selectedWave.name)" -Sentence "The coordinator must bound Wave $($selectedWave.id) to $targetText and must preserve the '$($selectedWave.name)' lane.$parallelSentence$dependencySentence"
    }
}

foreach ($entry in $selectedEntries) {
    $pr = [int]$entry.pr
    $sourceSha = [string]$entry.headSha
    $sourceBase = [string]$entry.base
    $classification = ConvertTo-TbgWords $entry.class
    $strategy = ConvertTo-TbgWords $entry.strategy
    $inspectCommand = "gh pr view $pr --json number,title,state,isDraft,mergeable,baseRefName,headRefName,headRefOid,commits,files,reviews,comments"
    Add-TbgInstruction -List $instructions -Stage 'action' -Subject "The PR #$pr recovery agent" -Verb 'must inspect' -Object "source head $sourceSha" -Condition "before it replays any value from base '$sourceBase'" -Evidence 'current pull-request metadata, changed paths, commits, reviews, and comments' -Command $inspectCommand -Sentence "The PR #$pr recovery agent must inspect source head '$sourceSha' and base '$sourceBase' before it replays any value, and the agent must record the current pull-request metadata, changed paths, commits, reviews, and comments."
    Add-TbgInstruction -List $instructions -Stage 'bounded_plan' -Subject "The PR #$pr recovery agent" -Verb 'must classify' -Object 'each commit, path, hunk, and useful comment' -Condition "before applying the $strategy strategy" -Evidence "classification: $classification; risk: $($entry.risk)" -Sentence "The PR #$pr recovery agent must classify each commit, path, hunk, and useful comment as keep, superseded, reject, owner review, or runtime proof before the agent applies the $strategy strategy."

    $usefulShas = @($entry.usefulShas)
    $actionCommand = if ([string]$entry.strategy -eq 'selective_path_replay' -and $usefulShas.Count -gt 0) { "git cherry-pick -x $($usefulShas[0])" } else { '' }
    $shaText = ConvertTo-TbgQuotedList $usefulShas
    Add-TbgInstruction -List $instructions -Stage 'action' -Subject "The PR #$pr recovery agent" -Verb 'may replay' -Object $shaText -Condition 'only after current-source comparison proves that the selected unit remains coherent' -Evidence 'the replacement commit must retain source PR and source SHA attribution' -Command $actionCommand -Sentence "The PR #$pr recovery agent may replay $shaText only after current-source comparison proves that the selected unit remains coherent, and the replacement commit must retain the source PR and source SHA attribution."

    foreach ($validator in @($entry.validators)) {
        Add-TbgInstruction -List $instructions -Stage 'validation' -Subject "The PR #$pr recovery agent" -Verb 'must complete' -Object ([string]$validator) -Condition 'before the replacement pull request can satisfy its current-context gate' -Evidence 'the validator output or an exact skipped-check record' -Command ([string]$validator) -Sentence "The PR #$pr recovery agent must complete '$validator' before the replacement pull request can satisfy its current-context gate, or the agent must record the skipped check and the exact later command."
    }
    Add-TbgInstruction -List $instructions -Stage 'next_decision' -Subject 'The coordinator' -Verb 'must retain' -Object "PR #$pr" -Condition ([string]$entry.gate) -Evidence 'a replacement pull request, a rejection record, or a historical-retention record' -Sentence "The coordinator must retain PR #$pr until this disposition gate is satisfied: $($entry.gate)"
}

Add-TbgInstruction -List $instructions -Stage 'validation' -Subject 'The harness validator' -Verb 'must compare' -Object 'the JSON instruction count, JSONL event count, progress-line count, and English report content' -Condition 'before the instruction packet can pass static validation' -Evidence 'matching counts and matching complete sentences' -Command '.\scripts\tbg\Test-TbgStalePrRecovery.ps1' -Sentence 'The harness validator must compare the JSON instruction count, JSONL event count, progress-line count, and English report content before the instruction packet can pass static validation.'

$outputRoot = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $repoRoot $OutputDirectory }
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
$resultPath = Join-Path $outputRoot 'stale-pr-recovery.result.json'
$reportPath = Join-Path $outputRoot 'stale-pr-recovery.report.md'
$eventsPath = Join-Path $outputRoot 'stale-pr-recovery.events.jsonl'
$progressPath = Join-Path $outputRoot 'stale-pr-recovery.progress.log'
$handoffPath = Join-Path $outputRoot 'stale-pr-recovery.handoff.md'
Add-TbgInstruction -List $instructions -Stage 'artifacts' -Subject 'The harness' -Verb 'must write' -Object 'the linked JSON result, English report, JSONL events, progress log, and handoff report' -Evidence 'all five files must describe the same selected wave and terminal state' -Sentence 'The harness must write the linked JSON result, English report, JSONL events, progress log, and handoff report, and all five files must describe the same selected wave and terminal state.'
Add-TbgInstruction -List $instructions -Stage 'report' -Subject 'The final report' -Verb 'must name' -Object 'the repository, branch, sprint, lane, scope, forbidden scope, changed files, artifacts, validation, skipped checks, gaps, risks, git state, next command, and next-agent paths' -Evidence 'the report must use complete English sentences before any raw JSON appendix' -Sentence 'The final report must name the repository, branch, sprint, lane, scope, forbidden scope, changed files, artifacts, validation, skipped checks, gaps, risks, git state, next command, and next-agent paths in complete English sentences.'

$selectedDependencies = @($selectedWaves | ForEach-Object { foreach ($dependency in @(Get-TbgValue -Object $_ -Name 'blockedBy' -Default @())) { $dependency } } | Select-Object -Unique)
$status = 'ready'
$verdict = 'READY'
$terminalState = 'READY_bounded_recovery_instruction'
$blockedReason = ''
$nextCommand = ''
if ($PrNumber -gt 0 -and $selectedEntries.Count -eq 0) {
    $status = 'blocked'; $verdict = 'BLOCKED'; $terminalState = 'BLOCKED_source_pr_not_in_plan'
    $blockedReason = "PR #$PrNumber is not present in the committed recovery plan."
    $nextCommand = "Get-Content -LiteralPath '$PlanPath' -Raw"
}
elseif ($selectedDependencies.Count -gt 0) {
    $status = 'blocked'; $verdict = 'BLOCKED'; $terminalState = 'BLOCKED_wave_dependency'
    $blockedReason = "The selected wave depends on PR $($selectedDependencies -join ' and PR ')."
    $nextCommand = "gh pr view $($selectedDependencies[0]) --json number,state,isDraft,mergeable,headRefOid,baseRefName"
}
elseif (-not $LocalFloorVerified -and $Wave -ne '0') {
    $status = 'blocked'; $verdict = 'BLOCKED'; $terminalState = 'BLOCKED_local_floor_unverified'
    $blockedReason = 'The local repository floor has not been verified.'
    $nextCommand = '.\ForgeRepoHygiene.cmd -NoGitHub -FailOnBlocked'
}
elseif ($Wave -eq '0') {
    $terminalState = 'READY_local_floor_collection'
    $nextCommand = '.\ForgeRepoHygiene.cmd -NoGitHub -FailOnBlocked'
}
else {
    $firstEntry = @($selectedEntries | Select-Object -First 1)
    $nextCommand = if ($firstEntry.Count -gt 0) { "gh pr view $([int]$firstEntry[0].pr) --json number,title,state,isDraft,mergeable,baseRefName,headRefName,headRefOid,commits,files,reviews,comments" } else { 'git status --short' }
}

Add-TbgInstruction -List $instructions -Stage 'next_decision' -Subject 'The coordinator' -Verb 'must execute' -Object $nextCommand -Condition "after reading terminal state '$terminalState'" -Evidence 'the next command must produce the evidence required for the following bounded decision' -Command $nextCommand -Sentence "The coordinator must execute '$nextCommand' after reading terminal state '$terminalState', and the coordinator must preserve the command output for the following bounded decision."

$artifactPaths = @($resultPath, $reportPath, $eventsPath, $progressPath, $handoffPath)
$resultDraft = [pscustomobject][ordered]@{
    schema = 'TbgStalePrRecoveryInstructionResult.v1'; profileId = [string]$contract.id; action = 'InvokeStalePrRecovery'
    generatedUtc = [DateTime]::UtcNow.ToString('o'); repository = [string]$plan.repository; planPath = $PlanPath
    selectedWave = $Wave; selectedPr = $PrNumber; localFloorVerified = [bool]$LocalFloorVerified
    status = $status; verdict = $verdict; terminalState = $terminalState; blockedReason = $blockedReason
    nextPatchHint = $nextCommand; selectedTargets = @($selectedEntries | ForEach-Object { [int]$_.pr })
    safeParallelWaves = @($selectedWaves | ForEach-Object { foreach ($parallel in @(Get-TbgValue -Object $_ -Name 'parallelWith' -Default @())) { $parallel } } | Select-Object -Unique)
    sourceFiles = @($PlanPath, $contractRelative); artifacts = $artifactPaths; instructions = @($instructions)
}

Import-Module (Join-Path $repoRoot 'scripts/harness/TbgEffectivePolicy.psm1') -Force
$effectivePolicy = Get-TbgEffectivePolicyContext -ProfileId ([string]$contract.id) -InputObject $resultDraft -RowType 'result' -RepoRoot $repoRoot
$policyEnglish = ConvertTo-TbgPolicyEnglish -Context $effectivePolicy
$summarySentence = if ($verdict -eq 'READY') { "The stale PR recovery harness prepared $($instructions.Count) bounded instructions for $selectedLabel and selected '$nextCommand' as the next command." } else { "The stale PR recovery harness blocked $selectedLabel because $blockedReason The harness selected '$nextCommand' as the next command." }
$result = [pscustomobject][ordered]@{
    schema = $resultDraft.schema; profileId = $resultDraft.profileId; action = $resultDraft.action; generatedUtc = $resultDraft.generatedUtc
    repository = $resultDraft.repository; planPath = $resultDraft.planPath; selectedWave = $Wave; selectedPr = $PrNumber
    localFloorVerified = [bool]$LocalFloorVerified; status = $status; verdict = $verdict; terminalState = $terminalState
    blockedReason = $blockedReason; nextCommand = $nextCommand; selectedTargets = $resultDraft.selectedTargets
    safeParallelWaves = $resultDraft.safeParallelWaves; effectivePolicy = $effectivePolicy
    englishSummary = "$policyEnglish $summarySentence"; sourceFiles = $resultDraft.sourceFiles; artifacts = $artifactPaths
    instructions = @($instructions)
}

$result | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $resultPath -Encoding UTF8
@($instructions | ForEach-Object { $_ | ConvertTo-Json -Depth 10 -Compress }) | Set-Content -LiteralPath $eventsPath -Encoding UTF8
@($instructions | ForEach-Object { $_.sentence }) | Set-Content -LiteralPath $progressPath -Encoding UTF8

$report = New-Object System.Collections.Generic.List[string]
$report.Add('# Stale PR recovery instruction report'); $report.Add(''); $report.Add($result.englishSummary); $report.Add('')
$report.Add("The repository is '$($result.repository)'."); $report.Add("The harness selected '$selectedLabel' and reached terminal state '$terminalState'.")
if (-not [string]::IsNullOrWhiteSpace($blockedReason)) { $report.Add("The harness is blocked because $blockedReason") }
$report.Add("The next command is '$nextCommand'."); $report.Add(''); $report.Add('## Ordered instructions')
foreach ($instruction in $instructions) {
    $report.Add(''); $report.Add("$($instruction.sequence). $($instruction.sentence)")
    if (-not [string]::IsNullOrWhiteSpace([string]$instruction.command)) { $report.Add(''); $report.Add('```text'); $report.Add([string]$instruction.command); $report.Add('```') }
}
$report.Add(''); $report.Add('## Proof boundary'); $report.Add('')
$report.Add('This report proves that the committed plan was parsed and rendered as deterministic instructions. This report does not prove that a cherry-pick, build, launcher action, gameplay behavior, pull-request closure, or runtime action occurred.')
$report | Set-Content -LiteralPath $reportPath -Encoding UTF8

$handoff = @(
    '# Stale PR recovery handoff', '',
    "The next agent must inspect '$PlanPath' and '$contractRelative'.",
    "The next agent must treat '$terminalState' as the current terminal state.",
    "The next agent must run '$nextCommand' and preserve its output.",
    'The next agent must not close a stale pull request, delete a branch or worktree, or reuse historical evidence as current proof.',
    "The next agent must inspect '$resultPath', '$reportPath', '$eventsPath', and '$progressPath'."
)
$handoff | Set-Content -LiteralPath $handoffPath -Encoding UTF8
Write-Output ($result | ConvertTo-Json -Depth 30)
