# Summarizes available BlacksmithGuild runtime proof artifacts without launching the game.
$ErrorActionPreference = 'Stop'

param(
    [string]$BannerlordRoot = 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord',

    [string]$OutputPath = '',

    [switch]$RequireRouteStart
)

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $latestDir = Join-Path $repoRoot 'artifacts\latest'
    New-Item -ItemType Directory -Force -Path $latestDir | Out-Null
    $OutputPath = Join-Path $latestDir 'runtime-proof.validation.json'
}

function Read-JsonOrNull {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try { return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
    catch { return $null }
}

function Get-Value {
    param(
        [object]$Object,
        [string[]]$Path,
        $Default = $null
    )

    $current = $Object
    foreach ($part in $Path) {
        if ($null -eq $current) { return $Default }
        $property = $current.PSObject.Properties[$part]
        if ($null -eq $property) { return $Default }
        $current = $property.Value
    }

    if ($null -eq $current) { return $Default }
    return $current
}

function To-Bool {
    param($Value)
    if ($Value -is [bool]) { return $Value }
    if ($null -eq $Value) { return $false }
    try { return [System.Convert]::ToBoolean($Value) }
    catch { return $false }
}

$statusPath = Join-Path $BannerlordRoot 'BlacksmithGuild_Status.json'
$routeCertPath = Join-Path $BannerlordRoot 'BlacksmithGuild_MapTradeRouteCert.json'
$legacyCertPath = Join-Path $BannerlordRoot 'BlacksmithGuild_MapTradeCert.json'
$ackPath = Join-Path $BannerlordRoot 'BlacksmithGuild_CommandAck.json'
$phaseLogPath = Join-Path $BannerlordRoot 'BlacksmithGuild_Phase1.log'

$status = Read-JsonOrNull -Path $statusPath
$routeCert = Read-JsonOrNull -Path $routeCertPath
$legacyCert = Read-JsonOrNull -Path $legacyCertPath
$ack = Read-JsonOrNull -Path $ackPath

$cert = if ($null -ne $routeCert) { $routeCert } else { $legacyCert }
$certPath = if ($null -ne $routeCert) { $routeCertPath } elseif ($null -ne $legacyCert) { $legacyCertPath } else { $null }

$runtime = [ordered]@{
    statusFound = $null -ne $status
    campaignReady = $false
    mapStateActive = $false
    safeToExecuteTravel = $false
    nextPlannedBranch = $null
    targetSettlement = $null
}

if ($null -ne $status) {
    $runtime.campaignReady = To-Bool (Get-Value $status @('campaignReady') $false)
    $runtime.mapStateActive = To-Bool (Get-Value $status @('session','mapStateActive') (Get-Value $status @('stateMachine','isMapStateActive') $false))
    $runtime.safeToExecuteTravel = To-Bool (Get-Value $status @('stateMachine','safeToExecuteTravel') $false)
    $runtime.nextPlannedBranch = Get-Value $status @('recursiveBranchState','nextPlannedBranch') $null
    $runtime.targetSettlement = Get-Value $status @('recursiveBranchState','targetSettlement') $null
}

$route = [ordered]@{
    certFound = $null -ne $cert
    certPath = $certPath
    destinationSettlement = $null
    travelCommandIssued = $false
    routeStarted = $false
    blockedReason = $null
}

if ($null -ne $cert) {
    $route.destinationSettlement = Get-Value $cert @('destinationSettlement') (Get-Value $cert @('mission','targetSettlementName') $null)
    $route.travelCommandIssued = To-Bool (Get-Value $cert @('travelCommandIssued') $false)
    $route.routeStarted = To-Bool (Get-Value $cert @('routeStarted') $route.travelCommandIssued)
    $route.blockedReason = Get-Value $cert @('blockedReason') $null
}

$files = [ordered]@{
    status = $statusPath
    routeCert = $routeCertPath
    legacyRouteCert = $legacyCertPath
    commandAck = $ackPath
    phaseLog = $phaseLogPath
    statusExists = Test-Path -LiteralPath $statusPath
    routeCertExists = Test-Path -LiteralPath $routeCertPath
    legacyRouteCertExists = Test-Path -LiteralPath $legacyCertPath
    commandAckExists = Test-Path -LiteralPath $ackPath
    phaseLogExists = Test-Path -LiteralPath $phaseLogPath
}

$allowedClaims = New-Object System.Collections.Generic.List[string]
$forbiddenClaims = New-Object System.Collections.Generic.List[string]
$blockers = New-Object System.Collections.Generic.List[string]

if ($runtime.statusFound) { $allowedClaims.Add('runtime status file was found') | Out-Null } else { $blockers.Add('status file missing') | Out-Null }
if ($route.certFound) { $allowedClaims.Add('route cert file was found') | Out-Null } else { $blockers.Add('route cert missing') | Out-Null }
if ($route.travelCommandIssued) { $allowedClaims.Add('travel command was reported as issued') | Out-Null }
if ($route.routeStarted) { $allowedClaims.Add('route was reported as started') | Out-Null }

$forbiddenClaims.Add('route completed') | Out-Null
$forbiddenClaims.Add('arrival completed') | Out-Null
$forbiddenClaims.Add('trade completed') | Out-Null
$forbiddenClaims.Add('activity ledger is listening in-game') | Out-Null

$pass = $runtime.statusFound -and $runtime.campaignReady -and $runtime.mapStateActive
if ($RequireRouteStart) {
    $pass = $pass -and $runtime.safeToExecuteTravel -and ($runtime.nextPlannedBranch -eq 'travel') -and $route.certFound -and $route.travelCommandIssued -and $route.routeStarted
}

$verdict = if ($pass) { 'PASS' } elseif ($blockers.Count -gt 0) { 'BLOCKED' } else { 'FAIL' }

$result = [ordered]@{
    schema = 'tbg.runtimeProofValidation.v1'
    generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    verdict = $verdict
    requireRouteStart = [bool]$RequireRouteStart
    bannerlordRoot = $BannerlordRoot
    files = $files
    runtime = $runtime
    route = $route
    commandAckFound = $null -ne $ack
    allowedClaims = @($allowedClaims)
    forbiddenClaims = @($forbiddenClaims)
    blockers = @($blockers)
    nextPatchHint = if ($verdict -eq 'PASS') { 'Runtime proof summary met requested gate. Continue with the next bounded proof.' } else { 'Patch the first missing or blocked proof artifact before claiming runtime behavior.' }
}

$result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host "Runtime proof validation verdict: $verdict"
Write-Host "Result: $OutputPath"

if ($verdict -eq 'PASS') { exit 0 }
if ($verdict -eq 'BLOCKED') { exit 2 }
exit 1
