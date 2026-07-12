Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$contractPath = Join-Path $repoRoot '.tbg\workflows\continuum-interoperability.contract.json'
$schemaPath = Join-Path $repoRoot '.tbg\harness\schemas\continuum-capability-packet.schema.json'
$exporterPath = Join-Path $PSScriptRoot 'Export-TbgContinuumCapabilityPacket.ps1'
$docPath = Join-Path $repoRoot 'docs\architecture\continuum-interoperability.md'
$manifestPath = Join-Path $repoRoot '.tbg\harness\manifest.json'
$workflowPath = Join-Path $repoRoot '.github\workflows\governor-contracts.yml'

function Assert-Condition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

try {
    foreach ($path in @($contractPath, $schemaPath, $exporterPath, $docPath, $manifestPath, $workflowPath)) {
        Assert-Condition -Condition (Test-Path -LiteralPath $path -PathType Leaf) -Message "Required Continuum interoperability file is missing: $path"
    }

    $contract = Get-Content -LiteralPath $contractPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $schema = Get-Content -LiteralPath $schemaPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $exporter = Get-Content -LiteralPath $exporterPath -Raw -Encoding UTF8
    $doc = Get-Content -LiteralPath $docPath -Raw -Encoding UTF8
    $workflow = Get-Content -LiteralPath $workflowPath -Raw -Encoding UTF8

    Assert-Condition -Condition ($contract.id -eq 'continuum-interoperability') -Message 'Continuum interoperability contract id is incorrect.'
    Assert-Condition -Condition ($contract.schemaVersion -eq 'TbgWorkflowContract.v1') -Message 'Continuum interoperability contract schema version is incorrect.'
    Assert-Condition -Condition ($contract.status -eq 'experiment_active') -Message 'Initial Continuum interoperability state must remain experiment_active.'
    Assert-Condition -Condition ($contract.producer.repo -eq 'EndeavorEverlasting/BlacksmithGuild') -Message 'BlacksmithGuild must remain the packet producer.'
    Assert-Condition -Condition ($contract.consumer.repo -eq 'EndeavorEverlasting/Continuum') -Message 'Continuum consumer repository is incorrect.'
    Assert-Condition -Condition (-not [bool]$contract.consumer.required) -Message 'Continuum must remain optional.'
    Assert-Condition -Condition ([bool]$contract.operatingModel.blacksmithGuildRemainsStandalone) -Message 'BlacksmithGuild standalone operation is not guaranteed.'
    Assert-Condition -Condition (-not [bool]$contract.operatingModel.requiredForBuild) -Message 'Continuum must not be required for BlacksmithGuild builds.'
    Assert-Condition -Condition (-not [bool]$contract.operatingModel.requiredForRuntime) -Message 'Continuum must not be required for BlacksmithGuild runtime.'
    Assert-Condition -Condition (-not [bool]$contract.operatingModel.requiredForRepositoryValidation) -Message 'Continuum must not be required for BlacksmithGuild repository validation.'
    Assert-Condition -Condition (-not [bool]$contract.operatingModel.continuumMayMutateBlacksmithGuildRuntime) -Message 'Continuum must not receive BlacksmithGuild runtime mutation authority.'

    Assert-Condition -Condition ($schema.'$schema' -eq 'https://json-schema.org/draft/2020-12/schema') -Message 'Capability packet schema must use JSON Schema draft 2020-12.'
    Assert-Condition -Condition ($schema.properties.schema.const -eq 'TbgContinuumCapabilityPacket.v1') -Message 'Capability packet schema id is incorrect.'

    $allowedClassifications = @('candidate_for_continuum', 'blacksmith_adapter', 'domain_locked')
    $capabilities = @($contract.capabilities)
    Assert-Condition -Condition ($capabilities.Count -ge 6) -Message 'Interoperability contract must inventory at least six capabilities.'

    $ids = @($capabilities | ForEach-Object { [string]$_.id })
    Assert-Condition -Condition (($ids | Sort-Object -Unique).Count -eq $ids.Count) -Message 'Capability ids must be unique.'

    $candidateCount = 0
    $domainLockedCount = 0
    $domainTerms = @('bannerlord', 'launcher', 'save', 'campaign', 'route', 'smithing', 'trade', 'economy', 'gameplay', 'movement')
    $repoRootFull = [IO.Path]::GetFullPath($repoRoot)

    foreach ($capability in $capabilities) {
        $id = [string]$capability.id
        $classification = [string]$capability.classification
        Assert-Condition -Condition ($allowedClassifications -contains $classification) -Message "Capability $id has an unsupported classification: $classification"
        Assert-Condition -Condition (@($capability.sourcePaths).Count -gt 0) -Message "Capability $id must name at least one source path."
        Assert-Condition -Condition (@($capability.blacksmithAdapter).Count -gt 0) -Message "Capability $id must preserve an app-owned adapter or authority boundary."

        foreach ($relativePath in @($capability.sourcePaths)) {
            Assert-Condition -Condition (-not [IO.Path]::IsPathRooted([string]$relativePath)) -Message "Capability $id uses an absolute source path: $relativePath"
            $fullPath = [IO.Path]::GetFullPath((Join-Path $repoRoot ([string]$relativePath)))
            Assert-Condition -Condition ($fullPath.StartsWith($repoRootFull, [StringComparison]::OrdinalIgnoreCase)) -Message "Capability $id escapes the repository root: $relativePath"
            Assert-Condition -Condition (Test-Path -LiteralPath $fullPath -PathType Leaf) -Message "Capability $id references a missing source path: $relativePath"
        }

        if ($classification -eq 'candidate_for_continuum') {
            $candidateCount++
            Assert-Condition -Condition (@($capability.genericCore).Count -gt 0) -Message "Continuum candidate $id must define a generic core."
            $genericText = (@($capability.genericCore) -join ' ').ToLowerInvariant()
            foreach ($term in $domainTerms) {
                Assert-Condition -Condition (-not $genericText.Contains($term)) -Message "Continuum candidate $id leaks app-domain term '$term' into its generic core."
            }
        }

        if ($classification -eq 'domain_locked') {
            $domainLockedCount++
            Assert-Condition -Condition (@($capability.genericCore).Count -eq 0) -Message "Domain-locked capability $id must not expose a generic core."
        }
    }

    Assert-Condition -Condition ($candidateCount -ge 5) -Message 'At least five current harness capabilities must be inventoried as Continuum candidates.'
    Assert-Condition -Condition ($domainLockedCount -ge 1) -Message 'At least one explicit domain-locked capability is required.'

    $forbiddenText = (@($contract.forbiddenScope) -join ' ').ToLowerInvariant()
    foreach ($requiredTerm in @('build', 'runtime dependency', 'route', 'smithing', 'launcher', 'save', 'cross-repository mutation')) {
        Assert-Condition -Condition ($forbiddenText.Contains($requiredTerm)) -Message "Forbidden-scope boundary is missing: $requiredTerm"
    }

    Assert-Condition -Condition ($manifest.paths.interoperabilityContract -eq '.tbg/workflows/continuum-interoperability.contract.json') -Message 'Harness manifest does not expose the interoperability contract.'
    Assert-Condition -Condition ($manifest.paths.continuumCapabilitySchema -eq '.tbg/harness/schemas/continuum-capability-packet.schema.json') -Message 'Harness manifest does not expose the capability packet schema.'

    foreach ($term in @('standalone', 'one-way', 'export-before-extraction', 'optional development accelerator', 'parity')) {
        Assert-Condition -Condition ($doc.ToLowerInvariant().Contains($term)) -Message "Continuum interoperability documentation is missing doctrine term: $term"
    }

    foreach ($forbiddenPattern in @(
        '(?im)^\s*gh\s+',
        '(?im)^\s*git\s+',
        '(?im)^\s*continuum\s+',
        '(?im)Invoke-WebRequest',
        '(?im)Invoke-RestMethod',
        '(?im)Start-Process'
    )) {
        Assert-Condition -Condition ($exporter -notmatch $forbiddenPattern) -Message "Capability exporter contains forbidden external execution matching: $forbiddenPattern"
    }

    Assert-Condition -Condition ($workflow.Contains('Verify-TbgContinuumInteroperability.ps1')) -Message 'Governor workflow does not run the Continuum interoperability verifier.'
    Assert-Condition -Condition ($workflow.Contains('Export-TbgContinuumCapabilityPacket.ps1')) -Message 'Governor workflow does not exercise the capability exporter.'

    $packetPath = Join-Path ([IO.Path]::GetTempPath()) ("tbg-continuum-capabilities-{0}.json" -f [Guid]::NewGuid().ToString('N'))
    try {
        & $exporterPath -OutputPath $packetPath
        $packet = Get-Content -LiteralPath $packetPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-Condition -Condition ($packet.schema -eq 'TbgContinuumCapabilityPacket.v1') -Message 'Exported packet schema is incorrect.'
        Assert-Condition -Condition ($packet.producer -eq 'EndeavorEverlasting/BlacksmithGuild') -Message 'Exported packet producer is incorrect.'
        Assert-Condition -Condition ($packet.consumer -eq 'EndeavorEverlasting/Continuum') -Message 'Exported packet consumer is incorrect.'
        Assert-Condition -Condition ($packet.relationship -eq 'optional_development_accelerator') -Message 'Exported packet relationship is incorrect.'
        Assert-Condition -Condition ([bool]$packet.standalone.build -and [bool]$packet.standalone.runtime -and [bool]$packet.standalone.repositoryValidation) -Message 'Exported packet does not preserve standalone operation.'
        Assert-Condition -Condition (@($packet.capabilities).Count -eq $capabilities.Count) -Message 'Exported packet capability count does not match the contract.'
        Assert-Condition -Condition ((@($packet.capabilities.id) | Sort-Object -Unique).Count -eq $capabilities.Count) -Message 'Exported packet capability ids are not unique.'
        [void][DateTime]::Parse([string]$packet.generatedUtc)
    } finally {
        Remove-Item -LiteralPath $packetPath -Force -ErrorAction SilentlyContinue
    }

    Write-Host 'PASS: BlacksmithGuild exports a versioned Continuum capability packet while preserving standalone operation, app-owned adapters, and domain/runtime authority.' -ForegroundColor Green
    exit 0
} catch {
    Write-Host ('FAIL: Continuum interoperability verifier: {0}' -f $_.Exception.Message) -ForegroundColor Red
    exit 1
}
