$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$baselinePath = Join-Path $repoRoot 'docs\handoff\test-duration-inventory-baseline.tsv'
$longThresholdSec = 60
$excludeDirNames = @('.git', 'node_modules', '__pycache__', 'Output', 'Archive', 'dist', 'bin', 'obj', 'artifacts', 'logs', 'runtime')
$extensions = @('*.ps1', '*.cmd', '*.bat')
$allowMarkers = @(
    'AllowLongRun',
    'LongRunReason',
    'live_certificate',
    'manual_debug',
    'operator_approved_long_cert',
    'explicit long-run',
    'full_runtime_soak'
)

$patternSpecs = @(
    [pscustomobject]@{
        Name = 'Start-Sleep seconds'
        Regex = '(?i)\bStart-Sleep\b[^\r\n]*\s-(?:Seconds|s)\s+(?<Value>\d+)\b'
        Unit = 'sec'
        Threshold = $longThresholdSec
        FlagAnyPositive = $false
    },
    [pscustomobject]@{
        Name = 'duration seconds assignment'
        Regex = '(?i)\b(?:TimeoutSec|WaitSec|AttachWaitSec|MaxRuntimeSec|BudgetSec)\b\s*=\s*(?<Value>\d+)\b'
        Unit = 'sec'
        Threshold = $longThresholdSec
        FlagAnyPositive = $false
    },
    [pscustomobject]@{
        Name = 'duration seconds argument'
        Regex = '(?i)(?:^|[\s:/-])(?:TimeoutSec|WaitSec|AttachWaitSec|MaxRuntimeSec|BudgetSec)\s+(?<Value>\d+)\b'
        Unit = 'sec'
        Threshold = $longThresholdSec
        FlagAnyPositive = $false
    },
    [pscustomobject]@{
        Name = 'MaxRuntimeMinutes assignment'
        Regex = '(?i)\bMaxRuntimeMinutes\b\s*=\s*(?<Value>\d+)\b'
        Unit = 'min'
        Threshold = 1
        FlagAnyPositive = $true
    },
    [pscustomobject]@{
        Name = 'CMD timeout wait'
        Regex = '(?i)\btimeout\b\s+(?:/t\s+)?(?<Value>\d+)\b'
        Unit = 'sec'
        Threshold = $longThresholdSec
        FlagAnyPositive = $false
    }
)

$failures = New-Object System.Collections.Generic.List[object]
$allowed = New-Object System.Collections.Generic.List[object]
$baselineAllowed = New-Object System.Collections.Generic.List[object]
$staleBaseline = New-Object System.Collections.Generic.List[object]
$baseline = @{}

function Get-TbgRelativePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    return $Path.Substring($repoRoot.Length).TrimStart('\', '/')
}

function Normalize-TbgText {
    param([AllowEmptyString()][string]$Text)

    return (($Text.Trim() -replace '\s+', ' ')).ToLowerInvariant()
}

function New-TbgInventoryKey {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Value,
        [AllowEmptyString()][string]$Text
    )

    $normalizedPath = $Path.Replace('/', '\').ToLowerInvariant()
    $normalizedPattern = $Pattern.ToLowerInvariant()
    $normalizedValue = $Value.ToLowerInvariant()
    $normalizedText = Normalize-TbgText -Text $Text
    return "$normalizedPath|$normalizedPattern|$normalizedValue|$normalizedText"
}

function Read-TbgInventoryBaseline {
    if (-not (Test-Path -LiteralPath $baselinePath)) {
        throw "Inventory baseline missing: $baselinePath"
    }

    $table = @{}
    $lineNo = 0
    foreach ($line in Get-Content -LiteralPath $baselinePath -Encoding UTF8) {
        $lineNo++
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.TrimStart().StartsWith('#')) { continue }

        $parts = $line -split "`t", 6
        if ($parts.Count -ne 6) {
            throw "Malformed inventory baseline line ${lineNo}. Expected 6 tab-separated fields."
        }

        $key = New-TbgInventoryKey -Path $parts[0] -Pattern $parts[1] -Value $parts[2] -Text $parts[3]
        if (-not $table.ContainsKey($key)) {
            $table[$key] = New-Object 'System.Collections.Generic.Queue[object]'
        }

        $table[$key].Enqueue([pscustomobject]@{
            Path = $parts[0]
            Pattern = $parts[1]
            Value = $parts[2]
            Text = $parts[3]
            Class = $parts[4]
            Reason = $parts[5]
        })
    }

    return $table
}

function Test-TbgExcludedPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    foreach ($ex in $excludeDirNames) {
        if ($RelativePath -match "(^|[\\/])$([regex]::Escape($ex))([\\/]|$)") { return $true }
    }
    return $false
}

function Test-TbgCommentLine {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Line,
        [Parameter(Mandatory = $true)][string]$Extension
    )

    $trimmed = $Line.TrimStart()
    if ($Extension -eq '.ps1') { return $trimmed.StartsWith('#') }
    if (@('.cmd', '.bat') -contains $Extension) {
        return ($trimmed -match '^(?i:rem)(\s|$)' -or $trimmed.StartsWith('::'))
    }
    return $false
}

