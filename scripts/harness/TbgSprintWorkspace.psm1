Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-TbgStatusPaths {
    param([string]$StatusShort)

    $paths = New-Object System.Collections.Generic.List[string]
    foreach ($line in @($StatusShort -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 4) { continue }
        $path = $line.Substring(3).Trim()
        if ($path -like '* -> *') { $path = ($path -split ' -> ')[-1] }
        if (-not [string]::IsNullOrWhiteSpace($path)) { $paths.Add($path.Replace('\', '/')) }
    }
    return @($paths)
}

function Test-TbgForbiddenPath {
    param(
        [string]$Path,
        [string[]]$ForbiddenPaths
    )

    $normalized = $Path.Replace('\', '/')
    foreach ($forbidden in @($ForbiddenPaths)) {
        $pattern = ([string]$forbidden).Replace('\', '/')
        if ($normalized -ieq $pattern -or $normalized -like $pattern) { return $true }
    }
    return $false
}

function Quote-TbgGitArgument {
    param([string]$Value)

    if ($Value.Contains("`0") -or $Value.Contains("`r") -or $Value.Contains("`n")) {
        throw "Unsafe null or newline in git argument: $Value"
    }
    return "'" + $Value.Replace("'", "''") + "'"
}

function Resolve-TbgSprintWorkspaceDecision {
    [CmdletBinding()]
    param(
        [AllowEmptyString()][string]$StatusShort = '',
        [string[]]$ConflictedPaths = @(),
        [string]$CurrentBranch = '',
        [string]$DefaultRemoteBase = 'origin/main',
        [ValidateSet('none', 'OPEN', 'MERGED', 'CLOSED', 'UNKNOWN')][string]$FoundationPrState = 'none',
        [string]$FoundationHead = '',
        [string]$FoundationBase = '',
        [string]$FoundationPrUrl = '',
        [string]$ExistingWorktreePath = '',
        [string]$PrimaryRepo = '',
        [string]$WorktreePath = '',
        [string]$TargetBranch = '',
        [string[]]$ForbiddenPaths = @()
    )

    $statusPaths = @(Get-TbgStatusPaths -StatusShort $StatusShort)
    $conflicts = New-Object System.Collections.Generic.List[string]
    foreach ($path in @($ConflictedPaths)) {
        $normalized = ([string]$path).Replace('\', '/')
        if (-not [string]::IsNullOrWhiteSpace($normalized) -and -not $conflicts.Contains($normalized)) { $conflicts.Add($normalized) }
    }
    foreach ($line in @($StatusShort -split "`r?`n")) {
        if ($line -match '^(UU|AA|DD|AU|UA|DU|UD)\s+(.+)$') {
            $path = $Matches[2].Trim().Replace('\', '/')
            if (-not $conflicts.Contains($path)) { $conflicts.Add($path) }
        }
    }

    $touched = New-Object System.Collections.Generic.List[string]
    foreach ($path in @($statusPaths + @($conflicts))) {
        if ((Test-TbgForbiddenPath -Path $path -ForbiddenPaths $ForbiddenPaths) -and -not $touched.Contains($path)) {
            $touched.Add($path)
        }
    }

    $chosenBase = $DefaultRemoteBase
    $baseReason = 'remote_default_selected'
    $baseBlocked = [string]::IsNullOrWhiteSpace($DefaultRemoteBase)
    if ($baseBlocked) { $baseReason = 'remote_default_missing' }
    switch ($FoundationPrState) {
        'MERGED' {
            $chosenBase = $DefaultRemoteBase
            $baseReason = 'foundation_pr_merged_use_remote_default'
        }
        'OPEN' {
            if ([string]::IsNullOrWhiteSpace($FoundationHead)) {
                $baseBlocked = $true
                $baseReason = 'open_foundation_pr_missing_head'
            }
            else {
                $chosenBase = if ($FoundationHead -like 'origin/*') { $FoundationHead } else { "origin/$FoundationHead" }
                $baseReason = 'open_foundation_pr_use_remote_head'
            }
        }
        'CLOSED' {
            $baseBlocked = $true
            $baseReason = 'closed_unmerged_foundation_pr_requires_review'
        }
        'UNKNOWN' {
            $baseBlocked = $true
            $baseReason = 'foundation_pr_state_unknown'
        }
        default { }
    }

    $primaryDirty = -not [string]::IsNullOrWhiteSpace($StatusShort)
    $primaryConflicted = $conflicts.Count -gt 0
    $disposition = 'use_primary'
    if ($baseBlocked) {
        $disposition = 'blocked'
    }
    elseif (-not [string]::IsNullOrWhiteSpace($ExistingWorktreePath)) {
        $disposition = 'use_existing_worktree'
    }
    elseif ($primaryDirty -or $primaryConflicted) {
        if ([string]::IsNullOrWhiteSpace($WorktreePath) -or [string]::IsNullOrWhiteSpace($TargetBranch)) {
            $disposition = 'blocked'
            $baseReason = 'isolated_worktree_requires_path_and_branch'
        }
        else {
            $disposition = 'create_isolated_worktree'
        }
    }

    $worktreeCommand = ''
    $selectedPath = $PrimaryRepo
    $selectedBranch = $CurrentBranch
    if ($disposition -eq 'create_isolated_worktree') {
        $worktreeCommand = "git worktree add -b $(Quote-TbgGitArgument -Value $TargetBranch) -- $(Quote-TbgGitArgument -Value $WorktreePath) $(Quote-TbgGitArgument -Value $chosenBase)"
        $selectedPath = $WorktreePath
        $selectedBranch = $TargetBranch
    }
    elseif ($disposition -eq 'use_existing_worktree') {
        $selectedPath = $ExistingWorktreePath
        $selectedBranch = $TargetBranch
    }

    $status = 'ready'
    if ($disposition -eq 'create_isolated_worktree') { $status = 'needs_isolated_worktree' }
    elseif ($disposition -eq 'blocked') { $status = 'blocked' }

    $conflictText = if ($primaryConflicted) { 'conflicted' } elseif ($primaryDirty) { 'dirty' } else { 'clean' }
    $scopeText = if ($touched.Count -gt 0) { " It touches forbidden paths: $(@($touched) -join ', ')." } else { '' }
    $actionText = switch ($disposition) {
        'create_isolated_worktree' { "The harness selected an isolated worktree at $WorktreePath from $chosenBase." }
        'use_existing_worktree' { "The harness selected the existing worktree at $ExistingWorktreePath from $chosenBase." }
        'use_primary' { "The harness kept the primary checkout on $CurrentBranch." }
        default { "The harness blocked workspace selection because $baseReason." }
    }
    $english = "The primary checkout is $conflictText.$scopeText $actionText"

    return [pscustomobject][ordered]@{
        schema = 'tbg.harness.sprint-workspace-decision.v1'
        status = $status
        disposition = $disposition
        primaryRepo = $PrimaryRepo
        currentBranch = $CurrentBranch
        primaryDirty = $primaryDirty
        primaryConflicted = $primaryConflicted
        conflictedPaths = @($conflicts)
        forbiddenScopeTouched = $touched.Count -gt 0
        forbiddenPathsTouched = @($touched)
        foundationPrState = $FoundationPrState
        foundationHead = $FoundationHead
        foundationBase = $FoundationBase
        foundationPrUrl = $FoundationPrUrl
        chosenBaseRef = $chosenBase
        baseReason = $baseReason
        worktreePath = $selectedPath
        targetBranch = $selectedBranch
        worktreeCommand = $worktreeCommand
        evidence = [pscustomobject][ordered]@{
            statusShort = $StatusShort
            statusPaths = @($statusPaths)
            conflictedPaths = @($conflicts)
        }
        handoff = [pscustomobject][ordered]@{
            workspacePath = $selectedPath
            branch = $selectedBranch
            baseRef = $chosenBase
            nextCommand = $worktreeCommand
        }
        englishSummary = $english.Trim()
    }
}

Export-ModuleMember -Function Resolve-TbgSprintWorkspaceDecision
