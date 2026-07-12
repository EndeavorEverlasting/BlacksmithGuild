# Context-aware, crash-aware operator session for RunAutonomousGuildLoopNow.
# A click means Automation intent unless a fresh ForgeStop sentinel says Quit intent.
# The only normal human gate is a five-second cancel/change-mind window.

param(
    [int]$TimeoutSec = 60,
    [int]$PollMs = 500,
    [ValidateRange(3, 5)]
    [int]$QuitGraceSec = 5
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'forge-status.ps1')
. (Join-Path $PSScriptRoot 'governor-operator-common.ps1')

$commandName = 'RunAutonomousGuildLoopNow'
$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot
$docsRoot = Get-BannerlordDocsRoot
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
$authorityCandidates = @(
    (Join-Path $bannerlordRoot 'BlacksmithGuild_EngineToggleAuthority.json'),
    (Join-Path $docsRoot 'BlacksmithGuild_EngineToggleAuthority.json')
)
$phaseCandidates = @(
    (Join-Path $bannerlordRoot 'BlacksmithGuild_Phase1.log'),
    (Join-Path $docsRoot 'BlacksmithGuild_Phase1.log')
)
$guildLoopCandidates = @(
    (Join-Path $bannerlordRoot 'BlacksmithGuild_AutonomousGuildLoop.json'),
    (Join-Path $docsRoot 'BlacksmithGuild_AutonomousGuildLoop.json')
)

$script:ContextTransitions = New-Object 'System.Collections.Generic.List[object]'
$script:FocusReacquireCount = 0
$script:NextSequence = [int64]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())

function Add-TbgContextTransition {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$Result = 'observed',
        [string]$Detail = ''
    )
    $script:ContextTransitions.Add([pscustomobject][ordered]@{
        atUtc = (Get-Date).ToUniversalTime().ToString('o')
        name = $Name
        result = $Result
        detail = $Detail
    }) | Out-Null
    Write-Host ("[TBG CONTEXT] {0} = {1}{2}" -f $Name, $Result, $(if ($Detail) { " - $Detail" } else { '' })) -ForegroundColor DarkCyan
}

function Read-TbgJsonFile {
    param([string[]]$Candidates)
    $existing = @($Candidates |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        ForEach-Object { Get-Item -LiteralPath $_ } |
        Sort-Object LastWriteTimeUtc -Descending)
    foreach ($item in $existing) {
        try {
            return [pscustomobject][ordered]@{
                path = $item.FullName
                lastWriteTimeUtc = $item.LastWriteTimeUtc.ToString('o')
                value = Get-Content -LiteralPath $item.FullName -Raw | ConvertFrom-Json
            }
        } catch {
            return [pscustomobject][ordered]@{
                path = $item.FullName
                lastWriteTimeUtc = $item.LastWriteTimeUtc.ToString('o')
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
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
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
    param([string[]]$Candidates, [int]$Tail = 100)
    $existing = @($Candidates |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        ForEach-Object { Get-Item -LiteralPath $_ } |
        Sort-Object LastWriteTimeUtc -Descending)
    if ($existing.Count -eq 0) { return $null }
    return [pscustomobject][ordered]@{
        path = $existing[0].FullName
        lines = @(Get-Content -LiteralPath $existing[0].FullName -Tail $Tail -ErrorAction SilentlyContinue)
    }
}

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
            $hwnd = [int64]0
            try { $path = [string]$process.Path } catch { }
            try { $title = [string]$process.MainWindowTitle } catch { }
            try { $startTimeUtc = $process.StartTime.ToUniversalTime().ToString('o') } catch { }
            try { $responding = [bool]$process.Responding } catch { }
            try { $workingSet64 = [int64]$process.WorkingSet64 } catch { }
            try { $hwnd = [int64]$process.MainWindowHandle } catch { }
            $isRuntime = $process.ProcessName -eq 'Bannerlord' -or
                $process.ProcessName -eq 'Bannerlord.Native' -or
                $process.ProcessName -eq 'TaleWorlds.MountAndBlade' -or
                $title -like '*Bannerlord - Singleplayer*'
            $rows += [pscustomobject][ordered]@{
                id = [int]$process.Id
                name = [string]$process.ProcessName
                title = $title
                path = $path
                hwnd = $hwnd
                isRuntime = [bool]$isRuntime
                startTimeUtc = $startTimeUtc
                responding = $responding
                workingSet64 = $workingSet64
            }
        }
    }
    return @($rows | Sort-Object id -Unique)
}

