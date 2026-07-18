# Local iteration time-budget contract helpers.
# Stub/contract layer only. These helpers are safe to dot-source and are intended
# to be wired into Reboot, ForgeVerify, launcher, and runner flows by follow-up patches.

$script:TbgNormalTimeBudgetSec = 30
$script:TbgLongActionDefaultBudgetSec = 180
$script:TbgLongActionHardCeilingSec = 300
$script:TbgAllowedLongActionClasses = @(
    'travel_between_settlements',
    'blacksmithing_batch_work',
    'trading_batch_work'
)

function Get-TbgTimeBudget {
    param(
        [string]$ActionClass = 'normal',
        [int]$RequestedTimeoutSec = 0
    )

    $normalized = if ([string]::IsNullOrWhiteSpace($ActionClass)) { 'normal' } else { [string]$ActionClass }
    $isLongAllowed = $script:TbgAllowedLongActionClasses -contains $normalized

    if ($normalized -eq 'normal' -or -not $isLongAllowed) {
        $budget = if ($RequestedTimeoutSec -gt 0) { [Math]::Min($RequestedTimeoutSec, $script:TbgNormalTimeBudgetSec) } else { $script:TbgNormalTimeBudgetSec }
        return [pscustomobject]@{
            actionClass = $normalized
            timeBudgetSec = $budget
            maxTimeBudgetSec = $script:TbgNormalTimeBudgetSec
            longWaitException = $false
            allowed = ($RequestedTimeoutSec -le 0 -or $RequestedTimeoutSec -le $script:TbgNormalTimeBudgetSec)
            reason = 'normal operations classify after 30 seconds'
        }
    }

    $requested = if ($RequestedTimeoutSec -gt 0) { $RequestedTimeoutSec } else { $script:TbgLongActionDefaultBudgetSec }
    $budget = [Math]::Min($requested, $script:TbgLongActionHardCeilingSec)
    return [pscustomobject]@{
        actionClass = $normalized
        timeBudgetSec = $budget
        maxTimeBudgetSec = $script:TbgLongActionHardCeilingSec
        longWaitException = $true
        allowed = ($requested -le $script:TbgLongActionHardCeilingSec)
        reason = 'allowlisted gameplay-long operation'
    }
}

function Test-TbgLongWaitAllowed {
    param(
        [string]$ActionClass,
        [int]$TimeoutSec
    )

    $budget = Get-TbgTimeBudget -ActionClass $ActionClass -RequestedTimeoutSec $TimeoutSec
    return [bool]($budget.allowed -and ($budget.longWaitException -or $budget.timeBudgetSec -le $script:TbgNormalTimeBudgetSec))
}

function Assert-TbgNormalTimeout {
    param(
        [Parameter(Mandatory = $true)][int]$TimeoutSec,
        [string]$ActionClass = 'normal',
        [string]$Context = 'unspecified'
    )

    $budget = Get-TbgTimeBudget -ActionClass $ActionClass -RequestedTimeoutSec $TimeoutSec
    if (-not $budget.allowed) {
        throw "time budget violation: context=$Context actionClass=$ActionClass timeoutSec=$TimeoutSec maxTimeBudgetSec=$($budget.maxTimeBudgetSec)"
    }
    return $budget
}

function Write-TbgTimeBudgetViolation {
    param(
        [string]$Path,
        [string]$Context,
        [string]$ActionClass,
        [int]$TimeoutSec,
        [string]$Reason = 'time budget violation'
    )

    $payload = [ordered]@{
        schemaVersion = 1
        classification = 'time_budget_violation'
        context = $Context
        actionClass = $ActionClass
        timeoutSec = $TimeoutSec
        normalTimeBudgetSec = $script:TbgNormalTimeBudgetSec
        longActionHardCeilingSec = $script:TbgLongActionHardCeilingSec
        reason = $Reason
        generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    }

    if ($Path) {
        $dir = Split-Path -Parent $Path
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        $payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
    }

    return [pscustomobject]$payload
}

function Invoke-TbgTimedStep {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][scriptblock]$Script,
        [string]$ActionClass = 'normal',
        [int]$TimeoutSec = 30
    )

    # Stub implementation: validates the declared budget, then invokes synchronously.
    # Follow-up wiring may replace this with process/job-based timeout enforcement.
    $budget = Assert-TbgNormalTimeout -TimeoutSec $TimeoutSec -ActionClass $ActionClass -Context $Label
    $started = Get-Date
    & $Script
    $exitCode = $LASTEXITCODE
    $elapsed = [int]([Math]::Round(((Get-Date) - $started).TotalSeconds))
    return [pscustomobject]@{
        label = $Label
        actionClass = $budget.actionClass
        timeBudgetSec = $budget.timeBudgetSec
        elapsedSec = $elapsed
        exitCode = $exitCode
        passedBudgetContract = ($elapsed -le $budget.timeBudgetSec)
    }
}
