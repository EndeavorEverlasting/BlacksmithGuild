param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

function Get-Newline {
    param([Parameter(Mandatory = $true)][string]$Text)

    if ($Text -match "`r`n") {
        return "`r`n"
    }

    return "`n"
}

function Normalize-Block {
    param(
        [Parameter(Mandatory = $true)][string]$Block,
        [Parameter(Mandatory = $true)][string]$Newline
    )

    return ($Block -replace "`r?`n", $Newline).TrimEnd()
}

function Insert-AfterLine {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$AnchorLine,
        [Parameter(Mandatory = $true)][string]$InsertBlock
    )

    $nl = Get-Newline -Text $Text
    $block = Normalize-Block -Block $InsertBlock -Newline $nl
    $pattern = [regex]::Escape($AnchorLine) + "`r?`n"

    if ($Text -notmatch $pattern) {
        throw "Anchor not found: $AnchorLine"
    }

    return [regex]::Replace($Text, $pattern, $AnchorLine + $nl + $block + $nl, 1)
}

function Insert-BeforeText {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$AnchorText,
        [Parameter(Mandatory = $true)][string]$InsertBlock
    )

    $nl = Get-Newline -Text $Text
    $block = Normalize-Block -Block $InsertBlock -Newline $nl

    if (-not $Text.Contains($AnchorText)) {
        throw "Anchor not found: $AnchorText"
    }

    return $Text.Replace($AnchorText, $block + $nl + $AnchorText)
}

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

    $nl = Get-Newline -Text $text

    if ($text -notmatch 'using BlacksmithGuild\.CampaignRuntime;') {
        $text = $text -replace 'using System\.Collections\.Generic;\r?\n', "using System.Collections.Generic;${nl}using BlacksmithGuild.CampaignRuntime;${nl}"
    }

    if ($text -notmatch 'RunCampaignGovernorCycleNowCommand') {
        $text = Insert-AfterLine -Text $text -AnchorLine '                CharacterBuildVariantService.DumpCharacterBuildSnapshotNowCommand,' -InsertBlock @'
                CampaignRuntimeGovernor.RunCampaignGovernorCycleNowCommand,
                CampaignRuntimeGovernor.ShowCampaignGovernorDecisionCommand,
                CampaignRuntimeGovernor.PauseCampaignGovernorAutomationCommand,
                CampaignRuntimeGovernor.ResumeCampaignGovernorAutomationCommand,
'@
    }

    return $text
}

Update-TextFile -Path 'src/BlacksmithGuild/DevTools/DevCommandBus.cs' -Transform {
    param($text)

    $nl = Get-Newline -Text $text

    if ($text -notmatch 'using BlacksmithGuild\.CampaignRuntime;') {
        $text = $text -replace 'using BlacksmithGuild\.ClanIntel;\r?\n', "using BlacksmithGuild.CampaignRuntime;${nl}using BlacksmithGuild.ClanIntel;${nl}"
    }

    if ($text -notmatch 'commandName == CampaignRuntimeGovernor\.RunCampaignGovernorCycleNowCommand') {
        $text = Insert-BeforeText -Text $text -AnchorText '                commandName == MapTradeVanillaTradeDriver.ProbeVanillaTradeExecutionNowCommand ||' -InsertBlock @'
                commandName == CampaignRuntimeGovernor.RunCampaignGovernorCycleNowCommand ||
                commandName == CampaignRuntimeGovernor.ShowCampaignGovernorDecisionCommand ||
                commandName == CampaignRuntimeGovernor.PauseCampaignGovernorAutomationCommand ||
                commandName == CampaignRuntimeGovernor.ResumeCampaignGovernorAutomationCommand ||
'@
    }

    if ($text -notmatch 'campaign governor command failed') {
        $text = Insert-BeforeText -Text $text -AnchorText '            if (commandName == AssistiveLeaveTownTravelService.Command)' -InsertBlock @'
            if (commandName == CampaignRuntimeGovernor.RunCampaignGovernorCycleNowCommand ||
                commandName == CampaignRuntimeGovernor.ShowCampaignGovernorDecisionCommand ||
                commandName == CampaignRuntimeGovernor.PauseCampaignGovernorAutomationCommand ||
                commandName == CampaignRuntimeGovernor.ResumeCampaignGovernorAutomationCommand)
            {
                return "campaign governor command failed";
            }

'@
    }

    if ($text -notmatch 'case CampaignRuntimeGovernor\.RunCampaignGovernorCycleNowCommand:') {
        $text = Insert-BeforeText -Text $text -AnchorText '                case CharacterBuildVariantService.DumpCharacterBuildSnapshotNowCommand:' -InsertBlock @'
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
    }

    return $text
}

Write-Host 'Campaign governor command-bus local patch complete. Run build and contract verifiers next.'
