Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$stdin = [Console]::In.ReadToEnd()
$commandText = ""
try {
    if (-not [string]::IsNullOrWhiteSpace($stdin)) {
        $payload = $stdin | ConvertFrom-Json
        if ($payload.tool_input.command) { $commandText = [string]$payload.tool_input.command }
    }
} catch {
    $commandText = $stdin
}

if ([string]::IsNullOrWhiteSpace($commandText)) {
    $commandText = $env:TBG_HOOK_COMMAND_TEXT
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "../..")
$validator = Join-Path $repoRoot "scripts/harness/Test-TbgCommandSafety.ps1"
$resultJson = & $validator -CommandText $commandText
$result = $resultJson | ConvertFrom-Json

if ($result.decision -eq "deny") {
    Write-Error $result.reason
    exit 2
}

Write-Output $resultJson