function Get-TbgRuntimeProcesses {
    return @(Get-TbgGameProcessSnapshot | Where-Object { $_.isRuntime })
}

$native = @'
using System;
using System.Runtime.InteropServices;

public static class TbgOperatorContextNative
{
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool attach);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int command);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);

    public const int SW_RESTORE = 9;

    public static bool ForceForegroundWindow(IntPtr hwnd)
    {
        if (hwnd == IntPtr.Zero || !IsWindow(hwnd)) return false;
        var foreground = GetForegroundWindow();
        uint ignored;
        var foregroundThread = foreground == IntPtr.Zero ? 0 : GetWindowThreadProcessId(foreground, out ignored);
        var targetThread = GetWindowThreadProcessId(hwnd, out ignored);
        var currentThread = GetCurrentThreadId();
        var foregroundAttached = false;
        var targetAttached = false;
        try
        {
            if (foregroundThread != 0 && foregroundThread != currentThread)
                foregroundAttached = AttachThreadInput(currentThread, foregroundThread, true);
            if (targetThread != 0 && targetThread != currentThread)
                targetAttached = AttachThreadInput(currentThread, targetThread, true);
            ShowWindow(hwnd, SW_RESTORE);
            BringWindowToTop(hwnd);
            SetForegroundWindow(hwnd);
        }
        finally
        {
            if (targetAttached) AttachThreadInput(currentThread, targetThread, false);
            if (foregroundAttached) AttachThreadInput(currentThread, foregroundThread, false);
        }
        return GetForegroundWindow() == hwnd;
    }
}
'@
if (-not ('TbgOperatorContextNative' -as [type])) {
    Add-Type -TypeDefinition $native -ErrorAction Stop
}

function Get-TbgPreferredRuntimeProcess {
    $runtime = @(Get-TbgRuntimeProcesses)
    if ($runtime.Count -eq 0) { return $null }
    $preferred = @($runtime | Where-Object { $_.title -like '*Bannerlord - Singleplayer*' -and $_.hwnd -ne 0 } | Select-Object -First 1)
    if ($preferred.Count -gt 0) { return $preferred[0] }
    $preferred = @($runtime | Where-Object { $_.name -eq 'Bannerlord' -and $_.hwnd -ne 0 } | Select-Object -First 1)
    if ($preferred.Count -gt 0) { return $preferred[0] }
    $preferred = @($runtime | Where-Object { $_.hwnd -ne 0 } | Select-Object -First 1)
    if ($preferred.Count -gt 0) { return $preferred[0] }
    return $runtime[0]
}

function Set-TbgRuntimeForeground {
    param([string]$Reason = 'operator automation context')
    $process = Get-TbgPreferredRuntimeProcess
    if (-not $process -or [int64]$process.hwnd -eq 0) {
        Add-TbgContextTransition -Name 'foreground' -Result 'blocked' -Detail 'no live Bannerlord runtime window'
        return $false
    }
    $hwnd = [IntPtr]([int64]$process.hwnd)
    $alreadyForeground = [TbgOperatorContextNative]::GetForegroundWindow() -eq $hwnd
    if ($alreadyForeground) { return $true }
    $acquired = [TbgOperatorContextNative]::ForceForegroundWindow($hwnd)
    Start-Sleep -Milliseconds 150
    $matches = [TbgOperatorContextNative]::GetForegroundWindow() -eq $hwnd
    if ($matches) { $script:FocusReacquireCount++ }
    Add-TbgContextTransition -Name 'foreground' -Result $(if ($matches) { 'acquired' } else { 'failed' }) -Detail ("pid={0} hwnd={1} reason={2}" -f $process.id, $process.hwnd, $Reason)
    return $matches
}

