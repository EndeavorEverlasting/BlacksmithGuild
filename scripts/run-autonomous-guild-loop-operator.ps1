# Crash-aware, user-facing wrapper for RunAutonomousGuildLoopNow.
# This script is intentionally not a certification harness. It exists so the
# click-first operator path records what happened when Bannerlord disappears,
# pauses, or never consumes the inbox command.

param(
    [int]$TimeoutSec = 60,
    [int]$PollMs = 500
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'forge-status.ps1')

$commandName = 'RunAutonomousGuildLoopNow'
$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot
$docsRoot = Join-Path $env:USERPROFILE 'Documents\Mount and Blade II Bannerlord'
$latestDir = Join-Path $repoRoot 'artifacts\latest'
New-Item -ItemType Directory -Force -Path $latestDir | Out-Null

$resultPath = Join-Path $latestDir 'autonomous-guild-loop-operator.json'
$reportPath = Join-Path $latestDir 'autonomous-guild-loop-operator.md'
$inboxPath = Join-Path $bannerlordRoot 'BlacksmithGuild_CommandInbox.json'
$ackPath = Join-Path $bannerlordRoot 'BlacksmithGuild_CommandAck.json'
$statusCandidates = @(
    (Join-Path $bannerlordRoot 'BlacksmithGuild_Status.json'),
    (Join-Path $docsRoot 'BlacksmithGuild_Status.json')
)
$phaseCandidates = @(
    (Join-Path $bannerlordRoot 'BlacksmithGuild_Phase1.log'),
    (Join-Path $docsRoot 'BlacksmithGuild_Phase1.log')
)
$guildLoopCandidates = @(
    (Join-Path $bannerlordRoot 'BlacksmithGuild_AutonomousGuildLoop.json'),
    (Join-Path $docsRoot 'BlacksmithGuild_AutonomousGuildLoop.json')
)

function Get-TbgGameProcessSnapshot {
    $names = @('Bannerlord', 'Bannerlord.Native', 'TaleWorlds.MountAndBlade', 'TaleWorlds.MountAndBlade.Launcher')
    $rows = @()
    foreach ($name in $names) {
        foreach ($process in @(Get-Process -Name $name -ErrorAction SilentlyContinue)) {
            $path = $null
            $title = $null
            $startTimeUtc = $null
            $responding = $null
            $workingSet64 = $null
            try { $path = [string]$process.Path } catch { }
            try { $title = [string]$process.MainWindowTitle } catch { }
            try { $startTimeUtc = $process.StartTime.ToUniversalTime().ToString('o') } catch { }
            try { $responding = [bool]$process.Responding } catch { }
            try { $workingSet64 = [int64]$process.WorkingSet64 } catch { }
            $rows += [pscustomobject][ordered]@{
                id = [int]$process.Id
                name = [string]$process.ProcessName
                title = $title
                path = $path
                startTimeUtc = $startTimeUtc
                responding = $responding
                workingSet64 = $workingSet64
            }
        }
    }
    return @($rows | Sort-Object id -Unique)
}

function Read-TbgJsonFile {
    param([string[]]$Candidates)
    foreach ($candidate in $Candidates) {
        if (-not (Test-Path -LiteralPath $candidate)) { continue }
        try {
            return [pscustomobject][ordered]@{
                path = $candidate
                value = Get-Content -LiteralPath $candidate -Raw | ConvertFrom-Json
            }
        } catch {
            return [pscustomobject][ordered]@{
                path = $candidate
                parseError = $_.Exception.Message
            }
        }
    }
    return $null
}

function Get-TbgFileSummary {
    param([string[]]$Candidates)
    $rows = @()
    foreach ($candidate in $Candidates) {
        if (Test-Path -LiteralPath $candidate) {
            $item = Get-Item -LiteralPath $candidate
            $rows += [pscustomobject][ordered]@{
                path = $candidate
                length = [int64]$item.Length
                lastWriteTimeUtc = $item.LastWriteTimeUtc.ToString('o')
            }
        }
    }
    return @($rows)
}

function Get-TbgLogTail {
    param([string[]]$Candidates, [int]$Tail = 80)
    foreach ($candidate in $Candidates) {
        if (-not (Test-Path -LiteralPath $candidate)) { continue }
        return [pscustomobject][ordered]@{
            path = $candidate
            lines = @(Get-Content -LiteralPath $candidate -Tail $Tail -ErrorAction SilentlyContinue)
        }
    }
    return $null
}

