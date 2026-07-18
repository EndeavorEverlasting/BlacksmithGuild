[CmdletBinding()]
param(
    [ValidateSet('scan','watch','status','learn')]
    [string]$Command = 'scan',

    [ValidateSet('observe','auto','strict')]
    [string]$Mode = 'observe',

    [int]$ProcessId = 0,
    [Int64]$Hwnd = 0,
    [string]$IdentityId,
    [string]$BannerlordRoot,
    [string]$FixturePath,
    [string]$RegistryPath,
    [string]$PolicyPath,
    [string]$CachePath,
    [string]$OutputDirectory,
    [string]$ContextPath,
    [string]$LifecycleRunId,
    [string]$LifecycleCorrelationId,
    [int]$DurationSeconds = 30,
    [int]$PollMilliseconds = 100,
    [switch]$AllowKnownActions,
    [switch]$AllowFocusSteal,
    [switch]$NoJournal,
    [switch]$NoLifecycle
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if ([string]::IsNullOrWhiteSpace($RegistryPath)) {
    $RegistryPath = Join-Path $repoRoot '.tbg/harness/window-identities.registry.json'
}
if ([string]::IsNullOrWhiteSpace($PolicyPath)) {
    $PolicyPath = Join-Path $repoRoot '.tbg/harness/policies/window-intelligence.policy.json'
}
if ([string]::IsNullOrWhiteSpace($CachePath)) {
    $CachePath = Join-Path $repoRoot '.local/tbg-window-intelligence/learned-window-aliases.json'
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot 'artifacts/latest/window-intelligence'
}

$resultPath = Join-Path $OutputDirectory 'window-intelligence.result.json'
$reportPath = Join-Path $OutputDirectory 'window-intelligence.report.md'
$eventsPath = Join-Path $OutputDirectory 'window-intelligence.events.jsonl'
$progressPath = Join-Path $OutputDirectory 'window-intelligence.progress.log'
$handoffPath = Join-Path $OutputDirectory 'window-intelligence.handoff.md'
$learningPath = Join-Path $OutputDirectory 'window-intelligence.learning-candidates.json'
$leasePath = Join-Path (Split-Path -Parent $CachePath) 'watcher.json'
$actionLeasePath = Join-Path (Split-Path -Parent $CachePath) 'action-leases.json'

function Resolve-TbgFullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([IO.Path]::IsPathRooted($Path)) { return $Path }
    return Join-Path $repoRoot $Path
}

function Ensure-TbgDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Write-TbgJson {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$Depth = 20
    )
    $parent = Split-Path -Parent $Path
    if ($parent) { Ensure-TbgDirectory -Path $parent }
    $Value | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Read-TbgJson {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try { return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $null }
}

function Get-TbgSha256 {
    param([AllowEmptyString()][string]$Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes([string]$Text)
        $hash = $sha.ComputeHash($bytes)
        return ([BitConverter]::ToString($hash).Replace('-', '').ToLowerInvariant())
    }
    finally { $sha.Dispose() }
}

function Normalize-TbgText {
    param([AllowNull()][string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    return ([regex]::Replace($Text.Trim().ToLowerInvariant(), '\s+', ' '))
}

function Normalize-TbgVersion {
    param([AllowNull()][string]$Version)
    if ([string]::IsNullOrWhiteSpace($Version)) { return $null }
    $clean = $Version.Trim()
    if ($clean.StartsWith('v', [StringComparison]::OrdinalIgnoreCase)) { $clean = $clean.Substring(1) }
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($part in @($clean -split '\.')) {
        if ($part -match '^([0-9]+)') { $parts.Add($Matches[1]) | Out-Null }
    }
    while ($parts.Count -lt 4) { $parts.Add('0') | Out-Null }
    return (@($parts.ToArray()) -join '.')
}

function Add-TbgProgress {
    param([Parameter(Mandatory = $true)][string]$Sentence)
    $line = '[{0}] {1}' -f ([DateTime]::UtcNow.ToString('o')), $Sentence
    Add-Content -LiteralPath $progressPath -Value $line -Encoding UTF8
    Write-Host $Sentence
}

function Add-TbgEvent {
    param(
        [Parameter(Mandatory = $true)][string]$EventType,
        [Parameter(Mandatory = $true)][string]$Sentence,
        [hashtable]$Data = @{}
    )
    $event = [ordered]@{
        schema = 'TbgWindowIntelligenceEvent.v1'
        sequence = ((Get-Content -LiteralPath $eventsPath -ErrorAction SilentlyContinue | Measure-Object).Count + 1)
        timestampUtc = [DateTime]::UtcNow.ToString('o')
        eventType = $EventType
        subject = 'The window intelligence harness'
        action = $EventType
        object = if ($Data.ContainsKey('identityId')) { [string]$Data.identityId } else { 'the observed window' }
        condition = if ($Data.ContainsKey('condition')) { [string]$Data.condition } else { 'when the metadata was evaluated' }
        evidence = $Data
        sentence = $Sentence
    }
    ($event | ConvertTo-Json -Depth 15 -Compress) | Add-Content -LiteralPath $eventsPath -Encoding UTF8
    Add-TbgProgress -Sentence $Sentence
    return $event
}

function Test-TbgWindowsHost {
    return ($env:OS -eq 'Windows_NT')
}

function Initialize-TbgNativeWindowType {
    if (-not (Test-TbgWindowsHost)) { return }
    if ('TbgWindowNative' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class TbgWindowNative
{
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

    public class ChildInfo
    {
        public long Hwnd;
        public string Text;
        public string ClassName;
        public bool Visible;
        public bool Enabled;
    }

    public class WindowInfo
    {
        public long Hwnd;
        public int ProcessId;
        public string Title;
        public string ClassName;
        public bool Visible;
        public bool Enabled;
        public RECT Rect;
        public List<ChildInfo> Children = new List<ChildInfo>();
    }

    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
    [DllImport("user32.dll")] private static extern bool EnumChildWindows(IntPtr parent, EnumWindowsProc callback, IntPtr lParam);
    [DllImport("user32.dll")] private static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int maxCount);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetClassName(IntPtr hWnd, StringBuilder text, int maxCount);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern bool IsWindowEnabled(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);

    private static string ReadText(IntPtr hWnd)
    {
        int length = GetWindowTextLength(hWnd);
        var sb = new StringBuilder(Math.Max(512, length + 2));
        GetWindowText(hWnd, sb, sb.Capacity);
        return sb.ToString();
    }

    private static string ReadClass(IntPtr hWnd)
    {
        var sb = new StringBuilder(512);
        GetClassName(hWnd, sb, sb.Capacity);
        return sb.ToString();
    }

    public static List<WindowInfo> Enumerate()
    {
        var result = new List<WindowInfo>();
        EnumWindows((hWnd, lParam) =>
        {
            uint pid;
            GetWindowThreadProcessId(hWnd, out pid);
            RECT rect;
            GetWindowRect(hWnd, out rect);
            var item = new WindowInfo {
                Hwnd = hWnd.ToInt64(), ProcessId = (int)pid, Title = ReadText(hWnd),
                ClassName = ReadClass(hWnd), Visible = IsWindowVisible(hWnd),
                Enabled = IsWindowEnabled(hWnd), Rect = rect
            };
            EnumChildWindows(hWnd, (child, lp) =>
            {
                item.Children.Add(new ChildInfo {
                    Hwnd = child.ToInt64(), Text = ReadText(child), ClassName = ReadClass(child),
                    Visible = IsWindowVisible(child), Enabled = IsWindowEnabled(child)
                });
                return true;
            }, IntPtr.Zero);
            result.Add(item);
            return true;
        }, IntPtr.Zero);
        return result;
    }
}
'@ -ErrorAction Stop
}

function Get-TbgUiaElements {
    param(
        [Parameter(Mandatory = $true)][Int64]$TargetHwnd,
        [int]$MaximumControls = 256
    )
    $items = New-Object System.Collections.Generic.List[object]
    if (-not (Test-TbgWindowsHost)) { return @() }
    try {
        Add-Type -AssemblyName UIAutomationClient -ErrorAction Stop
        Add-Type -AssemblyName UIAutomationTypes -ErrorAction Stop
        $root = [System.Windows.Automation.AutomationElement]::FromHandle([IntPtr]$TargetHwnd)
        if (-not $root) { return @() }
        $collection = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
        $count = [Math]::Min($collection.Count, $MaximumControls)
        for ($index = 0; $index -lt $count; $index++) {
            $element = $collection.Item($index)
            try {
                $typeName = [string]$element.Current.ControlType.ProgrammaticName
                if ($typeName -like 'ControlType.*') { $typeName = $typeName.Substring(12) }
                $items.Add([pscustomobject][ordered]@{
                    name = [string]$element.Current.Name
                    automationId = [string]$element.Current.AutomationId
                    className = [string]$element.Current.ClassName
                    controlType = $typeName
                    enabled = [bool]$element.Current.IsEnabled
                    offscreen = [bool]$element.Current.IsOffscreen
                }) | Out-Null
            } catch { }
        }
    } catch { }
    return @($items.ToArray())
}

function Get-TbgDependencyComparison {
    param([string]$InstalledRoot)
    $comparisons = New-Object System.Collections.Generic.List[object]
    $repoSubModulePath = Join-Path $repoRoot 'Module/BlacksmithGuild/SubModule.xml'
    if (-not (Test-Path -LiteralPath $repoSubModulePath -PathType Leaf)) { return @() }
    try { [xml]$repoModule = Get-Content -LiteralPath $repoSubModulePath -Raw -Encoding UTF8 } catch { return @() }
    foreach ($dependency in @($repoModule.Module.DependedModules.DependedModule)) {
        $moduleId = [string]$dependency.Id
        $expected = Normalize-TbgVersion -Version ([string]$dependency.DependentVersion)
        $current = $null
        $installedPath = $null
        if (-not [string]::IsNullOrWhiteSpace($InstalledRoot)) {
            $installedPath = Join-Path $InstalledRoot ("Modules/{0}/SubModule.xml" -f $moduleId)
            if (Test-Path -LiteralPath $installedPath -PathType Leaf) {
                try {
                    [xml]$installedModule = Get-Content -LiteralPath $installedPath -Raw -Encoding UTF8
                    $current = Normalize-TbgVersion -Version ([string]$installedModule.Module.Version.value)
                } catch { }
            }
        }
        $comparisons.Add([pscustomobject][ordered]@{
            module = $moduleId
            expectedVersion = $expected
            currentVersion = $current
            mismatch = [bool]($current -and $expected -and $current -ne $expected)
            installedMetadataPath = $installedPath
        }) | Out-Null
    }
    return @($comparisons.ToArray())
}

function Get-TbgRelevantProcessName {
    param([int]$TargetProcessId)
    try { return [string](Get-Process -Id $TargetProcessId -ErrorAction Stop).ProcessName } catch { return '' }
}

function Get-TbgExecutablePath {
    param([int]$TargetProcessId)
    try { return [string](Get-Process -Id $TargetProcessId -ErrorAction Stop).Path } catch { return $null }
}

function New-TbgNativeObservation {
    param(
        [Parameter(Mandatory = $true)]$Window,
        [Parameter(Mandatory = $true)][object[]]$DependencyComparison,
        [int]$MaximumControls = 256
    )
    $uia = @(Get-TbgUiaElements -TargetHwnd ([Int64]$Window.Hwnd) -MaximumControls $MaximumControls)
    $texts = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace([string]$Window.Title)) { $texts.Add([string]$Window.Title) | Out-Null }
    foreach ($child in @($Window.Children)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$child.Text)) { $texts.Add([string]$child.Text) | Out-Null }
    }
    foreach ($element in $uia) {
        if (-not [string]::IsNullOrWhiteSpace([string]$element.name)) { $texts.Add([string]$element.name) | Out-Null }
    }
    $rect = [pscustomobject][ordered]@{
        left = [int]$Window.Rect.Left
        top = [int]$Window.Rect.Top
        right = [int]$Window.Rect.Right
        bottom = [int]$Window.Rect.Bottom
        width = [int]$Window.Rect.Right - [int]$Window.Rect.Left
        height = [int]$Window.Rect.Bottom - [int]$Window.Rect.Top
    }
    return [pscustomobject][ordered]@{
        schema = 'TbgWindowObservation.v1'
        source = 'native_metadata'
        capturedAtUtc = [DateTime]::UtcNow.ToString('o')
        process = [pscustomobject][ordered]@{
            pid = [int]$Window.ProcessId
            processName = Get-TbgRelevantProcessName -TargetProcessId ([int]$Window.ProcessId)
            executablePath = Get-TbgExecutablePath -TargetProcessId ([int]$Window.ProcessId)
        }
        window = [pscustomobject][ordered]@{
            hwnd = [Int64]$Window.Hwnd
            title = [string]$Window.Title
            className = [string]$Window.ClassName
            visible = [bool]$Window.Visible
            enabled = [bool]$Window.Enabled
            rect = $rect
        }
        win32Texts = @($texts.ToArray() | Select-Object -Unique)
        uiaElements = $uia
        dependencyComparison = @($DependencyComparison)
    }
}

