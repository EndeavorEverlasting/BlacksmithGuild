# Remaining product gap impact helpers.
# Stub/contract layer only. These functions let future gameplay/product patches
# report which product gaps they improved or deliberately left untouched.

function Get-TbgRemainingProductGapCatalog {
    return @(
        [pscustomobject]@{ id = 'P1'; name = 'Time-budget doctrine documented but not fully enforced in code'; key = 'time_budget_not_enforced' },
        [pscustomobject]@{ id = 'P2'; name = 'Reboot does not yet have positive success terminal semantics'; key = 'reboot_positive_success_missing' },
        [pscustomobject]@{ id = 'P3'; name = 'ForgeVerify fast/full split is not fully productized'; key = 'forgeverify_fast_full_missing' },
        [pscustomobject]@{ id = 'P4'; name = 'Latest local evidence is not discoverable enough'; key = 'latest_evidence_not_discoverable' },
        [pscustomobject]@{ id = 'P5'; name = 'Doctrine is still ahead of enforcement'; key = 'doctrine_ahead_of_enforcement' },
        [pscustomobject]@{ id = 'P6'; name = 'Travel is proven enough to observe movement, but not yet productized as a user-safe travel feature'; key = 'travel_not_productized' },
        [pscustomobject]@{ id = 'P7'; name = 'Blacksmithing batch work is not yet a complete user-facing loop'; key = 'blacksmithing_batch_loop_missing' },
        [pscustomobject]@{ id = 'P8'; name = 'Trading batch work is not yet a complete user-facing loop'; key = 'trading_batch_loop_missing' },
        [pscustomobject]@{ id = 'P9'; name = 'Advisory surfaces are not yet unified into one operator-facing report'; key = 'operator_report_not_unified' },
        [pscustomobject]@{ id = 'P10'; name = 'Hotkey and command surface governance is incomplete'; key = 'hotkey_command_governance_missing' },
        [pscustomobject]@{ id = 'P11'; name = 'Character build automation is not yet connected to product doctrine'; key = 'character_build_doctrine_missing' },
        [pscustomobject]@{ id = 'P12'; name = 'Non-cheat doctrine needs broader mutation coverage'; key = 'non_cheat_mutation_coverage_missing' },
        [pscustomobject]@{ id = 'P13'; name = 'Save/profile safety is not yet fully formalized'; key = 'save_profile_safety_missing' },
        [pscustomobject]@{ id = 'P14'; name = 'Companion/stamina handling is not yet productized'; key = 'companion_stamina_not_productized' },
        [pscustomobject]@{ id = 'P15'; name = 'Route/advisory decisions need explicit risk policy'; key = 'route_risk_policy_missing' },
        [pscustomobject]@{ id = 'P16'; name = 'Generated docs/evidence may outpace repo navigation'; key = 'operator_docs_index_missing' }
    )
}

function New-TbgProductGapImpactNotes {
    param([object[]]$Rows = @())

    $existing = @{}
    foreach ($row in @($Rows)) {
        if ($row -and $row.id) { $existing[[string]$row.id] = $row }
    }

    return @(Get-TbgRemainingProductGapCatalog | ForEach-Object {
        if ($existing.ContainsKey([string]$_.id)) {
            $existing[[string]$_.id]
        } else {
            [pscustomobject]@{
                id = $_.id
                gap = $_.name
                key = $_.key
                status = 'not_touched_with_reason'
                impact = 'stub impact row; future product patch must provide impact or follow-up reason'
            }
        }
    })
}

function Assert-TbgProductGapImpactNotes {
    param([object[]]$Notes)

    $allowedStatuses = @('improved','covered_by_existing_contract','not_touched_with_reason','new_follow_up_required')
    $rows = @($Notes)
    $catalog = @(Get-TbgRemainingProductGapCatalog)

    foreach ($gap in $catalog) {
        $row = @($rows | Where-Object { [string]$_.id -eq [string]$gap.id }) | Select-Object -First 1
        if (-not $row) { throw "product gap impact missing row id=$($gap.id) name=$($gap.name)" }
        if ($allowedStatuses -notcontains [string]$row.status) { throw "product gap row id=$($gap.id) has invalid status '$($row.status)'" }
        if ([string]::IsNullOrWhiteSpace([string]$row.impact)) { throw "product gap row id=$($gap.id) missing impact/follow-up reason" }
    }

    return $true
}

function ConvertTo-TbgProductGapImpactMarkdown {
    param([object[]]$Notes)

    Assert-TbgProductGapImpactNotes -Notes $Notes | Out-Null
    $lines = @('| Product gap | Status | Impact / reason |','| --- | --- | --- |')
    foreach ($row in @($Notes | Sort-Object id)) {
        $lines += "| $($row.id). $($row.gap) | $($row.status) | $($row.impact) |"
    }
    return ($lines -join [Environment]::NewLine)
}

function Write-TbgProductGapImpactReport {
    param(
        [object[]]$Notes,
        [string]$Path
    )

    $markdown = ConvertTo-TbgProductGapImpactMarkdown -Notes $Notes
    if ($Path) {
        $dir = Split-Path -Parent $Path
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        Set-Content -LiteralPath $Path -Value $markdown -Encoding UTF8
    }
    return $markdown
}
