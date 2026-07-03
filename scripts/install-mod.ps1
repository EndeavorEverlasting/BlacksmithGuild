# Build, install, and verify The Blacksmith Guild mod (one-click dev workflow).
#
# Usage:
#   .\scripts\install-mod.ps1                               # build + copy to Bannerlord/Modules
#   .\scripts\install-mod.ps1 -Launch -LaunchIntent play    # also open/navigate the Bannerlord launcher
#   .\scripts\install-mod.ps1 -CheckLog                     # also scan for acceptance log / PASS line

param(
    [switch]$Launch,
    [ValidateSet('play', 'continue')]
    [string]$LaunchIntent,
    [switch]$LaunchManual,
    [switch]$CheckLog,
    [switch]$SkipInstall,
    [ValidateSet('AttachOnly', 'FreshTestLaunch', 'UserSession', 'RunnerCleanup')]
    [string]$SessionAuthorityMode
)

$ErrorActionPreference = 'Stop'
if ($Launch -and -not $LaunchIntent) {
    throw 'LaunchIntent is required when -Launch is used. Pass -LaunchIntent play or -LaunchIntent continue.'
}
. (Join-Path $PSScriptRoot 'forge-status.ps1')
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'copy-client-dll.ps1')

function Get-RepoRoot {
    $root = Split-Path -Parent $PSScriptRoot
    if (-not (Test-Path (Join-Path $root 'src\BlacksmithGuild\BlacksmithGuild.csproj'))) {
        throw "Cannot find repo root from $PSScriptRoot"
    }
    return $root
}

function Get-BannerlordRoot {
    param([string]$RepoRoot)
    return Get-BannerlordRootFromRepo -RepoRoot $RepoRoot
}

$operation = if ($Launch) { 'launch' } elseif ($CheckLog) { 'check' } else { 'install' }
Start-ForgeStatusRun -Source 'install-mod' -Operation $operation

