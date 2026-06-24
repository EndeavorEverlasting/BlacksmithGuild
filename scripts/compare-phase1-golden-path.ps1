# Compare Phase1 tail against golden Continue boot checklist.
# Em dash in tbgReady pattern: docs/conventions/em-dashes-and-log-grep.md
param(
    [Parameter(Mandatory = $true)]
    [string]$Phase1Path,

    [datetime]$SinceLocal,

    [string]$JsonOut
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')

$stepOrder = @(
    @{ id = 'mainMenu'; pattern = 'transition: Idle -> MainMenu'; label = 'Idle -> MainMenu' },
    @{ id = 'mapTransition'; pattern = 'transition: MainMenu -> MapTransition'; label = 'MainMenu -> MapTransition' },
    @{ id = 'mapReady'; pattern = 'transition: MapTransition -> MapReady'; label = 'MapTransition -> MapReady' },
    @{ id = 'bootstrapDisarmed'; pattern = 'bootstrap disarmed'; label = 'bootstrap disarmed' },
    @{ id = 'mapReadyStatusFlush'; pattern = '\[TBG MAPREADY\] StatusFlush ok'; label = '[TBG MAPREADY] StatusFlush ok' },
    @{ id = 'tbgReady'; pattern = (Get-TbgReadyGoldenPathPattern); label = 'campaign map ready marker' }
)

$steps = [ordered]@{}
foreach ($s in $stepOrder) { $steps[$s.id] = $false }

$mapReadyTimestamp = $null
$hotkeyTraceAtMapReady = $false

if (-not (Test-Path -LiteralPath $Phase1Path)) {
    $result = [ordered]@{
        available = $true
        reason = 'Phase1 file missing'
        firstMissingStep = $stepOrder[0].label
        mapReadySeen = $false
        tbgReadySeen = $false
        hotkeyTraceAtMapReady = $false
        steps = $steps
    }
    if ($JsonOut) { $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $JsonOut -Encoding UTF8 }
    return [pscustomobject]$result
}

$lines = Get-Content -LiteralPath $Phase1Path -ErrorAction Stop
$sessionFresh = (-not $SinceLocal)
foreach ($line in $lines) {
    if ($SinceLocal -and $line -match '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]') {
        $lineTime = [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', $null)
        if ($lineTime -lt $SinceLocal) { continue }
    }

    if ($line -match '\[TBG VERSION\] Loaded assembly:') {
        $sessionFresh = $true
    }

    if (-not $sessionFresh) { continue }

    foreach ($s in $stepOrder) {
        if ($line -match $s.pattern) {
            $steps[$s.id] = $true
            if ($s.id -eq 'mapReady' -and $line -match '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]') {
                $mapReadyTimestamp = $Matches[1]
            }
        }
    }

    if ($mapReadyTimestamp -and $line -match '^\[(' + [regex]::Escape($mapReadyTimestamp) + ')\].*\[TBG HOTKEY TRACE\]') {
        $hotkeyTraceAtMapReady = $true
    }
}

$firstMissing = $null
foreach ($s in $stepOrder) {
    if (-not $steps[$s.id]) {
        $firstMissing = $s.label
        break
    }
}

$result = [ordered]@{
    available = $true
    sessionFresh = $sessionFresh
    firstMissingStep = if (-not $sessionFresh) { 'fresh module load ([TBG VERSION])' } else { $firstMissing }
    mapReadySeen = [bool]($sessionFresh -and $steps.mapReady)
    tbgReadySeen = [bool]($sessionFresh -and $steps.tbgReady)
    hotkeyTraceAtMapReady = $hotkeyTraceAtMapReady
    steps = $steps
}

if ($JsonOut) {
    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $JsonOut -Encoding UTF8
}

return [pscustomobject]$result
