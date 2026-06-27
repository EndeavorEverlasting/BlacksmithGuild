param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

function Update-TextFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][scriptblock]$Transform
    )

    $full = Join-Path $RepoRoot $Path
    if (-not (Test-Path -LiteralPath $full)) {
        throw "Missing file: $Path"
    }

    $text = Get-Content -LiteralPath $full -Raw
    $updated = & $Transform $text
    if ($updated -ne $text) {
        Set-Content -LiteralPath $full -Value $updated -NoNewline -Encoding UTF8
        Write-Host "patched $Path"
    } else {
        Write-Host "unchanged $Path"
    }
}

Update-TextFile -Path 'src/BlacksmithGuild/DevTools/DevCommandRegistry.cs' -Transform {
    param($text)

    if ($text -notmatch 'using BlacksmithGuild\.CampaignRuntime;') {
        $text = $text -replace 'using System\.Collections\.Generic;\r?\n', "using System.Collections.Generic;`r`nusing BlacksmithGuild.CampaignRuntime;`r`n"
    }

    $anchor = '                CharacterBuildVariantService.DumpCharacterBuildSnapshotNowCommand,'
    $insert = @'
                CampaignRuntimeGovernor.RunCampaignGovernorCycleNowCommand,
                CampaignRuntimeGovernor.ShowCampaignGovernorDecisionCommand,
                CampaignRuntimeGovernor.PauseCampaignGovernorAutomationCommand,
                CampaignRuntimeGovernor.ResumeCampaignGovernorAutomationCommand,
'@

    if ($text -notmatch 'RunCampaignGovernorCycleNowCommand') {
        $text = $text.Replace($anchor + "`r`n", $anchor + "`r`n" + $insert)
    }

    return $text
}

Update-TextFile -Path 'src/BlacksmithGuild/DevTools/DevCommandBus.cs' -Transform {
    param($text)

    if ($text -notmatch 'using BlacksmithGuild\.CampaignRuntime;') {
        $text = $text -replace 'using BlacksmithGuild\.ClanIntel;\r?\n', "using BlacksmithGuild.CampaignRuntime;`r`nusing BlacksmithGuild.ClanIntel;`r`n"
    }

    $notifyAnchor = '                commandName == MapTradeVanillaTradeDriver.ProbeVanillaTradeExecutionNowCommand ||'
    $notifyInsert = @'
                commandName == CampaignRuntimeGovernor.RunCampaignGovernorCycleNowCommand ||
                commandName == CampaignRuntimeGovernor.ShowCampaignGovernorDecisionCommand ||
                commandName == CampaignRuntimeGovernor.PauseCampaignGovernorAutomationCommand ||
                commandName == CampaignRuntimeGovernor.ResumeCampaignGovernorAutomationCommand ||
'@
    if ($text -notmatch 'commandName == CampaignRuntimeGovernor\.RunCampaignGovernorCycleNowCommand') {
        $text = $text.Replace($notifyAnchor + "`r`n", $notifyInsert + $notifyAnchor + "`r`n")
    }

    $failAnchor = '            if (commandName == AssistiveLeaveTownTravelService.Command)'
    $failInsert = @'
            if (commandName == CampaignRuntimeGovernor.RunCampaignGovernorCycleNowCommand ||
                commandName == CampaignRuntimeGovernor.ShowCampaignGovernorDecisionCommand ||
                commandName == CampaignRuntimeGovernor.PauseCampaignGovernorAutomationCommand ||
                commandName == CampaignRuntimeGovernor.ResumeCampaignGovernorAutomationCommand)
            {
                return "campaign governor command failed";
            }

'@
    if ($text -notmatch 'campaign governor command failed') {
        $text = $text.Replace($failAnchor, $failInsert + $failAnchor)
    }

    $executeAnchor = '                case CharacterBuildVariantService.DumpCharacterBuildSnapshotNowCommand:'
    $executeInsert = @'
                case CampaignRuntimeGovernor.RunCampaignGovernorCycleNowCommand:
                    return CampaignRuntimeGovernor.RunCycleNow(source: commandName)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case CampaignRuntimeGovernor.ShowCampaignGovernorDecisionCommand:
                    return CampaignRuntimeGovernor.ShowLastDecision()
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case CampaignRuntimeGovernor.PauseCampaignGovernorAutomationCommand:
                    return CampaignRuntimeGovernor.PauseAutomation("command")
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case CampaignRuntimeGovernor.ResumeCampaignGovernorAutomationCommand:
                    return CampaignRuntimeGovernor.ResumeAutomation("command")
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
'@
    if ($text -notmatch 'case CampaignRuntimeGovernor\.RunCampaignGovernorCycleNowCommand:') {
        $text = $text.Replace($executeAnchor, $executeInsert + $executeAnchor)
    }

    return $text
}

Write-Host 'Campaign governor command-bus local patch complete. Run build and contract verifiers next.'
