param(
    [Parameter(Mandatory=$true)][string]$CommandText,
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
$policyPath = Join-Path $repoRoot ".tbg/harness/policies/command-safety.policy.json"
$policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json

$decision = "ask"
$reason = "No allow or deny rule matched."
$matchedPattern = $null
$requiresForgeStop = $false

foreach ($pattern in @($policy.denyPatterns)) {
    if ($CommandText -match $pattern) {
        $decision = "deny"
        $reason = "Command matches deny pattern."
        $matchedPattern = $pattern
        break
    }
}

foreach ($pattern in @($policy.requiresForgeStopFirst)) {
    if ($CommandText -match $pattern) { $requiresForgeStop = $true }
}

if ($decision -ne "deny") {
    $allowPatterns = @()
    if ($policy.allowPatternsByContract.PSObject.Properties.Name -contains $ContractId) {
        $allowPatterns = @($policy.allowPatternsByContract.$ContractId)
    }
    foreach ($pattern in $allowPatterns) {
        if ($CommandText -match $pattern) {
            $decision = "allow"
            $reason = "Command matches allow pattern for active contract."
            $matchedPattern = $pattern
            break
        }
    }
}

$result = [pscustomobject]@{
    schema = "tbg.hook-result.v1"
    hook = "command-safety"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    contractId = $ContractId
    commandText = $CommandText
    decision = $decision
    reason = $reason
    matchedPattern = $matchedPattern
    requiresForgeStopFirst = $requiresForgeStop
    findings = @()
}

$artifactDir = Join-Path $repoRoot "artifacts/latest"
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
$result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $artifactDir "command-safety.result.json") -Encoding UTF8
$result | ConvertTo-Json -Depth 20

if ($FailOnDeny -and $decision -eq "deny") { exit 2 }
