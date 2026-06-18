# Build, install, and verify The Blacksmith Guild mod (one-click dev workflow).
#
# Usage:
#   .\scripts\install-mod.ps1           # build + copy to Bannerlord/Modules
#   .\scripts\install-mod.ps1 -Launch   # also open the Bannerlord launcher
#   .\scripts\install-mod.ps1 -CheckLog # also scan for acceptance log / PASS line

param(
    [switch]$Launch,
    [switch]$CheckLog
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'forge-status.ps1')

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

    Invoke-ForgeStep -Name 'install' -Action {
        Write-Host ''
        Write-Host '[2/3] Installing to Modules/BlacksmithGuild...'
        Copy-Item -Recurse -Force -LiteralPath $ModuleSrc -Destination $ModuleDest

        Copy-Item -Force -LiteralPath (Join-Path $ModuleSrc 'SubModule.xml') -Destination (Join-Path $ModuleDest 'SubModule.xml')
        foreach ($dllRel in @($DllRelClient, $DllRelWEditor)) {
            $srcDll = Join-Path $ModuleSrc $dllRel
            $destDll = Join-Path $ModuleDest $dllRel
            $destDir = Split-Path $destDll -Parent
            if (-not (Test-Path -LiteralPath $destDir)) {
                New-Item -ItemType Directory -Force -Path $destDir | Out-Null
            }
            Copy-Item -Force -LiteralPath $srcDll -Destination $destDll
        }

        $installedXml = Join-Path $ModuleDest 'SubModule.xml'
        $installedDllClient = Join-Path $ModuleDest $DllRelClient
        $installedDllWEditor = Join-Path $ModuleDest $DllRelWEditor
        if (-not (Test-Path -LiteralPath $installedXml)) { throw 'Missing installed SubModule.xml' }
        if (-not (Test-Path -LiteralPath $installedDllClient)) { throw "Missing installed Client DLL: $installedDllClient" }
        if (-not (Test-Path -LiteralPath $installedDllWEditor)) { throw "Missing installed wEditor DLL: $installedDllWEditor" }
        Write-Host 'PASS - Module installed (Client + wEditor DLLs)' -ForegroundColor Green
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
        [xml]$subModule = Get-Content -LiteralPath $installedXml
        Write-Host "PASS - Module $($subModule.Module.Name.value) ($($subModule.Module.Id.value)) $($subModule.Module.Version.value)" -ForegroundColor Green
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
    Write-Host 'Daily play:' -ForegroundColor Cyan
    Write-Host '  Steam -> Play (launcher uses your saved mod checkboxes).'
    Write-Host 'After code changes: dotnet build -c Release (auto-installs), then Steam -> Play.'
    Write-Host 'Use forge -Launch only for first install or when you want the launcher opened explicitly.' -ForegroundColor Cyan

    if ($Launch) {
        Invoke-ForgeStep -Name 'open_launcher' -Action {
            if (-not (Test-Path -LiteralPath $LauncherExe)) { throw "Launcher not found: $LauncherExe" }
            Write-Host ''
            Write-Host 'Opening Bannerlord launcher...'
            Start-Process -LiteralPath $LauncherExe
        }
    }

    $overall = 'PASS'
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
