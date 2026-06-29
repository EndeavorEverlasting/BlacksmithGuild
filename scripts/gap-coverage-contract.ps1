# Local iteration gap coverage contract helpers.
# Stub/contract layer only. Future patches should wire these into final reports,
# verifiers, and validation summaries.

function Get-TbgLocalIterationGapCatalog {
    return @(
        [pscustomobject]@{ id = 1; name = 'Command ACK treated as gameplay proof'; key = 'command_ack_gameplay_proof' },
        [pscustomobject]@{ id = 2; name = 'Single weak metric treated as final verdict'; key = 'single_weak_metric_final_verdict' },
        [pscustomobject]@{ id = 3; name = 'Ambiguity handled by waiting instead of classification'; key = 'ambiguity_waiting_not_classification' },
        [pscustomobject]@{ id = 4; name = 'Machine-readable evidence missing or incomplete'; key = 'machine_readable_evidence_missing' },
        [pscustomobject]@{ id = 5; name = 'Long-wait permission too broad'; key = 'long_wait_permission_too_broad' },
        [pscustomobject]@{ id = 6; name = 'Foreground/operator interruption conflated with runtime failure'; key = 'foreground_operator_conflated_runtime_failure' },
        [pscustomobject]@{ id = 7; name = 'Success semantics are too negative'; key = 'negative_success_semantics' },
        [pscustomobject]@{ id = 8; name = 'Validation UX still allows command necklaces'; key = 'validation_command_necklaces' },
        [pscustomobject]@{ id = 9; name = 'Local evidence exists but is not discoverable enough'; key = 'local_evidence_not_discoverable' },
        [pscustomobject]@{ id = 10; name = 'Docs not converted into enforceable contracts'; key = 'docs_not_enforceable_contracts' }
    )
}

function New-TbgGapCoverageMatrix {
    param(
        [object[]]$Rows = @()
    )

    $existing = @{}
    foreach ($row in @($Rows)) {
        if ($row -and $row.id) { $existing[[int]$row.id] = $row }
    }

    return @(Get-TbgLocalIterationGapCatalog | ForEach-Object {
        if ($existing.ContainsKey([int]$_.id)) {
            $existing[[int]$_.id]
        } else {
            [pscustomobject]@{
                id = $_.id
                gap = $_.name
                key = $_.key
                status = 'new_follow_up_required'
                evidence = 'stub coverage row; future patch must provide evidence/test/reason'
            }
        }
    })
}

function Assert-TbgGapCoverageMatrix {
    param([object[]]$Matrix)

    $allowedStatuses = @('patched','covered_by_existing_contract','not_touched_with_reason','new_follow_up_required')
    $rows = @($Matrix)
    $catalog = @(Get-TbgLocalIterationGapCatalog)

    foreach ($gap in $catalog) {
        $row = @($rows | Where-Object { [int]$_.id -eq [int]$gap.id }) | Select-Object -First 1
        if (-not $row) { throw "gap coverage missing row id=$($gap.id) name=$($gap.name)" }
        if ($allowedStatuses -notcontains [string]$row.status) { throw "gap coverage row id=$($gap.id) has invalid status '$($row.status)'" }
        if ([string]::IsNullOrWhiteSpace([string]$row.evidence)) { throw "gap coverage row id=$($gap.id) missing evidence/test/reason" }
    }

    return $true
}

function ConvertTo-TbgGapCoverageMarkdown {
    param([object[]]$Matrix)

    Assert-TbgGapCoverageMatrix -Matrix $Matrix | Out-Null
    $lines = @('| Gap | Status | Evidence / test / reason |','| --- | --- | --- |')
    foreach ($row in @($Matrix | Sort-Object id)) {
        $lines += "| $($row.id). $($row.gap) | $($row.status) | $($row.evidence) |"
    }
    return ($lines -join [Environment]::NewLine)
}

function Write-TbgGapCoverageReport {
    param(
        [object[]]$Matrix,
        [string]$Path
    )

    $markdown = ConvertTo-TbgGapCoverageMarkdown -Matrix $Matrix
    if ($Path) {
        $dir = Split-Path -Parent $Path
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        Set-Content -LiteralPath $Path -Value $markdown -Encoding UTF8
    }
    return $markdown
}
