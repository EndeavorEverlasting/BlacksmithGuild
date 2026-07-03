$Script:TbgTestDurationDefaultBudgetSec = 30

function Get-TbgTestDurationPolicyManifestPath {
    param([string]$RepoRoot = (Split-Path -Parent $PSScriptRoot))
    return (Join-Path $RepoRoot 'docs\handoff\test-duration-policy.manifest.json')
}

function Read-TbgTestDurationPolicyManifest {
    param(
        [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
        [string]$PolicyPath
    )

    if ([string]::IsNullOrWhiteSpace($PolicyPath)) {
        $PolicyPath = Get-TbgTestDurationPolicyManifestPath -RepoRoot $RepoRoot
    }
    if (-not (Test-Path -LiteralPath $PolicyPath)) { throw "Policy manifest not found: $PolicyPath" }

    $manifest = (Get-Content -LiteralPath $PolicyPath -Raw -Encoding UTF8) | ConvertFrom-Json
    if (-not $manifest.defaultBudgetSec) { throw "Policy manifest missing defaultBudgetSec: $PolicyPath" }
    return $manifest
}

function Test-TbgExplicitLongRunProfile {
    param([string]$CertProfile, $Manifest)

    if ([string]::IsNullOrWhiteSpace($CertProfile)) { return $false }
    $classes = @()
    if ($Manifest -and $Manifest.explicitLongRunClasses) { $classes = @($Manifest.explicitLongRunClasses) }
    if ($classes -contains $CertProfile) { return $true }
    return ($CertProfile -match '(?i)(live|cert|soak|manual_debug|long)')
}

function Resolve-TbgTestDurationBudget {
    [CmdletBinding()]
    param(
        [int]$RequestedBudgetSec = 0,
        [switch]$AllowLongRun,
        [string]$LongRunReason,
        [string]$CertProfile,
        [string]$Caller = 'unknown',
        [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
        [string]$PolicyPath
    )

    $manifest = Read-TbgTestDurationPolicyManifest -RepoRoot $RepoRoot -PolicyPath $PolicyPath
    $defaultBudgetSec = [int]$manifest.defaultBudgetSec
    if ($defaultBudgetSec -le 0) { $defaultBudgetSec = $Script:TbgTestDurationDefaultBudgetSec }

    $source = 'default'
    $budgetSec = $defaultBudgetSec
    if ($PSBoundParameters.ContainsKey('RequestedBudgetSec') -and $RequestedBudgetSec -gt 0) {
        $budgetSec = [int]$RequestedBudgetSec
        $source = 'explicit_parameter'
    }

    $isLongRun = ($budgetSec -gt $defaultBudgetSec)
    $profileAllowsLongRun = Test-TbgExplicitLongRunProfile -CertProfile $CertProfile -Manifest $manifest

    if ($isLongRun -and -not ($AllowLongRun -or $profileAllowsLongRun)) { throw "Budget exceeds default policy for $Caller." }
    if ($isLongRun -and [string]::IsNullOrWhiteSpace($LongRunReason)) { throw "Extended budget requires a reason for $Caller." }

    return [pscustomobject]@{
        schemaVersion = 1
        caller = $Caller
        budgetSec = $budgetSec
        defaultBudgetSec = $defaultBudgetSec
        isLongRun = $isLongRun
        source = $source
        allowLongRun = [bool]($AllowLongRun -or $profileAllowsLongRun)
        certProfile = $CertProfile
        reason = $LongRunReason
        policyPath = $PolicyPath
    }
}

function New-TbgTestDurationDeadline {
    param([Parameter(Mandatory = $true)]$Budget)
    return (Get-Date).AddSeconds([int]$Budget.budgetSec)
}

function Test-TbgTestDurationExpired {
    param([Parameter(Mandatory = $true)][datetime]$Deadline)
    return ((Get-Date) -ge $Deadline)
}

function Write-TbgTestDurationBudget {
    param([Parameter(Mandatory = $true)]$Budget)
    $kind = if ($Budget.isLongRun) { 'long-run' } else { 'bounded' }
    $reason = if ([string]::IsNullOrWhiteSpace($Budget.reason)) { 'default policy' } else { $Budget.reason }
    Write-Host ("test-duration: {0} caller={1} budgetSec={2} defaultBudgetSec={3} source={4} reason={5}" -f $kind, $Budget.caller, $Budget.budgetSec, $Budget.defaultBudgetSec, $Budget.source, $reason)
}
