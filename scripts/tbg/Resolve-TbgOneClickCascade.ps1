[CmdletBinding()]
param(
  [string]$RunRoot,
  [string]$TriggersDir='',
  [string]$OutputRoot=''
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if (-not $TriggersDir) { $TriggersDir = Join-Path $repoRoot '.tbg\harness\triggers.d' }
if (-not $OutputRoot) { $OutputRoot = Join-Path $repoRoot 'artifacts\latest\one-click-cascade' }
if (-not $RunRoot) { throw '-RunRoot is required (path to a completed one-click test run)' }
if (-not (Test-Path $RunRoot -PathType Container)) { throw "RunRoot not found: $RunRoot" }

$correlationId = [guid]::NewGuid().ToString('N')
$cascadeDepth = 0
$processedEvents = 0
$maxDepth = 10
$triggerLedger = @()
$cascadeEvents = @()
$errors = @()

function Read-JsonSafe([string]$Path) {
  if (-not (Test-Path $Path -PathType Leaf)) { return $null }
  try { return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $null }
}

function Write-CascadeEvent([string]$Type, $Payload=$null) {
  $cascadeEvents += [pscustomobject]@{
    eventId=[guid]::NewGuid().ToString('N');eventType=$Type
    correlationId=$correlationId;timestamp=[DateTime]::UtcNow.ToString('o')
    payload=$(if($Payload){$Payload}else{@{}})
  }
}

function Test-EventMatch($Event, $Trigger) {
  $matchTypes = @()
  try { $matchTypes = @($Trigger.eventMatch.eventTypes) } catch {}
  if ($matchTypes.Count -gt 0 -and $matchTypes -notcontains $Event.eventType) { return $false }
  $cond = ''
  try { $cond = [string]$Trigger.condition } catch {}
  if ($cond) {
    try { $cr = $ExecutionContext.InvokeCommand.ExpandString($cond); if (-not $cr) { return $false } } catch { return $false }
  }
  return $true
}

function Get-TbgRunEvents([string]$EventsPath) {
  if (-not (Test-Path $EventsPath -PathType Leaf)) { return @() }
  $result = @()
  foreach ($line in Get-Content -LiteralPath $EventsPath -Encoding UTF8) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    try { $result += ($line | ConvertFrom-Json) } catch {}
  }
  return $result
}

# Load triggers
if (-not (Test-Path $TriggersDir -PathType Container)) { throw "Triggers dir not found: $TriggersDir" }
$triggers = @()
foreach ($f in Get-ChildItem -LiteralPath $TriggersDir -Filter '*.trigger.json' -File) {
  try {
    $t = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($t.schema -ne 'tbg.one-click-test.trigger.v1') { throw "Unsupported trigger schema: $($t.schema)" }
    $triggers += [pscustomobject]@{
      triggerId=[string]$t.triggerId;displayName=[string]$t.displayName
      eventMatch=$t.eventMatch;condition=[string]$t.condition
      requiredFreshness=[string]$t.requiredFreshness;requiredProofLevel=[string]$t.requiredProofLevel
      downstreamOperation=[string]$t.downstreamOperation
      maxCascadeDepth=[int]$t.maxCascadeDepth;deduplicationKey=[string]$t.deduplicationKey
      cooldownSeconds=[int]$t.cooldownSeconds
      mutationAuthority=[string]$t.mutationAuthority
      sourcePath=$f.FullName
    }
  } catch { $errors += "Failed to parse trigger '$($f.Name)': $_" }
}

Write-CascadeEvent 'cascade.started' @{triggerCount=$triggers.Count;runRoot=$RunRoot}

# Load run events
$eventsPath = Join-Path $RunRoot 'events.jsonl'
$events = Get-TbgRunEvents $eventsPath
Write-CascadeEvent 'cascade.events.loaded' @{eventCount=$events.Count}

# Process events through triggers
$matched = @{}
$processedEvents = @()
$dedupLookup = @{}

foreach ($ev in $events) {
  $evPayload = $null
  try { $evPayload = $ev.payload } catch {}
  $e = [pscustomobject]@{
    eventId=[string]$ev.eventId;eventType=[string]$ev.eventType;runId=[string]$ev.runId
    testId=[string]$ev.testId;timestamp=[string]$ev.timestamp;payload=$evPayload
  }
  $processedEvents = $processedEvents + 1

  foreach ($trigger in $triggers) {
    $depthKey = "$($trigger.triggerId):$($e.eventId)"
    if ($dedupLookup.ContainsKey($depthKey)) { continue }

    if (-not (Test-EventMatch $e $trigger)) { continue }
    if ($cascadeDepth -ge $maxDepth) {
      Write-CascadeEvent 'cascade.depth.limit' @{triggerId=$trigger.triggerId;eventId=$e.eventId;depth=$cascadeDepth}
      continue
    }
    if ($cascadeDepth -ge $trigger.maxCascadeDepth) {
      Write-CascadeEvent 'cascade.trigger.depth.limit' @{triggerId=$trigger.triggerId;eventId=$e.eventId;maxDepth=$trigger.maxCascadeDepth}
      continue
    }

    $cascadeDepth = $cascadeDepth + 1
    $dedupLookup[$depthKey] = $true

    $matchEntry = [pscustomobject]@{
      triggerId=$trigger.triggerId;eventId=$e.eventId;eventType=$e.eventType
      testId=$e.testId;downstreamOperation=$trigger.downstreamOperation
      cascadeSequence=$cascadeDepth;matchedUtc=[DateTime]::UtcNow.ToString('o')
    }
    $triggerLedger += $matchEntry
    if ($matched.ContainsKey([string]$trigger.triggerId)) {
      $matched[[string]$trigger.triggerId] = [int]$matched[[string]$trigger.triggerId] + 1
    } else {
      $matched[[string]$trigger.triggerId] = 1
    }

    Write-CascadeEvent 'trigger.matched' @{
      triggerId=$trigger.triggerId;eventId=$e.eventId;eventType=$e.eventType
      downstreamOperation=$trigger.downstreamOperation;cascadeDepth=$cascadeDepth
    }
  }
}

Write-CascadeEvent 'cascade.completed' @{totalEvents=$processedEvents.Count;matchedTriggers=$triggerLedger.Count;depth=$cascadeDepth}

# Write output
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$cascadeResult = [ordered]@{
  schema='tbg.one-click-cascade.v1';correlationId=$correlationId
  runRoot=$RunRoot;triggerCount=$triggers.Count;eventCount=$processedEvents.Count
  matchedTriggerCount=$triggerLedger.Count;cascadeDepth=$cascadeDepth
  generatedUtc=[DateTime]::UtcNow.ToString('o')
  matched=$matched;errors=@($errors)
}
$cascadeResult | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $OutputRoot 'cascade-result.json') -Encoding UTF8

$triggerLedger | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $OutputRoot 'trigger-ledger.json') -Encoding UTF8

Write-Host "Cascade: $($triggerLedger.Count) trigger matches from $processedEvents events across $($triggers.Count) triggers, depth $cascadeDepth"
if ($errors.Count -gt 0) { Write-Warning "Errors: $($errors -join '; ')" }

return $cascadeResult
