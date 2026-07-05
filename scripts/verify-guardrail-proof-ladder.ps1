# Offline verifier for the default proof ladder docs.
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$errors = New-Object System.Collections.Generic.List[string]

function ReadText([string]$Rel) {
    $path = Join-Path $root $Rel
    if (-not (Test-Path -LiteralPath $path)) {
        $errors.Add("missing file: $Rel") | Out-Null
        return ''
    }
    return Get-Content -LiteralPath $path -Raw
}

function Need([string]$Rel, [string]$Needle) {
    $text = ReadText $Rel
    if ($text.IndexOf($Needle, [StringComparison]::Ordinal) -lt 0) {
        $errors.Add("$Rel missing '$Needle'") | Out-Null
    }
}

$doc = 'docs\handoff\proof-claim-discipline.md'
$map = 'docs\handoff\default-guardrails.md'

Need $doc '# Proof Claim Discipline'
Need $doc 'Build PASS'
Need $doc 'Verifier PASS'
Need $doc 'Static PASS'
Need $doc 'Runtime PASS'
Need $doc 'Visible PASS'
Need $doc 'Product PASS'
Need $doc 'Stale evidence rule'
Need $map 'Build PASS does not imply Runtime PASS.'
Need $map 'Verifier PASS does not imply Runtime PASS.'
Need $map 'Runtime ACK does not imply product completion.'
Need $map 'Launcher handoff does not imply automation success.'
Need $map 'A checkpoint is progress, not completion.'

if ($errors.Count -gt 0) {
    Write-Host "FAIL: proof ladder verifier found $($errors.Count) issue(s)." -ForegroundColor Red
    foreach ($item in $errors) { Write-Host "  - $item" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: proof ladder verified.' -ForegroundColor Green
