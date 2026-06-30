# Read-only verifier for shared automation profile CMD/state contract.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]

function Read-Text($RelativePath) {
    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) { $failures.Add("missing file: $RelativePath") | Out-Null; return '' }
    return Get-Content -LiteralPath $path -Raw
}
function Assert-Contains($RelativePath, $Needle, $Why = '') {
    $text = Read-Text $RelativePath
    if ($text.IndexOf($Needle, [System.StringComparison]::Ordinal) -lt 0) { $failures.Add("$RelativePath missing '$Needle' $Why") | Out-Null }
}
function Assert-NotContains($RelativePath, $Needle, $Why = '') {
    $text = Read-Text $RelativePath
    if ($text.IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $failures.Add("$RelativePath must not contain '$Needle' $Why") | Out-Null }
}

$helper = 'scripts\automation-profile.ps1'
$cmd = 'ForgeProfile.cmd'
$reboot = 'scripts\run-reboot-iteration.ps1'
$assist = 'scripts\run-autonomous-assist-session.ps1'
$common = 'scripts\governor-operator-common.ps1'

Read-Text $helper | Out-Null
Read-Text $cmd | Out-Null
Read-Text $common | Out-Null

foreach ($needle in @(
    'function Get-TbgAutomationProfileJsonPath',
    'function Read-TbgAutomationProfile',
    'function Write-TbgAutomationProfile',
    'function Resolve-TbgAutomationProfile',
    'BlacksmithGuild_AutomationProfile.json',
    "@('default', 'economic_loop')",
    'profile = $Profile',
    'requestedBy = $RequestedBy',
    'reason = $Reason',
    'updatedAtUtc = (Get-Date).ToUniversalTime().ToString(''o'')',
    'source = ''explicit_CertProfile''',
    'source = ''shared_json''',
    'source = ''safe_default''',
    'explicit parameter wins'
)) { Assert-Contains $helper $needle }

foreach ($needle in @(
    'ForgeProfile.cmd',
    'status',
    'default',
    'economic_loop',
    'toggle',
    'FORGE_NO_PAUSE',
    'scripts\automation-profile.ps1',
    'Write-TbgAutomationProfile',
    'Resolve-TbgAutomationProfile'
)) { Assert-Contains $cmd $needle }

Assert-Contains $assist "[ValidateSet('default', 'economic_loop')]" 'existing direct -CertProfile calls must remain valid'
Assert-Contains $assist "governor-operator-common.ps1" 'direct runner must load the shared operator/profile seam before evidence setup'
Assert-Contains $common 'function Resolve-GovernorAutomationProfileForDirectAssistRunner' 'direct runner profile resolver must live in the dot-sourced operator seam'
Assert-Contains $common 'Test-GovernorExplicitCertProfileArgument' 'direct runner must detect explicit -CertProfile'
Assert-Contains $common 'Resolve-TbgAutomationProfile -ExplicitProfile $explicitProfile' 'direct runner must use explicit -> shared JSON -> safe default resolver'
Assert-Contains $common 'Set-Variable -Name CertProfile -Value ([string]$resolution.profile) -Scope 1' 'direct runner CertProfile variable must be corrected before evidence/session setup'
Assert-Contains $common 'Set-Variable -Name TbgAutomationProfileResolution -Value $resolution -Scope 1' 'direct runner must expose resolved profile metadata'
Assert-Contains $common 'run-autonomous-assist-session\.ps1' 'resolver must only trigger for direct assist runner command line'

Assert-Contains $reboot "automation-profile.ps1" 'Reboot must load shared automation profile state'
Assert-Contains $reboot 'Resolve-TbgAutomationProfile' 'Reboot must resolve explicit -> shared JSON -> safe default'
Assert-Contains $reboot "'-CertProfile',$CertProfile" 'Reboot must forward resolved profile to assist runner'
Assert-Contains $reboot 'automationProfileSource' 'Reboot summary must expose profile source'
Assert-NotContains $helper 'personal save' 'profile helper must not mention or mutate saves'

if ($failures.Count -gt 0) {
    Write-Host "FAIL: automation profile contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}
Write-Host 'PASS: automation profile contract verified.' -ForegroundColor Green
exit 0
