param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-Equal {
    param([object]$Actual, [object]$Expected, [string]$Message)
    if ([string]$Actual -cne [string]$Expected) { throw "$Message Expected '$Expected', got '$Actual'." }
}

function Set-TestBundleTimestamp {
    param([string]$Path, [datetime]$TimestampUtc)
    foreach ($item in @(Get-ChildItem -LiteralPath $Path -Recurse -Force | Sort-Object FullName -Descending)) {
        $item.LastWriteTimeUtc = $TimestampUtc
    }
    (Get-Item -LiteralPath $Path -Force).LastWriteTimeUtc = $TimestampUtc
}

function New-RetentionTestRepo {
    param([object[]]$Runs, [datetime]$ReferenceTimeUtc)
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('tbg-retention-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $root | Out-Null
    & git -C $root init -q
    if ($LASTEXITCODE -ne 0) { throw 'Could not initialize retention fixture repository.' }
    Set-Content -LiteralPath (Join-Path $root '.gitignore') -Value "artifacts/`n" -Encoding UTF8
    & git -C $root config user.email 'retention-fixture@blacksmithguild.local'
    & git -C $root config user.name 'TBG Retention Fixture'
    & git -C $root config core.autocrlf false
    & git -C $root add -- '.gitignore'
    & git -C $root commit -qm 'fixture root'
    if ($LASTEXITCODE -ne 0) { throw 'Could not commit retention fixture root.' }
    foreach ($run in $Runs) {
        $bundle = Join-Path $root ('artifacts/' + [string]$run.name)
        $nested = Join-Path $bundle 'nested'
        New-Item -ItemType Directory -Force -Path $nested | Out-Null
        Set-Content -LiteralPath (Join-Path $bundle 'manifest.json') -Value ('{"run":"' + [string]$run.name + '"}') -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $nested 'runtime.log') -Value (('runtime-' + [string]$run.name + "`n") * 4) -Encoding UTF8
        Set-TestBundleTimestamp -Path $bundle -TimestampUtc $ReferenceTimeUtc.AddDays(-[double]$run.ageDays)
    }
    $tracked = $Runs | Where-Object { [string]$_.name -eq 'tracked-old' } | Select-Object -First 1
    if ($null -ne $tracked) {
        & git -C $root add -f -- 'artifacts/tracked-old/manifest.json'
        if ($LASTEXITCODE -ne 0) { throw 'Could not register tracked-content fixture.' }
    }
    return $root
}

