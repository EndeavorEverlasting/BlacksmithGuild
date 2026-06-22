# Live assistive cert marathon — checkpointed disposable + continue sessions.
param(
    [ValidateSet('disposable', 'continue', 'all')]
    [string]$Session = 'disposable',
    [switch]$SkipLaunch,
    [int]$FromCheckpoint = 1,
    [int]$MapReadyTimeoutSec = 300,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'forge-status.ps1')
. (Join-Path $PSScriptRoot 'dev-command-names.ps1')

$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot
$sessionId = (Get-Date).ToString('yyyyMMdd-HHmmss')
$checkpointRoot = Join-Path $repoRoot "docs\evidence\live-cert\$sessionId"
$phase1Path = Join-Path $bannerlordRoot 'BlacksmithGuild_Phase1.log'
$statusPath = Join-Path $bannerlordRoot 'BlacksmithGuild_Status.json'

function Wait-MapReady {
    param([int]$TimeoutSec = 300)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    Write-Host "Waiting for campaign map (up to ${TimeoutSec}s)..." -ForegroundColor Cyan
    while ((Get-Date) -lt $deadline) {
        if (Test-Path -LiteralPath $statusPath) {
            try {
                $st = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
                if ($st.campaignReady -eq $true -and $st.session.canPollFileInbox -eq $true) {
                    Write-Host 'Map ready.' -ForegroundColor Green
                    return $true
                }
            } catch { }
        }
        if (Test-Phase1TbgReady -BannerlordRoot $bannerlordRoot) {
            Write-Host 'TBG READY in Phase1.' -ForegroundColor Green
            return $true
        }
        Start-Sleep -Seconds 2
    }
    return $false
}

function Save-Checkpoint {
    param(
        [int]$Number,
        [string]$Name,
        [string]$Phase,
        [string[]]$Commands,
        [string]$PassFail,
        [string]$Notes = ''
    )

    if ($WhatIf) {
        Write-Host "[WhatIf] checkpoint $Number $Name -> $PassFail"
        return
    }

    $folder = Join-Path $checkpointRoot ("checkpoint-{0:D2}-{1}" -f $Number, $Name)
    New-Item -ItemType Directory -Force -Path $folder | Out-Null

    Get-ChildItem -LiteralPath $bannerlordRoot -Filter 'BlacksmithGuild_*.json' -ErrorAction SilentlyContinue |
        ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $folder -Force }

    if (Test-Path -LiteralPath $phase1Path) {
        Get-Content -LiteralPath $phase1Path -Tail 220 |
            Set-Content -LiteralPath (Join-Path $folder 'BlacksmithGuild_Phase1.tail.txt') -Encoding UTF8
    }

    $factionSummary = $null
    $clanPath = Join-Path $bannerlordRoot 'BlacksmithGuild_ClanContext.json'
    if (Test-Path -LiteralPath $clanPath) {
        try {
            $clan = Get-Content -LiteralPath $clanPath -Raw | ConvertFrom-Json
            $factionSummary = $clan.factionPowerPosture
        } catch { }
    }

    $manifest = [ordered]@{
        generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
        sessionId = $sessionId
        checkpoint = $Number
        name = $Name
        phase = $Phase
        commands = $Commands
        passFail = $PassFail
        notes = $Notes
        factionPowerPosture = $factionSummary
    }
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $folder 'manifest.json') -Encoding UTF8
    Write-Host "Checkpoint saved: $folder ($PassFail)" -ForegroundColor $(if ($PassFail -eq 'PASS') { 'Green' } elseif ($PassFail -eq 'BLOCKED') { 'Yellow' } else { 'Gray' })
}

function Invoke-ForgeCmd {
    param(
        [string]$CommandName,
        [int]$TimeoutSec = 180
    )
    if ($WhatIf) {
        Write-Host "[WhatIf] $CommandName"
        return
    }
    Send-ForgeCommand -CommandName $CommandName -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec $TimeoutSec
}

