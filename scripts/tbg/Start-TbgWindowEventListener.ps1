[CmdletBinding()]
param(
    [ValidateSet('observe', 'fixture')]
    [string]$Mode = 'observe',
    [int]$DurationSeconds = 30,
    [int]$ProcessId = 0,
    [Int64]$Hwnd = 0,
    [string]$RunContextPath,
    [string]$RunId,
    [string]$CorrelationId,
    [string]$FixturePath,
    [int]$LaunchPollMilliseconds = 100,
    [int]$StablePollMilliseconds = 500,
    [int]$StableAfterSeconds = 3,
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

function Ensure-TbgDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Read-TbgJson {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-TbgGitValue {
    param([Parameter(Mandatory = $true)][string[]]$Arguments, [string]$Fallback = 'unknown')
    try {
        $value = (& git -C $repoRoot @Arguments 2>$null | Out-String).Trim()
        if (-not [string]::IsNullOrWhiteSpace($value)) { return $value }
    } catch { }
    return $Fallback
}

function Get-TbgCanonicalProcessName {
    param([string]$ImageName)
    switch -Regex ($ImageName) {
        '(?i)^Bannerlord\.Native$' { return 'Bannerlord.Native' }
        '(?i)^Bannerlord$' { return 'Bannerlord' }
        '(?i)^TaleWorlds\.MountAndBlade\.Launcher$' { return 'TaleWorlds.MountAndBlade.Launcher' }
        '(?i)^TaleWorlds\.MountAndBlade$' { return 'TaleWorlds.MountAndBlade' }
        default { return 'unknown' }
    }
}

function Initialize-TbgWindowEventNative {
    if ($env:OS -ne 'Windows_NT' -or ('TbgWindowEventNative' -as [type])) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public sealed class TbgWinEventRecord {
    public uint EventType;
    public long Hwnd;
    public int ProcessId;
    public DateTime ObservedUtc;
}

public sealed class TbgWindowSnapshot {
    public long Hwnd;
    public int ProcessId;
    public string Title;
    public string ClassName;
    public bool Visible;
}

public static class TbgWindowEventNative {
    public const uint EVENT_SYSTEM_FOREGROUND = 0x0003;
    public const uint EVENT_OBJECT_CREATE = 0x8000;
    public const uint EVENT_OBJECT_DESTROY = 0x8001;
    public const uint EVENT_OBJECT_SHOW = 0x8002;
    public const uint EVENT_OBJECT_HIDE = 0x8003;
    public const uint EVENT_OBJECT_NAMECHANGE = 0x800C;
    public const uint WINEVENT_OUTOFCONTEXT = 0;
    public delegate void WinEventDelegate(IntPtr hook, uint eventType, IntPtr hwnd, int objectId, int childId, uint threadId, uint eventTime);
    public static readonly ConcurrentQueue<TbgWinEventRecord> Queue = new ConcurrentQueue<TbgWinEventRecord>();
    private static readonly WinEventDelegate Callback = OnEvent;
    public static WinEventDelegate Handler { get { return Callback; } }
    [DllImport("user32.dll")] public static extern IntPtr SetWinEventHook(uint min, uint max, IntPtr module, WinEventDelegate callback, uint processId, uint threadId, uint flags);
    [DllImport("user32.dll")] public static extern bool UnhookWinEvent(IntPtr hook);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int maxCount);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetClassName(IntPtr hwnd, StringBuilder text, int maxCount);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hwnd);
    public delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr lParam);
    private static void OnEvent(IntPtr hook, uint eventType, IntPtr hwnd, int objectId, int childId, uint threadId, uint eventTime) {
        try {
            if (hwnd == IntPtr.Zero || objectId != 0 || childId != 0) return;
            uint pid; GetWindowThreadProcessId(hwnd, out pid);
            Queue.Enqueue(new TbgWinEventRecord { EventType = eventType, Hwnd = hwnd.ToInt64(), ProcessId = (int)pid, ObservedUtc = DateTime.UtcNow });
        } catch { }
    }
    private static string Text(IntPtr hwnd) { var sb = new StringBuilder(1024); GetWindowText(hwnd, sb, sb.Capacity); return sb.ToString(); }
    private static string Class(IntPtr hwnd) { var sb = new StringBuilder(512); GetClassName(hwnd, sb, sb.Capacity); return sb.ToString(); }
    public static List<TbgWindowSnapshot> Enumerate() {
        var items = new List<TbgWindowSnapshot>();
        EnumWindows((hwnd, ignored) => {
            uint pid; GetWindowThreadProcessId(hwnd, out pid);
            items.Add(new TbgWindowSnapshot { Hwnd = hwnd.ToInt64(), ProcessId = (int)pid, Title = Text(hwnd), ClassName = Class(hwnd), Visible = IsWindowVisible(hwnd) });
            return true;
        }, IntPtr.Zero);
        return items;
    }
}
'@ -ErrorAction Stop
}

