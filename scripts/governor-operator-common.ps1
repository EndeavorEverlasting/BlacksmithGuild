# Shared operator helpers for governor smoke/validation flows.
$script:GovernorClassificationPass = 'PASS'
$script:GovernorClassificationFail = 'FAIL'
$script:GovernorClassificationBlocked = 'BLOCKED'
$script:GovernorClassificationEnvironmentBlocked = 'ENVIRONMENT BLOCKED'
$script:GovernorClassificationUserCancelled = 'USER CANCELLED'

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

function Get-GovernorDisposableSavePolicyPath {
    param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
    return Join-Path $RepoRoot '.tbg\harness\policies\disposable-save.policy.json'
}

function Get-GovernorDisposableSavePolicy {
    param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
    $path = Get-GovernorDisposableSavePolicyPath -RepoRoot $RepoRoot
    if (-not (Test-Path -LiteralPath $path)) {
        return [pscustomobject]@{
            schema = 'TbgDisposableSavePolicy.v1'
            namePatterns = @('BlacksmithGuild_DevStart*.sav', 'BlacksmithGuild_Disposable_*.sav', 'TBG_Disposable_*.sav')
            preferredLeafNames = @('BlacksmithGuild_DevStart.sav')
            activePinRelativePath = '.local/disposable-save.active.json'
            operatorAuthorityRelativePath = '.local/disposable-save.operator.json'
            saveRootRelativeSegments = @(
                @('Mount and Blade II Bannerlord', 'Game Saves'),
                @('Mount and Blade II Bannerlord', 'Game Saves', 'Native')
            )
            shippedDefaults = [pscustomobject]@{
                yearFloorEnabled = $false
                mutateUnnamedSaves = $false
                treatCalendarYearAsDisposable = $false
            }
        }
    }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-GovernorDisposableSaveOperatorAuthority {
    param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
    $policy = Get-GovernorDisposableSavePolicy -RepoRoot $RepoRoot
    $rel = if ($policy.operatorAuthorityRelativePath) { [string]$policy.operatorAuthorityRelativePath } else { '.local/disposable-save.operator.json' }
    $path = Join-Path $RepoRoot ($rel -replace '/', '\')
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    try {
        return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Get-GovernorNativeSaveRoot {
    return Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Mount and Blade II Bannerlord\Game Saves\Native'
}

function Get-GovernorSaveRoots {
    param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
    $policy = Get-GovernorDisposableSavePolicy -RepoRoot $RepoRoot
    $docs = [Environment]::GetFolderPath('MyDocuments')
    $roots = New-Object System.Collections.Generic.List[string]
    foreach ($segments in @($policy.saveRootRelativeSegments)) {
        $parts = @($segments | ForEach-Object { [string]$_ })
        if ($parts.Count -eq 0) { continue }
        $path = $docs
        foreach ($part in $parts) { $path = Join-Path $path $part }
        if ((Test-Path -LiteralPath $path) -and -not $roots.Contains($path)) {
            $roots.Add($path) | Out-Null
        }
    }
    $legacyNative = Get-GovernorNativeSaveRoot
    if ((Test-Path -LiteralPath $legacyNative) -and -not $roots.Contains($legacyNative)) {
        $roots.Add($legacyNative) | Out-Null
    }
    return @($roots)
}

function Get-GovernorDisposableSavePatterns {
    param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
    $policy = Get-GovernorDisposableSavePolicy -RepoRoot $RepoRoot
    $patterns = @($policy.namePatterns | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($patterns.Count -eq 0) {
        $patterns = @('BlacksmithGuild_DevStart*.sav', 'BlacksmithGuild_Disposable_*.sav', 'TBG_Disposable_*.sav')
    }
    return $patterns
}

function Get-GovernorActiveDisposableSavePinPath {
    param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
    $policy = Get-GovernorDisposableSavePolicy -RepoRoot $RepoRoot
    $rel = if ($policy.activePinRelativePath) { [string]$policy.activePinRelativePath } else { '.local/disposable-save.active.json' }
    return Join-Path $RepoRoot ($rel -replace '/', '\')
}

function Get-GovernorActiveDisposableSavePin {
    param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
    $path = Get-GovernorActiveDisposableSavePinPath -RepoRoot $RepoRoot
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    try {
        return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Set-GovernorActiveDisposableSavePin {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$SaveFile,
        [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
        [string]$Reason = 'operator or sprint selected disposable save'
    )
    $confidence = Test-DisposableSaveConfidence -SaveFile $SaveFile -RepoRoot $RepoRoot
    if (-not $confidence.ApprovedPattern) {
        throw "Refusing to pin non-approved save: $($SaveFile.FullName) ($($confidence.Reason))"
    }
    $path = Get-GovernorActiveDisposableSavePinPath -RepoRoot $RepoRoot
    $payload = [ordered]@{
        schema = 'TbgDisposableSaveActivePin.v1'
        machineLocalOnly = $true
        leafName = $SaveFile.Name
        fullPath = $SaveFile.FullName
        lastWriteUtc = $SaveFile.LastWriteTimeUtc.ToString('o')
        approvalReason = $confidence.Reason
        reason = $Reason
        updatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    }
    Write-GovernorJsonFile -InputObject $payload -Path $path -Depth 6
    return $payload
}

function Get-GovernorDisposableSaveCandidates {
    param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
    $all = New-Object System.Collections.Generic.List[System.IO.FileInfo]
    $patterns = @(Get-GovernorDisposableSavePatterns -RepoRoot $RepoRoot)
    foreach ($root in @(Get-GovernorSaveRoots -RepoRoot $RepoRoot)) {
        foreach ($pattern in $patterns) {
            foreach ($file in @(Get-ChildItem -LiteralPath $root -Filter $pattern -File -ErrorAction SilentlyContinue)) {
                $all.Add($file) | Out-Null
            }
        }
        # Machine-local year-floor cohort only when operator authority file enables it.
        $authority = Get-GovernorDisposableSaveOperatorAuthority -RepoRoot $RepoRoot
        if ($authority -and $authority.yearFloorEnabled -eq $true -and $authority.yearFloor) {
            $yearFloor = [int]$authority.yearFloor
            foreach ($file in @(Get-ChildItem -LiteralPath $root -Filter '*.sav' -File -ErrorAction SilentlyContinue)) {
                if ($file.LastWriteTime.Year -ge $yearFloor) {
                    $all.Add($file) | Out-Null
                }
            }
        }
    }
    return @($all | Sort-Object FullName -Unique | Sort-Object LastWriteTimeUtc -Descending)
}

function Test-DisposableSaveConfidence {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$SaveFile,
        [Nullable[datetime]]$TestStartUtc = $null,
        [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    )
    $name = $SaveFile.Name
    $approved = $false
    $reason = 'not an approved disposable pattern'
    foreach ($pattern in @(Get-GovernorDisposableSavePatterns -RepoRoot $RepoRoot)) {
        if ($name -like $pattern) {
            $approved = $true
            $reason = 'approved disposable pattern'
            break
        }
    }

    $pin = Get-GovernorActiveDisposableSavePin -RepoRoot $RepoRoot
    if ($pin -and [string]::Equals([string]$pin.fullPath, $SaveFile.FullName, [StringComparison]::OrdinalIgnoreCase)) {
        $approved = $true
        $reason = 'active disposable-save pin'
    }

    $authority = Get-GovernorDisposableSaveOperatorAuthority -RepoRoot $RepoRoot
    if (-not $approved -and $authority -and $authority.yearFloorEnabled -eq $true -and $authority.yearFloor) {
        if ($SaveFile.LastWriteTime.Year -ge [int]$authority.yearFloor) {
            $approved = $true
            $reason = "machine-local operator year-floor $($authority.yearFloor)+ (not a shipped product default)"
        }
    }

    $score = if ($approved) { 0.10 } else { 0.80 }
    if (-not $approved -and $name -match '^(save[0-9]+|autosave|ironman|quick.*save)\.sav$') {
        $score = [Math]::Max($score, 0.90)
        $reason = 'generic personal-save name'
    }
    if ($TestStartUtc -and $SaveFile.LastWriteTimeUtc -ge ([datetime]$TestStartUtc).AddMinutes(-5) -and $approved) {
        $score = [Math]::Min($score, 0.05)
        $reason = 'fresh approved disposable save'
    }

    return [PSCustomObject]@{
        Score = [double]$score
        Reason = $reason
        ApprovedPattern = [bool]$approved
        MachineLocalYearFloor = [bool]($authority -and $authority.yearFloorEnabled -eq $true)
    }
}

function Get-GovernorBestDisposableSave {
    param(
        [Nullable[datetime]]$TestStartUtc = $null,
        [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    )
    $policy = Get-GovernorDisposableSavePolicy -RepoRoot $RepoRoot
    $preferred = @($policy.preferredLeafNames | ForEach-Object { [string]$_ })

    $pin = Get-GovernorActiveDisposableSavePin -RepoRoot $RepoRoot
    if ($pin -and $pin.fullPath -and (Test-Path -LiteralPath ([string]$pin.fullPath))) {
        $pinnedFile = Get-Item -LiteralPath ([string]$pin.fullPath)
        $pinnedConfidence = Test-DisposableSaveConfidence -SaveFile $pinnedFile -TestStartUtc $TestStartUtc -RepoRoot $RepoRoot
        if ($pinnedConfidence.ApprovedPattern -and $pinnedConfidence.Score -lt 0.70) {
            return [PSCustomObject]@{ File = $pinnedFile; Confidence = $pinnedConfidence }
        }
    }

    $candidates = @(Get-GovernorDisposableSaveCandidates -RepoRoot $RepoRoot)
    foreach ($leaf in $preferred) {
        $match = @($candidates | Where-Object { [string]::Equals($_.Name, $leaf, [StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1)
        if ($match.Count -gt 0) {
            $confidence = Test-DisposableSaveConfidence -SaveFile $match[0] -TestStartUtc $TestStartUtc -RepoRoot $RepoRoot
            if ($confidence.ApprovedPattern -and $confidence.Score -lt 0.70) {
                return [PSCustomObject]@{ File = $match[0]; Confidence = $confidence }
            }
        }
    }

    foreach ($save in $candidates) {
        $confidence = Test-DisposableSaveConfidence -SaveFile $save -TestStartUtc $TestStartUtc -RepoRoot $RepoRoot
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