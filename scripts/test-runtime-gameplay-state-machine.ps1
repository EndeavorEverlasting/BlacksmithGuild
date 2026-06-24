# Offline regression: runtime gameplay state machine contract mirrors C# classifier rules.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

function Test-ContainsAny {
    param([string]$Haystack, [string[]]$Needles)
    if ([string]::IsNullOrWhiteSpace($Haystack)) { return $false }
    foreach ($needle in $Needles) {
        if ($Haystack.IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true }
    }
    return $false
}

function Get-GameplaySurfaceFromInputs {
    param($StateInput)
    $menuLocation = @($StateInput.MenuId, $StateInput.LocationId) -join '|'
    $activeState = $StateInput.ActiveStateName

    if ($StateInput.IsEscapeMenu -or (Test-ContainsAny $menuLocation @('escape'))) { return 'escape_menu' }
    if ($activeState -eq 'MainMenuState') {
        if (Test-ContainsAny $menuLocation @('multiplayer')) { return 'multiplayer' }
        return 'main_menu'
    }
    if ($activeState -eq 'GameLoadingState' -or -not $StateInput.IsCampaignLoaded -or -not $StateInput.IsMainHeroReady) { return 'loading' }
    if (Test-ContainsAny $activeState @('multiplayer')) { return 'multiplayer' }
    if ($StateInput.IsConversation) { return 'conversation' }
    if ($StateInput.IsTournament -or (Test-ContainsAny $menuLocation @('tournament'))) { return 'tournament' }
    if ($StateInput.IsBattle) { return 'battle' }
    if ($StateInput.IsSmithing -or (Test-ContainsAny $menuLocation @('smith','smithy','craft','forge'))) { return 'blacksmithing' }
    if ($StateInput.IsTrading -or (Test-ContainsAny $menuLocation @('trade','market','shop','merchant'))) { return 'trading' }
    if (Test-ContainsAny $menuLocation @('inventory','stash')) { return 'inventory' }
    if (Test-ContainsAny $menuLocation @('party')) { return 'party' }
    if (Test-ContainsAny $menuLocation @('character','hero')) { return 'character' }
    if (Test-ContainsAny $menuLocation @('kingdom')) { return 'kingdom' }
    if (Test-ContainsAny $menuLocation @('clan')) { return 'clan' }
    if (Test-ContainsAny $menuLocation @('arena')) { return 'arena' }
    if (Test-ContainsAny $menuLocation @('hideout')) { return 'hideout' }
    if ($StateInput.IsMissionActive) { return 'unknown' }
    if ($StateInput.IsMapStateActive -and $StateInput.IsMapMenuOpen) { return 'settlement_menu' }
    if ($StateInput.IsSettlementInteriorReady) {
        if (Test-ContainsAny $menuLocation @('center','town','city')) { return 'settlement_city' }
        return 'settlement_interior'
    }
    if ($StateInput.IsMapStateActive -and -not $StateInput.IsMapMenuOpen) { return 'campaign_map' }
    return 'unknown'
}

function Get-MissionKindFromInputs {
    param($StateInput, [string]$Surface)
    if (-not $StateInput.IsMissionActive -and $Surface -notin @('battle','tournament','conversation','arena','hideout')) { return $null }
    if ($StateInput.IsBattle -or $Surface -eq 'battle') { return 'mission_active:battle' }
    if ($StateInput.IsTournament -or $Surface -eq 'tournament') { return 'mission_active:tournament' }
    if ($StateInput.IsConversation -or $Surface -eq 'conversation') { return 'mission_active:conversation' }
    if ($Surface -eq 'arena') { return 'mission_active:arena' }
    if ($Surface -eq 'hideout') { return 'mission_active:hideout' }
    return 'mission_active:unknown'
}

function Get-SafetyFromSurface {
    param([string]$Surface, [string]$MissionKind, [bool]$IsMissionActive)
    $travel = $Surface -in @('settlement_menu','campaign_map') -and -not $IsMissionActive -and [string]::IsNullOrEmpty($MissionKind)
    $smith = $Surface -eq 'blacksmithing'
    $trade = $Surface -eq 'trading'
    return [ordered]@{
        safeToExecuteTravel   = $travel
        safeToExecuteSmithing = $smith
        safeToExecuteTrade    = $trade
    }
}

function New-GameplayInput {
    param(
        [string]$ActiveStateName = 'MapState',
        [bool]$IsCampaignLoaded = $true,
        [bool]$IsMainHeroReady = $true,
        [bool]$IsMapStateActive = $true,
        [bool]$IsMapMenuOpen = $false,
        [bool]$IsSettlementInteriorReady = $false,
        [bool]$IsMissionActive = $false,
        [string]$MenuId = $null,
        [string]$LocationId = $null,
        [bool]$IsConversation = $false,
        [bool]$IsTournament = $false,
        [bool]$IsBattle = $false,
        [bool]$IsSmithing = $false,
        [bool]$IsTrading = $false,
        [bool]$IsEscapeMenu = $false
    )
    return [pscustomobject]@{
        ActiveStateName = $ActiveStateName
        IsCampaignLoaded = $IsCampaignLoaded
        IsMainHeroReady = $IsMainHeroReady
        IsMapStateActive = $IsMapStateActive
        IsMapMenuOpen = $IsMapMenuOpen
        IsSettlementInteriorReady = $IsSettlementInteriorReady
        IsMissionActive = $IsMissionActive
        MenuId = $MenuId
        LocationId = $LocationId
        IsConversation = $IsConversation
        IsTournament = $IsTournament
        IsBattle = $IsBattle
        IsSmithing = $IsSmithing
        IsTrading = $IsTrading
        IsEscapeMenu = $IsEscapeMenu
    }
}

