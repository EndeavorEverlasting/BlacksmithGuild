param(
    [Parameter(Mandatory=$true)][string]$Action,
    [Parameter(Mandatory=$true)][string]$Status,
    [Parameter(Mandatory=$true)][string]$Verdict,
    [string]$ContractId = "local-mcp-code-intelligence",
    [string[]]$Findings = @(),
    [string[]]$MissingPrereqs = @(),
    [string[]]$Artifacts = @(),
    [bool]$ForbiddenScopeTouched = $false,
    [string]$OutputPath = ""
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

function Invoke-Capture {
    param([string]$FileName, [string[]]$Arguments)
    try {
        $output = & $FileName @Arguments 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }
        return ($output -join "`n").Trim()
    } catch { return $null }
}

$repoRoot = Find-TbgRepoRoot
Push-Location $repoRoot
try {
    $branch = Invoke-Capture -FileName "git" -Arguments @("rev-parse", "--abbrev-ref", "HEAD")
} finally { Pop-Location }
if ([string]::IsNullOrWhiteSpace($branch)) { $branch = "unknown" }

$artifactDir = Join-Path $repoRoot "artifacts/latest"
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $safeAction = ($Action -replace '[^A-Za-z0-9_.-]', '-').ToLowerInvariant()
    $OutputPath = Join-Path $artifactDir "$safeAction.result.json"
}
$reportPath = $OutputPath -replace '\.result\.json$', '.report.md'
if ($reportPath -eq $OutputPath) { $reportPath = $OutputPath -replace '\.json$', '.report.md' }
if ($reportPath -eq $OutputPath) { $reportPath = "$OutputPath.report.md" }
$resultArtifacts = @($Artifacts)
foreach ($path in @($OutputPath, $reportPath)) {
    $fullPath = [System.IO.Path]::GetFullPath($path)
    if ($fullPath.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relativePath = $fullPath.Substring($repoRoot.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
        if ($resultArtifacts -notcontains $relativePath) { $resultArtifacts += $relativePath }
    }
}

$result = [pscustomobject]@{
    schema = "tbg.harness.result.v1"
    action = $Action
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    repoRoot = $repoRoot
    branch = $branch
    contractId = $ContractId
    status = $Status
    verdict = $Verdict
    findings = @($Findings)
    missingPrereqs = @($MissingPrereqs)
    forbiddenScopeTouched = $ForbiddenScopeTouched
    artifacts = @($resultArtifacts)
}

Import-Module (Join-Path $PSScriptRoot "TbgEffectivePolicy.psm1") -Force
$json = Write-TbgPolicyReport -ResultObject $result -JsonPath $OutputPath -MarkdownPath $reportPath -ProfileId $ContractId -RowType "result" -RepoRoot $repoRoot -Title $Action
Write-Output $json