function Read-TbgTimedDecision {
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [Parameter(Mandatory = $true)][string[]]$AllowedKeys,
        [Parameter(Mandatory = $true)][int]$Seconds
    )
    Write-Host $Prompt -ForegroundColor Yellow
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        try {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                $name = [string]$key.Key
                if ($AllowedKeys -contains $name) {
                    Write-Host ''
                    return $name
                }
            }
        } catch { }
        $remaining = [Math]::Max(0, [int][Math]::Ceiling(($deadline - (Get-Date)).TotalSeconds))
        Write-Host ("`r[TBG] Continuing in {0}s... " -f $remaining) -NoNewline -ForegroundColor DarkYellow
        Start-Sleep -Milliseconds 100
    }
    Write-Host ''
    return $null
}

function Get-TbgStopContext {
    $path = Get-GovernorStopSentinelPath -RepoRoot $repoRoot
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return [pscustomobject]@{ active = $false; path = $path; ageSec = $null; value = $null }
    }
    $value = $null
    $ageSec = $null
    try {
        $value = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $requestedUtc = [datetime]::Parse([string]$value.requestedUtc).ToUniversalTime()
        $ageSec = [int]((Get-Date).ToUniversalTime() - $requestedUtc).TotalSeconds
    } catch { }
    return [pscustomobject]@{ active = $true; path = $path; ageSec = $ageSec; value = $value }
}

function Get-TbgRuntimeContext {
    $status = Read-TbgJsonFile $statusCandidates
    $authority = Read-TbgJsonFile $authorityCandidates
    $phase = 'Unknown'
    $paused = $null
    $campaignReady = $null
    $globalMode = 'Unknown'
    if ($status -and $status.value) {
        if ($status.value.session) {
            if ($status.value.session.phase) { $phase = [string]$status.value.session.phase }
            if ($null -ne $status.value.session.timePaused) { $paused = [bool]$status.value.session.timePaused }
        }
        if ($null -ne $status.value.campaignReady) { $campaignReady = [bool]$status.value.campaignReady }
    }
    if ($authority -and $authority.value -and $authority.value.globalMode) {
        $globalMode = [string]$authority.value.globalMode
    }
    return [pscustomobject][ordered]@{
        phase = $phase
        timePaused = $paused
        campaignReady = $campaignReady
        globalMode = $globalMode
        foregroundMatches = $(
            $preferred = Get-TbgPreferredRuntimeProcess
            if ($preferred -and [int64]$preferred.hwnd -ne 0) {
                [TbgOperatorContextNative]::GetForegroundWindow() -eq [IntPtr]([int64]$preferred.hwnd)
            } else { $false }
        )
        statusPath = $(if ($status) { $status.path } else { $null })
        authorityPath = $(if ($authority) { $authority.path } else { $null })
    }
}

function New-TbgCommandSequence {
    $lastConsumed = Get-LastConsumedForgeInboxSequence -BannerlordRoot $bannerlordRoot
    if ($script:NextSequence -le $lastConsumed) { $script:NextSequence = [int64]$lastConsumed + 1 }
    $sequence = $script:NextSequence
    $script:NextSequence++
    return $sequence
}

