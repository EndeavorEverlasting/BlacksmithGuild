param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Require-Text {
    param([string]$Path, [string]$Needle)
    $full = Join-Path $RepoRoot $Path
    if (-not (Test-Path -LiteralPath $full)) { throw "Missing file: $Path" }
    $text = Get-Content -LiteralPath $full -Raw
    if ($text.IndexOf($Needle, [System.StringComparison]::Ordinal) -lt 0) {
        throw "Missing '$Needle' in $Path"
    }
}

$runner = 'scripts/run-maptrade-branch-autostart-proof.ps1'
Require-Text $runner 'dirty_worktree'
Require-Text $runner 'preexisting_game_process_before_build'
Require-Text $runner 'installed_dll_hash_mismatch'
Require-Text $runner "`$surface -eq 'settlement_menu'"
Require-Text $runner "Invoke-ForgeCommandChecked -Command 'SetMapTradeAutomation'"
Require-Text $runner "exactAutostartSource = [string]`$cert.source -eq 'campaign_tick_recursive_branch_travel'"
Require-Text $runner 'sameTickReturnObserved'
Require-Text $runner 'sameTickHoldAbsent'
Require-Text $runner 'positivePartyDistance'
Require-Text $runner "Invoke-ForgeCommandChecked -Command 'SetMapTradeManual'"
Require-Text $runner 'Do not substitute historical evidence'

Require-Text 'src/BlacksmithGuild/MapTrade/MapTradeEvidenceWriter.cs' 'autoStartTickReturnObserved'
Require-Text 'src/BlacksmithGuild/MapTrade/MapTradeEvidenceWriter.cs' 'sameTickHoldObserved'
Require-Text 'src/BlacksmithGuild/MapTrade/MapTradeEvidenceWriter.cs' 'partyMovedDistance'
Require-Text 'src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs' 'MarkAutoStartTickReturn();'
Require-Text 'src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs' 'ObserveRouteMovement();'

Write-Host 'MapTrade branch autostart proof contract: PASS'
