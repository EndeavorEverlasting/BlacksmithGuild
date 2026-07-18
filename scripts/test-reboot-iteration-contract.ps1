$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot
. (Join-Path $PSScriptRoot 'reboot-context-classifier.ps1')

function Assert-ContainsText {
    param([string]$Path, [string]$Needle)
    $full = Join-Path $repoRoot $Path
    if (-not (Test-Path -LiteralPath $full)) { throw "missing file: $Path" }
    $text = Get-Content -LiteralPath $full -Raw
    if ($text.IndexOf($Needle, [System.StringComparison]::Ordinal) -lt 0) { throw "$Path missing '$Needle'" }
}

Assert-ContainsText 'ForgeReboot.cmd' 'scripts\run-reboot-iteration.ps1'
Assert-ContainsText 'ForgeReboot.cmd' '-NoProfile -ExecutionPolicy Bypass'
Assert-ContainsText 'scripts\run-reboot-iteration.ps1' '[int]$MaxIterations = 2'
Assert-ContainsText 'scripts\run-reboot-iteration.ps1' '[int]$RepeatThreshold = 2'
Assert-ContainsText 'scripts\run-reboot-iteration.ps1' '[int]$NormalActionTimeoutSec = 30'
Assert-ContainsText 'scripts\run-reboot-iteration.ps1' 'run-autonomous-assist-session.ps1'
Assert-ContainsText 'scripts\run-reboot-iteration.ps1' 'stable_gap'
Assert-ContainsText 'scripts\reboot-context-classifier.ps1' 'function New-RebootNormalizedContext'
Assert-ContainsText 'scripts\reboot-context-classifier.ps1' 'function Test-RebootContextRepeat'
Assert-ContainsText 'scripts\reboot-context-classifier.ps1' 'function Write-RebootStableGapHandoff'
Assert-ContainsText 'docs\operator\reboot-iteration-doctrine.md' 'AI tokens are for designing patches'
Assert-ContainsText 'docs\operator\reboot-iteration-doctrine.md' 'checkpoint-based'
Assert-ContainsText '.gitignore' 'docs/evidence/reboot*-reboot-session/'

if ((Get-RebootActionTimeoutSec -ActionClass normal) -ne 30) { throw 'normal action timeout must default to 30 seconds' }
if ((Get-RebootActionTimeoutSec -ActionClass long_distance_travel) -le 30) { throw 'long-distance travel must be allowed a longer timeout classification' }
if ((Get-RebootActionTimeoutSec -ActionClass large_smithing) -le 30) { throw 'large smithing must be allowed a longer timeout classification' }
if ((Get-RebootActionTimeoutSec -ActionClass mass_trade) -le 30) { throw 'mass trade must be allowed a longer timeout classification' }

$scriptText = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts\run-reboot-iteration.ps1') -Raw
foreach ($forbidden in @('git add docs\evidence','git commit','git push','Remove-Item -Path $env:ProgramData')) {
    if ($scriptText.IndexOf($forbidden, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        throw "reboot script must not perform forbidden action: $forbidden"
    }
}

Write-Host 'PASS reboot iteration contract regression'