function Write-TbgOperatorResult {
    param(
        [Parameter(Mandatory = $true)][string]$Verdict,
        [Parameter(Mandatory = $true)][string]$Reason,
        [int]$Sequence,
        $BeforeProcesses,
        $AfterProcesses,
        $Ack,
        $Status,
        $GuildLoop,
        $PhaseTail
    )

    $payload = [ordered]@{
        schemaVersion = 'TbgAutonomousGuildLoopOperatorResult.v1'
        generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
        command = $commandName
        sequence = $Sequence
        verdict = $Verdict
        reason = $Reason
        bannerlordRoot = $bannerlordRoot
        docsRoot = $docsRoot
        processCountBefore = @($BeforeProcesses).Count
        processCountAfter = @($AfterProcesses).Count
        beforeProcesses = @($BeforeProcesses)
        afterProcesses = @($AfterProcesses)
        ack = $Ack
        status = $Status
        guildLoop = $GuildLoop
        files = [ordered]@{
            inbox = Get-TbgFileSummary @($inboxPath)
            ack = Get-TbgFileSummary @($ackPath)
            status = Get-TbgFileSummary $statusCandidates
            phase = Get-TbgFileSummary $phaseCandidates
            guildLoop = Get-TbgFileSummary $guildLoopCandidates
        }
        phaseTail = $PhaseTail
        operatorNotes = @(
            'This wrapper is for play/operator feedback, not live certification.',
            'If Bannerlord disappears during the wait, the terminal result is FAILED_game_disappeared_during_command.',
            'If no ACK/status appears, inspect whether the game was foreground, unpaused, and polling the command inbox.'
        )
    }

    $payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resultPath -Encoding UTF8

    $phasePath = ''
    if ($PhaseTail -and $PhaseTail.path) { $phasePath = [string]$PhaseTail.path }
    $color = 'Yellow'
    if ($Verdict -like 'PASS*') { $color = 'Green' }
    elseif ($Verdict -like 'FAILED*') { $color = 'Red' }

    $md = @(
        '# Autonomous Guild Loop Operator Result',
        '',
        "- Verdict: `$Verdict`",
        "- Reason: $Reason",
        "- Command: `$commandName`",
        "- Sequence: `$Sequence`",
        "- Process count before: $(@($BeforeProcesses).Count)",
        "- Process count after: $(@($AfterProcesses).Count)",
        "- Result JSON: `$resultPath`",
        "- Phase log: `$phasePath`",
        '',
        '## What this means',
        '',
        '- `FAILED_game_disappeared_during_command` means the game process existed before the command wait and vanished before ACK/status.',
        '- `BLOCKED_no_ack` means the inbox command was written but no matching ACK/status was observed before timeout.',
        '- Focus loss and in-game pause can prevent movement even when the inbox command is written.',
        '',
        '## Next useful evidence',
        '',
        'Run `CollectDiagnostics.cmd` if Bannerlord crashed or vanished. Run `Run-ExportEvidence.cmd` if the game stayed open but the command did not move the party.'
    )
    $md | Set-Content -LiteralPath $reportPath -Encoding UTF8

    Write-Host "[TBG] Operator result: $Verdict - $Reason" -ForegroundColor $color
    Write-Host "[TBG] Result JSON: $resultPath" -ForegroundColor Cyan
    Write-Host "[TBG] Report:      $reportPath" -ForegroundColor Cyan
}

$beforeProcesses = Get-TbgGameProcessSnapshot
if ($beforeProcesses.Count -eq 0) {
    Write-Host '[TBG] No Bannerlord process detected before command. The game must be loaded before this wrapper can run the loop.' -ForegroundColor Yellow
}

Clear-StaleMutationCommandInbox -BannerlordRoot $bannerlordRoot | Out-Null
$lastConsumed = Get-LastConsumedForgeInboxSequence -BannerlordRoot $bannerlordRoot
$sequence = [int]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
if ($sequence -le $lastConsumed) { $sequence = $lastConsumed + 1 }