function Get-TbgProcessImageName {
    param([int]$TargetProcessId)
    try { return [string](Get-Process -Id $TargetProcessId -ErrorAction Stop).ProcessName } catch { return '' }
}

function Test-TbgTargetWindow {
    param([int]$TargetProcessId, [Int64]$TargetHwnd)
    if ($Hwnd -ne 0 -and $TargetHwnd -ne $Hwnd) { return $false }
    if ($ProcessId -gt 0 -and $TargetProcessId -ne $ProcessId) { return $false }
    if ($ProcessId -gt 0 -or $Hwnd -ne 0) { return $true }
    return (Get-TbgProcessImageName -TargetProcessId $TargetProcessId) -match '^(?i)(Bannerlord|TaleWorlds\.MountAndBlade)'
}

function Get-TbgWindowIdentity {
    param([int]$TargetProcessId, [Int64]$TargetHwnd, [string]$Title = '', [string]$ClassName = '', [bool]$Visible = $false)
    $imageName = Get-TbgProcessImageName -TargetProcessId $TargetProcessId
    return [ordered]@{
        hwnd = $TargetHwnd
        title = $Title
        className = $ClassName
        visible = $Visible
        processImage = $imageName
    }
}

function Write-TbgObserverEvent {
    param(
        [Parameter(Mandatory = $true)][string]$EventType,
        [Parameter(Mandatory = $true)][string]$Source,
        [int]$TargetProcessId = 0,
        [Int64]$TargetHwnd = 0,
        [hashtable]$Payload = @{},
        [ValidateSet('info', 'warning', 'error', 'critical')][string]$Severity = 'info',
        [string]$Title = '',
        [string]$ClassName = '',
        [bool]$Visible = $false
    )
    $imageName = Get-TbgProcessImageName -TargetProcessId $TargetProcessId
    $now = [DateTime]::UtcNow.ToString('o')
    $event = [ordered]@{
        schema = 'TbgRuntimeObserverEvent.v1'
        version = 1
        eventId = ('window-listener-{0}' -f [Guid]::NewGuid().ToString('N'))
        runId = $script:runId
        commandId = $null
        correlationId = $script:correlationId
        spanId = $null
        parentSpanId = $null
        observerId = 'windows-window-event-listener'
        sourceKind = if ($EventType -like 'observer.*') { 'observer_health' } else { 'window_lifecycle' }
        eventType = $EventType
        severity = $Severity
        observedUtc = $now
        sourceTimestamp = $now
        processIdentity = [ordered]@{ canonicalName = Get-TbgCanonicalProcessName -ImageName $imageName; pid = if ($TargetProcessId -gt 0) { $TargetProcessId } else { $null } }
        windowIdentity = if ($TargetHwnd -gt 0) { Get-TbgWindowIdentity -TargetProcessId $TargetProcessId -TargetHwnd $TargetHwnd -Title $Title -ClassName $ClassName -Visible $Visible } else { $null }
        operation = 'window_event_observation'
        expectedSignalId = $null
        payload = [ordered]@{ source = $Source; data = $Payload }
        evidenceRefs = @('scripts/tbg/Start-TbgWindowEventListener.ps1')
        freshness = 'fresh'
        proofLevel = 'harness'
        redactionState = 'sanitized'
    }
    ($event | ConvertTo-Json -Depth 12 -Compress) | Add-Content -LiteralPath $script:eventsPath -Encoding UTF8
    $script:eventCount++
    return $event
}

