# Central Bannerlord + BlacksmithGuild log/status path helpers.
# C# writes Phase1/Forge/Status under BasePath.Name (usually Documents);
# PS automation also reads Steam BannerlordRoot — check both.

function Get-BannerlordDocsRoot {
    $docsRoot = Join-Path $env:USERPROFILE 'Documents\Mount and Blade II Bannerlord'
    if (-not (Test-Path -LiteralPath $docsRoot)) {
        New-Item -ItemType Directory -Force -Path $docsRoot | Out-Null
    }
    return $docsRoot
}

function Get-BannerlordRootFromRepo {
    param([string]$RepoRoot = (Split-Path -Parent $PSScriptRoot))

    $csproj = Join-Path $RepoRoot 'src\BlacksmithGuild\BlacksmithGuild.csproj'
    if (Test-Path -LiteralPath $csproj) {
        $csprojText = Get-Content -LiteralPath $csproj -Raw
        if ($csprojText -match '<GameFolder>([^<]+)</GameFolder>') {
            $fromCsproj = $Matches[1] -replace '&amp;', '&'
            if (Test-Path -LiteralPath $fromCsproj) { return $fromCsproj }
        }
    }

    $default = 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord'
    if (Test-Path -LiteralPath $default) { return $default }

    throw 'Bannerlord install not found. Set GameFolder in BlacksmithGuild.csproj.'
}

function Get-Phase1LogCandidates {
    param([string]$BannerlordRoot)

    @(
        (Join-Path $BannerlordRoot 'BlacksmithGuild_Phase1.log'),
        (Join-Path (Get-BannerlordDocsRoot) 'BlacksmithGuild_Phase1.log')
    ) | Select-Object -Unique
}

function Get-StatusJsonCandidates {
    param([string]$BannerlordRoot)

    @(
        (Join-Path $BannerlordRoot 'BlacksmithGuild_Status.json'),
        (Join-Path (Get-BannerlordDocsRoot) 'BlacksmithGuild_Status.json')
    ) | Select-Object -Unique
}

function Get-Phase1LogPath {
    param([string]$BannerlordRoot)

    return Find-NewestExistingPath -Candidates (Get-Phase1LogCandidates -BannerlordRoot $BannerlordRoot) `
        -Preferred (Join-Path (Get-BannerlordDocsRoot) 'BlacksmithGuild_Phase1.log')
}

function Get-StatusJsonPath {
    param([string]$BannerlordRoot)

    return Find-NewestExistingPath -Candidates (Get-StatusJsonCandidates -BannerlordRoot $BannerlordRoot) `
        -Preferred (Join-Path (Get-BannerlordDocsRoot) 'BlacksmithGuild_Status.json')
}

function Get-CrashContextJsonCandidates {
    param([string]$BannerlordRoot)

    @(
        (Join-Path $BannerlordRoot 'BlacksmithGuild_CrashContext.json'),
        (Join-Path (Get-BannerlordDocsRoot) 'BlacksmithGuild_CrashContext.json')
    ) | Select-Object -Unique
}

