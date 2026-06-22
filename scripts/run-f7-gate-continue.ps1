# F7 Continue gate harness wrapper. Does not launch gameplay systems by itself.
param(
    [string]$HookMask = '0x01',
    [int]$StabilitySeconds = 60,
    [switch]$SkipLaunch
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot
& (Join-Path $PSScriptRoot 'write-launch-log.ps1') -BannerlordRoot $bannerlordRoot -Message ("F7 gate continue start HookMask={0} StabilitySeconds={1} SkipLaunch={2}" -f $HookMask,$StabilitySeconds,[bool]$SkipLaunch)
Write-Host ("F7 gate continue: HookMask={0}; stable poll={1}s" -f $HookMask,$StabilitySeconds)
Write-Host 'Canonical bisect invocation: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-f7-gate-continue.ps1 -HookMask 0x01'
Write-Host 'Do not wrap through cmd /c or Run-F7GateContinue.cmd during Unicode/em-dash bisects.'
if (-not $SkipLaunch) { Write-Host 'Launch intentionally not performed by this safety wrapper in agent validation.' }
exit 0
