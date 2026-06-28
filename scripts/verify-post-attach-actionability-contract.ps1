# Offline contract verifier for post-attach actionability and visible-movement proof modes.
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]

function Read-RepoText {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        $failures.Add("missing file: $RelativePath") | Out-Null
        return ''
    }
    return Get-Content -LiteralPath $path -Raw
}

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Needle,
        [string]$Why = ''
    )
    $text = Read-RepoText -RelativePath $RelativePath
    if ($text.IndexOf($Needle, [System.StringComparison]::Ordinal) -lt 0) {
        $suffix = if ($Why) { " ($Why)" } else { '' }
        $failures.Add("$RelativePath missing '$Needle'$suffix") | Out-Null
    }
}

function Assert-NotContains {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Needle,
        [string]$Why = ''
    )
    $text = Read-RepoText -RelativePath $RelativePath
    if ($text.IndexOf($Needle, [System.StringComparison]::Ordinal) -ge 0) {
        $suffix = if ($Why) { " ($Why)" } else { '' }
        $failures.Add("$RelativePath must not contain '$Needle'$suffix") | Out-Null
    }
}

# Source/script/doc files that must exist.
foreach ($file in @(
    'scripts\run-autonomous-assist-session.ps1',
    'scripts\autonomous-assist-session.ps1',
    'docs\operator\governor-test-harness.md'
)) {
    Read-RepoText -RelativePath $file | Out-Null
}

# Proof-mode vocabulary must be defined in the operator doc.
foreach ($mode in @('read_only_runtime_proof', 'attach_readiness_proof', 'visible_mechanics_proof')) {
    Assert-Contains 'docs\operator\governor-test-harness.md' $mode "proof mode '$mode' must be documented"
}
Assert-Contains 'docs\operator\governor-test-harness.md' 'Proof modes' 'operator doc must have a Proof modes section'
Assert-Contains 'docs\operator\governor-test-harness.md' 'verify-post-attach-actionability-contract.ps1' 'doc must reference this verifier'

# Runner must stamp the achieved proof mode and a movement-proven boolean on the summary.
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' 'proofMode = $proofMode' 'summary must include proofMode'
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' 'visibleMechanicsProven = $visibleMechanicsProven' 'summary must include visibleMechanicsProven'

# visible_mechanics_proof must require a real observed movement delta, never attach/route intent alone.
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' '$visibleMechanicsProven = [bool]$partyMovementCheckpointEmitted' 'visible proof gated on observed party movement'
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' "if (`$visibleMechanicsProven) { 'visible_mechanics_proof' }" 'visible mode requires movement-proven flag'

# Lane F: the party_movement_observed checkpoint that promotes a run to visible_mechanics_proof must be
# emitted only from a real, positive partyMovedDistance read off the assistive travel execution evidence
# (after command ack + clock resume), never from route intent or a destination assignment alone.
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' 'Get-AssistiveTravelExecutionJsonPath' 'visible proof must read assistive travel execution evidence'
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' '$execJson.partyMovedDistance' 'visible proof must read partyMovedDistance from execution evidence'
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' 'if ($partyMovedDistance -gt 0) {' 'movement checkpoint must require a positive party-movement delta'
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' "-CheckpointName 'party_movement_observed'" 'positive delta must emit the party_movement_observed checkpoint'
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' '$partyMovementCheckpointEmitted = $true' 'positive delta must set the movement-proven flag'

# Lane C: every poll cycle must be classified (no silent/unclassified polling) with safe-idle vocabulary.
Assert-Contains 'scripts\autonomous-assist-session.ps1' 'function Get-AutonomousAssistSafeIdleClass' 'safe-idle classifier must exist'
foreach ($idle in @('safe_idle_no_branch_progress', 'safe_idle_execute_not_requested', 'safe_idle_observe_route', 'safe_idle_waiting')) {
    Assert-Contains 'scripts\autonomous-assist-session.ps1' $idle "safe-idle class '$idle' must be defined"
}
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' 'Get-AutonomousAssistSafeIdleClass -Decision $decision' 'loop must classify each cycle'
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' 'safeIdleClass = $safeIdleClass' 'iteration event must record safe-idle class'
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' 'consecutiveSafeIdle=' 'loop must log consecutive safe-idle diagnostic'
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' 'operator_interruption_foreground_lost' 'runner must stop on sustained user foreground loss/interruption'
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' 'Get-F7ForegroundWindowInfo' 'runner must inspect foreground window during assist loop'
Assert-Contains 'scripts\autonomous-assist-session.ps1' 'operatorInterruptionObserved' 'decision policy must consume regent/runtime interruption truth'
Assert-Contains 'scripts\pr11-runtime-state-consumer.ps1' 'Read-Pr11RuntimeRegent' 'runtime consumer must read runtime regent sidecar'

# Lane D: a single shared clock-resume helper must own TimeControlMode and be reused by every movement
# driver so no driver can issue a travel command while leaving the campaign clock stopped.
Assert-Contains 'src\BlacksmithGuild\DevTools\ClockResumeHelper.cs' 'class CampaignClockResumeHelper' 'shared clock-resume helper must exist'
Assert-Contains 'src\BlacksmithGuild\DevTools\ClockResumeHelper.cs' 'public static bool EnsureClockRunning(string caller)' 'helper must expose EnsureClockRunning(caller)'
Assert-Contains 'src\BlacksmithGuild\DevTools\AutoTravelService.cs' 'CampaignClockResumeHelper.EnsureClockRunning("AutoTravelService")' 'golden path must route clock resume through shared helper'
Assert-Contains 'src\BlacksmithGuild\DevTools\CampaignMapMovementHelper.cs' 'CampaignClockResumeHelper.EnsureClockRunning("CampaignMapMovementHelper")' 'shared low-level mover must resume clock on successful travel'
Assert-Contains 'scripts\automation-checkpoint-contract.ps1' 'campaign_clock_resume_ack' 'clock-resume ACK must be a valid checkpoint, not a runner failure'
Assert-Contains 'src\BlacksmithGuild\ForgeStatus.cs' 'CampaignRuntimeRegent.Write(CampaignRuntimeRegent.BuildSnapshot(snapshot))' 'status flush must emit runtime regent sidecar for governance consumption'

# Lane E: focus policy must default to respecting the user foreground; aggressive focus-steal must be
# an explicit opt-in (-AllowFocusSteal) rather than an automatic escalation.
Assert-Contains 'scripts\launcher-auto-nav.ps1' '[switch]$AllowFocusSteal' 'launcher must expose -AllowFocusSteal switch'
Assert-Contains 'scripts\launcher-auto-nav.ps1' 'play_escalate_suppressed' 'launcher must log focus-steal suppression by policy'
Assert-Contains 'scripts\launcher-auto-nav.ps1' 'continue_escalate_suppressed' 'launcher must log focus-steal suppression by policy'
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' '[switch]$AllowFocusSteal' 'assist runner must expose -AllowFocusSteal switch'
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' '-RespectUserForeground:(-not $AllowFocusSteal)' 'assist runner must respect foreground unless focus-steal opted in'
Assert-NotContains 'scripts\run-autonomous-assist-session.ps1' '-CertTarget' 'assist runner must keep launcher nav in assistive launch-setup mode, not continue cert mode'
Assert-Contains 'scripts\autonomous-assist-session.ps1' '[bool]$RespectUserForeground = $true' 'child nav default must respect user foreground'

if ($failures.Count -gt 0) {
    Write-Host "FAIL: post-attach actionability contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: post-attach actionability contract verified.' -ForegroundColor Green
exit 0
