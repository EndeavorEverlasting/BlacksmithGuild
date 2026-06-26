# Offline regression: C# runtime checkpoint/user-message surface.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

function Require-Needle {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Needle
    )
    $text = Get-Content -LiteralPath $Path -Raw
    if ($text -notmatch [regex]::Escape($Needle)) {
        throw "$Path missing needle: $Needle"
    }
}

$automationDir = Join-Path $repoRoot 'src\BlacksmithGuild\DevTools\Automation'
$eventPath = Join-Path $automationDir 'AutomationCheckpointEvent.cs'
$writerPath = Join-Path $automationDir 'AutomationCheckpointEventWriter.cs'
$messagePath = Join-Path $automationDir 'AutomationUserMessageService.cs'
$previousPath = Join-Path $automationDir 'AutomationPreviousRunNotice.cs'

foreach ($path in @($eventPath, $writerPath, $messagePath, $previousPath)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "missing automation C# file: $path" }
}

foreach ($needle in @(
    'BlacksmithGuild_AutomationEvents.jsonl',
    'checkpoint_reached',
    'finalization_started',
    'finalized_pass',
    'finalized_fail',
    'finalized_abort',
    'previous_run_terminal_notice',
    'messageShownInGame',
    'messageText')) {
    Require-Needle -Path $eventPath -Needle $needle
}

Require-Needle -Path $writerPath -Needle 'File.AppendAllText'
Require-Needle -Path $writerPath -Needle 'Encoding.UTF8'
Require-Needle -Path $writerPath -Needle 'Escape'

Require-Needle -Path $messagePath -Needle 'InGameNotice.Info'
Require-Needle -Path $messagePath -Needle 'InGameNotice.Success'
Require-Needle -Path $messagePath -Needle 'InGameNotice.Fail'
Require-Needle -Path $messagePath -Needle 'throttleSeconds'
Require-Needle -Path $messagePath -Needle 'AutomationCheckpointEventWriter.Append'

Require-Needle -Path $previousPath -Needle 'IsTerminalLine'
Require-Needle -Path $previousPath -Needle 'relatedEventId'
Require-Needle -Path $previousPath -Needle 'Previous automation run ended'

Require-Needle -Path (Join-Path $repoRoot 'src\BlacksmithGuild\SubModule.cs') -Needle 'AutomationPreviousRunNotice.TryShow'
Require-Needle -Path (Join-Path $repoRoot 'src\BlacksmithGuild\DevTools\RuntimeLifecycleWriter.cs') -Needle 'RuntimeLifecycleConsumed'
Require-Needle -Path (Join-Path $repoRoot 'src\BlacksmithGuild\ForgeStatus.cs') -Needle 'StateMachineConsumed'
Require-Needle -Path (Join-Path $repoRoot 'src\BlacksmithGuild\DevTools\Assistive\AssistReadinessEvaluator.cs') -Needle 'AttachReady'
Require-Needle -Path (Join-Path $repoRoot 'src\BlacksmithGuild\DevTools\DevCommandFileInbox.cs') -Needle 'ProbeAck'
Require-Needle -Path (Join-Path $repoRoot 'src\BlacksmithGuild\DevTools\DevCommandFileInbox.cs') -Needle 'ExecuteAck'
Require-Needle -Path (Join-Path $repoRoot 'src\BlacksmithGuild\DevTools\Assistive\AssistiveTravelEvidenceWriter.cs') -Needle 'PartyMovementObserved'

Write-Host 'PASS runtime user message event surface' -ForegroundColor Green
exit 0
