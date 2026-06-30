# Shared route opportunity mode state for direct travel versus opt-in exploration.
$script:TbgRouteOpportunityModes = @('direct', 'exploring')

function Get-TbgRouteOpportunityModeJsonPath {
    param([string]$BannerlordRoot)
    $fileName = 'BlacksmithGuild_RouteOpportunityMode.json'
    if (-not (Get-Command Get-AssistiveArtifactCandidates -ErrorAction SilentlyContinue)) {
        $pathsScript = Join-Path $PSScriptRoot 'bannerlord-paths.ps1'
        if (Test-Path -LiteralPath $pathsScript) { . $pathsScript }
    }
    if (Get-Command Get-AssistiveArtifactCandidates -ErrorAction SilentlyContinue) {
        $preferred = Join-Path (Get-BannerlordDocsRoot) $fileName
        if ([string]::IsNullOrWhiteSpace($BannerlordRoot)) { return $preferred }
        return Find-NewestExistingPath -Candidates (Get-AssistiveArtifactCandidates -BannerlordRoot $BannerlordRoot -FileName $fileName) `
            -Preferred $preferred
    }
    return Join-Path (Split-Path -Parent $PSScriptRoot) $fileName
}

function Get-TbgRouteOpportunityModeWritePaths {
    param([string]$BannerlordRoot)
    $fileName = 'BlacksmithGuild_RouteOpportunityMode.json'
    if (-not (Get-Command Get-AssistiveArtifactCandidates -ErrorAction SilentlyContinue)) {
        $pathsScript = Join-Path $PSScriptRoot 'bannerlord-paths.ps1'
        if (Test-Path -LiteralPath $pathsScript) { . $pathsScript }
    }
    if (Get-Command Get-AssistiveArtifactCandidates -ErrorAction SilentlyContinue) {
        if ([string]::IsNullOrWhiteSpace($BannerlordRoot)) { return @((Join-Path (Get-BannerlordDocsRoot) $fileName)) }
        return @(Get-AssistiveArtifactCandidates -BannerlordRoot $BannerlordRoot -FileName $fileName)
    }
    return @((Join-Path (Split-Path -Parent $PSScriptRoot) $fileName))
}

function New-TbgRouteOpportunityModePayload {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('direct', 'exploring')][string]$Mode,
        [string]$RequestedBy = 'ForgeRouteMode.cmd',
        [string]$Reason = 'operator_requested',
        [string]$Origin = $null,
        [string]$Destination = $null
    )
    $exploring = ($Mode -eq 'exploring')
    return [ordered]@{
        mode = $Mode
        requestedBy = $RequestedBy
        reason = $Reason
        origin = $Origin
        destination = $Destination
        allowVillageStops = [bool]$exploring
        allowRecruitmentStops = [bool]$exploring
        allowHorseStops = [bool]$exploring
        allowGoodsStops = [bool]$exploring
        updatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    }
}

function Read-TbgRouteOpportunityMode {
    param([string]$BannerlordRoot)
    $path = Get-TbgRouteOpportunityModeJsonPath -BannerlordRoot $BannerlordRoot
    $result = [ordered]@{
        path = $path
        parseOk = $false
        mode = 'direct'
        modeSupported = $false
        requestedBy = $null
        reason = $null
        origin = $null
        destination = $null
        allowVillageStops = $false
        allowRecruitmentStops = $false
        allowHorseStops = $false
        allowGoodsStops = $false
        updatedAtUtc = $null
    }
    if (-not (Test-Path -LiteralPath $path)) { return [pscustomobject]$result }
    try {
        $json = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $mode = [string]$json.mode
        $result.parseOk = $true
        $result.mode = if (-not [string]::IsNullOrWhiteSpace($mode)) { $mode } else { 'direct' }
        $result.modeSupported = ($script:TbgRouteOpportunityModes -contains $result.mode)
        $result.requestedBy = if ($json.requestedBy) { [string]$json.requestedBy } else { $null }
        $result.reason = if ($json.reason) { [string]$json.reason } else { $null }
        $result.origin = if ($json.origin) { [string]$json.origin } else { $null }
        $result.destination = if ($json.destination) { [string]$json.destination } else { $null }
        $result.allowVillageStops = ($json.allowVillageStops -eq $true)
        $result.allowRecruitmentStops = ($json.allowRecruitmentStops -eq $true)
        $result.allowHorseStops = ($json.allowHorseStops -eq $true)
        $result.allowGoodsStops = ($json.allowGoodsStops -eq $true)
        $result.updatedAtUtc = if ($json.updatedAtUtc) { [string]$json.updatedAtUtc } else { $null }
    } catch { }
    return [pscustomobject]$result
}

function Write-TbgRouteOpportunityMode {
    param(
        [string]$BannerlordRoot,
        [Parameter(Mandatory = $true)]
        [ValidateSet('direct', 'exploring')]
        [string]$Mode,
        [string]$RequestedBy = 'ForgeRouteMode.cmd',
        [string]$Reason = 'operator_requested',
        [string]$Origin = $null,
        [string]$Destination = $null
    )
    $payload = New-TbgRouteOpportunityModePayload -Mode $Mode -RequestedBy $RequestedBy -Reason $Reason -Origin $Origin -Destination $Destination
    $json = $payload | ConvertTo-Json -Depth 5
    $written = $null
    foreach ($path in @(Get-TbgRouteOpportunityModeWritePaths -BannerlordRoot $BannerlordRoot)) {
        $dir = Split-Path -Parent $path
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        Set-Content -LiteralPath $path -Value $json -Encoding UTF8
        $written = $path
    }
    return $written
}

function Resolve-TbgRouteOpportunityMode {
    param(
        [string]$BannerlordRoot,
        [string]$ExplicitMode = $null,
        [string]$RequestedBy = 'resolver'
    )
    if (-not [string]::IsNullOrWhiteSpace($ExplicitMode)) {
        if ($script:TbgRouteOpportunityModes -notcontains $ExplicitMode) { throw "Unsupported route opportunity mode: $ExplicitMode" }
        return [pscustomobject][ordered]@{
            mode = $ExplicitMode
            source = 'explicit_route_mode'
            path = $null
            allowVillageStops = [bool]($ExplicitMode -eq 'exploring')
            requestedBy = $RequestedBy
            reason = 'explicit parameter wins'
        }
    }
    $state = Read-TbgRouteOpportunityMode -BannerlordRoot $BannerlordRoot
    if ($state.parseOk -and $state.modeSupported) {
        return [pscustomobject][ordered]@{
            mode = [string]$state.mode
            source = 'shared_json'
            path = $state.path
            allowVillageStops = [bool]$state.allowVillageStops
            requestedBy = $state.requestedBy
            reason = $state.reason
        }
    }
    return [pscustomobject][ordered]@{
        mode = 'direct'
        source = 'safe_default'
        path = $state.path
        allowVillageStops = $false
        requestedBy = $RequestedBy
        reason = if ($state.parseOk) { "unsupported mode '$($state.mode)'" } else { 'route mode state missing or unreadable' }
    }
}
