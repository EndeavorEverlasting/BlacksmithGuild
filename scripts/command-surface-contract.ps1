# Command and hotkey surface governance contract helpers.
# Stub/contract layer only. Future command/hotkey registration should replace the
# stub catalog with the real runtime command surface.

function Get-TbgCommandSurfaceCatalog {
    return @(
        [pscustomobject]@{ commandName = 'AssistiveLeaveTownAndTravel'; hotkey = $null; ownerFeature = 'travel'; safetyLevel = 'mutating'; mutatesGameplay = $true; evidenceArtifact = 'BlacksmithGuild_AssistiveTravelExecution.json'; knownConflict = $null; status = 'stub' },
        [pscustomobject]@{ commandName = 'ProbeSmithingAudit'; hotkey = $null; ownerFeature = 'smithing'; safetyLevel = 'read_only'; mutatesGameplay = $false; evidenceArtifact = 'BlacksmithGuild_SmithingAudit.json'; knownConflict = $null; status = 'stub' },
        [pscustomobject]@{ commandName = 'ProbeSmithingRefineApi'; hotkey = $null; ownerFeature = 'smithing'; safetyLevel = 'mutating_probe'; mutatesGameplay = $true; evidenceArtifact = 'BlacksmithGuild_SmithingRefineProbe.json'; knownConflict = $null; status = 'stub' },
        [pscustomobject]@{ commandName = 'MarketIntel'; hotkey = 'F12'; ownerFeature = 'market'; safetyLevel = 'read_only'; mutatesGameplay = $false; evidenceArtifact = 'BlacksmithGuild_MarketIntel.json'; knownConflict = 'Steam screenshot hotkey'; status = 'stub' }
    )
}

function Test-TbgCommandSurfaceEntry {
    param([object]$Entry)

    if (-not $Entry) { return $false }
    if ([string]::IsNullOrWhiteSpace([string]$Entry.commandName)) { return $false }
    if ([string]::IsNullOrWhiteSpace([string]$Entry.ownerFeature)) { return $false }
    if ([string]::IsNullOrWhiteSpace([string]$Entry.safetyLevel)) { return $false }
    if ($Entry.mutatesGameplay -eq $true -and [string]::IsNullOrWhiteSpace([string]$Entry.evidenceArtifact)) { return $false }
    return $true
}

function Assert-TbgCommandSurfaceGovernance {
    param([object[]]$Catalog = $(Get-TbgCommandSurfaceCatalog))

    foreach ($entry in @($Catalog)) {
        if (-not (Test-TbgCommandSurfaceEntry -Entry $entry)) {
            throw "invalid command surface entry: $($entry | ConvertTo-Json -Compress -Depth 6)"
        }
    }
    return $true
}

function ConvertTo-TbgCommandSurfaceMarkdown {
    param([object[]]$Catalog = $(Get-TbgCommandSurfaceCatalog))

    Assert-TbgCommandSurfaceGovernance -Catalog $Catalog | Out-Null
    $lines = @('| Command | Hotkey | Feature | Safety | Mutates | Evidence | Conflict |','| --- | --- | --- | --- | --- | --- | --- |')
    foreach ($entry in @($Catalog | Sort-Object commandName)) {
        $lines += "| $($entry.commandName) | $($entry.hotkey) | $($entry.ownerFeature) | $($entry.safetyLevel) | $($entry.mutatesGameplay) | $($entry.evidenceArtifact) | $($entry.knownConflict) |"
    }
    return ($lines -join [Environment]::NewLine)
}

function Write-TbgCommandSurfaceReport {
    param(
        [object[]]$Catalog = $(Get-TbgCommandSurfaceCatalog),
        [string]$Path
    )

    $markdown = ConvertTo-TbgCommandSurfaceMarkdown -Catalog $Catalog
    if ($Path) {
        $dir = Split-Path -Parent $Path
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        Set-Content -LiteralPath $Path -Value $markdown -Encoding UTF8
    }
    return $markdown
}
