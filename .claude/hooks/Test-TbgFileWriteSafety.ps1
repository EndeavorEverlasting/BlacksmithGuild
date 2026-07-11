Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$stdin = [Console]::In.ReadToEnd()
$pathText = ""
try {
    if (-not [string]::IsNullOrWhiteSpace($stdin)) {
        $payload = $stdin | ConvertFrom-Json
        if ($payload.tool_input.file_path) { $pathText = [string]$payload.tool_input.file_path }
        elseif ($payload.tool_input.path) { $pathText = [string]$payload.tool_input.path }
    }
} catch {
    $pathText = $stdin
}

if ([string]::IsNullOrWhiteSpace($pathText)) {
    $pathText = $env:TBG_HOOK_PATH_TEXT
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "../..")
$validator = Join-Path $repoRoot "scripts/harness/Test-TbgFileSafety.ps1"
$resultJson = & $validator -PathText $pathText
$result = $resultJson | ConvertFrom-Json

if ($result.decision -eq "deny") {
    Write-Error $result.reason
    exit 2
}

Write-Output $resultJson
