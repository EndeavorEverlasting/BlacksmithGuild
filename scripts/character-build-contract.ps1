# Character build preset contract helpers.
# Stub/contract layer only. Future character creation automation should emit
# decision evidence matching these preset contracts.

function Get-TbgCharacterBuildPresetCatalog {
    return @(
        [pscustomobject]@{
            presetId = 'tbg_aserai_trade_smith'
            displayName = 'TBG Aserai Trade-Smith'
            preferredCultureId = 'aserai'
            fallbackCultures = @('khuzait')
            primarySkills = @('Trade','Smithing','Riding')
            secondarySkills = @('Steward','Charm','Leadership')
            doctrine = 'use existing game mechanics; record costs/drawbacks; do not grant free XP/resources'
        }
    )
}

function Get-TbgCharacterBuildPreset {
    param([string]$PresetId = 'tbg_aserai_trade_smith')
    return @(Get-TbgCharacterBuildPresetCatalog | Where-Object { $_.presetId -eq $PresetId }) | Select-Object -First 1
}

function New-TbgCharacterBuildDecisionEvidence {
    param(
        [string]$PresetId = 'tbg_aserai_trade_smith',
        [string]$CultureId = $null,
        [object[]]$Decisions = @(),
        [object]$ResultingSkills = $null,
        [string[]]$CostsOrDrawbacks = @()
    )

    return [pscustomobject]@{
        schemaVersion = 1
        preset = Get-TbgCharacterBuildPreset -PresetId $PresetId
        cultureId = $CultureId
        decisions = @($Decisions)
        resultingSkills = $ResultingSkills
        costsOrDrawbacks = @($CostsOrDrawbacks)
        generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    }
}

function Test-TbgCharacterBuildMatchesPreset {
    param([object]$Evidence)

    if (-not $Evidence -or -not $Evidence.preset) { return $false }
    if ([string]::IsNullOrWhiteSpace([string]$Evidence.cultureId)) { return $false }
    $allowedCultures = @($Evidence.preset.preferredCultureId) + @($Evidence.preset.fallbackCultures)
    if ($allowedCultures -notcontains [string]$Evidence.cultureId) { return $false }
    if (-not $Evidence.decisions -or @($Evidence.decisions).Count -eq 0) { return $false }
    return $true
}

function Assert-TbgCharacterBuildMatchesPreset {
    param([object]$Evidence)

    if (-not (Test-TbgCharacterBuildMatchesPreset -Evidence $Evidence)) {
        throw 'character build evidence does not match preset or lacks decision evidence'
    }
    return $true
}
