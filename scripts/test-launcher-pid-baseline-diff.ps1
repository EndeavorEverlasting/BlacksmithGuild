# Offline regression: launcher UIA must capture a pre-launch PID baseline and prefer
# before/after process-set diff over coordinate/title window fallback for game-host detection.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$src = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'launcher-auto-nav.ps1') -Raw

$anchors = @(
    'public static void CaptureBaselineProcessIds()',
    'private static HashSet<int> GetNewProcessIdsSinceBaseline()',
    'private static HashSet<int> _baselineProcessIds',
    '[UIAHelper]::CaptureBaselineProcessIds()',
    'foreach (var newId in GetNewProcessIdsSinceBaseline())'
)

foreach ($a in $anchors) {
    if ($src -notmatch [regex]::Escape($a)) {
        throw "launcher-auto-nav.ps1 missing anchor: $a"
    }
}

Write-Host 'PASS offline launcher PID baseline diff anchors'