function Invoke-TbgContextCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [int]$WaitSec = 15,
        [switch]$MaintainFocus
    )
    $beforeRuntime = @(Get-TbgRuntimeProcesses)
    if ($beforeRuntime.Count -eq 0) {
        return [pscustomobject]@{ success = $false; verdict = 'FAILED_no_runtime'; result = 'Failed'; reason = 'No live Bannerlord runtime'; sequence = 0; ack = $null; status = $null }
    }
    if (Test-Path -LiteralPath $ackPath) {
        Remove-Item -LiteralPath $ackPath -Force -ErrorAction SilentlyContinue
    }
    $sequence = New-TbgCommandSequence
    [ordered]@{
        sequence = $sequence
        command = $Name
        source = 'Run-AutonomousGuildLoop.cmd/context-controller'
    } | ConvertTo-Json | Set-Content -LiteralPath $inboxPath -Encoding UTF8
    Add-TbgContextTransition -Name $Name -Result 'written' -Detail ("sequence={0}" -f $sequence)

    $deadline = (Get-Date).AddSeconds($WaitSec)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds $PollMs
        $runtime = @(Get-TbgRuntimeProcesses)
        if ($runtime.Count -eq 0) {
            return [pscustomobject]@{ success = $false; verdict = 'FAILED_game_disappeared_during_command'; result = 'Failed'; reason = "Bannerlord disappeared while waiting for $Name"; sequence = $sequence; ack = (Read-TbgJsonFile @($ackPath)); status = (Read-TbgJsonFile $statusCandidates) }
        }
        if ($MaintainFocus) { [void](Set-TbgRuntimeForeground -Reason $Name) }

        $ack = Read-TbgJsonFile @($ackPath)
        if ($ack -and $ack.value -and [int64]$ack.value.sequence -eq [int64]$sequence -and [string]$ack.value.command -eq $Name) {
            $result = [string]$ack.value.result
            $success = $result -eq 'Success'
            Add-TbgContextTransition -Name $Name -Result $result -Detail 'matching ACK'
            return [pscustomobject]@{ success = $success; verdict = $(if ($success) { 'PASS_ack_success' } else { 'BLOCKED_ack_' + $result }); result = $result; reason = 'matching ACK'; sequence = $sequence; ack = $ack; status = (Read-TbgJsonFile $statusCandidates) }
        }

        $status = Read-TbgJsonFile $statusCandidates
        if ($status -and $status.value -and $status.value.lastCommand -and
            [int64]$status.value.lastCommand.sequence -eq [int64]$sequence -and
            [string]$status.value.lastCommand.name -eq $Name) {
            $result = [string]$status.value.lastCommand.result
            $success = $result -eq 'Success'
            Add-TbgContextTransition -Name $Name -Result $result -Detail 'matching status'
            return [pscustomobject]@{ success = $success; verdict = $(if ($success) { 'PASS_status_success' } else { 'BLOCKED_status_' + $result }); result = $result; reason = 'matching status'; sequence = $sequence; ack = $null; status = $status }
        }
    }
    Add-TbgContextTransition -Name $Name -Result 'timeout' -Detail ("no ACK/status after {0}s" -f $WaitSec)
    return [pscustomobject]@{ success = $false; verdict = 'BLOCKED_no_ack'; result = 'Timeout'; reason = "No matching ACK/status after ${WaitSec}s"; sequence = $sequence; ack = (Read-TbgJsonFile @($ackPath)); status = (Read-TbgJsonFile $statusCandidates) }
}

