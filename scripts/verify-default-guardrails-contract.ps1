# Offline contract verifier for the default guardrail map.
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]

function Read-RepoText {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        $failures.Add("missing file: $RelativePath") | Out-Null
        return ''
    }
    return Get-Content -LiteralPath $path -Raw
}

function Assert-TextContains {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Needle,
        [string]$Why = ''
    )
    $text = Read-RepoText -RelativePath $RelativePath
    if ($text.IndexOf($Needle, [System.StringComparison]::Ordinal) -lt 0) {
        $suffix = if ($Why) { " ($Why)" } else { '' }
        $failures.Add("$RelativePath missing '$Needle'$suffix") | Out-Null
    }
}

$guardrails = 'docs\handoff\default-guardrails.md'
$manifest = 'docs\handoff\guardrail-map.manifest.json'
$proof = 'docs\handoff\proof-claim-discipline.md'
$contamination = 'docs\handoff\runtime-contamination-doctrine.md'
$actionEvidence = 'docs\handoff\campaign-action-evidence-schema.md'

Assert-TextContains -RelativePath $guardrails -Needle '# Default Guardrails' -Why 'primary map must exist'
Assert-TextContains -RelativePath $guardrails -Needle 'Repo hygiene guardrails' -Why 'repo hygiene layer must exist'
Assert-TextContains -RelativePath $guardrails -Needle 'Evidence and claim guardrails' -Why 'evidence layer must exist'
Assert-TextContains -RelativePath $guardrails -Needle 'Agent workflow guardrails' -Why 'agent workflow layer must exist'
Assert-TextContains -RelativePath $guardrails -Needle 'Runtime and game-state guardrails' -Why 'runtime layer must exist'
Assert-TextContains -RelativePath $guardrails -Needle 'Domain automation guardrails' -Why 'domain layer must exist'
Assert-TextContains -RelativePath $guardrails -Needle 'Architecture and orchestration guardrails' -Why 'architecture layer must exist'
Assert-TextContains -RelativePath $guardrails -Needle 'Build PASS does not imply Runtime PASS.' -Why 'proof distinction must be explicit'
Assert-TextContains -RelativePath $guardrails -Needle 'Launcher handoff does not imply automation success.' -Why 'launcher proof boundary must be explicit'
Assert-TextContains -RelativePath $guardrails -Needle 'game_spawned != attach_ready' -Why 'runtime readiness ladder must be explicit'
Assert-TextContains -RelativePath $guardrails -Needle 'Automate the hands, not the consequences.' -Why 'product safety doctrine must be explicit'
Assert-TextContains -RelativePath $guardrails -Needle 'scripts/invoke-agent-stop-hook.ps1' -Why 'highest-priority missing stop hook must be tracked'
Assert-TextContains -RelativePath $guardrails -Needle 'proof claim discipline verifier' -Why 'proof verifier gap must be tracked'
Assert-TextContains -RelativePath $guardrails -Needle 'byte-safe text replacement helper' -Why 'byte-safe helper gap must be tracked'
Assert-TextContains -RelativePath $guardrails -Needle 'runtime contamination classifier' -Why 'contamination classifier gap must be tracked'
Assert-TextContains -RelativePath $guardrails -Needle 'campaign action evidence schema implementation' -Why 'campaign action evidence implementation gap must be tracked'

Assert-TextContains -RelativePath $manifest -Needle '"policyId": "default-guardrails"' -Why 'manifest policy id must exist'
Assert-TextContains -RelativePath $manifest -Needle '"primaryDoc": "docs/handoff/default-guardrails.md"' -Why 'manifest primary doc must be set'
Assert-TextContains -RelativePath $manifest -Needle '"repo hygiene"' -Why 'manifest must list repo hygiene layer'
Assert-TextContains -RelativePath $manifest -Needle '"evidence and claims"' -Why 'manifest must list evidence layer'
Assert-TextContains -RelativePath $manifest -Needle '"agent workflow"' -Why 'manifest must list agent workflow layer'
Assert-TextContains -RelativePath $manifest -Needle '"runtime and game state"' -Why 'manifest must list runtime layer'
Assert-TextContains -RelativePath $manifest -Needle '"domain automation"' -Why 'manifest must list domain layer'
Assert-TextContains -RelativePath $manifest -Needle '"architecture and orchestration"' -Why 'manifest must list architecture layer'
Assert-TextContains -RelativePath $manifest -Needle '"checkpoint is not completion"' -Why 'manifest must include checkpoint distinction'
Assert-TextContains -RelativePath $manifest -Needle '"BlacksmithGuild_CampaignActionEvidence.json"' -Why 'manifest must include campaign action evidence output'
Assert-TextContains -RelativePath $manifest -Needle '"contractVerifier": "scripts/verify-default-guardrails-contract.ps1"' -Why 'manifest must point to this verifier'

