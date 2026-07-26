# Offline regression: Send-ForgeCommand must pick sequence=3 after Phase1 shows consumed sequence=2,
# even when a noisy trace-only tail would break a last-800-lines scan.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'dev-command-names.ps1')
. (Join-Path $PSScriptRoot 'forge-status.ps1')

$forgeStatusPath = Join-Path $PSScriptRoot 'forge-status.ps1'
$forgeStatusText = Get-Content -LiteralPath $forgeStatusPath -Raw
foreach ($needle in @(
    'Get-LastConsumedForgeInboxSequence',
    'Select-String',
    'consumed sequence=',
    'commandId',
    'runId',
    'correlationId',
    'Only the exact correlated ACK above may complete this wait.'
)) {
    if ($forgeStatusText -notmatch [regex]::Escape($needle)) {
        throw "forge-status.ps1 missing production needle: $needle"
    }
}

$tmpRoot = Join-Path $env:TEMP "forge-seq-test-$PID"
if (Test-Path -LiteralPath $tmpRoot) {
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $tmpRoot | Out-Null

try {
    $phase1Path = Join-Path $tmpRoot 'BlacksmithGuild_Phase1.log'
    $inboxPath = Join-Path $tmpRoot 'BlacksmithGuild_CommandInbox.json'

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('[2026-06-24 02:04:12] [TBG INBOX] consumed sequence=1') | Out-Null
    $lines.Add('[2026-06-24 02:04:18] [TBG INBOX] consumed sequence=2') | Out-Null
    for ($i = 0; $i -lt 1200; $i++) {
        $seq = 1610000 + $i
        $lines.Add("[2026-06-24 02:08:24] [TBG TEST] [TBG TRACE] seq=$seq area=MapTransitionGuard op=CampaignTick stage=ok elapsedMs=1 path=continue") | Out-Null
    }
    Set-Content -LiteralPath $phase1Path -Value $lines -Encoding UTF8

    $staleInbox = [ordered]@{
        sequence = 1
        command  = 'AssistiveTownToTownProbe'
        source   = 'stale-fixture'
    }
    $staleInbox | ConvertTo-Json | Set-Content -LiteralPath $inboxPath -Encoding UTF8

    $lastConsumed = Get-LastConsumedForgeInboxSequence -BannerlordRoot $tmpRoot
    if ($lastConsumed -ne 2) {
        throw "Expected last consumed sequence=2 got $lastConsumed"
    }

    $tail800 = Get-Content -LiteralPath $phase1Path -Tail 800 -ErrorAction Stop
    if ($tail800 -match '\[TBG INBOX\] consumed sequence=2') {
        throw 'Negative control failed: tail-800 scan must not find consumed sequence=2'
    }

    $writtenSeq = Send-ForgeCommand -CommandName AssistiveTownToTownProbe -BannerlordRoot $tmpRoot
    if ($writtenSeq -ne 3) {
        throw "Expected written sequence=3 got $writtenSeq"
    }

    $inbox = Get-Content -LiteralPath $inboxPath -Raw | ConvertFrom-Json
    $inboxSeq = [int]$inbox.sequence
    if ($inboxSeq -eq 1) {
        throw 'stale inbox sequence regression'
    }
    if ($inboxSeq -ne 3) {
        throw "Inbox JSON sequence must be 3 got $inboxSeq"
    }
    foreach ($field in @('commandId', 'runId', 'correlationId', 'requestedUtc')) {
        if (-not ($inbox.PSObject.Properties.Name -contains $field) -or
            [string]::IsNullOrWhiteSpace([string]$inbox.$field)) {
            throw "Inbox JSON must carry non-empty $field"
        }
    }
    if ([string]$inbox.correlationId -ne [string]$inbox.runId) {
        throw 'Default command correlationId must equal runId'
    }

    $inboxSource = Get-Content -LiteralPath (Join-Path $repoRoot 'src\BlacksmithGuild\DevTools\DevCommandFileInbox.cs') -Raw
    foreach ($needle in @('payload?.CommandId', 'payload?.RunId', 'payload?.CorrelationId', 'payload?.RequestedUtc', 'ackUtc')) {
        if ($inboxSource -notmatch [regex]::Escape($needle)) {
            throw "DevCommandFileInbox.cs missing correlated ACK field $needle"
        }
    }

    Write-Host 'PASS offline forge command sequence and correlated ACK contract'
}
finally {
    if (Test-Path -LiteralPath $tmpRoot) {
        Remove-Item -LiteralPath $tmpRoot -Recurse -Force
    }
}