function Write-TbgOperatorResult {
    param(
        [Parameter(Mandatory = $true)][string]$Verdict,
        [Parameter(Mandatory = $true)][string]$Reason,
        [int64]$Sequence = 0,
        $CommandResult = $null,
        $BeforeProcesses = @(),
        $AfterProcesses = @()
    )
    $status = Read-TbgJsonFile $statusCandidates
    $authority = Read-TbgJsonFile $authorityCandidates
    $guildLoop = Read-TbgJsonFile $guildLoopCandidates
    $phaseTail = Get-TbgLogTail $phaseCandidates
    $finalContext = Get-TbgRuntimeContext
    $phasePath = ''
    if ($phaseTail -and $phaseTail.path) { $phasePath = [string]$phaseTail.path }

    $payload = [ordered]@{
        schemaVersion = 'TbgAutonomousGuildLoopOperatorResult.v2'
        generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
        command = $commandName
        sequence = $Sequence
        verdict = $Verdict
        reason = $Reason
        bannerlordRoot = $bannerlordRoot
        docsRoot = $docsRoot
        quitGraceSec = $QuitGraceSec
        focusReacquireCount = $script:FocusReacquireCount
        contextTransitions = @($script:ContextTransitions)
        finalContext = $finalContext
        processCountBefore = @($BeforeProcesses).Count
        processCountAfter = @($AfterProcesses).Count
        beforeProcesses = @($BeforeProcesses)
        afterProcesses = @($AfterProcesses)
        commandResult = $CommandResult
        status = $status
        authority = $authority
        guildLoop = $guildLoop
        files = [ordered]@{
            inbox = Get-TbgFileSummary @($inboxPath)
            ack = Get-TbgFileSummary @($ackPath)
            status = Get-TbgFileSummary $statusCandidates
            authority = Get-TbgFileSummary $authorityCandidates
            phase = Get-TbgFileSummary $phaseCandidates
            guildLoop = Get-TbgFileSummary $guildLoopCandidates
        }
        phaseTail = $phaseTail
    }
    $payload | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resultPath -Encoding UTF8

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
        "- Focus reacquisitions: $script:FocusReacquireCount",
        "- Final phase: $($finalContext.phase)",
        "- Final paused state: $($finalContext.timePaused)",
        "- Final engine mode: $($finalContext.globalMode)",
        "- Result JSON: `$resultPath`",
        "- Phase log: `$phasePath`",
        '',
        '## Context policy',
        '',
        '- Automation intent sets global Automation, foregrounds Bannerlord, resumes the campaign clock, and starts the bounded guild loop.',
        '- ForgeStop is Quit intent. It provides a five-second Cancel/Force/Soft grace window before acting.',
        '- A fresh stop sentinel is never overridden silently; the operator receives a five-second chance to cancel the quit before automation can resume.'
    )
    $md | Set-Content -LiteralPath $reportPath -Encoding UTF8
    Write-Host "[TBG] Operator result: $Verdict - $Reason" -ForegroundColor $color
    Write-Host "[TBG] Result JSON: $resultPath" -ForegroundColor Cyan
    Write-Host "[TBG] Report:      $reportPath" -ForegroundColor Cyan
}

$beforeProcesses = Get-TbgGameProcessSnapshot
$stopContext = Get-TbgStopContext
if ($stopContext.active -and $null -ne $stopContext.ageSec -and $stopContext.ageSec -gt 1800) {
    Clear-GovernorStopSentinel -RepoRoot $repoRoot
    Add-TbgContextTransition -Name 'quit_context' -Result 'stale_cleared' -Detail ("ageSec={0}" -f $stopContext.ageSec)
    $stopContext = Get-TbgStopContext
}

if ($stopContext.active) {
    Add-TbgContextTransition -Name 'quit_context' -Result 'detected' -Detail $stopContext.path
    $changeMind = Read-TbgTimedDecision -Prompt "[TBG] Quit/stop context is active. Press C within ${QuitGraceSec}s to cancel the quit and resume automation." -AllowedKeys @('C') -Seconds $QuitGraceSec
    if ($changeMind -eq 'C') {
        Clear-GovernorStopSentinel -RepoRoot $repoRoot
        Add-TbgContextTransition -Name 'quit_context' -Result 'cancelled_by_user' -Detail 'automation may proceed'
    } else {
        Write-TbgOperatorResult -Verdict 'USER_QUIT_HONORED' -Reason 'Fresh ForgeStop context remained active after the change-mind window.' -BeforeProcesses $beforeProcesses -AfterProcesses (Get-TbgGameProcessSnapshot)
        exit 0
    }
} else {
    $quitKey = Read-TbgTimedDecision -Prompt "[TBG] Automation intent detected. Press Q or Escape within ${QuitGraceSec}s to quit instead; otherwise setup is automatic." -AllowedKeys @('Q', 'Escape') -Seconds $QuitGraceSec
    if ($quitKey) {
        $sentinel = Write-GovernorStopSentinel -RepoRoot $repoRoot -Reason 'operator cancelled autonomous guild-loop startup during grace window'
        Add-TbgContextTransition -Name 'quit_context' -Result 'requested_by_user' -Detail $sentinel
        Write-TbgOperatorResult -Verdict 'USER_QUIT_REQUESTED' -Reason "Operator pressed $quitKey during the automation grace window." -BeforeProcesses $beforeProcesses -AfterProcesses (Get-TbgGameProcessSnapshot)
        exit 0
    }
}

