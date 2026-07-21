# Writes BlacksmithGuild_LaunchIntent.json and BlacksmithGuild_SessionIntent.json before launcher automation.
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('play', 'continue')]
    [string]$LaunchIntent,

    [Parameter(Mandatory = $true)]
    [string]$BannerlordRoot,

    [ValidateSet('human_player', 'multitasking', 'automation_script', 'ai_agent', 'ci_cd', 'unknown')]
    [string]$DrivenBy = 'automation_script',

    [string]$SessionId = $null,

    [string]$Sprint = $null,

    [string]$AgentRole = $null,

    [string]$AgentLabel = $null,

    [ValidateSet('conserve_resources', 'observe_only', 'normal', 'aggressive_proof')]
    [string]$PriorityEngineMode = 'normal',

    [switch]$AutoLoopEnabled,

    [string]$CertProfile = $null,

    [string]$CertSegment = $null,

    [string]$Branch = $null,

    [string]$CommitSha = $null,

    [string]$Comment = $null
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $BannerlordRoot)) {
    throw "Bannerlord root not found: $BannerlordRoot"
}

if (-not $SessionId) {
    $SessionId = (Get-Date).ToString('yyyyMMdd-HHmmss')
}

# Legacy intent file (backward compat)
$legacyPayload = @{
    intent    = $LaunchIntent
    writtenAt = (Get-Date).ToString('o')
} | ConvertTo-Json -Compress

# Session intent file (new, richer)
$sessionPayload = [ordered]@{
    schema             = 'tbg.session-intent.v1'
    generatedUtc       = (Get-Date).ToUniversalTime().ToString('o')
    drivenBy           = $DrivenBy
    launchIntent       = $LaunchIntent
    sessionId          = $SessionId
    sprint             = $Sprint
    agentRole          = $AgentRole
    agentLabel         = $AgentLabel
    priorityEngineMode = $PriorityEngineMode
    autoLoopEnabled    = [bool]$AutoLoopEnabled
    certProfile        = $CertProfile
    certSegment        = $CertSegment
    branch             = $Branch
    commitSha          = $CommitSha
    comment            = $Comment
}

$propsToRemove = @(
    'sprint', 'agentRole', 'agentLabel', 'certProfile', 'certSegment', 'branch', 'commitSha', 'comment'
)
foreach ($prop in $propsToRemove) {
    if ([string]::IsNullOrWhiteSpace($sessionPayload[$prop])) {
        $sessionPayload.Remove($prop)
    }
}

$sessionJson = $sessionPayload | ConvertTo-Json -Depth 5 -Compress

$intentPaths = @(
    (Join-Path $BannerlordRoot 'BlacksmithGuild_LaunchIntent.json'),
    (Join-Path $BannerlordRoot 'BlacksmithGuild_SessionIntent.json'),
    (Join-Path $env:USERPROFILE 'Documents\Mount and Blade II Bannerlord\BlacksmithGuild_LaunchIntent.json'),
    (Join-Path $env:USERPROFILE 'Documents\Mount and Blade II Bannerlord\BlacksmithGuild_SessionIntent.json')
)

foreach ($intentPath in $intentPaths) {
    $parent = Split-Path -Parent $intentPath
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }

    $isSessionFile = $intentPath -like '*SessionIntent*'
    $content = if ($isSessionFile) { $sessionJson } else { $legacyPayload }

    Set-Content -LiteralPath $intentPath -Value $content -Encoding UTF8
    $label = if ($isSessionFile) { 'session' } else { 'legacy' }
    Write-Host "Launch intent written ($label): $LaunchIntent drivenBy=$DrivenBy -> $intentPath" -ForegroundColor Cyan
}