function Get-CrashContextJsonPath {
    param([string]$BannerlordRoot)

    return Find-NewestExistingPath -Candidates (Get-CrashContextJsonCandidates -BannerlordRoot $BannerlordRoot) `
        -Preferred (Join-Path (Get-BannerlordDocsRoot) 'BlacksmithGuild_CrashContext.json')
}

function Get-AssistiveArtifactCandidates {
    param(
        [string]$BannerlordRoot,
        [Parameter(Mandatory = $true)]
        [string]$FileName
    )

    @(
        (Join-Path $BannerlordRoot $FileName),
        (Join-Path (Get-BannerlordDocsRoot) $FileName)
    ) | Select-Object -Unique
}

function Get-AssistiveSessionJsonPath {
    param([string]$BannerlordRoot)

    return Find-NewestExistingPath -Candidates (Get-AssistiveArtifactCandidates -BannerlordRoot $BannerlordRoot `
        -FileName 'BlacksmithGuild_AssistiveSession.json') `
        -Preferred (Join-Path (Get-BannerlordDocsRoot) 'BlacksmithGuild_AssistiveSession.json')
}

function Get-TownToTownTradeProbeJsonPath {
    param([string]$BannerlordRoot)

    return Find-NewestExistingPath -Candidates (Get-AssistiveArtifactCandidates -BannerlordRoot $BannerlordRoot `
        -FileName 'BlacksmithGuild_TownToTownTradeProbe.json') `
        -Preferred (Join-Path (Get-BannerlordDocsRoot) 'BlacksmithGuild_TownToTownTradeProbe.json')
}

function Get-ForgeLogPath {
    return Join-Path (Get-BannerlordDocsRoot) 'BlacksmithGuild_Forge.log'
}

function Get-LaunchLogPath {
    param([string]$BannerlordRoot)
    return Join-Path $BannerlordRoot 'BlacksmithGuild_Launch.log'
}

function Get-NavLockPath {
    param([string]$BannerlordRoot)
    return Join-Path $BannerlordRoot 'BlacksmithGuild_Launch.lock'
}

function Find-NewestExistingPath {
    param(
        [string[]]$Candidates,
        [string]$Preferred
    )

    $newest = $null
    $newestTime = [datetime]::MinValue
    foreach ($path in $Candidates) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        try {
            $mtime = (Get-Item -LiteralPath $path -ErrorAction Stop).LastWriteTime
        } catch {
            continue
        }
        if ($mtime -gt $newestTime) {
            $newestTime = $mtime
            $newest = $path
        }
    }

    if ($newest) { return $newest }
    return $Preferred
}

# Central Bannerlord + BlacksmithGuild log/status path helpers.
# C# writes Phase1/Forge/Status under BasePath.Name (usually Documents);
# PS automation also reads Steam BannerlordRoot — check both.
# Em dash in log grep: docs/conventions/em-dashes-and-log-grep.md

$script:ModDisplayEmDash = [char]0x2014
$script:TbgModDisplayReadyPrefix = "Blacksmith Guild $([char]0x2014) Ready:"

function Get-TbgReadyGoldenPathPattern {
    $ready = [regex]::Escape($script:TbgModDisplayReadyPrefix)
    return "${ready}|TBG READY|\[TBG MAPREADY\] immediate hooks complete|map_ready.*PASS"
}

function Test-Phase1ReadyLine {
    param([string]$Line)

    return $Line -match 'TBG READY' `
        -or $Line -match ([regex]::Escape($script:TbgModDisplayReadyPrefix)) `
        -or $Line -match '\[TBG MAPREADY\] immediate hooks complete' `
        -or $Line -match 'map_ready.*PASS'
}

function Get-F7GateManifestPath {
    param([string]$CheckpointDir)
    return Join-Path $CheckpointDir 'manifest.json'
}

function Confirm-F7GateManifestWritten {
    param([string]$CheckpointDir)

    $path = Get-F7GateManifestPath -CheckpointDir $CheckpointDir
    if (-not (Test-Path -LiteralPath $path)) {
        throw "F7 gate manifest missing: $path"
    }
    try {
        Get-Content -LiteralPath $path -Raw | ConvertFrom-Json | Out-Null
    } catch {
        throw "F7 gate manifest unreadable: $path - $($_.Exception.Message)"
    }
    return $path
}

function Test-F7GateManifestPass {
    param(
        [string]$ManifestPath,
        [int]$RequiredStableSeconds = 60
    )

    if (-not $ManifestPath -or -not (Test-Path -LiteralPath $ManifestPath)) { return $false }
    try {
        $m = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
    } catch { return $false }

    return ($m.passFail -eq 'PASS') -and ([int]$m.exitCode -eq 0) -and ([int]$m.stableSeconds -ge $RequiredStableSeconds)
}

function Get-LatestF7GateManifestPath {
    param(
        [string]$RepoRoot,
        [string]$SessionId = $null
    )

    if ($SessionId) {
        $explicit = Join-Path $RepoRoot "docs\evidence\live-cert\$SessionId\checkpoint-01-f7-gate\manifest.json"
        if (Test-Path -LiteralPath $explicit) { return $explicit }
    }

    $evidenceRoot = Join-Path $RepoRoot 'docs\evidence\live-cert'
    if (-not (Test-Path -LiteralPath $evidenceRoot)) { return $null }

    $latest = Get-ChildItem -LiteralPath $evidenceRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d{8}-\d{6}$' } |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if (-not $latest) { return $null }

    $path = Join-Path $latest.FullName 'checkpoint-01-f7-gate\manifest.json'
    if (Test-Path -LiteralPath $path) { return $path }
    return $null
}

