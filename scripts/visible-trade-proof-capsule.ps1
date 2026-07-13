# Visible Trade Proof evidence capsule generation and sanitization.
# Produces a sanitized capsule for remote publication, excluding saves, binaries,
# credentials, tokens, personal paths, and oversized raw logs.

Set-StrictMode -Version Latest

function New-TbgVisibleTradeProofCapsule {
    param(
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$SourceShortSha,
        [Parameter(Mandatory = $true)][string]$RunRoot,
        [Parameter(Mandatory = $true)][string]$ResultJson,
        [Parameter(Mandatory = $true)][string]$ProofJson,
        [Parameter(Mandatory = $true)][string]$EventsJsonl,
        [Parameter(Mandatory = $true)][string]$HandoffMd,
        [Parameter(Mandatory = $true)][string]$ProgressLog,
        [Parameter(Mandatory = $true)][string]$CapsulePath
    )

    $capsuleDir = Split-Path -Parent $CapsulePath
    New-Item -ItemType Directory -Force -Path $capsuleDir | Out-Null

    $capsuleFiles = [System.Collections.Generic.List[object]]::new()
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

    $selectedLogs = [System.Collections.Generic.List[string]]::new()
    $stepsDir = Join-Path $RunRoot 'steps'
    if (Test-Path -LiteralPath $stepsDir) {
        $stepFiles = @(Get-ChildItem -LiteralPath $stepsDir -Filter '*.log' -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTimeUtc |
            Select-Object -First 5)
        foreach ($sf in $stepFiles) {
            $content = Get-Content -LiteralPath $sf.FullName -Raw -ErrorAction SilentlyContinue
            if ($content) {
                $selectedLogs.Add($sf.Name + ':' + [Math]::Min($content.Length, 2000)) | Out-Null
            }
        }
    }

    $resultObj = $null
    try {
        if (Test-Path -LiteralPath $ResultJson) {
            $resultObj = Get-Content -LiteralPath $ResultJson -Raw | ConvertFrom-Json
        }
    } catch { }

    $sanitizedResult = $null
    if ($resultObj) {
        $sanitizedResult = Sanitize-TbgCapsuleObject -InputObject $resultObj -RepoRoot $repoRoot
    }

    $sanitizedProof = $null
    if (Test-Path -LiteralPath $ProofJson) {
        try {
            $proofObj = Get-Content -LiteralPath $ProofJson -Raw | ConvertFrom-Json
            $sanitizedProof = Sanitize-TbgCapsuleObject -InputObject $proofObj -RepoRoot $repoRoot
        } catch { }
    }

    $eventsData = @()
    if (Test-Path -LiteralPath $EventsJsonl) {
        $lines = @(Get-Content -LiteralPath $EventsJsonl -Raw -ErrorAction SilentlyContinue -Split "`n" | Where-Object { $_.Trim().Length -gt 0 })
        foreach ($line in $lines) {
            try {
                $ev = $line | ConvertFrom-Json
                $eventsData += @(Sanitize-TbgCapsuleObject -InputObject $ev -RepoRoot $repoRoot)
            } catch {
                $eventsData += @{ raw = Sanitize-TbgCapsuleString -Input $line -RepoRoot $repoRoot }
            }
        }
    }

    $manifest = [ordered]@{
        schemaVersion = 'TbgVisibleTradeProofCapsule.v1'
        runId = $RunId
        sourceShortSha = $SourceShortSha
        generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        terminalState = if ($sanitizedResult) { [string]$sanitizedResult.terminalState } else { 'unknown' }
        files = @()
    }

    $artifactIndex = [ordered]@{
        schemaVersion = 'TbgArtifactIndex.v1'
        runId = $RunId
        generatedAtUtc = $manifest.generatedAtUtc
        entries = @()
    }

    function Add-CapsuleFile {
        param(
            [string]$Name,
            [object]$Content,
            [string]$SourcePath = ''
        )
        $destPath = Join-Path $capsuleDir $Name
        if ($null -ne $Content -and ($Content -is [string])) {
            [System.IO.File]::WriteAllText($destPath, $Content, [System.Text.UTF8Encoding]::new($false))
        } elseif ($null -ne $Content) {
            $json = $Content | ConvertTo-Json -Depth 40
            [System.IO.File]::WriteAllText($destPath, $json, [System.Text.UTF8Encoding]::new($false))
        } else {
            return
        }
        $hash = ''
        if (Test-Path -LiteralPath $destPath) {
            $hash = Get-TbgFileSha256 -LiteralPath $destPath
        }
        $manifest.files += @{ name = $Name; sha256 = $hash }
        $relPath = $destPath
        if ($destPath.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            $relPath = $destPath.Substring($repoRoot.Length).TrimStart('\', '/')
        }
        $artifactIndex.entries += @{ name = $Name; path = $relPath; sha256 = $hash; sourcePath = $SourcePath }
    }

    Add-CapsuleFile -Name 'manifest.json' -Content $manifest
    Add-CapsuleFile -Name 'result.json' -Content $sanitizedResult
    Add-CapsuleFile -Name 'proof.json' -Content $sanitizedProof
    Add-CapsuleFile -Name 'events.jsonl' -Content ($eventsData | ConvertTo-Json -Depth 10 -Compress)
    Add-CapsuleFile -Name 'handoff.md' -Content (Sanitize-TbgCapsuleMarkdown -Path $HandoffMd -RepoRoot $repoRoot)
    Add-CapsuleFile -Name 'artifact-index.json' -Content $artifactIndex

    if ($selectedLogs.Count -gt 0) {
        $logSummary = $selectedLogs -join "`n"
        Add-CapsuleFile -Name 'logs/selected-step-summaries.log' -Content $logSummary
    }

    return [pscustomobject]@{
        capsulePath = $CapsuleDir
        manifestPath = Join-Path $capsuleDir 'manifest.json'
        fileCount = $manifest.files.Count
    }
}

function Sanitize-TbgCapsuleString {
    param(
        [string]$Input,
        [string]$RepoRoot
    )

    $result = $Input
    if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
        $escaped = [regex]::Escape($RepoRoot)
        $result = $result -replace $escaped, '<REPO_ROOT>'
    }
    $userProfile = $env:USERPROFILE
    if (-not [string]::IsNullOrWhiteSpace($userProfile)) {
        $escaped = [regex]::Escape($userProfile)
        $result = $result -replace $escaped, '<USER_PROFILE>'
    }
    $result = $result -replace 'C:\\Users\\[^\\]+\\', '<USER>/'
    $result = $result -replace '/home/[^/]+/', '<USER>/'
    $result = $result -replace 'D:\\[^\\]+\\', '<DRIVE>/'
    $result = $result -replace 'E:\\[^\\]+\\', '<DRIVE>/'
    $result = $result -replace '(ghp_[A-Za-z0-9]{36})', '<TOKEN_REDACTED>'
    $result = $result -replace '(gho_[A-Za-z0-9]{36})', '<TOKEN_REDACTED>'
    $result = $result -replace '(github_pat_[A-Za-z0-9_]{80,})', '<TOKEN_REDACTED>'
    return $result
}

function Sanitize-TbgCapsuleObject {
    param(
        $InputObject,
        [string]$RepoRoot
    )

    if ($null -eq $InputObject) { return $null }
    $json = $InputObject | ConvertTo-Json -Depth 40
    $sanitized = Sanitize-TbgCapsuleString -Input $json -RepoRoot $RepoRoot
    try {
        return $sanitized | ConvertFrom-Json
    } catch {
        return @{ sanitized = $true; originalParseError = $_.Exception.Message }
    }
}

function Sanitize-TbgCapsuleMarkdown {
    param(
        [string]$Path,
        [string]$RepoRoot
    )

    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    $content = Get-Content -LiteralPath $Path -Raw
    return Sanitize-TbgCapsuleString -Input $content -RepoRoot $RepoRoot
}