function Read-Result {
    param([string]$Path)
    Assert-True -Condition (Test-Path -LiteralPath $Path -PathType Leaf) -Message "Missing machine result: $Path"
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$fixturePath = Join-Path $repoRoot '.tbg/harness/fixtures/evidence-retention.fixtures.json'
$policyPath = Join-Path $repoRoot '.tbg/harness/policies/evidence-retention.policy.json'
$schemaPath = Join-Path $repoRoot '.tbg/harness/schemas/evidence-retention-result.schema.json'
$retentionScript = Join-Path $PSScriptRoot 'Invoke-TbgEvidenceRetention.ps1'
$dispatcher = Join-Path $PSScriptRoot 'Invoke-TbgHarness.ps1'
$fixtures = Get-Content -LiteralPath $fixturePath -Raw | ConvertFrom-Json
$schema = Get-Content -LiteralPath $schemaPath -Raw | ConvertFrom-Json
$referenceTimeUtc = ([datetime]$fixtures.referenceTimeUtc).ToUniversalTime()
$tempRoots = New-Object System.Collections.Generic.List[string]

try {
    $testRepo = New-RetentionTestRepo -Runs @($fixtures.runs) -ReferenceTimeUtc $referenceTimeUtc
    $tempRoots.Add($testRepo) | Out-Null
    $planOutputPath = Join-Path $testRepo 'artifacts/latest/retention-plan.result.json'
    & $retentionScript -RepoRoot $testRepo -PolicyPath $policyPath -OutputPath $planOutputPath -ReferenceTimeUtc $referenceTimeUtc | Out-Null
    $plan = Read-Result -Path $planOutputPath
    Assert-Equal -Actual $plan.schema -Expected 'tbg.evidence-retention.result.v1' -Message 'Plan schema mismatch.'
    Assert-Equal -Actual $plan.mode -Expected 'plan' -Message 'Default invocation must remain plan-only.'
    Assert-Equal -Actual $plan.verdict -Expected $fixtures.expected.planVerdict -Message 'Plan verdict mismatch.'
    Assert-Equal -Actual $plan.summary.plannedCount -Expected $fixtures.expected.planCount -Message 'Plan count mismatch.'
    foreach ($required in @($schema.required)) {
        Assert-True -Condition ($null -ne $plan.PSObject.Properties[[string]$required]) -Message "Plan omitted schema-required field '$required'."
    }
    foreach ($run in @($fixtures.runs)) {
        $candidate = @($plan.candidates | Where-Object { $_.relativePath -eq ('artifacts/' + [string]$run.name) })
        Assert-Equal -Actual $candidate.Count -Expected 1 -Message "Missing fixture candidate '$($run.name)'."
        Assert-Equal -Actual $candidate[0].disposition -Expected $run.expectedPlanDisposition -Message "Disposition mismatch for '$($run.name)'."
    }
    $planArchives = @(if (Test-Path -LiteralPath (Join-Path $testRepo 'artifacts/archive')) { Get-ChildItem -LiteralPath (Join-Path $testRepo 'artifacts/archive') -File -Filter '*.zip' })
    Assert-Equal -Actual $planArchives.Count -Expected 0 -Message 'Plan mode created an archive.'
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $testRepo 'artifacts/archive'))) -Message 'Plan mode created the archive directory.'
    Assert-True -Condition ($plan.summary.liveCandidateBytes -gt 0) -Message 'Plan omitted live-byte accounting.'
    Assert-True -Condition ($plan.summary.projectedLiveBytesAfterApply -lt $plan.summary.liveCandidateBytes) -Message 'Plan omitted projected size relief.'
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $testRepo 'artifacts/old-a')) -Message 'Plan mode removed old-a.'
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $testRepo 'artifacts/old-b')) -Message 'Plan mode removed old-b.'

    $applyOutputPath = Join-Path $testRepo 'artifacts/latest/retention-apply.result.json'
    & $retentionScript -RepoRoot $testRepo -PolicyPath $policyPath -OutputPath $applyOutputPath -ReferenceTimeUtc $referenceTimeUtc -Apply | Out-Null
    $applyResult = Read-Result -Path $applyOutputPath
    Assert-Equal -Actual $applyResult.mode -Expected 'apply' -Message 'Apply mode was not recorded.'
    Assert-Equal -Actual $applyResult.verdict -Expected $fixtures.expected.applyVerdict -Message 'Apply verdict mismatch.'
    Assert-Equal -Actual $applyResult.summary.archivedCount -Expected $fixtures.expected.archiveCount -Message 'Archive count mismatch.'
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $testRepo 'artifacts/old-a'))) -Message 'Verified old-a source was not removed.'
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $testRepo 'artifacts/old-b'))) -Message 'Verified old-b source was not removed.'
    foreach ($protectedName in @('old-newest', 'recent', 'tracked-old', 'latest', 'current')) {
        Assert-True -Condition (Test-Path -LiteralPath (Join-Path $testRepo ('artifacts/' + $protectedName))) -Message "Protected bundle '$protectedName' was removed."
    }
    $archives = @(Get-ChildItem -LiteralPath (Join-Path $testRepo 'artifacts/archive') -File -Filter '*.zip')
    $manifests = @(Get-ChildItem -LiteralPath (Join-Path $testRepo 'artifacts/archive') -File -Filter '*.zip.manifest.json')
    Assert-Equal -Actual $archives.Count -Expected $fixtures.expected.archiveCount -Message 'Published archive count mismatch.'
    Assert-Equal -Actual $manifests.Count -Expected $fixtures.expected.archiveCount -Message 'Published archive-manifest count mismatch.'
    foreach ($manifestFile in $manifests) {
        $manifest = Get-Content -LiteralPath $manifestFile.FullName -Raw | ConvertFrom-Json
        Assert-True -Condition ($manifest.verified -eq $true) -Message "Archive manifest is not verified: $($manifestFile.Name)"
        Assert-Equal -Actual $manifest.verification -Expected $fixtures.expected.archiveVerification -Message 'Archive verification method mismatch.'
        $archivePath = Join-Path $testRepo ([string]$manifest.archiveRelativePath)
        $archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
        Assert-Equal -Actual $archiveHash -Expected $manifest.archiveSha256 -Message 'Published archive hash mismatch.'
        Assert-Equal -Actual @($manifest.files).Count -Expected $manifest.sourceFileCount -Message 'Manifest did not preserve the per-file analytical inventory.'
    }

    # The public dispatcher must expose the same safe default without requiring direct script knowledge.
    $dispatchOutput = Join-Path $testRepo 'artifacts/latest/retention-dispatch.result.json'
    & $dispatcher -Action ManageRetention -RetentionRepoRoot $testRepo -RetentionPolicyPath $policyPath -RetentionOutputPath $dispatchOutput -RetentionReferenceTimeUtc $referenceTimeUtc | Out-Null
    $dispatchResult = Read-Result -Path $dispatchOutput
    Assert-Equal -Actual $dispatchResult.mode -Expected 'plan' -Message 'Harness dispatcher did not preserve plan-only default.'

    # A pre-existing destination is a fail-closed collision: the source must survive.
    $collisionRuns = @(
        [pscustomobject]@{ name = 'collision-old'; ageDays = 60 },
        [pscustomobject]@{ name = 'keep-one'; ageDays = 5 },
        [pscustomobject]@{ name = 'keep-two'; ageDays = 2 }
    )
    $collisionRepo = New-RetentionTestRepo -Runs $collisionRuns -ReferenceTimeUtc $referenceTimeUtc
    $tempRoots.Add($collisionRepo) | Out-Null
    $collisionPlanPath = Join-Path $collisionRepo 'artifacts/latest/collision-plan.result.json'
    & $retentionScript -RepoRoot $collisionRepo -PolicyPath $policyPath -OutputPath $collisionPlanPath -ReferenceTimeUtc $referenceTimeUtc | Out-Null
    $collisionPlan = Read-Result -Path $collisionPlanPath
    $collisionCandidate = @($collisionPlan.candidates | Where-Object { $_.relativePath -eq 'artifacts/collision-old' })[0]
    Assert-Equal -Actual $collisionCandidate.disposition -Expected 'planned' -Message 'Collision candidate was not planned.'
    $collisionArchive = Join-Path $collisionRepo ([string]$collisionCandidate.archiveRelativePath)
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $collisionArchive) | Out-Null
    Set-Content -LiteralPath $collisionArchive -Value 'pre-existing archive collision' -Encoding UTF8
    $collisionApplyPath = Join-Path $collisionRepo 'artifacts/latest/collision-apply.result.json'
    & $retentionScript -RepoRoot $collisionRepo -PolicyPath $policyPath -OutputPath $collisionApplyPath -ReferenceTimeUtc $referenceTimeUtc -Apply | Out-Null
    $collisionApply = Read-Result -Path $collisionApplyPath
    Assert-Equal -Actual $collisionApply.verdict -Expected 'retention_apply_partial' -Message 'Archive collision did not fail closed.'
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $collisionRepo 'artifacts/collision-old')) -Message 'Archive collision removed its source.'
    Assert-Equal -Actual @($collisionApply.candidates | Where-Object { $_.relativePath -eq 'artifacts/collision-old' })[0].disposition -Expected 'archive_failed_source_preserved' -Message 'Collision source-preservation disposition mismatch.'

    # Retired mode is separate, explicit, detached, merged, clean, and durable-host only.
    $crossRepo = New-RetentionTestRepo -Runs $collisionRuns -ReferenceTimeUtc $referenceTimeUtc
    $tempRoots.Add($crossRepo) | Out-Null
    $archiveHost = $crossRepo + '-archive-host'
    & git -C $crossRepo worktree add -q $archiveHost HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Could not create archive-host fixture worktree.' }
    $tempRoots.Insert(0, $archiveHost)

    $attachedOutputPath = Join-Path $crossRepo 'artifacts/latest/retired-attached.result.json'
    & $dispatcher -Action ManageRetention -RetentionRepoRoot $crossRepo -RetentionArchiveRepoRoot $archiveHost -RetentionPolicyPath $policyPath -RetentionOutputPath $attachedOutputPath -RetentionReferenceTimeUtc $referenceTimeUtc -RetentionRetiredWorktree | Out-Null
    $attachedResult = Read-Result -Path $attachedOutputPath
    Assert-Equal -Actual $attachedResult.verdict -Expected 'retention_blocked' -Message 'Retired profile accepted an attached source branch.'
    Assert-True -Condition ($attachedResult.retiredWorktreeChecks.detachedHead -eq $false) -Message 'Attached-head failure was not machine-readable.'

    & git -C $crossRepo update-ref refs/remotes/origin/main HEAD
    & git -C $crossRepo checkout --detach -q
    if ($LASTEXITCODE -ne 0) { throw 'Could not detach retired-worktree fixture.' }

    $lockedPath = Join-Path $crossRepo 'artifacts/collision-old/manifest.json'
    $heldStream = [System.IO.File]::Open($lockedPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
    try {
        $lockedOutputPath = Join-Path $crossRepo 'artifacts/latest/retired-locked.result.json'
        & $dispatcher -Action ManageRetention -RetentionRepoRoot $crossRepo -RetentionArchiveRepoRoot $archiveHost -RetentionPolicyPath $policyPath -RetentionOutputPath $lockedOutputPath -RetentionReferenceTimeUtc $referenceTimeUtc -RetentionRetiredWorktree | Out-Null
        $lockedResult = Read-Result -Path $lockedOutputPath
        Assert-Equal -Actual $lockedResult.verdict -Expected 'retention_blocked' -Message 'Retired profile accepted a selected file with an open handle.'
        Assert-Equal -Actual $lockedResult.retiredWorktreeChecks.openHandleProbeStatus -Expected 'blocked_open_handles' -Message 'Open-handle failure was not machine-readable.'
        Assert-True -Condition (Test-Path -LiteralPath (Join-Path $crossRepo 'artifacts/collision-old')) -Message 'Open-handle plan removed its source.'
    }
    finally { $heldStream.Dispose() }

    $retiredPlanPath = Join-Path $crossRepo 'artifacts/latest/retired-plan.result.json'
    & $dispatcher -Action ManageRetention -RetentionRepoRoot $crossRepo -RetentionArchiveRepoRoot $archiveHost -RetentionPolicyPath $policyPath -RetentionOutputPath $retiredPlanPath -RetentionReferenceTimeUtc $referenceTimeUtc -RetentionRetiredWorktree | Out-Null
    $retiredPlan = Read-Result -Path $retiredPlanPath
    Assert-Equal -Actual $retiredPlan.retentionProfile -Expected $fixtures.expected.retiredProfile -Message 'Retired profile was not recorded.'
    Assert-Equal -Actual $retiredPlan.verdict -Expected 'retention_plan_ready' -Message 'Safe retired plan was not ready.'
    Assert-Equal -Actual $retiredPlan.summary.plannedCount -Expected $fixtures.expected.retiredPlanCount -Message 'Retired plan count mismatch.'
    Assert-Equal -Actual $retiredPlan.retiredWorktreeChecks.openHandleProbeStatus -Expected 'passed' -Message 'Retired exclusive-file probe did not pass.'

    $crossOutputPath = Join-Path $crossRepo 'artifacts/latest/cross-worktree-apply.result.json'
    & $dispatcher -Action ManageRetention -RetentionRepoRoot $crossRepo -RetentionArchiveRepoRoot $archiveHost -RetentionPolicyPath $policyPath -RetentionOutputPath $crossOutputPath -RetentionReferenceTimeUtc $referenceTimeUtc -RetentionRetiredWorktree -ApplyRetention | Out-Null
    $crossResult = Read-Result -Path $crossOutputPath
    Assert-Equal -Actual $crossResult.verdict -Expected 'retention_apply_complete' -Message 'Cross-worktree retention did not complete.'
    Assert-Equal -Actual $crossResult.retentionProfile -Expected $fixtures.expected.retiredProfile -Message 'Retired apply profile was not recorded.'
    Assert-Equal -Actual $crossResult.archiveRepoRoot -Expected $archiveHost -Message 'Cross-worktree archive host was not recorded.'
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $crossRepo 'artifacts/collision-old'))) -Message 'Cross-worktree verified source was not removed.'
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $crossRepo 'artifacts/keep-one'))) -Message 'Retired profile did not archive the second eligible bundle.'
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $crossRepo 'artifacts/keep-two')) -Message 'Retired profile archived a bundle younger than three days.'
    Assert-Equal -Actual @(Get-ChildItem -LiteralPath (Join-Path $archiveHost 'artifacts/archive') -File -Filter '*.zip').Count -Expected $fixtures.expected.retiredPlanCount -Message 'Cross-worktree archives were not published to their durable host.'
    foreach ($retiredManifestFile in @(Get-ChildItem -LiteralPath (Join-Path $archiveHost 'artifacts/archive') -File -Filter '*.zip.manifest.json')) {
        $retiredManifest = Get-Content -LiteralPath $retiredManifestFile.FullName -Raw | ConvertFrom-Json
        Assert-Equal -Actual $retiredManifest.retentionProfile -Expected $fixtures.expected.retiredProfile -Message 'Archive manifest omitted retired profile provenance.'
    }

    $sourceText = Get-Content -LiteralPath $retentionScript -Raw
    $publishIndex = $sourceText.IndexOf('[System.IO.File]::Move($partialManifestPath, $ManifestFullPath)', [System.StringComparison]::Ordinal)
    $removeIndex = $sourceText.IndexOf("Remove-Item -LiteralPath `$Candidate.fullPath", [System.StringComparison]::Ordinal)
    Assert-True -Condition ($publishIndex -ge 0 -and $removeIndex -gt $publishIndex) -Message 'Source removal is not structurally ordered after verified manifest publication.'

    Write-Host 'PASS: evidence retention preserves active defaults and requires an explicit detached, merged, clean, unlocked retired-worktree profile for durable sibling archives.'
}
finally {
    foreach ($tempRoot in $tempRoots) {
        if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