function Write-ForgeRunLogPaths {
    param([string]$BannerlordRoot)

    $docsRoot = Get-BannerlordDocsRoot
    $phase1Candidates = Get-Phase1LogCandidates -BannerlordRoot $BannerlordRoot

    Write-Host ''
    Write-Host '--- Log surfaces (tail after run) ---' -ForegroundColor Cyan
    Write-Host "Forge log:    $(Get-ForgeLogPath)"
    foreach ($p in $phase1Candidates) {
        $tag = if ($p -like "$docsRoot*") { 'Documents' } else { 'Steam root' }
        Write-Host "Phase1 log ($tag): $p"
    }
    Write-Host "Launch log:   $(Get-LaunchLogPath -BannerlordRoot $BannerlordRoot)"
    Write-Host "Status JSON:  $(Get-StatusJsonPath -BannerlordRoot $BannerlordRoot)"
    Write-Host 'Collect:      .\forge.ps1 -CollectDiagnostics' -ForegroundColor DarkGray
    Write-Host ''
}

function Get-BannerlordBinRoots {
    param([string]$BannerlordRoot)

    @(
        (Join-Path $BannerlordRoot 'bin\Win64_Shipping_Client')
        (Join-Path $BannerlordRoot 'bin\Gaming.Desktop.x64_Shipping_Client')
        (Join-Path $BannerlordRoot 'bin\Win64_Shipping_wEditor')
    ) | Where-Object { Test-Path -LiteralPath $_ }
}

function Test-BannerlordWeakSupportProcess {
    param(
        [string]$ProcessName,
        [string]$Path
    )

    if ($ProcessName -eq 'Watchdog') { return $true }
    if ($Path -and $Path -match '\\Watchdog\\Watchdog\.exe$') { return $true }
    return $false
}

function Test-BannerlordGameExecutableLeaf {
    param([string]$Path)

    if (-not $Path) { return $false }
    $leaf = [System.IO.Path]::GetFileName($Path)
    return $leaf -in @('Bannerlord.exe', 'TaleWorlds.MountAndBlade.exe')
}

