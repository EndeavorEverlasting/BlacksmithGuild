param(
    [string]$ContractId = "local-mcp-code-intelligence"
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

function Test-CommandAvailable {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    return ($null -ne $cmd)
}

function Test-JsonFile {
    param([string]$Path)
    try {
        Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json | Out-Null
        return $true
    } catch {
        return $false
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
$findings = New-Object System.Collections.Generic.List[string]
$missing = New-Object System.Collections.Generic.List[string]

$requiredFiles = @(
    ".tbg/harness/manifest.json",
    ".tbg/workflows/$ContractId.contract.json",
    ".tbg/harness/policies/command-safety.policy.json",
    ".tbg/harness/policies/file-safety.policy.json",
    ".tbg/harness/policies/runtime-scope.policy.json",
    ".tbg/harness/policies/evidence-gates.policy.json"
)

foreach ($relative in $requiredFiles) {
    $full = Join-Path $repoRoot $relative
    if (-not (Test-Path -LiteralPath $full)) {
        $missing.Add($relative)
    } elseif (-not (Test-JsonFile -Path $full)) {
        $missing.Add("invalid-json:$relative")
    } else {
        $findings.Add("json-ok:$relative")
    }
}

foreach ($tool in @("git", "dotnet", "node", "go")) {
    if (Test-CommandAvailable -Name $tool) {
        $findings.Add("tool-ok:$tool")
    } else {
        $missing.Add("tool-missing:$tool")
    }
}

if ($PSVersionTable.PSVersion) {
    $findings.Add("powershell-version:$($PSVersionTable.PSVersion.ToString())")
}

$projectPath = Join-Path $repoRoot "src/BlacksmithGuild/BlacksmithGuild.csproj"
if (Test-Path -LiteralPath $projectPath) {
    $findings.Add("project-ok:src/BlacksmithGuild/BlacksmithGuild.csproj")
} else {
    $missing.Add("project-missing:src/BlacksmithGuild/BlacksmithGuild.csproj")
}

$solutionFiles = Get-ChildItem -LiteralPath $repoRoot -Filter "*.sln" -File -ErrorAction SilentlyContinue
if ($solutionFiles.Count -gt 0) {
    $findings.Add("solution-count:$($solutionFiles.Count)")
} else {
    $findings.Add("solution-count:0")
}

Push-Location $repoRoot
try {
    $branch = Invoke-Capture -FileName "git" -Arguments @("rev-parse", "--abbrev-ref", "HEAD")
    $statusShort = Invoke-Capture -FileName "git" -Arguments @("status", "--short")
} finally { Pop-Location }
if ([string]::IsNullOrWhiteSpace($branch)) { $branch = "unknown" }
if ($null -eq $statusShort) { $statusShort = "" }

$status = "ready"
$verdict = "harness_readiness_ready"
if ($missing.Count -gt 0) {
    $status = "missing_prereqs"
    $verdict = "harness_readiness_missing_prereqs"
}
if ($missing -contains ".tbg/harness/manifest.json") {
    $status = "repo_invalid"
    $verdict = "harness_readiness_repo_invalid"
}

$artifactDir = Join-Path $repoRoot "artifacts/latest"
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
$artifactPath = Join-Path $artifactDir "harness-readiness.result.json"

$result = [pscustomobject]@{
    schema = "tbg.harness.result.v1"
    action = "TestHarnessReadiness"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    repoRoot = $repoRoot
    branch = $branch
    contractId = $ContractId
    status = $status
    verdict = $verdict
    findings = @($findings)
    missingPrereqs = @($missing)
    forbiddenScopeTouched = $false
    artifacts = @("artifacts/latest/harness-readiness.result.json")
    gitStatusShort = $statusShort
}

$result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $artifactPath -Encoding UTF8
$result | ConvertTo-Json -Depth 20
