# Visible Trade Proof event schema helpers.
# Every event includes: schema, runId, correlationId, sequence, timestamp UTC,
# stage, status, subject, action, object, condition, evidence, sentence.

Set-StrictMode -Version Latest

function New-TbgVisibleTradeProofEvent {
    param(
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$CorrelationId,
        [Parameter(Mandatory = $true)][int]$Sequence,
        [Parameter(Mandatory = $true)][string]$Stage,
        [Parameter(Mandatory = $true)][ValidateSet('started','passed','failed','blocked','skipped','info','adjusted')][string]$Status,
        [Parameter(Mandatory = $true)][string]$Subject,
        [Parameter(Mandatory = $true)][string]$Action,
        [Parameter(Mandatory = $true)][string]$Object,
        [string]$Condition = '',
        [string]$Evidence = '',
        [Parameter(Mandatory = $true)][string]$Sentence
    )

    $timestamp = (Get-Date).ToUniversalTime().ToString('o')

    return [ordered]@{
        schema = 'TbgVisibleTradeProofEvent.v1'
        runId = $RunId
        correlationId = $CorrelationId
        sequence = $Sequence
        timestampUtc = $timestamp
        stage = $Stage
        status = $Status
        subject = $Subject
        action = $Action
        object = $Object
        condition = $Condition
        evidence = $Evidence
        sentence = $Sentence
    }
}

function Write-TbgVisibleTradeProofEvent {
    param(
        [Parameter(Mandatory = $true)]$Event,
        [Parameter(Mandatory = $true)][string]$EventsPath,
        [Parameter(Mandatory = $true)][string]$ProgressPath
    )

    $line = '[{0}] {1}: {2}' -f $Event.timestampUtc, $Event.status.ToUpperInvariant(), $Event.sentence
    Add-Content -LiteralPath $ProgressPath -Value $line -Encoding UTF8
    Add-Content -LiteralPath $EventsPath -Value ($Event | ConvertTo-Json -Compress -Depth 8) -Encoding UTF8
    Write-Host $line
}

function Get-TbgVisibleTradeProofStageList {
    return @(
        'preflight'
        'workspace'
        'validation'
        'runtime-stop'
        'build'
        'install'
        'hash-verification'
        'evidence-start'
        'launch'
        'campaign-ready'
        'route-request'
        'command-ack'
        'time-advance'
        'movement'
        'checkpoint'
        'arrival'
        'buy'
        'travel'
        'sell'
        'runtime-stop-final'
        'capsule'
        'remote-publish'
        'closeout'
    )
}

function Get-TbgVisibleTradeProofTerminalStates {
    return @(
        'PASS_VISIBLE_TRADE_PROVEN'
        'BLOCKED_CAMPAIGN_NOT_READY'
        'BLOCKED_RUNTIME_ENVIRONMENT_UNAVAILABLE'
        'FAIL_SOURCE_BUILD_INSTALL_MISMATCH'
        'FAIL_STATIC_VALIDATION'
        'FAIL_LAUNCHER_HANDOFF'
        'FAIL_COMMAND_NOT_ACKNOWLEDGED'
        'FAIL_CAMPAIGN_TIME_NOT_ADVANCING'
        'FAIL_NO_POSITION_DELTA'
        'FAIL_ROUTE_CHECKPOINT_NOT_OBSERVED'
        'FAIL_ARRIVAL_NOT_OBSERVED'
        'FAIL_BUY_DELTA_NOT_OBSERVED'
        'FAIL_SELL_DELTA_NOT_OBSERVED'
        'FAIL_EVIDENCE_INCOMPLETE'
        'FAIL_REMOTE_EVIDENCE_NOT_PUBLISHED'
        'CANCELLED_SAFE_STOP'
    )
}
