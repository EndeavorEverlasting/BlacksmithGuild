# Classify runtime proof contamination from local text artifacts.

param(
    [string]$EvidenceRoot = $PWD.Path,
    [string]$OutputPath = $null,
    [int]$Tail = 200
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $OutputPath) {
    $OutputPath = Join-Path $repoRoot 'BlacksmithGuild_RuntimeContamination.json'
}

$patterns = @(
    @{ id = 'interactive_parameter_prompt'; text = 'Supply values for the following parameters:'; severity = 'blocking' },
    @{ id = 'launch_intent_prompt'; text = 'LaunchIntent:'; severity = 'blocking' },
    @{ id = 'safe_mode_modal'; text = 'safe_mode_detected'; severity = 'blocking' },
    @{ id = 'crash_reporter'; text = 'crash reporter'; severity = 'blocking' },
    @{ id = 'operator_action_required'; text = 'operator_action_required'; severity = 'blocking' },
    @{ id = 'manual_input'; text = 'manual input'; severity = 'blocking' },
    @{ id = 'stale_runtime_surface'; text = 'stale'; severity = 'warning' }
)

$matches = New-Object System.Collections.Generic.List[object]
$files = @()
if (Test-Path -LiteralPath $EvidenceRoot) {
    $files = Get-ChildItem -LiteralPath $EvidenceRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in @('.log', '.txt', '.json', '.jsonl') } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 200
}

foreach ($file in $files) {
    try {
        $content = (Get-Content -LiteralPath $file.FullName -Tail $Tail -ErrorAction Stop) -join "`n"
    } catch {
        continue
    }
    foreach ($pattern in $patterns) {
        if ($content.IndexOf($pattern.text, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $matches.Add([pscustomobject][ordered]@{
                id = $pattern.id
                severity = $pattern.severity
                evidencePath = $file.FullName
                pattern = $pattern.text
                observedUtc = $file.LastWriteTimeUtc.ToString('o')
            }) | Out-Null
        }
    }
}

$blocking = @($matches | Where-Object { $_.severity -eq 'blocking' }).Count -gt 0
$classification = if ($blocking) { 'proof_contaminated' } elseif ($matches.Count -gt 0) { 'possible_contamination' } else { 'no_contamination_signal_found' }

$result = [pscustomobject][ordered]@{
    schema = 'TbgRuntimeContamination.v1'
    generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    evidenceRoot = $EvidenceRoot
    classification = $classification
    blocking = $blocking
    matches = @($matches)
    allowedClaims = if ($blocking) { @('A contamination signal was observed.', 'The run should be treated as blocked until a fresh clean proof exists.') } else { @('No known contamination signal was found in scanned artifacts.') }
    forbiddenClaims = if ($blocking) { @('Do not claim zero-click proof from this evidence set.', 'Do not claim route or movement completion from this evidence set.') } else { @('This scan alone does not prove runtime success.') }
}

$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host ("Runtime contamination classification: {0}" -f $classification) -ForegroundColor Cyan
Write-Host ("Wrote: {0}" -f $OutputPath) -ForegroundColor Green
if ($blocking) { exit 2 }
