# Immediate context controller for normal play.
# No startup countdown: foreground Bannerlord, enter Automation, resume time, and run one bounded guild loop.

param(
    [int]$TimeoutSec = 60,
    [int]$PollMs = 500
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'forge-status.ps1')

$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot
$docsRoot = Get-BannerlordDocsRoot
$latestDir = Join-Path $repoRoot 'artifacts\latest'
New-Item -ItemType Directory -Force -Path $latestDir | Out-Null
$resultPath = Join-Path $latestDir 'autonomous-guild-loop-operator.json'
$reportPath = Join-Path $latestDir 'autonomous-guild-loop-operator.md'
$inboxPath = Join-Path $bannerlordRoot 'BlacksmithGuild_CommandInbox.json'
$ackPath = Join-Path $bannerlordRoot 'BlacksmithGuild_CommandAck.json'
$statusPaths = @(
    (Join-Path $bannerlordRoot 'BlacksmithGuild_Status.json'),
    (Join-Path $docsRoot 'BlacksmithGuild_Status.json')
)
$loopPaths = @(
    (Join-Path $bannerlordRoot 'BlacksmithGuild_AutonomousGuildLoop.json'),
    (Join-Path $docsRoot 'BlacksmithGuild_AutonomousGuildLoop.json')
)
$transitions = [System.Collections.Generic.List[object]]::new()
$nextSequence = [int64]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
$focusCount = 0

$native = @'
using System;
using System.Runtime.InteropServices;
public static class TbgImmediateContextNative
{
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int command);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
    public static bool Focus(IntPtr hwnd)
    {
        if (hwnd == IntPtr.Zero) return false;
        ShowWindow(hwnd, 9);
        BringWindowToTop(hwnd);
        SetForegroundWindow(hwnd);
        return GetForegroundWindow() == hwnd;
    }
}
'@
if (-not ('TbgImmediateContextNative' -as [type])) {
    Add-Type -TypeDefinition $native -ErrorAction Stop
}

function Add-Transition {
    param([string]$Name, [string]$Result, [string]$Detail = '')
    $transitions.Add([pscustomobject][ordered]@{
        atUtc = (Get-Date).ToUniversalTime().ToString('o')
        name = $Name
        result = $Result
        detail = $Detail
    }) | Out-Null
    Write-Host "[TBG CONTEXT] $Name = $Result$(if ($Detail) { ' - ' + $Detail })" -ForegroundColor DarkCyan
}

function Read-LatestJson {
    param([string[]]$Paths)
    foreach ($item in @($Paths | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | ForEach-Object { Get-Item -LiteralPath $_ } | Sort-Object LastWriteTimeUtc -Descending)) {
        try {
            return [pscustomobject]@{
                path = $item.FullName
                lastWriteTimeUtc = $item.LastWriteTimeUtc
                value = Get-Content -LiteralPath $item.FullName -Raw | ConvertFrom-Json
            }
        } catch { }
    }
    return $null
}

function Get-GameProcess {
    $all = @()
    foreach ($name in @('Bannerlord', 'Bannerlord.Native', 'TaleWorlds.MountAndBlade')) {
        $all += @(Get-Process -Name $name -ErrorAction SilentlyContinue)
    }
    $preferred = @($all | Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -like '*Bannerlord - Singleplayer*' } | Select-Object -First 1)
    if ($preferred.Count -gt 0) { return $preferred[0] }
    $preferred = @($all | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1)
    if ($preferred.Count -gt 0) { return $preferred[0] }
    return $null
}

function Focus-Game {
    param([string]$Reason)
    $process = Get-GameProcess
    if (-not $process) { return $false }
    $hwnd = [IntPtr]$process.MainWindowHandle
    if ([TbgImmediateContextNative]::GetForegroundWindow() -eq $hwnd) { return $true }
    $ok = [TbgImmediateContextNative]::Focus($hwnd)
    if ($ok) { $script:focusCount++ }
    Add-Transition -Name 'foreground' -Result $(if ($ok) { 'acquired' } else { 'failed' }) -Detail "pid=$($process.Id) reason=$Reason"
    return $ok
}

function New-Sequence {
    $lastConsumed = Get-LastConsumedForgeInboxSequence -BannerlordRoot $bannerlordRoot
    if ($script:nextSequence -le $lastConsumed) { $script:nextSequence = [int64]$lastConsumed + 1 }
    $value = $script:nextSequence
    $script:nextSequence++
    return $value
}

