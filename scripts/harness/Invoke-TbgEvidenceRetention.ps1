param(
    [string]$RepoRoot = '',
    [string]$ArchiveRepoRoot = '',
    [string]$PolicyPath = '',
    [string]$OutputPath = '',
    [switch]$Apply,
    [switch]$RetiredWorktree,
    [datetime]$ReferenceTimeUtc = [datetime]::UtcNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-PathWithinRoot {
    param([string]$Path, [string]$Root)
    $fullPath = [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    $fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    if ($fullPath.Equals($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $fullPath.StartsWith($fullRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
}

function Resolve-BoundedRepoPath {
    param([string]$Root, [string]$RelativePath, [string]$Label)
    if ([string]::IsNullOrWhiteSpace($RelativePath)) { throw "$Label must not be blank." }
    if ([System.IO.Path]::IsPathRooted($RelativePath)) { throw "$Label must be repository-relative: $RelativePath" }
    $segments = @($RelativePath -split '[\\/]')
    if ($segments -contains '..') { throw "$Label must not contain '..': $RelativePath" }
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $Root $RelativePath))
    if (-not (Test-PathWithinRoot -Path $fullPath -Root $Root)) { throw "$Label escaped the repository root: $RelativePath" }
    return $fullPath
}

function Get-RepoRelativePath {
    param([string]$Root, [string]$Path)
    $fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-PathWithinRoot -Path $fullPath -Root $fullRoot)) { throw "Path is outside repository root: $fullPath" }
    if ($fullPath.Equals($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)) { return '.' }
    return $fullPath.Substring($fullRoot.Length).TrimStart('\', '/').Replace('\', '/')
}

function Get-HexDigest {
    param([byte[]]$Bytes)
    return ([System.BitConverter]::ToString($Bytes) -replace '-', '').ToLowerInvariant()
}

function Get-StringSha256 {
    param([string]$Value)
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try { return Get-HexDigest -Bytes $algorithm.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Value)) }
    finally { $algorithm.Dispose() }
}

function Get-StreamSha256 {
    param([System.IO.Stream]$Stream)
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try { return Get-HexDigest -Bytes $algorithm.ComputeHash($Stream) }
    finally { $algorithm.Dispose() }
}