function Get-TbgObservationTexts {
    param([Parameter(Mandatory = $true)]$Observation)
    $texts = New-Object System.Collections.Generic.List[string]
    if ($Observation.window -and $Observation.window.title) { $texts.Add([string]$Observation.window.title) | Out-Null }
    foreach ($text in @($Observation.win32Texts)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$text)) { $texts.Add([string]$text) | Out-Null }
    }
    foreach ($element in @($Observation.uiaElements)) {
        if ($element.name -and -not [string]::IsNullOrWhiteSpace([string]$element.name)) { $texts.Add([string]$element.name) | Out-Null }
        if ($element.automationId -and -not [string]::IsNullOrWhiteSpace([string]$element.automationId)) { $texts.Add([string]$element.automationId) | Out-Null }
    }
    return @($texts.ToArray() | Select-Object -Unique)
}

function Get-TbgControlNames {
    param([Parameter(Mandatory = $true)]$Observation)
    $names = New-Object System.Collections.Generic.List[string]
    foreach ($element in @($Observation.uiaElements)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$element.name)) { $names.Add([string]$element.name) | Out-Null }
        if (-not [string]::IsNullOrWhiteSpace([string]$element.automationId)) { $names.Add([string]$element.automationId) | Out-Null }
    }
    return @($names.ToArray() | Select-Object -Unique)
}

function Get-TbgWindowFingerprint {
    param([Parameter(Mandatory = $true)]$Observation)
    $controlNames = @(Get-TbgControlNames -Observation $Observation | ForEach-Object { Normalize-TbgText $_ } | Sort-Object -Unique)
    $texts = @(Get-TbgObservationTexts -Observation $Observation | ForEach-Object { Normalize-TbgText $_ } | Sort-Object -Unique)
    $fingerprintObject = [ordered]@{
        processName = Normalize-TbgText ([string]$Observation.process.processName)
        title = Normalize-TbgText ([string]$Observation.window.title)
        className = Normalize-TbgText ([string]$Observation.window.className)
        controls = $controlNames
        texts = $texts
    }
    $json = $fingerprintObject | ConvertTo-Json -Depth 10 -Compress
    return [pscustomobject][ordered]@{
        hash = Get-TbgSha256 -Text $json
        normalized = $fingerprintObject
    }
}

function Read-TbgCache {
    param([Parameter(Mandatory = $true)]$Registry)
    $cache = Read-TbgJson -Path $CachePath
    if (-not $cache) {
        return [pscustomobject][ordered]@{
            schema = 'TbgWindowIdentityCache.v1'
            registryVersion = [string]$Registry.version
            updatedAtUtc = [DateTime]::UtcNow.ToString('o')
            aliases = @()
        }
    }
    return $cache
}

function Save-TbgCache {
    param([Parameter(Mandatory = $true)]$Cache)
    $Cache.updatedAtUtc = [DateTime]::UtcNow.ToString('o')
    Write-TbgJson -Value $Cache -Path $CachePath -Depth 15
}

