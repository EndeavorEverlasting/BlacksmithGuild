# Agent A: sequential F7 hook mask bisect (0x01, 0x03, 0x07, 0x0F).
# End-to-end only — invokes real gate runner via direct PowerShell (no -SkipLaunch).
param(
    [string[]]$Masks = @('0x01', '0x03', '0x07', '0x0F'),
    [string]$LogPath = (Join-Path $PSScriptRoot '..\docs\evidence\live-cert\agent-a-bisect-run.log'),
    [int]$StableSeconds = 60,
    [int]$TimeoutSeconds = 300
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')

$gateScript = Join-Path $PSScriptRoot 'run-f7-gate-continue.ps1'

function Write-BisectLog {
    param([string]$Line)
    $ts = Get-Date -Format 'o'
    $full = "[$ts] $Line"
    Write-Host $full
    $logDir = Split-Path -Parent $LogPath
    if ($logDir -and -not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    Add-Content -LiteralPath $LogPath -Value $full -Encoding UTF8
}

Write-BisectLog "Agent A bisect start HEAD=$(git rev-parse --short HEAD)"

$fakePassDetected = $false
$results = New-Object System.Collections.Generic.List[object]

foreach ($mask in $Masks) {
    Write-BisectLog "=== HookMask $mask ==="
    & powershell -NoProfile -ExecutionPolicy Bypass -File $gateScript `
        -HookMask $mask -StableSeconds $StableSeconds -TimeoutSeconds $TimeoutSeconds
    $ec = $LASTEXITCODE

    $manifestPath = Get-LatestF7GateManifestPath -RepoRoot $repoRoot
    $manifestPass = $false
    if ($manifestPath) {
        $manifestPass = Test-F7GateManifestPass -ManifestPath $manifestPath -RequiredStableSeconds $StableSeconds
    }

    if ($ec -eq 0 -and -not $manifestPass) {
        Write-BisectLog "FAKE_PASS_REJECTED mask=$mask exit=$ec manifest=$manifestPath"
        $fakePassDetected = $true
        $ec = 1
    }

    $results.Add([pscustomobject]@{
        HookMask     = $mask
        ExitCode     = $ec
        ManifestPath = $manifestPath
        ManifestPass = $manifestPass
    }) | Out-Null

    $manifestDetail = ''
    if ($manifestPath -and (Test-Path -LiteralPath $manifestPath)) {
        try {
            $m = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
            $score = if ($m.evidenceCompleteness) { $m.evidenceCompleteness.score } else { 'n/a' }
            $manifestDetail = " launchPath=$($m.launchPath) selectedBy=$($m.launchSelectedBy) targetMismatch=$($m.targetMismatch) evidence=$score lastMarker=$($m.lastPhase1Marker)"
        } catch { }
    }

    Write-BisectLog "=== Exit $ec mask $mask manifest=$manifestPath pass=$manifestPass$manifestDetail ==="

    if ($ec -eq 0 -and $manifestPass) {
        Write-BisectLog 'PASS verified — stopping bisect early'
        exit 0
    }
}

if ($fakePassDetected) {
    Write-BisectLog 'Bisect complete — fake pass rejected (runner exit 0 without manifest PASS)'
    exit 1
}

Write-BisectLog 'All masks failed - bisect complete'
exit 1
