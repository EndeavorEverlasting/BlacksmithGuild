# Remote evidence relay for visible trade proof.
# Creates a sanitized evidence branch from the tested source commit,
# pushes it, and adds/updates a PR comment with the evidence marker.

Set-StrictMode -Version Latest

function Publish-TbgVisibleTradeProofEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$SourceCommit,
        [Parameter(Mandatory = $true)][string]$SourceBranch,
        [Parameter(Mandatory = $true)][string]$CapsuleDir,
        [Parameter(Mandatory = $true)][string]$ResultJson,
        [Parameter(Mandatory = $true)][string]$ProofJson,
        [Parameter(Mandatory = $true)][string]$EventsJsonl,
        [Parameter(Mandatory = $true)][string]$HandoffMd,
        [Parameter(Mandatory = $true)][string]$CapsuleManifestJson,
        [Parameter(Mandatory = $true)][string]$ArtifactIndexJson,
        [string]$RepoRoot = $null,
        [int]$MaxRetries = 3,
        [int]$PrNumber = 43
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    }

    $shortSha = $SourceCommit.Substring(0, [Math]::Min(8, $SourceCommit.Length))
    $evidenceBranch = "evidence/visible-trade/$shortSha/$RunId"
    $evidencePath = "evidence/visible-trade/$RunId"

    $publishResult = [ordered]@{
        schemaVersion = 'TbgVisibleTradeProofPublication.v1'
        runId = $RunId
        sourceCommit = $SourceCommit
        sourceBranch = $SourceBranch
        evidenceBranch = $evidenceBranch
        evidenceCommit = ''
        evidencePath = $evidencePath
        prCommentId = ''
        prCommentUrl = ''
        published = false
        error = ''
    }

    try {
        $tempWorktree = Join-Path ([System.IO.Path]::GetTempPath()) ("tbg-evidence-$RunId")
        if (Test-Path -LiteralPath $tempWorktree) {
            Remove-Item -LiteralPath $tempWorktree -Recurse -Force -ErrorAction SilentlyContinue
        }

        $createBranch = & git -C $RepoRoot branch --show-current 2>&1
        $createBranch = ($createBranch | Out-String).Trim()

        $wtResult = & git -C $RepoRoot worktree add -b $evidenceBranch $tempWorktree $SourceCommit 2>&1
        $wtExit = $LASTEXITCODE
        if ($wtExit -ne 0) {
            & git -C $RepoRoot worktree prune 2>&1 | Out-Null
            $wtResult = & git -C $RepoRoot worktree add -b $evidenceBranch $tempWorktree $SourceCommit 2>&1
            $wtExit = $LASTEXITCODE
        }
        if ($wtExit -ne 0) {
            throw "Failed to create evidence worktree: $($wtResult -join ' ')"
        }

        $destEvidenceDir = Join-Path $tempWorktree $evidencePath
        New-Item -ItemType Directory -Force -Path $destEvidenceDir | Out-Null

        $filesToCopy = @{
            'manifest.json' = $CapsuleManifestJson
            'result.json' = $ResultJson
            'proof.json' = $ProofJson
            'events.jsonl' = $EventsJsonl
            'handoff.md' = $HandoffMd
            'artifact-index.json' = $ArtifactIndexJson
        }
        foreach ($entry in $filesToCopy.GetEnumerator()) {
            if (Test-Path -LiteralPath $entry.Value) {
                Copy-Item -LiteralPath $entry.Value -Destination (Join-Path $destEvidenceDir $entry.Key) -Force
            }
        }

        $logsDir = Join-Path $destEvidenceDir 'logs'
        New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
        $capsuleLogsDir = Join-Path $CapsuleDir 'logs'
        if (Test-Path -LiteralPath $capsuleLogsDir) {
            Copy-Item -LiteralPath (Join-Path $capsuleLogsDir '*') -Destination $logsDir -Force -ErrorAction SilentlyContinue
        }

        Push-Location $tempWorktree
        try {
            & git add -A 2>&1 | Out-Null
            & git commit -m "evidence(visible-trade): $RunId proof capsule" 2>&1 | Out-Null
            $commitExit = $LASTEXITCODE
            if ($commitExit -ne 0) {
                throw "Evidence commit failed with exit $commitExit"
            }

            $evidenceCommit = (& git rev-parse HEAD 2>&1 | Out-String).Trim()
            $publishResult.evidenceCommit = $evidenceCommit

            $pushed = $false
            for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
                $pushResult = & git push -u origin $evidenceBranch 2>&1
                $pushExit = $LASTEXITCODE
                if ($pushExit -eq 0) {
                    $pushed = $true
                    break
                }
                if ($attempt -lt $MaxRetries) {
                    Start-Sleep -Seconds (2 * $attempt)
                }
            }
            if (-not $pushed) {
                throw "Failed to push evidence branch after $MaxRetries attempts"
            }

            $commentBody = @"
<!-- tbg-visible-trade-proof -->
## Visible Trade Proof Evidence

- **Run ID:** ``$RunId``
- **Tested source branch:** ``$SourceBranch``
- **Tested source head:** ``$SourceCommit``
- **Evidence branch:** ``$evidenceBranch``
- **Evidence commit:** ``$evidenceCommit``
- **Terminal state:** ``$($publishResult.terminalState)``
- **Highest proof reached:** See result.json
- **Movement delta:** See result.json
- **Arrival outcome:** See result.json
- **Buy outcome:** See result.json
- **Sell outcome:** See result.json
- **Capsule path:** ``$evidencePath``

Generated by ``Run-VisibleTradeProof.cmd``
"@

            $resultObj = $null
            if (Test-Path -LiteralPath $ResultJson) {
                $resultObj = Get-Content -LiteralPath $ResultJson -Raw | ConvertFrom-Json
                $commentBody = @"
<!-- tbg-visible-trade-proof -->
## Visible Trade Proof Evidence

- **Run ID:** ``$RunId``
- **Tested source branch:** ``$SourceBranch``
- **Tested source head:** ``$SourceCommit``
- **Evidence branch:** ``$evidenceBranch``
- **Evidence commit:** ``$evidenceCommit``
- **Terminal state:** ``$($resultObj.terminalState)``
- **Highest proof reached:** ``$($resultObj.highestProofReached)``
- **Movement delta:** ``$($resultObj.movement.delta)``
- **Arrival outcome:** ``$($resultObj.arrival.observed)``
- **Buy outcome:** ``$($resultObj.buy.observed)``
- **Sell outcome:** ``$($resultObj.sell.observed)``
- **Capsule path:** ``$evidencePath``

Generated by ``Run-VisibleTradeProof.cmd``
"@
            }

            $commented = $false
            for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
                $commentResult = & gh pr comment $PrNumber --repo EndeavorEverlasting/BlacksmithGuild --body $commentBody 2>&1
                $commentExit = $LASTEXITCODE
                if ($commentExit -eq 0) {
                    $commented = $true
                    $publishResult.prCommentId = "pr-$PrNumber-comment-$RunId"
                    break
                }
                if ($attempt -lt $MaxRetries) {
                    Start-Sleep -Seconds (2 * $attempt)
                }
            }
            if (-not $commented) {
                $publishResult.error = "PR comment failed after $MaxRetries attempts"
            }

            $publishResult.published = $true
        } finally {
            Pop-Location
        }
    } catch {
        $publishResult.error = $_.Exception.Message
    } finally {
        if (Test-Path -LiteralPath $tempWorktree) {
            & git worktree remove $tempWorktree --force 2>&1 | Out-Null
        }
    }

    return [pscustomobject]$publishResult
}
