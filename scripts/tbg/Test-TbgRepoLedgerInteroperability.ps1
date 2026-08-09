#!/usr/bin/env pwsh
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$ContractPath = Join-Path $RepoRoot '.tbg\workflows\repo-ledger-interoperability.contract.json'
$SchemaPath = Join-Path $RepoRoot '.tbg\harness\schemas\repo-ledger-adoption.schema.json'
$RegistryPath = Join-Path $RepoRoot '.tbg\harness\repo-ledger-contributions.registry.json'
$DocPath = Join-Path $RepoRoot 'docs\architecture\repo-ledger-interoperability.md'
$Failures = [System.Collections.Generic.List[string]]::new()

function Fail([string]$Message) {
    $Failures.Add($Message)
}

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { Fail $Message }
}

function Test-ExactCommitPin([string]$Value) {
    return $Value -cmatch '^[0-9a-f]{40}$'
}

function Read-Json([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Fail "missing tracked ledger contract file: $([IO.Path]::GetRelativePath($RepoRoot, $Path))"
        return $null
    }
    try {
        return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Fail "invalid JSON: $([IO.Path]::GetRelativePath($RepoRoot, $Path)): $($_.Exception.Message)"
        return $null
    }
}

$Contract = Read-Json $ContractPath
$Schema = Read-Json $SchemaPath
$Registry = Read-Json $RegistryPath
Assert-True (Test-Path -LiteralPath $DocPath -PathType Leaf) 'missing docs/architecture/repo-ledger-interoperability.md'

$ExpectedDonorCommit = '9351c952b057ae4520b1ea0d388e1d8908f4c093'
$ExpectedSources = [ordered]@{
    '.ai/README.md' = '78eee20a18ab20e66193542be0b35099428fc83b'
    '.ai/WORK_QUEUE.md' = '916d31d8f41cc130eee32f069043934fbde98186'
    '.ai/authority.json' = '6228a537381823e1685f094ad9fd502226829444'
    'scripts/ai-harness/validate-work-queue.mjs' = '50f8fef19c261b38cc560ad9e9c9c4012ec4db8d'
}
$ExpectedStatuses = @('READY','CLAIMED','VERIFY','REVIEW','MERGE','OPERATOR','BLOCKED','DONE')
$ExpectedClassifications = @(
    'portable_harness',
    'reusable_skill',
    'shared_schema_or_evidence_packet',
    'adapter',
    'reference_only_doctrine',
    'domain_specific_rejected'
)
$ExpectedConsumers = [ordered]@{
    'EndeavorEverlasting/AxTask' = 'AXQ'
    'EndeavorEverlasting/AgentSwitchboard' = 'ASQ'
    'EndeavorEverlasting/web-excel-repair-triage' = 'TRQ'
}

if ($Contract) {
    Assert-True ($Contract.id -eq 'repo-ledger-interoperability') 'contract id drifted'
    Assert-True ($Contract.contractVersion -eq 'RepoLedgerInteroperability.v1') 'contract version drifted'
    Assert-True ($Contract.contractOwner.repo -eq 'EndeavorEverlasting/BlacksmithGuild') 'BlacksmithGuild must remain the portable contract owner'
    Assert-True ($Contract.donor.repo -eq 'EndeavorEverlasting/AxTask') 'AxTask donor repository drifted'
    Assert-True ($Contract.donor.commit -eq $ExpectedDonorCommit) 'AxTask donor commit drifted without a versioned compatibility update'
    Assert-True (Test-ExactCommitPin ([string]$Contract.donor.commit)) 'donor commit must be an exact 40-hex pin'
    Assert-True (@($Contract.donor.sourcePaths).Count -eq $ExpectedSources.Count) 'donor authoritative source-path count drifted'
    foreach ($Path in $ExpectedSources.Keys) {
        Assert-True (@($Contract.donor.sourcePaths) -contains $Path) "missing donor source path: $Path"
    }
    Assert-True ((Compare-Object $ExpectedStatuses @($Contract.portableContract.statuses) -SyncWindow 0).Count -eq 0) 'portable status vocabulary drifted'
    Assert-True ($Contract.portableContract.doneNextAction -eq 'none; no safe actionable work remains') 'strict DONE next-action token drifted'
    Assert-True ($Contract.compatibility.adoptionSchema -eq 'RepoLedgerAdoption.v1') 'adoption schema id drifted'
    Assert-True ($Contract.proofCeiling -eq 'contract_and_repository_harness_proof_only') 'contract proof ceiling drifted'
    Assert-True (@($Contract.consumerContract.mustNotReimplement) -contains 'AxTask production recovery queue contents') 'AxTask domain-copy prohibition missing'
    Assert-True (@($Contract.forbiddenScope) -contains 'centralizing consumer queue contents in BlacksmithGuild') 'central runtime-queue prohibition missing'
}

