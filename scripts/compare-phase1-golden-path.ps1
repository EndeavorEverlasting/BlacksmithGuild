# Compare Phase1 tail against golden Continue boot checklist.
param(
    [Parameter(Mandatory = $true)]
    [string]$Phase1Path,

    [datetime]$SinceLocal,

    [string]$JsonOut
)

$ErrorActionPreference = 'Stop'

$stepOrder = @(
    @{ id = 'mainMenu'; pattern = 'transition: Idle -> MainMenu'; label = 'Idle -> MainMenu' },
    @{ id = 'mapTransition'; pattern = 'transition: MainMenu -> MapTransition'; label = 'MainMenu -> MapTransition' },
    @{ id = 'mapReady'; pattern = 'transition: MapTransition -> MapReady'; label = 'MapTransition -> MapReady' },
    @{ id = 'bootstrapDisarmed'; pattern = 'bootstrap disarmed'; label = 'bootstrap disarmed' },
    @{ id = 'mapReadyStatusFlush'; pattern = '\[TBG MAPREADY\] StatusFlush ok'; label = '[TBG MAPREADY] StatusFlush ok' },
    @{ id = 'tbgReady'; pattern = 'TBG READY'; label = 'TBG READY' }
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
foreach ($line in $lines) {
    if ($SinceLocal -and $line -match '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]') {
        $lineTime = [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', $null)
        if ($lineTime -lt $SinceLocal) { continue }
    }

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
    firstMissingStep = $firstMissing
    mapReadySeen = [bool]$steps.mapReady
    tbgReadySeen = [bool]$steps.tbgReady
    hotkeyTraceAtMapReady = $hotkeyTraceAtMapReady
    steps = $steps
}

if ($JsonOut) {
    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $JsonOut -Encoding UTF8
}

return [pscustomobject]$result
