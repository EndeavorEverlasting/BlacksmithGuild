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

function Scan-AcceptanceLog {
    param([string]$LogPath)

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

    if (Select-String -LiteralPath $LogPath -Pattern 'Assertion Failed|has missing beard tag' -Quiet) {
        Add-ForgeError 'Engine assertion or beard-tag failure detected in log. Run CollectDiagnostics; do not rely on in-game OK dialogs.'
        Set-ForgeTest -Name 'engine_integrity' -Status 'FAIL' -Message 'See log / diagnostic-summary.txt'
    }
}