function Get-GitOutput {
    param([string]$Root, [string[]]$Arguments)
    $output = @(& git -C $Root @Arguments 2>$null)
    if ($LASTEXITCODE -ne 0) { return @() }
    return @($output | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Get-GitCommonDirectory {
    param([string]$Root)
    $output = @(Get-GitOutput -Root $Root -Arguments @('rev-parse', '--git-common-dir'))
    if ($output.Count -eq 0) { throw "Could not resolve Git common directory for: $Root" }
    $path = $output[0]
    if (-not [System.IO.Path]::IsPathRooted($path)) { $path = Join-Path $Root $path }
    return [System.IO.Path]::GetFullPath($path).TrimEnd('\', '/')
}

function Test-GitIgnored {
    param([string]$Root, [string]$RelativePath)
    & git -C $Root check-ignore -q -- $RelativePath 2>$null
    return ($LASTEXITCODE -eq 0)
}

function Test-HasTrackedContent {
    param([string]$Root, [string]$RelativePath)
    return (@(Get-GitOutput -Root $Root -Arguments @('ls-files', '--', $RelativePath)).Count -gt 0)
}

function Get-CandidateInventory {
    param([System.IO.FileSystemInfo]$Candidate)

    $files = New-Object System.Collections.Generic.List[object]
    $directories = New-Object System.Collections.Generic.List[string]
    $hasReparsePoint = [bool]($Candidate.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
    $lastActivityUtc = $Candidate.LastWriteTimeUtc

    if (-not $hasReparsePoint -and $Candidate.PSIsContainer) {
        $pending = New-Object System.Collections.Generic.Stack[string]
        $pending.Push($Candidate.FullName)
        while ($pending.Count -gt 0 -and -not $hasReparsePoint) {
            $directory = $pending.Pop()
            foreach ($item in @(Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop)) {
                if ($item.LastWriteTimeUtc -gt $lastActivityUtc) { $lastActivityUtc = $item.LastWriteTimeUtc }
                if ([bool]($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                    $hasReparsePoint = $true
                    break
                }
                if ($item.PSIsContainer) {
                    $relativeDirectory = $item.FullName.Substring($Candidate.FullName.Length).TrimStart('\', '/').Replace('\', '/')
                    $directories.Add($relativeDirectory) | Out-Null
                    $pending.Push($item.FullName)
                }
                else {
                    $entryName = $item.FullName.Substring($Candidate.FullName.Length).TrimStart('\', '/').Replace('\', '/')
                    $files.Add([pscustomobject]@{
                        fullPath = $item.FullName
                        entryName = $entryName
                        length = [long]$item.Length
                        lastWriteTimeUtc = $item.LastWriteTimeUtc
                    }) | Out-Null
                }
            }
        }
    }
    elseif (-not $hasReparsePoint) {
        $files.Add([pscustomobject]@{
            fullPath = $Candidate.FullName
            entryName = $Candidate.Name
            length = [long]$Candidate.Length
            lastWriteTimeUtc = $Candidate.LastWriteTimeUtc
        }) | Out-Null
    }

    $totalBytes = [long]0
    foreach ($file in $files) { $totalBytes += [long]$file.length }
    return [pscustomobject]@{
        hasReparsePoint = $hasReparsePoint
        lastActivityUtc = $lastActivityUtc
        totalBytes = $totalBytes
        files = $files.ToArray()
        directories = $directories.ToArray()
    }
}

function Test-CandidateExclusiveAccess {
    param([object[]]$Candidates)
    $lockedPaths = New-Object System.Collections.Generic.List[string]
    $filesProbed = 0
    foreach ($candidate in $Candidates) {
        foreach ($file in @($candidate.inventory.files)) {
            $filesProbed++
            $stream = $null
            try {
                $stream = [System.IO.File]::Open([string]$file.fullPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
            }
            catch {
                $lockedPaths.Add([string]$file.fullPath) | Out-Null
            }
            finally {
                if ($null -ne $stream) { $stream.Dispose() }
            }
        }
    }
    return [pscustomobject]@{
        mode = if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) { 'windows_exclusive_file_open' } else { 'best_effort_exclusive_file_open' }
        status = if ($lockedPaths.Count -eq 0) { 'passed' } else { 'blocked_open_handles' }
        filesProbed = $filesProbed
        lockedPaths = $lockedPaths.ToArray()
    }
}

function Get-ArchiveFileName {
    param([string]$CandidateRelativePath, [datetime]$LastActivityUtc)
    $safeName = ($CandidateRelativePath -replace '[^A-Za-z0-9_.-]+', '--').Trim('-')
    if ($safeName.Length -gt 96) { $safeName = $safeName.Substring(0, 96).TrimEnd('-') }
    $key = (Get-StringSha256 -Value $CandidateRelativePath).Substring(0, 10)
    return '{0}--{1}--{2}.zip' -f $safeName, $LastActivityUtc.ToUniversalTime().ToString('yyyyMMddTHHmmssZ'), $key
}

function Invoke-VerifiedArchive {
    param(
        [object]$Candidate,
        [string]$ArchiveFullPath,
        [string]$ManifestFullPath,
        [string]$SourceRoot,
        [string]$DestinationRoot,
        [string]$Branch,
        [string]$RetentionProfile,
        [datetime]$NowUtc,
        [switch]$RequireExclusiveAccess
    )

    $partialArchivePath = Join-Path (Split-Path -Parent $ArchiveFullPath) ('.partial-' + [guid]::NewGuid().ToString('N') + '.zip')
    $partialManifestPath = $ManifestFullPath + '.partial-' + [guid]::NewGuid().ToString('N')
    $archivePublished = $false
    try {
        if (Test-Path -LiteralPath $ArchiveFullPath) { throw "Archive already exists; source was preserved: $ArchiveFullPath" }
        if (Test-Path -LiteralPath $ManifestFullPath) { throw "Archive manifest already exists; source was preserved: $ManifestFullPath" }
        if (-not (Test-PathWithinRoot -Path $Candidate.fullPath -Root $SourceRoot)) { throw 'Candidate path escaped the source repository root.' }
        if (-not (Test-PathWithinRoot -Path $ArchiveFullPath -Root $DestinationRoot)) { throw 'Archive path escaped the archive repository root.' }

        $expectedFiles = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::Ordinal)
        foreach ($file in @($Candidate.inventory.files)) {
            if (-not (Test-Path -LiteralPath $file.fullPath -PathType Leaf)) { throw "Source changed before archive: $($file.fullPath)" }
            $expectedFiles.Add([string]$file.entryName, [pscustomobject]@{
                length = [long]$file.length
                sha256 = (Get-FileHash -LiteralPath $file.fullPath -Algorithm SHA256).Hash.ToLowerInvariant()
                fullPath = [string]$file.fullPath
                lastWriteTimeUtc = ([datetime]$file.lastWriteTimeUtc).ToUniversalTime()
            })
        }

        Add-Type -AssemblyName System.IO.Compression -ErrorAction SilentlyContinue
        $archiveStream = [System.IO.File]::Open($partialArchivePath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        try {
            $zip = New-Object System.IO.Compression.ZipArchive($archiveStream, [System.IO.Compression.ZipArchiveMode]::Create, $true)
            try {
                foreach ($directoryName in @($Candidate.inventory.directories)) {
                    [void]$zip.CreateEntry(([string]$directoryName).TrimEnd('/') + '/')
                }
                foreach ($file in @($Candidate.inventory.files)) {
                    $entry = $zip.CreateEntry([string]$file.entryName, [System.IO.Compression.CompressionLevel]::Optimal)
                    $sourceStream = [System.IO.File]::Open([string]$file.fullPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
                    try {
                        $entryStream = $entry.Open()
                        try { $sourceStream.CopyTo($entryStream) }
                        finally { $entryStream.Dispose() }
                    }
                    finally { $sourceStream.Dispose() }
                }
            }
            finally { $zip.Dispose() }
        }
        finally { $archiveStream.Dispose() }

        $verifiedFiles = New-Object System.Collections.Generic.List[object]
        $readStream = [System.IO.File]::Open($partialArchivePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        try {
            $readZip = New-Object System.IO.Compression.ZipArchive($readStream, [System.IO.Compression.ZipArchiveMode]::Read, $true)
            try {
                $fileEntries = @($readZip.Entries | Where-Object { -not $_.FullName.EndsWith('/') })
                $directoryEntries = @($readZip.Entries | Where-Object { $_.FullName.EndsWith('/') })
                if ($fileEntries.Count -ne $expectedFiles.Count) { throw "Archive file-count verification failed: expected $($expectedFiles.Count), got $($fileEntries.Count)." }
                if ($directoryEntries.Count -ne @($Candidate.inventory.directories).Count) { throw 'Archive directory-count verification failed.' }
                foreach ($entry in $fileEntries) {
                    if (-not $expectedFiles.ContainsKey($entry.FullName)) { throw "Archive contains unexpected entry: $($entry.FullName)" }
                    $expected = $expectedFiles[$entry.FullName]
                    if ([long]$entry.Length -ne [long]$expected.length) { throw "Archive length mismatch for $($entry.FullName)." }
                    $entryStream = $entry.Open()
                    try { $entryHash = Get-StreamSha256 -Stream $entryStream }
                    finally { $entryStream.Dispose() }
                    if ($entryHash -cne [string]$expected.sha256) { throw "Archive SHA-256 mismatch for $($entry.FullName)." }
                    $verifiedFiles.Add([pscustomobject]@{
                        path = $entry.FullName
                        bytes = [long]$entry.Length
                        sha256 = $entryHash
                    }) | Out-Null
                }
            }
            finally { $readZip.Dispose() }
        }
        finally { $readStream.Dispose() }

        # Re-hash the source after archive verification. A concurrently changing bundle is never removed.
        foreach ($entryName in $expectedFiles.Keys) {
            $expected = $expectedFiles[$entryName]
            if (-not (Test-Path -LiteralPath $expected.fullPath -PathType Leaf)) { throw "Source changed during archive: $($expected.fullPath)" }
            $currentFile = Get-Item -LiteralPath $expected.fullPath -Force
            if ([long]$currentFile.Length -ne [long]$expected.length) { throw "Source length changed during archive: $($expected.fullPath)" }
            $currentHash = (Get-FileHash -LiteralPath $expected.fullPath -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($currentHash -cne [string]$expected.sha256) { throw "Source content changed during archive: $($expected.fullPath)" }
        }
        if ($RequireExclusiveAccess) {
            $exclusiveCheck = Test-CandidateExclusiveAccess -Candidates @($Candidate)
            if ($exclusiveCheck.status -ne 'passed') {
                throw "Source acquired an open file handle during archive; source was preserved: $($exclusiveCheck.lockedPaths -join ', ')"
            }
        }

        [System.IO.File]::Move($partialArchivePath, $ArchiveFullPath)
        $archivePublished = $true
        $archiveHash = (Get-FileHash -LiteralPath $ArchiveFullPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $archiveInfo = Get-Item -LiteralPath $ArchiveFullPath
        $manifest = [ordered]@{
            schema = 'tbg.evidence-retention.archive.v1'
            archivedAtUtc = $NowUtc.ToUniversalTime().ToString('o')
            sourceRelativePath = [string]$Candidate.relativePath
            sourceRepoRoot = $SourceRoot
            sourceKind = [string]$Candidate.kind
            sourceLastActivityUtc = ([datetime]$Candidate.lastActivityUtc).ToUniversalTime().ToString('o')
            sourceBytes = [long]$Candidate.bytes
            sourceFileCount = [int]$Candidate.fileCount
            sourceDirectoryCount = [int]$Candidate.directoryCount
            branch = $Branch
            retentionProfile = $RetentionProfile
            archiveRepoRoot = $DestinationRoot
            archiveRelativePath = Get-RepoRelativePath -Root $DestinationRoot -Path $ArchiveFullPath
            archiveBytes = [long]$archiveInfo.Length
            archiveSha256 = $archiveHash
            verification = 'sha256_each_entry'
            verified = $true
            files = $verifiedFiles.ToArray()
        }
        $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $partialManifestPath -Encoding UTF8
        $writtenManifest = Get-Content -LiteralPath $partialManifestPath -Raw | ConvertFrom-Json
        if ($writtenManifest.verified -ne $true -or [string]$writtenManifest.archiveSha256 -cne $archiveHash) {
            throw 'Published archive manifest verification failed; source was preserved.'
        }
        [System.IO.File]::Move($partialManifestPath, $ManifestFullPath)

        # This is the only source-removal point. Path bounds, ignore/tracked policy, archive hashes,
        # post-copy source hashes, the published archive, and its manifest have all passed first.
        if ($Candidate.kind -eq 'directory') {
            Remove-Item -LiteralPath $Candidate.fullPath -Recurse -Force
        }
        else {
            Remove-Item -LiteralPath $Candidate.fullPath -Force
        }
        return [pscustomobject]@{
            succeeded = $true
            archiveRelativePath = Get-RepoRelativePath -Root $DestinationRoot -Path $ArchiveFullPath
            manifestRelativePath = Get-RepoRelativePath -Root $DestinationRoot -Path $ManifestFullPath
            archiveSha256 = $archiveHash
            archiveBytes = [long]$archiveInfo.Length
            error = ''
        }
    }
    catch {
        if (Test-Path -LiteralPath $partialArchivePath -PathType Leaf) { [System.IO.File]::Delete($partialArchivePath) }
        if (Test-Path -LiteralPath $partialManifestPath -PathType Leaf) { [System.IO.File]::Delete($partialManifestPath) }
        return [pscustomobject]@{
            succeeded = $false
            archiveRelativePath = if ($archivePublished) { Get-RepoRelativePath -Root $DestinationRoot -Path $ArchiveFullPath } else { '' }
            manifestRelativePath = ''
            archiveSha256 = ''
            archiveBytes = [long]0
            error = [string]$_.Exception.Message
        }
    }
}

$scriptRepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if ([string]::IsNullOrWhiteSpace($RepoRoot)) { $RepoRoot = $scriptRepoRoot }
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$insideWorktree = @(Get-GitOutput -Root $RepoRoot -Arguments @('rev-parse', '--is-inside-work-tree'))
if ($insideWorktree.Count -eq 0 -or $insideWorktree[0] -ne 'true') { throw "RepoRoot is not a Git worktree: $RepoRoot" }
if ([string]::IsNullOrWhiteSpace($ArchiveRepoRoot)) { $ArchiveRepoRoot = $RepoRoot }
$ArchiveRepoRoot = (Resolve-Path -LiteralPath $ArchiveRepoRoot).Path
$archiveInsideWorktree = @(Get-GitOutput -Root $ArchiveRepoRoot -Arguments @('rev-parse', '--is-inside-work-tree'))
if ($archiveInsideWorktree.Count -eq 0 -or $archiveInsideWorktree[0] -ne 'true') { throw "ArchiveRepoRoot is not a Git worktree: $ArchiveRepoRoot" }
$sourceCommonDirectory = Get-GitCommonDirectory -Root $RepoRoot
$archiveCommonDirectory = Get-GitCommonDirectory -Root $ArchiveRepoRoot
if (-not $sourceCommonDirectory.Equals($archiveCommonDirectory, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'ArchiveRepoRoot must be a registered worktree of the same Git repository as RepoRoot.'
}

if ([string]::IsNullOrWhiteSpace($PolicyPath)) { $PolicyPath = Join-Path $scriptRepoRoot '.tbg/harness/policies/evidence-retention.policy.json' }
if (-not [System.IO.Path]::IsPathRooted($PolicyPath)) { $PolicyPath = Join-Path $RepoRoot $PolicyPath }
$PolicyPath = (Resolve-Path -LiteralPath $PolicyPath).Path
$policy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json
if ([string]$policy.schema -cne 'tbg.evidence-retention.policy.v1') { throw "Unsupported retention policy schema: $($policy.schema)" }
if ([string]$policy.defaultMode -cne 'plan') { throw 'Retention policy must default to plan mode.' }
if ($policy.safety.applyRequiresExplicitSwitch -ne $true) { throw 'Retention policy must require an explicit apply switch.' }
if ($policy.safety.deleteOnlyAfterArchiveVerification -ne $true) { throw 'Retention policy must require verification before deletion.' }
if ([string]$policy.archive.verification -cne 'sha256_each_entry') { throw 'Retention policy must require per-entry SHA-256 verification.' }

$archiveRoot = Resolve-BoundedRepoPath -Root $ArchiveRepoRoot -RelativePath ([string]$policy.archive.relativePath) -Label 'archive.relativePath'
if ($policy.safety.archiveMustRemainUnderRepoRoot -ne $true -or -not (Test-PathWithinRoot -Path $archiveRoot -Root $ArchiveRepoRoot)) {
    throw 'Archive root must remain inside the selected archive-host worktree.'
}
if ($policy.safety.requireGitIgnored -eq $true -and -not (Test-GitIgnored -Root $ArchiveRepoRoot -RelativePath ([string]$policy.archive.relativePath))) {
    throw 'Archive root must be ignored by Git in the selected archive-host worktree.'
}

$branchOutput = @(Get-GitOutput -Root $RepoRoot -Arguments @('branch', '--show-current'))
$branch = if ($branchOutput.Count -gt 0) { $branchOutput[0] } else { '(detached)' }
$retentionProfile = 'active_worktree'
$retiredPreconditionFailures = New-Object System.Collections.Generic.List[string]
$retiredChecks = [ordered]@{
    requested = [bool]$RetiredWorktree
    explicitSwitch = [bool]$RetiredWorktree
    detachedHead = $null
    cleanTrackedWorktree = $null
    headAncestorOf = ''
    headIsAncestor = $null
    differentArchiveRepoRoot = $null
    sameGitCommonDirectory = $sourceCommonDirectory.Equals($archiveCommonDirectory, [System.StringComparison]::OrdinalIgnoreCase)
    openHandleProbeMode = 'not_run'
    openHandleProbeStatus = 'not_run'
    filesProbed = 0
    lockedPaths = @()
    failures = @()
}
if ($RetiredWorktree) {
    $retiredPolicy = $policy.retiredWorktreeProfile
    if ($retiredPolicy.explicitSwitchRequired -ne $true) { throw 'Retired-worktree policy must require an explicit switch.' }
    if ($retiredPolicy.requireDetachedHead -ne $true -or $retiredPolicy.requireCleanTrackedWorktree -ne $true) { throw 'Retired-worktree policy must require detached and clean tracked state.' }
    if ($retiredPolicy.requireDifferentArchiveRepoRoot -ne $true -or $retiredPolicy.requireSameGitCommonDirectory -ne $true) { throw 'Retired-worktree policy must require a durable sibling archive host.' }
    if ($retiredPolicy.requireExclusiveFileProbe -ne $true) { throw 'Retired-worktree policy must require the exclusive file probe.' }
    $retentionProfile = [string]$retiredPolicy.profileId
    $retiredChecks.detachedHead = ($branch -eq '(detached)')
    if (-not $retiredChecks.detachedHead) { $retiredPreconditionFailures.Add("Source worktree is attached to branch '$branch'.") | Out-Null }

    $trackedStatus = @(Get-GitOutput -Root $RepoRoot -Arguments @('status', '--porcelain', '--untracked-files=no'))
    $retiredChecks.cleanTrackedWorktree = ($trackedStatus.Count -eq 0)
    if (-not $retiredChecks.cleanTrackedWorktree) { $retiredPreconditionFailures.Add('Source worktree has tracked changes.') | Out-Null }

    $retiredChecks.headAncestorOf = [string]$retiredPolicy.requireHeadAncestorOf
    $savedErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & git -C $RepoRoot merge-base --is-ancestor HEAD $retiredChecks.headAncestorOf *> $null
        $ancestorExitCode = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $savedErrorActionPreference }
    $retiredChecks.headIsAncestor = ($ancestorExitCode -eq 0)
    if (-not $retiredChecks.headIsAncestor) { $retiredPreconditionFailures.Add("Source HEAD is not contained in $($retiredChecks.headAncestorOf).") | Out-Null }

    $retiredChecks.differentArchiveRepoRoot = -not $ArchiveRepoRoot.Equals($RepoRoot, [System.StringComparison]::OrdinalIgnoreCase)
    if (-not $retiredChecks.differentArchiveRepoRoot) { $retiredPreconditionFailures.Add('Retired evidence requires a different durable archive-host worktree.') | Out-Null }
    if (-not $retiredChecks.sameGitCommonDirectory) { $retiredPreconditionFailures.Add('Archive host is not a worktree of the same Git repository.') | Out-Null }
}
$retiredProfileBlocked = ($retiredPreconditionFailures.Count -gt 0)

$protectedPaths = @($policy.protectedRelativePaths | ForEach-Object {
    (Resolve-BoundedRepoPath -Root $RepoRoot -RelativePath ([string]$_) -Label 'protectedRelativePaths').TrimEnd('\', '/')
})
$protectedLeafNames = @($policy.protectedLeafNames | ForEach-Object { ([string]$_).ToLowerInvariant() })
$allCandidates = New-Object System.Collections.Generic.List[object]
$selectedCandidates = New-Object System.Collections.Generic.List[object]
$liveCandidateBytes = [long]0
$maximumLiveBytesTotal = [long]0

foreach ($rootPolicy in @($policy.candidateRoots)) {
    $candidateRoot = Resolve-BoundedRepoPath -Root $RepoRoot -RelativePath ([string]$rootPolicy.relativePath) -Label 'candidateRoots.relativePath'
    if (-not (Test-Path -LiteralPath $candidateRoot -PathType Container)) { continue }
    $rootCandidates = New-Object System.Collections.Generic.List[object]
    $maximumLiveBytesTotal += [long]$rootPolicy.maximumLiveBytes
    foreach ($item in @(Get-ChildItem -LiteralPath $candidateRoot -Force)) {
        $relativePath = Get-RepoRelativePath -Root $RepoRoot -Path $item.FullName
        $kind = if ($item.PSIsContainer) { 'directory' } else { 'file' }
        $candidate = [pscustomobject][ordered]@{
            relativePath = $relativePath
            fullPath = $item.FullName
            kind = $kind
            disposition = 'discovered'
            reason = ''
            lastActivityUtc = $item.LastWriteTimeUtc
            ageDays = [double]0
            bytes = [long]0
            fileCount = [int]0
            directoryCount = [int]0
            selectedForArchive = $false
            archiveRelativePath = ''
            manifestRelativePath = ''
            archiveSha256 = ''
            archiveBytes = [long]0
            inventory = $null
        }
        $allCandidates.Add($candidate) | Out-Null

        $normalizedFullPath = $item.FullName.TrimEnd('\', '/')
        $isProtectedPath = $false
        foreach ($protectedPath in $protectedPaths) {
            if ($normalizedFullPath.Equals($protectedPath, [System.StringComparison]::OrdinalIgnoreCase)) { $isProtectedPath = $true; break }
        }
        if ($isProtectedPath -or $protectedLeafNames -contains $item.Name.ToLowerInvariant()) {
            $candidate.disposition = 'protected_path'
            $candidate.reason = 'Policy protects current, latest, and archive paths from retention.'
            continue
        }
        if ([bool]($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
            $candidate.disposition = 'blocked_reparse_point'
            $candidate.reason = 'Reparse points and links are never archived or removed.'
            continue
        }
        if ($policy.safety.rejectTrackedContent -eq $true -and (Test-HasTrackedContent -Root $RepoRoot -RelativePath $relativePath)) {
            $candidate.disposition = 'blocked_tracked_content'
            $candidate.reason = 'Git reports tracked content under this candidate.'
            continue
        }
        if ($policy.safety.requireGitIgnored -eq $true -and -not (Test-GitIgnored -Root $RepoRoot -RelativePath $relativePath)) {
            $candidate.disposition = 'blocked_not_ignored'
            $candidate.reason = 'Candidate is not ignored by Git.'
            continue
        }

        $inventory = Get-CandidateInventory -Candidate $item
        $candidate.inventory = $inventory
        $candidate.lastActivityUtc = $inventory.lastActivityUtc
        $candidate.bytes = [long]$inventory.totalBytes
        $candidate.fileCount = @($inventory.files).Count
        $candidate.directoryCount = @($inventory.directories).Count
        $candidate.ageDays = [math]::Round(($ReferenceTimeUtc.ToUniversalTime() - ([datetime]$inventory.lastActivityUtc).ToUniversalTime()).TotalDays, 3)
        if ($inventory.hasReparsePoint -and $policy.safety.rejectReparsePoints -eq $true) {
            $candidate.disposition = 'blocked_reparse_point'
            $candidate.reason = 'Candidate contains a nested reparse point or link.'
            continue
        }
        $rootCandidates.Add($candidate) | Out-Null
        $liveCandidateBytes += [long]$candidate.bytes
    }

    if ($retiredProfileBlocked) {
        foreach ($candidate in $rootCandidates) {
            $candidate.disposition = 'blocked_retired_precondition'
            $candidate.reason = $retiredPreconditionFailures -join ' '
        }
        continue
    }

    $safeNewestFirst = @($rootCandidates | Sort-Object @{ Expression = { $_.lastActivityUtc }; Descending = $true }, @{ Expression = { $_.relativePath }; Descending = $false })
    $keepNewest = if ($RetiredWorktree) { [math]::Max(0, [int]$policy.retiredWorktreeProfile.keepNewest) } else { [math]::Max(0, [int]$rootPolicy.keepNewest) }
    for ($index = 0; $index -lt [math]::Min($keepNewest, $safeNewestFirst.Count); $index++) {
        $safeNewestFirst[$index].disposition = 'protected_newest'
        $safeNewestFirst[$index].reason = "Policy keeps the $keepNewest newest safe bundle(s) in this root."
    }

    $minimumAgeDays = if ($RetiredWorktree) { [double]$policy.retiredWorktreeProfile.minimumAgeDays } else { [double]$rootPolicy.minimumAgeDays }
    $cutoffUtc = $ReferenceTimeUtc.ToUniversalTime().AddDays(-$minimumAgeDays)
    $eligible = New-Object System.Collections.Generic.List[object]
    foreach ($candidate in $safeNewestFirst) {
        if ($candidate.disposition -eq 'protected_newest') { continue }
        if (([datetime]$candidate.lastActivityUtc).ToUniversalTime() -gt $cutoffUtc) {
            $candidate.disposition = 'protected_recent'
            $candidate.reason = "Bundle is younger than the $minimumAgeDays-day minimum age for profile '$retentionProfile'."
            continue
        }
        $eligible.Add($candidate) | Out-Null
    }

    $oldestFirst = @($eligible | Sort-Object @{ Expression = { $_.lastActivityUtc }; Descending = $false }, @{ Expression = { $_.relativePath }; Descending = $false })
    $maxArchives = if ($RetiredWorktree) { [math]::Max(0, [int]$policy.retiredWorktreeProfile.maxArchivesPerApply) } else { [math]::Max(0, [int]$rootPolicy.maxArchivesPerApply) }
    for ($index = 0; $index -lt $oldestFirst.Count; $index++) {
        $candidate = $oldestFirst[$index]
        if ($index -ge $maxArchives) {
            $candidate.disposition = 'deferred_capacity'
            $candidate.reason = "Per-run archive limit is $maxArchives."
            continue
        }
        $archiveFileName = Get-ArchiveFileName -CandidateRelativePath $candidate.relativePath -LastActivityUtc $candidate.lastActivityUtc
        $archiveFullPath = Join-Path $archiveRoot $archiveFileName
        $candidate.disposition = 'planned'
        $candidate.reason = if ($Apply) { 'Selected for verified archive and bounded source removal.' } else { 'Plan only; no archive or source mutation was performed.' }
        $candidate.selectedForArchive = $true
        $candidate.archiveRelativePath = Get-RepoRelativePath -Root $ArchiveRepoRoot -Path $archiveFullPath
        $selectedCandidates.Add($candidate) | Out-Null
    }
}

if ($RetiredWorktree -and -not $retiredProfileBlocked -and $selectedCandidates.Count -gt 0) {
    $exclusiveProbe = Test-CandidateExclusiveAccess -Candidates $selectedCandidates.ToArray()
    $retiredChecks.openHandleProbeMode = $exclusiveProbe.mode
    $retiredChecks.openHandleProbeStatus = $exclusiveProbe.status
    $retiredChecks.filesProbed = $exclusiveProbe.filesProbed
    $retiredChecks.lockedPaths = $exclusiveProbe.lockedPaths
    if ($exclusiveProbe.status -ne 'passed') {
        $retiredPreconditionFailures.Add('At least one selected evidence file has an open handle.') | Out-Null
        foreach ($candidate in $selectedCandidates) {
            $candidate.disposition = 'blocked_open_handles'
            $candidate.reason = "Exclusive file probe failed: $($exclusiveProbe.lockedPaths -join ', ')"
            $candidate.selectedForArchive = $false
        }
        $selectedCandidates.Clear()
        $retiredProfileBlocked = $true
    }
}
elseif ($RetiredWorktree -and -not $retiredProfileBlocked) {
    $retiredChecks.openHandleProbeStatus = 'no_eligible_files'
}
$retiredChecks.failures = $retiredPreconditionFailures.ToArray()

if ($Apply -and -not $retiredProfileBlocked -and $selectedCandidates.Count -gt 0) {
    New-Item -ItemType Directory -Force -Path $archiveRoot | Out-Null
}
$resultArtifacts = New-Object System.Collections.Generic.List[string]
$selectedFailures = 0
if ($Apply) {
    foreach ($candidate in $selectedCandidates) {
        $archiveFullPath = Resolve-BoundedRepoPath -Root $ArchiveRepoRoot -RelativePath $candidate.archiveRelativePath -Label 'candidate archive path'
        $manifestFullPath = $archiveFullPath + [string]$policy.archive.manifestSuffix
        $archiveResult = Invoke-VerifiedArchive -Candidate $candidate -ArchiveFullPath $archiveFullPath -ManifestFullPath $manifestFullPath -SourceRoot $RepoRoot -DestinationRoot $ArchiveRepoRoot -Branch $branch -RetentionProfile $retentionProfile -NowUtc $ReferenceTimeUtc -RequireExclusiveAccess:$RetiredWorktree
        if ($archiveResult.succeeded) {
            $candidate.disposition = 'archived_verified_source_removed'
            $candidate.reason = 'Archive and manifest passed SHA-256 verification before bounded source removal.'
            $candidate.archiveRelativePath = [string]$archiveResult.archiveRelativePath
            $candidate.manifestRelativePath = [string]$archiveResult.manifestRelativePath
            $candidate.archiveSha256 = [string]$archiveResult.archiveSha256
            $candidate.archiveBytes = [long]$archiveResult.archiveBytes
            if ($ArchiveRepoRoot.Equals($RepoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                $resultArtifacts.Add([string]$archiveResult.archiveRelativePath) | Out-Null
                $resultArtifacts.Add([string]$archiveResult.manifestRelativePath) | Out-Null
            }
            else {
                $resultArtifacts.Add((Join-Path $ArchiveRepoRoot ([string]$archiveResult.archiveRelativePath))) | Out-Null
                $resultArtifacts.Add((Join-Path $ArchiveRepoRoot ([string]$archiveResult.manifestRelativePath))) | Out-Null
            }
        }
        else {
            $candidate.disposition = 'archive_failed_source_preserved'
            $candidate.reason = [string]$archiveResult.error
            $selectedFailures++
            if (-not [string]::IsNullOrWhiteSpace([string]$archiveResult.archiveRelativePath)) {
                $resultArtifacts.Add([string]$archiveResult.archiveRelativePath) | Out-Null
            }
        }
    }
}

$plannedCount = @($allCandidates | Where-Object { $_.selectedForArchive }).Count
$archivedCandidates = @($allCandidates | Where-Object { $_.disposition -eq 'archived_verified_source_removed' })
$protectedCount = @($allCandidates | Where-Object { $_.disposition -like 'protected_*' }).Count
$blockedCount = @($allCandidates | Where-Object { $_.disposition -like 'blocked_*' -or $_.disposition -eq 'archive_failed_source_preserved' }).Count
$deferredCount = @($allCandidates | Where-Object { $_.disposition -eq 'deferred_capacity' }).Count
$plannedBytes = [long]0
$archivedSourceBytes = [long]0
foreach ($candidate in @($allCandidates | Where-Object { $_.selectedForArchive })) { $plannedBytes += [long]$candidate.bytes }
foreach ($candidate in $archivedCandidates) { $archivedSourceBytes += [long]$candidate.bytes }

$sizePressureBytes = [math]::Max([long]0, $liveCandidateBytes - $maximumLiveBytesTotal)
$projectedLiveBytesAfterApply = [math]::Max([long]0, $liveCandidateBytes - $plannedBytes)
$mode = if ($Apply) { 'apply' } else { 'plan' }
if ($retiredProfileBlocked) { $status = 'blocked'; $verdict = 'retention_blocked' }
elseif (-not $Apply -and $plannedCount -gt 0) { $status = 'ready'; $verdict = 'retention_plan_ready' }
elseif (-not $Apply) { $status = 'ready'; $verdict = 'nothing_to_archive' }
elseif ($selectedFailures -gt 0) { $status = 'partial'; $verdict = 'retention_apply_partial' }
elseif ($plannedCount -gt 0) { $status = 'complete'; $verdict = 'retention_apply_complete' }
else { $status = 'complete'; $verdict = 'nothing_to_archive' }

if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Resolve-BoundedRepoPath -Root $RepoRoot -RelativePath ([string]$policy.resultPath) -Label 'resultPath' }
elseif (-not [System.IO.Path]::IsPathRooted($OutputPath)) { $OutputPath = Resolve-BoundedRepoPath -Root $RepoRoot -RelativePath $OutputPath -Label 'OutputPath' }
else {
    $OutputPath = [System.IO.Path]::GetFullPath($OutputPath)
    if (-not (Test-PathWithinRoot -Path $OutputPath -Root $RepoRoot)) { throw 'OutputPath must remain inside RepoRoot.' }
}
$outputParent = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $outputParent | Out-Null
$outputRelativePath = Get-RepoRelativePath -Root $RepoRoot -Path $OutputPath
$resultArtifacts.Add($outputRelativePath) | Out-Null

$publicCandidates = @($allCandidates | ForEach-Object {
    [ordered]@{
        relativePath = $_.relativePath
        kind = $_.kind
        disposition = $_.disposition
        reason = $_.reason
        lastActivityUtc = ([datetime]$_.lastActivityUtc).ToUniversalTime().ToString('o')
        ageDays = [double]$_.ageDays
        bytes = [long]$_.bytes
        fileCount = [int]$_.fileCount
        directoryCount = [int]$_.directoryCount
        selectedForArchive = [bool]$_.selectedForArchive
        archiveRelativePath = $_.archiveRelativePath
        manifestRelativePath = $_.manifestRelativePath
        archiveSha256 = $_.archiveSha256
        archiveBytes = [long]$_.archiveBytes
    }
})
$result = [ordered]@{
    schema = 'tbg.evidence-retention.result.v1'
    action = 'ManageEvidenceRetention'
    timestampUtc = $ReferenceTimeUtc.ToUniversalTime().ToString('o')
    repoRoot = $RepoRoot
    branch = $branch
    retentionProfile = $retentionProfile
    mode = $mode
    status = $status
    verdict = $verdict
    policyPath = Get-RepoRelativePath -Root $scriptRepoRoot -Path $PolicyPath
    archiveRepoRoot = $ArchiveRepoRoot
    archiveRoot = Get-RepoRelativePath -Root $ArchiveRepoRoot -Path $archiveRoot
    retiredWorktreeChecks = $retiredChecks
    summary = [ordered]@{
        discoveredCount = $allCandidates.Count
        plannedCount = $plannedCount
        archivedCount = $archivedCandidates.Count
        protectedCount = $protectedCount
        blockedCount = $blockedCount
        deferredCount = $deferredCount
        plannedBytes = $plannedBytes
        archivedSourceBytes = $archivedSourceBytes
        liveCandidateBytes = $liveCandidateBytes
        sizePressureBytes = $sizePressureBytes
        projectedLiveBytesAfterApply = $projectedLiveBytesAfterApply
    }
    candidates = $publicCandidates
    artifacts = @($resultArtifacts | Select-Object -Unique)
}
$result | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
$result | ConvertTo-Json -Depth 30
