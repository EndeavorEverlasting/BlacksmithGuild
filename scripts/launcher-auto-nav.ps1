# Pre-main-menu UI automation: PLAY/CONTINUE, CAUTION Confirm, Safe Mode No (Sprint 006E).
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('play', 'continue')]
    [string]$LaunchIntent,

    [Parameter(Mandatory = $true)]
    [string]$BannerlordRoot,

    [int]$TimeoutSec = 300,
    [int]$PollMs = 180,
    [bool]$RespectUserForeground = $true,
    [ValidateSet('continue', 'play', 'any')]
    [string]$CertTarget = 'any',
    [bool]$AllowCertRetry = $false,
    [int]$CertRetryAttempt = 0,
    [string]$ExternalStateTimelinePath = $null,
    [switch]$LaunchSetup,
    [int]$LauncherSelectionMaxMs = 30000,
    # Focus policy: by default the launcher respects the user's foreground window and never steals
    # focus. Aggressive focus-steal escalation (real foreground clicks) only happens when the
    # operator explicitly opts in with -AllowFocusSteal.
    [switch]$AllowFocusSteal
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'f7-launch-contract.ps1')
. (Join-Path $PSScriptRoot 'f7-external-state-classifier.ps1')
. (Join-Path $PSScriptRoot 'process-lifecycle-authority.ps1')
. (Join-Path $PSScriptRoot 'pr11-process-window-classifier.ps1')
$lockPath = Get-NavLockPath -BannerlordRoot $BannerlordRoot
$lockMaxAgeMin = 10
$script:navLockHeld = $false
$script:operatorGuardedClickDeniedCount = 0

function Get-NavLockOwnerPid {
    if (-not (Test-Path -LiteralPath $lockPath)) { return 0 }
    try {
        $text = Get-Content -LiteralPath $lockPath -Raw -ErrorAction Stop
        $match = [regex]::Match($text, '(?m)^pid=([0-9]+)\s*$')
        if ($match.Success) { return [int]$match.Groups[1].Value }
    } catch { }
    return 0
}

function Test-NavLockActive {
    if (-not (Test-Path -LiteralPath $lockPath)) { return $false }
    $ownerPid = Get-NavLockOwnerPid
    if ($ownerPid -gt 0 -and -not (Get-Process -Id $ownerPid -ErrorAction SilentlyContinue)) {
        Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
        return $false
    }
    $age = (Get-Date) - (Get-Item -LiteralPath $lockPath).LastWriteTime
    if ($age.TotalMinutes -ge $lockMaxAgeMin) {
        Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
        return $false
    }
    return $true
}

function Acquire-NavLock {
    if (Test-NavLockActive) {
        throw "launcher nav already running (lock $lockPath age < ${lockMaxAgeMin} min) — stop ForgeContinue/F7/Run-LauncherNavNow first"
    }
    $lockBody = "pid=$PID`nstarted=$(Get-Date -Format o)`nintent=$LaunchIntent"
    Set-Content -LiteralPath $lockPath -Value $lockBody -Encoding UTF8
    $script:navLockHeld = $true
}

function Release-NavLock {
    if (-not $script:navLockHeld) { return }
    Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
    $script:navLockHeld = $false
}

Acquire-NavLock

$logPath = Get-LaunchLogPath -BannerlordRoot $BannerlordRoot
$launcherExeName = 'TaleWorlds.MountAndBlade.Launcher'
$gameExeName = 'Bannerlord'
$windowSnapshotS1Path = Join-Path $BannerlordRoot 'window-snapshot-S1-pre-launch.json'
$windowSnapshotS2Path = Join-Path $BannerlordRoot 'window-snapshot-S2-post-launch.json'
$windowDeltaCandidatesPath = Join-Path $BannerlordRoot 'window-delta-candidates.json'
$chosenLaunchWindowPath = Join-Path $BannerlordRoot 'chosen-launch-window.json'
$launchSelectionArtifactPath = Join-Path $BannerlordRoot 'launch-selection.json'
$script:launcherSelectionBaselineSnapshot = $null
$script:lastLauncherWindowDeltaDecision = $null
$script:lastLauncherWindowCandidates = @()
$script:lastLauncherWindowDeltaRefreshUtc = $null

function Write-LaunchLog {
    param([string]$Message)
    $line = "[{0}] launcher-auto: {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
    Write-Host $line -ForegroundColor DarkGray
}

function Save-TbgLauncherWindowArtifact {
    param(
        [AllowNull()]$Object,
        [Parameter(Mandatory = $true)][string]$Path
    )

    if (Get-Command Save-Pr11JsonArtifact -ErrorAction SilentlyContinue) {
        Save-Pr11JsonArtifact -Object $Object -Path $Path | Out-Null
        return
    }

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    if ($null -eq $Object) {
        'null' | Set-Content -LiteralPath $Path -Encoding UTF8
    }
    elseif ($Object -is [System.Array] -and $Object.Count -eq 0) {
        '[]' | Set-Content -LiteralPath $Path -Encoding UTF8
    }
    else {
        $Object | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8
    }
}

function Write-TbgLauncherSelectionDecisionArtifact {
    param(
        $Decision,
        $ChosenWindow = $null
    )

    $payload = [ordered]@{
        updatedAtUtc   = (Get-Date).ToUniversalTime().ToString('o')
        intent         = [string]$LaunchIntent
        selectionBasis = 'S1_to_S2_window_delta'
        allowed        = [bool]($Decision -and $Decision.allowed)
        reason         = if ($Decision) { [string]$Decision.reason } else { 'no_decision' }
        candidateCount = @($script:lastLauncherWindowCandidates).Count
        chosenWindow   = $ChosenWindow
    }
    Save-TbgLauncherWindowArtifact -Object $payload -Path $launchSelectionArtifactPath
}

function Test-TbgLauncherDeltaMenuReady {
    param($Decision = $script:lastLauncherWindowDeltaDecision)

    if (-not $Decision -or -not $Decision.allowed -or -not $Decision.winner) { return $false }
    if ([int64]$Decision.winner.hwnd -eq 0) { return $false }
    if ([int]$Decision.winner.score -lt $script:Pr11ClickConfidenceThreshold) { return $false }
    return ([string]$Decision.winner.processName -match 'Bannerlord|TaleWorlds')
}