function Test-TbgAllowedLongRunContext {
    param(
        [AllowEmptyCollection()][AllowEmptyString()][string[]]$Lines = @(),
        [Parameter(Mandatory = $true)][int]$Index
    )

    if ($Lines.Count -eq 0) { return $false }

    $start = [Math]::Max(0, $Index - 2)
    $end = [Math]::Min($Lines.Count - 1, $Index + 2)
    $context = ($Lines[$start..$end] -join "`n")

    foreach ($marker in $allowMarkers) {
        if ($context.IndexOf($marker, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true }
    }
    return $false
}

function Test-TbgLongDurationMatch {
    param(
        [Parameter(Mandatory = $true)]$Spec,
        [Parameter(Mandatory = $true)][int]$Value
    )

    if ($Spec.FlagAnyPositive) { return ($Value -ge $Spec.Threshold) }
    return ($Value -ge $Spec.Threshold)
}

$baseline = Read-TbgInventoryBaseline

$files = foreach ($extension in $extensions) {
    Get-ChildItem -LiteralPath $repoRoot -Recurse -Filter $extension -File -ErrorAction SilentlyContinue
}

$files = $files | Where-Object {
    $relativePath = Get-TbgRelativePath -Path $_.FullName
    -not (Test-TbgExcludedPath -RelativePath $relativePath)
} | Sort-Object FullName -Unique

foreach ($file in $files) {
    $relativePath = Get-TbgRelativePath -Path $file.FullName
    $extension = $file.Extension.ToLowerInvariant()
    $lines = [string[]][System.IO.File]::ReadAllLines($file.FullName)

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if (Test-TbgCommentLine -Line $line -Extension $extension) { continue }

        foreach ($spec in $patternSpecs) {
            foreach ($match in [regex]::Matches($line, $spec.Regex)) {
                if (-not $match.Groups['Value'].Success) { continue }

                $value = [int]$match.Groups['Value'].Value
                if (-not (Test-TbgLongDurationMatch -Spec $spec -Value $value)) { continue }

                $record = [pscustomobject]@{
                    Path = $relativePath
                    Line = $i + 1
                    Pattern = $spec.Name
                    Value = "$value $($spec.Unit)"
                    Text = $line.Trim()
                    Class = ''
                    Reason = ''
                }

                if (Test-TbgAllowedLongRunContext -Lines $lines -Index $i) {
                    $allowed.Add($record) | Out-Null
                    continue
                }

                $key = New-TbgInventoryKey -Path $record.Path -Pattern $record.Pattern -Value $record.Value -Text $record.Text
                if ($baseline.ContainsKey($key) -and $baseline[$key].Count -gt 0) {
                    $base = $baseline[$key].Dequeue()
                    $record.Class = $base.Class
                    $record.Reason = $base.Reason
                    $baselineAllowed.Add($record) | Out-Null
                } else {
                    $failures.Add($record) | Out-Null
                }
            }
        }
    }
}

foreach ($entry in $baseline.GetEnumerator() | Sort-Object Name) {
    while ($entry.Value.Count -gt 0) {
        $staleBaseline.Add($entry.Value.Dequeue()) | Out-Null
    }
}

if ($allowed.Count -gt 0) {
    Write-Host "INFO: inventory guard allowed $($allowed.Count) explicit long-run marker match(es)."
    foreach ($item in $allowed) {
        Write-Host ("  ALLOW {0}:{1} [{2}] value={3}" -f $item.Path, $item.Line, $item.Pattern, $item.Value)
    }
}

if ($baselineAllowed.Count -gt 0) {
    Write-Host "INFO: inventory guard matched $($baselineAllowed.Count) documented baseline long-duration default(s)."
    foreach ($item in $baselineAllowed) {
        Write-Host ("  BASELINE {0}:{1} [{2}] value={3} class={4}" -f $item.Path, $item.Line, $item.Pattern, $item.Value, $item.Class)
    }
}

if ($staleBaseline.Count -gt 0) {
    Write-Host "FAIL: test duration inventory baseline contains $($staleBaseline.Count) stale unmatched entr(y/ies)." -ForegroundColor Red
    foreach ($item in $staleBaseline) {
        Write-Host ("  STALE {0} [{1}] value={2} class={3} :: {4}" -f $item.Path, $item.Pattern, $item.Value, $item.Class, $item.Text) -ForegroundColor Red
    }
    Write-Host ''
    Write-Host 'Fix: remove stale baseline rows or rerun the inventory after intentional debt changes. Stale baseline debt can bless reintroduced long waits.' -ForegroundColor Yellow
}

if ($failures.Count -gt 0) {
    Write-Host "FAIL: test duration inventory guard found $($failures.Count) new or undocumented casual long-duration default(s)." -ForegroundColor Red
    foreach ($item in $failures) {
        Write-Host ("  {0}:{1} [{2}] value={3} :: {4}" -f $item.Path, $item.Line, $item.Pattern, $item.Value, $item.Text) -ForegroundColor Red
    }
    Write-Host ''
    Write-Host 'Fix: keep defaults at 30 seconds, add explicit long-run markers nearby, or document existing debt in docs\handoff\test-duration-inventory-baseline.tsv with a reason.' -ForegroundColor Yellow
}

if (($staleBaseline.Count -gt 0) -or ($failures.Count -gt 0)) {
    exit 1
}

Write-Host "PASS: test duration inventory guard scanned $($files.Count) executable wrapper/script file(s); $($baselineAllowed.Count) baseline and $($allowed.Count) explicit long-run match(es) allowed." -ForegroundColor Green
exit 0