function Get-TbgEventType {
    param([uint32]$NativeEvent)
    switch ($NativeEvent) {
        0x8000 { 'window.created' }
        0x8001 { 'window.destroyed' }
        0x8002 { 'window.shown' }
        0x8003 { 'window.hidden' }
        0x800C { 'window.title_changed' }
        0x0003 { 'window.focus_changed' }
        default { $null }
    }
}

function Publish-TbgCandidate {
    param(
        [Parameter(Mandatory = $true)][string]$EventType,
        [Parameter(Mandatory = $true)][string]$Source,
        [int]$TargetProcessId,
        [Int64]$TargetHwnd,
        [string]$Title = '',
        [string]$ClassName = '',
        [bool]$Visible = $false,
        [hashtable]$Payload = @{}
    )
    $key = '{0}|{1}|{2}|{3}' -f $EventType, $TargetProcessId, $TargetHwnd, $Title
    $now = [DateTime]::UtcNow
    if ($script:recent.ContainsKey($key)) {
        $previous = $script:recent[$key]
        if ($previous.source -ne $Source -and (($now - $previous.at).TotalMilliseconds -lt 350)) {
            $script:deduplicated++
            return
        }
    }
    $script:recent[$key] = [pscustomobject]@{ source = $Source; at = $now }
    Write-TbgObserverEvent -EventType $EventType -Source $Source -TargetProcessId $TargetProcessId -TargetHwnd $TargetHwnd -Title $Title -ClassName $ClassName -Visible $Visible -Payload $Payload | Out-Null
}

function Invoke-TbgReconciliation {
    param([string]$Reason = 'scheduled_poll')
    $current = @{}
    foreach ($snapshot in @([TbgWindowEventNative]::Enumerate())) {
        if (-not (Test-TbgTargetWindow -TargetProcessId ([int]$snapshot.ProcessId) -TargetHwnd ([Int64]$snapshot.Hwnd)) -or (-not $snapshot.Visible -and [string]::IsNullOrWhiteSpace($snapshot.Title))) { continue }
        $key = '{0}|{1}' -f [int]$snapshot.ProcessId, [Int64]$snapshot.Hwnd
        $current[$key] = $snapshot
        if (-not $script:knownWindows.ContainsKey($key)) {
            Publish-TbgCandidate -EventType 'window.created' -Source 'poll' -TargetProcessId ([int]$snapshot.ProcessId) -TargetHwnd ([Int64]$snapshot.Hwnd) -Title ([string]$snapshot.Title) -ClassName ([string]$snapshot.ClassName) -Visible ([bool]$snapshot.Visible) -Payload @{ reconciliation = $Reason }
            Write-TbgObserverEvent -EventType 'observer.reconciled' -Source 'poll' -TargetProcessId ([int]$snapshot.ProcessId) -TargetHwnd ([Int64]$snapshot.Hwnd) -Payload @{ reason = 'window_present_without_hook_record'; reconciliation = $Reason } | Out-Null
        } elseif ([string]$script:knownWindows[$key].Title -ne [string]$snapshot.Title) {
            Publish-TbgCandidate -EventType 'window.title_changed' -Source 'poll' -TargetProcessId ([int]$snapshot.ProcessId) -TargetHwnd ([Int64]$snapshot.Hwnd) -Title ([string]$snapshot.Title) -ClassName ([string]$snapshot.ClassName) -Visible ([bool]$snapshot.Visible) -Payload @{ reconciliation = $Reason }
        }
    }
    foreach ($knownKey in @($script:knownWindows.Keys)) {
        if ($current.ContainsKey($knownKey)) { continue }
        $old = $script:knownWindows[$knownKey]
        Publish-TbgCandidate -EventType 'window.destroyed' -Source 'poll' -TargetProcessId ([int]$old.ProcessId) -TargetHwnd ([Int64]$old.Hwnd) -Title ([string]$old.Title) -ClassName ([string]$old.ClassName) -Visible $false -Payload @{ disposition = 'disappearance_only'; reconciliation = $Reason }
        Write-TbgObserverEvent -EventType 'observer.reconciled' -Source 'poll' -TargetProcessId ([int]$old.ProcessId) -TargetHwnd ([Int64]$old.Hwnd) -Payload @{ reason = 'window_disappearance_reconciled_without_acceptance'; reconciliation = $Reason } | Out-Null
    }
    $script:knownWindows = $current
}