function Get-TbgDirectSignals {
    param([Parameter(Mandatory = $true)]$Observation)
    $texts = @((Get-TbgObservationTexts -Observation $Observation) | ForEach-Object { Normalize-TbgText $_ })
    $controls = @((Get-TbgControlNames -Observation $Observation) | ForEach-Object { Normalize-TbgText $_ })
    $joined = $texts -join "`n"
    $signals = New-Object System.Collections.Generic.List[string]
    if ($joined -match 'caution') { $signals.Add('caution_text_or_control') | Out-Null }
    if ($controls -contains 'confirm') { $signals.Add('confirm_control') | Out-Null }
    if (@($Observation.dependencyComparison | Where-Object { [bool]$_.mismatch }).Count -gt 0) { $signals.Add('dependency_mismatch') | Out-Null }
    if ($joined -match 'safe mode' -or (Normalize-TbgText ([string]$Observation.window.title)) -match 'safe mode') { $signals.Add('safe_mode_title_or_text') | Out-Null }
    if ($controls -contains 'no') { $signals.Add('no_control') | Out-Null }
    if ($controls -contains 'play') { $signals.Add('play_control') | Out-Null }
    if ($controls -contains 'continue') { $signals.Add('continue_control') | Out-Null }
    return @($signals.ToArray() | Select-Object -Unique)
}

function Test-TbgRegexAny {
    param([string[]]$Patterns, [string[]]$Values)
    foreach ($pattern in @($Patterns)) {
        foreach ($value in @($Values)) {
            if ([regex]::IsMatch([string]$value, [string]$pattern)) { return $true }
        }
    }
    return $false
}

function Test-TbgRegexAll {
    param([string[]]$Patterns, [string[]]$Values)
    foreach ($pattern in @($Patterns)) {
        $matched = $false
        foreach ($value in @($Values)) {
            if ([regex]::IsMatch([string]$value, [string]$pattern)) { $matched = $true; break }
        }
        if (-not $matched) { return $false }
    }
    return $true
}

function Resolve-TbgWindowIdentity {
    param(
        [Parameter(Mandatory = $true)]$Observation,
        [Parameter(Mandatory = $true)]$Registry,
        [Parameter(Mandatory = $true)]$Cache
    )
    $fingerprint = Get-TbgWindowFingerprint -Observation $Observation
    $directSignals = @(Get-TbgDirectSignals -Observation $Observation)
    $cacheMatch = @($Cache.aliases | Where-Object { [string]$_.fingerprintHash -eq $fingerprint.hash -and [string]$Cache.registryVersion -eq [string]$Registry.version } | Select-Object -First 1)
    if ($cacheMatch.Count -gt 0) {
        $cachedIdentity = @($Registry.identities | Where-Object { [string]$_.id -eq [string]$cacheMatch[0].identityId } | Select-Object -First 1)
        if ($cachedIdentity.Count -gt 0) {
            return [pscustomobject][ordered]@{
                recognized = $true
                identityId = [string]$cachedIdentity[0].id
                displayName = [string]$cachedIdentity[0].displayName
                score = 100
                basis = 'exact_cached_fingerprint'
                directSignals = $directSignals
                fingerprint = $fingerprint
                identity = $cachedIdentity[0]
                candidates = @()
            }
        }
    }

    $texts = @(Get-TbgObservationTexts -Observation $Observation)
    $controls = @(Get-TbgControlNames -Observation $Observation)
    $processName = [string]$Observation.process.processName
    $title = [string]$Observation.window.title
    $candidates = New-Object System.Collections.Generic.List[object]

    foreach ($identity in @($Registry.identities)) {
        $score = 0
        $matchedSignals = New-Object System.Collections.Generic.List[string]
        $hardFailure = $false
        $match = $identity.match

        if (@($match.processNames).Count -gt 0) {
            $processMatch = @($match.processNames | Where-Object { [string]$_ -ieq $processName }).Count -gt 0
            if ($processMatch) { $score += 15; $matchedSignals.Add('process_name') | Out-Null } else { $hardFailure = $true }
        }
        if (-not $hardFailure -and @($match.titleRegex).Count -gt 0) {
            if (Test-TbgRegexAny -Patterns @($match.titleRegex) -Values @($title)) { $score += 20; $matchedSignals.Add('title') | Out-Null }
        }
        if (-not $hardFailure -and @($match.anyControlNames).Count -gt 0) {
            $controlMatch = $false
            foreach ($expectedControl in @($match.anyControlNames)) {
                if (@($controls | Where-Object { [string]$_ -ieq [string]$expectedControl }).Count -gt 0) { $controlMatch = $true; break }
            }
            if ($controlMatch) { $score += 20; $matchedSignals.Add('named_control') | Out-Null }
        }
        if (-not $hardFailure -and @($match.allTextRegex).Count -gt 0) {
            if (Test-TbgRegexAll -Patterns @($match.allTextRegex) -Values $texts) { $score += 30; $matchedSignals.Add('all_semantic_text') | Out-Null } else { $hardFailure = $true }
        }
        if (-not $hardFailure -and @($match.anyTextRegex).Count -gt 0) {
            if (Test-TbgRegexAny -Patterns @($match.anyTextRegex) -Values $texts) { $score += 15; $matchedSignals.Add('semantic_text') | Out-Null }
        }
        if (-not $hardFailure -and $match.PSObject.Properties['dependencyMismatch'] -and [bool]$match.dependencyMismatch) {
            if (@($Observation.dependencyComparison | Where-Object { [bool]$_.mismatch }).Count -gt 0) { $score += 20; $matchedSignals.Add('dependency_mismatch') | Out-Null } else { $hardFailure = $true }
        }
        if ($hardFailure) { $score = 0 }
        if ($score -gt 100) { $score = 100 }
        $candidates.Add([pscustomobject][ordered]@{
            identityId = [string]$identity.id
            displayName = [string]$identity.displayName
            score = $score
            matchedSignals = @($matchedSignals.ToArray())
            identity = $identity
        }) | Out-Null
    }

    $winner = @($candidates.ToArray() | Sort-Object score -Descending | Select-Object -First 1)
    $minimum = [int]$Registry.defaultPolicy.minimumRecognitionScore
    if ($winner.Count -gt 0 -and [int]$winner[0].score -ge $minimum) {
        return [pscustomobject][ordered]@{
            recognized = $true
            identityId = [string]$winner[0].identityId
            displayName = [string]$winner[0].displayName
            score = [int]$winner[0].score
            basis = 'tracked_registry_metadata_match'
            directSignals = $directSignals
            fingerprint = $fingerprint
            identity = $winner[0].identity
            candidates = @($candidates.ToArray() | Sort-Object score -Descending | Select-Object identityId,score,matchedSignals)
        }
    }

    return [pscustomobject][ordered]@{
        recognized = $false
        identityId = $null
        displayName = 'Unknown window'
        score = if ($winner.Count -gt 0) { [int]$winner[0].score } else { 0 }
        basis = 'delta_discovery_required'
        directSignals = $directSignals
        fingerprint = $fingerprint
        identity = $null
        candidates = @($candidates.ToArray() | Sort-Object score -Descending | Select-Object identityId,score,matchedSignals)
    }
}

function Update-TbgLearnedAlias {
    param(
        [Parameter(Mandatory = $true)]$Resolution,
        [Parameter(Mandatory = $true)]$Observation,
        [Parameter(Mandatory = $true)]$Registry,
        [Parameter(Mandatory = $true)]$Cache,
        [switch]$Explicit
    )
    if (-not $Resolution.identityId) { return $Cache }
    if (-not $Explicit -and [int]$Resolution.score -lt 90) { return $Cache }
    $now = [DateTime]::UtcNow.ToString('o')
    $existing = @($Cache.aliases | Where-Object { [string]$_.fingerprintHash -eq [string]$Resolution.fingerprint.hash } | Select-Object -First 1)
    if ($existing.Count -gt 0) {
        $existing[0].lastSeenUtc = $now
        $existing[0].hitCount = [int]$existing[0].hitCount + 1
        $existing[0].identityId = [string]$Resolution.identityId
    } else {
        $newAlias = [pscustomobject][ordered]@{
            fingerprintHash = [string]$Resolution.fingerprint.hash
            identityId = [string]$Resolution.identityId
            registryVersion = [string]$Registry.version
            normalizedTitle = [string]$Resolution.fingerprint.normalized.title
            className = [string]$Resolution.fingerprint.normalized.className
            processName = [string]$Resolution.fingerprint.normalized.processName
            controlNames = @($Resolution.fingerprint.normalized.controls)
            firstSeenUtc = $now
            lastSeenUtc = $now
            hitCount = 1
            source = if ($Explicit) { 'explicit_learning' } else { 'high_confidence_registry_match' }
        }
        $Cache.aliases = @($Cache.aliases) + @($newAlias)
    }
    $Cache.registryVersion = [string]$Registry.version
    Save-TbgCache -Cache $Cache
    return $Cache
}

