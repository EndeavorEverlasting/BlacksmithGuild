# Offline regression: faction-power posture scan must be crash-hardened.
#
# Locks in the fix for the travel-time native crash where the every-~0.5s status flush ran
# FactionPowerPostureScan across all nearby parties while the campaign clock was running and
# hit a native access violation. Two layers are asserted:
#   1. Source anchors: the C# guards/throttle/skip actually exist in the shipped source.
#   2. Logic mirror: the gate decision (skip during travel OR rate-limited -> reuse cache).
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

function Read-Source {
    param([string]$RelPath)
    $full = Join-Path $repoRoot $RelPath
    if (-not (Test-Path -LiteralPath $full)) { throw "missing source: $RelPath" }
    return Get-Content -LiteralPath $full -Raw
}

# --- Layer 1: source anchors -------------------------------------------------

$scanner = Read-Source 'src/BlacksmithGuild/Cohesion/CohesionPartyScanner.cs'
if ($scanner -notmatch 'IsPartyReadable') {
    throw 'CohesionPartyScanner must gate parties through IsPartyReadable'
}
if ($scanner -notmatch 'party\.IsActive' -or $scanner -notmatch 'party\.Party\s*!=\s*null') {
    throw 'IsPartyReadable must require party.IsActive and non-null party.Party'
}
if ($scanner -notmatch 'new List<MobileParty>\(MobileParty\.All\)') {
    throw 'Scan must snapshot MobileParty.All before enumeration to avoid mid-tick mutation'
}

$forge = Read-Source 'src/BlacksmithGuild/ForgeStatus.cs'
if ($forge -notmatch 'FactionPowerPostureStatusScanEnabled') {
    throw 'AppendFactionPowerPosture must be gated by the diagnostic status scan switch'
}
if ($forge -notmatch 'faction-posture-status-scan-disabled') {
    throw 'AppendFactionPowerPosture must log the disabled diagnostic scan gate'
}
if ($forge -notmatch 'IsAssistTravelActive') {
    throw 'AppendFactionPowerPosture must skip while assistive travel is active'
}
if ($forge -notmatch 'FactionPostureScanMinIntervalSec') {
    throw 'AppendFactionPowerPosture must rate-limit the scan via a min interval'
}
if ($forge -notmatch '_lastFactionPostureJson') {
    throw 'AppendFactionPowerPosture must reuse a cached posture block between scans'
}

$travel = Read-Source 'src/BlacksmithGuild/DevTools/AutoTravelService.cs'
if ($travel -notmatch 'public static bool IsAssistTravelActive') {
    throw 'AutoTravelService must expose IsAssistTravelActive'
}

$config = Read-Source 'src/BlacksmithGuild/DevTools/DevToolsConfig.cs'
if ($config -notmatch 'FactionPowerPostureStatusScanEnabled\s*=\s*false') {
    throw 'FactionPowerPostureStatusScanEnabled must default false for live attach proof safety'
}

# --- Layer 2: logic mirror ---------------------------------------------------

function Test-ShouldScanPosture {
    param(
        [bool]$StatusScanEnabled,
        [bool]$AssistTravelActive,
        [double]$SecondsSinceLastScan,
        [double]$MinIntervalSec = 5.0
    )
    if (-not $StatusScanEnabled) { return $false }
    if ($AssistTravelActive) { return $false }
    return $SecondsSinceLastScan -ge $MinIntervalSec
}

# Diagnostic disabled: never scan during live attach proof.
if (Test-ShouldScanPosture -StatusScanEnabled $false -AssistTravelActive $false -SecondsSinceLastScan 999) {
    throw 'disabled diagnostic status scan must not run'
}

# Active travel: never scan (reuse cache), regardless of elapsed time.
if (Test-ShouldScanPosture -StatusScanEnabled $true -AssistTravelActive $true -SecondsSinceLastScan 999) {
    throw 'must not scan posture during active assistive travel'
}

# Stationary but within interval: reuse cache, do not scan.
if (Test-ShouldScanPosture -StatusScanEnabled $true -AssistTravelActive $false -SecondsSinceLastScan 1.0) {
    throw 'must not re-scan within the throttle interval'
}

# Stationary and interval elapsed: scan.
if (-not (Test-ShouldScanPosture -StatusScanEnabled $true -AssistTravelActive $false -SecondsSinceLastScan 6.0)) {
    throw 'must scan posture once interval has elapsed and not travelling'
}

# Mirror of IsPartyReadable: inactive or null-Party parties are skipped.
function Test-PartyReadable {
    param([bool]$IsActive, [bool]$HasParty)
    return $IsActive -and $HasParty
}
if (Test-PartyReadable -IsActive $false -HasParty $true) { throw 'inactive party must be skipped' }
if (Test-PartyReadable -IsActive $true -HasParty $false) { throw 'party with null Party must be skipped' }
if (-not (Test-PartyReadable -IsActive $true -HasParty $true)) { throw 'active party with Party must be readable' }

Write-Host 'PASS offline faction posture scan guard regression'
