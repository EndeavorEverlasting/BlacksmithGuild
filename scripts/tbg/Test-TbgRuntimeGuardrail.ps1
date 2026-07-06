param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('docs', 'static-review', 'patch', 'build', 'install', 'launch', 'live-cert', 'route-visible-start')]
    [string]$Intent,

    [switch]$StoppedGameConfirmed,

    [switch]$Json
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $repoRoot

$requiresInactiveGame = @{
    'docs' = $false
    'static-review' = $false
    'patch' = $true
    'build' = $true
    'install' = $true
    'launch' = $true
    'live-cert' = $true
    'route-visible-start' = $true
}

$requiredPreflight = @(
    "$env:FORGE_NO_PAUSE = '1'",
    "$env:FORGE_STOP_CHOICE = 'F'",
    "$env:FORGE_STOP_DEFAULT = 'F'",
    "$env:FORGE_STOP_TIMEOUT_SECONDS = '0'",
    "cmd /c .\ForgeStop.cmd force"
)

$branch = $null
try {
    $branch = (git branch --show-current).Trim()
} catch {
    $branch = $null
}

$result = [ordered]@{
    guardrail = 'runtime-state-preflight'
    intent = $Intent
    branch = $branch
    requiresInactiveGame = [bool]$requiresInactiveGame[$Intent]
    stoppedGameConfirmed = [bool]$StoppedGameConfirmed
    verdict = 'PASS'
    blockedReason = $null
    nextPatchHint = $null
    requiredPreflight = $requiredPreflight
}

if ($requiresInactiveGame[$Intent] -and -not $StoppedGameConfirmed) {
    $result.verdict = 'BLOCKED'
    $result.blockedReason = 'runtime-state guardrail requires ForgeStop before this intent'
    $result.nextPatchHint = "Run the required preflight from this result, then rerun this checker with -StoppedGameConfirmed."

    if ($Json) {
        $result | ConvertTo-Json -Depth 8
    } else {
        Write-Host "BLOCKED: $($result.blockedReason)" -ForegroundColor Yellow
        Write-Host 'Required preflight:'
        foreach ($line in $requiredPreflight) {
            Write-Host $line
        }
        Write-Host $result.nextPatchHint
    }
    exit 2
}

if ($Json) {
    $result | ConvertTo-Json -Depth 8
} else {
    Write-Host "PASS: runtime-state guardrail satisfied for intent '$Intent'."
}
