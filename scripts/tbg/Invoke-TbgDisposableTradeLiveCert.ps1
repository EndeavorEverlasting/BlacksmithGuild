<#
.SYNOPSIS
  Canonical live certificate for proving a real visible in-game trade from a clean current-main checkout.

.DESCRIPTION
  This wrapper composes existing repository authorities instead of rediscovering launcher, save,
  or version rules. Certifying mode is mandatory: build/install/launch cannot be skipped.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
$RepoRoot = [IO.Path]::GetFullPath($RepoRoot)
Set-Location -LiteralPath $RepoRoot
. (Join-Path $RepoRoot 'scripts/governor-operator-common.ps1')

$startedUtc = [DateTime]::UtcNow
$outputRoot = Join-Path $RepoRoot 'artifacts/latest/disposable-trade-live-cert'
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
$resultPath = Join-Path $outputRoot 'result.json'
$reportPath = Join-Path $outputRoot 'report.md'
$events = [System.Collections.Generic.List[string]]::new()

function Add-Event([string]$Message) {
    $line = '[{0}] {1}' -f ([DateTime]::UtcNow.ToString('HH:mm:ss')), $Message
    $events.Add($line) | Out-Null
    Write-Host $line
}

function Write-CertResult {
    param(
        [Parameter(Mandatory = $true)][string]$TerminalState,
        [Parameter(Mandatory = $true)][string]$Verdict,
        [string]$Reason,
        [string]$Head,
        [string]$PinnedSave,
        [string]$SaveCompatibilityState,
        [string]$VisibleTradeState,
        $VisibleTradeResult
    )

    $payload = [ordered]@{
        schema = 'TbgDisposableVisibleTradeLiveCertResult.v1'
        generatedUtc = [DateTime]::UtcNow.ToString('o')
        startedUtc = $startedUtc.ToString('o')
        verdict = $Verdict
        terminalState = $TerminalState
        reason = $Reason
        sourceBranch = 'main'
        sourceCommit = $Head
        pinnedSave = $PinnedSave
        saveCompatibilityState = $SaveCompatibilityState
        visibleTradeTerminalState = $VisibleTradeState
        commandAckObserved = if ($VisibleTradeResult) { [bool]$VisibleTradeResult.commandAck.observed } else { $false }
        movementObserved = if ($VisibleTradeResult) { [bool]$VisibleTradeResult.movement.observed } else { $false }
        arrivalObserved = if ($VisibleTradeResult) { [bool]$VisibleTradeResult.arrival.observed } else { $false }
        buyObserved = if ($VisibleTradeResult) { [bool]$VisibleTradeResult.buy.observed } else { $false }
        buyInventoryDelta = if ($VisibleTradeResult) { [int]$VisibleTradeResult.buy.inventoryDelta } else { 0 }
        buyGoldDelta = if ($VisibleTradeResult) { [int]$VisibleTradeResult.buy.goldDelta } else { 0 }
        visibleTradeResultPath = 'artifacts/latest/visible-trade-proof.result.json'
        proofBoundary = 'Exact clean-main source + canonical version/save admission + real launcher/runtime + command ACK + movement + arrival + visible buy delta. Separate Sell-priority proof is not claimed.'
        events = @($events.ToArray())
    }
    $payload | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resultPath -Encoding UTF8
    @(
        '# Disposable visible trade live certificate','',
        ('- Verdict: `{0}`' -f $Verdict),
        ('- Terminal state: `{0}`' -f $TerminalState),
        ('- Source commit: `{0}`' -f $Head),
        ('- Pinned save: `{0}`' -f $PinnedSave),
        ('- Save compatibility: `{0}`' -f $SaveCompatibilityState),
        ('- Visible-trade state: `{0}`' -f $VisibleTradeState),
        ('- Command ACK observed: `{0}`' -f $payload.commandAckObserved),
        ('- Movement observed: `{0}`' -f $payload.movementObserved),
        ('- Arrival observed: `{0}`' -f $payload.arrivalObserved),
        ('- Buy observed: `{0}`' -f $payload.buyObserved),
        ('- Inventory delta: `{0}`' -f $payload.buyInventoryDelta),
        ('- Gold delta: `{0}`' -f $payload.buyGoldDelta),'',
        ('Proof boundary: {0}' -f $payload.proofBoundary),'',
        ('Reason: {0}' -f $Reason)
    ) | Set-Content -LiteralPath $reportPath -Encoding UTF8
}

