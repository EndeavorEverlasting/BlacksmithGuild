[CmdletBinding()]
param(
  [string]$RunId,
  [string]$EventsPath,
  [string]$Profile,
  [int]$RefreshMs = 500,
  [switch]$Follow
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Clear-TbgConsole {
  if ($Host.UI.RawUI) {
    try { $Host.UI.RawUI.FlushInputBuffer() } catch {}
    [Console]::CursorVisible = $false
  }
}

function Write-TbgConsoleHeader {
  param([string]$RunId,[string]$Profile)
  Clear-TbgConsole
  $w = if ($Host.UI.RawUI) { $Host.UI.RawUI.WindowSize.Width } else { 80 }
  $line = ('=' * $w)
  Write-Host "`n$line" -ForegroundColor DarkCyan
  Write-Host "  TBG ForgeTest Live Console" -ForegroundColor Cyan
  Write-Host "  Run: $RunId  |  Profile: $Profile" -ForegroundColor Yellow
  Write-Host "$line" -ForegroundColor DarkCyan
}

function Write-TbgConsoleFooter {
  param([string]$StatusLine,[int]$Passed,[int]$Failed,[int]$Skipped,[int]$Total)
  $w = if ($Host.UI.RawUI) { $Host.UI.RawUI.WindowSize.Width } else { 80 }
  Write-Host ('-' * $w) -ForegroundColor DarkGray
  Write-Host "  $StatusLine" -ForegroundColor Cyan
  Write-Host "  PASS: $Passed  FAIL: $Failed  SKIP: $Skipped  TOTAL: $Total" -ForegroundColor $(if($Failed -gt 0){'Red'}else{'Green'})
  Write-Host ('=' * $w) -ForegroundColor DarkCyan
}

function Watch-TbgEvents {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
  $lines = Get-Content -LiteralPath $Path -Encoding UTF8
  $events = @()
  foreach ($line in $lines) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    try { $events += ($line | ConvertFrom-Json) } catch {}
  }
  return $events
}

if ($Follow) {
  Write-TbgConsoleHeader -RunId $RunId -Profile $Profile
  Write-Host "  Following event stream (Ctrl+C to stop)..." -ForegroundColor Gray
  Write-Host ""

  $lastEventCount = 0
  $passed = 0; $failed = 0; $skipped = 0; $total = 0
  $currentTest = ''
  $lastEvent = ''

  try {
    while ($true) {
      $events = Watch-TbgEvents -Path $EventsPath
      $newCount = @($events).Count

      if ($newCount -gt $lastEventCount) {
        for ($i = $lastEventCount; $i -lt $newCount; $i++) {
          $e = $events[$i]
          $ts = if ($e.timestamp -and $e.timestamp -match '\d{2}:\d{2}:\d{2}') {
            $e.timestamp
          } elseif ($e.timestamp) {
            try { ([DateTime]$e.timestamp).ToString('HH:mm:ss') } catch { $e.timestamp.Substring(11,8) }
          } else { '' }

          switch ($e.eventType) {
            'test.started' {
              $currentTest = $e.testId
              Write-Host "  [$ts] RUN   $($e.testId)" -ForegroundColor Cyan
            }
            'test.completed' {
              $passed++
              Write-Host "  [$ts] PASS  $($e.testId)" -ForegroundColor Green
              $currentTest = ''
            }
            'test.failed' {
              $failed++
              Write-Host "  [$ts] FAIL  $($e.testId)" -ForegroundColor Red
              $currentTest = ''
            }
            'test.skipped' {
              $skipped++
              Write-Host "  [$ts] SKIP  $($e.testId)" -ForegroundColor Gray
            }
            'test.stdout' {
              if ($e.payload -and $e.payload.text) {
                foreach ($line in ($e.payload.text -split "`n")) {
                  if (-not [string]::IsNullOrWhiteSpace($line)) {
                    Write-Host "         $line" -ForegroundColor DarkGray
                  }
                }
              }
            }
            'artifact.registered' {
              Write-Host "  [$ts] ART   $($e.payload.path)" -ForegroundColor Magenta
            }
            'run.started' { Write-Host "  [$ts] START Run $($e.runId)" -ForegroundColor Yellow }
            'run.completed' { Write-Host "  [$ts] DONE  Completed" -ForegroundColor Green }
            'run.blocked' { Write-Host "  [$ts] STOP  Blocked" -ForegroundColor Yellow }
            default {
              if ($e.testId) {
                Write-Host "  [$ts] $($e.eventType) $($e.testId)" -ForegroundColor DarkGray
              } else {
                Write-Host "  [$ts] $($e.eventType)" -ForegroundColor DarkGray
              }
            }
          }
          $total = $passed + $failed + $skipped
        }
        Write-TbgConsoleFooter -StatusLine "Status: $([DateTime]::UtcNow.ToString('HH:mm:ss'))" -Passed $passed -Failed $failed -Skipped $skipped -Total $total
      }

      Start-Sleep -Milliseconds $RefreshMs
    }
  } catch {
    Write-Host "`n  Live console stopped." -ForegroundColor Yellow
  }
  [Console]::CursorVisible = $true
} else {
  Write-TbgConsoleHeader -RunId $RunId -Profile $Profile
  $events = Watch-TbgEvents -Path $EventsPath
  foreach ($e in $events) {
    Write-Host "  $($e.eventType) $($e.testId)" -ForegroundColor White
  }
  Write-TbgConsoleFooter -StatusLine "Snapshot at $([DateTime]::UtcNow.ToString('HH:mm:ss'))" -Passed 0 -Failed 0 -Skipped 0 -Total 0
}
