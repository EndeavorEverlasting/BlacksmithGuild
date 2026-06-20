# Shared status + logging for forge.ps1 workflows.
# Writes BlacksmithGuild_Status.json and BlacksmithGuild_Forge.log under Documents.

$script:ForgeStatusState = $null

function Get-ForgeStatusPaths {
    $docsRoot = Join-Path $env:USERPROFILE 'Documents\Mount and Blade II Bannerlord'
    if (-not (Test-Path -LiteralPath $docsRoot)) {
        New-Item -ItemType Directory -Force -Path $docsRoot | Out-Null
    }

    return @{
        DocsRoot   = $docsRoot
        StatusJson = Join-Path $docsRoot 'BlacksmithGuild_Status.json'
        ForgeLog   = Join-Path $docsRoot 'BlacksmithGuild_Forge.log'
    }
}

function Write-ForgeLogLine {
    param([string]$Message)

    $paths = Get-ForgeStatusPaths
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $paths.ForgeLog -Value $line -Encoding UTF8
}

function Start-ForgeStatusRun {
    param(
        [string]$Source,
        [string]$Operation
    )

    if ($script:ForgeStatusState -and $script:ForgeStatusState.overall -eq 'RUNNING') {
        Write-ForgeLogLine "RUN attach source=$Source operation=$Operation"
        return
    }

    $script:ForgeStatusState = [ordered]@{
        updatedAt = (Get-Date).ToString('o')
        source    = $Source
        operation = $Operation
        overall   = 'RUNNING'
        steps     = @()
        tests     = @{}
        errors    = @()
    }

    Write-ForgeLogLine "RUN start source=$Source operation=$Operation"
    Save-ForgeStatus
}

function Set-ForgeStep {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Message = ''
    )

    if (-not $script:ForgeStatusState) {
        Start-ForgeStatusRun -Source 'unknown' -Operation 'unknown'
    }

    $existing = @($script:ForgeStatusState.steps | Where-Object { $_.name -eq $Name })
    if ($existing.Count -gt 0) {
        $script:ForgeStatusState.steps = @($script:ForgeStatusState.steps | Where-Object { $_.name -ne $Name })
    }

    $script:ForgeStatusState.steps += [ordered]@{
        name      = $Name
        status    = $Status
        message   = $Message
        updatedAt = (Get-Date).ToString('o')
    }

    $script:ForgeStatusState.updatedAt = (Get-Date).ToString('o')
    Write-ForgeLogLine "STEP $Name = $Status $(if ($Message) { "- $Message" })"
    Save-ForgeStatus
}

function Set-ForgeTest {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Message = ''
    )

    if (-not $script:ForgeStatusState) {
        Start-ForgeStatusRun -Source 'unknown' -Operation 'unknown'
    }

    $script:ForgeStatusState.tests[$Name] = [ordered]@{
        status    = $Status
        message   = $Message
        updatedAt = (Get-Date).ToString('o')
    }

    $script:ForgeStatusState.updatedAt = (Get-Date).ToString('o')
    Write-ForgeLogLine "TEST $Name = $Status $(if ($Message) { "- $Message" })"
    Save-ForgeStatus
}

function Add-ForgeError {
    param([string]$Message)

    if (-not $script:ForgeStatusState) {
        Start-ForgeStatusRun -Source 'unknown' -Operation 'unknown'
    }

    $script:ForgeStatusState.errors += [ordered]@{
        message   = $Message
        updatedAt = (Get-Date).ToString('o')
    }

    $script:ForgeStatusState.updatedAt = (Get-Date).ToString('o')
    Write-ForgeLogLine "ERROR $Message"
    Save-ForgeStatus
}

function Complete-ForgeStatusRun {
    param([string]$Overall)

    if (-not $script:ForgeStatusState) {
        return (Get-ForgeStatusPaths).StatusJson
    }

    $script:ForgeStatusState.overall = $Overall
    $script:ForgeStatusState.updatedAt = (Get-Date).ToString('o')
    Write-ForgeLogLine "RUN complete overall=$Overall"
    Save-ForgeStatus
    return (Get-ForgeStatusPaths).StatusJson
}

