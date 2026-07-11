param(
    [string]$ContractId = "local-mcp-code-intelligence",
    [string]$OutputPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Find-TbgRepoRoot {
    $cursor = (Get-Location).Path
    while ($true) {
        if (Test-Path -LiteralPath (Join-Path $cursor ".tbg/harness/manifest.json")) { return $cursor }
        $parent = Split-Path -Parent $cursor
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $cursor) { throw "Could not locate repo root." }
        $cursor = $parent
    }
}

$repoRoot = Find-TbgRepoRoot
$artifactDir = Join-Path $repoRoot "artifacts/latest"
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $artifactDir "claude-rules-update.proposal.md"
}

$contractPath = Join-Path $repoRoot (".tbg/workflows/" + $ContractId + ".contract.json")
$contractLine = "Contract not found: $ContractId"
if (Test-Path -LiteralPath $contractPath) {
    $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
    $contractLine = "Contract: $($contract.id) / Sprint: $($contract.sprint)"
}

$body = @"
# Claude Rules Update Proposal

```text
[TBG | Stop Hook Proposal | contract: $ContractId]
```

Generated: $((Get-Date).ToUniversalTime().ToString("o"))

$contractLine

## Review checklist

- Did the agent ask for context already stored in `CLAUDE.md` or `.tbg` contracts?
- Did a repeated command pattern deserve a script?
- Did a validation failure reveal a missing rule?
- Did a new convention appear that belongs in a path-local `CLAUDE.md`?
- Did the agent touch or request forbidden runtime scope?

## Proposed changes

- [ ] No automatic rule change proposed. Fill this section manually after reviewing the session.

## Files to inspect

```text
CLAUDE.md
.tbg/workflows/$ContractId.contract.json
.tbg/harness/policies
artifacts/latest
```

## Rule

This file is a proposal only. Do not silently rewrite `CLAUDE.md` from a stop hook.
"@

Set-Content -LiteralPath $OutputPath -Encoding UTF8 -Value $body

$result = New-Object psobject -Property @{
    schema = "tbg.harness.result.v1"
    action = "WriteClaudeRulesProposal"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    repoRoot = $repoRoot
    branch = "unknown"
    contractId = $ContractId
    status = "ready"
    verdict = "claude_rules_proposal_written"
    findings = @("proposal-written")
    missingPrereqs = @()
    forbiddenScopeTouched = $false
    artifacts = @("artifacts/latest/claude-rules-update.proposal.md")
}

$result | ConvertTo-Json -Depth 20
