# Central Bannerlord + BlacksmithGuild log/status path helpers.
# C# writes Phase1/Forge/Status under BasePath.Name (usually Documents);
# PS automation also reads Steam BannerlordRoot — check both.

function Get-BannerlordDocsRoot {
    $docsRoot = Join-Path $env:USERPROFILE 'Documents\Mount and Blade II Bannerlord'
    if (-not (Test-Path -LiteralPath $docsRoot)) {
        New-Item -ItemType Directory -Force -Path $docsRoot | Out-Null
    }
    return $docsRoot
}

function Get-BannerlordRootFromRepo {
    param([string]$RepoRoot = (Split-Path -Parent $PSScriptRoot))

    $csproj = Join-Path $RepoRoot 'src\BlacksmithGuild\BlacksmithGuild.csproj'
    if (Test-Path -LiteralPath $csproj) {
        $csprojText = Get-Content -LiteralPath $csproj -Raw
        if ($csprojText -match '<GameFolder>([^<]+)</GameFolder>') {
            $fromCsproj = $Matches[1] -replace '&amp;', '&'
            if (Test-Path -LiteralPath $fromCsproj) { return $fromCsproj }
        }
    }

    $default = 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord'
    if (Test-Path -LiteralPath $default) { return $default }

    throw 'Bannerlord install not found. Set GameFolder in BlacksmithGuild.csproj.'
}

function Get-Phase1LogCandidates {
    param([string]$BannerlordRoot)

    @(
        (Join-Path $BannerlordRoot 'BlacksmithGuild_Phase1.log'),
        (Join-Path (Get-BannerlordDocsRoot) 'BlacksmithGuild_Phase1.log')
    ) | Select-Object -Unique
}

function Get-StatusJsonCandidates {
    param([string]$BannerlordRoot)

    @(
        (Join-Path $BannerlordRoot 'BlacksmithGuild_Status.json'),
        (Join-Path (Get-BannerlordDocsRoot) 'BlacksmithGuild_Status.json')
    ) | Select-Object -Unique
}

function Get-Phase1LogPath {
    param([string]$BannerlordRoot)

    return Find-NewestExistingPath -Candidates (Get-Phase1LogCandidates -BannerlordRoot $BannerlordRoot) `
        -Preferred (Join-Path (Get-BannerlordDocsRoot) 'BlacksmithGuild_Phase1.log')
}

function Get-StatusJsonPath {
    param([string]$BannerlordRoot)

    return Find-NewestExistingPath -Candidates (Get-StatusJsonCandidates -BannerlordRoot $BannerlordRoot) `
        -Preferred (Join-Path (Get-BannerlordDocsRoot) 'BlacksmithGuild_Status.json')
}

function Get-ForgeLogPath {
    return Join-Path (Get-BannerlordDocsRoot) 'BlacksmithGuild_Forge.log'
}

function Get-LaunchLogPath {
    param([string]$BannerlordRoot)
    return Join-Path $BannerlordRoot 'BlacksmithGuild_Launch.log'
}

function Get-NavLockPath {
    param([string]$BannerlordRoot)
    return Join-Path $BannerlordRoot 'BlacksmithGuild_Launch.lock'
}

function Find-NewestExistingPath {
    param(
        [string[]]$Candidates,
        [string]$Preferred
    )

    $newest = $null
    $newestTime = [datetime]::MinValue
    foreach ($path in $Candidates) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $mtime = (Get-Item -LiteralPath $path).LastWriteTime
        if ($mtime -gt $newestTime) {
            $newestTime = $mtime
            $newest = $path
        }
    }

    if ($newest) { return $newest }
    return $Preferred
}

# Central Bannerlord + BlacksmithGuild log/status path helpers.
# C# writes Phase1/Forge/Status under BasePath.Name (usually Documents);
# PS automation also reads Steam BannerlordRoot — check both.
# Em dash in log grep: docs/conventions/em-dashes-and-log-grep.md

$script:ModDisplayEmDash = [char]0x2014
$script:TbgModDisplayReadyPrefix = "Blacksmith Guild $([char]0x2014) Ready:"

function Get-TbgReadyGoldenPathPattern {
    $ready = [regex]::Escape($script:TbgModDisplayReadyPrefix)
    return "${ready}|TBG READY|\[TBG MAPREADY\] immediate hooks complete|map_ready.*PASS"
}

function Test-Phase1ReadyLine {
    param([string]$Line)

    return $Line -match 'TBG READY' `
        -or $Line -match ([regex]::Escape($script:TbgModDisplayReadyPrefix)) `
        -or $Line -match '\[TBG MAPREADY\] immediate hooks complete' `
        -or $Line -match 'map_ready.*PASS'
}

function Get-F7GateManifestPath {
    param([string]$CheckpointDir)
    return Join-Path $CheckpointDir 'manifest.json'
}

function Confirm-F7GateManifestWritten {
    param([string]$CheckpointDir)

    $path = Get-F7GateManifestPath -CheckpointDir $CheckpointDir
    if (-not (Test-Path -LiteralPath $path)) {
        throw "F7 gate manifest missing: $path"
    }
    try {
        Get-Content -LiteralPath $path -Raw | ConvertFrom-Json | Out-Null
    } catch {
        throw "F7 gate manifest unreadable: $path - $($_.Exception.Message)"
    }
    return $path
}

function Test-F7GateManifestPass {
    param(
        [string]$ManifestPath,
        [int]$RequiredStableSeconds = 60
    )

    if (-not $ManifestPath -or -not (Test-Path -LiteralPath $ManifestPath)) { return $false }
    try {
        $m = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
    } catch { return $false }

    return ($m.passFail -eq 'PASS') -and ([int]$m.exitCode -eq 0) -and ([int]$m.stableSeconds -ge $RequiredStableSeconds)
}

function Get-LatestF7GateManifestPath {
    param(
        [string]$RepoRoot,
        [string]$SessionId = $null
    )

    if ($SessionId) {
        $explicit = Join-Path $RepoRoot "docs\evidence\live-cert\$SessionId\checkpoint-01-f7-gate\manifest.json"
        if (Test-Path -LiteralPath $explicit) { return $explicit }
    }

    $evidenceRoot = Join-Path $RepoRoot 'docs\evidence\live-cert'
    if (-not (Test-Path -LiteralPath $evidenceRoot)) { return $null }

    $latest = Get-ChildItem -LiteralPath $evidenceRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d{8}-\d{6}$' } |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if (-not $latest) { return $null }

    $path = Join-Path $latest.FullName 'checkpoint-01-f7-gate\manifest.json'
    if (Test-Path -LiteralPath $path) { return $path }
    return $null
}

function Write-ForgeRunLogPaths {
    param([string]$BannerlordRoot)

    $docsRoot = Get-BannerlordDocsRoot
    $phase1Candidates = Get-Phase1LogCandidates -BannerlordRoot $BannerlordRoot

    Write-Host ''
    Write-Host '--- Log surfaces (tail after run) ---' -ForegroundColor Cyan
    Write-Host "Forge log:    $(Get-ForgeLogPath)"
    foreach ($p in $phase1Candidates) {
        $tag = if ($p -like "$docsRoot*") { 'Documents' } else { 'Steam root' }
        Write-Host "Phase1 log ($tag): $p"
    }
    Write-Host "Launch log:   $(Get-LaunchLogPath -BannerlordRoot $BannerlordRoot)"
    Write-Host "Status JSON:  $(Get-StatusJsonPath -BannerlordRoot $BannerlordRoot)"
    Write-Host 'Collect:      .\forge.ps1 -CollectDiagnostics' -ForegroundColor DarkGray
    Write-Host ''
}
