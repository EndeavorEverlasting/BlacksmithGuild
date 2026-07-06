# Presents the repo-owned agent orchestration map.
$ErrorActionPreference = 'Stop'

param(
    [ValidateSet('summary','paths','markdown','mermaid','mir','svg')]
    [string]$Format = 'summary',

    [switch]$Open,

    [switch]$WriteResult
)

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot

$paths = [ordered]@{
    markdown = 'docs\architecture\agent-orchestration-map.md'
    guardrails = 'docs\handoff\orchestration-map-guardrails.md'
    mermaid = 'docs\assets\agent-orchestration-map.mmd'
    mir = 'docs\assets\agent-orchestration-map.mir.json'
    svg = 'docs\assets\agent-orchestration-map.svg'
}

function Resolve-TbgMapPath {
    param([string]$RelativePath)
    return Join-Path $repoRoot $RelativePath
}

function Assert-TbgMapFile {
    param([string]$Key)
    $path = Resolve-TbgMapPath -RelativePath $paths[$Key]
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing orchestration map artifact: $($paths[$Key])"
    }
    return $path
}

foreach ($key in $paths.Keys) { Assert-TbgMapFile -Key $key | Out-Null }

$mirPath = Assert-TbgMapFile -Key 'mir'
$mir = Get-Content -LiteralPath $mirPath -Raw | ConvertFrom-Json

$result = [ordered]@{
    schema = 'tbg.orchestrationMapPresentation.v1'
    generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    format = $Format
    title = $mir.title
    subtitle = $mir.subtitle
    files = $paths
    sourceOfTruth = [ordered]@{
        editable = $paths.mermaid
        machineReadable = $paths.mir
        presentation = $paths.svg
        explanation = $paths.markdown
        guardrails = $paths.guardrails
    }
    flow = @(
        'Explore agent 1, Explore agent 2, and Explore agent 3',
        'Plan - writes plan.md',
        'Implement - writes report.md',
        'Review agent 1 - security',
        'Review agent 2 - correctness',
        'Review agent 3 - simplify',
        'Done - Open PR'
    )
}

if ($WriteResult) {
    $latestDir = Join-Path $repoRoot 'artifacts\latest'
    New-Item -ItemType Directory -Force -Path $latestDir | Out-Null
    $resultPath = Join-Path $latestDir 'agent-orchestration-map.result.json'
    $result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resultPath -Encoding UTF8
}

switch ($Format) {
    'paths' {
        Write-Host 'TBG agent orchestration map artifacts:'
        foreach ($key in $paths.Keys) { Write-Host ("{0}: {1}" -f $key, $paths[$key]) }
    }
    'markdown' {
        Get-Content -LiteralPath (Assert-TbgMapFile -Key 'markdown') -Raw
    }
    'mermaid' {
        Get-Content -LiteralPath (Assert-TbgMapFile -Key 'mermaid') -Raw
    }
    'mir' {
        Get-Content -LiteralPath (Assert-TbgMapFile -Key 'mir') -Raw
    }
    'svg' {
        Get-Content -LiteralPath (Assert-TbgMapFile -Key 'svg') -Raw
    }
    default {
        Write-Host 'TBG agent orchestration map'
        Write-Host "Title: $($result.title)"
        Write-Host "Editable Mermaid: $($paths.mermaid)"
        Write-Host "Machine-readable MIR: $($paths.mir)"
        Write-Host "Presentation SVG: $($paths.svg)"
        Write-Host "Guardrails: $($paths.guardrails)"
        Write-Host ''
        Write-Host 'Flow:'
        foreach ($step in $result.flow) { Write-Host "- $step" }
    }
}

if ($Open) {
    $openTarget = switch ($Format) {
        'mermaid' { Assert-TbgMapFile -Key 'mermaid' }
        'mir' { Assert-TbgMapFile -Key 'mir' }
        'svg' { Assert-TbgMapFile -Key 'svg' }
        'markdown' { Assert-TbgMapFile -Key 'markdown' }
        default { Assert-TbgMapFile -Key 'markdown' }
    }
    Invoke-Item -LiteralPath $openTarget
}

exit 0
