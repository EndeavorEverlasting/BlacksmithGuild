# Tier 2 visible tavern recruitment cert — disposable save recommended.
param(
    [ValidateSet('AutoLoop', 'Manual')]
    [string]$Mode = 'Manual',

    [switch]$Launch,

    [switch]$AllowContinueRecruit,

    [int]$ReadyTimeoutSec = 900,

    [int]$CommandTimeoutSec = 180
)

$ErrorActionPreference = 'Stop'

& (Join-Path $PSScriptRoot 'run-tavern-hero-intel-cert.ps1') `
    -Mode $Mode `
    -Launch:$Launch `
    -ReadyTimeoutSec $ReadyTimeoutSec `
    -CommandTimeoutSec $CommandTimeoutSec

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

. (Join-Path $PSScriptRoot 'forge-status.ps1')
$repoRoot = Split-Path -Parent $PSScriptRoot
$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot
$recruitPath = Join-Path $bannerlordRoot 'BlacksmithGuild_TavernHeroRecruitment.json'
$phase1Path = Join-Path $bannerlordRoot 'BlacksmithGuild_Phase1.log'

& (Join-Path $PSScriptRoot 'write-agent-iteration-config.ps1') `
    -Mode $Mode `
    -BannerlordRoot $bannerlordRoot `
    -AllowContinueRecruit:$AllowContinueRecruit | Out-Null

Write-Host ''
Write-Host '[cert] RecruitTavernHeroVisibleNow' -ForegroundColor Yellow
Send-ForgeCommand -CommandName 'RecruitTavernHeroVisibleNow' -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec $CommandTimeoutSec | Out-Null

if (-not (Test-Path -LiteralPath $recruitPath)) {
    Write-Host 'FAIL: BlacksmithGuild_TavernHeroRecruitment.json not written.' -ForegroundColor Red
    exit 1
}

$recruit = Get-Content -LiteralPath $recruitPath -Raw | ConvertFrom-Json
$verdict = 'INDETERMINATE'
$detail = 'Recruitment JSON present but not evaluated.'

if ($recruit.mutationAudit.directHeroInjectionUsed -eq $false) {
    if ($recruit.mutationAudit.partyChangedByVanillaRecruitment -eq $true) {
        $verdict = 'PASS'
        $detail = "hero recruited; goldDelta=$($recruit.after.goldDelta)"
    } elseif ($recruit.blockedReason) {
        $verdict = 'BLOCKED'
        $detail = $recruit.blockedReason
    }
}

if ($verdict -eq 'INDETERMINATE' -and (Test-Path -LiteralPath $phase1Path)) {
    $tail = Get-Content -LiteralPath $phase1Path -Tail 80 -ErrorAction SilentlyContinue
    if ($tail -match '\[TBG TAVERN SUCCESS\]') {
        $verdict = 'PASS'
        $detail = 'Phase1 success line detected.'
    } elseif ($tail -match '\[TBG TAVERN\] blocked:') {
        $verdict = 'BLOCKED'
        $detail = 'Phase1 blocked line detected.'
    }
}

Write-Host ''
Write-Host "Tier 2 ${verdict}: $detail" -ForegroundColor $(if ($verdict -eq 'PASS') { 'Green' } elseif ($verdict -eq 'BLOCKED') { 'Yellow' } else { 'Red' })
Write-Host "JSON:   $recruitPath"

if ($verdict -ne 'PASS') { exit 1 }
