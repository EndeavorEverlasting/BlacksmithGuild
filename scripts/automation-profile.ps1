# Shared automation profile state for Forge/Reboot/assistive runner surfaces.
$script:TbgAutomationProfiles = @('default', 'economic_loop')

function Get-TbgAutomationProfileJsonPath {
    param([string]$BannerlordRoot)
    $fileName = 'BlacksmithGuild_AutomationProfile.json'
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

function Get-TbgAutomationProfileWritePaths {
    param([string]$BannerlordRoot)
    $fileName = 'BlacksmithGuild_AutomationProfile.json'
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

function Read-TbgAutomationProfile {
    param([string]$BannerlordRoot)
    $path = Get-TbgAutomationProfileJsonPath -BannerlordRoot $BannerlordRoot
    $result = [ordered]@{
        path = $path
        parseOk = $false
        profile = 'default'
        profileSupported = $false
        requestedBy = $null
        reason = $null
        updatedAtUtc = $null
    }
    if (-not (Test-Path -LiteralPath $path)) { return [pscustomobject]$result }
    try {
        $json = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $profile = [string]$json.profile
        $result.parseOk = $true
        $result.profile = if (-not [string]::IsNullOrWhiteSpace($profile)) { $profile } else { 'default' }
        $result.profileSupported = ($script:TbgAutomationProfiles -contains $result.profile)
        $result.requestedBy = if ($json.requestedBy) { [string]$json.requestedBy } else { $null }
        $result.reason = if ($json.reason) { [string]$json.reason } else { $null }
        $result.updatedAtUtc = if ($json.updatedAtUtc) { [string]$json.updatedAtUtc } else { $null }
    } catch { }
    return [pscustomobject]$result
}

function Write-TbgAutomationProfile {
    param(
        [string]$BannerlordRoot,
        [Parameter(Mandatory = $true)]
        [ValidateSet('default', 'economic_loop')]
        [string]$Profile,
        [string]$RequestedBy = 'ForgeProfile.cmd',
        [string]$Reason = 'operator_requested'
    )
    $payload = [ordered]@{
        profile = $Profile
        requestedBy = $RequestedBy
        reason = $Reason
        updatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    }
    $json = $payload | ConvertTo-Json -Depth 4
    $written = $null
    foreach ($path in @(Get-TbgAutomationProfileWritePaths -BannerlordRoot $BannerlordRoot)) {
        $dir = Split-Path -Parent $path
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        Set-Content -LiteralPath $path -Value $json -Encoding UTF8
        $written = $path
    }
    return $written
}

function Resolve-TbgAutomationProfile {
    param(
        [string]$BannerlordRoot,
        [string]$ExplicitProfile = $null,
        [string]$RequestedBy = 'resolver'
    )
    if (-not [string]::IsNullOrWhiteSpace($ExplicitProfile)) {
        if ($script:TbgAutomationProfiles -notcontains $ExplicitProfile) { throw "Unsupported automation profile: $ExplicitProfile" }
        return [pscustomobject][ordered]@{
            profile = $ExplicitProfile
            source = 'explicit_CertProfile'
            path = $null
            requestedBy = $RequestedBy
            reason = 'explicit parameter wins'
        }
    }
    $state = Read-TbgAutomationProfile -BannerlordRoot $BannerlordRoot
    if ($state.parseOk -and $state.profileSupported) {
        return [pscustomobject][ordered]@{
            profile = [string]$state.profile
            source = 'shared_json'
            path = $state.path
            requestedBy = $state.requestedBy
            reason = $state.reason
        }
    }
    return [pscustomobject][ordered]@{
        profile = 'default'
        source = 'safe_default'
        path = $state.path
        requestedBy = $RequestedBy
        reason = if ($state.parseOk) { "unsupported profile '$($state.profile)'" } else { 'profile state missing or unreadable' }
    }
}