function Stop-Cert {
    param(
        [string]$State,
        [string]$Reason,
        [int]$ExitCode,
        [string]$Head = '',
        [string]$PinnedSave = '',
        [string]$SaveState = '',
        [string]$TradeState = '',
        $TradeResult = $null
    )
    Add-Event "$State: $Reason"
    Write-CertResult -TerminalState $State -Verdict 'BLOCKED' -Reason $Reason -Head $Head -PinnedSave $PinnedSave -SaveCompatibilityState $SaveState -VisibleTradeState $TradeState -VisibleTradeResult $TradeResult
    Write-Host "Result: $resultPath"
    exit $ExitCode
}

function Invoke-ValidatorChild {
    param([Parameter(Mandatory = $true)][string]$ScriptPath)
    & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $ScriptPath -RepoRoot $RepoRoot
    return (if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE })
}

Add-Event 'DISPOSABLE VISIBLE TRADE LIVE CERT START'
$branch = (@(& git -C $RepoRoot branch --show-current 2>$null) -join '').Trim()
$head = (@(& git -C $RepoRoot rev-parse HEAD 2>$null) -join '').Trim()
$status = @(& git -C $RepoRoot status --porcelain 2>$null)
if ([string]::IsNullOrWhiteSpace($head)) { Stop-Cert -State 'BLOCKED_GIT_HEAD_UNKNOWN' -Reason 'Unable to resolve repository HEAD.' -ExitCode 20 }
if ($branch -ne 'main') { Stop-Cert -State 'BLOCKED_NOT_MAIN' -Reason "Certifying live proof requires branch main; actual=$branch." -ExitCode 21 -Head $head }
if (@($status).Count -gt 0) { Stop-Cert -State 'BLOCKED_DIRTY_WORKTREE' -Reason 'Certifying live proof requires a clean worktree.' -ExitCode 22 -Head $head }
Add-Event "Git preflight PASS: main@$head clean."

$versionValidator = Join-Path $RepoRoot 'scripts/tbg/Test-TbgVersionAuthority.ps1'
$disposableValidator = Join-Path $RepoRoot 'scripts/tbg/Test-TbgDisposableSaveRegistry.ps1'
$updater = Join-Path $RepoRoot 'scripts/tbg/Update-TbgDisposableSaveRegistry.ps1'
$saveGateScript = Join-Path $RepoRoot 'scripts/tbg/Invoke-TbgSaveCompatibility.ps1'
$visibleTrade = Join-Path $RepoRoot 'scripts/run-visible-trade-proof.ps1'
foreach ($required in @($versionValidator,$disposableValidator,$updater,$saveGateScript,$visibleTrade)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        Stop-Cert -State 'BLOCKED_REQUIRED_COMPONENT_MISSING' -Reason "Required cert component missing: $required" -ExitCode 23 -Head $head
    }
}

$versionExit = Invoke-ValidatorChild -ScriptPath $versionValidator
if ($versionExit -ne 0) { Stop-Cert -State 'BLOCKED_VERSION_AUTHORITY' -Reason "Version authority validator exited $versionExit." -ExitCode 24 -Head $head }
$disposableExit = Invoke-ValidatorChild -ScriptPath $disposableValidator
if ($disposableExit -ne 0) { Stop-Cert -State 'BLOCKED_DISPOSABLE_SAVE_CONTRACT' -Reason "Disposable-save validator exited $disposableExit." -ExitCode 25 -Head $head }
Add-Event 'Static authority gates PASS.'

$catalog = & $updater -RepoRoot $RepoRoot -PassThru
if ($null -eq $catalog) { Stop-Cert -State 'BLOCKED_DISPOSABLE_CATALOG_MISSING' -Reason 'Disposable-save updater returned no catalog result.' -ExitCode 26 -Head $head }
$pin = Get-GovernorActiveDisposableSavePin -RepoRoot $RepoRoot
if (-not $pin -or [string]::IsNullOrWhiteSpace([string]$pin.fullPath) -or -not (Test-Path -LiteralPath ([string]$pin.fullPath) -PathType Leaf)) {
    Add-Event 'No usable active disposable pin; creating a fresh owned clone from an exact-version eligible source.'
    $created = & $updater -RepoRoot $RepoRoot -CreateOwned -PassThru
    if ($null -eq $created -or [string]$created.createState -ne 'PASS_OWNED_DISPOSABLE_CREATED_AND_PINNED') {
        $state = if ($created) { [string]$created.createState } else { 'NO_RESULT' }
        Stop-Cert -State 'BLOCKED_DISPOSABLE_PIN_UNAVAILABLE' -Reason "Unable to create an exact-version disposable pin; state=$state." -ExitCode 27 -Head $head
    }
    $pin = Get-GovernorActiveDisposableSavePin -RepoRoot $RepoRoot
}