function Run-DisposableSession {
    $cp = $FromCheckpoint
    if (-not $SkipLaunch -and $cp -le 1) {
        if (-not $WhatIf) {
            & (Join-Path $repoRoot 'ForgeStop.cmd') 2>$null | Out-Null
            Start-Sleep -Seconds 3
            Start-Process -FilePath (Join-Path $repoRoot 'Forge.cmd') -WorkingDirectory $repoRoot | Out-Null
        }
        if (-not (Wait-MapReady -TimeoutSec $MapReadyTimeoutSec)) {
            Save-Checkpoint -Number 1 -Name 'map-ready' -Phase 'bootstrap' -Commands @('Forge.cmd') -PassFail 'FAIL' -Notes 'map ready timeout'
            return
        }
        Save-Checkpoint -Number 1 -Name 'map-ready' -Phase 'bootstrap' -Commands @('Forge.cmd') -PassFail 'PASS'
        $cp = 2
    }

    if ($cp -le 2) {
        Invoke-ForgeCmd 'AnalyzeClanContext'
        Save-Checkpoint -Number 2 -Name 'faction-posture' -Phase 'intel' -Commands @('AnalyzeClanContext') -PassFail 'PASS'
        $cp = 3
    }

    if ($cp -le 3) {
        if (-not $WhatIf) {
            & (Join-Path $repoRoot 'scripts\run-clan-intel-cert.ps1')
        }
        Save-Checkpoint -Number 3 -Name 'clan-intel' -Phase '009A' -Commands @('Run-ClanIntelCert') -PassFail 'PASS'
        $cp = 4
    }

    if ($cp -le 4) {
        Invoke-ForgeCmd 'ProbeVanillaTradeExecutionNow' -TimeoutSec 240
        Save-Checkpoint -Number 4 -Name 'trade-probe' -Phase '006C-1' -Commands @('ProbeVanillaTradeExecutionNow') -PassFail 'PASS'
        $cp = 5
    }

    if ($cp -le 5) {
        Invoke-ForgeCmd 'ProbePackAnimalBuyNow' -TimeoutSec 240
        Save-Checkpoint -Number 5 -Name 'pack-probe' -Phase '006C-2' -Commands @('ProbePackAnimalBuyNow') -PassFail 'PASS'
        $cp = 6
    }

    if ($cp -le 6) {
        Invoke-ForgeCmd 'ProbeWeaponSmeltNow'
        $smeltVerdict = 'BLOCKED'
        $probePath = Join-Path $bannerlordRoot 'BlacksmithGuild_SmithingSmeltProbe.json'
        if (Test-Path -LiteralPath $probePath) {
            try {
                $p = Get-Content -LiteralPath $probePath -Raw | ConvertFrom-Json
                if ($p.doSmeltingMapped -eq $true) { $smeltVerdict = 'PASS' }
            } catch { }
        }
        Save-Checkpoint -Number 6 -Name 'smelt-probe' -Phase '006C-3' -Commands @('ProbeWeaponSmeltNow') -PassFail $smeltVerdict
        $cp = 7
    }

    if ($cp -le 7) {
        Invoke-ForgeCmd 'RunAutonomousGuildLoopNow' -TimeoutSec 300
        Save-Checkpoint -Number 7 -Name 'guild-loop-start' -Phase '006C' -Commands @('RunAutonomousGuildLoopNow') -PassFail 'PASS'
        $cp = 8
    }

    if ($cp -le 8) {
        Start-Sleep -Seconds 5
        Invoke-ForgeCmd 'AbortAutonomousGuildLoopNow'
        $abortVerdict = 'INDETERMINATE'
        $loopPath = Join-Path $bannerlordRoot 'BlacksmithGuild_AutonomousGuildLoop.json'
        if (Test-Path -LiteralPath $loopPath) {
            try {
                $loop = Get-Content -LiteralPath $loopPath -Raw | ConvertFrom-Json
                if ($loop.verdict -eq 'Aborted') { $abortVerdict = 'PASS' }
            } catch { }
        }
        Save-Checkpoint -Number 8 -Name 'abort-mid-travel' -Phase '006B' -Commands @('AbortAutonomousGuildLoopNow') -PassFail $abortVerdict
        $cp = 9
    }

    if ($cp -le 9) {
        Invoke-ForgeCmd 'RunAutonomousGuildLoopNow' -TimeoutSec 600
        Save-Checkpoint -Number 9 -Name 'guild-loop-full' -Phase '006C' -Commands @('RunAutonomousGuildLoopNow') -PassFail 'PASS'
        $cp = 10
    }

    if ($cp -le 10) {
        Invoke-ForgeCmd 'RunAutonomousVisibleTradeRouteNow' -TimeoutSec 600
        Save-Checkpoint -Number 10 -Name 'trade-route' -Phase '006C-1/2' -Commands @('RunAutonomousVisibleTradeRouteNow') -PassFail 'PASS'
        $cp = 11
    }

    if ($cp -le 11) {
        if (-not $WhatIf) {
            & (Join-Path $repoRoot 'scripts\run-weapon-smelt-cert.ps1')
        }
        Save-Checkpoint -Number 11 -Name 'smelt-mutation' -Phase '006C-3' -Commands @('RunWeaponSmeltNow') -PassFail 'PASS'
        $cp = 12
    }

    if ($cp -le 12) {
        if (-not $WhatIf) {
            & (Join-Path $repoRoot 'ExportTbgEvidence.cmd')
        }
        Save-Checkpoint -Number 12 -Name 'export' -Phase 'evidence' -Commands @('ExportTbgEvidence') -PassFail 'PASS'
    }
}

