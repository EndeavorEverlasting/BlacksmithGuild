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

function Assert-Ordered {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$First,
        [Parameter(Mandatory = $true)][string]$Then,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $full = Join-Path $RepoRoot $Path
    if (-not (Test-Path -LiteralPath $full)) {
        throw "Missing file: $Path"
    }

    $text = Get-Content -LiteralPath $full -Raw
    $firstIndex = $text.IndexOf($First, [StringComparison]::Ordinal)
    $thenIndex = $text.IndexOf($Then, [StringComparison]::Ordinal)
    if ($firstIndex -lt 0 -or $thenIndex -lt 0 -or $firstIndex -ge $thenIndex) {
        throw "Expected '$First' before '$Then' in $Path ($Label)"
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
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/QuickStart/SaveIdentityReportService.cs' -Pattern 'MBSaveLoad.ActiveSaveSlotName'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/QuickStart/SaveIdentityReportService.cs' -Pattern 'DevSaveResolver.IsDisposableSaveName(normalized)'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/QuickStart/SaveIdentityReportService.cs' -Pattern 'var explicitTrackerVerified = !hasActiveSaveSlot'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/QuickStart/SaveIdentityReportService.cs' -Pattern 'var devSaveLoadUsed = identityVerified'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/QuickStart/SaveIdentityReportService.cs' -Pattern 'var explicitLoadObserved = explicitTrackerAllowed'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/QuickStart/SaveIdentityReportService.cs' -Pattern 'string.Equals('
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/QuickStart/SaveIdentityReportService.cs' -Pattern 'identityVerified'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/QuickStart/SaveIdentityReportService.cs' -Pattern 'context?.CorrelationId'

Assert-Contains -Path 'src/BlacksmithGuild/DevTools/QuickStart/DevSaveResolver.cs' -Pattern 'public static bool TryGetUnique'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/QuickStart/DevSaveResolver.cs' -Pattern 'LegacyDevSaveName = "BlacksmithGuildDevStart"'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/QuickStart/DevSaveResolver.cs' -Pattern 'public static bool IsDisposableSaveName'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/QuickStart/DevSaveResolver.cs' -Pattern 'Where(IsDisposableSaveName)'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/QuickStart/DevSaveResolver.cs' -Pattern 'if (candidates.Count > 1)'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/QuickStart/DevSaveResolver.cs' -Pattern 'if (names == null || names.Count != 1)'

Assert-Contains -Path 'src/BlacksmithGuild/DevTools/QuickStart/MainMenuAutoLauncher.cs' -Pattern 'TryLoadUniqueDisposableSaveForContinue'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/QuickStart/MainMenuAutoLauncher.cs' -Pattern 'DevToolsConfig.AutoLoadDevSave'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/QuickStart/MainMenuAutoLauncher.cs' -Pattern 'DevSaveResolver.TryGetUnique(out var saveInfo)'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/QuickStart/MainMenuAutoLauncher.cs' -Pattern 'DevSaveAutoLoader.TryLoad(saveInfo)'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/QuickStart/MainMenuAutoLauncher.cs' -Pattern 'CompleteIntent($"auto-loading disposable dev save {devSaveName} (Continue).")'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/QuickStart/DevSaveAutoLoader.cs' -Pattern 'CampaignSetupStateTracker.MarkDevSaveLoadStarted(saveInfo.Name)'
Assert-Ordered -Path 'src/BlacksmithGuild/DevTools/QuickStart/MainMenuAutoLauncher.cs' `
    -First 'if (TryLoadUniqueDisposableSaveForContinue(out var devSaveName))' `
    -Then 'else if (TryExecuteFirstAvailable(ContinueOptionIds, "Continue Campaign", out var selectedId))' `
    -Label 'explicit disposable load must precede the vanilla Continue fallback'

Write-Host 'Campaign governor command-bus source contract: PASS'
