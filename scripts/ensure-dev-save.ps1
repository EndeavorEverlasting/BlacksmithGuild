param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [switch]$AllowManualDevSaveSetup
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'governor-operator-common.ps1')

function Get-DevSaveNativeRoot {
    return Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Mount and Blade II Bannerlord\Game Saves\Native'
}

function Get-DevSaveFile {
    $match = Get-GovernorBestDisposableSave
    if ($match) { return $match.File }
    return $null
}

function Test-DevSavePresent {
    return $null -ne (Get-DevSaveFile)
}

function Wait-CampaignRuntimeAttach {
    param(
        [Parameter(Mandatory = $true)][string]$BannerlordRoot,
        [Parameter(Mandatory = $true)][string]$StatusPath,
        [Parameter(Mandatory = $true)][datetime]$StartedUtc,
        [int]$TimeoutSec = 600
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        Assert-GovernorNotStopped -RepoRoot $RepoRoot
        Start-Sleep -Seconds 3
        if (-not (Test-Path -LiteralPath $StatusPath)) {
            continue
        }

        try {
            $status = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
            $heartbeat = $null
            if ($status.stateMachine -and $status.stateMachine.heartbeatUtc) {
                $heartbeat = [datetime]::Parse($status.stateMachine.heartbeatUtc).ToUniversalTime()
            }
            elseif ($status.updatedAt) {
                $heartbeat = [datetime]::Parse($status.updatedAt).ToUniversalTime()
            }

            $fresh = $heartbeat -and ($heartbeat -gt $StartedUtc.AddMinutes(-1))
            $ready = ($status.campaignReady -eq $true) -or ($status.session -and $status.session.canPollFileInbox -eq $true)
            if ($fresh -and $ready) {
                return $status
            }
        }
        catch {
            Write-Host "status parse warn: $($_.Exception.Message)" -ForegroundColor DarkYellow
        }
    }

    throw "campaign attach not observed within ${TimeoutSec}s"
}

function Wait-DevSaveOnDisk {
    param([int]$TimeoutSec = 120)

    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        Assert-GovernorNotStopped -RepoRoot $RepoRoot
        $save = Get-DevSaveFile
        if ($save) {
            return $save
        }

        Start-Sleep -Seconds 2
    }

    return $null
}

function Invoke-EnsureDevSave {
    param(
        [Parameter(Mandatory = $true)][string]$BannerlordRoot,
        [switch]$LaunchIfNeeded,
        [switch]$AllowManualDevSaveSetup,
        [int]$BootstrapAttachWaitSec = 1200,
        [int]$ContinueAttachWaitSec = 600
    )

    . (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
    . (Join-Path $PSScriptRoot 'forge-status.ps1')

    $statusPath = Get-StatusJsonPath -BannerlordRoot $BannerlordRoot
    $bootstrapUsed = $false
    $launchIntent = 'continue'

    if (-not (Test-DevSavePresent)) {
        if ($AllowManualDevSaveSetup) {
            Write-Host 'No approved disposable save found. See docs/operator/governor-test-harness.md#create-a-disposable-dev-save.' -ForegroundColor Yellow
            throw 'BLOCKED: manual disposable dev save setup required'
        }
        Write-Host 'No approved disposable save found.' -ForegroundColor Yellow
        Write-Host '[1] Create a new disposable dev save'
        Write-Host '[2] Open instructions for creating one manually'
        Write-Host '[3] Cancel test (default)'
        $choice = Read-GovernorOperatorChoice -Prompt 'Choose 1, 2, or 3' -Allowed @('1','2','3') -Default '3'
        if ($choice -eq '2') {
            Write-Host 'Instructions: docs/operator/governor-test-harness.md#create-a-disposable-dev-save' -ForegroundColor Cyan
            throw 'BLOCKED: operator chose manual disposable dev save setup'
        }
        if ($choice -ne '1') {
            throw 'USER CANCELLED: no disposable dev save approved'
        }
        Write-Host 'Bootstrapping disposable dev save via New Campaign.'
        $bootstrapUsed = $true
        $launchIntent = 'play'
    }
    else {
        Write-Host ("Dev save present: {0}" -f (Get-DevSaveFile).FullName)
    }

    if ($LaunchIfNeeded) {
        Write-Host "==> Launch $launchIntent"
        & (Join-Path $PSScriptRoot 'invoke-forge-launch-operator.ps1') -RepoRoot $RepoRoot -LaunchIntent $launchIntent
        if ($LASTEXITCODE -ne 0) {
            throw "operator launch failed with exit code $LASTEXITCODE"
        }
    }

    $startedUtc = (Get-Date).ToUniversalTime()
    $attachTimeout = if ($bootstrapUsed) { $BootstrapAttachWaitSec } else { $ContinueAttachWaitSec }
    Write-Host "==> Wait for campaign attach (timeout ${attachTimeout}s)"
    $status = Wait-CampaignRuntimeAttach -BannerlordRoot $BannerlordRoot -StatusPath $statusPath -StartedUtc $startedUtc -TimeoutSec $attachTimeout

    if ($bootstrapUsed) {
        Write-Host '==> Save disposable dev save (SaveDevStartSaveNow)'
        Assert-GovernorNotStopped -RepoRoot $RepoRoot
        Send-ForgeCommand -CommandName 'SaveDevStartSaveNow' -BannerlordRoot $BannerlordRoot -Wait -TimeoutSec 120 | Out-Null

        $save = Wait-DevSaveOnDisk -TimeoutSec 120
        if (-not $save) {
            throw 'SaveDevStartSaveNow acked but BlacksmithGuild_DevStart*.sav not found on disk'
        }

        Write-Host ("Dev save created: {0}" -f $save.FullName) -ForegroundColor Green
    }

    return [ordered]@{
        bootstrapUsed = $bootstrapUsed
        launchIntent  = $launchIntent
        devSavePath   = (Get-DevSaveFile).FullName
        status        = $status
    }
}
