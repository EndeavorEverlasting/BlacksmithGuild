param(
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$catalogPath = Join-Path $repoRoot '.tbg\operator\control-surface.json'
$workflowPath = Join-Path $repoRoot '.tbg\workflows\continue-visible-trade-cycle.contract.json'
$planPath = Join-Path $repoRoot 'docs\operator\load-save-toggle-and-visible-trade-plan.md'
$hotkeyPath = Join-Path $repoRoot 'src\BlacksmithGuild\DevTools\DevHotkeyHandler.cs'
$authorityPath = Join-Path $repoRoot 'src\BlacksmithGuild\DevTools\EngineToggleAuthority.cs'
$routePath = Join-Path $repoRoot 'src\BlacksmithGuild\MapTrade\MapTradeAutonomousService.cs'
$assistWrapperPath = Join-Path $repoRoot 'Run-AutonomousAssistSession.cmd'

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-ContainsText {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Needle,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if (-not $Text.Contains($Needle)) {
        throw "$Label missing required text: $Needle"
    }
}

foreach ($path in @($catalogPath, $workflowPath, $planPath, $hotkeyPath, $authorityPath, $routePath, $assistWrapperPath)) {
    Assert-True -Condition (Test-Path -LiteralPath $path) -Message "Operator control contract missing file: $path"
}

$catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
$workflow = Get-Content -LiteralPath $workflowPath -Raw | ConvertFrom-Json
$plan = Get-Content -LiteralPath $planPath -Raw
$hotkeys = Get-Content -LiteralPath $hotkeyPath -Raw
$authority = Get-Content -LiteralPath $authorityPath -Raw
$route = Get-Content -LiteralPath $routePath -Raw
$assistWrapper = Get-Content -LiteralPath $assistWrapperPath -Raw

Assert-True -Condition ($catalog.schemaVersion -eq 'TbgOperatorControlSurface.v1') -Message 'Unexpected operator catalog schemaVersion'
Assert-True -Condition ($workflow.schemaVersion -eq 'TbgWorkflowContract.v1') -Message 'Unexpected visible-trade workflow schemaVersion'

$enumMatch = [regex]::Match($authority, '(?s)public\s+enum\s+EngineToggleKey\s*\{(?<body>[^}]*)\}')
Assert-True -Condition $enumMatch.Success -Message 'EngineToggleKey enum was not found'
$sourceEngines = @(
    $enumMatch.Groups['body'].Value.Split(',') |
        ForEach-Object { $_.Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
)
$catalogEngines = @($catalog.engines | ForEach-Object { [string]$_.engine })
$engineDiff = @(Compare-Object -ReferenceObject $sourceEngines -DifferenceObject $catalogEngines)
Assert-True -Condition ($engineDiff.Count -eq 0) -Message "Operator engine catalog drift: $($engineDiff | Out-String)"

$toggle = @($catalog.hotkeys | Where-Object { $_.chord -eq 'Ctrl+Alt+T' })
Assert-True -Condition ($toggle.Count -eq 1) -Message 'Ctrl+Alt+T must have exactly one catalog row'
Assert-True -Condition ((@($toggle[0].cycle) -join ',') -eq 'Manual,Hybrid,Automation') -Message 'Ctrl+Alt+T cycle must be Manual, Hybrid, Automation'
Assert-True -Condition (-not [bool]$toggle[0].stopsExternalRunner) -Message 'Ctrl+Alt+T must not claim to stop the external runner'
Assert-ContainsText -Text $hotkeys -Needle 'TryEngineToggleHotkey(InputKey.T, "Ctrl+Alt+T"' -Label 'DevHotkeyHandler'
Assert-ContainsText -Text $hotkeys -Needle 'TryMovementAbortHotkey(InputKey.B, "Ctrl+Alt+B"' -Label 'DevHotkeyHandler'

Assert-True -Condition ($route -match '(?s)IsAutomationEnabled\(EngineToggleKey\.MapTrade\).*?TryStartFromRecursiveBranchState\(\)\)\s*\{.*?return;') -Message 'Automatic MapTrade tick must require Automation and return after successful start'
Assert-True -Condition ($route -match '(?s)if\s*\(!StartBranchRouteNow\(targetSettlement,\s*BranchRouteSource\)\)\s*\{\s*return false;\s*\}\s*_lastBranchAutoStartKey\s*=\s*key;') -Message 'Failed branch route starts must remain retryable'

$continuePath = @($catalog.launchPaths | Where-Object { $_.id -eq 'continue_native' })
Assert-True -Condition ($continuePath.Count -eq 1) -Message 'Native Continue launch path must have exactly one row'
Assert-True -Condition (-not [bool]$continuePath[0].exactSaveIdentityVerified) -Message 'Native Continue must not claim exact save identity'
Assert-ContainsText -Text ([string]$continuePath[0].warning) -Needle 'does not select or prove a named save' -Label 'Native Continue warning'

$incompleteGates = @(
    $catalog.engines |
        Where-Object { -not [bool]$_.authorityGateEffective } |
        ForEach-Object { [string]$_.engine }
)
Assert-True -Condition ((@($incompleteGates | Sort-Object) -join ',') -eq 'Cohesion,Companion,HorseMarket,Smithing') -Message 'Incomplete worker-engine gate catalog drift'

foreach ($needle in @(
        '.\ForgeContinue.cmd',
        'native **Continue** option',
        'does not select a save by file name',
        'Ctrl+Alt+T',
        'Ctrl+Alt+B',
        '.\Run-AutonomousGuildLoop.cmd',
        'waits for command acknowledgement, not terminal loop completion',
        'Sell execution remains a stub',
        'automated trading screen is not opened for the user',
        'No lower level may satisfy a higher level'
    )) {
    Assert-ContainsText -Text $plan -Needle $needle -Label 'Operator plan'
}

Assert-ContainsText -Text $assistWrapper -Needle 'scripts\run-autonomous-assist-session.ps1' -Label 'Autonomous assist CMD'

foreach ($requiredField in @('id', 'sprint', 'contextBanner', 'purpose', 'allowedScope', 'forbiddenScope', 'requiredArtifacts', 'validationCommands', 'terminalStates')) {
    Assert-True -Condition ($workflow.PSObject.Properties.Name -contains $requiredField) -Message "Workflow contract missing required field: $requiredField"
}

$sequences = @($workflow.orderedHandoffs | ForEach-Object { [int]$_.sequence })
Assert-True -Condition (($sequences -join ',') -eq '1,2,3,4,5,6,7') -Message 'Visible-trade ordered handoffs must be contiguous 1-7'
Assert-True -Condition (@($workflow.currentBlockers).Count -ge 6) -Message 'Visible-trade workflow must retain explicit current blockers'

$result = [ordered]@{
    schemaVersion = 'TbgOperatorControlSurfaceValidation.v1'
    verdict = 'PASS'
    catalog = '.tbg/operator/control-surface.json'
    workflow = '.tbg/workflows/continue-visible-trade-cycle.contract.json'
    plan = 'docs/operator/load-save-toggle-and-visible-trade-plan.md'
    engineCount = $catalogEngines.Count
    hotkeyCount = @($catalog.hotkeys).Count
    handoffCount = $sequences.Count
}

if ($Json) {
    $result | ConvertTo-Json -Depth 5
} else {
    Write-Host 'Operator control surface contract: PASS'
}