function Get-TbgActionDecision {
    param(
        [Parameter(Mandatory = $true)]$Resolution,
        [Parameter(Mandatory = $true)]$Observation
    )
    if (-not $Resolution.recognized -or -not $Resolution.identity) {
        return [pscustomobject][ordered]@{ allowed = $false; reason = 'unknown_window'; actionId = $null; semanticAction = $null; preferredControlNames = @(); fallbackKeys = @() }
    }
    $policy = $Resolution.identity.actionPolicy
    if (-not $policy -or -not [bool]$policy.automatic) {
        return [pscustomobject][ordered]@{ allowed = $false; reason = 'identity_has_no_automatic_action'; actionId = $null; semanticAction = $null; preferredControlNames = @(); fallbackKeys = @() }
    }
    if ([int]$Resolution.score -lt [int]$policy.minimumScore) {
        return [pscustomobject][ordered]@{ allowed = $false; reason = 'identity_score_below_action_minimum'; actionId = [string]$policy.actionId; semanticAction = [string]$policy.semanticAction; preferredControlNames = @($policy.preferredControlNames); fallbackKeys = @($policy.fallbackKeys) }
    }
    $missingSignals = New-Object System.Collections.Generic.List[string]
    foreach ($required in @($policy.requiredDirectSignals)) {
        if (@($Resolution.directSignals | Where-Object { [string]$_ -eq [string]$required }).Count -eq 0) { $missingSignals.Add([string]$required) | Out-Null }
    }
    if ($missingSignals.Count -gt 0) {
        return [pscustomobject][ordered]@{ allowed = $false; reason = 'required_direct_signals_missing'; missingSignals = @($missingSignals.ToArray()); actionId = [string]$policy.actionId; semanticAction = [string]$policy.semanticAction; preferredControlNames = @($policy.preferredControlNames); fallbackKeys = @($policy.fallbackKeys) }
    }
    return [pscustomobject][ordered]@{
        allowed = $true
        reason = 'known_identity_and_direct_action_signals_present'
        actionId = [string]$policy.actionId
        semanticAction = [string]$policy.semanticAction
        preferredControlNames = @($policy.preferredControlNames)
        fallbackKeys = @($policy.fallbackKeys)
        fallbackRequiresForegroundAuthority = [bool]$policy.fallbackRequiresForegroundAuthority
    }
}

function Read-TbgActionLeases {
    $leases = Read-TbgJson -Path $actionLeasePath
    if (-not $leases) { return [pscustomobject][ordered]@{ schema = 'TbgWindowActionLeases.v1'; actions = @() } }
    return $leases
}

function Save-TbgActionLeases {
    param([Parameter(Mandatory = $true)]$Leases)
    Write-TbgJson -Value $Leases -Path $actionLeasePath -Depth 12
}

function Test-TbgActionAlreadyDispatched {
    param([Parameter(Mandatory = $true)][string]$LeaseKey)
    $leases = Read-TbgActionLeases
    return (@($leases.actions | Where-Object { [string]$_.leaseKey -eq $LeaseKey }).Count -gt 0)
}

function Add-TbgActionLease {
    param([Parameter(Mandatory = $true)][string]$LeaseKey, [Parameter(Mandatory = $true)][string]$ActionId)
    $leases = Read-TbgActionLeases
    $leases.actions = @($leases.actions) + @([pscustomobject][ordered]@{
        leaseKey = $LeaseKey
        actionId = $ActionId
        dispatchedAtUtc = [DateTime]::UtcNow.ToString('o')
    })
    Save-TbgActionLeases -Leases $leases
}

function Invoke-TbgUiaNamedControl {
    param(
        [Parameter(Mandatory = $true)][Int64]$TargetHwnd,
        [Parameter(Mandatory = $true)][string[]]$Names
    )
    if (-not (Test-TbgWindowsHost)) { return $false }
    try {
        Add-Type -AssemblyName UIAutomationClient -ErrorAction Stop
        Add-Type -AssemblyName UIAutomationTypes -ErrorAction Stop
        $root = [System.Windows.Automation.AutomationElement]::FromHandle([IntPtr]$TargetHwnd)
        if (-not $root) { return $false }
        foreach ($name in @($Names)) {
            $condition = New-Object -TypeName System.Windows.Automation.PropertyCondition -ArgumentList @(
            [System.Windows.Automation.AutomationElement]::NameProperty,
            [string]$name
        )
            $element = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
            if (-not $element) { continue }
            if (-not [bool]$element.Current.IsEnabled) { continue }
            $patternObject = $null
            if ($element.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$patternObject)) {
                ([System.Windows.Automation.InvokePattern]$patternObject).Invoke()
                return $true
            }
        }
    } catch { }
    return $false
}

function Invoke-TbgKnownWindowAction {
    param(
        [Parameter(Mandatory = $true)]$Observation,
        [Parameter(Mandatory = $true)]$Resolution,
        [Parameter(Mandatory = $true)]$Decision
    )
    $leaseKey = '{0}|{1}|{2}' -f $Resolution.fingerprint.hash, $Decision.actionId, [string]$Observation.window.hwnd
    if (Test-TbgActionAlreadyDispatched -LeaseKey $leaseKey) {
        return [pscustomobject][ordered]@{ dispatched = $false; method = 'none'; reason = 'action_lease_already_exists'; leaseKey = $leaseKey }
    }
    if ($FixturePath) {
        return [pscustomobject][ordered]@{ dispatched = $false; wouldDispatch = $true; method = 'fixture_simulation'; reason = 'fixture_does_not_mutate_windows'; leaseKey = $leaseKey }
    }
    if (-not (Test-TbgWindowsHost)) {
        return [pscustomobject][ordered]@{ dispatched = $false; method = 'none'; reason = 'windows_host_required'; leaseKey = $leaseKey }
    }
    Initialize-TbgNativeWindowType
    $target = [IntPtr]([Int64]$Observation.window.hwnd)
    if (-not [TbgWindowNative]::IsWindow($target)) {
        return [pscustomobject][ordered]@{ dispatched = $false; method = 'none'; reason = 'target_hwnd_no_longer_exists'; leaseKey = $leaseKey }
    }
    if (Invoke-TbgUiaNamedControl -TargetHwnd ([Int64]$Observation.window.hwnd) -Names @($Decision.preferredControlNames)) {
        Add-TbgActionLease -LeaseKey $leaseKey -ActionId ([string]$Decision.actionId)
        return [pscustomobject][ordered]@{ dispatched = $true; method = 'uia_invoke'; reason = 'exact_named_control_invoked'; leaseKey = $leaseKey }
    }
    if (-not $AllowFocusSteal -and [bool]$Decision.fallbackRequiresForegroundAuthority) {
        return [pscustomobject][ordered]@{ dispatched = $false; method = 'none'; reason = 'keyboard_fallback_requires_foreground_authority'; leaseKey = $leaseKey }
    }
    [void][TbgWindowNative]::SetForegroundWindow($target)
    Start-Sleep -Milliseconds 60
    $shell = New-Object -ComObject WScript.Shell
    foreach ($key in @($Decision.fallbackKeys)) {
        if ([string]$key -eq 'ENTER') { $shell.SendKeys('{ENTER}') }
        elseif ([string]$key -eq 'ALT+N') { $shell.SendKeys('%n') }
        else { continue }
        Add-TbgActionLease -LeaseKey $leaseKey -ActionId ([string]$Decision.actionId)
        return [pscustomobject][ordered]@{ dispatched = $true; method = 'keyboard_fallback'; reason = ('known_identity_fallback_{0}' -f ([string]$key).ToLowerInvariant().Replace('+','_')); leaseKey = $leaseKey }
    }
    return [pscustomobject][ordered]@{ dispatched = $false; method = 'none'; reason = 'no_action_method_succeeded'; leaseKey = $leaseKey }
}

