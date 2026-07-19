[CmdletBinding()]
param(
  [string]$RepoRoot = '',
  [string]$OutputRoot = 'artifacts/latest/one-click-test'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
$RepoRoot = [IO.Path]::GetFullPath($RepoRoot)

$errors = [System.Collections.Generic.List[string]]::new()
$passes = 0

function Add-Check([bool]$Condition,[string]$Name,[string]$Message='contract failed') {
  if ($Condition) { $script:passes++; Write-Host "[PASS] $Name" -ForegroundColor Green }
  else { $script:errors.Add("${Name}: $Message"); Write-Host "[FAIL] $Name - $Message" -ForegroundColor Red }
}

function RepoPath([string]$Relative) { Join-Path $RepoRoot ($Relative -replace '/', [IO.Path]::DirectorySeparatorChar) }
function ReadJson([string]$Relative) { Get-Content -LiteralPath (RepoPath $Relative) -Raw | ConvertFrom-Json }

# Required files
$required = @(
  'ForgeTest.cmd',
  'scripts/tbg/Invoke-TbgOneClickTest.ps1',
  'scripts/tbg/Write-TbgLiveTestConsole.ps1',
  'scripts/tbg/Test-TbgOneClickTestSpine.ps1',
  '.tbg/workflows/one-click-test.contract.json',
  '.tbg/harness/schemas/one-click-test-run-context.schema.json',
  '.tbg/harness/schemas/one-click-test-catalog-entry.schema.json',
  '.tbg/harness/schemas/one-click-test-profile.schema.json',
  '.tbg/harness/schemas/one-click-test-event.schema.json',
  '.tbg/harness/schemas/one-click-test-artifact-registry.schema.json',
  '.tbg/harness/schemas/one-click-test-result.schema.json'
)
foreach ($item in $required) { Add-Check (Test-Path -LiteralPath (RepoPath $item) -PathType Leaf) "required/$item" }

# Test profiles
$profiles = @('default-static', 'operator-observe')
foreach ($p in $profiles) {
  Add-Check (Test-Path -LiteralPath (RepoPath ".tbg/harness/test-profiles.d/$p.profile.json") -PathType Leaf) "profile/$p"
}

# Parser checks
$scripts = @(
  'scripts/tbg/Invoke-TbgOneClickTest.ps1',
  'scripts/tbg/Write-TbgLiveTestConsole.ps1',
  'scripts/tbg/Test-TbgOneClickTestSpine.ps1'
)
foreach ($s in $scripts) {
  $path = RepoPath $s
  if (Test-Path -LiteralPath $path -PathType Leaf) {
    $tokens = $null; $parseErrors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$parseErrors)
    Add-Check ($parseErrors.Count -eq 0) "parse/$s" (($parseErrors | ForEach-Object Message) -join '; ')
  }
}

# Schema parsing
$schemas = @(
  'one-click-test-run-context.schema.json',
  'one-click-test-catalog-entry.schema.json',
  'one-click-test-profile.schema.json',
  'one-click-test-event.schema.json',
  'one-click-test-artifact-registry.schema.json',
  'one-click-test-result.schema.json'
)
foreach ($s in $schemas) {
  $path = RepoPath ".tbg/harness/schemas/$s"
  if (Test-Path -LiteralPath $path -PathType Leaf) {
    try { $j = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json; Add-Check ($null -ne $j) "json/$s" } catch { Add-Check $false "json/$s" $_.Exception.Message }
  }
}

# Workflow contract
$wc = ReadJson '.tbg/workflows/one-click-test.contract.json'
Add-Check ($wc.schema -eq 'tbg.workflow-contract.v1') 'contract/schema'
Add-Check ($wc.id -eq 'one-click-test') 'contract/id'

# ForgeTest.cmd
$forgeTestBytes = [IO.File]::ReadAllBytes((RepoPath 'ForgeTest.cmd'))
Add-Check ($forgeTestBytes.Length -gt 0) 'ForgeTest.cmd/exists'

# Catalog directory
$catalogDir = RepoPath '.tbg/harness/test-catalog.d'
Add-Check (Test-Path -LiteralPath $catalogDir -PathType Container) 'catalog/dir'

# Profile parsing
foreach ($p in $profiles) {
  try {
    $pp = ReadJson ".tbg/harness/test-profiles.d/$p.profile.json"
    Add-Check ($pp.schema -eq 'tbg.one-click-test.profile.v1') "profile/$p/schema"
    Add-Check ($null -ne $pp.profileId) "profile/$p/id"
  } catch { Add-Check $false "profile/$p/parse" }
}

# Forbidden patterns
$textFiles = @('ForgeTest.cmd', 'scripts/tbg/Invoke-TbgOneClickTest.ps1', 'scripts/tbg/Write-TbgLiveTestConsole.ps1')
$text = ($textFiles | ForEach-Object { Get-Content (RepoPath $_) -Raw }) -join "`n"
foreach ($pattern in @('C:\\Users\\Cheex', 'localhost:11434', 'OPENAI_API_KEY', 'ANTHROPIC_API_KEY')) {
  Add-Check (-not $text.Contains($pattern)) "forbidden/$pattern"
}

# BOM check on PS1 files
foreach ($s in $scripts) {
  $path = RepoPath $s
  if (Test-Path -LiteralPath $path -PathType Leaf) {
    $bytes = [IO.File]::ReadAllBytes($path)
    Add-Check ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) "bom/$s"
  }
}

# Results
$outputPath = if ([IO.Path]::IsPathRooted($OutputRoot)) { [IO.Path]::GetFullPath($OutputRoot) } else { RepoPath $OutputRoot }
New-Item -ItemType Directory -Force -Path $outputPath | Out-Null

$status = if ($errors.Count -eq 0) { 'PASS' } else { 'FAIL' }
[ordered]@{
  schema = 'tbg.one-click-test-spine-result.v1'
  generatedUtc = [DateTime]::UtcNow.ToString('o')
  status = $status
  passes = $passes
  errors = @($errors)
  proofLevel = 'static test'
  proofCeiling = 'Validates that the one-click test spine files exist, parse, and satisfy contract requirements. No build, launcher, or runtime proof is established.'
  claimsNotMade = @('build', 'launcher', 'command ACK', 'behavior', 'live runtime', 'deployment')
} | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $outputPath 'one-click-test-spine.validation.json') -Encoding UTF8

Write-Host "One-Click Test Spine validation: $status - $passes passed, $($errors.Count) failed"
if ($errors.Count -gt 0) {
  foreach ($e in $errors) { Write-Host "  FAIL: $e" -ForegroundColor Red }
  exit 1
}