function Update-TbgLauncherWindowDeltaSelection {
    param([switch]$Force)

    if (-not $script:launcherSelectionBaselineSnapshot) {
        return $null
    }

    if (-not [UIAHelper]::HasLauncherRoot()) {
        $script:lastLauncherWindowCandidates = @()
        $script:lastLauncherWindowDeltaDecision = [pscustomobject][ordered]@{
            allowed = $false
            reason  = 'no_launcher_root'
            winner  = $null
            tied    = @()
        }
        [UIAHelper]::ClearPreferredLauncherWindow()
        Save-TbgLauncherWindowArtifact -Object @() -Path $windowDeltaCandidatesPath
        Save-TbgLauncherWindowArtifact -Object $null -Path $chosenLaunchWindowPath
        Write-TbgLauncherSelectionDecisionArtifact -Decision $script:lastLauncherWindowDeltaDecision -ChosenWindow $null
        return $script:lastLauncherWindowDeltaDecision
    }

    if (-not $Force -and $script:lastLauncherWindowDeltaRefreshUtc -and (((Get-Date) - $script:lastLauncherWindowDeltaRefreshUtc).TotalSeconds -lt 1)) {
        return $script:lastLauncherWindowDeltaDecision
    }

    $s2 = Get-Pr11ProcessSnapshot -Label 'S2_post_launch' -BannerlordRoot $BannerlordRoot
    $script:lastLauncherWindowDeltaRefreshUtc = Get-Date
    Save-TbgLauncherWindowArtifact -Object $s2 -Path $windowSnapshotS2Path

    $delta = Compare-Pr11ProcessSnapshots -BaselineSnapshot $script:launcherSelectionBaselineSnapshot -AfterSnapshot $s2
    $candidates = @(Get-Pr11WindowCandidates -Delta $delta -BannerlordRoot $BannerlordRoot `
        -LaunchRequestedUtc $startTime.ToUniversalTime() `
        -UiaPlayVisible ([UIAHelper]::IsLauncherPlayOnlyVisible()) `
        -UiaContinueVisible ([UIAHelper]::IsLauncherContinueVisible()))

    $script:lastLauncherWindowCandidates = $candidates
    Save-TbgLauncherWindowArtifact -Object $candidates -Path $windowDeltaCandidatesPath

    $decision = Test-Pr11ClickAllowed -Candidates $candidates
    $script:lastLauncherWindowDeltaDecision = $decision

    if ($decision.allowed -and $decision.winner -and [int64]$decision.winner.hwnd -ne 0) {
        [UIAHelper]::SetPreferredLauncherWindow([int64]$decision.winner.hwnd, [int]$decision.winner.pid, [int]$decision.winner.score, [string]$decision.reason)
        Save-TbgLauncherWindowArtifact -Object $decision.winner -Path $chosenLaunchWindowPath
        Write-TbgLauncherSelectionDecisionArtifact -Decision $decision -ChosenWindow $decision.winner
        $winnerLine = 'AUDIT launcher delta winner: pid={0} hwnd={1} score={2} title={3} reason={4}' -f $decision.winner.pid, $decision.winner.hwnd, $decision.winner.score, $decision.winner.windowTitle, $decision.reason
        Write-LaunchLog $winnerLine
    }
    else {
        [UIAHelper]::ClearPreferredLauncherWindow()
        Save-TbgLauncherWindowArtifact -Object $null -Path $chosenLaunchWindowPath
        Write-TbgLauncherSelectionDecisionArtifact -Decision $decision -ChosenWindow $null
        $blockedLine = 'AUDIT launcher delta blocked: reason={0} candidates={1}' -f $decision.reason, @($candidates).Count
        Write-LaunchLog $blockedLine
    }

    return $decision
}

function Invoke-OperatorInteractiveFocusPrompt {
    param([string]$Reason)
    if ($env:TBG_OPERATOR_INTERACTIVE_FOCUS -ne '1') { return $false }
    Write-LaunchLog "LAUNCH_STATE=operator_focus_required reason=$Reason"
    Write-Host ''
    Write-Host 'Launcher focus required.' -ForegroundColor Yellow
    Write-Host 'Bring the Bannerlord launcher to the front, then press Enter to continue.' -ForegroundColor Yellow
    Write-Host 'Press C to cancel.' -ForegroundColor Yellow
    $answer = Read-Host 'Continue or C'
    if ($answer -and $answer.Trim().ToUpperInvariant() -eq 'C') {
        Write-LaunchLog 'LAUNCH_STATE=user_cancelled operator focus prompt'
        throw 'USER CANCELLED: launcher focus unavailable'
    }
    $script:operatorGuardedClickDeniedCount = 0
    return $true
}

function Get-NavExternalStateMode {
    if ((Get-Command Test-F7ContinueCertStrict -ErrorAction SilentlyContinue) -and (Test-F7ContinueCertStrict)) {
        return 'cert'
    }
    if ($LaunchSetup) {
        return 'assistive_launch_setup'
    }
    return 'assistive'
}

function Initialize-NavExternalStateTimelineIfNeeded {
    if (-not $ExternalStateTimelinePath) { return }
    if ($script:F7ExternalStateTimeline) { return }
    Initialize-F7ExternalStateTimeline -Mode (Get-NavExternalStateMode) -OutputPath $ExternalStateTimelinePath
}

function Write-NavExternalStateEvent {
    param([string]$ReasonOverride = $null)

    if (-not $ExternalStateTimelinePath) { return }
    Initialize-NavExternalStateTimelineIfNeeded
    $launchPath = if ($script:adoptedLaunchPath) { [string]$script:adoptedLaunchPath } else { 'unknown' }
    $selectedBy = if ($script:adoptedSelectedBy) { [string]$script:adoptedSelectedBy } else { 'unknown' }
    $null = Emit-F7ExternalStateTimelineCheckpoint -BannerlordRoot $BannerlordRoot `
        -Mode (Get-NavExternalStateMode) -StatusPath (Get-StatusJsonPath -BannerlordRoot $BannerlordRoot) `
        -Phase1Path (Get-Phase1LogPath -BannerlordRoot $BannerlordRoot) `
        -CertTarget $CertTarget -LaunchPath $launchPath -LaunchSelectedBy $selectedBy `
        -TargetMismatch ([bool]$script:contaminatedLaunchPath) `
        -LaunchState $(if ($script:contaminatedLaunchPath) { 'contaminated_launch_path' } else { 'nav_poll' }) `
        -ReasonOverride $ReasonOverride -Force
}

function Test-NavGuardedLauncherClick {
    param([string]$Intent)

    $action = if ($Intent -eq 'continue') { 'click_launcher_continue' } else { 'click_launcher_play' }
    $mode = Get-NavExternalStateMode
    $hasLauncherRoot = [UIAHelper]::HasLauncherRoot()
    $deltaDecision = $null
    if ($hasLauncherRoot) {
        $deltaDecision = Update-TbgLauncherWindowDeltaSelection
    }

    $classifiedState = 'UnknownWindowState'
    if ([UIAHelper]::IsLauncherPlayContinueVisible()) {
        $classifiedState = 'LauncherMenu'
    } elseif (Test-TbgLauncherDeltaMenuReady -Decision $deltaDecision) {
        $classifiedState = 'LauncherMenu'
    } elseif ($hasLauncherRoot) {
        $classifiedState = 'LauncherOpening'
    } else {
        $det = Get-LaunchNavProcessDetection
        $classifiedState = Resolve-F7ProcessClassifiedState -Detection $det
    }

    $allowed = Test-F7GuardedActionAllowed -Mode $mode -Action $action -ClassifiedState $classifiedState
    if (-not $allowed) {
        Write-LaunchLog "LAUNCH_STATE=unknown_window_state reason=guarded_click_denied action=$action mode=$mode state=$classifiedState"
        Write-NavExternalStateEvent -ReasonOverride "Guarded click denied for action=$action state=$classifiedState"
    }
    return [bool]$allowed
}

if (-not ('UIAHelper' -as [type])) {
    $uiaHelperSource = @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Automation;

public static class UIAHelper
{
    private const string LauncherProcessName = "TaleWorlds.MountAndBlade.Launcher";
    private const string GameProcessName = "Bannerlord";
    private const string CrashReporterTitle = "*_*";
    private const string ModuleMismatchTitle = "Module Mismatch";

    public static Action<string> Log;
    public static bool RespectUserForeground = true;

    private static bool _launcherFocused;
    private static bool _launcherAuditDone;
    private static DateTime _lastLauncherMissLogUtc = DateTime.MinValue;
    private static DateTime _firstLauncherWindowSeenUtc = DateTime.MinValue;
    private static DateTime _lastCoordClickUtc = DateTime.MinValue;
    private static int _coordAttemptIndex = 0;
    private static readonly double[] LauncherPlayXFractions = new double[] { 0.34, 0.38, 0.30 };
    private static readonly double[] LauncherContinueXFractions = new double[] { 0.55, 0.58, 0.52, 0.62 };
    private static readonly double[] LauncherCoordYFractions = new double[] { 0.90, 0.88 };
    private static readonly double[] ModuleMismatchYesXFractions = new double[] { 0.54, 0.56, 0.52 };
    private static readonly double[] ModuleMismatchYesYFractions = new double[] { 0.58, 0.56, 0.60 };
    private const int LauncherStableSecBeforeFallback = 1;
    private const int LauncherCoordClickThrottleSec = 1;
    private const int LauncherMinCoordWindowWidth = 800;
    private const int LauncherMinCoordWindowHeight = 600;
    private static bool _moduleMismatchAuditDone;
    private static int _moduleMismatchCoordAttemptIndex;
    private static HashSet<int> _baselineProcessIds = null;
    private static IntPtr _preferredLauncherWindowHwnd = IntPtr.Zero;
    private static int _preferredLauncherWindowPid = 0;
    private static int _preferredLauncherWindowScore = 0;
    private static string _preferredLauncherWindowReason = null;

    // Before/after PID diff: snapshot the launcher/game-family process IDs that exist BEFORE we
    // trigger a launch, so the genuinely NEW game-hosting process can be identified afterward
    // regardless of its process name. Steam frequently hosts the running game under the launcher
    // process name, which defeats name-only detection and forces a coordinate/title fallback.
    public static void CaptureBaselineProcessIds()
    {
        var ids = new HashSet<int>();
        foreach (var name in new[] { GameProcessName, LauncherProcessName })
        {
            try
            {
                foreach (var p in Process.GetProcessesByName(name))
                {
                    try { ids.Add(p.Id); } catch { }
                }
            }
            catch { }
        }
        _baselineProcessIds = ids;
        LogLine("AUDIT baseline process snapshot: " + ids.Count + " pre-launch launcher/game pids");
    }

    // PIDs in the launcher/game process family that were NOT present at baseline capture, i.e. the
    // process(es) our launch spawned. Under Steam in-launcher hosting these are the strongest
    // game-window candidates even when their process name is the launcher's.
    private static HashSet<int> GetNewProcessIdsSinceBaseline()
    {
        var newIds = new HashSet<int>();
        if (_baselineProcessIds == null) { return newIds; }
        foreach (var name in new[] { GameProcessName, LauncherProcessName })
        {
            try
            {
                foreach (var p in Process.GetProcessesByName(name))
                {
                    try { if (!_baselineProcessIds.Contains(p.Id)) { newIds.Add(p.Id); } }
                    catch { }
                }
            }
            catch { }
        }
        return newIds;
    }

    public static void SetPreferredLauncherWindow(long hwnd, int pid = 0, int score = 0, string reason = null)
    {
        _preferredLauncherWindowHwnd = hwnd == 0 ? IntPtr.Zero : new IntPtr(hwnd);
        _preferredLauncherWindowPid = pid;
        _preferredLauncherWindowScore = score;
        _preferredLauncherWindowReason = reason ?? string.Empty;
        LogLine(string.Format(
            "AUDIT preferred launcher window set hwnd={0} pid={1} score={2} reason={3}",
            hwnd, pid, score, _preferredLauncherWindowReason));
    }

    public static void ClearPreferredLauncherWindow()
    {
        if (_preferredLauncherWindowHwnd != IntPtr.Zero || _preferredLauncherWindowPid != 0)
        {
            LogLine(string.Format(
                "AUDIT preferred launcher window cleared hwnd={0} pid={1}",
                _preferredLauncherWindowHwnd, _preferredLauncherWindowPid));
        }
        _preferredLauncherWindowHwnd = IntPtr.Zero;
        _preferredLauncherWindowPid = 0;
        _preferredLauncherWindowScore = 0;
        _preferredLauncherWindowReason = null;
    }

    private static bool MatchesPreferredLauncherWindow(AutomationElement window)
    {
        if (window == null) return false;
        try
        {
            var hwnd = new IntPtr(window.Current.NativeWindowHandle);
            if (_preferredLauncherWindowHwnd != IntPtr.Zero && hwnd == _preferredLauncherWindowHwnd)
            {
                return true;
            }
            if (_preferredLauncherWindowPid > 0 && window.Current.ProcessId == _preferredLauncherWindowPid)
            {
                return true;
            }
        }
        catch { }
        return false;
    }

    private static AutomationElement FindPreferredLauncherWindow(List<AutomationElement> windows)
    {
        if (windows == null || windows.Count == 0) return null;
        foreach (var window in windows)
        {
            if (MatchesPreferredLauncherWindow(window))
            {
                return window;
            }
        }
        return null;
    }

    private static List<AutomationElement> OrderLauncherWindowsForSelection(List<AutomationElement> windows)
    {
        if (windows == null || windows.Count <= 1) return windows;
        var preferred = FindPreferredLauncherWindow(windows);
        if (preferred == null) return windows;

        var ordered = new List<AutomationElement>();
        ordered.Add(preferred);
        foreach (var window in windows)
        {
            try
            {
                if (window.Current.NativeWindowHandle == preferred.Current.NativeWindowHandle)
                {
                    continue;
                }
            }
            catch { }
            ordered.Add(window);
        }

        LogLine("AUDIT launcher window order: preferred first " + DescribeScope(preferred));
        return ordered;
    }

    private static void LogLine(string message)
    {
        if (Log == null) return;
        try { Log(message); } catch { }
    }

    // Never click AutomationElement.RootElement — only scoped Bannerlord windows/dialogs.

    public static string ClickButtonByNameInLauncher(string[] names, bool requireEnabled = true)
    {
        if (names == null || names.Length == 0) return null;

        var windows = FindAllLauncherWindowRoots();
        windows = OrderLauncherWindowsForSelection(windows);
        if (windows.Count == 0)
        {
            LogLauncherMissThrottled("CLICK SKIP launcher buttons — TaleWorlds launcher process has no UIA windows yet (desktop never searched)");
            return null;
        }

        if (_firstLauncherWindowSeenUtc == DateTime.MinValue)
        {
            _firstLauncherWindowSeenUtc = DateTime.UtcNow;
        }

        if (!_launcherFocused && !RespectUserForeground)
        {
            var focusTarget = FindPreferredLauncherWindow(windows) ?? GetBestLauncherWindowForCoords(windows) ?? windows[0];
            FocusScope(focusTarget, "launcher");
            _launcherFocused = true;
        }

        foreach (var window in windows)
        {
            var element = FindClickableInScope(window, names, requireEnabled);
            if (element == null) continue;

            var matchedName = element.Current.Name ?? names[0];
            var scopeDesc = DescribeScope(window);
            LogLine(string.Format("CLICK \"launcher PLAY/CONTINUE\" button=\"{0}\" in {1} | foreground before {2}", matchedName, scopeDesc, DescribeForegroundWindow()));
            if (InvokeElement(element, "launcher PLAY/CONTINUE", matchedName, scopeDesc))
            {
                return matchedName;
            }
        }

        var globalElement = FindNamedElementInLauncherProcess(names, requireEnabled);
        if (globalElement != null)
        {
            var matchedName = globalElement.Current.Name ?? names[0];
            var scopeDesc = string.Format("PID-global process={0} pid={1}", LauncherProcessName, globalElement.Current.ProcessId);
            LogLine(string.Format("CLICK \"launcher PLAY/CONTINUE\" button=\"{0}\" in {1} | foreground before {2}", matchedName, scopeDesc, DescribeForegroundWindow()));
            if (InvokeElement(globalElement, "launcher PLAY/CONTINUE", matchedName, scopeDesc))
            {
                return matchedName;
            }
        }

        var launcherStable = (DateTime.UtcNow - _firstLauncherWindowSeenUtc).TotalSeconds >= LauncherStableSecBeforeFallback;
        if (launcherStable && !IsCoordClickThrottled())
        {
            var coordIntent = NamesIndicateContinue(names) ? "continue" : "play";
            var coordWindow = GetBestLauncherWindowForCoords(windows);
            if (coordWindow != null)
            {
                FocusScope(coordWindow, "launcher coords prep");
                if (TryClickLauncherByCoordinates(coordWindow, coordIntent))
                {
                    _lastCoordClickUtc = DateTime.UtcNow;
                    _coordAttemptIndex++;
                    return names[0];
                }
            }
        }

        if (!_launcherAuditDone && launcherStable)
        {
            _launcherAuditDone = true;
            LogLauncherControlAudit(windows);
            LogLauncherPidNamedElementsAudit();
            LogLine("AUDIT launcher buttons: " + LogVisibleLauncherButtons());
        }

        LogLauncherMissThrottled("CLICK SKIP launcher PLAY/CONTINUE — not found in " + windows.Count + " launcher window(s) (scoped + PID-global + coords)");
        return null;
    }

    private static bool NamesIndicateContinue(string[] names)
    {
        if (names == null) return false;
        foreach (var name in names)
        {
            if (NameMatchesTarget(name, "CONTINUE") || NameMatchesTarget(name, "Continue"))
            {
                return true;
            }
        }
        return false;
    }

    private static AutomationElement FindNamedElementInLauncherProcess(string[] names, bool requireEnabled)
    {
        var pids = GetLauncherProcessIds();
        if (pids.Count == 0 || names == null || names.Length == 0) return null;

        foreach (var targetName in names)
        {
            try
            {
                var condition = new PropertyCondition(AutomationElement.NameProperty, targetName);
                var elements = AutomationElement.RootElement.FindAll(TreeScope.Descendants, condition);
                foreach (AutomationElement element in elements)
                {
                    try
                    {
                        if (!pids.Contains(element.Current.ProcessId)) continue;
                        if (requireEnabled && !element.Current.IsEnabled) continue;
                        return element;
                    }
                    catch { }
                }
            }
            catch { }
        }

        var controlTypes = new[] { ControlType.Button, ControlType.Custom, ControlType.Hyperlink, ControlType.Text, ControlType.ListItem };
        foreach (var controlType in controlTypes)
        {
            try
            {
                var typeCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, controlType);
                var elements = AutomationElement.RootElement.FindAll(TreeScope.Descendants, typeCondition);
                foreach (AutomationElement element in elements)
                {
                    try
                    {
                        if (!pids.Contains(element.Current.ProcessId)) continue;
                        var name = element.Current.Name ?? string.Empty;
                        foreach (var target in names)
                        {
                            if (!NameMatchesTargetLoose(name, target)) continue;
                            if (requireEnabled && !element.Current.IsEnabled) continue;
                            return element;
                        }
                    }
                    catch { }
                }
            }
            catch { }
        }

        return null;
    }

    public static void ResetLauncherClickRetryState()
    {
        _lastCoordClickUtc = DateTime.MinValue;
    }

    private static bool IsCoordClickThrottled()
    {
        if (_lastCoordClickUtc == DateTime.MinValue) return false;
        return (DateTime.UtcNow - _lastCoordClickUtc).TotalSeconds < LauncherCoordClickThrottleSec;
    }

    private static AutomationElement GetBestLauncherWindowForCoords(List<AutomationElement> windows)
    {
        if (windows == null || windows.Count == 0) return null;

        var preferred = FindPreferredLauncherWindow(windows);
        if (preferred != null)
        {
            LogLine(string.Format(
                "AUDIT coord window pick: preferred delta candidate {0} score={1} reason={2}",
                DescribeScope(preferred), _preferredLauncherWindowScore, _preferredLauncherWindowReason ?? string.Empty));
            return preferred;
        }

        AutomationElement best = null;
        double bestScore = -1;

        foreach (var window in windows)
        {
            try
            {
                var title = window.Current.Name ?? string.Empty;
                if (title.IndexOf("Singleplayer PID", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    continue;
                }

                var rect = window.Current.BoundingRectangle;
                if (rect.Width < 400 || rect.Height < 300)
                {
                    continue;
                }

                var area = rect.Width * rect.Height;
                var score = area;

                if (title.Equals("MB II: Bannerlord", StringComparison.OrdinalIgnoreCase) ||
                    title.Equals("M&B II: Bannerlord", StringComparison.OrdinalIgnoreCase))
                {
                    score *= 10;
                }
                else if (title.IndexOf("Bannerlord", StringComparison.OrdinalIgnoreCase) >= 0 &&
                         title.IndexOf("Singleplayer", StringComparison.OrdinalIgnoreCase) < 0)
                {
                    score *= 2;
                }

                if (score > bestScore)
                {
                    bestScore = score;
                    best = window;
                }
            }
            catch { }
        }

        if (best != null)
        {
            LogLine("AUDIT coord window pick: " + DescribeScope(best));
            return best;
        }

        foreach (var window in windows)
        {
            try
            {
                var title = window.Current.Name ?? string.Empty;
                var rect = window.Current.BoundingRectangle;
                var minW = title.IndexOf("Singleplayer PID", StringComparison.OrdinalIgnoreCase) >= 0
                    ? 400
                    : LauncherMinCoordWindowWidth;
                var minH = title.IndexOf("Singleplayer PID", StringComparison.OrdinalIgnoreCase) >= 0
                    ? 300
                    : LauncherMinCoordWindowHeight;
                if (rect.Width < minW || rect.Height < minH)
                {
                    continue;
                }

                LogLine("AUDIT coord window pick: no PLAY/CONTINUE chrome window — falling back to " + DescribeScope(window));
                return window;
            }
            catch { }
        }

        LogLine("AUDIT coord window pick: no suitable launcher window for coords");
        return null;
    }

    private static bool TryGetLauncherClientClickPoint(IntPtr hwnd, double xFraction, double yFraction, out int screenX, out int screenY)
    {
        screenX = 0;
        screenY = 0;
        if (hwnd == IntPtr.Zero) return false;

        RECT clientRect;
        if (!GetClientRect(hwnd, out clientRect))
        {
            return false;
        }

        var clientW = clientRect.Right - clientRect.Left;
        var clientH = clientRect.Bottom - clientRect.Top;
        if (clientW <= 0 || clientH <= 0) return false;

        var clientPoint = new POINT
        {
            X = (int)(clientW * xFraction),
            Y = (int)(clientH * yFraction)
        };

        if (!ClientToScreen(hwnd, ref clientPoint))
        {
            return false;
        }

        screenX = clientPoint.X;
        screenY = clientPoint.Y;
        return true;
    }

    private static bool TryClickLauncherByCoordinates(AutomationElement launcherWindow, string intent)
    {
        if (launcherWindow == null || string.IsNullOrWhiteSpace(intent)) return false;

        try
        {
            var hwnd = new IntPtr(launcherWindow.Current.NativeWindowHandle);
            if (hwnd == IntPtr.Zero)
            {
                LogLine("CLICK SKIP launcher coords — launcher hwnd is zero");
                return false;
            }

            var bounds = launcherWindow.Current.BoundingRectangle;
            if (bounds.Width <= 0 || bounds.Height <= 0)
            {
                LogLine("CLICK SKIP launcher coords — launcher window has zero-size bounds");
                return false;
            }

            var xFractions = intent == "continue" ? LauncherContinueXFractions : LauncherPlayXFractions;
            var xFraction = xFractions[_coordAttemptIndex % xFractions.Length];
            var yFraction = LauncherCoordYFractions[_coordAttemptIndex % LauncherCoordYFractions.Length];
            int x;
            int y;
            if (!TryGetLauncherClientClickPoint(hwnd, xFraction, yFraction, out x, out y))
            {
                x = (int)(bounds.X + bounds.Width * xFraction);
                y = (int)(bounds.Y + bounds.Height * yFraction);
                LogLine("CLICK WARN launcher coords — using UIA bounds fallback for client rect");
            }
            var scopeDesc = DescribeScope(launcherWindow);
            var label = intent == "continue" ? "launcher CONTINUE" : "launcher PLAY";

            LogHitWindowAtPoint(x, y, label, intent);
            var visuallyObscured = !IsScreenPointOnLauncherHwnd(hwnd, x, y);
            if (visuallyObscured)
            {
                LogLine(string.Format(
                    "CLICK NOTE launcher coords — visual hit-test not {0} at ({1},{2}); proceeding with hwnd-target SendMessage (background-safe per doctrine)",
                    LauncherProcessName, x, y));
            }

            LogLine(string.Format(
                "CLICK \"{0}\" intent={1} attempt={2} method=coords at ({3},{4}) fractions=({5:F2},{6:F2}) bounds=({7:F0},{8:F0},{9:F0},{10:F0}) in {11} | foreground {12}",
                label, intent, _coordAttemptIndex + 1, x, y, xFraction, yFraction, bounds.X, bounds.Y, bounds.Width, bounds.Height, scopeDesc, DescribeForegroundWindow()));

            // Custom-rendered launchers (e.g. "MB II: Bannerlord") ignore synthetic WM_LBUTTON*
            // messages, so SendMessage reports success but the CONTINUE/PLAY button never fires
            // and the click never verifies. When foreground control is permitted, drive the click
            // with real hardware input at the screen point — the method that actually registers.
            if (!RespectUserForeground)
            {
                ForceForegroundWindow(hwnd);
                Thread.Sleep(120);
                SetCursorPos(x, y);
                Thread.Sleep(40);
                mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
                mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
                Thread.Sleep(200);
                LogLine(string.Format("CLICK OK \"launcher PLAY/CONTINUE\" intent={0} method=real-input-mouse_event at ({1},{2}) in {3}", intent, x, y, scopeDesc));
                TryFocusGameOrLauncher();
                return true;
            }

            if (TryClickLauncherHwndAtScreenPoint(hwnd, x, y, scopeDesc, label))
            {
                Thread.Sleep(200);
                var method = visuallyObscured ? "hwnd SendMessage-background" : "hwnd SendMessage-first";
                LogLine(string.Format("CLICK OK \"launcher PLAY/CONTINUE\" intent={0} method={1} at ({2},{3}) in {4}", intent, method, x, y, scopeDesc));
                return true;
            }

            var savedUserForeground = GetForegroundWindow();
            ForceForegroundWindow(hwnd);
            Thread.Sleep(100);
            var clicked = TryClickLauncherHwndAtScreenPoint(hwnd, x, y, scopeDesc, label);
            if (!clicked)
            {
                SetCursorPos(x, y);
                Thread.Sleep(40);
                mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
                mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
                clicked = true;
            }
            if (clicked)
            {
                LogLine(string.Format("CLICK OK \"launcher PLAY/CONTINUE\" intent={0} method=brief-focus+restore at ({1},{2}) in {3}", intent, x, y, scopeDesc));
            }
            if (savedUserForeground != IntPtr.Zero && savedUserForeground != hwnd)
            {
                ForceForegroundWindow(savedUserForeground);
                LogLine("FOCUS restored user foreground after brief launcher click");
            }
            return clicked;
        }
        catch (Exception ex)
        {
            LogLine("CLICK FAIL launcher coords: " + ex.Message);
            return false;
        }
    }

    private static bool IsHwndOwnedByLauncher(IntPtr hwnd)
    {
        if (hwnd == IntPtr.Zero) return false;
        try
        {
            uint pid;
            GetWindowThreadProcessId(hwnd, out pid);
            return GetLauncherProcessIds().Contains((int)pid);
        }
        catch
        {
            return false;
        }
    }

    private static bool IsScreenPointOnLauncherHwnd(IntPtr launcherHwnd, int screenX, int screenY)
    {
        if (launcherHwnd == IntPtr.Zero) return false;

        try
        {
            var point = new POINT { X = screenX, Y = screenY };
            var hit = WindowFromPoint(point);
            if (hit == IntPtr.Zero) return false;

            if (hit == launcherHwnd) return true;

            var root = GetAncestor(hit, GA_ROOT);
            if (root == launcherHwnd) return true;

            return IsHwndOwnedByLauncher(hit);
        }
        catch
        {
            return false;
        }
    }

    private static void LogHitWindowAtPoint(int screenX, int screenY, string label, string intent)
    {
        try
        {
            var point = new POINT { X = screenX, Y = screenY };
            var hit = WindowFromPoint(point);
            if (hit == IntPtr.Zero)
            {
                LogLine(string.Format("AUDIT hit-test intent={0} label={1} at ({2},{3}) hwnd=none launcher_ok=false", intent, label, screenX, screenY));
                return;
            }

            var sb = new StringBuilder(256);
            GetWindowText(hit, sb, sb.Capacity);
            uint hitPid;
            GetWindowThreadProcessId(hit, out hitPid);
            var procName = "?";
            try { procName = Process.GetProcessById((int)hitPid).ProcessName; } catch { }
            var launcherOk = string.Equals(procName, LauncherProcessName, StringComparison.OrdinalIgnoreCase);
            LogLine(string.Format(
                "AUDIT hit-test intent={0} label={1} at ({2},{3}) hwnd={4} title=\"{5}\" process={6} pid={7} launcher_ok={8}",
                intent, label, screenX, screenY, hit.ToInt64(), sb.ToString(), procName, hitPid, launcherOk ? "true" : "false"));
        }
        catch (Exception ex)
        {
            LogLine("AUDIT hit-test failed: " + ex.Message);
        }
    }

    public static void LogLauncherPidNamedElementsAudit()
    {
        var pids = GetLauncherProcessIds();
        if (pids.Count == 0)
        {
            LogLine("AUDIT launcher PID-named elements: (no launcher PIDs)");
            return;
        }

        var names = new List<string>();
        var controlTypes = new[] { ControlType.Button, ControlType.Custom, ControlType.Hyperlink, ControlType.Text, ControlType.ListItem };
        foreach (var controlType in controlTypes)
        {
            try
            {
                var typeCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, controlType);
                var elements = AutomationElement.RootElement.FindAll(TreeScope.Descendants, typeCondition);
                foreach (AutomationElement element in elements)
                {
                    try
                    {
                        if (!pids.Contains(element.Current.ProcessId)) continue;
                        var name = element.Current.Name;
                        if (!string.IsNullOrWhiteSpace(name) && !names.Contains(name))
                        {
                            names.Add(name);
                        }
                    }
                    catch { }
                }
            }
            catch { }
        }

        LogLine(string.Format("AUDIT launcher PID-named elements: {0} (count={1})", names.Count == 0 ? "(none)" : string.Join(", ", names.ToArray()), names.Count));
    }

    private static void LogLauncherMissThrottled(string message)
    {
        var now = DateTime.UtcNow;
        if ((now - _lastLauncherMissLogUtc).TotalSeconds < 10) return;
        _lastLauncherMissLogUtc = now;
        LogLine(message);
    }

    private static bool NameMatchesTarget(string elementName, string targetName)
    {
        if (string.IsNullOrWhiteSpace(elementName) || string.IsNullOrWhiteSpace(targetName)) return false;
        return string.Equals(elementName.Trim(), targetName.Trim(), StringComparison.OrdinalIgnoreCase);
    }

    private static string NormalizeButtonName(string elementName)
    {
        if (string.IsNullOrWhiteSpace(elementName)) return string.Empty;
        return elementName.Trim().TrimStart('&');
    }

    private static bool NameMatchesTargetLoose(string elementName, string targetName)
    {
        if (string.IsNullOrWhiteSpace(elementName) || string.IsNullOrWhiteSpace(targetName)) return false;
        if (NameMatchesTarget(elementName, targetName)) return true;

        var normalized = NormalizeButtonName(elementName);
        var target = NormalizeButtonName(targetName);
        if (string.Equals(normalized, target, StringComparison.OrdinalIgnoreCase)) return true;

        if (target.Equals("CONTINUE", StringComparison.OrdinalIgnoreCase))
        {
            return normalized.IndexOf("Continue", StringComparison.OrdinalIgnoreCase) >= 0
                && normalized.IndexOf("Custom", StringComparison.OrdinalIgnoreCase) < 0
                && normalized.IndexOf("Play", StringComparison.OrdinalIgnoreCase) < 0;
        }

        if (target.Equals("PLAY", StringComparison.OrdinalIgnoreCase))
        {
            return normalized.Equals("Play", StringComparison.OrdinalIgnoreCase)
                || normalized.Equals("PLAY", StringComparison.OrdinalIgnoreCase);
        }

        return false;
    }

    private static AutomationElement FindClickableInScope(AutomationElement scope, string[] targetNames, bool requireEnabled)
    {
        if (scope == null || targetNames == null || targetNames.Length == 0) return null;

        var controlTypes = new[] { ControlType.Button, ControlType.Custom, ControlType.Hyperlink };
        foreach (var controlType in controlTypes)
        {
            try
            {
                var typeCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, controlType);
                var elements = scope.FindAll(TreeScope.Descendants, typeCondition);
                foreach (AutomationElement element in elements)
                {
                    var name = element.Current.Name ?? string.Empty;
                    foreach (var target in targetNames)
                    {
                        if (!NameMatchesTargetLoose(name, target)) continue;
                        if (requireEnabled && !element.Current.IsEnabled) continue;
                        return element;
                    }
                }
            }
            catch { }
        }

        return null;
    }

    private static HashSet<int> GetLauncherProcessIds()
    {
        var ids = new HashSet<int>();
        foreach (var process in Process.GetProcessesByName(LauncherProcessName))
        {
            try { ids.Add(process.Id); } catch { }
        }
        return ids;
    }

    private static bool IsLauncherForegroundHwnd(IntPtr launcherHwnd, HashSet<int> launcherPids)
    {
        try
        {
            var fg = GetForegroundWindow();
            if (fg == IntPtr.Zero) return false;
            if (fg == launcherHwnd) return true;

            var root = GetAncestor(fg, GA_ROOT);
            if (root == launcherHwnd) return true;

            uint pid;
            GetWindowThreadProcessId(fg, out pid);
            return launcherPids.Contains((int)pid);
        }
        catch
        {
            return false;
        }
    }

    private static void ForceForegroundWindow(IntPtr hwnd)
    {
        if (hwnd == IntPtr.Zero) return;

        try
        {
            var fg = GetForegroundWindow();
            uint fgPid;
            uint fgThread = GetWindowThreadProcessId(fg, out fgPid);
            uint targetPid;
            uint targetThread = GetWindowThreadProcessId(hwnd, out targetPid);
            uint currentThread = GetCurrentThreadId();

            if (fgThread != 0 && fgThread != currentThread)
            {
                AttachThreadInput(currentThread, fgThread, true);
            }
            if (targetThread != 0 && targetThread != currentThread)
            {
                AttachThreadInput(currentThread, targetThread, true);
            }

            ShowWindow(hwnd, SW_RESTORE);
            BringWindowToTop(hwnd);
            SetForegroundWindow(hwnd);
            Thread.Sleep(200);

            if (fgThread != 0 && fgThread != currentThread)
            {
                AttachThreadInput(currentThread, fgThread, false);
            }
            if (targetThread != 0 && targetThread != currentThread)
            {
                AttachThreadInput(currentThread, targetThread, false);
            }
        }
        catch { }
    }

    private static bool TryClickLauncherHwndAtScreenPoint(IntPtr hwnd, int screenX, int screenY, string scopeDesc, string label)
    {
        if (hwnd == IntPtr.Zero) return false;

        if (!IsHwndOwnedByLauncher(hwnd))
        {
            LogLine("CLICK SKIP launcher hwnd — target hwnd is not owned by " + LauncherProcessName + " (" + scopeDesc + ")");
            return false;
        }

        try
        {
            var point = new POINT { X = screenX, Y = screenY };
            if (!ScreenToClient(hwnd, ref point))
            {
                LogLine("CLICK SKIP launcher hwnd — ScreenToClient failed for " + scopeDesc);
                return false;
            }

            var lParam = MakeLParam(point.X, point.Y);
            LogLine(string.Format(
                "CLICK \"{0}\" method=hwnd SendMessage at client ({1},{2}) screen ({3},{4}) in {5}",
                label, point.X, point.Y, screenX, screenY, scopeDesc));

            SendMessage(hwnd, WM_LBUTTONDOWN, MK_LBUTTON, lParam);
            Thread.Sleep(40);
            SendMessage(hwnd, WM_LBUTTONUP, 0, lParam);
            LogLine(string.Format("CLICK hwnd SendMessage at ({0},{1}) in {2}", screenX, screenY, scopeDesc));
            return true;
        }
        catch (Exception ex)
        {
            LogLine("CLICK FAIL launcher hwnd: " + ex.Message);
            return false;
        }
    }

    private static DateTime _lastLauncherRestoreUtc = DateTime.MinValue;

    public static int TryRestoreLauncherWindows()
    {
        var now = DateTime.UtcNow;
        if ((now - _lastLauncherRestoreUtc).TotalSeconds < 2) return 0;
        _lastLauncherRestoreUtc = now;

        var restored = 0;
        foreach (var pid in GetLauncherProcessIds())
        {
            EnumWindows((hwnd, param) =>
            {
                try
                {
                    uint windowPid;
                    GetWindowThreadProcessId(hwnd, out windowPid);
                    if ((int)windowPid != pid) return true;

                    var sb = new StringBuilder(256);
                    GetWindowText(hwnd, sb, sb.Capacity);
                    if (sb.Length == 0) return true;

                    if (!IsIconic(hwnd)) return true;

                    ShowWindow(hwnd, SW_RESTORE);
                    restored++;
                }
                catch { }
                return true;
            }, IntPtr.Zero);
        }

        if (restored > 0)
        {
            Thread.Sleep(400);
        }

        return restored;
    }

    private static List<AutomationElement> FindAllLauncherWindowRoots()
    {
        var results = new List<AutomationElement>();
        var pids = GetLauncherProcessIds();
        if (pids.Count == 0) return results;

        try
        {
            var windowCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Window);
            var windows = AutomationElement.RootElement.FindAll(TreeScope.Children, windowCondition);
            foreach (AutomationElement window in windows)
            {
                try
                {
                    if (!pids.Contains(window.Current.ProcessId)) continue;
                    if (!ContainsWindow(results, window))
                    {
                        results.Add(window);
                    }
                }
                catch { }
            }
        }
        catch { }

        foreach (var pid in pids)
        {
            try
            {
                CollectLauncherWindowsFromPid(pid, results);
                var process = Process.GetProcessById(pid);
                var hwnd = process.MainWindowHandle;
                if (hwnd == IntPtr.Zero) continue;
                var fromHandle = AutomationElement.FromHandle(hwnd);
                if (fromHandle != null && !ContainsWindow(results, fromHandle))
                {
                    results.Add(fromHandle);
                }
            }
            catch { }
        }

        if (results.Count == 0)
        {
            TryRestoreLauncherWindows();
            try
            {
                var windowCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Window);
                var windows = AutomationElement.RootElement.FindAll(TreeScope.Children, windowCondition);
                foreach (AutomationElement window in windows)
                {
                    try
                    {
                        if (!pids.Contains(window.Current.ProcessId)) continue;
                        if (!ContainsWindow(results, window))
                        {
                            results.Add(window);
                        }
                    }
                    catch { }
                }
            }
            catch { }

            foreach (var pid in pids)
            {
                try
                {
                    CollectLauncherWindowsFromPid(pid, results);
                    var process = Process.GetProcessById(pid);
                    var hwnd = process.MainWindowHandle;
                    if (hwnd == IntPtr.Zero) continue;
                    var fromHandle = AutomationElement.FromHandle(hwnd);
                    if (fromHandle != null && !ContainsWindow(results, fromHandle))
                    {
                        results.Add(fromHandle);
                    }
                }
                catch { }
            }
        }

        return results;
    }

    private static void CollectLauncherWindowsFromPid(int pid, List<AutomationElement> results)
    {
        EnumWindows((hwnd, param) =>
        {
            try
            {
                uint windowPid;
                GetWindowThreadProcessId(hwnd, out windowPid);
                if ((int)windowPid != pid) return true;
                if (!IsWindowVisible(hwnd)) return true;
                var fromHandle = AutomationElement.FromHandle(hwnd);
                if (fromHandle != null && !ContainsWindow(results, fromHandle))
                {
                    results.Add(fromHandle);
                }
            }
            catch { }
            return true;
        }, IntPtr.Zero);
    }

    private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    private static bool ContainsWindow(List<AutomationElement> list, AutomationElement candidate)
    {
        foreach (var existing in list)
        {
            try
            {
                if (existing.Current.NativeWindowHandle == candidate.Current.NativeWindowHandle)
                {
                    return true;
                }
            }
            catch { }
        }
        return false;
    }

    public static void LogLauncherControlAudit(List<AutomationElement> windows)
    {
        var parts = new List<string>();
        foreach (var window in windows)
        {
            try
            {
                var title = window.Current.Name ?? string.Empty;
                var controls = new List<string>();
                CollectInteractiveNames(window, controls);
                parts.Add(string.Format("{0}=[{1}]", title, controls.Count == 0 ? "(none)" : string.Join(", ", controls.ToArray())));
            }
            catch (Exception ex)
            {
                parts.Add("audit-error=" + ex.Message);
            }
        }

        LogLine("AUDIT launcher controls: " + string.Join(" | ", parts.ToArray()));
    }

    private static void CollectInteractiveNames(AutomationElement scope, List<string> names)
    {
        if (scope == null) return;

        var controlTypes = new[] { ControlType.Button, ControlType.Custom, ControlType.Hyperlink, ControlType.Text };
        foreach (var controlType in controlTypes)
        {
            try
            {
                var typeCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, controlType);
                var elements = scope.FindAll(TreeScope.Descendants, typeCondition);
                foreach (AutomationElement element in elements)
                {
                    var name = element.Current.Name;
                    if (!string.IsNullOrWhiteSpace(name) && !names.Contains(name))
                    {
                        names.Add(name);
                    }
                }
            }
            catch { }
        }
    }

    public static bool HasCrashReporterDialog()
    {
        var crashRoot = FindCrashReporterRoot();
        if (crashRoot == null) return false;

        if (HasGameMainWindow()) return false;

        return ScopeContainsText(crashRoot, "application faced a problem");
    }

    public static bool HasGameMainWindow()
    {
        return FindGameMainWindowRoot() != null;
    }

    public static bool TryFocusGameOrLauncher()
    {
        var game = FindGameMainWindowRoot();
        if (game != null)
        {
            try
            {
                var hwnd = new IntPtr(game.Current.NativeWindowHandle);
                if (hwnd != IntPtr.Zero)
                {
                    ForceForegroundWindow(hwnd);
                    LogLine("FOCUS refocus game/launcher after click target=game | " + DescribeForegroundWindow());
                    return true;
                }
            }
            catch { }
        }

        var launcher = FindLauncherRoot();
        if (launcher != null)
        {
            try
            {
                var hwnd = new IntPtr(launcher.Current.NativeWindowHandle);
                if (hwnd != IntPtr.Zero)
                {
                    ForceForegroundWindow(hwnd);
                    LogLine("FOCUS refocus game/launcher after click target=launcher | " + DescribeForegroundWindow());
                    return true;
                }
            }
            catch { }
        }

        LogLine("FOCUS refocus game/launcher after click — no game or launcher hwnd");
        return false;
    }

    public static bool HasLauncherRoot()
    {
        return FindAllLauncherWindowRoots().Count > 0 || GetLauncherProcessIds().Count > 0;
    }

    public static bool HasLauncherLoadingSurface()
    {
        foreach (var window in FindAllLauncherWindowRoots())
        {
            try
            {
                var title = window.Current.Name ?? string.Empty;
                if (title.IndexOf("Singleplayer PID", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    return true;
                }
            }
            catch { }
        }

        return false;
    }

    public static bool ClickCrashReporterNo()
    {
        var crashRoot = FindCrashReporterRoot();
        if (crashRoot != null)
        {
            FocusScope(crashRoot, "crash reporter");
            if (TryClickButtonInScope(crashRoot, "No", false, "crash reporter No"))
                return true;
        }

        // Fallback: native Win32 close when UIA cannot see the dialog
        return NativeCloseCrashDialog();
    }

    private static bool NativeCloseCrashDialog()
    {
        var hwnd = FindWindow(null, CrashReporterTitle);
        if (hwnd == IntPtr.Zero)
        {
            // Try alternate title patterns
            hwnd = FindWindow(null, "*_*");
        }
        if (hwnd == IntPtr.Zero) return false;

        LogLine(string.Format("NATIVE CRASH CLOSE hwnd=0x{0:X8}", (long)hwnd));
        SetForegroundWindow(hwnd);
        Thread.Sleep(100);
        SendMessage(hwnd, 0x0111, (IntPtr)7, IntPtr.Zero);   // WM_COMMAND IDNO
        SendMessage(hwnd, 0x0010, IntPtr.Zero, IntPtr.Zero);  // WM_CLOSE
        PostMessage(hwnd, 0x0010, IntPtr.Zero, IntPtr.Zero);  // WM_CLOSE
        return true;
    }

    public static string LogVisibleLauncherButtons()
    {
        var names = new List<string>();
        var windows = FindAllLauncherWindowRoots();
        if (windows.Count == 0) return "launcher window not found";

        foreach (var window in windows)
        {
            CollectButtonNames(window, names);
            CollectInteractiveNames(window, names);
        }

        if (names.Count == 0) return "no launcher buttons visible in " + windows.Count + " window(s)";
        return string.Join(", ", names.ToArray());
    }

    public static bool HasSafeModeDialog()
    {
        return FindWindowRootByTitle("Safe Mode") != null;
    }

    public static bool IsLauncherPlayContinueVisible()
    {
        var names = new List<string>();
        var windows = FindAllLauncherWindowRoots();
        if (windows.Count == 0) return false;

        foreach (var window in windows)
        {
            CollectButtonNames(window, names);
            CollectInteractiveNames(window, names);
        }

        foreach (var name in names)
        {
            var normalized = NormalizeButtonName(name);
            if (normalized.IndexOf("Continue", StringComparison.OrdinalIgnoreCase) >= 0
                && normalized.IndexOf("Custom", StringComparison.OrdinalIgnoreCase) < 0)
            {
                return true;
            }

            if (normalized.Equals("Play", StringComparison.OrdinalIgnoreCase)
                || normalized.Equals("PLAY", StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }
        }

        return false;
    }

    private static void CollectLauncherButtonNames(List<string> names)
    {
        var windows = FindAllLauncherWindowRoots();
        if (windows.Count == 0) return;
        foreach (var window in windows)
        {
            CollectButtonNames(window, names);
            CollectInteractiveNames(window, names);
        }
    }

    public static bool IsLauncherContinueVisible()
    {
        var names = new List<string>();
        CollectLauncherButtonNames(names);
        foreach (var name in names)
        {
            var normalized = NormalizeButtonName(name);
            if (normalized.IndexOf("Continue", StringComparison.OrdinalIgnoreCase) >= 0
                && normalized.IndexOf("Custom", StringComparison.OrdinalIgnoreCase) < 0)
            {
                return true;
            }
        }
        return false;
    }

    public static bool IsLauncherPlayOnlyVisible()
    {
        var names = new List<string>();
        CollectLauncherButtonNames(names);
        var hasPlay = false;
        var hasContinue = false;
        foreach (var name in names)
        {
            var normalized = NormalizeButtonName(name);
            if (normalized.IndexOf("Continue", StringComparison.OrdinalIgnoreCase) >= 0
                && normalized.IndexOf("Custom", StringComparison.OrdinalIgnoreCase) < 0)
            {
                hasContinue = true;
            }
            if (normalized.Equals("Play", StringComparison.OrdinalIgnoreCase)
                || normalized.Equals("PLAY", StringComparison.OrdinalIgnoreCase))
            {
                hasPlay = true;
            }
        }
        return hasPlay && !hasContinue;
    }

    public static bool ClickSafeModeNo()
    {
        var safeModeRoot = FindWindowRootByTitle("Safe Mode");
        if (safeModeRoot == null) return false;

        FocusScope(safeModeRoot, "Safe Mode");
        foreach (var name in new[] { "No", "&No", "NO" })
        {
            if (TryClickButtonInScope(safeModeRoot, name, false, "Safe Mode No"))
            {
                return true;
            }
        }

        var noButton = FindNoButtonInScope(safeModeRoot);
        if (noButton != null)
        {
            var scopeDesc = DescribeScope(safeModeRoot);
            if (InvokeElement(noButton, "Safe Mode No", NormalizeButtonName(noButton.Current.Name), scopeDesc))
            {
                return true;
            }
        }

        return TryClickSafeModeNoByCoords(safeModeRoot);
    }

    private static AutomationElement FindNoButtonInScope(AutomationElement scope)
    {
        if (scope == null) return null;

        var controlTypes = new[] { ControlType.Button, ControlType.Custom, ControlType.Hyperlink };
        foreach (var controlType in controlTypes)
        {
            try
            {
                var typeCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, controlType);
                var elements = scope.FindAll(TreeScope.Descendants, typeCondition);
                foreach (AutomationElement element in elements)
                {
                    var normalized = NormalizeButtonName(element.Current.Name ?? string.Empty);
                    if (normalized.Equals("No", StringComparison.OrdinalIgnoreCase))
                    {
                        return element;
                    }
                }
            }
            catch { }
        }

        return null;
    }

    private static bool TryClickSafeModeNoByCoords(AutomationElement safeModeRoot)
    {
        if (safeModeRoot == null) return false;

        try
        {
            var hwnd = new IntPtr(safeModeRoot.Current.NativeWindowHandle);
            if (hwnd == IntPtr.Zero) return false;

            var bounds = safeModeRoot.Current.BoundingRectangle;
            if (bounds.Width <= 0 || bounds.Height <= 0) return false;

            var x = (int)(bounds.X + bounds.Width * 0.32);
            var y = (int)(bounds.Y + bounds.Height * 0.72);
            var scopeDesc = DescribeScope(safeModeRoot);

            LogLine(string.Format("CLICK \"Safe Mode No\" method=coords at ({0},{1}) in {2}", x, y, scopeDesc));
            if (TryClickLauncherHwndAtScreenPoint(hwnd, x, y, scopeDesc, "Safe Mode No"))
            {
                LogLine("CLICK OK \"Safe Mode No\" method=hwnd-only");
                return true;
            }
            var savedUserForeground = GetForegroundWindow();
            ForceForegroundWindow(hwnd);
            Thread.Sleep(80);
            if (TryClickLauncherHwndAtScreenPoint(hwnd, x, y, scopeDesc, "Safe Mode No"))
            {
                if (savedUserForeground != IntPtr.Zero && savedUserForeground != hwnd)
                {
                    ForceForegroundWindow(savedUserForeground);
                    LogLine("FOCUS restored user foreground after Safe Mode click");
                }
                LogLine("CLICK OK \"Safe Mode No\" method=brief-focus+restore");
                return true;
            }
            SetCursorPos(x, y);
            Thread.Sleep(40);
            mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
            mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
            if (savedUserForeground != IntPtr.Zero && savedUserForeground != hwnd)
            {
                ForceForegroundWindow(savedUserForeground);
                LogLine("FOCUS restored user foreground after Safe Mode click");
            }
            return true;
        }
        catch (Exception ex)
        {
            LogLine("CLICK FAIL Safe Mode coords: " + ex.Message);
            return false;
        }
    }

    public static bool HasCautionDialog()
    {
        return FindCautionDialogRoot() != null;
    }

    public static bool ClickCautionConfirm()
    {
        var cautionRoot = FindCautionDialogRoot();
        if (cautionRoot == null) return false;

        FocusScope(cautionRoot, "CAUTION");
        return TryClickButtonInScope(cautionRoot, "Confirm", true, "CAUTION Confirm");
    }

    public static bool HasModuleMismatchDialog()
    {
        return FindModuleMismatchDialogRoot() != null;
    }

    public static string LogVisibleModuleMismatchButtons()
    {
        var names = new List<string>();
        var scope = FindModuleMismatchDialogRoot();
        if (scope == null) return "Module Mismatch dialog not found";

        CollectButtonNames(scope, names);
        if (names.Count == 0) return "no Module Mismatch buttons visible";
        return string.Join(", ", names.ToArray());
    }

    public static bool ClickModuleMismatchYes()
    {
        var scope = FindModuleMismatchDialogRoot();
        if (scope == null) return false;

        FocusScope(scope, "Module Mismatch");
        foreach (var name in new[] { "Yes", "OK", "Continue" })
        {
            if (TryClickButtonInScope(scope, name, false, "Module Mismatch " + name))
            {
                return true;
            }
        }

        var globalElement = FindNamedElementInGameProcess(new[] { "Yes", "OK", "Continue" }, false);
        if (globalElement != null)
        {
            var matchedName = globalElement.Current.Name ?? "Yes";
            var scopeDesc = string.Format("PID-global process={0} pid={1}", GameProcessName, globalElement.Current.ProcessId);
            if (InvokeElement(globalElement, "Module Mismatch Yes", matchedName, scopeDesc))
            {
                return true;
            }
        }

        var game = FindGameMainWindowRoot();
        if (game != null && TryClickModuleMismatchYesByCoordinates(game))
        {
            return true;
        }

        if (!_moduleMismatchAuditDone)
        {
            _moduleMismatchAuditDone = true;
            LogLine("AUDIT Module Mismatch game elements: " + LogModuleMismatchGameElements());
        }

        return false;
    }

    public static bool ClickModuleMismatchYesByGameCoords()
    {
        var game = FindGameMainWindowRoot();
        if (game == null) return false;

        FocusScope(game, "Module Mismatch coord fallback");
        return TryClickModuleMismatchYesByCoordinates(game);
    }

    private static AutomationElement FindLauncherRoot()
    {
        var preferred = FindPreferredLauncherWindow(FindAllLauncherWindowRoots());
        if (preferred != null)
        {
            return preferred;
        }
        return FindProcessMainWindowRoot(LauncherProcessName);
    }

    private static AutomationElement FindGameMainWindowRoot()
    {
        return FindProcessMainWindowRoot(GameProcessName);
    }

    private static AutomationElement FindProcessMainWindowRoot(string processName)
    {
        var processes = Process.GetProcessesByName(processName);
        foreach (var process in processes)
        {
            try
            {
                var hwnd = process.MainWindowHandle;
                if (hwnd != IntPtr.Zero)
                {
                    return AutomationElement.FromHandle(hwnd);
                }
            }
            catch { }
        }

        return null;
    }

    private static AutomationElement FindCrashReporterRoot()
    {
        var hwnd = FindWindow(null, CrashReporterTitle);
        if (hwnd != IntPtr.Zero)
        {
            try { return AutomationElement.FromHandle(hwnd); } catch { }
        }

        return FindWindowRootByTitle("*_*");
    }

    private static AutomationElement FindCautionDialogRoot()
    {
        var launcher = FindLauncherRoot();
        if (launcher != null && ScopeContainsNamedElement(launcher, "CAUTION"))
        {
            return launcher;
        }

        return FindWindowRootByTitle("CAUTION");
    }

    private static AutomationElement FindModuleMismatchDialogRoot()
    {
        var byTitle = FindWindowRootByTitle(ModuleMismatchTitle);
        if (byTitle != null) return byTitle;

        var launcher = FindLauncherRoot();
        if (launcher != null && ScopeContainsExactModuleMismatch(launcher))
        {
            return launcher;
        }

        var game = FindGameMainWindowRoot();
        if (game != null && ScopeContainsExactModuleMismatch(game))
        {
            return game;
        }

        if (FindModuleMismatchInGameProcess())
        {
            return FindGameMainWindowRoot();
        }

        return null;
    }

    private static bool FindModuleMismatchInGameProcess()
    {
        var pids = GetGameProcessIds();
        if (pids.Count == 0) return false;

        var fragments = new[] { ModuleMismatchTitle, "different modules" };
        var controlTypes = new[] { ControlType.Text, ControlType.Custom, ControlType.Button, ControlType.Group, ControlType.Pane, ControlType.Document };
        foreach (var controlType in controlTypes)
        {
            try
            {
                var typeCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, controlType);
                var elements = AutomationElement.RootElement.FindAll(TreeScope.Descendants, typeCondition);
                foreach (AutomationElement element in elements)
                {
                    try
                    {
                        if (!pids.Contains(element.Current.ProcessId)) continue;
                        var name = element.Current.Name ?? string.Empty;
                        foreach (var fragment in fragments)
                        {
                            if (name.IndexOf(fragment, StringComparison.OrdinalIgnoreCase) >= 0)
                            {
                                return true;
                            }
                        }
                    }
                    catch { }
                }
            }
            catch { }
        }

        return false;
    }

    private static AutomationElement FindWindowRootByTitle(string titleFragment)
    {
        if (string.IsNullOrWhiteSpace(titleFragment)) return null;

        try
        {
            var windowCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Window);
            var windows = AutomationElement.RootElement.FindAll(TreeScope.Children, windowCondition);
            foreach (AutomationElement window in windows)
            {
                var title = window.Current.Name ?? string.Empty;
                if (title.IndexOf(titleFragment, StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    LogLine(string.Format("DIALOG MATCH title=\"{0}\" matched=\"{1}\"", title, titleFragment));
                    return window;
                }
            }
        }
        catch { }

        return null;
    }

    private static bool ScopeContainsExactModuleMismatch(AutomationElement scope)
    {
        return ScopeContainsFragment(scope, ModuleMismatchTitle, "different modules");
    }

    private static bool ScopeContainsFragment(AutomationElement scope, params string[] fragments)
    {
        if (scope == null || fragments == null || fragments.Length == 0) return false;

        var controlTypes = new[] { ControlType.Text, ControlType.Custom, ControlType.Button, ControlType.Group, ControlType.Pane, ControlType.Document };
        foreach (var controlType in controlTypes)
        {
            try
            {
                var typeCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, controlType);
                var elements = scope.FindAll(TreeScope.Descendants, typeCondition);
                foreach (AutomationElement element in elements)
                {
                    var name = element.Current.Name ?? string.Empty;
                    foreach (var fragment in fragments)
                    {
                        if (!string.IsNullOrWhiteSpace(fragment)
                            && name.IndexOf(fragment, StringComparison.OrdinalIgnoreCase) >= 0)
                        {
                            return true;
                        }
                    }
                }
            }
            catch { }
        }

        return false;
    }

    private static bool ScopeContainsNamedElement(AutomationElement scope, string name)
    {
        if (scope == null || string.IsNullOrWhiteSpace(name)) return false;

        try
        {
            var condition = new PropertyCondition(AutomationElement.NameProperty, name);
            return scope.FindFirst(TreeScope.Descendants, condition) != null;
        }
        catch { return false; }
    }

    private static bool ScopeContainsText(AutomationElement scope, string fragment)
    {
        if (scope == null || string.IsNullOrWhiteSpace(fragment)) return false;

        try
        {
            var textCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text);
            var textElements = scope.FindAll(TreeScope.Descendants, textCondition);
            foreach (AutomationElement element in textElements)
            {
                var name = element.Current.Name ?? string.Empty;
                if (name.IndexOf(fragment, StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    return true;
                }
            }
        }
        catch { }

        return false;
    }

    private static void CollectButtonNames(AutomationElement scope, List<string> names)
    {
        if (scope == null) return;

        var controlTypes = new[] { ControlType.Button, ControlType.Custom, ControlType.Hyperlink };
        foreach (var controlType in controlTypes)
        {
            try
            {
                var typeCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, controlType);
                var buttons = scope.FindAll(TreeScope.Descendants, typeCondition);
                foreach (AutomationElement button in buttons)
                {
                    var name = button.Current.Name;
                    if (!string.IsNullOrWhiteSpace(name) && !names.Contains(name))
                    {
                        names.Add(name);
                    }
                }
            }
            catch { }
        }
    }

    private static HashSet<int> GetGameProcessIds()
    {
        var ids = new HashSet<int>();
        foreach (var process in Process.GetProcessesByName(GameProcessName))
        {
            try { ids.Add(process.Id); } catch { }
        }
        // Before/after diff: also treat processes that appeared after baseline capture as game-host
        // candidates, so in-game elements are reachable even when the game runs under the launcher
        // process name (Steam in-launcher hosting). Purely additive: name-matched PIDs are kept.
        foreach (var newId in GetNewProcessIdsSinceBaseline())
        {
            ids.Add(newId);
        }
        return ids;
    }

    private static AutomationElement FindNamedElementInGameProcess(string[] names, bool requireEnabled)
    {
        var pids = GetGameProcessIds();
        if (pids.Count == 0 || names == null || names.Length == 0) return null;

        foreach (var targetName in names)
        {
            try
            {
                var condition = new PropertyCondition(AutomationElement.NameProperty, targetName);
                var elements = AutomationElement.RootElement.FindAll(TreeScope.Descendants, condition);
                foreach (AutomationElement element in elements)
                {
                    try
                    {
                        if (!pids.Contains(element.Current.ProcessId)) continue;
                        if (requireEnabled && !element.Current.IsEnabled) continue;
                        return element;
                    }
                    catch { }
                }
            }
            catch { }
        }

        var controlTypes = new[] { ControlType.Button, ControlType.Custom, ControlType.Hyperlink, ControlType.Text, ControlType.ListItem };
        foreach (var controlType in controlTypes)
        {
            try
            {
                var typeCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, controlType);
                var elements = AutomationElement.RootElement.FindAll(TreeScope.Descendants, typeCondition);
                foreach (AutomationElement element in elements)
                {
                    try
                    {
                        if (!pids.Contains(element.Current.ProcessId)) continue;
                        var name = element.Current.Name ?? string.Empty;
                        foreach (var target in names)
                        {
                            if (!NameMatchesTargetLoose(name, target)) continue;
                            if (requireEnabled && !element.Current.IsEnabled) continue;
                            return element;
                        }
                    }
                    catch { }
                }
            }
            catch { }
        }

        return null;
    }

    private static bool TryClickModuleMismatchYesByCoordinates(AutomationElement gameWindow)
    {
        if (gameWindow == null) return false;

        try
        {
            var hwnd = new IntPtr(gameWindow.Current.NativeWindowHandle);
            if (hwnd == IntPtr.Zero) return false;

            var bounds = gameWindow.Current.BoundingRectangle;
            var xFraction = ModuleMismatchYesXFractions[_moduleMismatchCoordAttemptIndex % ModuleMismatchYesXFractions.Length];
            var yFraction = ModuleMismatchYesYFractions[_moduleMismatchCoordAttemptIndex % ModuleMismatchYesYFractions.Length];
            int x;
            int y;
            if (!TryGetLauncherClientClickPoint(hwnd, xFraction, yFraction, out x, out y))
            {
                x = (int)(bounds.X + bounds.Width * xFraction);
                y = (int)(bounds.Y + bounds.Height * yFraction);
            }

            var scopeDesc = DescribeScope(gameWindow);
            LogLine(string.Format(
                "CLICK \"Module Mismatch Yes\" method=coords at ({0},{1}) fractions=({2:F2},{3:F2}) in {4}",
                x, y, xFraction, yFraction, scopeDesc));
            if (TryClickLauncherHwndAtScreenPoint(hwnd, x, y, scopeDesc, "Module Mismatch Yes"))
            {
                LogLine("CLICK OK \"Module Mismatch Yes\" method=hwnd-only");
                _moduleMismatchCoordAttemptIndex++;
                return true;
            }
            if (!RespectUserForeground)
            {
                ForceForegroundWindow(hwnd);
                Thread.Sleep(250);
                TryClickLauncherHwndAtScreenPoint(hwnd, x, y, scopeDesc, "Module Mismatch Yes");
                SetCursorPos(x, y);
                Thread.Sleep(80);
                mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
                mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
                _moduleMismatchCoordAttemptIndex++;
                return true;
            }
            return false;
        }
        catch (Exception ex)
        {
            LogLine("CLICK FAIL Module Mismatch coords: " + ex.Message);
            return false;
        }
    }

    private static string LogModuleMismatchGameElements()
    {
        var names = new List<string>();
        var game = FindGameMainWindowRoot();
        if (game != null)
        {
            CollectButtonNames(game, names);
            CollectInteractiveNames(game, names);
        }

        if (names.Count == 0) return "no named game elements in Bannerlord scope";
        return string.Join(", ", names.ToArray());
    }

    private static void FocusScope(AutomationElement scope, string reason)
    {
        if (scope == null) return;

        LogLine(string.Format("FOCUS request ({0}) target={1} | before {2}", reason, DescribeScope(scope), DescribeForegroundWindow()));

        if (RespectUserForeground)
        {
            LogLine(string.Format("FOCUS skipped ({0}) — RespectUserForeground", reason));
            return;
        }

        try
        {
            var hwnd = new IntPtr(scope.Current.NativeWindowHandle);
            if (hwnd != IntPtr.Zero)
            {
                SetForegroundWindow(hwnd);
                Thread.Sleep(60);
            }
        }
        catch (Exception ex)
        {
            LogLine("FOCUS failed: " + ex.Message);
            return;
        }

        LogLine(string.Format("FOCUS done ({0}) | after {1}", reason, DescribeForegroundWindow()));
    }

    private static bool TryClickButtonInScope(AutomationElement scope, string name, bool requireEnabled, string actionLabel)
    {
        if (scope == null || string.IsNullOrWhiteSpace(name)) return false;

        var scopeDesc = DescribeScope(scope);
        var label = string.IsNullOrWhiteSpace(actionLabel) ? name : actionLabel;

        try
        {
            var condition = new PropertyCondition(AutomationElement.NameProperty, name);
            var element = scope.FindFirst(TreeScope.Descendants, condition);
            if (element == null)
            {
                return false;
            }

            LogLine(string.Format("CLICK \"{0}\" button=\"{1}\" in {2} | foreground before {3}", label, name, scopeDesc, DescribeForegroundWindow()));
            return InvokeElement(element, label, name, scopeDesc);
        }
        catch (Exception ex)
        {
            LogLine(string.Format("CLICK FAIL \"{0}\" button=\"{1}\" in {2}: {3}", label, name, scopeDesc, ex.Message));
            return false;
        }
    }

    private static bool InvokeElement(AutomationElement element, string actionLabel, string buttonName, string scopeDesc)
    {
        try
        {
            object pattern;
            if (element.TryGetCurrentPattern(InvokePattern.Pattern, out pattern))
            {
                InvokePattern invokePattern = pattern as InvokePattern;
                if (invokePattern != null)
                {
                    invokePattern.Invoke();
                    LogLine(string.Format("CLICK OK \"{0}\" button=\"{1}\" method=InvokePattern in {2} | foreground after {3}", actionLabel, buttonName, scopeDesc, DescribeForegroundWindow()));
                    return true;
                }
            }
        }
        catch (Exception ex)
        {
            LogLine(string.Format("CLICK InvokePattern failed \"{0}\": {1}", actionLabel, ex.Message));
        }

        try
        {
            var rect = element.Current.BoundingRectangle;
            if (rect.Width <= 0 || rect.Height <= 0)
            {
                LogLine(string.Format("CLICK FAIL \"{0}\" — zero-size bounds in {1}", actionLabel, scopeDesc));
                return false;
            }
            var x = (int)(rect.X + rect.Width / 2);
            var y = (int)(rect.Y + rect.Height / 2);
            var hwnd = new IntPtr(element.Current.NativeWindowHandle);
            if (hwnd != IntPtr.Zero && TryClickLauncherHwndAtScreenPoint(hwnd, x, y, scopeDesc, actionLabel))
            {
                LogLine(string.Format("CLICK OK \"{0}\" button=\"{1}\" method=hwnd-only in {2} | foreground after {3}", actionLabel, buttonName, scopeDesc, DescribeForegroundWindow()));
                if (!RespectUserForeground)
                {
                    TryFocusGameOrLauncher();
                }
                return true;
            }
            if (!RespectUserForeground)
            {
                SetCursorPos(x, y);
                Thread.Sleep(60);
                mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
                mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
                LogLine(string.Format("CLICK OK \"{0}\" button=\"{1}\" method=mouse at ({2},{3}) in {4} | foreground after {5}", actionLabel, buttonName, x, y, scopeDesc, DescribeForegroundWindow()));
                TryFocusGameOrLauncher();
                return true;
            }
            LogLine(string.Format("CLICK FAIL \"{0}\" — SendMessage failed and RespectUserForeground=true", actionLabel));
            return false;
        }
        catch (Exception ex)
        {
            LogLine(string.Format("CLICK FAIL \"{0}\" mouse click: {1}", actionLabel, ex.Message));
            return false;
        }
    }

    public static string DescribeScope(AutomationElement scope)
    {
        if (scope == null) return "scope=null";
        try
        {
            var name = scope.Current.Name ?? string.Empty;
            var pid = scope.Current.ProcessId;
            var procName = "?";
            try { procName = Process.GetProcessById(pid).ProcessName; } catch { }
            return string.Format("window=\"{0}\" process={1} pid={2}", name, procName, pid);
        }
        catch
        {
            return "scope=unknown";
        }
    }

    public static string DescribeForegroundWindow()
    {
        try
        {
            var hwnd = GetForegroundWindow();
            if (hwnd == IntPtr.Zero) return "foreground=none";

            var sb = new StringBuilder(512);
            GetWindowText(hwnd, sb, sb.Capacity);
            var title = sb.ToString();

            uint pid;
            GetWindowThreadProcessId(hwnd, out pid);
            var procName = "?";
            try { procName = Process.GetProcessById((int)pid).ProcessName; } catch { }

            return string.Format("foreground=\"{0}\" process={1} pid={2}", title, procName, pid);
        }
        catch
        {
            return "foreground=unknown";
        }
    }

    public static string DescribeEnvironment()
    {
        return string.Format(
            "env launcher={0} game={1} {2}",
            HasLauncherRoot() ? "yes" : "no",
            HasGameMainWindow() ? "yes" : "no",
            DescribeForegroundWindow());
    }

    public static string LogTopLevelWindows()
    {
        var parts = new List<string>();
        try
        {
            var windowCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Window);
            var windows = AutomationElement.RootElement.FindAll(TreeScope.Children, windowCondition);
            foreach (AutomationElement window in windows)
            {
                try
                {
                    var title = window.Current.Name ?? string.Empty;
                    if (string.IsNullOrWhiteSpace(title)) continue;
                    var pid = window.Current.ProcessId;
                    var procName = "?";
                    try { procName = Process.GetProcessById(pid).ProcessName; } catch { }
                    parts.Add(string.Format("\"{0}\"({1})", title, procName));
                }
                catch { }
            }

            var summary = parts.Count == 0
                ? "AUDIT top-level windows: (none with titles)"
                : "AUDIT top-level windows (" + parts.Count + "): " + string.Join("; ", parts.ToArray());
            LogLine(summary);
            return summary;
        }
        catch (Exception ex)
        {
            var msg = "AUDIT top-level windows: scan failed — " + ex.Message;
            LogLine(msg);
            return msg;
        }
    }

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    private static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    private static extern void mouse_event(int dwFlags, int dx, int dy, int dwData, UIntPtr dwExtraInfo);

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("kernel32.dll")]
    private static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    private static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);

    [DllImport("user32.dll")]
    private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    private static extern bool BringWindowToTop(IntPtr hWnd);

    [DllImport("user32.dll")]
    private static extern IntPtr GetAncestor(IntPtr hwnd, uint gaFlags);

    [DllImport("user32.dll")]
    private static extern bool ScreenToClient(IntPtr hWnd, ref POINT lpPoint);

    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    private static extern bool IsIconic(IntPtr hWnd);

    [DllImport("user32.dll")]
    private static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    private static extern bool ClientToScreen(IntPtr hWnd, ref POINT lpPoint);

    [DllImport("user32.dll")]
    private static extern IntPtr WindowFromPoint(POINT point);

    [DllImport("user32.dll")]
    private static extern IntPtr SendMessage(IntPtr hWnd, int msg, int wParam, int lParam);

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT
    {
        public int X;
        public int Y;
    }

    private static int MakeLParam(int x, int y)
    {
        return (y << 16) | (x & 0xFFFF);
    }

    private const int MOUSEEVENTF_LEFTDOWN = 0x0002;
    private const int MOUSEEVENTF_LEFTUP = 0x0004;
    private const int WM_LBUTTONDOWN = 0x0201;
    private const int WM_LBUTTONUP = 0x0202;
    private const int MK_LBUTTON = 0x0001;
    private const int SW_RESTORE = 9;
    private const uint GA_ROOT = 2;
}
'@
    try {
        Add-Type -TypeDefinition $uiaHelperSource -ReferencedAssemblies @(
            'UIAutomationClient',
            'UIAutomationTypes',
            'System.Windows.Forms',
            'WindowsBase'
        ) -ErrorAction Stop
    } catch {
        if (-not ('UIAHelper' -as [type])) { throw }
    }
}

[UIAHelper]::Log = [Action[string]]{ param($m) Write-LaunchLog "UIA: $m" }
[UIAHelper]::RespectUserForeground = $RespectUserForeground
# Pre-launch PID baseline: lets the game-host window be identified by what is NEW after launch,
    # not by process name, which Steam in-launcher hosting makes unreliable.
    [UIAHelper]::CaptureBaselineProcessIds()

    # Pre-flight: scan and close any stale crash reporter / assertion / safe mode dialogs from prior runs.
    # These modal dialogs persist across restarts and block new launches.
    if ([UIAHelper]::HasCrashReporterDialog()) {
        Write-LaunchLog 'PREFLIGHT: stale crash reporter dialog detected — closing'
        [UIAHelper]::ClickCrashReporterNo() | Out-Null
        Start-Sleep -Milliseconds 500
    }
    if ([UIAHelper]::HasSafeModeDialog()) {
        Write-LaunchLog 'PREFLIGHT: stale safe mode dialog detected — closing'
        [UIAHelper]::ClickSafeModeNo() | Out-Null
        Start-Sleep -Milliseconds 500
    }

    Write-LaunchLog "session pid=$PID log=$logPath intent=$LaunchIntent timeout=${TimeoutSec}s poll=${PollMs}ms respectUserForeground=$RespectUserForeground"
Write-LaunchLog ([UIAHelper]::DescribeEnvironment())
[UIAHelper]::LogTopLevelWindows() | Out-Null

$clickedPlayContinue = $false
$clickedCaution = $false
$clickedSafeMode = $false
$clickedCrashReporter = $false
$clickedModuleMismatch = $false
$loggedModuleMismatchButtons = $false
$gameStablePolls = 0
$requiredStablePolls = 3
$playClickUtc = $null
$playEscalated = $false
$continueEscalated = $false
$script:automationClickedPlayContinue = $false
$script:launchPathAdopted = $false
$script:adoptedLaunchPath = $null
$script:adoptedSelectedBy = $null
$script:contaminatedLaunchPath = $false
$script:contaminatedLaunchReason = $null
$script:automationContinueIntentDeclared = $false
$script:launcherReadyLogged = $false
$script:safeModeVisibleLogged = $false
$script:ContinueClickVerifySec = 4
$script:ContinueClickVerifySecChrome = 2
$script:PlayClickVerifySec = 6
$script:LauncherSelectionMaxMs = $LauncherSelectionMaxMs
$script:playContinueMenuFirstSeenUtc = $null
$script:launcherChromeFirstSeenUtc = $null
if ($LaunchSetup.IsPresent) {
    $script:ContinueClickVerifySec = 3
    $script:ContinueClickVerifySecChrome = 2
    $script:PlayClickVerifySec = 4
    if ($PollMs -gt 120) { $PollMs = 120 }
}
$script:launcherSelectionAttempts = 0
$script:continueVerifyTotalMs = 0
$script:safeModeBeforeContinue = $false
$script:launcherSelectionEnded = $false
$startTime = Get-Date
$effectiveTimeout = $TimeoutSec
$deadline = $startTime.AddSeconds($effectiveTimeout)
$loadStallSec = 180
$phase1LogPath = Get-Phase1LogPath -BannerlordRoot $BannerlordRoot
$statusJsonPath = Get-StatusJsonPath -BannerlordRoot $BannerlordRoot
$crashContextPath = Get-CrashContextJsonPath -BannerlordRoot $BannerlordRoot
$lastHeartbeat = Get-Date
$heartbeatSec = 30
$preHandoffSuppressedLogged = $false
$preHandoffMismatchSuppressedLogged = $false
$handoffStarted = $false
$lastRefocusUtc = $null
$gameSpawnLogged = $false
$mismatchCoordAttemptMain = 0
$phase1ReadyBaseline = @{}
$focusHelperPath = Join-Path $PSScriptRoot 'focus-bannerlord-window.ps1'
if (Test-Path -LiteralPath $phase1LogPath) {
    Get-Content -LiteralPath $phase1LogPath -Tail 40 -ErrorAction SilentlyContinue |
        Where-Object { Test-Phase1ReadyLine -Line $_ } |
        ForEach-Object { $phase1ReadyBaseline[$_] = $true }
}
if (Test-Path -LiteralPath $windowSnapshotS1Path) {
    try {
        $script:launcherSelectionBaselineSnapshot = Get-Content -LiteralPath $windowSnapshotS1Path -Raw | ConvertFrom-Json
        Write-LaunchLog 'AUDIT S1 baseline loaded from pre-launch snapshot artifact'
    }
    catch {
        Write-LaunchLog "AUDIT S1 baseline load failed; recapturing in launcher-auto-nav: $($_.Exception.Message)"
    }
}
if (-not $script:launcherSelectionBaselineSnapshot) {
    $script:launcherSelectionBaselineSnapshot = Get-Pr11ProcessSnapshot -Label 'S1_pre_launch_fallback' -BannerlordRoot $BannerlordRoot
    Save-TbgLauncherWindowArtifact -Object $script:launcherSelectionBaselineSnapshot -Path $windowSnapshotS1Path
    Write-LaunchLog 'AUDIT S1 baseline recaptured inside launcher-auto-nav (fallback only)'
}
[UIAHelper]::ClearPreferredLauncherWindow()
Write-TbgLauncherSelectionDecisionArtifact -Decision $null -ChosenWindow $null

function Test-LauncherChromeVisible {
    if ([UIAHelper]::HasSafeModeDialog()) { return $true }
    if ([UIAHelper]::HasLauncherRoot()) { return $true }
    if ([UIAHelper]::IsLauncherPlayContinueVisible()) { return $true }
    return $false
}

function Update-LauncherSelectionTimer {
    if (-not [UIAHelper]::IsLauncherPlayContinueVisible()) { return }
    if (-not $script:playContinueMenuFirstSeenUtc) {
        $script:playContinueMenuFirstSeenUtc = Get-Date
    }
    if (-not $script:launcherChromeFirstSeenUtc) {
        $script:launcherChromeFirstSeenUtc = $script:playContinueMenuFirstSeenUtc
    }
}

function Test-LauncherSelectionBudgetExceeded {
    if ($handoffStarted -or $clickedPlayContinue) { return $false }
    $anchor = if ($script:playContinueMenuFirstSeenUtc) { $script:playContinueMenuFirstSeenUtc } else { $script:launcherChromeFirstSeenUtc }
    if (-not $anchor) { return $false }
    $elapsedMs = ((Get-Date) - $anchor).TotalMilliseconds
    return ($elapsedMs -gt $script:LauncherSelectionMaxMs)
}

function Write-LaunchTimingEvidence {
    param([string]$Result)

    if ($script:launcherSelectionEnded) { return }
    $selMs = 0
    $timingAnchor = if ($script:playContinueMenuFirstSeenUtc) { $script:playContinueMenuFirstSeenUtc } else { $script:launcherChromeFirstSeenUtc }
    if ($timingAnchor) {
        $selMs = [int][Math]::Max(0, ((Get-Date) - $timingAnchor).TotalMilliseconds)
    }
    $safeFlag = if ($script:safeModeBeforeContinue) { 'true' } else { 'false' }
    $line = "LAUNCH_TIMING launcherSelectionMs=$selMs continueVerifyMs=$($script:continueVerifyTotalMs) safeModeBeforeContinue=$safeFlag attempts=$($script:launcherSelectionAttempts) result=$Result"
    Write-LaunchLog $line
    $script:launcherSelectionEnded = $true
}

function Invoke-BannerlordFocusHelper {
    param([string]$Context = 'post-handoff')

    if (-not (Test-Path -LiteralPath $focusHelperPath)) {
        Write-LaunchLog 'post-handoff: refocus skipped; focus helper missing'
        return $false
    }

    Write-LaunchLog "post-handoff: refocus game/launcher attempted ($Context)"
    try {
        $focused = & $focusHelperPath
        if ($focused) {
            Write-LaunchLog "post-handoff: refocus game/launcher succeeded ($Context)"
        }
        return [bool]$focused
    } catch {
        Write-LaunchLog "post-handoff: refocus game/launcher failed ($Context): $($_.Exception.Message)"
        return $false
    }
}

function Extend-DeadlineForSlowPath {
    if ($clickedSafeMode -or $clickedCrashReporter) {
        $extended = [Math]::Max($TimeoutSec, 180)
        if ($extended -gt $script:effectiveTimeout) {
            $script:effectiveTimeout = $extended
            $script:deadline = $script:startTime.AddSeconds($extended)
            Write-LaunchLog "extended timeout to ${extended}s (Safe Mode or crash reporter path)"
        }
    }
}

function Extend-DeadlineAfterPlayClick {
    if (-not $script:clickedPlayContinue -or -not $script:playClickUtc) {
        return
    }

    $extendedDeadline = $script:playClickUtc.AddSeconds(240)
    if ($extendedDeadline -gt $script:deadline) {
        $script:deadline = $extendedDeadline
        $script:effectiveTimeout = [int][Math]::Ceiling(($script:deadline - $script:startTime).TotalSeconds)
        Write-LaunchLog "extended timeout to $($script:effectiveTimeout)s (post-PLAY spawn wait)"
    }
}

function Test-PreHandoffReadyAllowed {
    if ($script:clickedPlayContinue) { return $true }
    if (Test-GameProcessRunning) { return $true }
    if (-not [UIAHelper]::HasLauncherRoot()) { return $true }
    return $false
}

function Test-LaunchReadyNow {
    param([ref]$StallDetected)

    if (-not (Test-PreHandoffReadyAllowed)) {
        if (-not $script:preHandoffSuppressedLogged) {
            Write-LaunchLog 'pre-handoff ready suppressed — launcher idle, PLAY/CONTINUE not clicked yet'
            $script:preHandoffSuppressedLogged = $true
        }
        return $false
    }

    if ((Test-Phase1ReadyOrStall -StallDetected $StallDetected) -or (Test-StatusJsonReady)) {
        if ($LaunchIntent -eq 'continue' -and -not (Test-PostHandoffReadyAllowed)) {
            if (-not $script:preHandoffMismatchSuppressedLogged) {
                Write-LaunchLog 'pre-handoff ready suppressed — Module Mismatch inquiry not cleared'
                $script:preHandoffMismatchSuppressedLogged = $true
            }
            return $false
        }
        return $true
    }

    return $false
}

function Get-LaunchNavProcessDetection {
    return Get-BannerlordProcessDetection -BannerlordRoot $BannerlordRoot `
        -Phase1Path $phase1LogPath -StatusPath $statusJsonPath -CrashContextPath $crashContextPath
}

function Test-GameProcessRunning {
    return [bool](Get-LaunchNavProcessDetection).gameProcessRunning
}

function Test-RealGameProcessSpawned {
    return Test-TbgRealGameSpawnDetection -Detection (Get-LaunchNavProcessDetection)
}

function Get-LaunchNavEnvironmentLine {
    $base = [UIAHelper]::DescribeEnvironment()
    $det = Get-LaunchNavProcessDetection
    if ($det.gameProcessRunning) {
        if ((Test-F7ContinueCertStrict) -and -not $script:automationContinueIntentDeclared) {
            $launcherProc = Get-Process -Name $launcherExeName -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($launcherProc -and (Test-LauncherMenuWindowTitle -Title $launcherProc.MainWindowTitle)) {
                return ($base -replace 'game=(yes|no|hosted|phase1|uncertain)', 'game=menu')
            }
            if (Test-F7StrongPreIntentGameSignal -Detection $det) {
                $tag = switch ([string]$det.gameAliveConfidence) {
                    'definite' { 'yes' }
                    'launcher_hosted' { 'hosted' }
                    'phase1_active' { 'phase1' }
                    'process_detection_uncertain' { 'uncertain' }
                    default { 'yes' }
                }
                return ($base -replace 'game=(yes|no)', "game=$tag")
            }
            return ($base -replace 'game=(yes|no|hosted|phase1|uncertain)', 'game=menu')
        }
        $tag = switch ([string]$det.gameAliveConfidence) {
            'definite' { 'yes' }
            'launcher_hosted' { 'hosted' }
            'phase1_active' { 'phase1' }
            'process_detection_uncertain' { 'uncertain' }
            default { 'yes' }
        }
        return ($base -replace 'game=(yes|no)', "game=$tag")
    }
    return $base
}

function Test-F7ContinueCertStrict {
    return ($CertTarget -eq 'continue')
}

function Get-F7SpawnAttribution {
    if (Test-Path -LiteralPath $logPath) {
        $tail = Get-Content -LiteralPath $logPath -Tail 200 -ErrorAction SilentlyContinue
        foreach ($line in @($tail)) {
            if ($line -match 'LAUNCH_STATE=play_clicked selectedBy=user|play_clicked selectedBy=user') {
                return 'user'
            }
        }
    }

    if ([UIAHelper]::IsLauncherPlayContinueVisible()) {
        $launcherProc = Get-Process -Name $launcherExeName -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($launcherProc -and (Test-LauncherSingleplayerHostedTitle -Title $launcherProc.MainWindowTitle)) {
            return 'launcher_auto_resume'
        }
    }

    return 'preautomation_spawn'
}

function Write-ContaminatedLaunchPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Reason,
        [string]$SpawnAttribution = 'external_or_unknown'
    )

    $script:contaminatedLaunchPath = $true
    $script:contaminatedLaunchReason = [string]$Reason
    Write-LaunchLog "LAUNCH_STATE=contaminated_launch_path reason=$Reason certTarget=$CertTarget spawnAttribution=$SpawnAttribution"
}

