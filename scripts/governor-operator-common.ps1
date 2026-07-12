# Shared operator helpers for governor smoke/validation flows.
$script:GovernorClassificationPass = 'PASS'
$script:GovernorClassificationFail = 'FAIL'
$script:GovernorClassificationBlocked = 'BLOCKED'
$script:GovernorClassificationEnvironmentBlocked = 'ENVIRONMENT BLOCKED'
$script:GovernorClassificationUserCancelled = 'USER CANCELLED'

. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')

function Get-GovernorOperatorLocalRoot {
    param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
    return Join-Path $RepoRoot '.local'
}

function Get-GovernorSmokeRoot {
    param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
    return Join-Path (Get-GovernorOperatorLocalRoot -RepoRoot $RepoRoot) 'governor-smoke'
}

function Get-GovernorValidationRoot {
    param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
    return Join-Path (Get-GovernorOperatorLocalRoot -RepoRoot $RepoRoot) 'governor-validation'
}

function Get-GovernorStopRoot {
    param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
    return Join-Path (Get-GovernorOperatorLocalRoot -RepoRoot $RepoRoot) 'operator-stop'
}

function Get-GovernorStopSentinelPath {
    param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
    return Join-Path (Get-GovernorStopRoot -RepoRoot $RepoRoot) 'forge-stop-requested.json'
}

function New-GovernorOperatorSessionDir {
    param(
        [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
        [string]$Kind = 'governor-smoke'
    )
    $root = if ($Kind -eq 'governor-validation') { Get-GovernorValidationRoot -RepoRoot $RepoRoot } else { Get-GovernorSmokeRoot -RepoRoot $RepoRoot }
    $sessionId = Get-Date -Format 'yyyyMMdd-HHmmss'
    $path = Join-Path $root $sessionId
    New-Item -ItemType Directory -Force -Path $path | Out-Null
    return [PSCustomObject]@{ SessionId = $sessionId; Path = $path }
}

function Write-GovernorJsonFile {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$Depth = 8
    )
    $dir = Split-Path -Parent $Path
    if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $InputObject | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Write-GovernorStopSentinel {
    param(
        [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
        [string]$Reason = 'operator requested stop'
    )
    $path = Get-GovernorStopSentinelPath -RepoRoot $RepoRoot
    $payload = [ordered]@{
        requestedUtc = (Get-Date).ToUniversalTime().ToString('o')
        pid = $PID
        reason = $Reason
    }
    Write-GovernorJsonFile -InputObject $payload -Path $path -Depth 4
    return $path
}

function Clear-GovernorStopSentinel {
    param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
    Remove-Item -LiteralPath (Get-GovernorStopSentinelPath -RepoRoot $RepoRoot) -Force -ErrorAction SilentlyContinue
}

function Test-GovernorStopRequested {
    param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
    return Test-Path -LiteralPath (Get-GovernorStopSentinelPath -RepoRoot $RepoRoot)
}

function Assert-GovernorNotStopped {
    param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
    if (Test-GovernorStopRequested -RepoRoot $RepoRoot) {
        throw "${script:GovernorClassificationUserCancelled}: forge stop sentinel requested"
    }
}

function Get-GovernorDisposableSavePatterns {
    return @((Get-BannerlordDevSavePatterns) + @('BlacksmithGuild_Disposable_*.sav', 'TBG_Disposable_*.sav'))
}

function Get-GovernorDisposableSaveCandidates {
    $all = @()
    foreach ($root in @(Get-BannerlordExistingGameSaveRoots)) {
        foreach ($pattern in (Get-GovernorDisposableSavePatterns)) {
            $all += @(Get-ChildItem -LiteralPath $root -Filter $pattern -File -ErrorAction SilentlyContinue)
        }
    }
    return @($all | Sort-Object FullName -Unique | Sort-Object LastWriteTimeUtc -Descending)
}

function Test-DisposableSaveConfidence {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$SaveFile,
        [Nullable[datetime]]$TestStartUtc = $null
    )
    $name = $SaveFile.Name
    $approved = $false
    foreach ($pattern in (Get-GovernorDisposableSavePatterns)) {
        if ($name -like $pattern) { $approved = $true; break }
    }

    $score = if ($approved) { 0.10 } else { 0.80 }
    $reason = if ($approved) { 'approved disposable pattern' } else { 'not an approved disposable pattern' }
    if ($name -match '^(save[0-9]+|autosave|ironman|quick.*save)\.sav$') {
        $score = [Math]::Max($score, 0.90)
        $reason = 'generic personal-save name'
    }
    if ($TestStartUtc -and $SaveFile.LastWriteTimeUtc -ge ([datetime]$TestStartUtc).AddMinutes(-5) -and $approved) {
        $score = [Math]::Min($score, 0.05)
        $reason = 'fresh approved disposable save'
    }

    return [PSCustomObject]@{ Score = [double]$score; Reason = $reason; ApprovedPattern = [bool]$approved }
}

function Get-GovernorBestDisposableSave {
    param([Nullable[datetime]]$TestStartUtc = $null)
    foreach ($save in @(Get-GovernorDisposableSaveCandidates)) {
        $confidence = Test-DisposableSaveConfidence -SaveFile $save -TestStartUtc $TestStartUtc
        if ($confidence.ApprovedPattern -and $confidence.Score -lt 0.70) {
            return [PSCustomObject]@{ File = $save; Confidence = $confidence }
        }
    }
    return $null
}

function Read-GovernorOperatorChoice {
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [string[]]$Allowed = @('1', '2', '3'),
        [string]$Default = '3'
    )
    $choice = Read-Host $Prompt
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = $Default }
    $choice = $choice.Trim()
    if ($Allowed -notcontains $choice) { return $Default }
    return $choice
}

