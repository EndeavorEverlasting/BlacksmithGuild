[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$OutputRoot = 'artifacts/latest/session-intent-contract'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

function Resolve-RepoPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return $Path }
    return Join-Path $RepoRoot ($Path -replace '/', [IO.Path]::DirectorySeparatorChar)
}

$schemaPath = Resolve-RepoPath '.tbg/harness/schemas/tbg-session-intent.schema.json'
$policyPath = Resolve-RepoPath '.tbg/harness/policies/session-intent.policy.json'
$outputPath = Resolve-RepoPath $OutputRoot
$errors = [System.Collections.Generic.List[string]]::new()
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check([string]$Name, [bool]$Passed, [string]$Detail = '') {
    $checks.Add([pscustomobject]@{ name = $Name; passed = $Passed; detail = $Detail }) | Out-Null
    if (-not $Passed) { $errors.Add("${Name}: ${Detail}") | Out-Null }
}

Add-Check 'session intent schema exists' (Test-Path -LiteralPath $schemaPath -PathType Leaf) $schemaPath
Add-Check 'session intent policy exists' (Test-Path -LiteralPath $policyPath -PathType Leaf) $policyPath

$schema = $null
$policy = $null
if ($errors.Count -eq 0) {
    try { $schema = Get-Content -LiteralPath $schemaPath -Raw | ConvertFrom-Json }
    catch { $errors.Add("schema parse failed: $($_.Exception.Message)") | Out-Null }
    try { $policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json }
    catch { $errors.Add("policy parse failed: $($_.Exception.Message)") | Out-Null }
}

if ($schema) {
    Add-Check 'schema id' ($schema.schema -eq 'tbg.session-intent.schema.v1') ([string]$schema.schema)
    Add-Check 'schema contract-only status' ($schema.implementationStatus -eq 'contract_only_product_integration_deferred') ([string]$schema.implementationStatus)
    Add-Check 'schema proof ceiling' ($schema.proofCeiling -eq 'contract') ([string]$schema.proofCeiling)
    $required = @($schema.required)
    foreach ($field in @('schema','generatedUtc','drivenBy','launchIntent','sessionId')) {
        Add-Check "schema requires $field" ($required -contains $field) ($required -join ',')
    }
}

if ($policy) {
    Add-Check 'policy id' ($policy.schema -eq 'tbg.session-intent.policy.v1') ([string]$policy.schema)
    Add-Check 'policy contract-only status' ($policy.status -eq 'contract_only_product_integration_deferred') ([string]$policy.status)
    Add-Check 'policy proof ceiling' ($policy.proofCeiling -eq 'contract') ([string]$policy.proofCeiling)
    Add-Check 'policy authority boundary exists' ($null -ne $policy.authorityBoundary) 'authorityBoundary is required'
    Add-Check 'human fails closed' ([bool]$policy.drivenBy.human_player.autonomousDriversBlocked) 'human_player must block autonomous drivers by default'
    Add-Check 'unknown fails closed' ([bool]$policy.drivenBy.unknown.autonomousDriversBlocked) 'unknown must block autonomous drivers by default'
}

if ($schema -and $policy) {
    $schemaDrivers = @($schema.properties.drivenBy.enum | ForEach-Object { [string]$_ } | Sort-Object)
    $policyDrivers = @($policy.drivenBy.PSObject.Properties.Name | ForEach-Object { [string]$_ } | Sort-Object)
    Add-Check 'driver taxonomy matches' (($schemaDrivers -join '|') -eq ($policyDrivers -join '|')) "schema=$($schemaDrivers -join ',') policy=$($policyDrivers -join ',')"

    $policyText = $policy | ConvertTo-Json -Depth 20
    Add-Check 'policy does not grant authority' ($policyText -notmatch 'Full automation including bounded execution is permitted') 'session intent must remain descriptive/requested state only'
    Add-Check 'commitSha spelling repaired' ($policyText -notmatch 'comitSha') 'use commitSha'
}

New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
$passed = @($checks | Where-Object { $_.passed }).Count
$failed = @($checks | Where-Object { -not $_.passed }).Count + $errors.Count
$status = if ($failed -eq 0) { 'PASS_session_intent_contract' } else { 'FAIL_session_intent_contract' }
$result = [ordered]@{
    schema = 'tbg.session-intent-contract.result.v1'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    status = $status
    proofLevel = 'static test'
    proofCeiling = 'The session-intent schema and policy are internally consistent contract artifacts. No runtime integration, launch, mutation, or gameplay behavior is proven.'
    checks = @($checks)
    errors = @($errors)
}
$result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $outputPath 'session-intent-contract.result.json') -Encoding UTF8

Write-Host "Session intent contract validation: $status"
Write-Host "Checks: $passed passed; $failed failed"
if ($failed -ne 0) {
    foreach ($error in $errors) { Write-Host "  ERROR: $error" }
    exit 1
}
exit 0
