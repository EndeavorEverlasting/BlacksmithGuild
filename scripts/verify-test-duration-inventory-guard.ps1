$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
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

function Get-TbgRelativePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    return $Path.Substring($repoRoot.Length).TrimStart('\', '/')
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
                }

                if (Test-TbgAllowedLongRunContext -Lines $lines -Index $i) {
                    $allowed.Add($record) | Out-Null
                } else {
                    $failures.Add($record) | Out-Null
                }
            }
        }
    }
}

if ($allowed.Count -gt 0) {
    Write-Host "INFO: inventory guard allowed $($allowed.Count) explicit long-run match(es)."
    foreach ($item in $allowed) {
        Write-Host ("  ALLOW {0}:{1} [{2}] value={3}" -f $item.Path, $item.Line, $item.Pattern, $item.Value)
    }
}

if ($failures.Count -gt 0) {
    Write-Host "FAIL: test duration inventory guard found $($failures.Count) casual long-duration default(s)." -ForegroundColor Red
    foreach ($item in $failures) {
        Write-Host ("  {0}:{1} [{2}] value={3} :: {4}" -f $item.Path, $item.Line, $item.Pattern, $item.Value, $item.Text) -ForegroundColor Red
    }
    Write-Host ''
    Write-Host 'Fix: keep defaults at 30 seconds, or mark the nearby code as explicit long-run behavior with AllowLongRun/LongRunReason and an operator-facing reason.' -ForegroundColor Yellow
    exit 1
}

Write-Host "PASS: test duration inventory guard scanned $($files.Count) executable wrapper/script file(s); $($allowed.Count) explicit long-run match(es) allowed." -ForegroundColor Green
exit 0
