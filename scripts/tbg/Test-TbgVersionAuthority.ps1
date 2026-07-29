[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$OutputRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
$RepoRoot = [IO.Path]::GetFullPath($RepoRoot)

if (-not [string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
    if (-not (Test-Path -LiteralPath $OutputRoot -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
    }
}

$failures = [System.Collections.Generic.List[string]]::new()
function Fail([string]$Message) {
    $failures.Add($Message) | Out-Null
}

function Resolve-RepoPath([string]$RelativePath) {
    return Join-Path $RepoRoot ($RelativePath -replace '/', [IO.Path]::DirectorySeparatorChar)
}

function Read-Json([string]$RelativePath) {
    $path = Resolve-RepoPath $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Fail "missing: $RelativePath"
        return $null
    }

    try {
        return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Fail "invalid JSON: $RelativePath :: $($_.Exception.Message)"
        return $null
    }
}

function Read-Text([string]$RelativePath) {
    $path = Resolve-RepoPath $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Fail "missing: $RelativePath"
        return ''
    }

    return Get-Content -LiteralPath $path -Raw -Encoding UTF8
}

function Get-NestedValue {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $current = $Object
    foreach ($segment in $Path.Split('.')) {
        if ($null -eq $current) {
            return $null
        }

        $property = $current.PSObject.Properties[$segment]
        if ($null -eq $property) {
            return $null
        }

        $current = $property.Value
    }

    return $current
}

$policyPath = '.tbg/harness/policies/version-authority.policy.json'
$policy = Read-Json $policyPath
if ($null -eq $policy) {
    Write-Host 'FAIL_version_authority_contract'
    foreach ($failure in $failures) { Write-Host " - $failure" }
    exit 1
}

if ([string]$policy.schema -ne 'TbgVersionAuthorityPolicy.v1') {
    Fail 'version authority policy schema mismatch'
}

$canonicalRegistryPath = [string]$policy.canonicalAuthority.registry
$supportedVersionField = [string]$policy.canonicalAuthority.supportedVersionField
$moduleVersionField = [string]$policy.canonicalAuthority.moduleDependencyVersionField
$moduleMetadataPath = [string]$policy.canonicalAuthority.moduleMetadata
$moduleMetadataSourceField = [string]$policy.canonicalAuthority.moduleMetadataSourceField

$registry = Read-Json $canonicalRegistryPath
$supportedPrefix = $null
$moduleDependencyVersion = $null

if ($registry) {
    $supportedPrefix = [string](Get-NestedValue -Object $registry -Path $supportedVersionField)
    $moduleDependencyVersion = [string](Get-NestedValue -Object $registry -Path $moduleVersionField)
    $declaredMetadataSource = [string](Get-NestedValue -Object $registry -Path $moduleMetadataSourceField)

    if ([string]::IsNullOrWhiteSpace($supportedPrefix)) {
        Fail "canonical registry field is empty: $supportedVersionField"
    }
    if ([string]::IsNullOrWhiteSpace($moduleDependencyVersion)) {
        Fail "canonical registry field is empty: $moduleVersionField"
    }
    if (-not [string]::IsNullOrWhiteSpace($supportedPrefix) -and $moduleDependencyVersion -ne ('v' + $supportedPrefix)) {
        Fail "module dependency version '$moduleDependencyVersion' does not equal canonical prefix 'v$supportedPrefix'"
    }
    if ($declaredMetadataSource -ne $moduleMetadataPath) {
        Fail "canonical registry source '$declaredMetadataSource' does not match policy module metadata '$moduleMetadataPath'"
    }
}

$moduleMetadataText = Read-Text $moduleMetadataPath
if (-not [string]::IsNullOrWhiteSpace($moduleMetadataText)) {
    try {
        [xml]$moduleXml = $moduleMetadataText
        $dependencies = @($moduleXml.Module.DependedModules.DependedModule | Where-Object {
            [string]$_.Optional -ne 'true'
        })
        if ($dependencies.Count -eq 0) {
            Fail 'module metadata contains no required dependencies'
        }
        else {
            foreach ($dependency in $dependencies) {
                $dependencyId = [string]$dependency.Id
                $dependencyVersion = [string]$dependency.DependentVersion
                if ($dependencyVersion -ne $moduleDependencyVersion) {
                    Fail "module dependency '$dependencyId' declares '$dependencyVersion' instead of canonical '$moduleDependencyVersion'"
                }
            }
        }
    }
    catch {
        Fail "invalid module metadata XML: $moduleMetadataPath :: $($_.Exception.Message)"
    }
}

$literalPattern = [string]$policy.versionLiteralPattern
try {
    $literalRegex = [regex]::new($literalPattern)
}
catch {
    Fail "invalid version literal regex: $($_.Exception.Message)"
    $literalRegex = $null
}

$consumerPaths = @($policy.protectedConsumers | ForEach-Object { [string]$_.path })
if (($consumerPaths | Sort-Object -Unique).Count -ne $consumerPaths.Count) {
    Fail 'version authority policy contains duplicate protected consumer paths'
}

foreach ($consumer in @($policy.protectedConsumers)) {
    $consumerPath = [string]$consumer.path
    $consumerText = Read-Text $consumerPath
    if ([string]::IsNullOrWhiteSpace($consumerText)) {
        continue
    }

    foreach ($marker in @($consumer.requiredMarkers)) {
        $markerText = [string]$marker
        if (-not $consumerText.Contains($markerText)) {
            Fail "consumer '$consumerPath' is missing authority marker '$markerText'"
        }
    }

    foreach ($propertyName in @($consumer.forbiddenProperties)) {
        $propertyText = [string]$propertyName
        $propertyPattern = '"{0}"\s*:' -f [regex]::Escape($propertyText)
        if ([regex]::IsMatch($consumerText, $propertyPattern)) {
            Fail "consumer '$consumerPath' duplicates forbidden authority property '$propertyText'"
        }
    }

    if ($consumer.forbidVersionLiterals -eq $true -and $null -ne $literalRegex) {
        $literalMatches = @(
            $literalRegex.Matches($consumerText) |
                ForEach-Object { $_.Value } |
                Sort-Object -Unique
        )
        if ($literalMatches.Count -gt 0) {
            Fail "consumer '$consumerPath' contains branch-local Bannerlord version literal(s): $($literalMatches -join ', ')"
        }
    }
}

$allowedOwners = @($policy.allowedVersionLiteralOwners | ForEach-Object { [string]$_ })
foreach ($requiredOwner in @($canonicalRegistryPath, $moduleMetadataPath)) {
    if ($allowedOwners -notcontains $requiredOwner) {
        Fail "allowed version-literal owners omit canonical path '$requiredOwner'"
    }
}

$result = [ordered]@{
    schema = 'TbgVersionAuthorityValidationResult.v1'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    status = if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL' }
    canonicalRegistry = $canonicalRegistryPath
    supportedGameVersionPrefix = $supportedPrefix
    moduleDependencyVersion = $moduleDependencyVersion
    protectedConsumerCount = @($policy.protectedConsumers).Count
    failureCount = $failures.Count
    failures = @($failures.ToArray())
    proofCeiling = [string]$policy.proofBoundary
}

if (-not [string]::IsNullOrWhiteSpace($OutputRoot)) {
    $result |
        ConvertTo-Json -Depth 10 |
        Set-Content -LiteralPath (Join-Path $OutputRoot 'version-authority.validation.json') -Encoding UTF8
}

if ($failures.Count -gt 0) {
    Write-Host 'FAIL_version_authority_contract'
    foreach ($failure in $failures) { Write-Host " - $failure" }
    exit 1
}

Write-Host 'PASS_version_authority_contract'
Write-Host "canonicalVersion=$supportedPrefix moduleDependencyVersion=$moduleDependencyVersion"
Write-Host "protectedConsumers=$(@($policy.protectedConsumers).Count)"
exit 0
