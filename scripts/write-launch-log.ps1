# Append a line to BlacksmithGuild_Launch.log (shared audit trail for Forge automation).
param(
    [Parameter(Mandatory = $true)]
    [string]$Message,

    [string]$BannerlordRoot
)
$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
if (-not $BannerlordRoot) { $BannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $RepoRoot }
if (-not $BannerlordRoot) { return }
$logPath = Get-BannerlordLogPath -BannerlordRoot $BannerlordRoot -Kind Launch
$line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
$parent = Split-Path -Parent $logPath
if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
$mutexName = 'Global\BlacksmithGuildLaunchLogWrite'
$mutex = New-Object System.Threading.Mutex($false, $mutexName)
try {
    [void]$mutex.WaitOne([TimeSpan]::FromSeconds(10))
    Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
} finally {
    try { $mutex.ReleaseMutex() | Out-Null } catch { }
    $mutex.Dispose()
}