function Save-ForgeStatus {
    $paths = Get-ForgeStatusPaths
    if (-not $script:ForgeStatusState) { return }

  $payload = [ordered]@{
        updatedAt = $script:ForgeStatusState.updatedAt
        source    = $script:ForgeStatusState.source
        operation = $script:ForgeStatusState.operation
        overall   = $script:ForgeStatusState.overall
        steps     = @($script:ForgeStatusState.steps)
        tests     = $script:ForgeStatusState.tests
        errors    = @($script:ForgeStatusState.errors)
    }

    $payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $paths.StatusJson -Encoding UTF8
}

function Write-ForgeStatusSummary {
    param([string]$StatusJsonPath)

    if (-not (Test-Path -LiteralPath $StatusJsonPath)) {
        Write-Host 'Status file not written.' -ForegroundColor Yellow
        return
    }

    $status = Get-Content -LiteralPath $StatusJsonPath -Raw | ConvertFrom-Json
    Write-Host ''
    Write-Host "=== Forge status: $($status.overall) ===" -ForegroundColor Cyan
    Write-Host "Status file: $StatusJsonPath"
    Write-Host "Forge log:   $((Get-ForgeStatusPaths).ForgeLog)"
    Write-Host ''

    if ($status.steps) {
        Write-Host 'Steps:'
        foreach ($step in $status.steps) {
            $color = switch ($step.status) {
                'PASS' { 'Green' }
                'FAIL' { 'Red' }
                'WARN' { 'Yellow' }
                'BLOCKED' { 'Yellow' }
                'RUNNING' { 'Cyan' }
                default { 'Gray' }
            }
            $msg = if ($step.message) { " - $($step.message)" } else { '' }
            Write-Host "  [$($step.status)] $($step.name)$msg" -ForegroundColor $color
        }
    }

    if ($status.tests -and $status.tests.PSObject.Properties.Count -gt 0) {
        Write-Host ''
        Write-Host 'Tests:'
        foreach ($prop in $status.tests.PSObject.Properties) {
            $test = $prop.Value
            $color = switch ($test.status) {
                'PASS' { 'Green' }
                'FAIL' { 'Red' }
                'PENDING' { 'Yellow' }
                'BLOCKED' { 'Yellow' }
                default { 'Gray' }
            }
            $msg = if ($test.message) { " - $($test.message)" } else { '' }
            Write-Host "  [$($test.status)] $($prop.Name)$msg" -ForegroundColor $color
        }
    }

    if ($status.errors -and $status.errors.Count -gt 0) {
        Write-Host ''
        Write-Host 'Errors (logged; no in-game OK required):' -ForegroundColor Yellow
        foreach ($err in $status.errors) {
            Write-Host "  - $($err.message)" -ForegroundColor Yellow
        }
    }
}

function Invoke-ForgeStep {
    param(
        [string]$Name,
        [scriptblock]$Action
    )

    Set-ForgeStep -Name $Name -Status 'RUNNING'
    try {
        & $Action
        Set-ForgeStep -Name $Name -Status 'PASS'
    } catch {
        Set-ForgeStep -Name $Name -Status 'FAIL' -Message $_.Exception.Message
        Add-ForgeError $_.Exception.Message
        throw
    }
}

function Complete-ForgeStepBlocked {
    param(
        [string]$Name,
        [string]$Message = ''
    )

    Set-ForgeStep -Name $Name -Status 'BLOCKED' -Message $Message
}

function Test-ForgeStepBlocked {
    param([string]$Name)

    if (-not $script:ForgeStatusState) {
        return $false
    }

    foreach ($step in $script:ForgeStatusState.steps) {
        if ($step.name -eq $Name -and $step.status -eq 'BLOCKED') {
            return $true
        }
    }

    return $false
}