function Test-PreIntentGameSpawnAndContaminate {
    if (-not (Test-F7ContinueCertStrict)) { return $false }
    if ($script:automationContinueIntentDeclared) { return $false }
    if ($script:contaminatedLaunchPath) { return $true }

    $det = Get-LaunchNavProcessDetection
    $loading = [UIAHelper]::HasLauncherLoadingSurface()
    $launcherGone = -not [UIAHelper]::HasLauncherRoot()

    if (-not (Test-F7StrongPreIntentGameSignal -Detection $det -LoadingSurface $loading -LauncherGone $launcherGone)) {
        return $false
    }

    $attr = Get-F7SpawnAttribution
    Write-ContaminatedLaunchPath -Reason 'game_running_before_automation_continue' -SpawnAttribution $attr
    Write-LaunchLog 'LAUNCH_STATE=fail_contaminated_launch_path'
    return $true
}

function Record-TbgNavLaunchSelection {
    param(
        [ValidateSet('play', 'continue')][string]$Intent,
        [ValidateSet('script', 'user_or_external')][string]$Actor,
        [string]$ButtonText,
        [ValidateSet('uia', 'pid_global_uia', 'coordinate_fallback', 'user_handoff')][string]$Method,
        [int]$Confidence = 85,
        [int]$ProcessId = 0,
        [int64]$Hwnd = 0,
        [string]$WindowTitle = $null,
        [string]$ProcessName = $null
    )
    if (-not (Get-Command Write-TbgLaunchSelection -ErrorAction SilentlyContinue)) { return }
    Write-TbgLaunchSelection -BannerlordRoot $BannerlordRoot -Actor $Actor -Intent $Intent `
        -ButtonText $ButtonText -Method $Method -Confidence $Confidence -ProcessId $ProcessId -Hwnd $Hwnd `
        -WindowTitle $WindowTitle -ProcessName $ProcessName
}

