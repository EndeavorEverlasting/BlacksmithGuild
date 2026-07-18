# GuildLoopReport contract helpers.
# Stub/contract layer only. Future report generation should unify market, forge,
# smithing, travel, advisory, and latest proof artifacts through this shape.

function New-TbgGuildLoopReport {
    param(
        [string]$Location = $null,
        [string]$CurrentAction = $null,
        [string]$NextAction = $null,
        [string]$BlockingResource = $null,
        [object[]]$SourceArtifacts = @(),
        [object]$LastProof = $null
    )

    return [pscustomobject]@{
        schemaVersion = 1
        location = $Location
        currentAction = $CurrentAction
        nextAction = $NextAction
        blockingResource = $BlockingResource
        sourceArtifacts = @($SourceArtifacts)
        lastProof = $LastProof
        generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    }
}

function Test-TbgGuildLoopReportComplete {
    param([object]$Report)

    if (-not $Report) { return $false }
    foreach ($field in @('location','nextAction')) {
        if ([string]::IsNullOrWhiteSpace([string]$Report.$field)) { return $false }
    }
    if (-not $Report.sourceArtifacts -or @($Report.sourceArtifacts).Count -eq 0) { return $false }
    return $true
}

function Assert-TbgGuildLoopReportComplete {
    param([object]$Report)

    if (-not (Test-TbgGuildLoopReportComplete -Report $Report)) {
        throw 'GuildLoopReport incomplete: location, nextAction, and sourceArtifacts are required'
    }
    return $true
}

function Write-TbgGuildLoopReport {
    param(
        [object]$Report,
        [string]$Path
    )

    Assert-TbgGuildLoopReportComplete -Report $Report | Out-Null
    if ($Path) {
        $dir = Split-Path -Parent $Path
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        $Report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8
    }
    return $Report
}