function Scan-InGameStatus {
    param([string]$BannerlordRoot)

    $statusPath = Join-Path $BannerlordRoot 'BlacksmithGuild_Status.json'
    if (-not (Test-Path -LiteralPath $statusPath)) {
        Set-ForgeTest -Name 'in_game_status' -Status 'PENDING' -Message 'BlacksmithGuild_Status.json not found in Bannerlord root'
        return $false
    }

    Write-Host "In-game status: $statusPath"
    $status = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
    Set-ForgeTest -Name 'in_game_status' -Status 'PASS' -Message $statusPath

    if ($status.modLoaded -eq $true) {
        Set-ForgeTest -Name 'mod_loaded' -Status 'PASS'
    }

    if ($status.campaignReady -eq $true) {
        Set-ForgeTest -Name 'campaign_ready' -Status 'PASS'
    } else {
        Set-ForgeTest -Name 'campaign_ready' -Status 'PENDING' -Message 'Load a campaign'
    }

    if ($status.mainHeroReady -eq $true) {
        Set-ForgeTest -Name 'main_hero_ready' -Status 'PASS'
    } else {
        Set-ForgeTest -Name 'main_hero_ready' -Status 'PENDING' -Message 'Wait for MainHero on campaign map'
    }

    if ($status.preflight) {
        $verdict = [string]$status.preflight.verdict
        if ($verdict -eq 'Pass') {
            Set-ForgeTest -Name 'preflight' -Status 'PASS'
        } elseif ($verdict -eq 'Fail') {
            Set-ForgeTest -Name 'preflight' -Status 'FAIL' -Message $status.preflight.reason
        } else {
            Set-ForgeTest -Name 'preflight' -Status 'PENDING' -Message "Preflight verdict: $verdict"
        }
    }

    if ($status.certification) {
        $cert = $status.certification
        $certOverall = [string]$cert.overall
        Write-Host "Certification ($($cert.sprint)): $certOverall ($($cert.completed)/$($cert.required)) next=$($cert.nextCheck)"
        $certColor = switch ($certOverall) {
            'PASS' { 'Green' }
            'FAIL' { 'Red' }
            'BLOCKED' { 'Yellow' }
            'IN_PROGRESS' { 'Cyan' }
            'WARMUP' { 'Yellow' }
            default { 'Gray' }
        }
        Set-ForgeTest -Name 'certification' -Status $(if ($certOverall -eq 'PASS') { 'PASS' } elseif ($certOverall -eq 'FAIL') { 'FAIL' } else { 'PENDING' }) -Message "$certOverall ($($cert.completed)/$($cert.required))"

        if ($cert.checks) {
            foreach ($prop in $cert.checks.PSObject.Properties) {
                $check = $prop.Value
                $checkStatus = [string]$check.status
                $color = switch ($checkStatus) {
                    'PASS' { 'Green' }
                    'FAIL' { 'Red' }
                    'BLOCKED' { 'Yellow' }
                    'IN_PROGRESS' { 'Cyan' }
                    default { 'Gray' }
                }
                $msg = if ($check.message) { " - $($check.message)" } else { '' }
                Write-Host "  [$checkStatus] $($prop.Name)$msg" -ForegroundColor $color
                if ($checkStatus -eq 'PASS') {
                    Set-ForgeTest -Name "cert_$($prop.Name)" -Status 'PASS'
                } elseif ($checkStatus -eq 'FAIL') {
                    Set-ForgeTest -Name "cert_$($prop.Name)" -Status 'FAIL' -Message $check.message
                }
            }
        }
    }

    if ($status.session) {
        Write-Host "Session: phase=$($status.session.phase) paused=$($status.session.timePaused) inbox=$($status.session.canPollFileInbox)"
    }

    if ($status.goldTest) {
        if ($status.goldTest.passed -eq $true) {
            Set-ForgeTest -Name 'gold_test' -Status 'PASS' -Message "delta=$($status.goldTest.delta)"
        } elseif ($status.goldTest.ran -eq $true) {
            Set-ForgeTest -Name 'gold_test' -Status 'FAIL' -Message 'Gold test ran but did not pass'
        }
    }

    if ($status.certification002) {
        $cert2 = $status.certification002
        $cert2Overall = [string]$cert2.overall
        Write-Host "Certification002 ($($cert2.sprint)): $cert2Overall ($($cert2.completed)/$($cert2.required)) next=$($cert2.nextCheck)"
        Set-ForgeTest -Name 'certification002' -Status $(if ($cert2Overall -eq 'PASS') { 'PASS' } elseif ($cert2Overall -eq 'FAIL') { 'FAIL' } else { 'PENDING' }) -Message "$cert2Overall ($($cert2.completed)/$($cert2.required))"

        if ($cert2.checks) {
            foreach ($prop in $cert2.checks.PSObject.Properties) {
                $check = $prop.Value
                $checkStatus = [string]$check.status
                $msg = if ($check.message) { " - $($check.message)" } else { '' }
                Write-Host "  [$checkStatus] cert002_$($prop.Name)$msg" -ForegroundColor $(switch ($checkStatus) { 'PASS' { 'Green' } 'FAIL' { 'Red' } 'BLOCKED' { 'Yellow' } default { 'Gray' } })
                if ($checkStatus -eq 'PASS') {
                    Set-ForgeTest -Name "cert002_$($prop.Name)" -Status 'PASS'
                } elseif ($checkStatus -eq 'FAIL') {
                    Set-ForgeTest -Name "cert002_$($prop.Name)" -Status 'FAIL' -Message $check.message
                }
            }
        }
    }

    if ($status.progressionTest) {
        if ($status.progressionTest.passed -eq $true) {
            Set-ForgeTest -Name 'progression_test' -Status 'PASS' -Message "smithingXp=$($status.progressionTest.smithingXpBefore)->$($status.progressionTest.smithingXpAfter)"
        } elseif ($status.progressionTest.ran -eq $true) {
            Set-ForgeTest -Name 'progression_test' -Status 'FAIL' -Message 'Progression test ran but did not pass'
        }
    }

    if ($status.lastCommand) {
        $cmd = $status.lastCommand
        $msg = "$($cmd.name) via $($cmd.source) = $($cmd.result)"
        Set-ForgeTest -Name 'last_command' -Status 'PASS' -Message $msg
    }

    return $true
}