# MainMenuState -> main_menu
$mainMenu = New-GameplayInput -ActiveStateName 'MainMenuState' -IsCampaignLoaded $false -IsMainHeroReady $false -IsMapStateActive $false
if ((Get-GameplaySurfaceFromInputs $mainMenu) -ne 'main_menu') { throw 'MainMenuState must map to main_menu' }

# GameLoadingState -> loading
$loading = New-GameplayInput -ActiveStateName 'GameLoadingState' -IsMainHeroReady $false
if ((Get-GameplaySurfaceFromInputs $loading) -ne 'loading') { throw 'GameLoadingState must map to loading' }

# MapState + menu + settlement -> settlement_menu
$townMenu = New-GameplayInput -IsMapMenuOpen $true -MenuId 'town'
if ((Get-GameplaySurfaceFromInputs $townMenu) -ne 'settlement_menu') { throw 'MapState+menu must map to settlement_menu' }

# MapState + no menu -> campaign_map
$map = New-GameplayInput
if ((Get-GameplaySurfaceFromInputs $map) -ne 'campaign_map') { throw 'MapState without menu must map to campaign_map' }

# mission conversation
$conv = New-GameplayInput -IsMissionActive $true -IsConversation $true -IsMapStateActive $false
$sConv = Get-GameplaySurfaceFromInputs $conv
if ($sConv -ne 'conversation') { throw "mission conversation expected conversation got $sConv" }
if ((Get-MissionKindFromInputs $conv $sConv) -ne 'mission_active:conversation') { throw 'conversation mission kind mismatch' }

# mission tournament
$tour = New-GameplayInput -IsMissionActive $true -IsTournament $true -IsMapStateActive $false
$sTour = Get-GameplaySurfaceFromInputs $tour
if ($sTour -ne 'tournament') { throw 'tournament surface mismatch' }

# mission battle
$battle = New-GameplayInput -IsMissionActive $true -IsBattle $true -IsMapStateActive $false
if ((Get-GameplaySurfaceFromInputs $battle) -ne 'battle') { throw 'battle surface mismatch' }

# smithy menu
$smith = New-GameplayInput -IsMapMenuOpen $true -MenuId 'town_smithy' -LocationId 'smithy'
if ((Get-GameplaySurfaceFromInputs $smith) -ne 'blacksmithing') { throw 'smithy must map to blacksmithing' }

# trade menu
$trade = New-GameplayInput -IsMapMenuOpen $true -MenuId 'town_market' -LocationId 'market'
if ((Get-GameplaySurfaceFromInputs $trade) -ne 'trading') { throw 'market must map to trading' }

# multiplayer
$mp = New-GameplayInput -ActiveStateName 'MainMenuState' -IsCampaignLoaded $false -MenuId 'multiplayer_menu' -IsMapStateActive $false
if ((Get-GameplaySurfaceFromInputs $mp) -ne 'multiplayer') { throw 'multiplayer menu mismatch' }

# unknown state
$unknown = New-GameplayInput -ActiveStateName 'SomeWeirdState' -IsMapStateActive $false
$sUnknown = Get-GameplaySurfaceFromInputs $unknown
if ($sUnknown -ne 'unknown') { throw 'unknown active state must map to unknown' }
$safetyUnknown = Get-SafetyFromSurface $sUnknown $null $false
if ($safetyUnknown.safeToExecuteTravel) { throw 'unknown must block travel' }

# blacksmithing blocks travel but allows smithing
$safetySmith = Get-SafetyFromSurface 'blacksmithing' $null $false
if ($safetySmith.safeToExecuteTravel -or -not $safetySmith.safeToExecuteSmithing) { throw 'blacksmithing safety mismatch' }

# trading blocks travel but allows trade
$safetyTrade = Get-SafetyFromSurface 'trading' $null $false
if ($safetyTrade.safeToExecuteTravel -or -not $safetyTrade.safeToExecuteTrade) { throw 'trading safety mismatch' }

# command lifecycle contract fields exist in runtime lifecycle writer path
$forgeStatusCs = Get-Content -LiteralPath (Join-Path $repoRoot 'src\BlacksmithGuild\ForgeStatus.cs') -Raw
foreach ($needle in @('AppendStateMachineBlock', 'stateMachine', 'RuntimeLifecycleWriter.AppendStateMachine')) {
    if ($forgeStatusCs -notmatch [regex]::Escape($needle)) { throw "ForgeStatus.cs missing lifecycle needle: $needle" }
}

$runtimeWriter = Get-Content -LiteralPath (Join-Path $repoRoot 'src\BlacksmithGuild\DevTools\RuntimeLifecycleWriter.cs') -Raw
foreach ($needle in @('lastCommandStartedAtUtc', 'lastCommandFinishedAtUtc', 'gracefulShutdownObserved', 'BlacksmithGuild_RuntimeLifecycle.json')) {
    if ($runtimeWriter -notmatch [regex]::Escape($needle)) { throw "RuntimeLifecycleWriter missing: $needle" }
}

Write-Host 'PASS offline runtime gameplay state machine regression'
