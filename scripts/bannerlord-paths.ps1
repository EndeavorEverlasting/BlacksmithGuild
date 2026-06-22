# Shared Bannerlord path helpers for repository automation.
function Get-BannerlordRootFromRepo {
    param([string]$RepoRoot)

    $csproj = Join-Path $RepoRoot 'src\BlacksmithGuild\BlacksmithGuild.csproj'
    if (Test-Path -LiteralPath $csproj) {
        $content = Get-Content -LiteralPath $csproj -Raw
        if ($content -match '<GameFolder>([^<]+)</GameFolder>') {
            $fromCsproj = $Matches[1] -replace '&amp;', '&'
            if (Test-Path -LiteralPath $fromCsproj) { return $fromCsproj }
        }
    }

    $default = 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord'
    if (Test-Path -LiteralPath $default) { return $default }
    return $null
}

function Get-BannerlordLogPath {
    param(
        [Parameter(Mandatory = $true)][string]$BannerlordRoot,
        [ValidateSet('Launch','Phase1','Status')][string]$Kind = 'Launch'
    )

    switch ($Kind) {
        'Launch' { return (Join-Path $BannerlordRoot 'BlacksmithGuild_Launch.log') }
        'Phase1' { return (Join-Path $BannerlordRoot 'BlacksmithGuild_Phase1.log') }
        'Status' { return (Join-Path $BannerlordRoot 'BlacksmithGuild_Status.json') }
    }
}


function Get-TbgReadyGoldenPathPattern {
    # Keep the em dash in one BOM-protected helper. Callers should not retype it.
    return 'Blacksmith Guild — Ready:'
}