$runtimeBefore = @(Get-TbgRuntimeProcesses)
if ($runtimeBefore.Count -eq 0) {
    Add-TbgContextTransition -Name 'runtime' -Result 'blocked' -Detail 'no live Bannerlord Singleplayer runtime'
    Write-TbgOperatorResult -Verdict 'BLOCKED_no_runtime' -Reason 'Bannerlord must be loaded into a campaign before autonomous play can start.' -BeforeProcesses $beforeProcesses -AfterProcesses (Get-TbgGameProcessSnapshot)
    exit 1
}

if (-not (Set-TbgRuntimeForeground -Reason 'automation startup')) {
    Write-TbgOperatorResult -Verdict 'BLOCKED_focus' -Reason 'Could not foreground the bound Bannerlord runtime.' -BeforeProcesses $beforeProcesses -AfterProcesses (Get-TbgGameProcessSnapshot)
    exit 1
}

$initialContext = Get-TbgRuntimeContext
Add-TbgContextTransition -Name 'initial_context' -Result 'observed' -Detail ("phase={0} paused={1} mode={2}" -f $initialContext.phase, $initialContext.timePaused, $initialContext.globalMode)

$modeResult = $null
if ($initialContext.globalMode -ne 'Automation') {
    $modeResult = Invoke-TbgContextCommand -Name 'SetEngineToggleAutomation' -WaitSec 15 -MaintainFocus
    if (-not $modeResult.success) {
        Write-TbgOperatorResult -Verdict $modeResult.verdict -Reason ("Could not enter Automation mode: {0}" -f $modeResult.reason) -Sequence $modeResult.sequence -CommandResult $modeResult -BeforeProcesses $beforeProcesses -AfterProcesses (Get-TbgGameProcessSnapshot)
        exit 1
    }
} else {
    Add-TbgContextTransition -Name 'SetEngineToggleAutomation' -Result 'skipped' -Detail 'already Automation'
}

$resumeResult = Invoke-TbgContextCommand -Name 'ResumeCampaignClock' -WaitSec 15 -MaintainFocus
if (-not $resumeResult.success) {
    Write-TbgOperatorResult -Verdict $resumeResult.verdict -Reason ("Could not resume campaign clock: {0}" -f $resumeResult.reason) -Sequence $resumeResult.sequence -CommandResult $resumeResult -BeforeProcesses $beforeProcesses -AfterProcesses (Get-TbgGameProcessSnapshot)
    exit 1
}

$loopResult = Invoke-TbgContextCommand -Name $commandName -WaitSec 20 -MaintainFocus
if (-not $loopResult.success) {
    Write-TbgOperatorResult -Verdict $loopResult.verdict -Reason ("Guild loop did not start: {0}" -f $loopResult.reason) -Sequence $loopResult.sequence -CommandResult $loopResult -BeforeProcesses $beforeProcesses -AfterProcesses (Get-TbgGameProcessSnapshot)
    exit 1
}

