# Assistive attach cert skeleton — town-to-town trade probe (requires Agent B runtime command).
param(
    [int]$InboxWaitSec = 120,
    [int]$ProbeTimeoutSec = 30,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'f7-launch-contract.ps1')
. (Join-Path $PSScriptRoot 'f7-external-state-classifier.ps1')
. (Join-Path $PSScriptRoot 'forge-status.ps1')
. (Join-Path $PSScriptRoot 'dev-command-names.ps1')

$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot
$sessionId = (Get-Date).ToString('yyyyMMdd-HHmmss')
$startedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
$checkpointDir = Join-Path $repoRoot "docs\evidence\live-cert\$sessionId\checkpoint-01-assistive-town-trade"
$statusPath = Join-Path $bannerlordRoot 'BlacksmithGuild_Status.json'
$phase1Path = Join-Path $bannerlordRoot 'BlacksmithGuild_Phase1.log'
$crashContextPath = Join-Path $bannerlordRoot 'BlacksmithGuild_CrashContext.json'
$timelinePath = Join-Path $checkpointDir 'ExternalStateTimeline.json'
$manifestPath = Join-Path $checkpointDir 'manifest.json'
$probeCommand = 'AssistiveTownToTownProbe'

if ($WhatIf) {
    Write-Host "WhatIf: would attach assistive, wait for canPollFileInbox, Send-ForgeCommand $probeCommand" -ForegroundColor Cyan
    exit 0
}

$exitCode = 2
$passFail = 'FAIL'
$failureClass = $null
$notes = @()

function Write-AssistManifest {
    param([hashtable]$Extra = @{})

    if (-not (Test-Path -LiteralPath $checkpointDir)) {
        New-Item -ItemType Directory -Force -Path $checkpointDir | Out-Null
    }

    $surface = Get-F7StatusSurfaceSignals -StatusPath $statusPath -CertStartedUtc ([datetime]::Parse($startedAtUtc))
    $manifest = [ordered]@{
        checkpoint = 'checkpoint-01-assistive-town-trade'
        sessionId = $sessionId
        passFail = $passFail
        exitCode = $exitCode
        startedAtUtc = $startedAtUtc
        endedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        mode = 'assistive'
        certTarget = $null
        probeCommand = $probeCommand
        failureClass = $failureClass
        notes = ($notes -join '; ')
        readinessSurface = $surface.readinessSurface
        settlementMenuOpen = [bool]$surface.settlementMenuOpen
        campaignMapSurfaceOpen = [bool]$surface.campaignMapSurfaceOpen
        campaignReady = [bool]$surface.campaignReady
        canPollFileInbox = [bool]$surface.canPollFileInbox
    }
    foreach ($key in $Extra.Keys) {
        $manifest[$key] = $Extra[$key]
    }
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
}

Initialize-F7ExternalStateTimeline -Mode assistive -OutputPath $timelinePath -SessionId $sessionId -StartedAtUtc $startedAtUtc

$det = Get-BannerlordProcessDetection -BannerlordRoot $bannerlordRoot -Phase1Path $phase1Path -StatusPath $statusPath -CrashContextPath $crashContextPath
$attach = Get-F7AssistiveAttachResult -LaunchPath 'continue' -LaunchSelectedBy 'user' `
    -GameProcessRunning ([bool]$det.gameProcessRunning) -AutomationContinueSuccess $false

if (-not $attach.assistiveAttach) {
    $failureClass = 'assistive_attach_rejected'
    $notes += 'Get-F7AssistiveAttachResult returned assistiveAttach=false'
    Write-AssistManifest
    Write-Host "FAIL: $failureClass" -ForegroundColor Red
    exit $exitCode
}

$allowed = Get-DevCommandNames
if ($allowed -notcontains $probeCommand) {
    $failureClass = 'assistive_command_not_supported'
    $notes += "Runtime missing dev command $probeCommand (Agent B lane)"
    $null = Emit-F7ExternalStateTimelineCheckpoint -BannerlordRoot $bannerlordRoot -Mode assistive `
        -Phase1Path $phase1Path -StatusPath $statusPath -CrashContextPath $crashContextPath `
        -LaunchPath 'continue' -LaunchSelectedBy 'user' `
        -ReasonOverride "Assistive town-trade cert blocked: $probeCommand not in Get-DevCommandNames" -Force
    Save-F7ExternalStateTimeline | Out-Null
    Write-AssistManifest @{ assistiveCommandSupported = $false }
    Write-Host "FAIL: $failureClass - add $probeCommand in DevCommandRegistry.cs (Agent B)" -ForegroundColor Yellow
    exit $exitCode
}

$deadline = (Get-Date).AddSeconds($InboxWaitSec)
while ((Get-Date) -lt $deadline) {
    $surface = Get-F7StatusSurfaceSignals -StatusPath $statusPath -CertStartedUtc ([datetime]::Parse($startedAtUtc))
    if ($surface.canPollFileInbox) { break }
    Start-Sleep -Seconds 2
}

$surface = Get-F7StatusSurfaceSignals -StatusPath $statusPath -CertStartedUtc ([datetime]::Parse($startedAtUtc))
if (-not $surface.canPollFileInbox) {
    $failureClass = 'inbox_not_ready'
    $notes += "canPollFileInbox still false after ${InboxWaitSec}s"
    Write-AssistManifest
    Write-Host "FAIL: $failureClass" -ForegroundColor Red
    exit $exitCode
}

try {
    Send-ForgeCommand -CommandName $probeCommand -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec $ProbeTimeoutSec | Out-Null
    $passFail = 'PASS'
    $exitCode = 0
    $notes += "$probeCommand ack received"
} catch {
    $failureClass = 'assistive_probe_failed'
    $notes += $_.Exception.Message
}

$null = Emit-F7ExternalStateTimelineCheckpoint -BannerlordRoot $bannerlordRoot -Mode assistive `
    -Phase1Path $phase1Path -StatusPath $statusPath -CrashContextPath $crashContextPath `
    -LaunchPath 'continue' -LaunchSelectedBy 'user' `
    -ReasonOverride "Assistive town-trade cert ended passFail=$passFail" -Force
Save-F7ExternalStateTimeline | Out-Null
Write-AssistManifest @{ assistiveCommandSupported = $true }
Write-Host "$passFail assistive town-trade cert (exit $exitCode)" -ForegroundColor $(if ($exitCode -eq 0) { 'Green' } else { 'Red' })
exit $exitCode