function Get-TbgParsedDependencies {
    param([Parameter(Mandatory = $true)]$Observation)
    $parsed = New-Object System.Collections.Generic.List[object]
    $lineRegex = '(?i)(?<module>Native|SandBoxCore|Sandbox|StoryMode).*?depends on.*?v(?<expected>[0-9.]+).*?current version is.*?v(?<current>[0-9.]+)'
    foreach ($text in @(Get-TbgObservationTexts -Observation $Observation)) {
        $match = [regex]::Match([string]$text, $lineRegex)
        if ($match.Success) {
            $parsed.Add([pscustomobject][ordered]@{
                module = $match.Groups['module'].Value
                expectedVersion = Normalize-TbgVersion -Version $match.Groups['expected'].Value
                currentVersion = Normalize-TbgVersion -Version $match.Groups['current'].Value
                source = 'visible_window_text'
            }) | Out-Null
        }
    }
    if ($parsed.Count -eq 0) {
        foreach ($item in @($Observation.dependencyComparison | Where-Object { [bool]$_.mismatch })) {
            $parsed.Add([pscustomobject][ordered]@{
                module = [string]$item.module
                expectedVersion = [string]$item.expectedVersion
                currentVersion = [string]$item.currentVersion
                source = 'module_dependency_metadata'
            }) | Out-Null
        }
    }
    return @($parsed.ToArray())
}

function Write-TbgJournalObservation {
    param(
        [Parameter(Mandatory = $true)]$Observation,
        [Parameter(Mandatory = $true)]$Resolution,
        [Parameter(Mandatory = $true)]$ActionResult,
        [Parameter(Mandatory = $true)][string]$CorrelationId
    )
    if ($NoJournal -or $FixturePath) { return }
    $writer = Join-Path $repoRoot 'scripts/tbg/Write-TbgJournalEvent.ps1'
    if (-not (Test-Path -LiteralPath $writer -PathType Leaf)) { return }
    try {
        $payload = @{
            identityId = [string]$Resolution.identityId
            score = [int]$Resolution.score
            basis = [string]$Resolution.basis
            processId = [int]$Observation.process.pid
            hwnd = [Int64]$Observation.window.hwnd
            title = [string]$Observation.window.title
            fingerprintHash = [string]$Resolution.fingerprint.hash
            actionDispatched = [bool]$ActionResult.dispatched
            actionMethod = [string]$ActionResult.method
        }
        & $writer -EventType 'window.observed' -SourceKind 'runtime adapter' -SourceId 'window-intelligence' `
            -CorrelationId $CorrelationId -PayloadSchema 'TbgWindowObservation.v1' -Payload $payload `
            -RequestedDisposition 'process' -IdempotencyKey ('window|{0}|{1}' -f $Resolution.fingerprint.hash, [string]$ActionResult.method) -RepoRoot $repoRoot | Out-Null
    } catch { }
}

function Get-TbgWindowLifecycleKey {
    param([Parameter(Mandatory = $true)]$Observation)
    return 'pid:{0}|hwnd:{1}' -f [int]$Observation.process.pid, [Int64]$Observation.window.hwnd
}

