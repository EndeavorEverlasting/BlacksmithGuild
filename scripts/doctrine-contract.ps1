# Doctrine-to-contract mapping helpers.
# Stub/contract layer only. Future verifiers should use these helpers to ensure
# doctrine docs map to manifest fields and regression tests.

function Get-TbgDoctrineContractCatalog {
    return @(
        [pscustomobject]@{ id = 'D1'; doctrine = 'local iteration time budget'; docPath = 'docs/operator/local-iteration-time-budget.md'; expectedVerifier = 'time_budget_contract'; status = 'stub' },
        [pscustomobject]@{ id = 'D2'; doctrine = 'local iteration gap coverage'; docPath = 'docs/operator/local-iteration-gap-register.md'; expectedVerifier = 'gap_coverage_contract'; status = 'stub' },
        [pscustomobject]@{ id = 'D3'; doctrine = 'remaining product gap impact'; docPath = 'docs/operator/remaining-product-gap-register.md'; expectedVerifier = 'product_gap_contract'; status = 'stub' },
        [pscustomobject]@{ id = 'D4'; doctrine = 'checkpoint-based movement proof'; docPath = 'docs/operator/reboot-iteration-doctrine.md'; expectedVerifier = 'movement_proof_contract'; status = 'stub' },
        [pscustomobject]@{ id = 'D5'; doctrine = 'harness-engine wiring'; docPath = 'docs/operator/harness-engine-wiring.md'; expectedVerifier = 'harness_engine_wiring_contract'; status = 'stub' }
    )
}

function New-TbgDoctrineContractMatrix {
    param([object[]]$Rows = @())

    $existing = @{}
    foreach ($row in @($Rows)) {
        if ($row -and $row.id) { $existing[[string]$row.id] = $row }
    }

    return @(Get-TbgDoctrineContractCatalog | ForEach-Object {
        if ($existing.ContainsKey([string]$_.id)) {
            $existing[[string]$_.id]
        } else {
            [pscustomobject]@{
                id = $_.id
                doctrine = $_.doctrine
                docPath = $_.docPath
                expectedVerifier = $_.expectedVerifier
                status = 'new_follow_up_required'
                evidence = 'stub doctrine row; future verifier must prove enforcement path'
            }
        }
    })
}

function Assert-TbgDoctrineContractMatrix {
    param([object[]]$Matrix)

    $rows = @($Matrix)
    foreach ($entry in @(Get-TbgDoctrineContractCatalog)) {
        $row = @($rows | Where-Object { [string]$_.id -eq [string]$entry.id }) | Select-Object -First 1
        if (-not $row) { throw "doctrine contract missing row id=$($entry.id) doctrine=$($entry.doctrine)" }
        if ([string]::IsNullOrWhiteSpace([string]$row.status)) { throw "doctrine contract row id=$($entry.id) missing status" }
        if ([string]::IsNullOrWhiteSpace([string]$row.evidence)) { throw "doctrine contract row id=$($entry.id) missing evidence" }
    }
    return $true
}

function Write-TbgDoctrineContractReport {
    param(
        [object[]]$Matrix,
        [string]$Path
    )

    Assert-TbgDoctrineContractMatrix -Matrix $Matrix | Out-Null
    $lines = @('| Doctrine | Status | Verifier / evidence |','| --- | --- | --- |')
    foreach ($row in @($Matrix | Sort-Object id)) {
        $lines += "| $($row.id). $($row.doctrine) | $($row.status) | $($row.expectedVerifier): $($row.evidence) |"
    }
    $markdown = $lines -join [Environment]::NewLine
    if ($Path) {
        $dir = Split-Path -Parent $Path
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        Set-Content -LiteralPath $Path -Value $markdown -Encoding UTF8
    }
    return $markdown
}
