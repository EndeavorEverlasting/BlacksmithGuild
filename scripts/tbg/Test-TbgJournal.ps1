[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$OutputRoot = 'artifacts/latest/journal'
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

$errors = [System.Collections.Generic.List[string]]::new()

$journalRoot = Resolve-TbgRepoPath '.local/tbg-state/journal'
$committedDir = Join-Path $journalRoot 'committed'

if (-not (Test-Path -LiteralPath $committedDir -PathType Container)) {
    $errors.Add('Journal committed directory does not exist.')
}
else {
    $files = Get-ChildItem -LiteralPath $committedDir -Filter '*.json' -File
    $seenIds = @{}
    $prevHash = '0000000000000000000000000000000000000000000000000000000000000000'
    $events = @()
    foreach ($f in $files) {
        try {
            $evt = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json
            $events += [PSCustomObject]@{ File = $f; Event = $evt }
        } catch {
            $errors.Add("Malformed JSON in journal event: $($f.Name)")
        }
    }
    $sorted = @($events | Sort-Object { [int]$_.Event.sequence })

    foreach ($entry in $sorted) {
        $f = $entry.File
        $evt = $entry.Event

        if ([string]::IsNullOrWhiteSpace([string]$evt.eventId)) {
            $errors.Add("Event $($f.Name) missing eventId.")
        }
        if ([string]::IsNullOrWhiteSpace([string]$evt.eventType)) {
            $errors.Add("Event $($f.Name) missing eventType.")
        }
        if ([string]::IsNullOrWhiteSpace([string]$evt.contentHash)) {
            $errors.Add("Event $($f.Name) missing contentHash.")
        }
        if ([string]::IsNullOrWhiteSpace([string]$evt.sequence)) {
            $errors.Add("Event $($f.Name) missing sequence.")
        }

        $eid = [string]$evt.eventId
        if ($seenIds.ContainsKey($eid)) {
            $errors.Add("Duplicate eventId '$eid' found in journal.")
        } else {
            $seenIds[$eid] = $true
        }

        $pHash = [string]$evt.previousHash
        if ($pHash -ne $prevHash) {
            $errors.Add("Hash chain break at $($evt.eventId): expected previousHash '$prevHash' but got '$pHash'.")
        }
        $prevHash = [string]$evt.contentHash
    }
}

$outputPath = Resolve-TbgRepoPath $OutputRoot
New-Item -ItemType Directory -Force -Path $outputPath | Out-Null

$status = if ($errors.Count -eq 0) { 'PASS_ZERO_REMAINDERS' } else { 'FAIL_STATE_CORRUPTION' }

$result = [ordered]@{
    schema = 'TbgJournalValidationResult.v1'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    status = $status
    eventCount = @((Get-ChildItem -LiteralPath $committedDir -Filter '*.json' -File -ErrorAction SilentlyContinue)).Count
    errors = @($errors)
    proofLevel = 'static test'
}
$result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $outputPath 'journal-validation.result.json') -Encoding UTF8

$reportLines = @(
    '# TBG Journal Validation',
    '',
    "Status: **$status**",
    "- Events: $($result.eventCount)",
    "- Errors: $($errors.Count)",
    ''
)
if ($errors.Count -gt 0) {
    $reportLines += '## Errors'
    $reportLines += ''
    foreach ($e in $errors) { $reportLines += "- $e" }
    $reportLines += ''
}
$reportLines -join "`r`n" | Set-Content -LiteralPath (Join-Path $outputPath 'journal-validation.report.md') -Encoding UTF8

Write-Host "Journal validation: $status (events=$($result.eventCount), errors=$($errors.Count))"
if ($errors.Count -gt 0) { exit 1 }
