# Build, install, and verify The Blacksmith Guild mod (one-click dev workflow).
#
# Usage:
#   .\scripts\install-mod.ps1           # build + copy to Bannerlord/Modules
#   .\scripts\install-mod.ps1 -Launch   # also open the Bannerlord launcher
#   .\scripts\install-mod.ps1 -CheckLog # also scan for acceptance log / PASS line

param(
    [switch]$Launch,
    [ValidateSet('play', 'continue')]
    [string]$LaunchIntent = 'play',
    [switch]$LaunchManual,
    [switch]$CheckLog,
    [switch]$SkipInstall
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'forge-status.ps1')
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

    $csproj = Join-Path $RepoRoot 'src\BlacksmithGuild\BlacksmithGuild.csproj'
    if ($csproj -match '<GameFolder>([^<]+)</GameFolder>') {
        $fromCsproj = $Matches[1] -replace '&amp;', '&'
        if (Test-Path -LiteralPath $fromCsproj) { return $fromCsproj }
    }

    $default = 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord'
    if (Test-Path -LiteralPath $default) { return $default }

    throw 'Bannerlord install not found. Set GameFolder in BlacksmithGuild.csproj.'
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
            $logCandidates = @(
                (Join-Path $BannerlordRoot 'BlacksmithGuild_Phase1.log'),
                (Join-Path $env:USERPROFILE 'Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Phase1.log')
            )
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
    Write-Host '  Forge.cmd               -> auto PLAY -> New Campaign -> SandBox -> map'
    Write-Host '  ForgeContinue.cmd       -> auto CONTINUE -> dev save -> map'
    Write-Host '  LaunchForgeContinue.cmd -> build + launcher + CONTINUE intent (006I-5)'
    Write-Host '  -LaunchManual on forge.ps1 skips launcher UI automation (legacy).'
    Write-Host 'After code changes: close Bannerlord, then Forge.cmd / dotnet build / Ctrl+Shift+B to install.'

    & (Join-Path $PSScriptRoot 'pin-dev-save.ps1')

    if ($Launch) {
        Invoke-ForgeStep -Name 'open_launcher' -Action {
            Write-Host ''
            if (-not $LaunchManual) {
                & (Join-Path $PSScriptRoot 'write-launch-intent.ps1') -LaunchIntent $LaunchIntent -BannerlordRoot $BannerlordRoot
            }
            & (Join-Path $PSScriptRoot 'open-bannerlord-launcher.ps1') -BannerlordRoot $BannerlordRoot
            if (-not $LaunchManual) {
                & (Join-Path $PSScriptRoot 'launcher-auto-nav.ps1') -LaunchIntent $LaunchIntent -BannerlordRoot $BannerlordRoot
            }
        }
    }

    $overall = 'PASS'
    if (Test-ForgeStepBlocked -Name 'install') {
        $overall = 'WARN'
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