if (-not [string]::IsNullOrWhiteSpace($RunContextPath)) {
    $context = Read-TbgJson -Path $RunContextPath
    if ($null -ne $context) {
        if ($ProcessId -eq 0 -and $context.processIdentity -and $null -ne $context.processIdentity.pid) { $ProcessId = [int]$context.processIdentity.pid }
        if ([string]::IsNullOrWhiteSpace($RunId)) { $RunId = [string]$context.runId }
        if ([string]::IsNullOrWhiteSpace($CorrelationId)) { $CorrelationId = [string]$context.correlationId }
    }
}

$script:runId = if ([string]::IsNullOrWhiteSpace($RunId)) { 'window-listener-{0}' -f ([Guid]::NewGuid().ToString('N').Substring(0, 12)) } else { $RunId }
$script:correlationId = if ([string]::IsNullOrWhiteSpace($CorrelationId)) { 'window-listener-corr-{0}' -f ([Guid]::NewGuid().ToString('N').Substring(0, 12)) } else { $CorrelationId }
$runRoot = Join-Path $repoRoot ('.local/tbg-runtime-observer/{0}' -f $script:runId)
Ensure-TbgDirectory -Path $runRoot
$script:eventsPath = Join-Path $runRoot 'events.jsonl'
$script:eventCount = 0
$script:deduplicated = 0
$script:recent = @{}
$script:knownWindows = @{}
'' | Set-Content -LiteralPath $script:eventsPath -Encoding UTF8

$runContext = [ordered]@{
    schema = 'TbgRuntimeObserverRunContext.v1'
    runId = $script:runId
    correlationId = $script:correlationId
    sourceCommit = Get-TbgGitValue -Arguments @('rev-parse', 'HEAD')
    branch = Get-TbgGitValue -Arguments @('branch', '--show-current') -Fallback 'detached'
    worktreeLabel = 'sprint/window-event-listener'
    observers = @([ordered]@{ observerId = 'windows-window-event-listener'; version = '1.0'; sourceKind = 'window_lifecycle' })
    processIdentity = [ordered]@{ canonicalName = 'unknown'; pid = if ($ProcessId -gt 0) { $ProcessId } else { $null }; imageName = $null; ownership = 'unknown' }
    startedUtc = [DateTime]::UtcNow.ToString('o')
    completedUtc = $null
    mode = if ($Mode -eq 'fixture') { 'fixture' } else { 'observe' }
    authority = 'read-only window observation; no process, game, save, command, focus, or click mutation'
    proofCeiling = 'harness'
    artifactRoot = ('.local/tbg-runtime-observer/{0}' -f $script:runId)
    redactionPolicy = [ordered]@{ rawEvidenceLocalOnly = $true; forbiddenContent = @('secrets', 'tokens', 'personal_paths', 'dumps') }
}
$contextPath = Join-Path $runRoot 'run-context.json'
$runContext | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $contextPath -Encoding UTF8

