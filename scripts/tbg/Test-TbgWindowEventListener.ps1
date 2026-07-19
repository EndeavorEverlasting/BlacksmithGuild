[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-TbgTrue {
    param([bool]$Condition, [Parameter(Mandatory = $true)][string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-TbgPowerShellParses {
    param([Parameter(Mandatory = $true)][string]$Path)
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors) | Out-Null
    if (@($errors).Count -gt 0) { throw "$Path does not parse: $(@($errors | ForEach-Object Message) -join '; ')" }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$listenerPath = Join-Path $repoRoot 'scripts\tbg\Start-TbgWindowEventListener.ps1'
$fixturePath = Join-Path $repoRoot '.tbg\harness\fixtures\window-intelligence\window-event-listener.fixture.json'
$contractPath = Join-Path $repoRoot '.tbg\workflows\window-metadata-intelligence.contract.json'
$policyPath = Join-Path $repoRoot '.tbg\harness\policies\window-intelligence.policy.json'
$wrapperPath = Join-Path $repoRoot 'ForgeWindowIntel.cmd'

foreach ($path in @($listenerPath, $fixturePath, $contractPath, $policyPath, $wrapperPath)) {
    Assert-TbgTrue (Test-Path -LiteralPath $path -PathType Leaf) "Required listener surface is missing: $path"
}
Assert-TbgPowerShellParses -Path $listenerPath
Assert-TbgPowerShellParses -Path (Join-Path $repoRoot 'scripts\tbg\Invoke-TbgWindowIntelligence.ps1')

$fixture = Get-Content -LiteralPath $fixturePath -Raw -Encoding UTF8 | ConvertFrom-Json
$requiredCases = @('create-show-destroy', 'duplicate-hook-poll', 'unknown-quarantine', 'out-of-order', 'listener-restart', 'missed-event-reconciliation', 'callback-failure')
foreach ($caseId in $requiredCases) {
    Assert-TbgTrue ((@($fixture.events | Where-Object { [string]$_.caseId -eq $caseId }).Count) -gt 0) "Fixture case '$caseId' is missing."
}

$contract = Get-Content -LiteralPath $contractPath -Raw -Encoding UTF8 | ConvertFrom-Json
$policy = Get-Content -LiteralPath $policyPath -Raw -Encoding UTF8 | ConvertFrom-Json
$wrapper = Get-Content -LiteralPath $wrapperPath -Raw -Encoding UTF8
Assert-TbgTrue ([string]$contract.eventListenerPath -eq 'scripts/tbg/Start-TbgWindowEventListener.ps1') 'Contract does not register the event listener.'
Assert-TbgTrue ([string]$contract.listenCommand -match 'ForgeWindowIntel.cmd listen') 'Contract does not register the bounded listen command.'
Assert-TbgTrue ((@($policy.listenerRules) -join '|') -match 'SetWinEventHook') 'Policy does not require event-first hooks.'
Assert-TbgTrue ($wrapper -match 'Invoke-TbgWindowIntelligence.ps1') 'Wrapper no longer routes to window intelligence.'

$result = & $listenerPath -Mode fixture -FixturePath $fixturePath -RunId ('listener-test-{0}' -f [Guid]::NewGuid().ToString('N').Substring(0, 8)) -PassThru
Assert-TbgTrue ($null -ne $result) 'Fixture listener did not return a result.'
Assert-TbgTrue (Test-Path -LiteralPath $result.eventsPath -PathType Leaf) 'Listener did not write events.jsonl.'
Assert-TbgTrue (Test-Path -LiteralPath $result.statusPath -PathType Leaf) 'Listener did not write observer-status.json.'

$events = @(Get-Content -LiteralPath $result.eventsPath -Encoding UTF8 | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_ | ConvertFrom-Json })
Assert-TbgTrue ((@($events | Where-Object { $_.schema -ne 'TbgRuntimeObserverEvent.v1' -or $_.version -ne 1 }).Count) -eq 0) 'Listener emitted a noncanonical runtime observer envelope.'
Assert-TbgTrue ((@($events | Where-Object { $_.eventType -eq 'window.created' }).Count) -ge 2) 'Listener did not preserve create observations.'
Assert-TbgTrue ((@($events | Where-Object { $_.eventType -eq 'window.destroyed' -and $_.payload.data.disposition -eq 'disappearance_only' }).Count) -eq 1) 'Disappearance was not bounded to observation only.'
Assert-TbgTrue ((@($events | Where-Object { $_.eventType -eq 'window.title_changed' }).Count) -eq 1) 'Hook and poll duplicate was not deduplicated.'
Assert-TbgTrue ((@($events | Where-Object { $_.eventType -eq 'observer.reconciled' }).Count) -ge 1) 'Missed-event reconciliation was not emitted.'
Assert-TbgTrue ((@($events | Where-Object { $_.eventType -eq 'observer.gap' -and $_.payload.data.reason -eq 'callback_failure' }).Count) -eq 1) 'Callback failure was not isolated as observer.gap.'
Assert-TbgTrue ($result.deduplicated -ge 1) 'Cross-source deduplication count was not recorded.'
Assert-TbgTrue ((@($events | Where-Object { $_.eventType -eq 'window.created' -and $_.payload.data.quarantine }).Count) -eq 1) 'Unknown window was not retained as a quarantined observation.'

Write-Host 'PASS: event-first listener fixture emitted canonical envelopes, deduplicated hook/poll overlap, retained unknown quarantine, recorded callback gaps, and reconciled missed observations.'
