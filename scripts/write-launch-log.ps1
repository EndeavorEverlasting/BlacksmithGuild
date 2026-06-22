# Append a line to BlacksmithGuild_Launch.log (shared audit trail for Forge automation).
param(
    [Parameter(Mandatory = $true)]
    [string]$Message,

    [string]$BannerlordRoot
)

$previousErrorActionPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = 'Stop'
    . (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')

    if (-not $BannerlordRoot) {
        $RepoRoot = Split-Path -Parent $PSScriptRoot
        $BannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $RepoRoot
    }

    if (-not $BannerlordRoot) { return }

    $logPath = Get-LaunchLogPath -BannerlordRoot $BannerlordRoot
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    $parent = Split-Path -Parent $logPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $mutexName = 'Global\BlacksmithGuildLaunchLogWrite'
    $mutex = New-Object System.Threading.Mutex($false, $mutexName)
    $hasLock = $false
    try {
        $hasLock = $mutex.WaitOne([TimeSpan]::FromSeconds(10))
        if (-not $hasLock) {
            throw 'Launch log mutex timeout after 10s'
        }
        Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
    } finally {
        if ($hasLock) {
            try { $mutex.ReleaseMutex() | Out-Null } catch { }
        }
        $mutex.Dispose()
    }
} finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
