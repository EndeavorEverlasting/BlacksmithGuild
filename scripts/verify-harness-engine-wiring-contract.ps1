# Read-only verifier for harness to engine wiring contracts.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]

function Read-Text($RelativePath) {
    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) { $failures.Add("missing file: $RelativePath") | Out-Null; return '' }
    return Get-Content -LiteralPath $path -Raw
}
function Assert-Contains($RelativePath, $Needle, $Why = '') {
    $text = Read-Text $RelativePath
    if ($text.IndexOf($Needle, [System.StringComparison]::Ordinal) -lt 0) { $failures.Add("$RelativePath missing '$Needle' $Why") | Out-Null }
}
function Assert-NotContains($RelativePath, $Needle, $Why = '') {
    $text = Read-Text $RelativePath
    if ($text.IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $failures.Add("$RelativePath must not contain '$Needle' $Why") | Out-Null }
}

$docPath = 'docs\operator\harness-engine-wiring.md'
$manifestPath = 'docs\handoff\harness-engine-wiring.manifest.json'
Read-Text $docPath | Out-Null
$manifestRaw = Read-Text $manifestPath
$manifest = $null
try { $manifest = $manifestRaw | ConvertFrom-Json } catch { $failures.Add("manifest does not parse as JSON: $($_.Exception.Message)") | Out-Null }

if ($manifest) {
    if ([int]$manifest.normalActionTimeoutSec -gt 30) { $failures.Add('normalActionTimeoutSec must be <= 30') | Out-Null }
    $ids = @($manifest.contracts | ForEach-Object { [string]$_.contractId })
    foreach ($id in @(
        'cmd.forge_reboot.entrypoint', 'cmd.forge_stop.operator_stop', 'reboot.ctrl_c_operator_stop',
        'regent.operator_interruption', 'recursive_branch.travel_target', 'runner.engine_target_resolution',
        'assistive_travel.command_ack', 'assistive_travel.movement_proof', 'runner.foreground_loss', 'reboot.repeat_context'
    )) { if ($ids -notcontains $id) { $failures.Add("manifest missing contractId $id") | Out-Null } }
    $movement = @($manifest.contracts | Where-Object { $_.contractId -eq 'assistive_travel.movement_proof' } | Select-Object -First 1)
    if (-not $movement -or [string]$movement.proofRequired -notmatch 'durable checkpoint evidence') { $failures.Add('movement proof contract must require checkpoint-based durable evidence') | Out-Null }
}

foreach ($needle in @('long-distance travel', 'smithing with a large party', 'massive trade operations', 'Normal action timeout: 30 seconds')) {
    Assert-Contains $docPath $needle 'timeout doctrine must be documented'
}

Assert-Contains 'ForgeReboot.cmd' 'scripts\run-reboot-iteration.ps1'
Assert-Contains 'ForgeReboot.cmd' '%*' 'must forward script args for local/test invocation'
Assert-Contains 'ForgeReboot.cmd' 'FORGE_NO_PAUSE' 'must support noninteractive contract tests'
Assert-Contains 'ForgeReboot.cmd' 'stable-gap-handoff.md' 'stable gap is a useful result, not generic failure'
Assert-Contains 'ForgeStop.cmd' 'FORGE_STOP_CHOICE' 'must support noninteractive stop tests'
Assert-Contains 'ForgeStop.cmd' '"%~1"=="force"' 'must allow scripted force path'
Assert-Contains 'scripts\forge-stop.ps1' 'run-reboot-iteration' 'ForgeStop must include reboot shell cleanup'
Assert-Contains 'scripts\forge-stop.ps1' 'run-autonomous-assist-session' 'ForgeStop must include assist runner cleanup'

Assert-Contains 'scripts\run-reboot-iteration.ps1' 'Test-GovernorStopRequested' 'reboot runner must consume ForgeStop sentinel'
Assert-Contains 'scripts\run-reboot-iteration.ps1' 'ConsoleCancelEventHandler' 'reboot runner must classify Ctrl+C'
Assert-Contains 'scripts\run-reboot-iteration.ps1' 'operatorStopRequested' 'summary must expose operator stop'
Assert-Contains 'scripts\run-reboot-iteration.ps1' 'operator_stop_ctrl_c' 'Ctrl+C class must be explicit'
Assert-Contains 'scripts\run-reboot-iteration.ps1' 'operator_stop_forge_stop' 'ForgeStop class must be explicit'
Assert-Contains 'scripts\run-reboot-iteration.ps1' '[int]$NormalActionTimeoutSec = 30'
Assert-Contains 'scripts\run-reboot-iteration.ps1' 'LongTravelTimeoutSec'
Assert-Contains 'scripts\run-reboot-iteration.ps1' 'LargeSmithingTimeoutSec'
Assert-Contains 'scripts\run-reboot-iteration.ps1' 'MassTradeTimeoutSec'

Assert-Contains 'scripts\run-autonomous-assist-session.ps1' 'Get-AutonomousAssistEngineTravelTarget'
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' "source = 'missing_engine_handoff_target'"
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' 'resolvedTravelTargetSource = $targetResolution.source'
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' 'operator_interruption_foreground_lost'
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' 'movementProofClassification = $latestMovementUpdate.movementProofClassification'
Assert-Contains 'scripts\autonomous-assist-session.ps1' 'function Test-AutonomousAssistDurableMovementObserved'
Assert-Contains 'scripts\autonomous-assist-session.ps1' "-CheckpointName 'party_movement_observed'"
Assert-Contains 'src\BlacksmithGuild\DevTools\Assistive\MovementProofLedger.cs' 'enum MovementProofClassification'
Assert-Contains 'src\BlacksmithGuild\DevTools\Assistive\MovementProofLedgerService.cs' 'class MovementProofLedgerService'
Assert-Contains 'src\BlacksmithGuild\DevTools\Assistive\MovementProofLedgerService.cs' 'BlacksmithGuild_MovementProof.json'
Assert-Contains 'scripts\pr11-runtime-state-consumer.ps1' 'Read-Pr11RuntimeRegent'
Assert-Contains 'scripts\pr11-runtime-state-consumer.ps1' 'operatorInterruptionObserved'
Assert-Contains 'src\BlacksmithGuild\DevTools\RecursiveCampaignBranchState.cs' 'targetSettlement'
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRuntimeRegent.cs' 'OperatorInterruptionObserved'
Assert-NotContains 'scripts\run-autonomous-assist-session.ps1' "TargetSettlement = 'Ortysia'"
Assert-NotContains 'scripts\run-autonomous-assist-session.ps1' 'TargetSettlement = "Ortysia"'

Assert-Contains 'scripts\reboot-context-classifier.ps1' 'function Test-RebootContextRepeat'
Assert-Contains 'scripts\reboot-context-classifier.ps1' 'function Test-RebootDurableMovementObserved'
Assert-Contains 'scripts\reboot-context-classifier.ps1' 'stable_gap'

if ($failures.Count -gt 0) {
    Write-Host "FAIL: harness-engine wiring contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}
Write-Host 'PASS: harness-engine wiring contract verified.' -ForegroundColor Green
exit 0