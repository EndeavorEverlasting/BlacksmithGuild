param(
    [ValidateSet('New', 'Continue')]
    [string]$Mode,
    [ValidateSet('New', 'Continue')]
    [string]$SetMode,
    [switch]$Launch,
    [switch]$Menu,
    [switch]$ShowConfig
)

$ErrorActionPreference = 'Stop'

function Get-LaunchControlRepoRoot {
    $dir = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    return $dir
}

function Get-LaunchControlConfigPath {
    Join-Path $PSScriptRoot 'Launch-Control.generated.local.json'
}

function New-DefaultLaunchControlConfig {
    param([string]$RepoRoot)
    [ordered]@{
        launchMode = 'New'
        bannerlordInstallPath = $null
        repoPath = $RepoRoot
        lastCommand = $null
        lastRunUtc = $null
        createDesktopShortcut = $true
        createStartMenuShortcut = $true
        createTaskbarHelper = $true
        showConsole = $true
        writeEvidence = $true
        defaultNewCommand = 'LaunchNew'
        defaultContinueCommand = 'LaunchContinue'
        oneClickLaunch = $false
        postLaunchCommand = $null
        notes = @('Generated locally by TBG Launch Control. Machine-specific; do not commit.')
    }
}

function ConvertTo-LaunchControlJson {
    param($Object)
    $Object | ConvertTo-Json -Depth 8
}

function Save-LaunchControlConfig {
    param($Config)
    $Config | ConvertTo-LaunchControlJson | Set-Content -LiteralPath (Get-LaunchControlConfigPath) -Encoding UTF8
}

function Get-LaunchControlConfig {
    $repoRoot = Get-LaunchControlRepoRoot
    $path = Get-LaunchControlConfigPath
    if (-not (Test-Path -LiteralPath $path)) {
        $config = New-DefaultLaunchControlConfig -RepoRoot $repoRoot
        Save-LaunchControlConfig -Config $config
        return [pscustomobject]$config
    }

    $config = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if (-not $config.launchMode) { $config | Add-Member -NotePropertyName launchMode -NotePropertyValue 'New' }
    if (-not $config.repoPath) { $config | Add-Member -NotePropertyName repoPath -NotePropertyValue $repoRoot }
    if (-not ($config.PSObject.Properties.Name -contains 'oneClickLaunch')) { $config | Add-Member -NotePropertyName oneClickLaunch -NotePropertyValue $false }
    return $config
}

function Get-EvidenceFolder {
    Get-LaunchControlRepoRoot
}

function Write-LaunchControlEvidence {
    param([string]$Name, $Payload)
    $repoRoot = Get-LaunchControlRepoRoot
    $json = $Payload | ConvertTo-Json -Depth 10
    $rootPath = Join-Path $repoRoot $Name
    $json | Set-Content -LiteralPath $rootPath -Encoding UTF8
    $latest = Join-Path $repoRoot 'docs\evidence\latest'
    if (Test-Path -LiteralPath $latest) {
        $json | Set-Content -LiteralPath (Join-Path $latest $Name) -Encoding UTF8
    }
    return $rootPath
}

function Resolve-LaunchControlCommands {
    $repoRoot = Get-LaunchControlRepoRoot
    $newCmd = Join-Path $repoRoot 'Forge.cmd'
    $continueCmd = Join-Path $repoRoot 'ForgeContinue.cmd'
    [ordered]@{
        New = if (Test-Path -LiteralPath $newCmd) { $newCmd } else { $null }
        Continue = if (Test-Path -LiteralPath $continueCmd) { $continueCmd } else { $null }
    }
}

function Write-LaunchControlStatus {
    param($Config, [string]$Verdict = 'Ready', [string]$LastResult = $null)
    $commands = Resolve-LaunchControlCommands
    Write-LaunchControlEvidence -Name 'BlacksmithGuild_LaunchControlStatus.json' -Payload ([ordered]@{
        generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
        source = 'Launch-Control.ps1'
        launchMode = $Config.launchMode
        availableModes = @('New', 'Continue')
        resolvedCommands = $commands
        lastRunUtc = $Config.lastRunUtc
        lastResult = $LastResult
        evidenceFolder = (Get-EvidenceFolder)
        verdict = $Verdict
    }) | Out-Null
}

function Set-LaunchControlMode {
    param([ValidateSet('New', 'Continue')][string]$NewMode)
    $config = Get-LaunchControlConfig
    $config.launchMode = $NewMode
    Save-LaunchControlConfig -Config $config
    Write-LaunchControlStatus -Config $config -Verdict 'Ready' -LastResult "Default launch mode set to: $NewMode"
    Write-Host "Default launch mode set to: $NewMode" -ForegroundColor Green
}