Assert-TextContains -RelativePath $proof -Needle '# Proof Claim Discipline' -Why 'proof discipline doc must exist'
Assert-TextContains -RelativePath $proof -Needle 'Build PASS' -Why 'proof ladder must include build'
Assert-TextContains -RelativePath $proof -Needle 'Verifier PASS' -Why 'proof ladder must include verifier'
Assert-TextContains -RelativePath $proof -Needle 'Runtime PASS' -Why 'proof ladder must include runtime'
Assert-TextContains -RelativePath $proof -Needle 'Visible PASS' -Why 'proof ladder must include visible'
Assert-TextContains -RelativePath $proof -Needle 'Product PASS' -Why 'proof ladder must include product'
Assert-TextContains -RelativePath $proof -Needle 'Forbidden inflation examples' -Why 'inflation examples must be documented'
Assert-TextContains -RelativePath $proof -Needle 'Unsupported claim blocker' -Why 'unsupported claim blocker must be documented'
Assert-TextContains -RelativePath $proof -Needle 'scripts/verify-proof-claim-discipline-contract.ps1' -Why 'future proof verifier must be named'

Assert-TextContains -RelativePath $contamination -Needle '# Runtime Contamination Doctrine' -Why 'contamination doc must exist'
Assert-TextContains -RelativePath $contamination -Needle 'Manual input is not proof.' -Why 'manual input rule must be explicit'
Assert-TextContains -RelativePath $contamination -Needle 'Supply values for the following parameters:' -Why 'interactive prompt example must be present'
Assert-TextContains -RelativePath $contamination -Needle 'proof_contaminated' -Why 'contamination classification must be documented'
Assert-TextContains -RelativePath $contamination -Needle 'zero-click proof' -Why 'zero-click boundary must be documented'
Assert-TextContains -RelativePath $contamination -Needle 'scripts/classify-runtime-proof-contamination.ps1' -Why 'future contamination classifier must be named'

Assert-TextContains -RelativePath $actionEvidence -Needle '# Campaign Action Evidence Schema' -Why 'campaign action evidence doc must exist'
Assert-TextContains -RelativePath $actionEvidence -Needle 'BlacksmithGuild_CampaignActionEvidence.json' -Why 'campaign evidence output must be named'
Assert-TextContains -RelativePath $actionEvidence -Needle 'TbgCampaignActionEvidence.v1' -Why 'schema version must be named'
Assert-TextContains -RelativePath $actionEvidence -Needle 'Market' -Why 'market evidence rules must exist'
Assert-TextContains -RelativePath $actionEvidence -Needle 'Smithing' -Why 'smithing evidence rules must exist'
Assert-TextContains -RelativePath $actionEvidence -Needle 'Travel' -Why 'travel evidence rules must exist'
Assert-TextContains -RelativePath $actionEvidence -Needle 'Progression' -Why 'progression evidence rules must exist'
Assert-TextContains -RelativePath $actionEvidence -Needle 'Companion' -Why 'companion evidence rules must exist'
Assert-TextContains -RelativePath $actionEvidence -Needle 'Horse market' -Why 'horse evidence rules must exist'
Assert-TextContains -RelativePath $actionEvidence -Needle 'CampaignActionEvidence' -Why 'action evidence term must recur'
Assert-TextContains -RelativePath $actionEvidence -Needle 'CampaignEngineOutcome' -Why 'engine outcome relationship must be documented'

if ($failures.Count -gt 0) {
    Write-Host "FAIL: default guardrails contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: default guardrails contract verified.' -ForegroundColor Green
