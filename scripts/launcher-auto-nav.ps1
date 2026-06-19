# Pre-main-menu UI automation: PLAY/CONTINUE, CAUTION Confirm, Safe Mode No (Sprint 006E).
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('play', 'continue')]
    [string]$LaunchIntent,

    [Parameter(Mandatory = $true)]
    [string]$BannerlordRoot,

    [int]$TimeoutSec = 120,
    [int]$PollMs = 450
)

$ErrorActionPreference = 'Stop'

$logPath = Join-Path $BannerlordRoot 'BlacksmithGuild_Launch.log'
$launcherExeName = 'TaleWorlds.MountAndBlade.Launcher'
$gameExeName = 'Bannerlord'

function Write-LaunchLog {
    param([string]$Message)
    $line = "[{0}] launcher-auto: {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
    Write-Host $line -ForegroundColor DarkGray
}

if (-not (Get-Module -Name UIAHelper -ErrorAction SilentlyContinue)) {
    $uiaHelperSource = @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Automation;

public static class UIAHelper
{
    public static bool ClickButtonByName(string name, bool requireEnabled = true)
    {
        if (string.IsNullOrWhiteSpace(name)) return false;
        var condition = new PropertyCondition(AutomationElement.NameProperty, name);
        var element = AutomationElement.RootElement.FindFirst(TreeScope.Descendants, condition);
        if (element == null) return false;
        if (requireEnabled && !element.Current.IsEnabled) return false;
        return InvokeElement(element);
    }

    public static bool ClickSafeModeNo()
    {
        var hwnd = FindWindow(null, "Safe Mode");
        if (hwnd == IntPtr.Zero) return false;
        SetForegroundWindow(hwnd);
        Thread.Sleep(120);
        return ClickButtonByName("No", false);
    }

    public static bool HasCautionDialog()
    {
        var caution = AutomationElement.RootElement.FindFirst(
            TreeScope.Descendants,
            new PropertyCondition(AutomationElement.NameProperty, "CAUTION"));
        return caution != null;
    }

    private static bool InvokeElement(AutomationElement element)
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
                    return true;
                }
            }
        }
        catch { }

        try
        {
            var rect = element.Current.BoundingRectangle;
            if (rect.Width <= 0 || rect.Height <= 0) return false;
            var x = (int)(rect.X + rect.Width / 2);
            var y = (int)(rect.Y + rect.Height / 2);
            SetCursorPos(x, y);
            Thread.Sleep(60);
            mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
            mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
            return true;
        }
        catch { return false; }
    }

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    private static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    private static extern void mouse_event(int dwFlags, int dx, int dy, int dwData, UIntPtr dwExtraInfo);

    private const int MOUSEEVENTF_LEFTDOWN = 0x0002;
    private const int MOUSEEVENTF_LEFTUP = 0x0004;
}
'@
    Add-Type -TypeDefinition $uiaHelperSource -ReferencedAssemblies @(
        'UIAutomationClient',
        'UIAutomationTypes',
        'System.Windows.Forms',
        'WindowsBase'
    ) -ErrorAction Stop
}

Write-LaunchLog "intent=$LaunchIntent"

$clickedPlayContinue = $false
$clickedCaution = $false
$clickedSafeMode = $false
$deadline = (Get-Date).AddSeconds($TimeoutSec)
$targetButton = if ($LaunchIntent -eq 'continue') { 'CONTINUE' } else { 'PLAY' }

while ((Get-Date) -lt $deadline) {
    if (Get-Process -Name $gameExeName -ErrorAction SilentlyContinue) {
        Write-LaunchLog 'Bannerlord.exe detected — handoff to in-game mod'
        return
    }

    if ([UIAHelper]::ClickSafeModeNo()) {
        if (-not $clickedSafeMode) {
            Write-LaunchLog 'clicked Safe Mode No'
            $clickedSafeMode = $true
        }
        Start-Sleep -Milliseconds $PollMs
        continue
    }

    if ([UIAHelper]::HasCautionDialog()) {
        if ([UIAHelper]::ClickButtonByName('Confirm')) {
            if (-not $clickedCaution) {
                Write-LaunchLog 'clicked CAUTION Confirm'
                $clickedCaution = $true
            }
        } else {
            # GPU overlay fallback — Enter often activates focused Confirm
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
            Write-LaunchLog 'CAUTION Confirm fallback (Enter)'
            $clickedCaution = $true
        }
        Start-Sleep -Milliseconds $PollMs
        continue
    }

    if (-not $clickedPlayContinue) {
        if ([UIAHelper]::ClickButtonByName($targetButton)) {
            Write-LaunchLog "clicked $targetButton"
            $clickedPlayContinue = $true
        }
    }

    Start-Sleep -Milliseconds $PollMs
}

throw "launcher-auto-nav timed out after ${TimeoutSec}s (see $logPath)"
