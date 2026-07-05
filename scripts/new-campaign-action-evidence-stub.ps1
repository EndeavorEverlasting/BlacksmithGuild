# Create a schema-valid CampaignActionEvidence stub for future engine integration.

param(
    [string]$Engine = 'Unknown',
    [string]$Action = 'unknown_action',
    [string]$Mode = 'Manual',
    [string]$RunId = $null,
    [string]$OutputPath = $null,
    [switch]$Terminal
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $RunId) { $RunId = 'campaign-' + (Get-Date -Format 'yyyyMMdd-HHmmss') }
if (-not $OutputPath) { $OutputPath = Join-Path $repoRoot 'BlacksmithGuild_CampaignActionEvidence.json' }

function Invoke-GitText {
    param([string[]]$Args)
    try {
        $out = & git -C $repoRoot @Args 2>$null
        if ($LASTEXITCODE -eq 0) { return (($out | ForEach-Object { [string]$_ }) -join "`n").Trim() }
    } catch { }
    return $null
}

$branch = Invoke-GitText @('rev-parse', '--abbrev-ref', 'HEAD')
$headSha = Invoke-GitText @('rev-parse', 'HEAD')

$evidence = [pscustomobject][ordered]@{
    schema = 'TbgCampaignActionEvidence.v1'
    generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    runId = $RunId
    branch = $branch
    headSha = $headSha
    engine = $Engine
    action = $Action
    mode = $Mode
    authorityAllowed = $false
    preState = [ordered]@{}
    actionRequested = [ordered]@{
        stub = $true
        note = 'Stub evidence only. Runtime engine integration has not populated action request details.'
    }
    actionResult = [ordered]@{
        status = 'not_run_stub'
        note = 'This file validates schema shape only.'
    }
    postState = [ordered]@{}
    delta = [ordered]@{}
    evidenceFiles = @()
    allowedClaims = @('CampaignActionEvidence schema was generated.')
    forbiddenClaims = @('This does not prove gameplay action execution.', 'This does not prove runtime state mutation.')
    nextAction = [ordered]@{
        title = 'Wire runtime engine to populate CampaignActionEvidence fields.'
        required = $true
    }
    terminal = [bool]$Terminal
}

$evidence | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host ("Wrote CampaignActionEvidence stub: {0}" -f $OutputPath) -ForegroundColor Green