function Invoke-AdoptLaunchPath {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('play', 'continue')]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [ValidateSet('user', 'automation', 'unknown')]
        [string]$SelectedBy
    )

    if ($script:launchPathAdopted) { return }

    if (Test-F7ContinueCertStrict) {
        if ($Path -eq 'play') {
            $attr = if ($SelectedBy -eq 'user') { 'user' } else { 'external_or_unknown' }
            Write-ContaminatedLaunchPath -Reason 'user_or_observed_play' -SpawnAttribution $attr
            return
        }
        if ($SelectedBy -eq 'user') {
            Write-ContaminatedLaunchPath -Reason 'user_handoff' -SpawnAttribution 'user'
            return
        }
    }

    $script:launchPathAdopted = $true
    $script:adoptedLaunchPath = $Path
    $script:adoptedSelectedBy = $SelectedBy
    $script:clickedPlayContinue = $true
    $script:playClickUtc = Get-Date
    if ($Path -eq 'continue') {
        $script:automationContinueIntentDeclared = $true
        Write-LaunchLog "LAUNCH_STATE=continue_clicked selectedBy=$SelectedBy"
    } else {
        Write-LaunchLog "LAUNCH_STATE=play_clicked selectedBy=$SelectedBy"
    }
    $actor = if ($SelectedBy -eq 'user') { 'user_or_external' } else { 'script' }
    $method = if ($SelectedBy -eq 'user') { 'user_handoff' } else { 'uia' }
    $btn = if ($Path -eq 'continue') { 'Continue' } else { 'Play' }
    $launcher = Get-Process -Name 'TaleWorlds.MountAndBlade.Launcher' -ErrorAction SilentlyContinue | Select-Object -First 1
    Record-TbgNavLaunchSelection -Intent $Path -Actor $actor -ButtonText $btn -Method $method `
        -ProcessId $(if ($launcher) { $launcher.Id } else { 0 }) `
        -Hwnd $(if ($launcher) { [int64]$launcher.MainWindowHandle } else { 0 }) `
        -WindowTitle $(if ($launcher) { [string]$launcher.MainWindowTitle } else { $null }) `
        -ProcessName $(if ($launcher) { [string]$launcher.ProcessName } else { $null })
}

