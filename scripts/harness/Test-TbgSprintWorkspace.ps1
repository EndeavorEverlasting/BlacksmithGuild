param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Equal {
    param([object]$Actual, [object]$Expected, [string]$Message)
    if ([string]$Actual -cne [string]$Expected) { throw "$Message Expected '$Expected', got '$Actual'." }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Import-Module (Join-Path $PSScriptRoot 'TbgSprintWorkspace.psm1') -Force
$fixtures = Get-Content -LiteralPath (Join-Path $repoRoot '.tbg/harness/fixtures/sprint-workspace.fixtures.json') -Raw | ConvertFrom-Json
$schema = Get-Content -LiteralPath (Join-Path $repoRoot '.tbg/harness/schemas/sprint-workspace-decision.schema.json') -Raw | ConvertFrom-Json
$count = 0

foreach ($case in @($fixtures.cases)) {
    $input = $case.input
    $args = @{
        StatusShort = [string]$input.statusShort
        CurrentBranch = [string]$input.currentBranch
        DefaultRemoteBase = [string]$input.defaultRemoteBase
        PrimaryRepo = [string]$input.primaryRepo
        WorktreePath = [string]$input.worktreePath
        TargetBranch = [string]$input.targetBranch
        ForbiddenPaths = @($fixtures.forbiddenPaths)
    }
    foreach ($name in @('conflictedPaths', 'foundationPrState', 'foundationHead', 'foundationBase', 'foundationPrUrl', 'existingWorktreePath')) {
        $property = $input.PSObject.Properties[$name]
        if ($null -ne $property) { $args[$name.Substring(0, 1).ToUpperInvariant() + $name.Substring(1)] = $property.Value }
    }

    $decision = Resolve-TbgSprintWorkspaceDecision @args
    foreach ($property in $case.expected.PSObject.Properties) {
        $actualProperty = $decision.PSObject.Properties[$property.Name]
        if ($null -eq $actualProperty) { throw "Fixture '$($case.id)' did not return '$($property.Name)'." }
        Assert-Equal -Actual $actualProperty.Value -Expected $property.Value -Message "Fixture '$($case.id)' field '$($property.Name)' failed."
    }
    foreach ($required in @($schema.required)) {
        if ($null -eq $decision.PSObject.Properties[[string]$required]) { throw "Fixture '$($case.id)' omitted required field '$required'." }
    }
    if ($decision.worktreeCommand -match '(?i)\b(reset|checkout|switch|clean|remove|delete)\b') {
        throw "Fixture '$($case.id)' emitted a destructive workspace command: $($decision.worktreeCommand)"
    }
    if ($decision.disposition -eq 'create_isolated_worktree' -and $decision.worktreeCommand -notmatch '^git worktree add -b .+ -- ') {
        throw "Fixture '$($case.id)' did not emit the bounded worktree command."
    }
    if ($decision.disposition -ne 'create_isolated_worktree' -and -not [string]::IsNullOrWhiteSpace($decision.worktreeCommand)) {
        throw "Fixture '$($case.id)' emitted a worktree command for disposition '$($decision.disposition)'."
    }
    if ([string]::IsNullOrWhiteSpace($decision.englishSummary)) { throw "Fixture '$($case.id)' omitted English handoff prose." }
    Write-Host "[$($case.id)] $($decision.englishSummary)"
    $count++
}

Write-Host "PASS: $count sprint workspace fixtures selected safe primary, existing, or isolated worktrees with PR-aware bases."
