# Optional startup-grace wrapper for the immediate autonomous guild-loop controller.
# Normal play uses run-autonomous-guild-loop-immediate.ps1 directly with no delay.

param(
    [int]$TimeoutSec = 60,
    [ValidateRange(3, 5)]
    [int]$QuitGraceSec = 5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'governor-operator-common.ps1')

$latestDir = Join-Path $repoRoot 'artifacts\latest'
New-Item -ItemType Directory -Force -Path $latestDir | Out-Null
$resultPath = Join-Path $latestDir 'autonomous-guild-loop-operator.json'
$reportPath = Join-Path $latestDir 'autonomous-guild-loop-operator.md'

function Read-TbgTimedKey {
    param(
        [Parameter(Mandatory = $true)][string[]]$AllowedKeys,
        [Parameter(Mandatory = $true)][int]$Seconds
    )

    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        try {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                $name = [string]$key.Key
                if ($AllowedKeys -contains $name) {
                    Write-Host ''
                    return $name
                }
            }
        }
        catch {
            # Non-interactive hosts simply allow the bounded default to win.
        }

        $remaining = [Math]::Max(0, [int][Math]::Ceiling(($deadline - (Get-Date)).TotalSeconds))
        Write-Host ("`r[TBG] Continuing in {0}s... " -f $remaining) -NoNewline -ForegroundColor DarkYellow
        Start-Sleep -Milliseconds 100
    }

    Write-Host ''
    return $null
}

function Write-TbgTimedResult {
    param(
        [Parameter(Mandatory = $true)][string]$Verdict,
        [Parameter(Mandatory = $true)][string]$Reason
    )

    $payload = [ordered]@{
        schemaVersion = 'TbgAutonomousGuildLoopOperatorResult.v2'
        generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
        mode = 'timed_grace'
        quitGraceSec = $QuitGraceSec
        verdict = $Verdict
        reason = $Reason
        immediateControllerStarted = $false
    }
    $payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $resultPath -Encoding UTF8

    @(
        '# Autonomous Guild Loop Operator Result',
        '',
        '- Mode: timed startup grace',
        "- Startup grace seconds: $QuitGraceSec",
        "- Verdict: $Verdict",
        "- Reason: $Reason",
        '- Immediate controller started: false',
        "- JSON: $resultPath"
    ) | Set-Content -LiteralPath $reportPath -Encoding UTF8

    Write-Host "[TBG] $Verdict - $Reason" -ForegroundColor Yellow
    Write-Host "[TBG] Result: $resultPath" -ForegroundColor Cyan
}

if (Test-GovernorStopRequested -RepoRoot $repoRoot) {
    Write-Host "[TBG] Quit context is active. Press C within ${QuitGraceSec}s to cancel the quit and run automation." -ForegroundColor Yellow
    $choice = Read-TbgTimedKey -AllowedKeys @('C') -Seconds $QuitGraceSec
    if ($choice -eq 'C') {
        Clear-GovernorStopSentinel -RepoRoot $repoRoot
        Write-Host '[TBG] Quit cancelled. Starting automation now.' -ForegroundColor Green
    }
    else {
        Write-TbgTimedResult -Verdict 'USER_QUIT_HONORED' -Reason 'The active ForgeStop context remained after the optional change-mind window.'
        exit 0
    }
}
else {
    Write-Host "[TBG] Optional startup grace. Press Q or Escape within ${QuitGraceSec}s to quit; otherwise automation starts." -ForegroundColor Yellow
    $choice = Read-TbgTimedKey -AllowedKeys @('Q', 'Escape') -Seconds $QuitGraceSec
    if ($choice) {
        $sentinel = Write-GovernorStopSentinel -RepoRoot $repoRoot -Reason 'operator cancelled autonomous guild-loop startup during optional grace'
        Write-TbgTimedResult -Verdict 'USER_QUIT_REQUESTED' -Reason "Operator pressed $choice during the optional startup window. Stop sentinel: $sentinel"
        exit 0
    }
}

& (Join-Path $PSScriptRoot 'run-autonomous-guild-loop-immediate.ps1') -TimeoutSec $TimeoutSec
exit $LASTEXITCODE
