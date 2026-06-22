# Append a line to BlacksmithGuild_Launch.log (shared audit trail for Forge automation).
param(
    [Parameter(Mandatory = $true)]
    [string]$Message,

    [string]$BannerlordRoot
)

function Get-BannerlordRootFromRepo {
    param([string]$RepoRoot)
    $csproj = Join-Path $RepoRoot 'src\BlacksmithGuild\BlacksmithGuild.csproj'
    if ($csproj -match '<GameFolder>([^<]+)</GameFolder>') {
        $fromCsproj = $Matches[1] -replace '&amp;', '&'
        if (Test-Path -LiteralPath $fromCsproj) { return $fromCsproj }
    }
    $default = 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord'
    if (Test-Path -LiteralPath $default) { return $default }
    return $null
}

if (-not $BannerlordRoot) {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
    $BannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $RepoRoot
}

if (-not $BannerlordRoot) { return }

$logPath = Join-Path $BannerlordRoot 'BlacksmithGuild_Launch.log'
$line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
for ($attempt = 0; $attempt -lt 3; $attempt++) {
    try {
        Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8 -ErrorAction Stop
        break
    } catch {
        if ($attempt -ge 2) { throw }
        Start-Sleep -Milliseconds 150
    }
}
