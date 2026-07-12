param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-RequiredText {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $RepoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing required context-controller file: $RelativePath"
    }
    return Get-Content -LiteralPath $path -Raw
}

function Assert-Contains {
    param([string]$Text, [string]$Needle, [string]$Message)
    if ($Text -notlike "*$Needle*") { throw $Message }
}

function Assert-Before {
    param([string]$Text, [string]$First, [string]$Second, [string]$Message)
    $firstIndex = $Text.IndexOf($First, [System.StringComparison]::Ordinal)
    $secondIndex = $Text.IndexOf($Second, [System.StringComparison]::Ordinal)
    if ($firstIndex -lt 0 -or $secondIndex -lt 0 -or $firstIndex -ge $secondIndex) { throw $Message }
}

function Assert-PowerShellParses {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $RepoRoot $RelativePath
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        throw "$RelativePath parse errors: $($errors.Message -join '; ')"
    }
}

$runnerPath = 'scripts\run-autonomous-guild-loop-operator.ps1'
$diagnosticInvokerPath = 'scripts\invoke-collect-diagnostics.ps1'
Assert-PowerShellParses -RelativePath $runnerPath
Assert-PowerShellParses -RelativePath $diagnosticInvokerPath

$runner = Read-RequiredText -RelativePath $runnerPath
Assert-Contains $runner '[ValidateRange(3, 5)]' 'QuitGraceSec must remain bounded to three through five seconds'
Assert-Contains $runner 'Set-TbgRuntimeForeground' 'Context controller must foreground the bound runtime'
Assert-Contains $runner 'SetEngineToggleAutomation' 'Context controller must enter Automation mode'
Assert-Contains $runner 'ResumeCampaignClock' 'Context controller must resume campaign time'
Assert-Contains $runner 'RunAutonomousGuildLoopNow' 'Context controller must start the autonomous loop'
Assert-Contains $runner 'Test-GovernorStopRequested' 'Active Quit intent must interrupt the context watch'
Assert-Contains $runner 'USER_QUIT_REQUESTED' 'Startup quit choice must be machine-readable'
Assert-Contains $runner 'USER_QUIT_HONORED' 'ForgeStop quit context must be machine-readable'
Assert-Contains $runner 'FocusReacquireCount' 'Foreground correction must be measured'
Assert-Contains $runner 'pause_correction' 'Paused-map correction must be logged'
Assert-Contains $runner 'TbgAutonomousGuildLoopOperatorResult.v2' 'Operator result schema must expose context transitions'
Assert-Before $runner "Invoke-TbgContextCommand -Name 'SetEngineToggleAutomation'" "Invoke-TbgContextCommand -Name 'ResumeCampaignClock'" 'Automation mode must be set before clock resume'
Assert-Before $runner "Invoke-TbgContextCommand -Name 'ResumeCampaignClock'" 'Invoke-TbgContextCommand -Name $commandName' 'Clock resume must happen before guild-loop start'

$runCmd = Read-RequiredText -RelativePath 'Run-AutonomousGuildLoop.cmd'
Assert-Contains $runCmd '-QuitGraceSec 5' 'Root automation wrapper must select a five-second grace window'
Assert-Contains $runCmd 'if "%TBG_EXIT%"=="0" goto done' 'Successful automation must not pause the console over the game'

$stopCmd = Read-RequiredText -RelativePath 'ForgeStop.cmd'
Assert-Contains $stopCmd 'choice /C SFC /N /T 5 /D S' 'ForgeStop must default to soft stop after a five-second change-mind window'
Assert-Contains $stopCmd 'goto cancelled' 'ForgeStop must preserve a cancel path'

$controlPath = Join-Path $RepoRoot '.tbg\operator\control-surface.json'
$control = Get-Content -LiteralPath $controlPath -Raw | ConvertFrom-Json
$wrapper = @($control.wrappers | Where-Object { $_.command -eq '.\Run-AutonomousGuildLoop.cmd' })
if ($wrapper.Count -ne 1) { throw 'Operator control surface must contain exactly one autonomous guild-loop wrapper entry' }
if ([string]$wrapper[0].kind -ne 'operator_context_controller') { throw 'Autonomous guild-loop wrapper kind must be operator_context_controller' }
if ([int]$wrapper[0].quitGraceSec -lt 3 -or [int]$wrapper[0].quitGraceSec -gt 5) { throw 'Control-surface quitGraceSec must remain between three and five seconds' }
foreach ($command in @('SetEngineToggleAutomation', 'ResumeCampaignClock', 'RunAutonomousGuildLoopNow')) {
    if (@($wrapper[0].automationCommands) -notcontains $command) { throw "Control surface missing context command: $command" }
}

$diagnosticInvoker = Read-RequiredText -RelativePath $diagnosticInvokerPath
Assert-Contains $diagnosticInvoker 'Get-TbgFileSha256' 'Diagnostics must use the repo .NET SHA-256 helper when Get-FileHash is unavailable'
Assert-Contains $diagnosticInvoker 'function global:Get-FileHash' 'Diagnostics must provide a process-local compatibility surface'

Write-Host 'Autonomous guild-loop context contract: PASS'