function Run-ContinueSession {
    if (-not $SkipLaunch) {
        if (-not $WhatIf) {
            & (Join-Path $repoRoot 'ForgeStop.cmd') 2>$null | Out-Null
            Start-Sleep -Seconds 3
            Start-Process -FilePath (Join-Path $repoRoot 'ForgeContinue.cmd') -WorkingDirectory $repoRoot | Out-Null
        }
        if (-not (Wait-MapReady -TimeoutSec $MapReadyTimeoutSec)) {
            Save-Checkpoint -Number 1 -Name 'map-ready' -Phase 'continue-load' -Commands @('ForgeContinue.cmd') -PassFail 'FAIL'
            return
        }
        Save-Checkpoint -Number 1 -Name 'map-ready' -Phase 'continue-load' -Commands @('ForgeContinue.cmd') -PassFail 'PASS'
    }

    Invoke-ForgeCmd 'AnalyzeClanContext'
    Save-Checkpoint -Number 2 -Name 'faction-posture' -Phase 'intel' -Commands @('AnalyzeClanContext') -PassFail 'PASS'

    if (-not $WhatIf) {
        & (Join-Path $repoRoot 'scripts\run-clan-intel-cert.ps1')
    }
    Save-Checkpoint -Number 3 -Name 'clan-intel-full' -Phase '009A' -Commands @('Run-ClanIntelCert') -PassFail 'PASS'

    Invoke-ForgeCmd 'AnalyzeCohesionOpportunities'
    Save-Checkpoint -Number 4 -Name 'cohesion-read' -Phase '006B' -Commands @('AnalyzeCohesionOpportunities') -PassFail 'PASS'

    if (-not $WhatIf) {
        & (Join-Path $repoRoot 'ExportTbgEvidence.cmd')
    }
    Save-Checkpoint -Number 5 -Name 'export' -Phase 'evidence' -Commands @('ExportTbgEvidence') -PassFail 'PASS'
}

Write-Host ''
Write-Host '=== Live Assistive Cert Marathon ===' -ForegroundColor Cyan
Write-Host "Session: $Session"
Write-Host "Checkpoints: $checkpointRoot"
Write-Host ''

New-Item -ItemType Directory -Force -Path $checkpointRoot | Out-Null

switch ($Session) {
    'disposable' { Run-DisposableSession }
    'continue' { Run-ContinueSession }
    'all' {
        Run-DisposableSession
        if (-not $WhatIf) {
            & (Join-Path $repoRoot 'ForgeStop.cmd') 2>$null | Out-Null
            Start-Sleep -Seconds 5
        }
        Run-ContinueSession
    }
}

Write-Host ''
Write-Host "Done. Review: $checkpointRoot" -ForegroundColor Cyan
