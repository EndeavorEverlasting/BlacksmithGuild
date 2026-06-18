# Debounced FileSystemWatcher: rebuild + install on source changes.

param(
    [int]$WatchDebounceSec = 2
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$script:firstRun = $true
$script:rebuildInProgress = $false
$state = [hashtable]::Synchronized(@{
    PendingFile = $null
    PendingAt   = $null
})

function Invoke-WatchRebuild {
    param([string]$TriggerFile)

    if ($script:rebuildInProgress) {
        return
    }

    $script:rebuildInProgress = $true
    try {
        Write-Host ''
        Write-Host "WATCH rebuild triggered by $TriggerFile" -ForegroundColor Cyan

        if ($script:firstRun) {
            . (Join-Path $RepoRoot 'scripts\backup-saves.ps1')
            Invoke-SaveBackupWorkflow | Out-Null
            $script:firstRun = $false
        }

        & (Join-Path $RepoRoot 'scripts\install-mod.ps1')
    } finally {
        $script:rebuildInProgress = $false
    }
}

function Register-SourceWatcher {
    param(
        [string]$Path,
        [string]$Filter,
        [bool]$IncludeSubdirectories
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Watch path not found: $Path"
    }

    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $Path
    $watcher.Filter = $Filter
    $watcher.IncludeSubdirectories = $IncludeSubdirectories
    $watcher.NotifyFilter = [IO.NotifyFilters]::LastWrite -bor [IO.NotifyFilters]::FileName
    $watcher.EnableRaisingEvents = $true

    Register-ObjectEvent -InputObject $watcher -EventName Changed -MessageData $state -Action {
        $path = $Event.SourceEventArgs.FullPath
        if ($path -match '\\obj\\|\\bin\\') { return }
        $sync = $Event.MessageData
        $sync.PendingFile = $path
        $sync.PendingAt = Get-Date
    } | Out-Null

    Register-ObjectEvent -InputObject $watcher -EventName Created -MessageData $state -Action {
        $path = $Event.SourceEventArgs.FullPath
        if ($path -match '\\obj\\|\\bin\\') { return }
        $sync = $Event.MessageData
        $sync.PendingFile = $path
        $sync.PendingAt = Get-Date
    } | Out-Null

    Register-ObjectEvent -InputObject $watcher -EventName Renamed -MessageData $state -Action {
        $path = $Event.SourceEventArgs.FullPath
        if ($path -match '\\obj\\|\\bin\\') { return }
        $sync = $Event.MessageData
        $sync.PendingFile = $path
        $sync.PendingAt = Get-Date
    } | Out-Null

    return $watcher
}

Write-Host '=== The Blacksmith Guild: forge watch ===' -ForegroundColor Cyan
Write-Host "Debounce: ${WatchDebounceSec}s. Ctrl+C to stop."
Write-Host "Watching: src\BlacksmithGuild\**\*.cs, Module\BlacksmithGuild\SubModule.xml"
Write-Host ''

$watchers = @(
    Register-SourceWatcher -Path (Join-Path $RepoRoot 'src\BlacksmithGuild') -Filter '*.cs' -IncludeSubdirectories $true
    Register-SourceWatcher -Path (Join-Path $RepoRoot 'Module\BlacksmithGuild') -Filter 'SubModule.xml' -IncludeSubdirectories $false
)

try {
    while ($true) {
        Start-Sleep -Milliseconds 500

        if ($null -eq $state.PendingAt -or $null -eq $state.PendingFile) {
            continue
        }

        $elapsed = ((Get-Date) - $state.PendingAt).TotalSeconds
        if ($elapsed -lt $WatchDebounceSec) {
            continue
        }

        $trigger = $state.PendingFile
        $state.PendingFile = $null
        $state.PendingAt = $null
        Invoke-WatchRebuild -TriggerFile $trigger
    }
} finally {
    foreach ($w in $watchers) {
        $w.EnableRaisingEvents = $false
        $w.Dispose()
    }

    Get-EventSubscriber | Unregister-Event -Force -ErrorAction SilentlyContinue
}