try {
    $RepoRoot = Get-RepoRoot
    $BannerlordRoot = Get-BannerlordRoot -RepoRoot $RepoRoot
    $ModuleSrc = Join-Path $RepoRoot 'Module\BlacksmithGuild'
    $ModuleDest = Join-Path $BannerlordRoot 'Modules\BlacksmithGuild'
    $DllRelClient = 'bin\Win64_Shipping_Client\BlacksmithGuild.dll'
    $DllRelWEditor = 'bin\Win64_Shipping_wEditor\BlacksmithGuild.dll'
    $LauncherExe = Join-Path $BannerlordRoot 'bin\Win64_Shipping_Client\TaleWorlds.MountAndBlade.Launcher.exe'

    Write-Host '=== The Blacksmith Guild: install-mod ===' -ForegroundColor Cyan
    Write-Host "Repo:       $RepoRoot"
    Write-Host "Bannerlord: $BannerlordRoot"
    Write-Host ''

    if ($SessionAuthorityMode -eq 'FreshTestLaunch') {
        . (Join-Path $PSScriptRoot 'process-lifecycle-authority.ps1')
        $runId = (Get-Date).ToString('yyyyMMdd-HHmmss-forge')
        $branch = $null
        try { $branch = (git -C $RepoRoot branch --show-current 2>$null).Trim() } catch { }
        Initialize-TbgProcessLifecycle -RunId $runId -BannerlordRoot $BannerlordRoot `
            -SessionAuthorityMode FreshTestLaunch -Operation 'forge_cmd_launch' -Branch $branch | Out-Null
        Write-Host '[lifecycle] FreshTestLaunch preflight: intentional close before build/install' -ForegroundColor Cyan
        Invoke-TbgFreshTestLaunchPreflight -BannerlordRoot $BannerlordRoot -Reason 'fresh_test_launch_dll_reload'
    }

    if (-not $SkipInstall) {
    Invoke-ForgeStep -Name 'build' -Action {
        Write-Host '[1/3] Building Release...'
        Push-Location $RepoRoot
        dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
        if ($LASTEXITCODE -ne 0) { throw 'Build failed.' }
        Pop-Location

        $builtDllClient = Join-Path $ModuleSrc $DllRelClient
        $builtDllWEditor = Join-Path $ModuleSrc $DllRelWEditor
        if (-not (Test-Path -LiteralPath $builtDllClient)) { throw "Missing build output: $builtDllClient" }
        if (-not (Test-Path -LiteralPath $builtDllWEditor)) { throw "Missing wEditor build output: $builtDllWEditor" }
        Write-Host "PASS - DLL built (Client + wEditor, $((Get-Item -LiteralPath $builtDllClient).Length) bytes each)" -ForegroundColor Green
    }

    Set-ForgeStep -Name 'install' -Status 'RUNNING'
    try {
        Write-Host ''
        Write-Host '[2/3] Installing to Modules/BlacksmithGuild...'

        $installResult = Sync-ModToGameModules `
            -ModuleSourceDir $ModuleSrc `
            -ModuleDestDir $ModuleDest `
            -BannerlordRoot $BannerlordRoot `
            -Source 'install-mod.ps1'

        if ($installResult.Status -eq 'blockedByRunningGame') {
            Complete-ForgeStepBlocked -Name 'install' -Message 'Client DLL locked by running Bannerlord'
            Write-Host ''
            Write-Host 'Build succeeded, but install is blocked because Bannerlord is running.' -ForegroundColor Yellow
            Write-Host 'Close Bannerlord, then run Forge.cmd again.' -ForegroundColor Yellow
        } else {
            Set-ForgeStep -Name 'install' -Status 'PASS'
            Write-Host 'PASS - Module installed (Client DLL required for Steam Play)' -ForegroundColor Green
        }
    } catch {
        Set-ForgeStep -Name 'install' -Status 'FAIL' -Message $_.Exception.Message
        Add-ForgeError $_.Exception.Message
        throw
    }

    Invoke-ForgeStep -Name 'verify_structure' -Action {
        Write-Host ''
        Write-Host '[3/3] Verifying structure...'
        $deps = @('Native', 'SandBoxCore', 'Sandbox', 'StoryMode')
        foreach ($dep in $deps) {
            $depXml = Join-Path $BannerlordRoot "Modules\$dep\SubModule.xml"
            if (-not (Test-Path -LiteralPath $depXml)) { throw "Missing dependency: $dep" }
        }
        $installedXml = Join-Path $ModuleDest 'SubModule.xml'
        $nestedModule = Join-Path $ModuleDest 'BlacksmithGuild'
        if (Test-Path -LiteralPath $nestedModule) {
            throw 'Nested module folder BlacksmithGuild/BlacksmithGuild detected — install is corrupt'
        }

        [xml]$subModule = Get-Content -LiteralPath $installedXml
        Write-Host "PASS - Module $($subModule.Module.Name.value) ($($subModule.Module.Id.value)) $($subModule.Module.Version.value)" -ForegroundColor Green
    }
    } else {
        Write-Host 'SkipInstall: scanning status/log only (no build/install).' -ForegroundColor Cyan
    }

    if ($CheckLog) {
        Invoke-ForgeStep -Name 'scan_log' -Action {
            Write-Host ''
            Write-Host '--- Log scan ---'
            $logCandidates = Get-Phase1LogCandidates -BannerlordRoot $BannerlordRoot
            $foundLog = $null
            foreach ($log in $logCandidates) {
                if (Test-Path -LiteralPath $log) {
                    $foundLog = $log
                    Write-Host "Log: $log"
                    Get-Content -LiteralPath $log -Tail 15
                    break
                }
            }

            if ($foundLog) {
                Scan-AcceptanceLog -LogPath $foundLog -BannerlordRoot $BannerlordRoot
            } else {
                Scan-AcceptanceLog -LogPath '' -BannerlordRoot $BannerlordRoot
                Write-Host 'No BlacksmithGuild_Phase1.log yet.' -ForegroundColor Yellow
                Write-Host 'Reminder: check The Blacksmith Guild in the launcher, click Play, then load a campaign.' -ForegroundColor Yellow
            }

            Write-Host ''
            Write-Host 'If the game crashed, run .\forge.ps1 -CollectDiagnostics and share diagnostic-summary.txt.' -ForegroundColor Yellow
            Write-Host 'Engine ASSERT dialogs (Abort/Retry/Ignore) are not mod-controlled; errors are captured in logs after CollectDiagnostics.' -ForegroundColor Yellow
        }
    }

    Write-Host ''
    Write-Host 'Daily play (006E zero-click):' -ForegroundColor Cyan
    Write-Host '  Forge.cmd               -> frozen-context PLAY -> readiness classification'
    Write-Host '  ForgeContinue.cmd       -> frozen-context CONTINUE -> readiness classification'
    Write-Host '  LaunchForgeContinue.cmd -> build + launcher + CONTINUE intent (006I-5)'
    Write-Host '  -LaunchManual on forge.ps1 skips launcher UI automation.'
    Write-Host 'After code changes: close Bannerlord, then Forge.cmd / dotnet build / Ctrl+Shift+B to install.'

    & (Join-Path $PSScriptRoot 'pin-dev-save.ps1')

    if ($Launch) {
        if (-not (Get-Command Test-Phase1TbgReady -ErrorAction SilentlyContinue)) {
            . (Join-Path $PSScriptRoot 'dev-command-names.ps1')
        }

        Set-ForgeStep -Name 'open_launcher' -Status 'RUNNING'
        try {
            Write-Host ''
            if (-not $LaunchManual) {
                & (Join-Path $PSScriptRoot 'write-launch-intent.ps1') -LaunchIntent $LaunchIntent -BannerlordRoot $BannerlordRoot
                if ($SessionAuthorityMode -eq 'FreshTestLaunch') {
                    . (Join-Path $PSScriptRoot 'process-lifecycle-authority.ps1')
                    Write-TbgLaunchRequest -BannerlordRoot $BannerlordRoot -LaunchIntent $LaunchIntent -RequestedBy 'script'
                }
            }
            & (Join-Path $PSScriptRoot 'open-bannerlord-launcher.ps1') -BannerlordRoot $BannerlordRoot `
                -LaunchIntent $LaunchIntent `
                -AllowExistingProcess:($SessionAuthorityMode -eq 'FreshTestLaunch')
            if (-not $LaunchManual) {
                $launcherContextPath = Join-Path $BannerlordRoot 'launcher-window-context.json'
                & (Join-Path $PSScriptRoot 'launcher-frozen-context-nav.ps1') -LaunchIntent $LaunchIntent -BannerlordRoot $BannerlordRoot -LauncherContextPath $launcherContextPath -TimeoutSec 120 -PollMs 250 -LaunchSetup
            }
            if ($LaunchIntent -eq 'continue' -and -not $LaunchManual) {
                $launchLogPath = Get-LaunchLogPath -BannerlordRoot $BannerlordRoot
                $continueVerified = $false
                if (Test-Path -LiteralPath $launchLogPath) {
                    $launchTail = Get-Content -LiteralPath $launchLogPath -Tail 120 -ErrorAction SilentlyContinue
                    $launchText = ($launchTail -join [Environment]::NewLine)
                    $continueVerified = ($launchText -match 'LAUNCH_STATE=continue_clicked') -or
                        ($launchText -match 'LAUNCH_STATE=game_spawned') -or
                        ($launchText -match 'LAUNCH_STATE=hotkeys_ready') -or
                        ($launchText -match 'classification=hotkeys_ready')
                }
                if (-not $continueVerified) {
                    Set-ForgeStep -Name 'open_launcher' -Status 'WARN' -Message 'continue intent exited without CONTINUE click, game spawn, or readiness in Launch.log'
                    Write-Host ''
                    Write-Host 'WARN - frozen launcher nav returned but Launch.log shows no CONTINUE click, game spawn, or readiness.' -ForegroundColor Yellow
                } else {
                    Set-ForgeStep -Name 'open_launcher' -Status 'PASS'
                }
            } elseif ($LaunchIntent -eq 'play' -and -not $LaunchManual) {
                $launchLogPath = Get-LaunchLogPath -BannerlordRoot $BannerlordRoot
                $playVerified = $false
                if (Test-Path -LiteralPath $launchLogPath) {
                    $launchTail = Get-Content -LiteralPath $launchLogPath -Tail 120 -ErrorAction SilentlyContinue
                    $launchText = ($launchTail -join [Environment]::NewLine)
                    $playVerified = ($launchText -match 'LAUNCH_STATE=play_clicked') -or
                        ($launchText -match 'LAUNCH_STATE=game_spawned') -or
                        ($launchText -match 'LAUNCH_STATE=hotkeys_ready') -or
                        ($launchText -match 'classification=hotkeys_ready')
                }
                if (-not $playVerified) {
                    Set-ForgeStep -Name 'open_launcher' -Status 'WARN' -Message 'play intent exited without PLAY click, game_spawned, or readiness in Launch.log'
                    Write-Host ''
                    Write-Host 'WARN - frozen launcher nav returned but Launch.log shows no PLAY click, game spawn, or readiness.' -ForegroundColor Yellow
                } else {
                    Set-ForgeStep -Name 'open_launcher' -Status 'PASS'
                }
            } else {
                Set-ForgeStep -Name 'open_launcher' -Status 'PASS'
            }
        } catch {
            if (Test-Phase1TbgReady -BannerlordRoot $BannerlordRoot) {
                Set-ForgeStep -Name 'open_launcher' -Status 'WARN' -Message $_.Exception.Message
                Write-Host ''
                Write-Host 'WARN - frozen launcher nav failed but TBG READY found in Phase1.log (map loaded).' -ForegroundColor Yellow
            } else {
                Set-ForgeStep -Name 'open_launcher' -Status 'FAIL' -Message $_.Exception.Message
                Add-ForgeError $_.Exception.Message
                throw
            }
        }
    }

    $overall = 'PASS'
    if (Test-ForgeStepBlocked -Name 'install') {
        $overall = 'WARN'
    }
    if ($script:ForgeStatusState.steps) {
        foreach ($step in $script:ForgeStatusState.steps) {
            if ($step.status -eq 'WARN') {
                $overall = 'WARN'
            }
        }
    }
    if ($CheckLog -and $script:ForgeStatusState.tests) {
        foreach ($key in $script:ForgeStatusState.tests.Keys) {
            if ($script:ForgeStatusState.tests[$key].status -eq 'FAIL') {
                $overall = 'WARN'
            }
        }
    }

    $statusPath = Complete-ForgeStatusRun -Overall $overall
    Write-ForgeStatusSummary -StatusJsonPath $statusPath
} catch {
    $statusPath = Complete-ForgeStatusRun -Overall 'FAIL'
    Write-ForgeStatusSummary -StatusJsonPath $statusPath
    throw
}