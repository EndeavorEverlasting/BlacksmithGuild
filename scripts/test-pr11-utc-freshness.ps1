# Offline regression: UTC freshness parsing must survive ConvertFrom-Json's datetime coercion.
#
# Locks in the fix for the live attach stall where stateMachine.updatedAtUtc ("...Z") was coerced
# by ConvertFrom-Json into a [datetime] and re-stringified WITHOUT the Z ("06/26/2026 03:40:58"),
# then .ToUniversalTime() treated that UTC wall-clock as local and shifted it +offset into the
# future -> negative age -> statusFresh ALWAYS false -> runner never attaches -> party stuck in town.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'pr11-runtime-state-consumer.ps1')

# 1. ISO "...Z" string -> exact UTC instant, Kind=Utc.
$z = ConvertTo-Pr11Utc -Value '2026-06-26T03:40:58.0000000Z'
if ($z.Kind -ne [System.DateTimeKind]::Utc -or $z.ToString('o') -ne '2026-06-26T03:40:58.0000000Z') {
    throw "Z string must parse as exact UTC got $($z.ToString('o'))/$($z.Kind)"
}

# 2. Culture-rendered UTC wall-clock (Z stripped) must be treated AS UTC, not shifted.
$culture = ConvertTo-Pr11Utc -Value '06/26/2026 03:40:58'
if ($culture.Kind -ne [System.DateTimeKind]::Utc -or $culture.Hour -ne 3) {
    throw "culture-rendered UTC string must stay UTC got $($culture.ToString('o'))"
}

# 3. Pre-converted [datetime] with Unspecified kind is treated AS UTC.
$uns = ConvertTo-Pr11Utc -Value ([datetime]::SpecifyKind([datetime]'2026-06-26T03:40:58', [System.DateTimeKind]::Unspecified))
if ($uns.Kind -ne [System.DateTimeKind]::Utc -or $uns.Hour -ne 3) {
    throw 'unspecified-kind datetime must be treated as UTC'
}

# 4. Local-kind datetime is converted to UTC.
$localDt = [datetime]::SpecifyKind([datetime]'2026-06-26T03:40:58', [System.DateTimeKind]::Local)
$loc = ConvertTo-Pr11Utc -Value $localDt
if ($loc.Kind -ne [System.DateTimeKind]::Utc -or $loc.ToString('o') -ne $localDt.ToUniversalTime().ToString('o')) {
    throw 'local-kind datetime must convert to UTC'
}

# 5. THE regression: a current UTC instant rendered culture-style must read as FRESH.
$nowUtcCulture = ([datetime]::UtcNow).ToString('MM/dd/yyyy HH:mm:ss')
if (-not (Test-Pr11UtcFresh -Utc (ConvertTo-Pr11Utc -Value $nowUtcCulture) -MaxAgeSec 60)) {
    throw 'culture-rendered current UTC must be fresh (statusFresh-always-false regression)'
}

# 6. An hour-old instant stays stale.
$old = ([datetime]::UtcNow.AddHours(-1)).ToString('o')
if (Test-Pr11UtcFresh -Utc (ConvertTo-Pr11Utc -Value $old) -MaxAgeSec 30) {
    throw 'hour-old instant must be stale'
}

# 7. Null is null-safe.
if ($null -ne (ConvertTo-Pr11Utc -Value $null)) { throw 'null must map to null' }

Write-Host 'PASS offline pr11 UTC freshness parse regression'