$savePath = [string]$pin.fullPath
$saveLeaf = [string]$pin.leafName
$saveGate = & $saveGateScript -Mode gate -TargetSavePath $savePath -RepoRoot $RepoRoot -NoExit -PassThru
$saveState = if ($saveGate) { [string]$saveGate.targetGateTerminalState } else { 'BLOCKED_SAVE_COMPATIBILITY_RESULT_MISSING' }
$saveRecord = if ($saveGate) { @($saveGate.saveRecords | Where-Object { $_.path -eq $savePath } | Select-Object -First 1) } else { @() }
if ($saveState -ne 'PASS_SAVE_VERSION_EXACT' -or $saveRecord.Count -ne 1 -or -not [bool]$saveRecord[0].autoLoadEligible) {
    Stop-Cert -State 'BLOCKED_SAVE_COMPATIBILITY' -Reason "Pinned save failed canonical exact-version admission; state=$saveState." -ExitCode 28 -Head $head -PinnedSave $saveLeaf -SaveState $saveState
}
Add-Event "Exact save admission PASS: $saveLeaf ($saveState)."

$visibleResultPath = Join-Path $RepoRoot 'artifacts/latest/visible-trade-proof.result.json'
if (Test-Path -LiteralPath $visibleResultPath) { Remove-Item -LiteralPath $visibleResultPath -Force }
Add-Event 'Invoking visible-trade coordinator in certifying mode (build/install/launch enabled).'
& powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $visibleTrade -RepoRoot $RepoRoot -ExpectedHead $head -DisposableSavePath $savePath
$visibleExit = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
if (-not (Test-Path -LiteralPath $visibleResultPath -PathType Leaf)) {
    Stop-Cert -State 'FAIL_VISIBLE_TRADE_RESULT_MISSING' -Reason "Visible-trade coordinator exited $visibleExit without a result artifact." -ExitCode 29 -Head $head -PinnedSave $saveLeaf -SaveState $saveState
}
$visibleItem = Get-Item -LiteralPath $visibleResultPath
if ($visibleItem.LastWriteTimeUtc -lt $startedUtc) {
    Stop-Cert -State 'FAIL_VISIBLE_TRADE_RESULT_STALE' -Reason 'Visible-trade result predates this cert run.' -ExitCode 30 -Head $head -PinnedSave $saveLeaf -SaveState $saveState
}
$tradeResult = Get-Content -LiteralPath $visibleResultPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
$tradeState = [string]$tradeResult.terminalState
$proofOk = $visibleExit -eq 0 `
    -and [string]$tradeResult.mode -eq 'certify' `
    -and $tradeState -eq 'PASS_VISIBLE_TRADE_PROVEN' `
    -and [string]$tradeResult.headSha -eq $head `
    -and [bool]$tradeResult.commandAck.observed `
    -and [bool]$tradeResult.movement.observed `
    -and [bool]$tradeResult.arrival.observed `
    -and [bool]$tradeResult.buy.observed `
    -and [int]$tradeResult.buy.inventoryDelta -gt 0 `
    -and [int]$tradeResult.buy.goldDelta -lt 0
if (-not $proofOk) {
    Stop-Cert -State 'FAIL_VISIBLE_TRADE_NOT_PROVEN' -Reason "Visible-trade proof did not satisfy the live-cert admission contract; exit=$visibleExit state=$tradeState." -ExitCode 31 -Head $head -PinnedSave $saveLeaf -SaveState $saveState -TradeState $tradeState -TradeResult $tradeResult
}

Add-Event "PASS: real visible purchase observed. item=$($tradeResult.buy.itemId) inventoryDelta=$($tradeResult.buy.inventoryDelta) goldDelta=$($tradeResult.buy.goldDelta)"
Write-CertResult -TerminalState 'PASS_DISPOSABLE_VISIBLE_TRADE_LIVE_CERT' -Verdict 'PASS' -Reason 'Exact clean-main source crossed canonical version/save/launcher/runtime gates and produced a real visible purchase.' -Head $head -PinnedSave $saveLeaf -SaveCompatibilityState $saveState -VisibleTradeState $tradeState -VisibleTradeResult $tradeResult
Write-Host 'PASS_DISPOSABLE_VISIBLE_TRADE_LIVE_CERT' -ForegroundColor Green
Write-Host "Result: $resultPath"
Write-Host "Report: $reportPath"
exit 0
