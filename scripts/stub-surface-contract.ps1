# Stub surface status contract helpers.
# Purpose: make intentional contract stubs machine-readable so Reboot/iteration
# JSON can distinguish a planned stub from a broken or missing implementation.

function Get-TbgStubSurfaceCatalog {
    return @(
        [pscustomobject]@{ key = 'time_budget_contract'; path = 'scripts/time-budget-contract.ps1'; status = 'stub'; kind = 'harness_contract'; blocksProductProof = $false; reason = 'contract helpers exist; enforcement wiring is follow-up work' },
        [pscustomobject]@{ key = 'evidence_pointer_contract'; path = 'scripts/evidence-pointer-contract.ps1'; status = 'stub'; kind = 'evidence_contract'; blocksProductProof = $false; reason = 'latest pointer helpers exist; not wired into every run yet' },
        [pscustomobject]@{ key = 'gap_coverage_contract'; path = 'scripts/gap-coverage-contract.ps1'; status = 'stub'; kind = 'reporting_contract'; blocksProductProof = $false; reason = 'coverage matrix helpers exist; reports must adopt them' },
        [pscustomobject]@{ key = 'product_gap_contract'; path = 'scripts/product-gap-contract.ps1'; status = 'stub'; kind = 'reporting_contract'; blocksProductProof = $false; reason = 'product gap impact helpers exist; reports must adopt them' },
        [pscustomobject]@{ key = 'doctrine_contract'; path = 'scripts/doctrine-contract.ps1'; status = 'stub'; kind = 'verifier_contract'; blocksProductProof = $false; reason = 'doctrine mapping exists; verifier enforcement is follow-up work' },
        [pscustomobject]@{ key = 'command_surface_contract'; path = 'scripts/command-surface-contract.ps1'; status = 'stub'; kind = 'product_contract'; blocksProductProof = $false; reason = 'command registry scaffold exists; runtime registry wiring is follow-up work' },
        [pscustomobject]@{ key = 'mutation_proof_contract'; path = 'scripts/mutation-proof-contract.ps1'; status = 'stub'; kind = 'product_contract'; blocksProductProof = $true; reason = 'mutating product loops must emit real before/after/delta proof before claiming completion' },
        [pscustomobject]@{ key = 'save_safety_contract'; path = 'scripts/save-safety-contract.ps1'; status = 'stub'; kind = 'safety_contract'; blocksProductProof = $true; reason = 'live mutating runs must classify save safety before product proof' },
        [pscustomobject]@{ key = 'route_risk_contract'; path = 'scripts/route-risk-contract.ps1'; status = 'stub'; kind = 'safety_contract'; blocksProductProof = $true; reason = 'travel should declare risk posture before productized travel proof' },
        [pscustomobject]@{ key = 'operator_doc_index_contract'; path = 'scripts/operator-doc-index-contract.ps1'; status = 'stub'; kind = 'docs_contract'; blocksProductProof = $false; reason = 'operator index helper exists; index generation/verification remains follow-up work' },
        [pscustomobject]@{ key = 'guild_loop_report_contract'; path = 'scripts/guild-loop-report-contract.ps1'; status = 'stub'; kind = 'product_contract'; blocksProductProof = $false; reason = 'report shape exists; runtime report unification remains follow-up work' },
        [pscustomobject]@{ key = 'smithing_batch_contract'; path = 'scripts/smithing-batch-contract.ps1'; status = 'stub'; kind = 'product_contract'; blocksProductProof = $true; reason = 'smithing batch loop must produce real stamina/material deltas before product proof' },
        [pscustomobject]@{ key = 'trading_batch_contract'; path = 'scripts/trading-batch-contract.ps1'; status = 'stub'; kind = 'product_contract'; blocksProductProof = $true; reason = 'trading batch loop must produce real inventory/gold deltas or blocked reason before product proof' },
        [pscustomobject]@{ key = 'character_build_contract'; path = 'scripts/character-build-contract.ps1'; status = 'stub'; kind = 'product_contract'; blocksProductProof = $true; reason = 'character build automation must emit preset decision evidence before product proof' },
        [pscustomobject]@{ key = 'companion_stamina_contract'; path = 'scripts/companion-stamina-contract.ps1'; status = 'stub'; kind = 'product_contract'; blocksProductProof = $true; reason = 'companion stamina handling must explain availability before smithing product proof' }
    )
}

function Test-TbgStubSurfaceCatalogEntry {
    param(
        [Parameter(Mandatory = $true)][object]$Entry,
        [string]$RepoRoot = $null
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) { $RepoRoot = Split-Path -Parent $PSScriptRoot }
    if (-not $Entry) { return $false }
    foreach ($field in @('key','path','status','kind','reason')) {
        if ([string]::IsNullOrWhiteSpace([string]$Entry.$field)) { return $false }
    }
    $fullPath = Join-Path $RepoRoot ([string]$Entry.path)
    return (Test-Path -LiteralPath $fullPath)
}

function New-TbgStubSurfaceStatusSummary {
    param(
        [string]$RepoRoot = $null
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) { $RepoRoot = Split-Path -Parent $PSScriptRoot }

    $entries = @(Get-TbgStubSurfaceCatalog | ForEach-Object {
        $exists = Test-TbgStubSurfaceCatalogEntry -Entry $_ -RepoRoot $RepoRoot
        [pscustomobject]@{
            key = $_.key
            path = $_.path
            exists = [bool]$exists
            isStub = [bool]($_.status -eq 'stub')
            stubStatus = $_.status
            stubKind = $_.kind
            blocksProductProof = [bool]$_.blocksProductProof
            reason = $_.reason
        }
    })

    $stubCount = @($entries | Where-Object { $_.isStub }).Count
    $missingCount = @($entries | Where-Object { -not $_.exists }).Count
    $blockingStubCount = @($entries | Where-Object { $_.isStub -and $_.blocksProductProof }).Count

    return [pscustomobject]@{
        schemaVersion = 1
        contract = 'tbg_stub_surface_status'
        generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
        hasIntentionalStubs = ($stubCount -gt 0)
        stubCount = $stubCount
        missingStubSurfaceCount = $missingCount
        blockingProductProofStubCount = $blockingStubCount
        status = if ($missingCount -gt 0) { 'stub_surface_missing' } elseif ($blockingStubCount -gt 0) { 'intentional_stubs_block_some_product_proof' } else { 'intentional_stubs_present' }
        note = 'Intentional stubs are contract surfaces, not broken tests. Product-proof-blocking stubs must be wired before claiming those product loops complete.'
        entries = $entries
    }
}

function Write-TbgStubSurfaceStatusSummary {
    param(
        [string]$Path,
        [string]$RepoRoot = $null
    )

    $summary = New-TbgStubSurfaceStatusSummary -RepoRoot $RepoRoot
    if ($Path) {
        $dir = Split-Path -Parent $Path
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        $summary | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8
    }
    return $summary
}

function Assert-TbgStubSurfaceStatusSummary {
    param([object]$Summary)

    if (-not $Summary) { throw 'stub surface status summary missing' }
    if ([string]$Summary.contract -ne 'tbg_stub_surface_status') { throw 'unexpected stub surface status contract name' }
    if ($Summary.missingStubSurfaceCount -gt 0) { throw "one or more declared stub surfaces are missing: missingStubSurfaceCount=$($Summary.missingStubSurfaceCount)" }
    if (-not $Summary.entries -or @($Summary.entries).Count -eq 0) { throw 'stub surface entries missing' }
    return $true
}