function Initialize-TbgWindowLifecycleRuntimeSession {
    param([Parameter(Mandatory = $true)][string]$CorrelationId)

    if ($NoLifecycle) { return $null }
    if ([string]::IsNullOrWhiteSpace($script:lifecycleRunId)) {
        $script:lifecycleRunId = if ([string]::IsNullOrWhiteSpace($LifecycleRunId)) {
            'wl-{0}-{1}' -f ([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')), ([Guid]::NewGuid().ToString('N').Substring(0, 8))
        } else {
            $LifecycleRunId
        }
    }
    if ([string]::IsNullOrWhiteSpace($script:lifecycleCorrelationId)) {
        $script:lifecycleCorrelationId = if ([string]::IsNullOrWhiteSpace($LifecycleCorrelationId)) { $CorrelationId } else { $LifecycleCorrelationId }
    }
    if ($null -eq $script:lifecycleSequenceByWindow) {
        $script:lifecycleSequenceByWindow = @{}
    }
    if ($null -eq $script:lifecycleKnownWindows) {
        $script:lifecycleKnownWindows = @{}
    }
    if ($null -eq $script:lifecycleRuntimePath) {
        $script:lifecycleRuntimePath = Join-Path $repoRoot 'scripts/tbg/Invoke-TbgWindowLifecycleRuntime.ps1'
    }
    return [pscustomobject][ordered]@{
        runId = [string]$script:lifecycleRunId
        correlationId = [string]$script:lifecycleCorrelationId
        runtimePath = [string]$script:lifecycleRuntimePath
    }
}

function Get-TbgNextLifecycleSequence {
    param([Parameter(Mandatory = $true)][string]$WindowKey)
    if (-not $script:lifecycleSequenceByWindow.ContainsKey($WindowKey)) {
        $script:lifecycleSequenceByWindow[$WindowKey] = 0
    }
    $script:lifecycleSequenceByWindow[$WindowKey] = [int]$script:lifecycleSequenceByWindow[$WindowKey] + 1
    return [int]$script:lifecycleSequenceByWindow[$WindowKey]
}

function Publish-TbgWindowLifecycleRuntimeEvents {
    param(
        [Parameter(Mandatory = $true)][object[]]$WindowResults,
        [Parameter(Mandatory = $true)][string]$CorrelationId,
        [switch]$EmitDisappearances
    )

    $session = Initialize-TbgWindowLifecycleRuntimeSession -CorrelationId $CorrelationId
    if ($null -eq $session) { return $null }
    if (-not (Test-Path -LiteralPath $session.runtimePath -PathType Leaf)) { return $null }

    $events = New-Object System.Collections.Generic.List[object]
    $currentKeys = @{}
    foreach ($item in @($WindowResults)) {
        $windowKey = Get-TbgWindowLifecycleKey -Observation $item.observation
        $currentKeys[$windowKey] = $true
        $isNewWindow = -not $script:lifecycleKnownWindows.ContainsKey($windowKey)
        $previous = if ($isNewWindow) { $null } else { $script:lifecycleKnownWindows[$windowKey] }

        if ($isNewWindow) {
            $events.Add([pscustomobject][ordered]@{
                    windowKey = $windowKey
                    sequence = (Get-TbgNextLifecycleSequence -WindowKey $windowKey)
                    eventType = 'window_observed'
                    sentence = 'The window intelligence harness observed a launcher or game window and forwarded it to the lifecycle runtime adapter.'
                }) | Out-Null
        }

        if ([bool]$item.resolution.recognized) {
            $alreadyRecognized = ($null -ne $previous) -and [bool]$previous.recognized -and ([string]$previous.identityId -eq [string]$item.resolution.identityId)
            if (-not $alreadyRecognized) {
                $events.Add([pscustomobject][ordered]@{
                        windowKey = $windowKey
                        sequence = (Get-TbgNextLifecycleSequence -WindowKey $windowKey)
                        eventType = 'identity_resolved'
                        identityId = [string]$item.resolution.identityId
                        sentence = ("The window intelligence harness resolved identity '{0}' and forwarded that recognition into the lifecycle reducer." -f [string]$item.resolution.identityId)
                    }) | Out-Null
                if ([string]$item.resolution.identityId -eq 'bannerlord.singleplayer-host') {
                    $events.Add([pscustomobject][ordered]@{
                            windowKey = $windowKey
                            sequence = (Get-TbgNextLifecycleSequence -WindowKey $windowKey)
                            eventType = 'host_handoff_observed'
                            identityId = 'bannerlord.singleplayer-host'
                            sentence = 'The window intelligence harness observed the canonical Singleplayer host and recorded a host handoff observation without claiming campaign readiness.'
                        }) | Out-Null
                }
            }
            $script:lifecycleKnownWindows[$windowKey] = [pscustomobject][ordered]@{
                identityId = [string]$item.resolution.identityId
                recognized = $true
            }
        }
        elseif ($isNewWindow) {
            $events.Add([pscustomobject][ordered]@{
                    windowKey = $windowKey
                    sequence = (Get-TbgNextLifecycleSequence -WindowKey $windowKey)
                    eventType = 'unknown_detected'
                    sentence = 'The window intelligence harness could not identify the observed window, so the lifecycle runtime adapter quarantined it.'
                }) | Out-Null
            $script:lifecycleKnownWindows[$windowKey] = [pscustomobject][ordered]@{
                identityId = $null
                recognized = $false
            }
        }
        else {
            $script:lifecycleKnownWindows[$windowKey] = [pscustomobject][ordered]@{
                identityId = $null
                recognized = $false
            }
        }

        if ([bool]$item.actionDecision.allowed) {
            $authorityKey = '{0}|authorized|{1}' -f $windowKey, [string]$item.actionDecision.actionId
            if (-not $script:lifecycleSequenceByWindow.ContainsKey($authorityKey)) {
                $events.Add([pscustomobject][ordered]@{
                        windowKey = $windowKey
                        sequence = (Get-TbgNextLifecycleSequence -WindowKey $windowKey)
                        eventType = 'action_authorized'
                        identityId = [string]$item.resolution.identityId
                        actionId = [string]$item.actionDecision.actionId
                        sentence = ("The window intelligence harness authorized action '{0}' from exact direct signals without claiming application acceptance." -f [string]$item.actionDecision.actionId)
                    }) | Out-Null
                $script:lifecycleSequenceByWindow[$authorityKey] = 1
            }
        }
        elseif ([bool]$item.resolution.recognized -and -not [bool]$item.actionDecision.allowed -and [string]$item.actionDecision.reason -match 'reject|invalid|missing') {
            $rejectKey = '{0}|rejected|{1}' -f $windowKey, [string]$item.actionDecision.reason
            if (-not $script:lifecycleSequenceByWindow.ContainsKey($rejectKey)) {
                $events.Add([pscustomobject][ordered]@{
                        windowKey = $windowKey
                        sequence = (Get-TbgNextLifecycleSequence -WindowKey $windowKey)
                        eventType = 'action_rejected'
                        identityId = [string]$item.resolution.identityId
                        actionId = [string]$item.actionDecision.actionId
                        reason = [string]$item.actionDecision.reason
                        sentence = ("The window intelligence harness rejected action authority because '{0}'." -f [string]$item.actionDecision.reason)
                    }) | Out-Null
                $script:lifecycleSequenceByWindow[$rejectKey] = 1
            }
        }

        if ([bool]$item.actionResult.dispatched) {
            $dispatchKey = '{0}|dispatched|{1}' -f $windowKey, [string]$item.actionDecision.actionId
            if (-not $script:lifecycleSequenceByWindow.ContainsKey($dispatchKey)) {
                $events.Add([pscustomobject][ordered]@{
                        windowKey = $windowKey
                        sequence = (Get-TbgNextLifecycleSequence -WindowKey $windowKey)
                        eventType = 'action_dispatched'
                        identityId = [string]$item.resolution.identityId
                        actionId = [string]$item.actionDecision.actionId
                        sentence = ("The window intelligence harness recorded action dispatch '{0}' through an exact registered control and did not promote that dispatch into application acceptance." -f [string]$item.actionDecision.actionId)
                    }) | Out-Null
                $script:lifecycleSequenceByWindow[$dispatchKey] = 1
            }
        }
        elseif ($FixturePath -and $item.actionResult.PSObject.Properties['wouldDispatch'] -and [bool]$item.actionResult.wouldDispatch) {
            # Fixture simulation proves authority only. Never emit action_dispatched for fixture runs.
        }
    }

    if ($EmitDisappearances) {
        foreach ($knownKey in @($script:lifecycleKnownWindows.Keys)) {
            if ($currentKeys.ContainsKey([string]$knownKey)) { continue }
            $disappearKey = '{0}|disappeared' -f [string]$knownKey
            if ($script:lifecycleSequenceByWindow.ContainsKey($disappearKey)) { continue }
            $events.Add([pscustomobject][ordered]@{
                    windowKey = [string]$knownKey
                    sequence = (Get-TbgNextLifecycleSequence -WindowKey ([string]$knownKey))
                    eventType = 'window_disappeared'
                    sentence = 'The window intelligence harness observed that a previously tracked window disappeared and recorded disappearance without treating it as application acceptance.'
                }) | Out-Null
            $script:lifecycleSequenceByWindow[$disappearKey] = 1
            $script:lifecycleKnownWindows.Remove([string]$knownKey)
        }
    }

    if ($events.Count -eq 0) { return $null }

    $launchIntent = 'unknown'
    $targetPid = $null
    $targetHwnd = $null
    if (-not [string]::IsNullOrWhiteSpace($ContextPath) -and (Test-Path -LiteralPath $ContextPath -PathType Leaf)) {
        try {
            $context = Read-TbgJson -Path $ContextPath
            if ($null -ne $context) {
                if ($context.PSObject.Properties['launchIntent']) { $launchIntent = [string]$context.launchIntent }
                if ($context.PSObject.Properties['processId']) { $targetPid = [int]$context.processId }
                if ($context.PSObject.Properties['hwnd']) { $targetHwnd = [Int64]$context.hwnd }
            }
        } catch { }
    }

    $mode = if ($FixturePath) { 'fixture' } else { 'live' }
    $eventJson = (@($events.ToArray()) | ConvertTo-Json -Depth 12 -Compress)
    if (-not $eventJson.StartsWith('[')) { $eventJson = "[$eventJson]" }
    $normalizedIntent = switch -Regex ([string]$launchIntent) {
        '^(?i)play$' { 'play' }
        '^(?i)continue$' { 'continue' }
        '^(?i)fixture$' { 'fixture' }
        default { 'unknown' }
    }

    try {
        $reduceArgs = @{
            Command = 'reduce'
            RunId = [string]$session.runId
            CorrelationId = [string]$session.correlationId
            EventJson = $eventJson
            Mode = $mode
            LaunchIntent = $normalizedIntent
            CreatedBy = 'Invoke-TbgWindowIntelligence.ps1'
            PassThru = $true
        }
        if (-not [string]::IsNullOrWhiteSpace($ContextPath)) { $reduceArgs.LauncherContextPath = $ContextPath }
        if ($null -ne $targetPid) { $reduceArgs.TargetProcessId = [int]$targetPid }
        if ($null -ne $targetHwnd) { $reduceArgs.TargetHwnd = [Int64]$targetHwnd }
        return & $session.runtimePath @reduceArgs
    }
    catch {
        Add-TbgProgress -Sentence ("The window intelligence harness could not publish lifecycle runtime events because {0}." -f $_.Exception.Message)
        return $null
    }
}

function Get-TbgNativeObservations {
    param([Parameter(Mandatory = $true)]$Registry)
    if (-not (Test-TbgWindowsHost)) { return @() }
    Initialize-TbgNativeWindowType
    $dependencyComparison = @(Get-TbgDependencyComparison -InstalledRoot $BannerlordRoot)
    $maximumControls = [int]$Registry.defaultPolicy.maximumControls
    $observations = New-Object System.Collections.Generic.List[object]
    foreach ($window in @([TbgWindowNative]::Enumerate())) {
        if ($Hwnd -ne 0 -and [Int64]$window.Hwnd -ne $Hwnd) { continue }
        if ($ProcessId -gt 0 -and [int]$window.ProcessId -ne $ProcessId) { continue }
        $processName = Get-TbgRelevantProcessName -TargetProcessId ([int]$window.ProcessId)
        if ($ProcessId -le 0 -and $processName -notmatch 'Bannerlord|TaleWorlds') { continue }
        if (-not [bool]$window.Visible -and [string]::IsNullOrWhiteSpace([string]$window.Title)) { continue }
        $observations.Add((New-TbgNativeObservation -Window $window -DependencyComparison $dependencyComparison -MaximumControls $maximumControls)) | Out-Null
    }
    return @($observations.ToArray())
}

function Get-TbgObservations {
    param([Parameter(Mandatory = $true)]$Registry)
    if ($FixturePath) {
        $resolvedFixture = Resolve-TbgFullPath -Path $FixturePath
        $fixture = Read-TbgJson -Path $resolvedFixture
        if (-not $fixture) { throw "Window intelligence fixture is missing or invalid: $resolvedFixture" }
        return @($fixture)
    }
    return @(Get-TbgNativeObservations -Registry $Registry)
}

function Add-TbgLearningCandidate {
    param([Parameter(Mandatory = $true)]$Observation, [Parameter(Mandatory = $true)]$Resolution)
    $existing = Read-TbgJson -Path $learningPath
    if (-not $existing) { $existing = [pscustomobject][ordered]@{ schema = 'TbgWindowLearningCandidates.v1'; candidates = @() } }
    if (@($existing.candidates | Where-Object { [string]$_.fingerprintHash -eq [string]$Resolution.fingerprint.hash }).Count -eq 0) {
        $existing.candidates = @($existing.candidates) + @([pscustomobject][ordered]@{
            fingerprintHash = [string]$Resolution.fingerprint.hash
            firstSeenUtc = [DateTime]::UtcNow.ToString('o')
            processName = [string]$Observation.process.processName
            title = [string]$Observation.window.title
            className = [string]$Observation.window.className
            controlNames = @(Get-TbgControlNames -Observation $Observation)
            topCandidates = @($Resolution.candidates | Select-Object -First 3)
            requiredFallback = 'capture S1/S2 delta once, then assign the canonical identity explicitly'
        })
        Write-TbgJson -Value $existing -Path $learningPath -Depth 15
    }
}

function Invoke-TbgScan {
    param(
        [Parameter(Mandatory = $true)]$Registry,
        [Parameter(Mandatory = $true)]$Cache,
        [Parameter(Mandatory = $true)][string]$CorrelationId
    )
    $windowResults = New-Object System.Collections.Generic.List[object]
    $observations = @(Get-TbgObservations -Registry $Registry)
    foreach ($observation in $observations) {
        $resolution = Resolve-TbgWindowIdentity -Observation $observation -Registry $Registry -Cache $Cache
        if ($Command -eq 'learn') {
            if ([string]::IsNullOrWhiteSpace($IdentityId)) { throw 'The learn command requires -IdentityId.' }
            $identity = @($Registry.identities | Where-Object { [string]$_.id -eq $IdentityId } | Select-Object -First 1)
            if ($identity.Count -eq 0) { throw "The identity '$IdentityId' is not present in the tracked registry." }
            $resolution.recognized = $true
            $resolution.identityId = [string]$identity[0].id
            $resolution.displayName = [string]$identity[0].displayName
            $resolution.score = 100
            $resolution.basis = 'explicit_learning'
            $resolution.identity = $identity[0]
            $Cache = Update-TbgLearnedAlias -Resolution $resolution -Observation $observation -Registry $Registry -Cache $Cache -Explicit
        }
        elseif ($resolution.recognized -and [bool]$Registry.defaultPolicy.cacheHighConfidenceMatches) {
            $Cache = Update-TbgLearnedAlias -Resolution $resolution -Observation $observation -Registry $Registry -Cache $Cache
        }
        else {
            Add-TbgLearningCandidate -Observation $observation -Resolution $resolution
        }

        $decision = Get-TbgActionDecision -Resolution $resolution -Observation $observation
        $actionResult = [pscustomobject][ordered]@{ dispatched = $false; method = 'none'; reason = 'automatic_action_not_requested' }
        if ($decision.allowed -and $AllowKnownActions -and ($Mode -eq 'auto' -or $Mode -eq 'strict')) {
            $actionResult = Invoke-TbgKnownWindowAction -Observation $observation -Resolution $resolution -Decision $decision
        }
        elseif ($decision.allowed -and -not $AllowKnownActions) {
            $actionResult = [pscustomobject][ordered]@{ dispatched = $false; wouldDispatch = $true; method = 'none'; reason = 'known_action_requires_AllowKnownActions' }
        }

        $parsedDependencies = @(Get-TbgParsedDependencies -Observation $observation)
        $sentence = if ($resolution.recognized) {
            "The window intelligence harness identified '$($resolution.displayName)' from $($resolution.basis) with score $($resolution.score)."
        } else {
            "The window intelligence harness could not identify the observed window, so the S1/S2 delta discovery fallback remains required."
        }
        Add-TbgEvent -EventType 'window.classified' -Sentence $sentence -Data @{
            identityId = [string]$resolution.identityId
            score = [int]$resolution.score
            basis = [string]$resolution.basis
            fingerprintHash = [string]$resolution.fingerprint.hash
        } | Out-Null
        if ($actionResult.dispatched) {
            Add-TbgEvent -EventType 'window.action.dispatched' -Sentence ("The window intelligence harness dispatched action '$($decision.actionId)' through $($actionResult.method) against the exact matching window.") -Data @{
                identityId = [string]$resolution.identityId
                actionId = [string]$decision.actionId
                method = [string]$actionResult.method
            } | Out-Null
        }
        elseif ($actionResult.PSObject.Properties['wouldDispatch'] -and [bool]$actionResult.wouldDispatch) {
            Add-TbgEvent -EventType 'window.action.ready' -Sentence ("The window intelligence harness proved that action '$($decision.actionId)' is ready, but this run did not mutate the window.") -Data @{
                identityId = [string]$resolution.identityId
                actionId = [string]$decision.actionId
                reason = [string]$actionResult.reason
            } | Out-Null
        }

        Write-TbgJournalObservation -Observation $observation -Resolution $resolution -ActionResult $actionResult -CorrelationId $CorrelationId
        $windowResults.Add([pscustomobject][ordered]@{
            observation = $observation
            resolution = $resolution
            parsedDependencies = $parsedDependencies
            actionDecision = $decision
            actionResult = $actionResult
        }) | Out-Null
    }

    Publish-TbgWindowLifecycleRuntimeEvents -WindowResults @($windowResults.ToArray()) -CorrelationId $CorrelationId -EmitDisappearances:($Command -eq 'watch') | Out-Null
    return @($windowResults.ToArray())
}

function Write-TbgOutputs {
    param(
        [Parameter(Mandatory = $true)]$Registry,
        [Parameter(Mandatory = $true)]$Policy,
        [AllowEmptyCollection()]
        [Parameter(Mandatory = $true)][object[]]$WindowResults,
        [Parameter(Mandatory = $true)][string]$CorrelationId,
        [Parameter(Mandatory = $true)][string]$StartedUtc
    )
    $recognized = @($WindowResults | Where-Object { [bool]$_.resolution.recognized })
    $unknown = @($WindowResults | Where-Object { -not [bool]$_.resolution.recognized })
    $dispatched = @($WindowResults | Where-Object { [bool]$_.actionResult.dispatched })
    $terminalState = 'PASS_no_relevant_windows'
    $verdict = 'PASS'
    if ($recognized.Count -gt 0) { $terminalState = 'PASS_known_windows_classified' }
    if ($dispatched.Count -gt 0) { $terminalState = 'PASS_known_window_action_dispatched' }
    if ($unknown.Count -gt 0) {
        $terminalState = 'ATTENTION_unknown_window_delta_discovery_required'
        $verdict = 'ATTENTION'
    }
    if ($Mode -eq 'strict' -and $unknown.Count -gt 0) {
        $terminalState = 'BLOCKED_unknown_window_in_strict_mode'
        $verdict = 'BLOCKED'
    }
    $result = [pscustomobject][ordered]@{
        schema = 'TbgWindowIntelligenceResult.v1'
        correlationId = $CorrelationId
        command = $Command
        mode = $Mode
        startedUtc = $StartedUtc
        completedUtc = [DateTime]::UtcNow.ToString('o')
        registryVersion = [string]$Registry.version
        policySchema = [string]$Policy.schema
        verdict = $verdict
        terminalState = $terminalState
        counts = [pscustomobject][ordered]@{
            observed = $WindowResults.Count
            recognized = $recognized.Count
            unknown = $unknown.Count
            actionDispatched = $dispatched.Count
        }
        contextPath = $ContextPath
        windowResults = @($WindowResults)
        artifacts = [pscustomobject][ordered]@{
            result = $resultPath
            report = $reportPath
            events = $eventsPath
            progress = $progressPath
            handoff = $handoffPath
            learningCandidates = $learningPath
            cache = $CachePath
        }
        proofLevel = if ($FixturePath) { 'static_fixture' } else { 'window_metadata_observation' }
        forbiddenClaims = @(
            'A parsed window does not prove that the game accepted an action.',
            'A launcher handoff does not prove campaign readiness.',
            'A command acknowledgement does not prove movement, arrival, trade, or live product completion.'
        )
    }
    Write-TbgJson -Value $result -Path $resultPath -Depth 25

    $markdown = New-Object System.Collections.Generic.List[string]
    $markdown.Add('# Window intelligence report')
    $markdown.Add('')
    $markdown.Add("> **Verdict: $verdict**")
    $markdown.Add("> **Terminal state: $terminalState**")
    $markdown.Add("> **Observed $($WindowResults.Count), recognized $($recognized.Count), unknown $($unknown.Count), actions dispatched $($dispatched.Count).**")
    $markdown.Add('')
    $markdown.Add('## Best-strategy policy')
    $markdown.Add('')
    $markdown.Add('The harness uses exact cached fingerprints first, tracked process/Win32/UI Automation metadata second, launcher context for PLAY versus CONTINUE, module dependency prediction fourth, and the S1/S2 snapshot delta only for first-seen discovery. Image parsing is diagnostic fallback only.')
    $markdown.Add('')
    $markdown.Add('## Observed windows')
    $markdown.Add('')
    if ($WindowResults.Count -eq 0) {
        $markdown.Add('No relevant Bannerlord or TaleWorlds windows were observed.')
    }
    foreach ($item in $WindowResults) {
        $identityText = if ($item.resolution.recognized) { [string]$item.resolution.displayName } else { 'Unknown window' }
        $markdown.Add("### $identityText")
        $markdown.Add('')
        $markdown.Add(('- Process: `{0}` PID {1}' -f [string]$item.observation.process.processName, [int]$item.observation.process.pid))
        $markdown.Add(('- HWND: `{0}`' -f [Int64]$item.observation.window.hwnd))
        $markdown.Add(('- Title: `{0}`' -f [string]$item.observation.window.title))
        $markdown.Add(('- Class: `{0}`' -f [string]$item.observation.window.className))
        $markdown.Add(('- Recognition: `{0}` at score {1}' -f [string]$item.resolution.basis, [int]$item.resolution.score))
        $markdown.Add(('- Fingerprint: `{0}`' -f [string]$item.resolution.fingerprint.hash))
        $markdown.Add(('- Action decision: `{0}`' -f [string]$item.actionDecision.reason))
        $markdown.Add(('- Action result: `{0}`' -f [string]$item.actionResult.reason))
        if (@($item.parsedDependencies).Count -gt 0) {
            $markdown.Add('')
            $markdown.Add('| Dependency | Expected | Current | Source |')
            $markdown.Add('|---|---|---|---|')
            foreach ($dependency in @($item.parsedDependencies)) {
                $markdown.Add("| $($dependency.module) | $($dependency.expectedVersion) | $($dependency.currentVersion) | $($dependency.source) |")
            }
        }
        $markdown.Add('')
    }
    $markdown.Add('## Proof boundary')
    $markdown.Add('')
    $markdown.Add('This report proves metadata collection, identity resolution, and any recorded action dispatch only. It does not prove that the game accepted an action, campaign readiness, command acknowledgement, movement, arrival, trading, or live product completion.')
    $markdown | Set-Content -LiteralPath $reportPath -Encoding UTF8

    $handoff = New-Object System.Collections.Generic.List[string]
    $handoff.Add('# Window intelligence handoff')
    $handoff.Add('')
    $handoff.Add(('The latest terminal state is `{0}`.' -f $terminalState))
    $handoff.Add('')
    if ($unknown.Count -gt 0) {
        $handoff.Add('At least one window remains unknown. Capture the fast S1/S2 PID/window delta once, inspect the learning candidate, and assign a tracked identity before allowing an automatic action.')
    } else {
        $handoff.Add('Every observed window matched a tracked or revalidated cached identity. Do not restart generic PLAY/CONTINUE selection or add an image parser before reading this result.')
    }
    $handoff.Add('')
    $handoff.Add('Exact status command:')
    $handoff.Add('')
    $handoff.Add('```powershell')
    $handoff.Add('.\ForgeWindowIntel.cmd status')
    $handoff.Add('```')
    $handoff | Set-Content -LiteralPath $handoffPath -Encoding UTF8
    return $result
}

Ensure-TbgDirectory -Path $OutputDirectory
Ensure-TbgDirectory -Path (Split-Path -Parent $CachePath)
if ($Command -ne 'status') {
    '' | Set-Content -LiteralPath $eventsPath -Encoding UTF8
    '' | Set-Content -LiteralPath $progressPath -Encoding UTF8
}

if ($Command -eq 'status') {
    $existingResult = Read-TbgJson -Path $resultPath
    if (-not $existingResult) {
        Write-Host 'No window-intelligence result exists yet.'
        exit 2
    }
    Write-Host ("Window intelligence: {0} / {1}" -f $existingResult.verdict, $existingResult.terminalState)
    Write-Host ("Observed={0} Recognized={1} Unknown={2} Actions={3}" -f $existingResult.counts.observed, $existingResult.counts.recognized, $existingResult.counts.unknown, $existingResult.counts.actionDispatched)
    Write-Host "Report: $reportPath"
    exit 0
}

$registry = Read-TbgJson -Path $RegistryPath
if (-not $registry) { throw "The window identity registry is missing or invalid: $RegistryPath" }
$policy = Read-TbgJson -Path $PolicyPath
if (-not $policy) { throw "The window intelligence policy is missing or invalid: $PolicyPath" }
$cache = Read-TbgCache -Registry $registry
$correlationId = if (-not [string]::IsNullOrWhiteSpace($LifecycleCorrelationId)) {
    $LifecycleCorrelationId
} else {
    'window-intel-{0}-{1}' -f ([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')), ([Guid]::NewGuid().ToString('N').Substring(0,8))
}
$script:lifecycleRunId = $LifecycleRunId
$script:lifecycleCorrelationId = $LifecycleCorrelationId
$script:lifecycleSequenceByWindow = @{}
$script:lifecycleKnownWindows = @{}
$script:lifecycleRuntimePath = $null
$startedUtc = [DateTime]::UtcNow.ToString('o')
Initialize-TbgWindowLifecycleRuntimeSession -CorrelationId $correlationId | Out-Null

$allResults = New-Object System.Collections.Generic.List[object]
if ($Command -eq 'watch') {
    $lease = [pscustomobject][ordered]@{
        schema = 'TbgWindowIntelligenceWatcher.v1'
        processId = $PID
        targetProcessId = $ProcessId
        startedUtc = $startedUtc
        durationSeconds = $DurationSeconds
        pollMilliseconds = $PollMilliseconds
        mode = $Mode
        allowKnownActions = [bool]$AllowKnownActions
        correlationId = $correlationId
        lifecycleRunId = [string]$script:lifecycleRunId
        lifecycleCorrelationId = [string]$script:lifecycleCorrelationId
    }
    Write-TbgJson -Value $lease -Path $leasePath -Depth 10
    try {
        $deadline = (Get-Date).AddSeconds([Math]::Max(1, $DurationSeconds))
        $seen = @{}
        while ((Get-Date) -lt $deadline) {
            $scanResults = @(Invoke-TbgScan -Registry $registry -Cache $cache -CorrelationId $correlationId)
            foreach ($item in $scanResults) {
                $key = '{0}|{1}|{2}' -f $item.resolution.fingerprint.hash, [string]$item.actionResult.reason, [string]$item.actionResult.method
                if (-not $seen.ContainsKey($key)) {
                    $seen[$key] = $true
                    $allResults.Add($item) | Out-Null
                }
            }
            Start-Sleep -Milliseconds ([Math]::Max(50, $PollMilliseconds))
        }
    }
    finally {
        Remove-Item -LiteralPath $leasePath -Force -ErrorAction SilentlyContinue
    }
} else {
    foreach ($item in @(Invoke-TbgScan -Registry $registry -Cache $cache -CorrelationId $correlationId)) { $allResults.Add($item) | Out-Null }
}

$result = Write-TbgOutputs -Registry $registry -Policy $policy -WindowResults @($allResults.ToArray()) -CorrelationId $correlationId -StartedUtc $startedUtc
Write-Host ("Window intelligence completed: {0} / {1}" -f $result.verdict, $result.terminalState)
Write-Host "Report: $reportPath"
if ($Mode -eq 'strict' -and [string]$result.verdict -eq 'BLOCKED') { exit 2 }
exit 0