function Get-MutationDevCommands {
    return @(
        'RunSmithingSafeActionNow',
        'RichPlayerEconomyTest',
        'RichSmithingProgressionTest',
        'AddSmithingXp',
        'AddSmithingFocus',
        'AddEnduranceAttribute',
        'ApplyAutoCharacterBuild'
    )
}

function Clear-StaleMutationCommandInbox {
    param(
        [Parameter(Mandatory = $true)][string]$BannerlordRoot
    )

    $inboxPath = Join-Path $BannerlordRoot 'BlacksmithGuild_CommandInbox.json'
    if (-not (Test-Path -LiteralPath $inboxPath)) {
        return $false
    }

    try {
        $existing = Get-Content -LiteralPath $inboxPath -Raw | ConvertFrom-Json
        $command = [string]$existing.command
        if ([string]::IsNullOrWhiteSpace($command)) {
            return $false
        }

        if ((Get-MutationDevCommands) -notcontains $command) {
            return $false
        }

        Remove-Item -LiteralPath $inboxPath -Force
        Write-Host "Cleared stale mutation command inbox: $command" -ForegroundColor Yellow
        return $true
    } catch {
        Write-Host "Could not inspect command inbox: $($_.Exception.Message)" -ForegroundColor DarkYellow
        return $false
    }
}

