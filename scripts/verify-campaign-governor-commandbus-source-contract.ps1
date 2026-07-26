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

Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandRegistry.cs' -Pattern 'using BlacksmithGuild.CampaignRuntime;'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandRegistry.cs' -Pattern 'CampaignRuntimeGovernor.RunCampaignGovernorCycleNowCommand'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandRegistry.cs' -Pattern 'CampaignRuntimeGovernor.ShowCampaignGovernorDecisionCommand'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandRegistry.cs' -Pattern 'CampaignRuntimeGovernor.PauseCampaignGovernorAutomationCommand'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandRegistry.cs' -Pattern 'CampaignRuntimeGovernor.ResumeCampaignGovernorAutomationCommand'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandRegistry.cs' -Pattern 'EngineToggleAuthority.ShowEngineToggleStateCommand'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandRegistry.cs' -Pattern 'EngineToggleAuthority.CycleEngineToggleModeCommand'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandRegistry.cs' -Pattern 'EngineToggleAuthority.SetEngineToggleManualCommand'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandRegistry.cs' -Pattern 'EngineToggleAuthority.SetEngineToggleHybridCommand'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandRegistry.cs' -Pattern 'EngineToggleAuthority.SetEngineToggleAutomationCommand'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandRegistry.cs' -Pattern 'SaveIdentityReportService.ReportSaveIdentityNowCommand'

Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandBus.cs' -Pattern 'using BlacksmithGuild.CampaignRuntime;'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandBus.cs' -Pattern 'commandName == CampaignRuntimeGovernor.RunCampaignGovernorCycleNowCommand'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandBus.cs' -Pattern 'commandName == CampaignRuntimeGovernor.ShowCampaignGovernorDecisionCommand'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandBus.cs' -Pattern 'commandName == CampaignRuntimeGovernor.PauseCampaignGovernorAutomationCommand'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandBus.cs' -Pattern 'commandName == CampaignRuntimeGovernor.ResumeCampaignGovernorAutomationCommand'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandBus.cs' -Pattern 'campaign governor command failed'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandBus.cs' -Pattern 'case CampaignRuntimeGovernor.RunCampaignGovernorCycleNowCommand:'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandBus.cs' -Pattern 'CampaignRuntimeGovernor.RunCycleNow(source: commandName)'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandBus.cs' -Pattern 'case CampaignRuntimeGovernor.ShowCampaignGovernorDecisionCommand:'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandBus.cs' -Pattern 'CampaignRuntimeGovernor.ShowLastDecision()'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandBus.cs' -Pattern 'case CampaignRuntimeGovernor.PauseCampaignGovernorAutomationCommand:'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandBus.cs' -Pattern 'CampaignRuntimeGovernor.PauseAutomation("command")'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandBus.cs' -Pattern 'case CampaignRuntimeGovernor.ResumeCampaignGovernorAutomationCommand:'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandBus.cs' -Pattern 'CampaignRuntimeGovernor.ResumeAutomation("command")'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandBus.cs' -Pattern 'case EngineToggleAuthority.ShowEngineToggleStateCommand:'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandBus.cs' -Pattern 'case EngineToggleAuthority.SetEngineToggleAutomationCommand:'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandBus.cs' -Pattern 'EngineToggleAuthority.RunCommand(commandName, commandName)'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandBus.cs' -Pattern 'SaveIdentityReportService.ReportNow(payload, commandName)'

Assert-Contains -Path 'src/BlacksmithGuild/DevTools/QuickStart/SaveIdentityReportService.cs' -Pattern 'public const string ReportSaveIdentityNowCommand'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/QuickStart/SaveIdentityReportService.cs' -Pattern 'CampaignSetupStateTracker.DevSaveLoadStartedExplicitly'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/QuickStart/SaveIdentityReportService.cs' -Pattern 'identityVerified'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/QuickStart/SaveIdentityReportService.cs' -Pattern 'context?.CorrelationId'

Write-Host 'Campaign governor command-bus source contract: PASS'
