# Offline regression: PR #11 PID/window classifier without launching the game.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'pr11-process-window-classifier.ps1')

function New-Pr11FixtureProcess {
    param(
        [int]$ProcessId,
        [string]$Name,
        [string]$Title = '',
        [string]$Path = '',
        [int64]$Hwnd = 0
    )
    return [pscustomobject][ordered]@{
        pid = $ProcessId; processName = $Name; parentPid = 1; startTime = (Get-Date).ToUniversalTime().ToString('o')
        mainWindowHandle = $Hwnd; mainWindowTitle = $Title; executablePath = $Path
        commandLine = $null; windowRectangle = $null; visible = ($Hwnd -ne 0); uiaProcessId = $null
    }
}

# PID delta detects new process
$s1 = [ordered]@{ label = 'S1'; processes = @(New-Pr11FixtureProcess -ProcessId 100 -Name 'dotnet' -Path 'C:\dotnet\dotnet.exe') }
$s2 = [ordered]@{ label = 'S2'; processes = @(
    (New-Pr11FixtureProcess -ProcessId 100 -Name 'dotnet' -Path 'C:\dotnet\dotnet.exe'),
    (New-Pr11FixtureProcess -ProcessId 200 -Name 'Bannerlord' -Title 'Bannerlord' -Path 'C:\Steam\Mount & Blade II Bannerlord\bin\Win64_Shipping_Client\Bannerlord.exe' -Hwnd 999)
) }
$delta = Compare-Pr11ProcessSnapshots -BaselineSnapshot $s1 -AfterSnapshot $s2
if (@($delta.newPids).Count -ne 1 -or [int]$delta.newPids[0].pid -ne 200) {
    throw 'PID delta must detect new Bannerlord process'
}

# Forge noise does not pollute launch delta when baseline is S1
$forgeOnly = Compare-Pr11ProcessSnapshots -BaselineSnapshot $s1 -AfterSnapshot $s1
if (@($forgeOnly.newPids).Count -ne 0) {
    throw 'S1 vs S1 must not report new PIDs'
}

# metadata match beats title-only match
$bannerlordRoot = 'C:\Steam\Mount & Blade II Bannerlord'
$meta = Get-Pr11WindowCandidateScore -ProcessRecord (New-Pr11FixtureProcess -ProcessId 201 -Name 'Bannerlord' `
    -Title 'Some unrelated title' -Path "$bannerlordRoot\bin\Win64_Shipping_Client\Bannerlord.exe" -Hwnd 1001) `
    -BannerlordRoot $bannerlordRoot -IsNewAfterBaseline $true
$titleOnly = Get-Pr11WindowCandidateScore -ProcessRecord (New-Pr11FixtureProcess -ProcessId 202 -Name 'notepad' `
    -Title 'Mount & Blade II Bannerlord' -Path 'C:\Windows\System32\notepad.exe' -Hwnd 1002) `
    -BannerlordRoot $bannerlordRoot -IsNewAfterBaseline $true
if ($meta.score -le $titleOnly.score) {
    throw 'metadata/path match must beat title-only match'
}

# confidence below threshold causes safe stop
$low = @($titleOnly)
$clickLow = Test-Pr11ClickAllowed -Candidates $low
if ($clickLow.allowed) { throw 'low confidence must not allow click' }
if ($clickLow.reason -ne 'below_confidence_threshold') { throw "expected below_confidence_threshold got $($clickLow.reason)" }

# multiple tied candidates -> no click
$tieA = Get-Pr11WindowCandidateScore -ProcessRecord (New-Pr11FixtureProcess -ProcessId 301 -Name 'Bannerlord' `
    -Path "$bannerlordRoot\bin\Win64_Shipping_Client\Bannerlord.exe" -Hwnd 2001) -BannerlordRoot $bannerlordRoot -IsNewAfterBaseline $true -UiaPlayVisible $true
$tieB = Get-Pr11WindowCandidateScore -ProcessRecord (New-Pr11FixtureProcess -ProcessId 302 -Name 'Bannerlord' `
    -Path "$bannerlordRoot\bin\Win64_Shipping_Client\Bannerlord.exe" -Hwnd 2002) -BannerlordRoot $bannerlordRoot -IsNewAfterBaseline $true -UiaPlayVisible $true
$clickTie = Test-Pr11ClickAllowed -Candidates @($tieA, $tieB)
if ($clickTie.allowed -or $clickTie.reason -ne 'multiple_tied_candidates') {
    throw 'tied high-confidence candidates must block click'
}

# in_game_attach_ready classification
$ready = [pscustomobject]@{
    parseOk = $true; canPollFileInbox = $true; inGameAssistReady = $true; canAcceptAssistiveCommand = $true
    campaignReady = $true; readinessSurface = 'settlement_menu'
}
$cls = Invoke-Pr11UiStateClassification -BannerlordRoot $bannerlordRoot -Candidates @($meta) -Readiness $ready
if ($cls.state -ne 'settlement_menu' -or $cls.nextAction -ne 'run_assistive_cert_commands') {
    throw "attach-ready settlement must classify settlement_menu got $($cls.state)"
}

# empty/null evidence snapshots must serialize instead of crashing the runner
$emptyJsonPath = Join-Path $env:TEMP "pr11-empty-window-candidates-$PID.json"
Save-Pr11JsonArtifact -Object @() -Path $emptyJsonPath | Out-Null
if ((Get-Content -LiteralPath $emptyJsonPath -Raw).Trim() -ne '[]') {
    throw 'empty window candidates must serialize as []'
}
Remove-Item -LiteralPath $emptyJsonPath -Force

$nullJsonPath = Join-Path $env:TEMP "pr11-null-artifact-$PID.json"
Save-Pr11JsonArtifact -Object $null -Path $nullJsonPath | Out-Null
if ((Get-Content -LiteralPath $nullJsonPath -Raw).Trim() -ne 'null') {
    throw 'null artifact snapshots must serialize as null'
}
Remove-Item -LiteralPath $nullJsonPath -Force

# existing advisory fixture unaffected — probe-only execution JSON absent still advisory path
. (Join-Path $PSScriptRoot 'pr11-assistive-execute-contract.ps1')
$advisoryFail = Test-Pr11AssistiveTravelExecutePass -ExecutionJson $null
if ($advisoryFail.failureClass -ne 'evidence_missing') {
    throw 'missing execution json must fail evidence_missing without breaking advisory tests'
}

Write-Host 'PASS offline PR11 process/window classifier regression'