function Send-ContextCommand {
    param([string]$Name, [int]$WaitSec = 15)
    if (-not (Get-GameProcess)) {
        return [pscustomobject]@{ success = $false; sequence = 0; result = 'NoRuntime'; reason = 'Bannerlord runtime not found' }
    }
    Remove-Item -LiteralPath $ackPath -Force -ErrorAction SilentlyContinue
    $sequence = New-Sequence
    [ordered]@{
        sequence = $sequence
        command = $Name
        source = 'Run-AutonomousGuildLoop.cmd/immediate-context'
    } | ConvertTo-Json | Set-Content -LiteralPath $inboxPath -Encoding UTF8
    Add-Transition -Name $Name -Result 'written' -Detail "sequence=$sequence"
    [void](Focus-Game -Reason $Name)

    $deadline = (Get-Date).AddSeconds($WaitSec)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds $PollMs
        if (-not (Get-GameProcess)) {
            return [pscustomobject]@{ success = $false; sequence = $sequence; result = 'GameDisappeared'; reason = "Bannerlord disappeared while waiting for $Name" }
        }
        [void](Focus-Game -Reason $Name)
        $ack = Read-LatestJson @($ackPath)
        if ($ack -and $ack.value -and [int64]$ack.value.sequence -eq $sequence -and [string]$ack.value.command -eq $Name) {
            $result = [string]$ack.value.result
            Add-Transition -Name $Name -Result $result -Detail 'matching ACK'
            return [pscustomobject]@{ success = $result -eq 'Success'; sequence = $sequence; result = $result; reason = 'matching ACK' }
        }
        $status = Read-LatestJson $statusPaths
        if ($status -and $status.value -and $status.value.lastCommand -and [int64]$status.value.lastCommand.sequence -eq $sequence -and [string]$status.value.lastCommand.name -eq $Name) {
            $result = [string]$status.value.lastCommand.result
            Add-Transition -Name $Name -Result $result -Detail 'matching status'
            return [pscustomobject]@{ success = $result -eq 'Success'; sequence = $sequence; result = $result; reason = 'matching status' }
        }
    }
    Add-Transition -Name $Name -Result 'timeout' -Detail "${WaitSec}s"
    return [pscustomobject]@{ success = $false; sequence = $sequence; result = 'Timeout'; reason = "No matching ACK/status after ${WaitSec}s" }
}

function Write-Result {
    param([string]$Verdict, [string]$Reason, $LastCommand = $null)
    $status = Read-LatestJson $statusPaths
    $loop = Read-LatestJson $loopPaths
    $transitionSnapshot = if ($transitions.Count -gt 0) { @($transitions.ToArray()) } else { @() }
    $payload = [ordered]@{
        schemaVersion = 'TbgAutonomousGuildLoopOperatorResult.v2'
        generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
        mode = 'immediate'
        quitGraceSec = 0
        verdict = $Verdict
        reason = $Reason
        focusReacquireCount = $script:focusCount
        contextTransitions = $transitionSnapshot
        lastCommand = $LastCommand
        status = $status
        guildLoop = $loop
    }
    $payload | ConvertTo-Json -Depth 9 | Set-Content -LiteralPath $resultPath -Encoding UTF8
    @(
        '# Autonomous Guild Loop Operator Result',
        '',
        '- Mode: immediate',
        '- Startup grace seconds: 0',
        "- Verdict: $Verdict",
        "- Reason: $Reason",
        "- Focus reacquisitions: $script:focusCount",
        "- JSON: $resultPath"
    ) | Set-Content -LiteralPath $reportPath -Encoding UTF8
    Write-Host "[TBG] $Verdict - $Reason" -ForegroundColor $(if ($Verdict -like 'PASS*') { 'Green' } elseif ($Verdict -like 'FAILED*') { 'Red' } else { 'Yellow' })
    Write-Host "[TBG] Result: $resultPath" -ForegroundColor Cyan
}

if (-not (Get-GameProcess)) {
    Write-Result -Verdict 'BLOCKED_no_runtime' -Reason 'Load a Bannerlord campaign before starting the autonomous guild loop.'
    exit 1
}
if (-not (Focus-Game -Reason 'immediate startup')) {
    Write-Result -Verdict 'BLOCKED_focus' -Reason 'Could not foreground Bannerlord.'
    exit 1
}

$mode = Send-ContextCommand -Name 'SetEngineToggleAutomation'
if (-not $mode.success) { Write-Result -Verdict 'BLOCKED_mode' -Reason $mode.reason -LastCommand $mode; exit 1 }
$resume = Send-ContextCommand -Name 'ResumeCampaignClock'
if (-not $resume.success) { Write-Result -Verdict 'BLOCKED_resume' -Reason $resume.reason -LastCommand $resume; exit 1 }
$loopStartUtc = (Get-Date).ToUniversalTime()
$start = Send-ContextCommand -Name 'RunAutonomousGuildLoopNow' -WaitSec 20
if (-not $start.success) { Write-Result -Verdict 'BLOCKED_start' -Reason $start.reason -LastCommand $start; exit 1 }

$deadline = (Get-Date).AddSeconds($TimeoutSec)
$lastResume = [datetime]::MinValue
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds $PollMs
    if (-not (Get-GameProcess)) {
        Write-Result -Verdict 'FAILED_game_disappeared_during_command' -Reason 'Bannerlord disappeared while the autonomous guild loop was active.' -LastCommand $start
        exit 2
    }
    [void](Focus-Game -Reason 'active guild-loop watch')
    $status = Read-LatestJson $statusPaths
    if ($status -and $status.value -and $status.value.session -and $status.value.session.timePaused -eq $true -and ((Get-Date) - $lastResume).TotalSeconds -ge 5) {
        $lastResume = Get-Date
        [void](Send-ContextCommand -Name 'ResumeCampaignClock' -WaitSec 10)
    }
    $loop = Read-LatestJson $loopPaths
    if ($loop -and $loop.lastWriteTimeUtc -ge $loopStartUtc.AddSeconds(-1) -and $loop.value -and -not [string]::IsNullOrWhiteSpace([string]$loop.value.verdict)) {
        $terminal = [string]$loop.value.verdict
        Write-Result -Verdict $(if ($terminal -eq 'Complete') { 'PASS_cycle_complete' } else { 'BLOCKED_cycle_' + $terminal }) -Reason "Guild loop terminal verdict: $terminal" -LastCommand $start
        if ($terminal -eq 'Complete') { exit 0 }
        exit 1
    }
}

Write-Result -Verdict 'BLOCKED_loop_not_terminal' -Reason "The guild loop started but did not reach a terminal report within ${TimeoutSec}s." -LastCommand $start
exit 1
