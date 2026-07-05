# Verifies that launcher Safe Mode remains documented as a first-class handoff state.

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Needle
    )

    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        $failures.Add("missing file: $RelativePath") | Out-Null
        return
    }

    $text = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    if ($text.IndexOf($Needle, [System.StringComparison]::Ordinal) -lt 0) {
        $failures.Add("$RelativePath missing '$Needle'") | Out-Null
    }
}

$doc = 'docs\handoff\launcher-safe-mode-handoff-doctrine.md'

foreach ($needle in @(
    '# Launcher Safe Mode Handoff Doctrine',
    'Safe Mode is part of launcher handoff.',
    'It is not solved by adding a longer timeout.',
    'frozen_target_invalidated',
    'Safe Mode modal',
    'Alt+N = No = decline Safe Mode = continue normal launch',
    'Do not use `Alt+C`',
    'safe_mode_detected',
    'decline_safe_mode',
    'safe_mode_normal_launch',
    'safeModeHandled=true',
    'postInvalidationResult=game_spawned',
    'post_handoff_watch',
    'operator_action_required',
    'Silent fallback is not allowed.'
)) {
    Assert-Contains $doc $needle
}

if ($failures.Count -gt 0) {
    Write-Host "FAIL: launcher Safe Mode doctrine has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: launcher Safe Mode doctrine verified.' -ForegroundColor Green