function Send-ForgeCommand {
    param(
        [Parameter(Mandatory = $true)][string]$CommandName,
        [Parameter(Mandatory = $true)][string]$BannerlordRoot,
        [switch]$Wait,
        [int]$TimeoutSec = 60
    )

    if (-not (Get-Command Get-DevCommandNames -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot 'dev-command-names.ps1')
    }

    $allowed = Get-DevCommandNames

    if ($allowed -notcontains $CommandName) {
        throw "Unknown command '$CommandName'. Allowed: $($allowed -join ', ')"
    }

    Clear-StaleMutationCommandInbox -BannerlordRoot $BannerlordRoot | Out-Null

    $inboxPath = Join-Path $BannerlordRoot 'BlacksmithGuild_CommandInbox.json'
    $ackPath = Join-Path $BannerlordRoot 'BlacksmithGuild_CommandAck.json'
    $statusPath = Join-Path $BannerlordRoot 'BlacksmithGuild_Status.json'
    $sequence = 1
    if (Test-Path -LiteralPath $inboxPath) {
        try {
            $existing = Get-Content -LiteralPath $inboxPath -Raw | ConvertFrom-Json
            if ($existing.sequence) {
                $sequence = [int]$existing.sequence + 1
            }
        } catch {
            $sequence = [int](Get-Date -UFormat %s)
        }
    }

    $payload = [ordered]@{
        sequence = $sequence
        command  = $CommandName
        source   = 'forge.ps1'
    }

    $payload | ConvertTo-Json | Set-Content -LiteralPath $inboxPath -Encoding UTF8
    Write-Host "Wrote command inbox: sequence=$sequence command=$CommandName" -ForegroundColor Green

    if (-not $Wait) {
        Write-Host 'Polls every 0.5s via OnApplicationTick (works when campaign loaded; focus not required).'
        return $sequence
    }

    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    Write-Host "Waiting up to ${TimeoutSec}s for ack (alt-tab OK if campaign is loaded)..." -ForegroundColor Cyan
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 500

        if (Test-Path -LiteralPath $ackPath) {
            try {
                $ack = Get-Content -LiteralPath $ackPath -Raw | ConvertFrom-Json
                if ([int]$ack.sequence -eq $sequence) {
                    Write-Host "ACK: $($ack.command) = $($ack.result)" -ForegroundColor Green
                    if ($ack.result -eq 'Blocked') {
                        Write-Host 'Command blocked by guardrail (expected for missing prerequisites).' -ForegroundColor Yellow
                        return $sequence
                    }
                    if ($ack.result -and $ack.result -ne 'Success') {
                        throw "Command '$CommandName' ack result: $($ack.result)"
                    }
                    return $sequence
                }
            } catch { }
        }

        if (Test-Path -LiteralPath $statusPath) {
            try {
                $st = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
                if ($st.lastCommand -and [int]$st.lastCommand.sequence -eq $sequence) {
                    Write-Host "Status: $($st.lastCommand.name) = $($st.lastCommand.result)" -ForegroundColor Green
                    if ($st.lastCommand.result -eq 'Blocked') {
                        Write-Host 'Command blocked by guardrail (expected for missing prerequisites).' -ForegroundColor Yellow
                        return $sequence
                    }
                    if ($st.lastCommand.result -and $st.lastCommand.result -ne 'Success') {
                        throw "Command '$CommandName' status result: $($st.lastCommand.result)"
                    }
                    return $sequence
                }
            } catch { }
        }
    }

    throw "Timeout waiting for command '$CommandName' (sequence $sequence). Is campaign loaded with mod ON?"
}

function Invoke-ForgeCertification {
    param(
        [Parameter(Mandatory = $true)][string]$BannerlordRoot,
        [int]$TimeoutSec = 90
    )

    Write-Host '=== Sprint 001 certification (file inbox, focus not required) ===' -ForegroundColor Cyan
    $steps = @(
        'ListScenarios',
        'AdvanceOneDay',
        'ToggleFastForward',
        'ToggleFastForward',
        'RichPlayerEconomyTest'
    )

    foreach ($cmd in $steps) {
        Send-ForgeCommand -CommandName $cmd -BannerlordRoot $BannerlordRoot -Wait -TimeoutSec $TimeoutSec
    }

    $statusPath = Join-Path $BannerlordRoot 'BlacksmithGuild_Status.json'
    if (Test-Path -LiteralPath $statusPath) {
        $st = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
        if ($st.certification) {
            Write-Host ''
            Write-Host "Certification overall: $($st.certification.overall) ($($st.certification.completed)/$($st.certification.required))" -ForegroundColor Cyan
        }
    }
}

function Invoke-ForgeProgressionCertification {
    param(
        [Parameter(Mandatory = $true)][string]$BannerlordRoot,
        [int]$TimeoutSec = 90
    )

    Write-Host '=== Sprint 002 progression certification (file inbox, focus not required) ===' -ForegroundColor Cyan
    $steps = @(
        'RichSmithingProgressionTest',
        'AddSmithingXp',
        'AddSmithingFocus',
        'AddEnduranceAttribute'
    )

    foreach ($cmd in $steps) {
        Send-ForgeCommand -CommandName $cmd -BannerlordRoot $BannerlordRoot -Wait -TimeoutSec $TimeoutSec
    }

    Start-Sleep -Milliseconds 500

    $statusPath = Join-Path $BannerlordRoot 'BlacksmithGuild_Status.json'
    if (Test-Path -LiteralPath $statusPath) {
        $st = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
        if ($st.certification002) {
            Write-Host ''
            Write-Host "Certification002 overall: $($st.certification002.overall) ($($st.certification002.completed)/$($st.certification002.required))" -ForegroundColor Cyan
        }
    }
}

