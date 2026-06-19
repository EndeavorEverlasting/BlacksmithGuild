# Shared Client DLL copy + pending-reload marker for install-mod and dotnet build.
# Client DLL is copied before SubModule.xml so a blocked install cannot bump the
# installed module version while the old DLL remains loaded (Module Mismatch).

param(
    [string]$BannerlordRoot,
    [string]$Source = 'dotnet-build',
    [string]$ModuleSourceDir,
    [string]$ModuleDestDir
)

$ErrorActionPreference = 'Stop'

function Test-DllCopyBlocked {
    param([System.Exception]$Exception)

    $msg = $Exception.Message
    return $msg -match 'being used by another process' -or $msg -match 'used by another process'
}

function Copy-ModClientDll {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDll,

        [Parameter(Mandatory = $true)]
        [string]$DestDll,

        [Parameter(Mandatory = $true)]
        [string]$BannerlordRoot,

        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$ModuleSourceDir
    )

    if (-not (Test-Path -LiteralPath $SourceDll)) {
        throw "Missing built Client DLL: $SourceDll"
    }

    $destDir = Split-Path -Parent $DestDll
    if (-not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    }

    try {
        Copy-Item -Force -LiteralPath $SourceDll -Destination $DestDll -ErrorAction Stop
    } catch {
        if (Test-DllCopyBlocked -Exception $_.Exception) {
            & (Join-Path $PSScriptRoot 'write-pending-reload.ps1') `
                -BannerlordRoot $BannerlordRoot `
                -Source $Source `
                -DllPath $SourceDll `
                -InstallStatus 'blockedByRunningGame' `
                -ModuleSourceDir $ModuleSourceDir

            return [pscustomobject]@{
                Status = 'blockedByRunningGame'
            }
        }

        throw
    }

    & (Join-Path $PSScriptRoot 'write-pending-reload.ps1') `
        -BannerlordRoot $BannerlordRoot `
        -Source $Source `
        -DllPath $DestDll `
        -InstallStatus 'installed'

    return [pscustomobject]@{
        Status = 'installed'
    }
}

function Sync-ModToGameModules {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleSourceDir,

        [Parameter(Mandatory = $true)]
        [string]$ModuleDestDir,

        [Parameter(Mandatory = $true)]
        [string]$BannerlordRoot,

        [Parameter(Mandatory = $true)]
        [string]$Source
    )

    $dllRelClient = 'bin\Win64_Shipping_Client\BlacksmithGuild.dll'
    $dllRelWEditor = 'bin\Win64_Shipping_wEditor\BlacksmithGuild.dll'

    $nestedModule = Join-Path $ModuleDestDir 'BlacksmithGuild'
    if (Test-Path -LiteralPath $nestedModule) {
        Write-Host 'Removing nested duplicate module folder from prior install...' -ForegroundColor Yellow
        Remove-Item -Recurse -Force -LiteralPath $nestedModule
    }

    if (-not (Test-Path -LiteralPath $ModuleDestDir)) {
        New-Item -ItemType Directory -Force -Path $ModuleDestDir | Out-Null
    }

    $clientResult = Copy-ModClientDll `
        -SourceDll (Join-Path $ModuleSourceDir $dllRelClient) `
        -DestDll (Join-Path $ModuleDestDir $dllRelClient) `
        -BannerlordRoot $BannerlordRoot `
        -Source $Source `
        -ModuleSourceDir $ModuleSourceDir

    if ($clientResult.Status -eq 'blockedByRunningGame') {
        return $clientResult
    }

    $harmonyRelClient = 'bin\Win64_Shipping_Client\0Harmony.dll'
    $harmonyRelWEditor = 'bin\Win64_Shipping_wEditor\0Harmony.dll'
    foreach ($harmonyRel in @($harmonyRelClient, $harmonyRelWEditor)) {
        $srcHarmony = Join-Path $ModuleSourceDir $harmonyRel
        if (-not (Test-Path -LiteralPath $srcHarmony)) {
            continue
        }

        $destHarmony = Join-Path $ModuleDestDir $harmonyRel
        $destDir = Split-Path $destHarmony -Parent
        if (-not (Test-Path -LiteralPath $destDir)) {
            New-Item -ItemType Directory -Force -Path $destDir | Out-Null
        }

        try {
            Copy-Item -Force -LiteralPath $srcHarmony -Destination $destHarmony -ErrorAction Stop
        } catch {
            Write-Host "WARN - Harmony DLL not copied ($harmonyRel)." -ForegroundColor Yellow
        }
    }

    Copy-Item -Force -LiteralPath (Join-Path $ModuleSourceDir 'SubModule.xml') `
        -Destination (Join-Path $ModuleDestDir 'SubModule.xml')

    foreach ($dllRel in @($dllRelWEditor)) {
        $srcDll = Join-Path $ModuleSourceDir $dllRel
        $destDll = Join-Path $ModuleDestDir $dllRel
        $destDir = Split-Path $destDll -Parent
        if (-not (Test-Path -LiteralPath $destDir)) {
            New-Item -ItemType Directory -Force -Path $destDir | Out-Null
        }
        try {
            Copy-Item -Force -LiteralPath $srcDll -Destination $destDll -ErrorAction Stop
        } catch {
            Write-Host "WARN - wEditor DLL not copied (game/launcher may have file locked). Client build is enough for Steam Play." -ForegroundColor Yellow
        }
    }

    $installedDllClient = Join-Path $ModuleDestDir $dllRelClient
    $installedDllWEditor = Join-Path $ModuleDestDir $dllRelWEditor
    $installedXml = Join-Path $ModuleDestDir 'SubModule.xml'

    if (-not (Test-Path -LiteralPath $installedXml)) { throw 'Missing installed SubModule.xml' }
    if (-not (Test-Path -LiteralPath $installedDllClient)) {
        throw "Missing installed Client DLL: $installedDllClient"
    }
    if (-not (Test-Path -LiteralPath $installedDllWEditor)) {
        Write-Host "WARN - wEditor DLL missing at $installedDllWEditor (launcher may be open). Steam Play uses Client DLL." -ForegroundColor Yellow
    }

    return $clientResult
}

if ($BannerlordRoot) {
    if (-not $ModuleSourceDir) {
        $ModuleSourceDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'Module\BlacksmithGuild'
    }
    if (-not $ModuleDestDir) {
        $ModuleDestDir = Join-Path $BannerlordRoot 'Modules\BlacksmithGuild'
    }

    $result = Sync-ModToGameModules `
        -ModuleSourceDir $ModuleSourceDir `
        -ModuleDestDir $ModuleDestDir `
        -BannerlordRoot $BannerlordRoot `
        -Source $Source

    if ($result.Status -eq 'installed') {
        Write-Host "BlacksmithGuild installed to $ModuleDestDir" -ForegroundColor Green
        exit 0
    }

    Write-Host 'Build succeeded, but install is blocked because Bannerlord is running.' -ForegroundColor Yellow
    Write-Host 'Close Bannerlord, then run Forge.cmd again.' -ForegroundColor Yellow
    exit 0
}
