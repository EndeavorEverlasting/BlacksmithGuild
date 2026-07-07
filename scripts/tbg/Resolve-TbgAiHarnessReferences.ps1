# Resolves the local AI harness reference shelf without hard-coding a Windows user name.
$ErrorActionPreference = 'Stop'

param(
    [string]$ReferenceRoot = '',
    [switch]$WriteResult
)

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot

if ([string]::IsNullOrWhiteSpace($ReferenceRoot)) {
    if (-not [string]::IsNullOrWhiteSpace($env:TBG_AI_HARNESS_REFERENCE_ROOT)) {
        $ReferenceRoot = $env:TBG_AI_HARNESS_REFERENCE_ROOT
    }
    elseif (-not [string]::IsNullOrWhiteSpace($env:AI_HARNESS_REFERENCE_ROOT)) {
        $ReferenceRoot = $env:AI_HARNESS_REFERENCE_ROOT
    }
    else {
        $ReferenceRoot = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Desktop\dev\references\ai-harnesses'
    }
}

$archonPath = Join-Path $ReferenceRoot 'Archon'
$helplinePath = Join-Path $ReferenceRoot 'helpline'

$result = [ordered]@{
    schema = 'tbg.aiHarnessReferences.v1'
    generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    referenceRoot = $ReferenceRoot
    rootExists = Test-Path -LiteralPath $ReferenceRoot
    references = [ordered]@{
        Archon = [ordered]@{
            path = $archonPath
            exists = Test-Path -LiteralPath $archonPath
        }
        helpline = [ordered]@{
            path = $helplinePath
            exists = Test-Path -LiteralPath $helplinePath
        }
    }
    guidance = 'Use repo-local BlacksmithGuild harness rules first. Inspect references only when local rules are insufficient. If missing, report missing_reference and continue from repo-local contracts.'
}

if ($WriteResult) {
    $latestDir = Join-Path $repoRoot 'artifacts\latest'
    New-Item -ItemType Directory -Force -Path $latestDir | Out-Null
    $resultPath = Join-Path $latestDir 'ai-harness-references.result.json'
    $result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resultPath -Encoding UTF8
}

$result | ConvertTo-Json -Depth 10
exit 0
