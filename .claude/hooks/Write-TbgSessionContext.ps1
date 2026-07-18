Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "../..")
$contextScript = Join-Path $repoRoot "scripts/harness/Get-TbgHarnessContext.ps1"

if (Test-Path -LiteralPath $contextScript) {
    & $contextScript -Json
} else {
    Write-Output "[TBG | Harness Missing | unable to resolve scripts/harness/Get-TbgHarnessContext.ps1]"
}