if ($Mode -eq 'fixture') {
    $fixture = Read-TbgJson -Path $FixturePath
    if ($null -eq $fixture) { throw "Listener fixture is missing or invalid: $FixturePath" }
    foreach ($item in @($fixture.events)) {
        $fixtureProcessId = [int]$item.pid; $window = [Int64]$item.hwnd
        $fixtureKind = if ($item.PSObject.Properties['kind']) { [string]$item.kind } else { '' }
        if ($fixtureKind -eq 'callback_failure') {
            Write-TbgObserverEvent -EventType 'observer.gap' -Source 'hook' -TargetProcessId $fixtureProcessId -TargetHwnd $window -Severity 'warning' -Payload @{ reason = 'callback_failure'; detail = [string]$item.detail } | Out-Null
            continue
        }
        if ($fixtureKind -eq 'reconciled') {
            Write-TbgObserverEvent -EventType 'observer.reconciled' -Source 'poll' -TargetProcessId $fixtureProcessId -TargetHwnd $window -Payload @{ reason = [string]$item.detail } | Out-Null
            continue
        }
        Publish-TbgCandidate -EventType ([string]$item.eventType) -Source ([string]$item.source) -TargetProcessId $fixtureProcessId -TargetHwnd $window -Title ([string]$item.title) -ClassName ([string]$item.className) -Visible ([bool]$item.visible) -Payload @{ fixtureCase = [string]$item.caseId; quarantine = ([string]$item.caseId -eq 'unknown-quarantine'); disposition = if ([string]$item.eventType -eq 'window.destroyed') { 'disappearance_only' } else { 'observation_only' } }
    }
} else {
    if ($env:OS -ne 'Windows_NT') { throw 'SetWinEventHook listener requires Windows.' }
    Initialize-TbgWindowEventNative
    $hooks = New-Object System.Collections.Generic.List[IntPtr]
    $nativeEvents = @(0x8000, 0x8001, 0x8002, 0x8003, 0x800C, 0x0003)
    try {
        foreach ($nativeEvent in $nativeEvents) {
            $hook = [TbgWindowEventNative]::SetWinEventHook([uint32]$nativeEvent, [uint32]$nativeEvent, [IntPtr]::Zero, [TbgWindowEventNative]::Handler, [uint32]0, [uint32]0, [uint32][TbgWindowEventNative]::WINEVENT_OUTOFCONTEXT)
            if ($hook -eq [IntPtr]::Zero) { throw "SetWinEventHook failed for event 0x$('{0:X}' -f $nativeEvent)." }
            $hooks.Add($hook) | Out-Null
        }
        Write-TbgObserverEvent -EventType 'observer.health' -Source 'hook' -Payload @{ state = 'listening'; hookCount = $hooks.Count; launchPollMilliseconds = $LaunchPollMilliseconds; stablePollMilliseconds = $StablePollMilliseconds } | Out-Null
        $started = Get-Date
        $nextPoll = Get-Date
        $deadline = $started.AddSeconds([Math]::Max(1, $DurationSeconds))
        while ((Get-Date) -lt $deadline) {
            $record = $null
            while ([TbgWindowEventNative]::Queue.TryDequeue([ref]$record)) {
                $eventType = Get-TbgEventType -NativeEvent $record.EventType
                if ($null -eq $eventType -or -not (Test-TbgTargetWindow -TargetProcessId $record.ProcessId -TargetHwnd $record.Hwnd)) { continue }
                Publish-TbgCandidate -EventType $eventType -Source 'hook' -TargetProcessId $record.ProcessId -TargetHwnd $record.Hwnd -Payload @{ nativeEvent = ('0x{0:X}' -f $record.EventType); disposition = if ($eventType -eq 'window.destroyed') { 'disappearance_only' } else { 'observation_only' } }
            }
            if ((Get-Date) -ge $nextPoll) {
                Invoke-TbgReconciliation
                $interval = if (((Get-Date) - $started).TotalSeconds -lt $StableAfterSeconds) { $LaunchPollMilliseconds } else { $StablePollMilliseconds }
                $nextPoll = (Get-Date).AddMilliseconds([Math]::Max(50, $interval))
            }
            Start-Sleep -Milliseconds 20
        }
    } catch {
        Write-TbgObserverEvent -EventType 'observer.gap' -Source 'listener' -Severity 'error' -Payload @{ reason = 'listener_failure'; detail = $_.Exception.Message } | Out-Null
        throw
    } finally {
        foreach ($hook in $hooks) { [void][TbgWindowEventNative]::UnhookWinEvent($hook) }
    }
}

$runContext.completedUtc = [DateTime]::UtcNow.ToString('o')
$runContext | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $contextPath -Encoding UTF8
$status = [ordered]@{
    schema = 'TbgRuntimeObserverStatus.v1'
    runId = $script:runId
    correlationId = $script:correlationId
    observerId = 'windows-window-event-listener'
    status = 'completed'
    eventCount = $script:eventCount
    deduplicatedCrossSourceEvents = $script:deduplicated
    completedUtc = $runContext.completedUtc
    proofLevel = 'harness'
    proofBoundary = 'Window disappearance is observation only and never application acceptance, process loss, or crash confirmation.'
}
$statusPath = Join-Path $runRoot 'observer-status.json'
$status | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $statusPath -Encoding UTF8
Write-Host ("Window event listener completed: {0} events, {1} cross-source duplicates suppressed." -f $script:eventCount, $script:deduplicated)
if ($PassThru) {
    return [pscustomobject]@{ runId = $script:runId; correlationId = $script:correlationId; eventsPath = $script:eventsPath; statusPath = $statusPath; eventCount = $script:eventCount; deduplicated = $script:deduplicated }
}
