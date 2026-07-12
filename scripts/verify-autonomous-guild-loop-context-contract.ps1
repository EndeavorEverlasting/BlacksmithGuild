param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-RequiredText {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $RepoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing required context-controller file: $RelativePath" }
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
    if ($errors.Count -gt 0) { throw "$RelativePath parse errors: $($errors.Message -join '; ')" }
}

$timedRunnerPath = 'scripts\run-autonomous-guild-loop-operator.ps1'
$immediateRunnerPath = 'scripts\run-autonomous-guild-loop-immediate.ps1'
$diagnosticInvokerPath = 'scripts\invoke-collect-diagnostics.ps1'
foreach ($path in @($timedRunnerPath, $immediateRunnerPath, $diagnosticInvokerPath)) { Assert-PowerShellParses -RelativePath $path }

$immediate = Read-RequiredText -RelativePath $immediateRunnerPath
Assert-Contains $immediate 'quitGraceSec = 0' 'Immediate runner result must record zero startup grace'
Assert-Contains $immediate 'SetEngineToggleAutomation' 'Immediate runner must enter Automation mode'
Assert-Contains $immediate 'ResumeCampaignClock' 'Immediate runner must resume campaign time'
Assert-Contains $immediate 'RunAutonomousGuildLoopNow' 'Immediate runner must start the autonomous loop'
Assert-Contains $immediate 'Focus-Game' 'Immediate runner must foreground and maintain Bannerlord'
Assert-Before $immediate "Send-ContextCommand -Name 'SetEngineToggleAutomation'" "Send-ContextCommand -Name 'ResumeCampaignClock'" 'Automation mode must be set before clock resume'
Assert-Before $immediate "Send-ContextCommand -Name 'ResumeCampaignClock'" "Send-ContextCommand -Name 'RunAutonomousGuildLoopNow'" 'Clock resume must happen before guild-loop start'

$timed = Read-RequiredText -RelativePath $timedRunnerPath
Assert-Contains $timed '[ValidateRange(3, 5)]' 'Optional timed runner must remain bounded to three through five seconds'
Assert-Contains $timed 'Test-GovernorStopRequested' 'Timed runner must honor active Quit intent'

$runCmd = Read-RequiredText -RelativePath 'Run-AutonomousGuildLoop.cmd'
Assert-Contains $runCmd 'run-autonomous-guild-loop-immediate.ps1' 'No-argument click path must use the immediate controller'
Assert-Contains $runCmd 'if "%~1"=="3" goto timed' 'Three-second startup grace must remain optional'
Assert-Contains $runCmd 'if "%~1"=="4" goto timed' 'Four-second startup grace must remain optional'
Assert-Contains $runCmd 'if "%~1"=="5" goto timed' 'Five-second startup grace must remain optional'
Assert-Contains $runCmd '-QuitGraceSec %~1' 'Optional grace value must be forwarded explicitly'
Assert-Contains $runCmd 'if "%TBG_EXIT%"=="0" goto done' 'Successful automation must not pause the console over the game'

$hotkey = Read-RequiredText -RelativePath 'src\BlacksmithGuild\DevTools\DevHotkeyHandler.cs'
Assert-Contains $hotkey 'OperatorAutomationContextController.HandleGlobalModeChanged(label)' 'Ctrl+Alt+T must hand off to the practical context controller'

$runtimeController = Read-RequiredText -RelativePath 'src\BlacksmithGuild\DevTools\OperatorAutomationContextController.cs'
Assert-Contains $runtimeController 'EngineToggleMode.Automation' 'Runtime controller must react to Automation mode'
Assert-Contains $runtimeController 'ResumeCampaignClockCommand' 'Runtime controller must resume campaign time after the hotkey'
Assert-Contains $runtimeController 'RunAutonomousGuildLoopNowCommand' 'Runtime controller must start or preserve the bounded guild loop'
Assert-Contains $runtimeController 'BlacksmithGuild_OperatorAutomationContext.json' 'Runtime controller must write practical follow-through evidence'
Assert-Contains $runtimeController 'loopAlreadyRunning' 'Runtime controller must be idempotent when the loop is already active'

$stopCmd = Read-RequiredText -RelativePath 'ForgeStop.cmd'
Assert-Contains $stopCmd 'choice /C SFC /N /T 5 /D S' 'ForgeStop must default to soft stop after a five-second change-mind window'
Assert-Contains $stopCmd 'goto cancelled' 'ForgeStop must preserve a cancel path'

$diagnosticInvoker = Read-RequiredText -RelativePath $diagnosticInvokerPath
Assert-Contains $diagnosticInvoker 'Get-TbgFileSha256' 'Diagnostics must use the repo .NET SHA-256 helper when Get-FileHash is unavailable'
Assert-Contains $diagnosticInvoker 'function global:Get-FileHash' 'Diagnostics must provide a process-local compatibility surface'

Write-Host 'Autonomous guild-loop context contract: PASS (immediate CMD + optional grace + hotkey follow-through)'
