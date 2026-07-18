param(
    [Parameter(Mandatory=$true)][string]$PathText,
    [string]$ContractId = "local-mcp-code-intelligence",
    [switch]$FailOnDeny
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Find-TbgRepoRoot {
    $cursor = (Get-Location).Path
    while ($true) {
        if (Test-Path -LiteralPath (Join-Path $cursor ".tbg/harness/manifest.json")) { return $cursor }
        $parent = Split-Path -Parent $cursor
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $cursor) { throw "Could not locate repo root." }
        $cursor = $parent
    }
}

$repoRoot = Find-TbgRepoRoot
$policyPath = Join-Path $repoRoot ".tbg/harness/policies/file-safety.policy.json"
$policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
$normalized = ($PathText -replace '\\', '/')

$decision = "ask"
$reason = "No allow or deny rule matched."
$matchedPattern = $null

foreach ($pattern in @($policy.protectedPaths)) {
    if ($normalized -match $pattern -or $PathText -match $pattern) {
        $decision = "deny"
        $reason = "Path matches protected path pattern."
        $matchedPattern = $pattern
        break
    }
}

if ($decision -ne "deny") {
    $allowPatterns = @()
    if ($policy.allowedPathPatternsByContract.PSObject.Properties.Name -contains $ContractId) {
        $allowPatterns = @($policy.allowedPathPatternsByContract.$ContractId)
    }
    foreach ($pattern in $allowPatterns) {
        if ($normalized -match $pattern) {
            $decision = "allow"
            $reason = "Path matches allowed pattern for active contract."
            $matchedPattern = $pattern
            break
        }
    }
}

$result = [pscustomobject]@{
    schema = "tbg.hook-result.v1"
    hook = "file-safety"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    contractId = $ContractId
    pathText = $PathText
    normalizedPath = $normalized
    decision = $decision
    reason = $reason
    matchedPattern = $matchedPattern
    findings = @()
    artifacts = @("artifacts/latest/file-safety.result.json", "artifacts/latest/file-safety.report.md")
}

$artifactDir = Join-Path $repoRoot "artifacts/latest"
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
$artifactPath = Join-Path $artifactDir "file-safety.result.json"
$reportPath = Join-Path $artifactDir "file-safety.report.md"
Import-Module (Join-Path $PSScriptRoot "TbgEffectivePolicy.psm1") -Force
$json = Write-TbgPolicyReport -ResultObject $result -JsonPath $artifactPath -MarkdownPath $reportPath -ProfileId $ContractId -RowType "file-safety" -RepoRoot $repoRoot -Title "File safety"
Write-Output $json

if ($FailOnDeny -and $decision -eq "deny") { exit 2 }