function Invoke-GovernorForgeStopApproval {
    param(
        [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
        [string]$Reason = 'deploy requires Bannerlord to stop'
    )
    Write-Host ''
    Write-Host 'Bannerlord appears to be running and this operation may need to deploy DLLs.' -ForegroundColor Yellow
    Write-Host '[1] Save-then-stop (soft stop request)'
    Write-Host '[2] Stop without save (soft stop request)'
    Write-Host '[3] Cancel (default)'
    $choice = Read-GovernorOperatorChoice -Prompt 'Choose 1, 2, or 3' -Allowed @('1','2','3') -Default '3'
    if ($choice -eq '3') { throw "${script:GovernorClassificationUserCancelled}: operator cancelled deploy stop" }
    $path = Write-GovernorStopSentinel -RepoRoot $RepoRoot -Reason $Reason
    Write-Host "Stop sentinel written: $path" -ForegroundColor Cyan
    & (Join-Path $RepoRoot 'scripts\forge-stop.ps1') | Out-Null
}

function Test-GovernorProperty {
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $false }
    return $null -ne $Object.PSObject.Properties[$Name]
}

function Assert-GovernorDecisionContract {
    param(
        [Parameter(Mandatory = $true)]$Decision,
        [Nullable[datetime]]$TestStartUtc = $null,
        [string]$DecisionPath = $null
    )
    if ($DecisionPath -and $TestStartUtc -and (Test-Path -LiteralPath $DecisionPath)) {
        $mtime = (Get-Item -LiteralPath $DecisionPath).LastWriteTimeUtc
        if ($mtime -le ([datetime]$TestStartUtc).ToUniversalTime()) { throw 'decision JSON is stale for this smoke session' }
    }
    foreach ($name in @('selectedBranch', 'allowed', 'proposedActivity', 'latestActivityResult')) {
        if (-not (Test-GovernorProperty -Object $Decision -Name $name)) { throw "decision JSON missing required field: $name" }
    }
    if ($null -eq $Decision.proposedActivity) { throw 'decision JSON proposedActivity is null' }
    foreach ($name in @('inputs', 'expectedOutputs', 'handoffTrail')) {
        if (-not (Test-GovernorProperty -Object $Decision.proposedActivity -Name $name)) { throw "decision JSON proposedActivity missing: $name" }
    }
    if ($null -eq $Decision.latestActivityResult) { throw 'decision JSON latestActivityResult is null' }
    foreach ($name in @('narrativeDetails', 'handoffTrail')) {
        if (-not (Test-GovernorProperty -Object $Decision.latestActivityResult -Name $name)) { throw "decision JSON latestActivityResult missing: $name" }
    }
    if ([bool]$Decision.allowed) { throw 'smoke expected allowed=false for no-mutation safety' }
    if ((Test-GovernorProperty -Object $Decision.latestActivityResult -Name 'mutationApplied') -and [bool]$Decision.latestActivityResult.mutationApplied) {
        throw 'smoke expected latestActivityResult.mutationApplied=false'
    }
}

function Find-GovernorDecisionPath {
    param([Parameter(Mandatory = $true)][string]$BannerlordRoot)
    $candidates = @(
        (Join-Path $BannerlordRoot 'BlacksmithGuild_CampaignGovernorDecision.json'),
        (Join-Path (Get-BannerlordDocsRoot) 'BlacksmithGuild_CampaignGovernorDecision.json')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    return $null
}
