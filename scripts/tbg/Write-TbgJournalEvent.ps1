[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$EventType,
    [Parameter(Mandatory = $true)][ValidateSet('workflow','skill','engine','script','command','runtime adapter','external adapter','operator','reconciler','system')][string]$SourceKind,
    [Parameter(Mandatory = $true)][string]$SourceId,
    [Parameter(Mandatory = $true)][string]$CorrelationId,
    [string]$CausationId,
    [Parameter(Mandatory = $true)][string]$PayloadSchema,
    [hashtable]$Payload = @{},
    [ValidateSet('process','observe','quarantine','reject')][string]$RequestedDisposition = 'process',
    [string]$IdempotencyKey,
    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Get-Location).Path
}

function Resolve-TbgRepoPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    Join-Path $RepoRoot ($RelativePath -replace '/', [IO.Path]::DirectorySeparatorChar)
}

$journalRoot = Resolve-TbgRepoPath '.local/tbg-state/journal'
$committedDir = Join-Path $journalRoot 'committed'
New-Item -ItemType Directory -Force -Path $committedDir | Out-Null

$timestamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$random = -join ((1..6) | ForEach-Object { '{0:x}' -f (Get-Random -Minimum 0 -Maximum 16) })
$eventId = "evt-${timestamp}-${random}"

if ([string]::IsNullOrWhiteSpace($CausationId)) { $CausationId = $eventId }

if ([string]::IsNullOrWhiteSpace($IdempotencyKey)) {
    $IdempotencyKey = "$EventType|$SourceId|$CorrelationId|$timestamp"
}

$existingFiles = @(Get-ChildItem -LiteralPath $committedDir -Filter '*.json' -File -ErrorAction SilentlyContinue | Sort-Object Name)
$lastContentHash = '0000000000000000000000000000000000000000000000000000000000000000'
$nextSequence = 0
foreach ($ef in $existingFiles) {
    try {
        $existing = Get-Content -LiteralPath $ef.FullName -Raw | ConvertFrom-Json
        if ($existing.idempotencyKey -eq $IdempotencyKey) {
            $duplicate = [ordered]@{
                schema = 'TbgEvent.v1'
                eventId = $existing.eventId
                ingestionStatus = 'duplicate'
                message = "Event with idempotencyKey '$IdempotencyKey' already committed as $($existing.eventId)."
            }
            $duplicate | ConvertTo-Json -Depth 10 | Write-Output
            return
        }
        $lastContentHash = [string]$existing.contentHash
        $nextSequence = [int]$existing.sequence + 1
    } catch { }
}

$payloadJson = ($Payload | ConvertTo-Json -Depth 10 -Compress)
$sha = [System.Security.Cryptography.SHA256]::Create()
$hashBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($payloadJson))
$contentHash = 'sha256:' + [BitConverter]::ToString($hashBytes).Replace('-', '').ToLower()

$event = [ordered]@{
    schema = 'TbgEvent.v1'
    eventId = $eventId
    correlationId = $CorrelationId
    causationId = $CausationId
    eventType = $EventType
    source = [ordered]@{
        kind = $SourceKind
        id = $SourceId
    }
    receivedUtc = [DateTime]::UtcNow.ToString('o')
    contentHash = $contentHash
    payloadSchema = $PayloadSchema
    payload = $Payload
    requestedDisposition = $RequestedDisposition
    sequence = $nextSequence
    previousHash = $lastContentHash
    ingestionStatus = 'committed'
    processingAttempts = 0
    idempotencyKey = $IdempotencyKey
}

$safeName = ($eventId -replace '[:/\\]', '_') + '.json'
$outPath = Join-Path $committedDir $safeName
$tempPath = $outPath + '.tmp'

$event | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $tempPath -Encoding UTF8
Move-Item -LiteralPath $tempPath -Destination $outPath -Force

Write-Host "Journal event committed: $eventId (type=$EventType, status=committed)"
$event | ConvertTo-Json -Depth 10 | Write-Output
