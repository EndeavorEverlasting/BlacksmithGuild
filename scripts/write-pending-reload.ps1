# Write BlacksmithGuild_PendingReload.json after a Release build/install attempt.
# Optional Windows toast when Bannerlord is running (restart required - no hot reload).

param(
    [Parameter(Mandatory = $true)]
    [string]$BannerlordRoot,

    [Parameter(Mandatory = $true)]
    [string]$Source,

    [Parameter(Mandatory = $true)]
    [string]$DllPath,

    [Parameter(Mandatory = $true)]
    [ValidateSet('installed', 'blockedByRunningGame')]
    [string]$InstallStatus,

    [string]$ModuleSourceDir
)

$ErrorActionPreference = 'Stop'

function Get-ModVersionFromXml {
    param([string]$SubModuleXml)

    if (-not (Test-Path -LiteralPath $SubModuleXml)) {
        return 'unknown'
    }

    [xml]$doc = Get-Content -LiteralPath $SubModuleXml
    return $doc.Module.Version.value
}

function Get-ModVersionFromInstall {
    param([string]$Root)

    $subModuleXml = Join-Path $Root 'Modules\BlacksmithGuild\SubModule.xml'
    return Get-ModVersionFromXml -SubModuleXml $subModuleXml
}

function Test-BannerlordProcessRunning {
    $names = @(
        'Bannerlord',
        'TaleWorlds.MountAndBlade.Launcher',
        'TaleWorlds.MountAndBlade.Launcher.exe'
    )

    foreach ($name in $names) {
        $procName = [System.IO.Path]::GetFileNameWithoutExtension($name)
        if (Get-Process -Name $procName -ErrorAction SilentlyContinue) {
            return $true
        }
    }

    return $false
}

function Show-ReloadToast {
    param(
        [string]$Title,
        [string]$Message
    )

    try {
        Add-Type -AssemblyName 'System.Runtime.WindowsRuntime' -ErrorAction Stop | Out-Null
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

        $escapedMessage = [System.Security.SecurityElement]::Escape($Message)
        $escapedTitle = [System.Security.SecurityElement]::Escape($Title)
        $template = @"
<toast>
  <visual>
    <binding template="ToastText02">
      <text id="1">$escapedTitle</text>
      <text id="2">$escapedMessage</text>
    </binding>
  </visual>
</toast>
"@

        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($template)
        $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('The Blacksmith Guild').Show($toast)
        return $true
    } catch {
        return $false
    }
}

if (-not (Test-Path -LiteralPath $DllPath)) {
    throw "Pending reload marker skipped - DLL not found: $DllPath"
}

$dllItem = Get-Item -LiteralPath $DllPath
if ($InstallStatus -eq 'blockedByRunningGame' -and $ModuleSourceDir) {
    $version = Get-ModVersionFromXml -SubModuleXml (Join-Path $ModuleSourceDir 'SubModule.xml')
} else {
    $version = Get-ModVersionFromInstall -Root $BannerlordRoot
}
$markerPath = Join-Path $BannerlordRoot 'BlacksmithGuild_PendingReload.json'

$payload = [ordered]@{
    installedAt     = (Get-Date).ToString('o')
    version         = $version
    dllBytes        = $dllItem.Length
    dllLastWriteUtc = $dllItem.LastWriteTimeUtc.ToString('o')
    source          = $Source
    installStatus   = $InstallStatus
}

$payload | ConvertTo-Json -Compress | Set-Content -LiteralPath $markerPath -Encoding UTF8
Write-Host "Pending reload marker written ($InstallStatus): $markerPath" -ForegroundColor DarkGray

if (-not (Test-BannerlordProcessRunning)) {
    return
}

if ($InstallStatus -eq 'installed') {
    $toastMessage = "Blacksmith Guild updated - restart Bannerlord to load $version"
    if (-not (Show-ReloadToast -Title 'The Blacksmith Guild' -Message $toastMessage)) {
        Write-Host $toastMessage -ForegroundColor Yellow
        Write-Host 'Restart Bannerlord to load the new mod DLL (no hot reload).' -ForegroundColor Yellow
    }
    return
}

$toastMessage = 'Build ready - close Bannerlord, then run Forge.cmd again'
if (-not (Show-ReloadToast -Title 'The Blacksmith Guild' -Message $toastMessage)) {
    Write-Host $toastMessage -ForegroundColor Yellow
    Write-Host 'The loaded mod DLL is locked while Bannerlord is running.' -ForegroundColor Yellow
}
