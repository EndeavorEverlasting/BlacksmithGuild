param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [string]$Label = $Pattern
    )

    $full = Join-Path $RepoRoot $Path
    if (-not (Test-Path -LiteralPath $full)) {
        throw "Missing file: $Path"
    }

    $text = Get-Content -LiteralPath $full -Raw
    if ($text -notmatch [regex]::Escape($Pattern)) {
        throw "Missing '$Label' in $Path"
    }
}

Assert-Contains -Path 'scripts/patch-campaign-governor-commandbus-local.ps1' -Pattern 'DevCommandRegistry.cs'
Assert-Contains -Path 'scripts/patch-campaign-governor-commandbus-local.ps1' -Pattern 'DevCommandBus.cs'
Assert-Contains -Path 'scripts/patch-campaign-governor-commandbus-local.ps1' -Pattern 'using BlacksmithGuild.CampaignRuntime;'
Assert-Contains -Path 'scripts/patch-campaign-governor-commandbus-local.ps1' -Pattern 'RunCampaignGovernorCycleNowCommand'
Assert-Contains -Path 'scripts/patch-campaign-governor-commandbus-local.ps1' -Pattern 'ShowCampaignGovernorDecisionCommand'
Assert-Contains -Path 'scripts/patch-campaign-governor-commandbus-local.ps1' -Pattern 'PauseCampaignGovernorAutomationCommand'
Assert-Contains -Path 'scripts/patch-campaign-governor-commandbus-local.ps1' -Pattern 'ResumeCampaignGovernorAutomationCommand'
Assert-Contains -Path 'scripts/patch-campaign-governor-commandbus-local.ps1' -Pattern 'CampaignRuntimeGovernor.RunCycleNow(source: commandName)'
Assert-Contains -Path 'scripts/patch-campaign-governor-commandbus-local.ps1' -Pattern 'CampaignRuntimeGovernor.ShowLastDecision()'
Assert-Contains -Path 'scripts/patch-campaign-governor-commandbus-local.ps1' -Pattern 'CampaignRuntimeGovernor.PauseAutomation("command")'
Assert-Contains -Path 'scripts/patch-campaign-governor-commandbus-local.ps1' -Pattern 'CampaignRuntimeGovernor.ResumeAutomation("command")'

Write-Host 'Campaign governor command-bus patch contract: PASS'