Add-TbgContextTransition -Name 'guild_loop_watch' -Result 'started' -Detail ("timeoutSec={0}" -f $TimeoutSec)
$watchDeadline = (Get-Date).AddSeconds($TimeoutSec)
$lastResumeUtc = [datetime]::MinValue
$lastProgressUtc = [datetime]::MinValue
while ((Get-Date) -lt $watchDeadline) {
    Start-Sleep -Milliseconds $PollMs
    $runtime = @(Get-TbgRuntimeProcesses)
    if ($runtime.Count -eq 0) {
        Write-TbgOperatorResult -Verdict 'FAILED_game_disappeared_during_command' -Reason 'Bannerlord disappeared while the autonomous guild loop was active.' -Sequence $loopResult.sequence -CommandResult $loopResult -BeforeProcesses $beforeProcesses -AfterProcesses (Get-TbgGameProcessSnapshot)
        exit 2
    }

    if (Test-GovernorStopRequested -RepoRoot $repoRoot) {
        Add-TbgContextTransition -Name 'quit_context' -Result 'honored_during_session' -Detail 'ForgeStop sentinel detected'
        Write-TbgOperatorResult -Verdict 'USER_QUIT_HONORED' -Reason 'ForgeStop requested during the autonomous session.' -Sequence $loopResult.sequence -CommandResult $loopResult -BeforeProcesses $beforeProcesses -AfterProcesses (Get-TbgGameProcessSnapshot)
        exit 0
    }

    [void](Set-TbgRuntimeForeground -Reason 'active guild-loop watch')
    $context = Get-TbgRuntimeContext
    if ($context.timePaused -eq $true -and ((Get-Date) - $lastResumeUtc).TotalSeconds -ge 5) {
        $lastResumeUtc = Get-Date
        $retryResume = Invoke-TbgContextCommand -Name 'ResumeCampaignClock' -WaitSec 10 -MaintainFocus
        Add-TbgContextTransition -Name 'pause_correction' -Result $(if ($retryResume.success) { 'resumed' } else { 'blocked' }) -Detail $retryResume.reason
    }

    $guildLoop = Read-TbgJsonFile $guildLoopCandidates
    if ($guildLoop -and $guildLoop.value -and -not [string]::IsNullOrWhiteSpace([string]$guildLoop.value.verdict)) {
        $terminal = [string]$guildLoop.value.verdict
        $verdict = if ($terminal -eq 'Complete') { 'PASS_cycle_complete' } else { 'BLOCKED_cycle_' + $terminal }
        Add-TbgContextTransition -Name 'guild_loop_watch' -Result $terminal -Detail ([string]$guildLoop.value.blockedReason)
        [void](Set-TbgRuntimeForeground -Reason 'cycle terminal handoff')
        Write-TbgOperatorResult -Verdict $verdict -Reason ("Guild loop terminal verdict: {0}" -f $terminal) -Sequence $loopResult.sequence -CommandResult $loopResult -BeforeProcesses $beforeProcesses -AfterProcesses (Get-TbgGameProcessSnapshot)
        if ($terminal -eq 'Complete') { exit 0 }
        exit 1
    }

    if (((Get-Date) - $lastProgressUtc).TotalSeconds -ge 5) {
        $lastProgressUtc = Get-Date
        $remaining = [Math]::Max(0, [int][Math]::Ceiling(($watchDeadline - (Get-Date)).TotalSeconds))
        Write-Host ("[TBG] Active: phase={0} paused={1} mode={2} remaining={3}s" -f $context.phase, $context.timePaused, $context.globalMode, $remaining) -ForegroundColor Cyan
    }
}

Write-TbgOperatorResult -Verdict 'BLOCKED_loop_not_terminal' -Reason "The guild loop acknowledged startup but did not reach a terminal report within ${TimeoutSec}s." -Sequence $loopResult.sequence -CommandResult $loopResult -BeforeProcesses $beforeProcesses -AfterProcesses (Get-TbgGameProcessSnapshot)
exit 1
