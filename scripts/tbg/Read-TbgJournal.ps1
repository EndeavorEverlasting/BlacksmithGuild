[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$CorrelationId,
    [string]$EventType,
    [string]$SinceUtc
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
$quarantineDir = Join-Path $journalRoot 'quarantine'

function Read-TbgEventDir {
    param([string]$Dir, [string]$Label)
    if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { return @() }
    $files = Get-ChildItem -LiteralPath $Dir -Filter '*.json' -File
    $events = @()
    foreach ($f in $files) {
        try {
            $evt = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json
            $events += $evt
        } catch {
            Write-Warning "Skipping malformed $Label event: $($f.FullName)"
        }
    }
    return $events
}

$committed = @(Read-TbgEventDir -Dir $committedDir -Label 'committed')
$quarantined = @(Read-TbgEventDir -Dir $quarantineDir -Label 'quarantined')

$all = @($committed) + @($quarantined)
$all = @($all | Sort-Object -Property { [int]$_.sequence } -ErrorAction SilentlyContinue)

if ($CorrelationId) {
    $all = @($all | Where-Object { $_.correlationId -eq $CorrelationId })
}
if ($EventType) {
    $all = @($all | Where-Object { $_.eventType -eq $EventType })
}
if ($SinceUtc) {
    $since = [DateTime]::Parse($SinceUtc).ToUniversalTime()
    $all = @($all | Where-Object { [DateTime]::Parse($_.receivedUtc).ToUniversalTime() -ge $since })
}

$result = [ordered]@{
    schema = 'TbgJournalReadResult.v1'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    committedCount = @($committed).Count
    quarantinedCount = @($quarantined).Count
    filteredCount = @($all).Count
    events = @($all)
}

$result | ConvertTo-Json -Depth 10 | Write-Output