function Get-BannerlordRootFromRepo {
    param([string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
    $csproj = Join-Path $RepoRoot 'src\BlacksmithGuild\BlacksmithGuild.csproj'
    if ($csproj -match '<GameFolder>([^<]+)</GameFolder>') {
        $fromCsproj = $Matches[1] -replace '&amp;', '&'
        if (Test-Path -LiteralPath $fromCsproj) { return $fromCsproj }
    }
    $default = 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord'
    if (Test-Path -LiteralPath $default) { return $default }
    throw 'Bannerlord install not found. Set GameFolder in BlacksmithGuild.csproj.'
}

function Scan-AcceptanceLog {
    param(
        [string]$LogPath,
        [string]$BannerlordRoot = ''
    )

    if ($BannerlordRoot -and (Test-Path -LiteralPath $BannerlordRoot)) {
        $scannedStatus = Scan-InGameStatus -BannerlordRoot $BannerlordRoot
        if ($scannedStatus) {
            Write-Host ''
        }
    }

    if (-not (Test-Path -LiteralPath $LogPath)) {
        Set-ForgeTest -Name 'mod_log_present' -Status 'FAIL' -Message 'BlacksmithGuild_Phase1.log not found'
        Set-ForgeTest -Name 'forge_lit' -Status 'PENDING' -Message 'Load a campaign first'
        Set-ForgeTest -Name 'preflight' -Status 'PENDING' -Message 'Load a campaign first'
        Set-ForgeTest -Name 'gold_test' -Status 'PENDING' -Message 'Advance one day after load'
        return
    }

    Set-ForgeTest -Name 'mod_log_present' -Status 'PASS' -Message $LogPath

    $patterns = @{
        forge_lit = '\[The Blacksmith Guild\] Mod loaded\. The forge is lit\.'
        preflight = '\[TBG PREFLIGHT\] Result: Pass'
        gold_test = '\[TBG TEST\] PASS'
        progression_test = '\[TBG TEST\] Scenario: RichSmithingProgressionTest'
    }

    foreach ($entry in $patterns.GetEnumerator()) {
        if (Select-String -LiteralPath $LogPath -Pattern $entry.Value -Quiet) {
            Set-ForgeTest -Name $entry.Key -Status 'PASS'
        } else {
            Set-ForgeTest -Name $entry.Key -Status 'PENDING' -Message 'Not found in log yet'
        }
    }

    if (Select-String -LiteralPath $LogPath -Pattern '\[TBG PREFLIGHT\] Result: Fail' -Quiet) {
        Set-ForgeTest -Name 'preflight' -Status 'FAIL' -Message 'Preflight failed; dev hotkeys blocked'
    } elseif (Select-String -LiteralPath $LogPath -Pattern '\[TBG SAFETY\].*blocked' -Quiet) {
        Set-ForgeTest -Name 'gold_test' -Status 'BLOCKED' -Message 'Blocked by preflight or safety gate'
    }

    $engineFail = $false
    $logLines = Get-Content -LiteralPath $LogPath -ErrorAction SilentlyContinue
    foreach ($line in $logLines) {
        if ($line -match '\[TBG PREFLIGHT\]') { continue }
        if ($line -match 'Assertion Failed|has missing beard tag!') {
            $engineFail = $true
            break
        }
    }

    if ($engineFail) {
        Add-ForgeError 'Engine assertion or beard-tag failure detected in log. Run CollectDiagnostics; do not rely on in-game OK dialogs.'
        Set-ForgeTest -Name 'engine_integrity' -Status 'FAIL' -Message 'See log / diagnostic-summary.txt'
    } else {
        Set-ForgeTest -Name 'engine_integrity' -Status 'PASS'
    }
}