function Test-BannerlordExecutablePath {
    param(
        [string]$Path,
        [string]$BannerlordRoot
    )

    if (-not $Path) { return $false }
    try {
        $full = [System.IO.Path]::GetFullPath($Path)
    } catch {
        return $false
    }
    foreach ($binRoot in (Get-BannerlordBinRoots -BannerlordRoot $BannerlordRoot)) {
        if ($full.StartsWith([System.IO.Path]::GetFullPath($binRoot), [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    if ($full -match '\\Mount & Blade II Bannerlord\\bin\\' -or $full -match '\\Mount and Blade II Bannerlord\\bin\\') {
        return $true
    }
    return $false
}

function Test-LauncherMenuWindowTitle {
    param([string]$Title)

    if (-not $Title) { return $false }
    if ($Title -match 'Singleplayer PID:' -or $Title -match 'Multiplayer PID:') { return $false }
    if ($Title -match 'Bannerlord - Singleplayer' -or $Title -match 'Bannerlord - Multiplayer') { return $false }
    return $Title -match '^M&B II: Bannerlord$' `
        -or $Title -match '^MB II: Bannerlord$' `
        -or $Title -match '^Mount and Blade II Bannerlord$'
}

function Test-LauncherSingleplayerHostedTitle {
    param([string]$Title)

    if (-not $Title) { return $false }
    return $Title -match 'Bannerlord - Singleplayer' `
        -or $Title -match 'Bannerlord - Multiplayer' `
        -or ($Title -match 'Singleplayer PID:' -and $Title -match 'Bannerlord') `
        -or ($Title -match 'Multiplayer PID:' -and $Title -match 'Bannerlord')
}

function Test-LauncherHostedWindowTitle {
    param([string]$Title)

    return Test-LauncherSingleplayerHostedTitle -Title $Title
}

function Test-F7PreflightCleanState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BannerlordRoot
    )

    $script:BannerlordProcessDetectionCache = $null
    $script:BannerlordProcessDetectionCacheUtc = [datetime]::MinValue
    $det = Get-BannerlordProcessDetection -BannerlordRoot $BannerlordRoot -CacheSec 0

    $pids = New-Object System.Collections.Generic.List[int]
    foreach ($name in @('Bannerlord', 'TaleWorlds.MountAndBlade.Launcher', 'Watchdog')) {
        foreach ($p in @(Get-Process -Name $name -ErrorAction SilentlyContinue)) {
            $pids.Add([int]$p.Id) | Out-Null
        }
    }

    $hostedWindow = $false
    foreach ($p in @(Get-Process -Name 'TaleWorlds.MountAndBlade.Launcher' -ErrorAction SilentlyContinue)) {
        if (Test-LauncherSingleplayerHostedTitle -Title $p.MainWindowTitle) {
            $hostedWindow = $true
        }
    }

    $clean = ($pids.Count -eq 0) -and -not $det.gameProcessRunning -and -not $hostedWindow
    $reason = $null
    if (-not $clean) {
        if ($pids.Count -gt 0) {
            $reason = "residual_pids=$($pids -join ',')"
        } elseif ($det.gameProcessRunning) {
            $reason = "detection_still_running method=$($det.gameProcessDetectionMethod)"
        } else {
            $reason = 'hosted_window_present'
        }
    }

    return [PSCustomObject]@{
        clean = [bool]$clean
        pids = @($pids)
        detection = $det
        hostedWindow = [bool]$hostedWindow
        reason = $reason
    }
}

function Test-BannerlordLogFresh {
    param(
        [string]$Path,
        [int]$MaxAgeSec = 10
    )

    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $false }
    try {
        $ageSec = ((Get-Date).ToUniversalTime() - (Get-Item -LiteralPath $Path).LastWriteTimeUtc).TotalSeconds
        return ($ageSec -ge 0 -and $ageSec -le $MaxAgeSec)
    } catch {
        return $false
    }
}

function Get-ProcessExecutablePathSafe {
    param([System.Diagnostics.Process]$Process)

    if (-not $Process) { return $null }
    try {
        return [string]$Process.MainModule.FileName
    } catch {
        try {
            $wmi = Get-CimInstance Win32_Process -Filter "ProcessId=$($Process.Id)" -ErrorAction Stop
            return [string]$wmi.ExecutablePath
        } catch {
            return $null
        }
    }
}

function Get-BannerlordProcessCandidates {
    param(
        [string]$BannerlordRoot,
        [int]$LauncherPidHint = 0
    )

    $candidates = New-Object System.Collections.ArrayList
    $seenPids = @{}

    function Add-Candidate {
        param(
            [System.Diagnostics.Process]$Proc,
            [string]$Method,
            [bool]$IsLauncherHosted = $false
        )
        if (-not $Proc -or $seenPids.ContainsKey($Proc.Id)) { return }
        $seenPids[$Proc.Id] = $true
        $exePath = Get-ProcessExecutablePathSafe -Process $Proc
        $windowTitle = ''
        try { $windowTitle = [string]$Proc.MainWindowTitle } catch { }
        [void]$candidates.Add([PSCustomObject]@{
            pid = [int]$Proc.Id
            name = [string]$Proc.ProcessName
            path = $exePath
            method = [string]$Method
            windowTitle = $windowTitle
            isLauncherHosted = [bool]$IsLauncherHosted
        })
    }

    foreach ($p in @(Get-Process -Name 'Bannerlord' -ErrorAction SilentlyContinue)) {
        Add-Candidate -Proc $p -Method 'process_name_bannerlord'
    }

    foreach ($p in @(Get-Process -Name 'TaleWorlds.MountAndBlade' -ErrorAction SilentlyContinue)) {
        Add-Candidate -Proc $p -Method 'process_name_taleworlds'
    }

    foreach ($p in @(Get-Process -ErrorAction SilentlyContinue)) {
        if ($p.ProcessName -in @('Bannerlord', 'TaleWorlds.MountAndBlade.Launcher', 'TaleWorlds.MountAndBlade')) { continue }
        $exePath = Get-ProcessExecutablePathSafe -Process $p
        if ((Test-BannerlordExecutablePath -Path $exePath -BannerlordRoot $BannerlordRoot) `
                -and (Test-BannerlordGameExecutableLeaf -Path $exePath)) {
            Add-Candidate -Proc $p -Method 'executable_path'
        }
    }

    foreach ($p in @(Get-Process -Name 'TaleWorlds.MountAndBlade.Launcher' -ErrorAction SilentlyContinue)) {
        if (Test-LauncherSingleplayerHostedTitle -Title $p.MainWindowTitle) {
            Add-Candidate -Proc $p -Method 'launcher_hosted_window' -IsLauncherHosted $true
        }
    }

    $launcherPids = @(
        @(Get-Process -Name 'TaleWorlds.MountAndBlade.Launcher' -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
    )
    if ($LauncherPidHint -gt 0) { $launcherPids += $LauncherPidHint }
    foreach ($parentPid in @($launcherPids | Select-Object -Unique)) {
        try {
            $children = Get-CimInstance Win32_Process -Filter "ParentProcessId=$parentPid" -ErrorAction Stop
            foreach ($child in @($children)) {
                $cp = Get-Process -Id $child.ProcessId -ErrorAction SilentlyContinue
                if ($cp) {
                    if (Test-BannerlordWeakSupportProcess -ProcessName $cp.ProcessName -Path $child.ExecutablePath) {
                        Add-Candidate -Proc $cp -Method 'launcher_child_weak'
                    } elseif (Test-BannerlordExecutablePath -Path $child.ExecutablePath -BannerlordRoot $BannerlordRoot `
                            -and (Test-BannerlordGameExecutableLeaf -Path $child.ExecutablePath)) {
                        Add-Candidate -Proc $cp -Method 'launcher_child_executable'
                    } else {
                        Add-Candidate -Proc $cp -Method 'launcher_child'
                    }
                }
            }
        } catch { }
    }

    return @($candidates.ToArray())
}

function Get-BannerlordProcessDetection {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BannerlordRoot,
        [string]$Phase1Path = $null,
        [string]$StatusPath = $null,
        [string]$CrashContextPath = $null,
        [int]$LauncherPidHint = 0,
        [int]$CacheSec = 2,
        [Nullable[datetime]]$LaunchStartedAtUtc = $null
    )

    $nowUtc = (Get-Date).ToUniversalTime()
    if ($script:BannerlordProcessDetectionCache -and $script:BannerlordProcessDetectionCacheUtc) {
        $cacheAge = ($nowUtc - $script:BannerlordProcessDetectionCacheUtc).TotalSeconds
        if ($cacheAge -le $CacheSec) {
            return $script:BannerlordProcessDetectionCache
        }
    }

    $warnings = New-Object System.Collections.Generic.List[string]
    $candidates = Get-BannerlordProcessCandidates -BannerlordRoot $BannerlordRoot -LauncherPidHint $LauncherPidHint

    $phase1Fresh = Test-BannerlordLogFresh -Path $Phase1Path -MaxAgeSec 10
    $statusFresh = Test-BannerlordLogFresh -Path $StatusPath -MaxAgeSec 15
    $crashFresh = Test-BannerlordLogFresh -Path $CrashContextPath -MaxAgeSec 15

    # Phase1.log is game-written, so freshness is a weak liveness signal. But a prior-run
    # Phase1.log can have a recent-ish mtime; when a launch-start reference is supplied, only
    # treat Phase1 as a runtime signal if it was written at/after the current launch began.
    $phase1FreshForRuntime = $phase1Fresh
    if ($phase1Fresh -and $LaunchStartedAtUtc -and $Phase1Path -and (Test-Path -LiteralPath $Phase1Path)) {
        try {
            $phase1MtimeUtc = (Get-Item -LiteralPath $Phase1Path).LastWriteTimeUtc
            if ($phase1MtimeUtc -lt ([datetime]$LaunchStartedAtUtc).ToUniversalTime()) {
                $phase1FreshForRuntime = $false
            }
        } catch { }
    }

    $best = $null
    $confidence = 'none'
    $method = 'none'
    $launcherPid = $null

    foreach ($c in $candidates) {
        if ($c.method -in @('process_name_bannerlord', 'process_name_taleworlds')) {
            $best = $c
            $confidence = 'definite'
            $method = [string]$c.method
            break
        }
    }

    if (-not $best) {
        foreach ($c in $candidates) {
            if ($c.isLauncherHosted) {
                $best = $c
                $confidence = 'launcher_hosted'
                $method = 'launcher_hosted_window'
                break
            }
        }
    }

    if (-not $best) {
        foreach ($c in $candidates) {
            if ($c.method -eq 'executable_path' -and (Test-BannerlordGameExecutableLeaf -Path $c.path)) {
                $best = $c
                $confidence = 'definite'
                $method = [string]$c.method
                break
            }
        }
    }

    if (-not $best) {
        foreach ($c in $candidates) {
            if ($c.method -eq 'launcher_child_executable' -and (Test-BannerlordGameExecutableLeaf -Path $c.path)) {
                $best = $c
                $confidence = 'definite'
                $method = [string]$c.method
                break
            }
        }
    }

    if (-not $best) {
        foreach ($c in $candidates) {
            if ($c.method -eq 'launcher_child_weak') {
                $warnings.Add('Watchdog or weak launcher child observed; not treated as game runtime') | Out-Null
                break
            }
        }
    }

    $launcherProc = Get-Process -Name 'TaleWorlds.MountAndBlade.Launcher' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($launcherProc) {
        $launcherPid = [int]$launcherProc.Id
    }

    if ($confidence -eq 'none' -and $phase1FreshForRuntime) {
        $confidence = 'phase1_active'
        $method = 'phase1_log_fresh'
        $warnings.Add('Phase1 log fresh but no Bannerlord process matched — likely launcher-hosted or renamed') | Out-Null
    } elseif ($confidence -eq 'none' -and ($statusFresh -or $crashFresh)) {
        # Status.json / CrashContext.json are written by deploy/forge tooling and crash capture,
        # NOT exclusively by a live game process. They must not signal gameProcessRunning, or a
        # freshly deploy-written Status.json trips a phantom game-spawn before any real launch.
        # Record the freshness for downstream classifiers but keep confidence='none'.
        $warnings.Add('Status/CrashContext fresh but no process match — not treated as running game (deploy/crash artifact)') | Out-Null
    }

    $gameProcessRunning = ($confidence -ne 'none')
    $lastSeenUtc = if ($gameProcessRunning) { $nowUtc.ToString('o') } else { $null }

    $result = [ordered]@{
        gameProcessRunning = [bool]$gameProcessRunning
        gameAliveConfidence = [string]$confidence
        gameProcessDetectionMethod = [string]$method
        gameProcessCandidates = @($candidates)
        gameProcessPid = if ($best) { [int]$best.pid } else { $null }
        gameProcessName = if ($best) { [string]$best.name } else { $null }
        gameProcessPath = if ($best) { [string]$best.path } else { $null }
        launcherProcessPid = $launcherPid
        processDetectionWarnings = @($warnings)
        processDetectionLastSeenUtc = $lastSeenUtc
        phase1LogFresh = [bool]$phase1Fresh
        statusJsonFresh = [bool]$statusFresh
        crashContextFresh = [bool]$crashFresh
    }

    $script:BannerlordProcessDetectionCache = $result
    $script:BannerlordProcessDetectionCacheUtc = $nowUtc
    return $result
}

function Test-BannerlordGameProcessRunning {
    param(
        [string]$BannerlordRoot,
        [string]$Phase1Path = $null,
        [string]$StatusPath = $null,
        [string]$CrashContextPath = $null,
        [int]$LauncherPidHint = 0
    )

    $det = Get-BannerlordProcessDetection -BannerlordRoot $BannerlordRoot `
        -Phase1Path $Phase1Path -StatusPath $StatusPath -CrashContextPath $CrashContextPath `
        -LauncherPidHint $LauncherPidHint
    return [bool]$det.gameProcessRunning
}

function Get-ProcessLifecycleJsonPath {
    param([string]$BannerlordRoot)
    . (Join-Path $PSScriptRoot 'process-lifecycle-authority.ps1')
    return Get-TbgProcessLifecycleJsonPath -BannerlordRoot $BannerlordRoot
}

function Get-CancelRunJsonPath {
    param([string]$BannerlordRoot)
    . (Join-Path $PSScriptRoot 'process-lifecycle-authority.ps1')
    return Get-TbgCancelRunJsonPath -BannerlordRoot $BannerlordRoot
}

function Get-RuntimeLifecycleJsonPath {
    param([string]$BannerlordRoot)
    if (-not (Get-Command Get-AssistiveArtifactCandidates -ErrorAction SilentlyContinue)) {
        return $null
    }
    return Find-NewestExistingPath -Candidates (Get-AssistiveArtifactCandidates -BannerlordRoot $BannerlordRoot `
        -FileName 'BlacksmithGuild_RuntimeLifecycle.json') `
        -Preferred (Join-Path (Get-BannerlordDocsRoot) 'BlacksmithGuild_RuntimeLifecycle.json')
}