if (Test-Path -LiteralPath $ackPath) {
    Remove-Item -LiteralPath $ackPath -Force -ErrorAction SilentlyContinue
}

$payload = [ordered]@{
    sequence = $sequence
    command = $commandName
    source = 'Run-AutonomousGuildLoop.cmd'
}
$payload | ConvertTo-Json | Set-Content -LiteralPath $inboxPath -Encoding UTF8

Write-Host "Wrote command inbox: sequence=$sequence command=$commandName" -ForegroundColor Green
Write-Host "Waiting up to ${TimeoutSec}s for ACK/status. Keep Bannerlord foreground and unpaused when movement is expected." -ForegroundColor Cyan
Write-Host 'If the game disappears, this wrapper will stop early and write an operator result.' -ForegroundColor Cyan

$deadline = (Get-Date).AddSeconds($TimeoutSec)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds $PollMs
    $afterProcesses = Get-TbgGameProcessSnapshot
    if ($beforeProcesses.Count -gt 0 -and $afterProcesses.Count -eq 0) {
        $ack = Read-TbgJsonFile @($ackPath)
        $status = Read-TbgJsonFile $statusCandidates
        $guildLoop = Read-TbgJsonFile $guildLoopCandidates
        $tail = Get-TbgLogTail $phaseCandidates
        Write-TbgOperatorResult -Verdict 'FAILED_game_disappeared_during_command' -Reason 'Bannerlord process existed before the command wait and disappeared before matching ACK/status.' -Sequence $sequence -BeforeProcesses $beforeProcesses -AfterProcesses $afterProcesses -Ack $ack -Status $status -GuildLoop $guildLoop -PhaseTail $tail
        exit 2
    }

    $ack = Read-TbgJsonFile @($ackPath)
    if ($ack -and $ack.value -and [int]$ack.value.sequence -eq $sequence -and [string]$ack.value.command -eq $commandName) {
        $status = Read-TbgJsonFile $statusCandidates
        $guildLoop = Read-TbgJsonFile $guildLoopCandidates
        $tail = Get-TbgLogTail $phaseCandidates
        $verdict = if ([string]$ack.value.result -eq 'Success') { 'PASS_ack_success' } else { 'BLOCKED_ack_' + [string]$ack.value.result }
        Write-TbgOperatorResult -Verdict $verdict -Reason ('ACK result: ' + [string]$ack.value.result) -Sequence $sequence -BeforeProcesses $beforeProcesses -AfterProcesses $afterProcesses -Ack $ack -Status $status -GuildLoop $guildLoop -PhaseTail $tail
        if ([string]$ack.value.result -eq 'Success') { exit 0 }
        exit 1
    }

    $status = Read-TbgJsonFile $statusCandidates
    if ($status -and $status.value -and $status.value.lastCommand -and [int]$status.value.lastCommand.sequence -eq $sequence -and [string]$status.value.lastCommand.name -eq $commandName) {
        $guildLoop = Read-TbgJsonFile $guildLoopCandidates
        $tail = Get-TbgLogTail $phaseCandidates
        $result = [string]$status.value.lastCommand.result
        $verdict = if ($result -eq 'Success') { 'PASS_status_success' } else { 'BLOCKED_status_' + $result }
        Write-TbgOperatorResult -Verdict $verdict -Reason ('Status result: ' + $result) -Sequence $sequence -BeforeProcesses $beforeProcesses -AfterProcesses $afterProcesses -Ack $null -Status $status -GuildLoop $guildLoop -PhaseTail $tail
        if ($result -eq 'Success') { exit 0 }
        exit 1
    }
}

$finalProcesses = Get-TbgGameProcessSnapshot
$finalAck = Read-TbgJsonFile @($ackPath)
$finalStatus = Read-TbgJsonFile $statusCandidates
$finalGuildLoop = Read-TbgJsonFile $guildLoopCandidates
$finalTail = Get-TbgLogTail $phaseCandidates
Write-TbgOperatorResult -Verdict 'BLOCKED_no_ack' -Reason "No matching ACK/status for $commandName after ${TimeoutSec}s." -Sequence $sequence -BeforeProcesses $beforeProcesses -AfterProcesses $finalProcesses -Ack $finalAck -Status $finalStatus -GuildLoop $finalGuildLoop -PhaseTail $finalTail
exit 1