function Invoke-LaunchControlLaunch {
    param([ValidateSet('New', 'Continue')][string]$RequestedMode)
    $config = Get-LaunchControlConfig
    $commands = Resolve-LaunchControlCommands
    $command = $commands[$RequestedMode]
    if (-not $command) {
        $payload = [ordered]@{
            generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
            source = 'Launch-Control.ps1'
            requestedMode = $RequestedMode
            resolvedCommand = $null
            started = $false
            processId = $null
            exitCode = $null
            result = 'MissingLaunchCommand'
            notes = @("Missing existing launch command for $RequestedMode. Expected Forge.cmd for New and ForgeContinue.cmd for Continue.")
        }
        Write-LaunchControlEvidence -Name 'BlacksmithGuild_LaunchControlLastRun.json' -Payload $payload | Out-Null
        Write-LaunchControlStatus -Config $config -Verdict 'Blocked' -LastResult 'MissingLaunchCommand'
        throw "Missing launch command for $RequestedMode. Evidence written."
    }

    Write-Host "Launch mode: $RequestedMode" -ForegroundColor Cyan
    Write-Host "Command: $command" -ForegroundColor DarkCyan
    $startedUtc = (Get-Date).ToUniversalTime().ToString('o')
    $config.lastCommand = $command
    $config.lastRunUtc = $startedUtc
    Save-LaunchControlConfig -Config $config

    $exitCode = $null
    $result = 'Started'
    try {
        & $command
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) { $result = 'Failed' } else { $result = 'Completed' }
    } catch {
        $result = 'Failed'
        $exitCode = 1
        throw
    } finally {
        Write-LaunchControlEvidence -Name 'BlacksmithGuild_LaunchControlLastRun.json' -Payload ([ordered]@{
            generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
            source = 'Launch-Control.ps1'
            requestedMode = $RequestedMode
            resolvedCommand = $command
            started = $true
            processId = $null
            exitCode = $exitCode
            result = $result
            notes = @('Wrapped existing command; no launcher workflow was replaced.')
        }) | Out-Null
        Write-LaunchControlStatus -Config $config -Verdict 'Ready' -LastResult $result
    }
    if ($exitCode -ne 0) { exit $exitCode }
}

function Show-LaunchControlConfig {
    $config = Get-LaunchControlConfig
    Write-LaunchControlStatus -Config $config -Verdict 'Ready'
    Get-Content -LiteralPath (Get-LaunchControlConfigPath) -Raw | Write-Host
}

function Open-LaunchControlPath {
    param([string]$Path)
    if ($IsLinux -or $IsMacOS) { Write-Host $Path; return }
    Start-Process explorer.exe -ArgumentList @($Path)
}

function Show-LaunchControlMenu {
    $config = Get-LaunchControlConfig
    Write-LaunchControlStatus -Config $config -Verdict 'Ready'
    while ($true) {
        $config = Get-LaunchControlConfig
        Write-Host ''
        Write-Host '========================================' -ForegroundColor Cyan
        Write-Host ' The Blacksmith Guild - Launch Control' -ForegroundColor Cyan
        Write-Host '========================================' -ForegroundColor Cyan
        Write-Host "Current default mode: $($config.launchMode)" -ForegroundColor Yellow
        Write-Host '1. Launch New'
        Write-Host '2. Launch Continue'
        Write-Host '3. Toggle Default Mode'
        Write-Host '4. Show Current Config'
        Write-Host '5. Open Evidence Folder'
        Write-Host '6. Open Repo Folder'
        Write-Host '7. Exit'
        $choice = Read-Host 'Choose 1-7'
        switch ($choice) {
            '1' { Invoke-LaunchControlLaunch -RequestedMode 'New'; return }
            '2' { Invoke-LaunchControlLaunch -RequestedMode 'Continue'; return }
            '3' { if ($config.launchMode -eq 'New') { Set-LaunchControlMode -NewMode 'Continue' } else { Set-LaunchControlMode -NewMode 'New' } }
            '4' { Show-LaunchControlConfig }
            '5' { Open-LaunchControlPath -Path (Get-EvidenceFolder) }
            '6' { Open-LaunchControlPath -Path (Get-LaunchControlRepoRoot) }
            '7' { return }
            default { Write-Host 'Please choose a number from 1 to 7.' -ForegroundColor Yellow }
        }
    }
}

if ($SetMode) { Set-LaunchControlMode -NewMode $SetMode; return }
if ($ShowConfig) { Show-LaunchControlConfig; return }
if ($Launch) {
    $config = Get-LaunchControlConfig
    $requested = if ($Mode) { $Mode } else { $config.launchMode }
    Invoke-LaunchControlLaunch -RequestedMode $requested
    return
}

$config = Get-LaunchControlConfig
if ($config.oneClickLaunch -eq $true -and -not $Menu) {
    Invoke-LaunchControlLaunch -RequestedMode $config.launchMode
} else {
    Show-LaunchControlMenu
}