if ($Schema) {
    Assert-True ($Schema.title -eq 'Repository ledger adoption manifest') 'adoption schema title drifted'
    Assert-True ($Schema.properties.schema.const -eq 'RepoLedgerAdoption.v1') 'adoption schema identifier drifted'
    Assert-True ($Schema.properties.contract.properties.repository.const -eq 'EndeavorEverlasting/BlacksmithGuild') 'schema contract owner drifted'
    Assert-True ($Schema.properties.contract.properties.version.const -eq 'RepoLedgerInteroperability.v1') 'schema contract version drifted'
    Assert-True ($Schema.properties.contract.properties.commit.pattern -eq '^[0-9a-f]{40}$') 'schema must reject symbolic/short contract refs'
    Assert-True ($Schema.properties.donor.properties.commit.const -eq $ExpectedDonorCommit) 'schema donor pin drifted'
    Assert-True ($Schema.properties.authority.properties.noCircularAuthority.const -eq $true) 'schema must require noCircularAuthority=true'
}

if ($Registry) {
    Assert-True ($Registry.schema -eq 'TbgRepoLedgerContributionRegistry.v1') 'contribution registry schema drifted'
    Assert-True ($Registry.contractOwner -eq 'EndeavorEverlasting/BlacksmithGuild') 'contribution registry owner drifted'
    Assert-True ($Registry.donor.repository -eq 'EndeavorEverlasting/AxTask') 'registry donor repository drifted'
    Assert-True ($Registry.donor.commit -eq $ExpectedDonorCommit) 'registry donor commit drifted'
    Assert-True (@($Registry.donor.sources).Count -eq $ExpectedSources.Count) 'registry donor source count drifted'
    foreach ($Source in @($Registry.donor.sources)) {
        Assert-True ($ExpectedSources.Contains([string]$Source.path)) "unapproved donor source path: $($Source.path)"
        if ($ExpectedSources.Contains([string]$Source.path)) {
            Assert-True ($Source.blob -eq $ExpectedSources[[string]$Source.path]) "donor blob pin drifted for $($Source.path)"
        }
        Assert-True (Test-ExactCommitPin ([string]$Source.blob)) "donor blob is not exact 40-hex for $($Source.path)"
    }

    $ActualClassifications = @($Registry.candidates | ForEach-Object { [string]$_.classification })
    foreach ($Classification in $ExpectedClassifications) {
        Assert-True ($ActualClassifications -contains $Classification) "missing candidate classification: $Classification"
    }
    Assert-True (@($ActualClassifications | Sort-Object -Unique).Count -eq $ExpectedClassifications.Count) 'candidate classifications must be unique and complete'

    $SeenConsumers = @{}
    $SeenNamespaces = @{}
    foreach ($Consumer in @($Registry.consumers)) {
        $Repo = [string]$Consumer.repository
        $Namespace = [string]$Consumer.taskNamespace
        Assert-True ($ExpectedConsumers.Contains($Repo)) "unexpected consumer repository: $Repo"
        if ($ExpectedConsumers.Contains($Repo)) {
            Assert-True ($Namespace -eq $ExpectedConsumers[$Repo]) "consumer task namespace drifted for $Repo"
        }
        Assert-True (-not $SeenConsumers.ContainsKey($Repo)) "duplicate consumer repository: $Repo"
        Assert-True (-not $SeenNamespaces.ContainsKey($Namespace)) "task namespace collision: $Namespace"
        $SeenConsumers[$Repo] = $true
        $SeenNamespaces[$Namespace] = $true
    }
    Assert-True ($SeenConsumers.Count -eq $ExpectedConsumers.Count) 'consumer registry is incomplete'
    Assert-True ($Registry.staleReferencePolicy.acceptedRef -eq 'exact 40-character lowercase hexadecimal commit SHA') 'stale-reference policy drifted'
}

foreach ($BadRef in @('main','master','HEAD','feat/repo-ledger','v1.0.0','9351c952b057')) {
    Assert-True (-not (Test-ExactCommitPin $BadRef)) "stale-reference probe unexpectedly accepted '$BadRef'"
}
Assert-True (Test-ExactCommitPin $ExpectedDonorCommit) 'exact donor pin probe failed'

if ($Failures.Count -gt 0) {
    Write-Error "[repo-ledger] FAIL ($($Failures.Count))"
    foreach ($Failure in $Failures) { Write-Error "- $Failure" }
    exit 1
}

Write-Host "[repo-ledger] PASS contract=RepoLedgerInteroperability.v1 donor=$($ExpectedDonorCommit.Substring(0,12)) consumers=$($ExpectedConsumers.Count) stale-ref-probes=PASS"
exit 0
