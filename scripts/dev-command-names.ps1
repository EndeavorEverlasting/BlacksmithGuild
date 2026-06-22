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
        'ProbeSmithingRefineApi',
        'RunSmithingAdvisoryNow',
        'RunSmithingSafeActionNow',
        'RunSmithingRestPlanNow',
        'RunBlacksmithAutomationNow',
        'RunGuildLoopNow',
        'ShowCharacterDoctrine',
        'MarketSnapshotNow',
        'AnalyzeHorseMarket',
        'ShowHorseMarketIntel',
        'RankHorseMarketActions',
        'ApplyAutoCharacterBuild',
        'ShowAutoCharacterBuildProfiles',
        'ShowAutoCharacterBuildProfile',
        'SetAutoCharacterBuildForgeQuartermasterWarlord',
        'SetAutoCharacterBuildSmithEconomist',
        'SetAutoCharacterBuildKingdomFounder',
        'SetAutoCharacterBuildStewardSurgeonEngineer',
        'SetAutoCharacterBuildWarCaptain',
        'SetAutoCharacterBuildLightTouchVanillaPlus',
        'SetAutoCharacterBuildShadowTrader',
        'BuildCharacterChoiceCatalogNow',
        'GenerateCharacterBuildCandidatesNow',
        'SelectCharacterBuildBestNow',
        'RunCharacterVisibleReplayNow',
        'DumpCharacterBuildSnapshotNow',
        'ShowAutoTravelChoices',
        'AutoTravelToRecommended',
        'AutoTravelChoice1',
        'AutoTravelChoice2',
        'AutoTravelChoice3',
        'AutoTravelChoice4',
        'AutoTravelChoice5',
        'AnalyzeTavernHeroes',
        'ShowTavernHeroIntel',
        'ProbeTavernRecruitmentApi',
        'NavigateToSettlementTavernNow',
        'RecruitTavernHeroVisibleNow',
        'SetTavernHeroDoctrineSmithingCrew',
        'SetTavernHeroDoctrineScoutQuartermaster',
        'SetTavernHeroDoctrineCombatEscort'
        # Dynamic prefix also accepted: AutoTravel:<town-or-village-name>
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
