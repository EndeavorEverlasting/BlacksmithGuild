[CmdletBinding()]
param(
    [string]$OutputPath,
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$contractPath = Join-Path $repoRoot '.tbg\workflows\continuum-interoperability.contract.json'

if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
    throw "Continuum interoperability contract is missing: $contractPath"
}

$contract = Get-Content -LiteralPath $contractPath -Raw -Encoding UTF8 | ConvertFrom-Json
$capabilities = @(
    foreach ($capability in @($contract.capabilities)) {
        [ordered]@{
            id = [string]$capability.id
            classification = [string]$capability.classification
            maturity = [string]$capability.maturity
            summary = [string]$capability.summary
            sourcePaths = @($capability.sourcePaths)
            genericCore = @($capability.genericCore)
            blacksmithAdapter = @($capability.blacksmithAdapter)
            proofLevel = [string]$capability.proofLevel
        }
    }
)

$packet = [ordered]@{
    schema = 'TbgContinuumCapabilityPacket.v1'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    producer = [string]$contract.producer.repo
    consumer = [string]$contract.consumer.repo
    relationship = [string]$contract.consumer.relationship
    contract = [ordered]@{
        id = [string]$contract.id
        schemaVersion = [string]$contract.schemaVersion
        status = [string]$contract.status
    }
    standalone = [ordered]@{
        build = -not [bool]$contract.operatingModel.requiredForBuild
        runtime = -not [bool]$contract.operatingModel.requiredForRuntime
        repositoryValidation = -not [bool]$contract.operatingModel.requiredForRepositoryValidation
    }
    capabilities = $capabilities
    migrationRules = @($contract.migrationRules)
}

$json = $packet | ConvertTo-Json -Depth 20

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $resolvedOutputPath = [IO.Path]::GetFullPath($OutputPath)
    $parent = Split-Path -Parent $resolvedOutputPath
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        [void](New-Item -ItemType Directory -Force -Path $parent)
    }
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($resolvedOutputPath, $json + [Environment]::NewLine, $encoding)
    Write-Host "Wrote BlacksmithGuild capability packet for Continuum to $resolvedOutputPath"
}

if ($PassThru -or [string]::IsNullOrWhiteSpace($OutputPath)) {
    Write-Output $json
}
