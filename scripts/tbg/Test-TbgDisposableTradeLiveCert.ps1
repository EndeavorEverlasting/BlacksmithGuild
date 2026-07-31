[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$OutputRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
$RepoRoot = [IO.Path]::GetFullPath($RepoRoot)
if (-not [string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
    New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
}

$failures = [System.Collections.Generic.List[string]]::new()
function Fail([string]$Message) { $failures.Add($Message) | Out-Null }
function Read-Text([string]$RelativePath) {
    $path = Join-Path $RepoRoot ($RelativePath -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Fail "missing: $RelativePath"; return '' }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8
}
function Read-Json([string]$RelativePath) {
    $text = Read-Text $RelativePath
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    try { return $text | ConvertFrom-Json -ErrorAction Stop }
    catch { Fail "invalid JSON: $RelativePath :: $($_.Exception.Message)"; return $null }
}
function Write-Result([string]$Status) {
    if ([string]::IsNullOrWhiteSpace($OutputRoot)) { return }
    [ordered]@{
        schema = 'TbgDisposableTradeLiveCertValidationResult.v1'
        generatedUtc = [DateTime]::UtcNow.ToString('o')
        status = $Status
        failureCount = $failures.Count
        failures = @($failures.ToArray())
        proofCeiling = 'static composition only; no Bannerlord launch or gameplay proof'
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutputRoot 'validation-result.json') -Encoding UTF8
}

$contract = Read-Json '.tbg/workflows/disposable-visible-trade-live-cert.contract.json'
$wrapperPath = Join-Path $RepoRoot 'scripts/tbg/Invoke-TbgDisposableTradeLiveCert.ps1'
$wrapper = Read-Text 'scripts/tbg/Invoke-TbgDisposableTradeLiveCert.ps1'
$cmd = Read-Text 'ForgeDisposableTradeCert.cmd'
$visible = Read-Text 'scripts/run-visible-trade-proof.ps1'
$versionPolicy = Read-Json '.tbg/harness/policies/version-authority.policy.json'
$disposableRegistry = Read-Json '.tbg/state/disposable-save.registry.json'

$tokens = $null
$parseErrors = $null
if (Test-Path -LiteralPath $wrapperPath -PathType Leaf) {
    [System.Management.Automation.Language.Parser]::ParseFile($wrapperPath, [ref]$tokens, [ref]$parseErrors) | Out-Null
    foreach ($err in @($parseErrors)) { Fail "wrapper parser error: $($err.Message)" }
}

if ($contract) {
    if ([string]$contract.operatorEntry -ne 'ForgeDisposableTradeCert.cmd') { Fail 'contract operatorEntry mismatch' }
    if ([string]$contract.implementation -ne 'scripts/tbg/Invoke-TbgDisposableTradeLiveCert.ps1') { Fail 'contract implementation mismatch' }
    if ($contract.requiresCleanMain -ne $true) { Fail 'contract must require clean main' }
    if ([string]$contract.saveAuthority.requiredState -ne 'PASS_SAVE_VERSION_EXACT') { Fail 'contract must require exact save version' }
    if ([string]$contract.visibleTradeCoordinator -ne 'scripts/run-visible-trade-proof.ps1') { Fail 'contract must delegate runtime proof to canonical visible-trade coordinator' }
    if ([string]$contract.requiredVisibleTradeTerminalState -ne 'PASS_VISIBLE_TRADE_PROVEN') { Fail 'contract visible-trade terminal state mismatch' }
    if ([string]$contract.successState -ne 'PASS_DISPOSABLE_VISIBLE_TRADE_LIVE_CERT') { Fail 'contract success state mismatch' }
    $signals = @($contract.requiredObservedSignals | ForEach-Object { [string]$_ })
    foreach ($required in @('commandAck.observed','movement.observed','arrival.observed','buy.observed','buy.inventoryDelta > 0','buy.goldDelta < 0')) {
        if ($signals -notcontains $required) { Fail "contract missing required observed signal: $required" }
    }
    if ($signals -contains 'sell.observed') { Fail 'contract must not promote the existing buy-only visible trade proof into a sell claim' }
}

foreach ($needle in @(
    "branch -ne 'main'",
    'status --porcelain',
    'Test-TbgVersionAuthority.ps1',
    'Test-TbgDisposableSaveRegistry.ps1',
    'Update-TbgDisposableSaveRegistry.ps1',
    'Invoke-TbgSaveCompatibility.ps1',
    'PASS_SAVE_VERSION_EXACT',
    'run-visible-trade-proof.ps1',
    "mode -eq 'certify'",
    "PASS_VISIBLE_TRADE_PROVEN",
    'commandAck.observed',
    'movement.observed',
    'arrival.observed',
    'buy.observed',
    'buy.inventoryDelta -gt 0',
    'buy.goldDelta -lt 0',
    'PASS_DISPOSABLE_VISIBLE_TRADE_LIVE_CERT'
)) {
    if ($wrapper -notmatch [regex]::Escape($needle)) { Fail "wrapper missing required marker: $needle" }
}
if ($wrapper -match 'Invoke-TbgPriorityEngine\.ps1') { Fail 'live cert must not reintroduce the single-priority dispatcher as terminal proof' }
foreach ($forbiddenSwitch in @('-Diagnostic','-SkipBuild','-SkipLaunch','-DryRun')) {
    if ($wrapper -match ('run-visible-trade-proof\.ps1[^\r\n]*' + [regex]::Escape($forbiddenSwitch))) { Fail "certifying visible-trade invocation includes forbidden switch: $forbiddenSwitch" }
}
if ($wrapper -notmatch 'powershell\.exe[^\r\n]*Test-TbgVersionAuthority' -and $wrapper -notmatch 'Invoke-ValidatorChild') { Fail 'validator exit isolation marker missing' }

foreach ($needle in @('Invoke-TbgDisposableTradeLiveCert.ps1','exit /b %TBG_EXIT%')) {
    if ($cmd -notmatch [regex]::Escape($needle)) { Fail "CMD entrypoint missing marker: $needle" }
}
if ($cmd -match '(?i)pause') { Fail 'agent-facing live cert CMD must not pause' }

foreach ($needle in @('PASS_VISIBLE_TRADE_PROVEN','buyResult.observed','buyResult.inventoryDelta -gt 0','buyResult.goldDelta -lt 0')) {
    if ($visible -notmatch [regex]::Escape($needle)) { Fail "canonical visible-trade coordinator missing proof marker: $needle" }
}
if ($visible -notmatch 'sellResult\.observed\s*=\s*\$buyResult\.observed\s*-and\s*\$buyResult\.goldDelta\s*-gt\s*0') {
    Fail 'visible-trade sell proof shape changed; review whether the wrapper proof boundary should now include independent sell evidence'
}

if ($versionPolicy -and [string]$versionPolicy.canonicalRegistry -ne '.tbg/state/game-compatibility.registry.json') { Fail 'version authority policy canonical registry drifted' }
if ($disposableRegistry -and [string]$disposableRegistry.saveCompatibilityEntrypoint -ne 'scripts/tbg/Invoke-TbgSaveCompatibility.ps1') { Fail 'disposable registry canonical save entrypoint drifted' }

if ($failures.Count -gt 0) {
    Write-Result -Status 'FAIL'
    Write-Host 'FAIL_disposable_trade_live_cert_contract'
    foreach ($failure in $failures) { Write-Host " - $failure" }
    exit 1
}
Write-Result -Status 'PASS'
Write-Host 'PASS_disposable_trade_live_cert_contract'
exit 0
