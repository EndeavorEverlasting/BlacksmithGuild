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

Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityHandoff.cs' -Pattern 'public sealed class CampaignActivityHandoff'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityHandoff.cs' -Pattern 'public static class CampaignActivityHandoffRecorder'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityHandoff.cs' -Pattern 'FromEngine'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityHandoff.cs' -Pattern 'ToEngine'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityHandoff.cs' -Pattern 'GovernorMode'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityHandoff.cs' -Pattern 'ExpectedProof'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityHandoff.cs' -Pattern 'result.HandoffTrail.Count == 0'

Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityContract.cs' -Pattern 'List<CampaignActivityHandoff> HandoffTrail'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityContract.cs' -Pattern 'governor_selection'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityContract.cs' -Pattern 'governor_observation'

Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityDispatcher.cs' -Pattern 'dispatch_received'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityDispatcher.cs' -Pattern 'adapter_selected'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityDispatcher.cs' -Pattern 'adapter_result'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityDispatcher.cs' -Pattern 'dispatch_result'

Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeDecisionWriter.cs' -Pattern 'handoffTrail'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeDecisionWriter.cs' -Pattern 'AppendHandoffTrail'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeDecisionWriter.cs' -Pattern 'governorMode'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeDecisionWriter.cs' -Pattern 'mutationApplied'

Write-Host 'Campaign activity handoff contract: PASS'