function Test-UserLaunchPathAdopted {
    if (Test-F7ContinueCertStrict) {
        if ($script:contaminatedLaunchPath) { return $false }
        return $false
    }

    if ($script:launchPathAdopted -or $script:automationClickedPlayContinue `
            -or $script:automationContinueIntentDeclared -or $script:launcherSelectionAttempts -gt 0 `
            -or $clickedSafeMode) {
        return $false
    }

    $gameRunning = Test-RealGameProcessSpawned
    $loading = [UIAHelper]::HasLauncherLoadingSurface()
    $launcherGone = -not [UIAHelper]::HasLauncherRoot()
    $buttonsVisible = [UIAHelper]::IsLauncherPlayContinueVisible()

    if (-not ($gameRunning -or $loading -or ($launcherGone -and -not $buttonsVisible))) {
        return $false
    }

    if ($LaunchIntent -eq 'continue' -and $gameRunning -and -not $script:automationClickedPlayContinue) {
        # An unattended runner-driven continue launch must not assume a *user* launched the game
        # on a weak/freshness-only signal. Only adopt when a real game process/window exists or the
        # launcher actually transitioned (loading/gone). Otherwise return false so the runner clicks
        # CONTINUE itself (continue_escalate) instead of recording a phantom user launch (attempts=0).
        $adoptDet = Get-LaunchNavProcessDetection
        $realSignal = $loading -or $launcherGone -or (Test-F7StrongPreIntentGameSignal -Detection $adoptDet `
                -LoadingSurface $loading -LauncherGone $launcherGone)
        if (-not $realSignal) {
            return $false
        }
        if (-not [UIAHelper]::IsLauncherPlayContinueVisible() -and -not [UIAHelper]::HasLauncherLoadingSurface()) {
            Invoke-AdoptLaunchPath -Path 'play' -SelectedBy 'user'
            return $true
        }
        Invoke-AdoptLaunchPath -Path 'continue' -SelectedBy 'user'
        return $true
    }

    if ($LaunchIntent -eq 'play' -and ($gameRunning -or $loading)) {
        Invoke-AdoptLaunchPath -Path 'play' -SelectedBy 'user'
        return $true
    }

    if ($LaunchIntent -eq 'continue' -and ($loading -or $launcherGone)) {
        Invoke-AdoptLaunchPath -Path 'continue' -SelectedBy 'user'
        return $true
    }

    return $false
}

function Invoke-Handoff {
    param([string]$Reason)
    Write-LaunchTimingEvidence -Result 'ok'
    $script:handoffStarted = $true
    Write-LaunchLog "handoff: $Reason"
    Write-LaunchLog 'LAUNCH_STATE=handoff'
    Wait-PostHandoffWatchdog -Reason $Reason
}

function Test-Phase1ReadyOrStall {
    param([ref]$StallDetected)

    $StallDetected.Value = $false
    if (-not (Test-Path -LiteralPath $phase1LogPath)) {
        return $false
    }

    $tail = Get-Content -LiteralPath $phase1LogPath -Tail 40 -ErrorAction SilentlyContinue
    if (-not $tail) {
        return $false
    }

    foreach ($line in $tail) {
        if (Test-Phase1ReadyLine -Line $line) {
            if (-not $script:phase1ReadyBaseline.ContainsKey($line)) {
                return $true
            }
        }
        if ($line -match 'load stall: GameLoadingState exceeded') {
            if ((Get-Item -LiteralPath $phase1LogPath).LastWriteTime -gt $script:startTime) {
                $StallDetected.Value = $true
            }
            return $false
        }
    }

    return $false
}

function Test-StatusJsonReady {
    if (-not (Test-Path -LiteralPath $statusJsonPath)) {
        return $false
    }

    $statusMtime = (Get-Item -LiteralPath $statusJsonPath).LastWriteTime
    if ($statusMtime -le $script:startTime) {
        return $false
    }

    try {
        $status = Get-Content -LiteralPath $statusJsonPath -Raw -ErrorAction Stop | ConvertFrom-Json
        if ($status.campaignReady -eq $true) {
            return $true
        }
    } catch { }

    return $false
}

function Invoke-ModuleMismatchClick {
    if (-not [UIAHelper]::HasModuleMismatchDialog()) {
        return $false
    }

    if (-not $loggedModuleMismatchButtons) {
        $visible = [UIAHelper]::LogVisibleModuleMismatchButtons()
        Write-LaunchLog "Module Mismatch visible buttons: $visible"
        $script:loggedModuleMismatchButtons = $true
    }

    if (-not [UIAHelper]::ClickModuleMismatchYes()) {
        return $false
    }

    if (-not $clickedModuleMismatch) {
        Write-LaunchLog 'clicked Module Mismatch Yes'
        $script:clickedModuleMismatch = $true
    }

    return $true
}

function Test-Phase1ModuleMismatchPending {
    if (-not (Test-Path -LiteralPath $phase1LogPath)) {
        return $false
    }

    $tail = Get-Content -LiteralPath $phase1LogPath -Tail 60 -ErrorAction SilentlyContinue
    if (-not $tail) {
        return $false
    }

    $queued = $false
    $confirmed = $false
    foreach ($line in $tail) {
        if ($line -match 'Module Mismatch inquiry queued') {
            $queued = $true
        }
        if ($line -match 'Module Mismatch auto-Yes confirmed \(inquiry cleared\)') {
            $confirmed = $true
        }
    }

    return $queued -and -not $confirmed
}

function Test-Phase1ModuleMismatchCleared {
    if (-not (Test-Path -LiteralPath $phase1LogPath)) {
        return $false
    }

    $tail = Get-Content -LiteralPath $phase1LogPath -Tail 60 -ErrorAction SilentlyContinue
    if (-not $tail) {
        return $false
    }

    foreach ($line in $tail) {
        if ($line -match 'Module Mismatch auto-Yes confirmed \(inquiry cleared\)') {
            return $true
        }
    }

    return $false
}

function Test-PostHandoffReadyAllowed {
    if ($LaunchIntent -ne 'continue') {
        return $true
    }

    if ($script:clickedModuleMismatch) {
        return $true
    }

    if ([UIAHelper]::HasModuleMismatchDialog()) {
        return $false
    }

    if (Test-Phase1ModuleMismatchPending) {
        return $false
    }

    return $true
}

function Invoke-ModuleMismatchCoordFallback {
    param([int]$AttemptNumber = 0)

    if (-not (Test-GameProcessRunning)) {
        return $false
    }

    if (-not [UIAHelper]::ClickModuleMismatchYesByGameCoords()) {
        return $false
    }

    Write-LaunchLog "post-handoff: Module Mismatch coord-click attempt $AttemptNumber"
    return $true
}

function Wait-PostHandoffWatchdog {
    param([string]$Reason)

    Write-LaunchLog "post-handoff watch started ($Reason)"
    $watchStart = Get-Date
    $gameLoadingSince = $null
    $stallDetected = $false
    $mismatchCoordAttempt = 0
    $mismatchWatchSec = 30
    $lastPostHandoffRefocusUtc = $null

    while (((Get-Date) - $watchStart).TotalSeconds -lt $loadStallSec) {
        $nowPostHandoffRefocusUtc = [DateTime]::UtcNow
        if (-not $lastPostHandoffRefocusUtc -or ($nowPostHandoffRefocusUtc - $lastPostHandoffRefocusUtc).TotalSeconds -ge 2) {
            if (-not $RespectUserForeground -and ((Test-GameProcessRunning) -or [UIAHelper]::HasLauncherRoot())) {
                Invoke-BannerlordFocusHelper -Context 'watchdog' | Out-Null
            }
            $lastPostHandoffRefocusUtc = $nowPostHandoffRefocusUtc
        }

        if (-not (Test-GameProcessRunning)) {
            Write-LaunchLog 'post-handoff: Bannerlord exited'
            return
        }

        if (Invoke-ModuleMismatchClick) {
            Start-Sleep -Milliseconds $PollMs
            continue
        }

        if ($LaunchIntent -eq 'continue' -and
            ((Get-Date) - $watchStart).TotalSeconds -lt $mismatchWatchSec -and
            (Test-Phase1ModuleMismatchPending)) {
            $mismatchCoordAttempt++
            if (Invoke-ModuleMismatchCoordFallback -AttemptNumber $mismatchCoordAttempt) {
                Start-Sleep -Milliseconds $PollMs
                continue
            }
        }

        if ((Test-PostHandoffReadyAllowed) -and
            ((Test-Phase1ReadyOrStall -StallDetected ([ref]$stallDetected)) -or (Test-StatusJsonReady))) {
            Write-LaunchLog 'post-handoff: TBG READY detected'
            return
        }

        if (-not (Test-PostHandoffReadyAllowed)) {
            Start-Sleep -Milliseconds $PollMs
            continue
        }

        if ($stallDetected) {
            Write-LaunchLog "load stall watchdog: C# stall signature in Phase1.log — terminating Bannerlord"
            Stop-Process -Name $gameExeName -Force -ErrorAction SilentlyContinue
            throw "load stall watchdog triggered (C# stall signature)"
        }

        if (Test-Path -LiteralPath $statusJsonPath) {
            try {
                $status = Get-Content -LiteralPath $statusJsonPath -Raw | ConvertFrom-Json
                if ($status.activeState -eq 'GameLoadingState') {
                    if (-not $gameLoadingSince) {
                        $gameLoadingSince = Get-Date
                    } elseif (((Get-Date) - $gameLoadingSince).TotalSeconds -ge $loadStallSec) {
                        Write-LaunchLog "load stall watchdog: GameLoadingState exceeded ${loadStallSec}s — terminating Bannerlord"
                        Stop-Process -Name $gameExeName -Force -ErrorAction SilentlyContinue
                        throw "load stall watchdog triggered after ${loadStallSec}s in GameLoadingState"
                    }
                } else {
                    $gameLoadingSince = $null
                }
            } catch {
                if ($_.Exception.Message -match 'load stall watchdog triggered') {
                    throw
                }
            }
        }

        Start-Sleep -Milliseconds 1000
    }

    Write-LaunchLog "post-handoff watch completed (${loadStallSec}s, no stall kill)"
}

function Test-HandoffWhenGameStable {
    $det = Get-LaunchNavProcessDetection
    if (-not $det.gameProcessRunning) {
        $script:gameStablePolls = 0
        return $false
    }

    if (-not (Test-TbgRealGameSpawnDetection -Detection $det)) {
        $script:gameStablePolls = 0
        if (-not $script:weakPostContinueSignalLogged) {
            Write-LaunchLog "LAUNCH_STATE=weak_handoff_signal_ignored confidence=$([string]$det.gameAliveConfidence) method=$([string]$det.gameProcessDetectionMethod) — awaiting real game process or fresh TBG READY"
            $script:weakPostContinueSignalLogged = $true
        }
        return $false
    }

    $script:gameStablePolls++
    if ($script:gameStablePolls -lt $requiredStablePolls) {
        return $false
    }

    $launcherGone = -not [UIAHelper]::HasLauncherRoot()
    $playPathSkipped = $clickedPlayContinue -or $clickedSafeMode

    if (-not ($launcherGone -or $playPathSkipped)) {
        return $false
    }

    if (-not [UIAHelper]::HasCrashReporterDialog()) {
        if ($clickedPlayContinue) {
            Invoke-Handoff 'Bannerlord.exe stable — PLAY clicked'
        } elseif ($clickedSafeMode) {
            Invoke-Handoff 'Bannerlord.exe stable — Safe Mode path'
        } else {
            Invoke-Handoff 'Bannerlord.exe stable — launcher gone'
        }
        return $true
    }

    if ($clickedCrashReporter) {
        Invoke-Handoff 'Bannerlord.exe stable — crash reporter dismissed'
        return $true
    }

    Write-LaunchLog 'Bannerlord.exe stable but crash reporter heuristic still true — waiting'
    return $false
}

function Invoke-LauncherSafeModeAndCrashDialogs {
    if ([UIAHelper]::HasCrashReporterDialog()) {
        if ([UIAHelper]::ClickCrashReporterNo()) {
            if (-not $clickedCrashReporter) {
                Write-LaunchLog 'clicked crash reporter No'
                $clickedCrashReporter = $true
                Extend-DeadlineForSlowPath
            }
            if (Test-GameProcessRunning) {
                Invoke-Handoff 'Bannerlord.exe running after crash reporter No'
                return $true
            }
        }
        Start-Sleep -Milliseconds $PollMs
        return $true
    }

    if ($clickedSafeMode -and -not $clickedPlayContinue) {
        [UIAHelper]::ResetLauncherClickRetryState()
    }

    if ([UIAHelper]::HasSafeModeDialog() -and -not $script:safeModeVisibleLogged) {
        Write-LaunchLog 'LAUNCH_STATE=safe_mode_visible'
        $script:safeModeVisibleLogged = $true
    }

    if ([UIAHelper]::ClickSafeModeNo()) {
        if (-not $clickedSafeMode) {
            Write-LaunchLog 'clicked Safe Mode No'
            Write-LaunchLog 'LAUNCH_STATE=safe_mode_no_clicked'
            Write-LaunchLog 'Safe Mode: No selected - prior session unexpected shutdown; crash on last run suspected (full mod load retained)'
            $clickedSafeMode = $true
            Extend-DeadlineForSlowPath
            if (-not $RespectUserForeground) {
                Invoke-BannerlordFocusHelper -Context 'after-safe-mode-no' | Out-Null
            }
        }
        return $true
    }

    if ([UIAHelper]::HasSafeModeDialog()) {
        Start-Sleep -Milliseconds 120
        return $true
    }

    return $false
}

function Test-LaunchClickVerified {
    param(
        [int]$WaitSec = 4,
        [string]$Intent = 'continue'
    )

    $chromeVisible = ([UIAHelper]::HasLauncherRoot() -and -not $handoffStarted)
    if ($Intent -eq 'continue') {
        if ($chromeVisible) {
            $WaitSec = [Math]::Max($WaitSec, $script:ContinueClickVerifySecChrome)
        } else {
            $WaitSec = [Math]::Max($WaitSec, $script:ContinueClickVerifySec)
        }
    } elseif ($Intent -eq 'play') {
        $WaitSec = [Math]::Max($WaitSec, $script:PlayClickVerifySec)
    }

    $verifyStart = Get-Date
    function Complete-LaunchClickVerify {
        param([bool]$Ok)
        $script:continueVerifyTotalMs += [int][Math]::Max(0, ((Get-Date) - $verifyStart).TotalMilliseconds)
        return $Ok
    }

    $deadline = (Get-Date).AddSeconds($WaitSec)
    while ((Get-Date) -lt $deadline) {
        if ([UIAHelper]::HasSafeModeDialog()) {
            return (Complete-LaunchClickVerify $false)
        }

        $det = Get-LaunchNavProcessDetection
        if ($det.gameProcessRunning) {
            if ($Intent -eq 'continue' -and (Test-F7ContinueCertStrict)) {
                if ($det.gameAliveConfidence -eq 'definite') { return (Complete-LaunchClickVerify $true) }
                if ([UIAHelper]::HasLauncherLoadingSurface()) { return (Complete-LaunchClickVerify $true) }
                if (-not [UIAHelper]::HasLauncherRoot()) { return (Complete-LaunchClickVerify $true) }
            } else {
                return (Complete-LaunchClickVerify $true)
            }
        }

        if ($Intent -eq 'continue') {
            if (-not (Test-F7ContinueCertStrict) -and $det.gameAliveConfidence -eq 'launcher_hosted') { return (Complete-LaunchClickVerify $true) }
            if ([UIAHelper]::HasLauncherLoadingSurface()) { return (Complete-LaunchClickVerify $true) }
            if (-not [UIAHelper]::HasLauncherRoot()) { return (Complete-LaunchClickVerify $true) }
        }

        if ($Intent -eq 'play') {
            if ([UIAHelper]::HasLauncherLoadingSurface()) { return (Complete-LaunchClickVerify $true) }
            if (-not [UIAHelper]::HasLauncherRoot()) { return (Complete-LaunchClickVerify $true) }
            if (-not [UIAHelper]::HasSafeModeDialog() -and -not [UIAHelper]::IsLauncherPlayContinueVisible()) {
                return (Complete-LaunchClickVerify $true)
            }
        }

        Start-Sleep -Milliseconds 150
    }
    return (Complete-LaunchClickVerify $false)
}

if ($LaunchIntent -eq 'continue') {
    $targetButtonNames = @('CONTINUE', 'Continue', 'Continue Campaign', 'Resume', 'Resume Game')
} else {
    $targetButtonNames = @('PLAY', 'Play', 'Play Game')
}

try {
Initialize-NavExternalStateTimelineIfNeeded
Write-NavExternalStateEvent -ReasonOverride 'launcher-auto-nav entry classification'
while ((Get-Date) -lt $deadline) {
    if (Test-PreIntentGameSpawnAndContaminate) {
        return
    }

    if ($script:contaminatedLaunchPath -and (Test-F7ContinueCertStrict)) {
        Write-LaunchLog 'LAUNCH_STATE=fail_contaminated_launch_path'
        return
    }

    if (Invoke-LauncherSafeModeAndCrashDialogs) {
        continue
    }

    Update-LauncherSelectionTimer
    if ((Test-F7ContinueCertStrict) -and $LaunchIntent -eq 'continue' -and (Test-LauncherChromeVisible)) {
        if ([UIAHelper]::IsLauncherPlayOnlyVisible() -and -not [UIAHelper]::IsLauncherContinueVisible()) {
            Write-LaunchTimingEvidence -Result 'failed'
            Write-LaunchLog 'LAUNCH_STATE=fail_launcher_play_only'
            throw 'launcher play-only visible during continue cert'
        }
    }
    if (Test-LauncherSelectionBudgetExceeded) {
        Write-LaunchTimingEvidence -Result 'timeout'
        Write-LaunchLog 'LAUNCH_STATE=launcher_timing_timeout'
        throw "launcher selection exceeded $($script:LauncherSelectionMaxMs / 1000)s budget after PLAY/CONTINUE menu (launcher_timing_timeout)"
    }

    if (((Get-Date) - $lastHeartbeat).TotalSeconds -ge $heartbeatSec) {
        $envDesc = Get-LaunchNavEnvironmentLine
        Write-LaunchLog $envDesc
        if ($envDesc -match 'launcher=no' -and (Get-Process -Name $launcherExeName -ErrorAction SilentlyContinue)) {
            Write-LaunchLog 'LAUNCH_STATE=waiting_launcher_hwnd'
        }
        if (-not $script:launcherReadyLogged -and [UIAHelper]::IsLauncherPlayContinueVisible()) {
            Write-LaunchLog 'LAUNCH_STATE=launcher_ready'
            $script:launcherReadyLogged = $true
        }
        $lastHeartbeat = Get-Date
    }

    if ((Test-RealGameProcessSpawned) -and -not $script:gameSpawnLogged) {
        if ((Test-F7ContinueCertStrict) -and -not $script:automationContinueIntentDeclared) {
            $det = Get-LaunchNavProcessDetection
            if (Test-F7StrongPreIntentGameSignal -Detection $det `
                    -LoadingSurface ([UIAHelper]::HasLauncherLoadingSurface()) `
                    -LauncherGone (-not [UIAHelper]::HasLauncherRoot())) {
                if (Test-PreIntentGameSpawnAndContaminate) { return }
            }
        } else {
            # Non-strict path: do not declare game_spawned on a weak/freshness-only signal
            # (e.g. phase1_active or a deploy-written Status.json). Require either a strong
            # real process/window signal, or that automation has actually clicked PLAY/CONTINUE.
            # Otherwise a phantom spawn leads to user-launch-path adoption with attempts=0.
            $det = Get-LaunchNavProcessDetection
            $strongSignal = Test-F7StrongPreIntentGameSignal -Detection $det `
                -LoadingSurface ([UIAHelper]::HasLauncherLoadingSurface()) `
                -LauncherGone (-not [UIAHelper]::HasLauncherRoot())
            if ($strongSignal -or $clickedPlayContinue -or $script:automationClickedPlayContinue) {
                Write-LaunchLog 'LAUNCH_STATE=game_spawned'
                $script:gameSpawnLogged = $true
                if (Test-Path -LiteralPath $focusHelperPath) {
                    try {
                        $raised = & $focusHelperPath
                        if ($raised) {
                            Write-LaunchLog 'raised Bannerlord window on game spawn'
                        }
                    } catch { }
                }
            } else {
                if (-not $script:weakSpawnSignalLogged) {
                    Write-LaunchLog "LAUNCH_STATE=weak_game_signal_ignored confidence=$([string]$det.gameAliveConfidence) method=$([string]$det.gameProcessDetectionMethod) — awaiting real process/window or automation click"
                    $script:weakSpawnSignalLogged = $true
                }
            }
        }
    }

    if ($LaunchIntent -eq 'play' -and $clickedPlayContinue -and -not (Test-GameProcessRunning) -and $script:playClickUtc) {
        $sinceClick = ((Get-Date) - $script:playClickUtc).TotalSeconds
        if ($sinceClick -ge 15 -and -not $script:playEscalated -and -not $script:launchPathAdopted) {
            $script:playEscalated = $true
            if ($AllowFocusSteal) {
                Write-LaunchLog 'LAUNCH_STATE=play_escalate — hwnd-only PLAY did not spawn Bannerlord.exe; retry with foreground clicks (AllowFocusSteal)'
                $clickedPlayContinue = $false
                $script:playClickUtc = $null
                $RespectUserForeground = $false
                [UIAHelper]::RespectUserForeground = $false
                [UIAHelper]::ResetLauncherClickRetryState()
            } else {
                Write-LaunchLog 'LAUNCH_STATE=play_escalate_suppressed — hwnd-only PLAY did not spawn Bannerlord.exe; focus-steal escalation suppressed by policy (pass -AllowFocusSteal to enable)'
            }
        }
    }

    if ($LaunchIntent -eq 'continue' -and $clickedPlayContinue -and -not (Test-GameProcessRunning) -and $script:playClickUtc) {
        $sinceClick = ((Get-Date) - $script:playClickUtc).TotalSeconds
        if ($sinceClick -ge 15 -and -not $script:continueEscalated -and -not $script:launchPathAdopted) {
            $script:continueEscalated = $true
            if ($AllowFocusSteal) {
                Write-LaunchLog 'LAUNCH_STATE=continue_escalate — hwnd-only CONTINUE did not spawn Bannerlord.exe; retry with foreground clicks (AllowFocusSteal)'
                $clickedPlayContinue = $false
                $script:playClickUtc = $null
                $RespectUserForeground = $false
                [UIAHelper]::RespectUserForeground = $false
                [UIAHelper]::ResetLauncherClickRetryState()
            } else {
                Write-LaunchLog 'LAUNCH_STATE=continue_escalate_suppressed — hwnd-only CONTINUE did not spawn Bannerlord.exe; focus-steal escalation suppressed by policy (pass -AllowFocusSteal to enable)'
            }
        }
    }

    if ($clickedPlayContinue -and -not (Test-GameProcessRunning) -and $script:playClickUtc -and -not $script:launchPathAdopted) {
        $sinceClick = ((Get-Date) - $script:playClickUtc).TotalSeconds
        if ($sinceClick -ge 12 -and [UIAHelper]::IsLauncherPlayContinueVisible() -and -not [UIAHelper]::HasSafeModeDialog()) {
            $retryLabel = if ($LaunchIntent -eq 'continue') { 'continue_retry' } else { 'play_retry' }
            Write-LaunchLog "LAUNCH_STATE=$retryLabel - game never spawned; resetting clickedPlayContinue"
            $clickedPlayContinue = $false
            $script:playClickUtc = $null
            [UIAHelper]::ResetLauncherClickRetryState()
        }
    }

    if ($clickedPlayContinue) {
        Extend-DeadlineAfterPlayClick
    }

    if ($clickedPlayContinue -and -not $handoffStarted -and -not $RespectUserForeground) {
        $refocusIntervalSec = if ([UIAHelper]::HasLauncherLoadingSurface()) { 5 } else { 2 }
        $nowRefocusUtc = [DateTime]::UtcNow
        if (-not $lastRefocusUtc -or ($nowRefocusUtc - $lastRefocusUtc).TotalSeconds -ge $refocusIntervalSec) {
            [UIAHelper]::TryFocusGameOrLauncher() | Out-Null
            $lastRefocusUtc = $nowRefocusUtc
        }
    }

    $preHandoffStall = $false
    if (Test-LaunchReadyNow -StallDetected ([ref]$preHandoffStall)) {
        Write-LaunchTimingEvidence -Result 'ok'
        Write-LaunchLog 'TBG READY detected (pre-handoff) — launch success'
        return
    }

    if ($preHandoffStall) {
        Write-LaunchLog 'load stall signature detected before handoff — waiting for watchdog path'
    }

    if (Test-HandoffWhenGameStable) {
        return
    }

    if (Get-Process -Name $gameExeName -ErrorAction SilentlyContinue) {
        if (-not [UIAHelper]::HasCrashReporterDialog()) {
            Invoke-Handoff 'Bannerlord.exe detected — handoff to in-game mod'
            return
        }
        Write-LaunchLog 'Bannerlord.exe running but crash reporter visible — waiting'
    }

    if (Invoke-ModuleMismatchClick) {
        Start-Sleep -Milliseconds $PollMs
        continue
    }

    if ($LaunchIntent -eq 'continue' -and (Test-GameProcessRunning) -and (Test-Phase1ModuleMismatchPending)) {
        $mismatchCoordAttemptMain++
        if (Invoke-ModuleMismatchCoordFallback -AttemptNumber $mismatchCoordAttemptMain) {
            Start-Sleep -Milliseconds $PollMs
            continue
        }
    }

    if ([UIAHelper]::HasCautionDialog()) {
        if ([UIAHelper]::ClickCautionConfirm()) {
            if (-not $clickedCaution) {
                Write-LaunchLog 'clicked CAUTION Confirm'
                $clickedCaution = $true
            }
        } else {
            Write-LaunchLog 'CAUTION visible but Confirm not clicked (scoped only — no global Enter)'
        }
        Start-Sleep -Milliseconds $PollMs
        continue
    }

    if (Test-UserLaunchPathAdopted) {
        if (Test-RealGameProcessSpawned) {
            Invoke-Handoff 'user launch path adopted — game running'
            return
        }
        if ([UIAHelper]::HasLauncherLoadingSurface() -or -not [UIAHelper]::HasLauncherRoot()) {
            Invoke-Handoff 'user launch path adopted — loading or launcher gone'
            return
        }
    }

    if (-not $clickedPlayContinue) {
        if ($script:contaminatedLaunchPath) {
            Write-LaunchLog 'LAUNCH_STATE=fail_contaminated_launch_path'
            return
        }
        if ([UIAHelper]::HasSafeModeDialog()) {
            Start-Sleep -Milliseconds $PollMs
            continue
        }
        if (-not (Test-NavGuardedLauncherClick -Intent $LaunchIntent)) {
            $script:operatorGuardedClickDeniedCount++
            if ($script:operatorGuardedClickDeniedCount -ge 10) {
                Invoke-OperatorInteractiveFocusPrompt -Reason 'guarded_click_denied' | Out-Null
            }
            Start-Sleep -Milliseconds $PollMs
            continue
        }
        $script:operatorGuardedClickDeniedCount = 0
        $matchedName = [UIAHelper]::ClickButtonByNameInLauncher($targetButtonNames)
        if ($matchedName) {
            $displayName = if ($LaunchIntent -eq 'continue') { 'CONTINUE' } else { 'PLAY' }
            $script:launcherSelectionAttempts++
            if ($clickedSafeMode) { $script:safeModeBeforeContinue = $true }
            if (Test-LaunchClickVerified -WaitSec 4 -Intent $LaunchIntent) {
                $script:automationClickedPlayContinue = $true
                Write-LaunchLog "clicked $displayName ($matchedName) — launch verified (game or launcher handoff)"
                if ($LaunchIntent -eq 'continue') {
                    $script:automationContinueIntentDeclared = $true
                    Write-LaunchLog 'LAUNCH_STATE=continue_clicked selectedBy=automation'
                } else {
                    Write-LaunchLog 'LAUNCH_STATE=play_clicked selectedBy=automation'
                }
                $deltaWinner = if ($script:lastLauncherWindowDeltaDecision -and $script:lastLauncherWindowDeltaDecision.allowed) {
                    $script:lastLauncherWindowDeltaDecision.winner
                } else {
                    $null
                }
                $launcher = Get-Process -Name 'TaleWorlds.MountAndBlade.Launcher' -ErrorAction SilentlyContinue | Select-Object -First 1
                Record-TbgNavLaunchSelection -Intent $LaunchIntent -Actor 'script' -ButtonText $displayName `
                    -Method 'uia' -Confidence $(if ($deltaWinner) { [int]$deltaWinner.score } else { 90 }) `
                    -ProcessId $(if ($deltaWinner) { [int]$deltaWinner.pid } elseif ($launcher) { $launcher.Id } else { 0 }) `
                    -Hwnd $(if ($deltaWinner) { [int64]$deltaWinner.hwnd } elseif ($launcher) { [int64]$launcher.MainWindowHandle } else { 0 }) `
                    -WindowTitle $(if ($deltaWinner) { [string]$deltaWinner.windowTitle } elseif ($launcher) { [string]$launcher.MainWindowTitle } else { $null }) `
                    -ProcessName $(if ($deltaWinner) { [string]$deltaWinner.processName } elseif ($launcher) { [string]$launcher.ProcessName } else { $null })
                $clickedPlayContinue = $true
                $script:playClickUtc = Get-Date
                Extend-DeadlineAfterPlayClick
                if (-not $RespectUserForeground) {
                    Invoke-BannerlordFocusHelper -Context 'after-play-continue-click' | Out-Null
                }
                if ($script:contaminatedLaunchPath -and (Test-F7ContinueCertStrict)) {
                    Write-LaunchLog 'LAUNCH_STATE=fail_contaminated_launch_path'
                    return
                }
            } else {
                Write-LaunchLog "click $displayName ($matchedName) NOT verified — PLAY/CONTINUE still on screen; will retry"
                [UIAHelper]::ResetLauncherClickRetryState()
            }
        }
    }

    $loopPollMs = if ([UIAHelper]::HasSafeModeDialog() -or (-not $clickedPlayContinue -and [UIAHelper]::IsLauncherPlayContinueVisible())) {
        120
    } else {
        $PollMs
    }
    Start-Sleep -Milliseconds $loopPollMs
}

$boundaryStall = $false
if (Test-LaunchReadyNow -StallDetected ([ref]$boundaryStall)) {
    Write-LaunchTimingEvidence -Result 'ok'
    Write-LaunchLog 'TBG READY detected at timeout boundary — treating as success'
    return
}

$visibleButtons = [UIAHelper]::LogVisibleLauncherButtons()
Write-LaunchLog "timeout: visible launcher buttons: $visibleButtons"
throw "launcher-auto-nav timed out after ${effectiveTimeout}s (see $logPath)"
} finally {
    Save-F7ExternalStateTimeline | Out-Null
    Release-NavLock
}
