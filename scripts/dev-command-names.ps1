# Keep in sync with DevCommandRegistry.cs (C#).
function Get-DevCommandNames {
    return @(
        'ListScenarios',
        'ShowForgeStatus',
        'AdvanceOneDay',
        'ToggleFastForward',
        'RichPlayerEconomyTest',
        'RichSmithingProgressionTest',
        'AddSmithingXp',
        'AddSmithingFocus',
        'AddEnduranceAttribute',
        'TreasurySnapshotNow',
        'RankForgeCandidates',
        'SetForgeCandidateSourceStub',
        'SetForgeCandidateSourceReal',
        'ShowForgeCandidateSource',
        'SetForgeDoctrineProfitForge',
        'SetForgeDoctrineRareMetalConservation',
        'SetForgeDoctrineCashCrisis',
        'ShowForgeDoctrine',
        'ProbeForgeRecipes',
        'ProbeSmithingAudit',
        'MarketSnapshotNow',
        'ApplyAutoCharacterBuild',
        'ShowAutoCharacterBuildProfiles',
        'ShowAutoCharacterBuildProfile',
        'SetAutoCharacterBuildForgeQuartermasterWarlord',
        'SetAutoCharacterBuildSmithEconomist',
        'SetAutoCharacterBuildKingdomFounder',
        'SetAutoCharacterBuildStewardSurgeonEngineer',
        'SetAutoCharacterBuildWarCaptain',
        'SetAutoCharacterBuildLightTouchVanillaPlus',
        'SetAutoCharacterBuildShadowTrader'
    )
}

function Test-Phase1TbgReady {
    param(
        [Parameter(Mandatory = $true)][string]$BannerlordRoot
    )

    $candidates = @(
        (Join-Path $BannerlordRoot 'BlacksmithGuild_Phase1.log'),
        (Join-Path $env:USERPROFILE 'Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Phase1.log')
    )

    foreach ($logPath in $candidates) {
        if (-not (Test-Path -LiteralPath $logPath)) {
            continue
        }

        $tail = Get-Content -LiteralPath $logPath -Tail 60 -ErrorAction SilentlyContinue
        if ($tail -match 'TBG READY') {
            return $true
        }
    }

    return $false
}
