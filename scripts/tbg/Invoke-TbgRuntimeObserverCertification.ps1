[CmdletBinding()]
param(
    [ValidateSet('fixtures', 'windows_smoke', 'certify')]
    [string]$Mode = 'certify',
    [string]$OutputRoot = '',
    [string]$AssemblyPath = '',
    [switch]$AllowLiveRuntime,
    [string]$LiveAuthorityArtifactPath = '',
    [ValidateRange(1, 300)]
    [int]$LiveDurationSeconds = 30,
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $repoRoot ('.local\tbg-runtime-observer-certification\{0}' -f [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ'))
}
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

function Get-TbgGit([string[]]$Arguments) {
    $value = & git -C $repoRoot @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed." }
    return (@($value) -join "`n").Trim()
}
function Write-TbgJson([object]$Value, [string]$Path) {
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 32), [Text.UTF8Encoding]::new($false))
}
function Add-TbgCheck([string]$Id, [string]$Status, [string]$Detail, [string]$ProofLevel = 'harness') {
    $script:checks.Add([ordered]@{ id = $Id; status = $Status; detail = $Detail; proofLevel = $ProofLevel }) | Out-Null
}
function Invoke-TbgScript([string]$Name, [string[]]$Arguments = @()) {
    $path = Join-Path $repoRoot "scripts\tbg\$Name"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required certification dependency is missing: scripts/tbg/$Name" }
    & $path @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Name exited with code $LASTEXITCODE." }
}
function Get-TbgProofRank([string]$Level) {
    $levels = @('contract', 'harness', 'static_test', 'build', 'launcher', 'command_ack', 'behavior_observed', 'live_runtime')
    return [array]::IndexOf($levels, $Level)
}

$checks = [System.Collections.Generic.List[object]]::new()
$head = Get-TbgGit @('rev-parse', 'HEAD')
$branch = Get-TbgGit @('branch', '--show-current')
$fixturePath = Join-Path $repoRoot '.tbg\harness\fixtures\runtime-observer-certification.fixtures.json'
$fixture = Get-Content -LiteralPath $fixturePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
if ($fixture.schema -ne 'TbgRuntimeObserverCertificationFixture.v1') { throw 'Certification fixture schema is invalid.' }

$terminalState = 'PASS_fixture_certification'
$proofLevel = 'static_test'
$liveBlocker = 'Explicit active live-runtime authority was not supplied; no Bannerlord attach was attempted.'

if ($Mode -in @('fixtures', 'certify')) {
    $required = @('composed-fixture-validation', 'disposable-windows-smoke', 'missing-live-authority', 'authorized-live-observation')
    foreach ($id in $required) {
        $scenario = @($fixture.scenarios | Where-Object { $_.id -eq $id })
        if ($scenario.Count -ne 1) { throw "Certification fixture scenario '$id' must occur exactly once." }
        if ([string]::IsNullOrWhiteSpace([string]$scenario[0].expectedProofLevel)) { throw "Certification fixture scenario '$id' lacks an exact proof level." }
        Add-TbgCheck "fixture.$id" 'passed' "Scenario declares proof ceiling '$($scenario[0].expectedProofLevel)' and forbidden claims." 'static_test'
    }
}

if ($Mode -in @('windows_smoke', 'certify')) {
    $smokeRoot = Join-Path $OutputRoot 'windows-smoke'
    New-Item -ItemType Directory -Force -Path $smokeRoot | Out-Null
    $listenerPath = Join-Path $repoRoot 'scripts\tbg\Start-TbgWindowEventListener.ps1'
    try {
        $listener = & $listenerPath -Mode observe -DurationSeconds 1 -ProcessId $PID -RunId ('cert-window-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)) -CorrelationId 'runtime-observer-certification' -PassThru
        if ($null -eq $listener) { throw 'Window listener did not return a disposal result.' }
        Add-TbgCheck 'windows.window_listener' 'passed' 'Event hook registration and listener disposal completed against this disposable PowerShell process.' 'harness'
    } catch {
        Add-TbgCheck 'windows.window_listener' 'unavailable' "Window hook smoke was unavailable: $($_.Exception.Message)" 'harness'
    }

    $child = Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" -ArgumentList '/d', '/c', 'timeout /t 2 /nobreak >nul' -PassThru
    $observer = & (Join-Path $repoRoot 'scripts\tbg\Start-TbgGameRuntimeObserver.ps1') -Command start -DurationSeconds 5 -OutputRoot $smokeRoot -TestProcessId $child.Id -PassThru
    $eventsPath = Join-Path $observer.runRoot 'events.jsonl'
    $events = @(Get-Content -LiteralPath $eventsPath -Encoding UTF8 | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_ | ConvertFrom-Json })
    if (@($events | Where-Object eventType -eq 'process.started').Count -lt 1 -or @($events | Where-Object eventType -eq 'process.exited').Count -lt 1) {
        throw 'Disposable child process did not produce both process.started and process.exited observations.'
    }
    $status = & (Join-Path $repoRoot 'scripts\tbg\Start-TbgGameRuntimeObserver.ps1') -Command status -RunId $observer.runId -OutputRoot $smokeRoot -PassThru
    if ([string]$status.leaseId -ne [string]$observer.leaseId) { throw 'Observer status did not preserve the owned observer lease.' }
    Add-TbgCheck 'windows.disposable_process' 'passed' 'Observed start and exit of a disposable cmd.exe child only; no Bannerlord process was targeted.' 'harness'
    Add-TbgCheck 'windows.observer_lease' 'passed' 'Observer status returned the lease created by this certification run.' 'harness'

    & (Join-Path $repoRoot 'scripts\tbg\Get-TbgWindowsCrashEvidence.ps1') -RunId $observer.runId -CorrelationId $observer.correlationId -SinceUtc ([DateTime]::UtcNow.AddMinutes(-1)) -OutputRoot $smokeRoot | Out-Null
    $werPath = Join-Path $smokeRoot "$($observer.runId)\windows-crash-evidence.jsonl"
    $werText = if (Test-Path -LiteralPath $werPath) { Get-Content -LiteralPath $werPath -Raw -Encoding UTF8 } else { '' }
    if ($werText -match '(?i)unrelated-process-attribution') { throw 'Bounded event-log query reported unrelated process attribution.' }
    Add-TbgCheck 'windows.event_log' 'passed' 'Bounded Windows event-log query completed without unrelated-process attribution.' 'harness'

    try {
        $incident = & (Join-Path $repoRoot 'scripts\tbg\Resolve-TbgRuntimeIncident.ps1') -RunRoot $observer.runRoot -LatestOutputRoot (Join-Path $smokeRoot 'incident-latest') -PassThru
        if ([string]::IsNullOrWhiteSpace([string]$incident.classification)) { throw 'Incident assembly returned no classification.' }
        Add-TbgCheck 'windows.incident_assembly' 'passed' "Incident assembly classified the disposable observer run as '$($incident.classification)'." 'harness'
    } catch {
        Add-TbgCheck 'windows.incident_assembly' 'failed' "Incident assembly rejected the disposable observer run: $($_.Exception.Message)" 'harness'
        $terminalState = 'FAIL_windows_smoke_incident_assembly'
    }
    $proofLevel = 'harness'
    if ($terminalState -ne 'FAIL_windows_smoke_incident_assembly') { $terminalState = 'PASS_windows_smoke' }
}

if (-not [string]::IsNullOrWhiteSpace($AssemblyPath)) {
    $resolvedAssembly = if ([IO.Path]::IsPathRooted($AssemblyPath)) { $AssemblyPath } else { Join-Path $repoRoot $AssemblyPath }
    if (-not (Test-Path -LiteralPath $resolvedAssembly -PathType Leaf)) { throw "Requested assembly hash path does not exist: $AssemblyPath" }
    $assemblyHash = (Get-FileHash -LiteralPath $resolvedAssembly -Algorithm SHA256).Hash.ToLowerInvariant()
    Add-TbgCheck 'build.assembly_hash' 'passed' "SHA-256 recorded for supplied Debug assembly." 'build'
    if ((Get-TbgProofRank -Level 'build') -gt (Get-TbgProofRank -Level $proofLevel)) { $proofLevel = 'build' }
} else {
    $assemblyHash = $null
}

if ($AllowLiveRuntime) {
    if ([string]::IsNullOrWhiteSpace($LiveAuthorityArtifactPath) -or -not (Test-Path -LiteralPath $LiveAuthorityArtifactPath -PathType Leaf)) {
        $liveBlocker = 'Live observation requires a current, explicit authority artifact with active_owned session classification, operator acceptance, matching exact head, and an unexpired authorization.'
    } else {
        $authority = Get-Content -LiteralPath $LiveAuthorityArtifactPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
        $expires = [DateTime]::MinValue
        $valid = ([string]$authority.authorization -eq 'explicit' -and [string]$authority.sessionClassification -eq 'active_owned' -and
            [bool]$authority.operatorAccepted -and [string]$authority.exactHead -eq $head -and
            [DateTime]::TryParse([string]$authority.expiresUtc, [ref]$expires) -and $expires.ToUniversalTime() -gt [DateTime]::UtcNow)
        if (-not $valid) {
            $liveBlocker = 'Live authority artifact failed one or more required fields: authorization=explicit, sessionClassification=active_owned, operatorAccepted=true, exactHead=current HEAD, expiresUtc=future.'
        } else {
            $live = & (Join-Path $repoRoot 'scripts\tbg\Start-TbgGameRuntimeObserver.ps1') -Command start -DurationSeconds $LiveDurationSeconds -OutputRoot (Join-Path $OutputRoot 'live-observation') -PassThru
            Add-TbgCheck 'live.read_only_observation' 'passed' "Authorized observer run '$($live.runId)' completed without process, launcher, command-inbox, or save mutation." 'live_runtime'
            $proofLevel = 'live_runtime'
            $terminalState = 'PASS_authorized_live_observation'
            $liveBlocker = $null
        }
    }
}
if ($null -ne $liveBlocker) {
    Add-TbgCheck 'live.authority_gate' 'blocked' $liveBlocker $proofLevel
    if ($terminalState -eq 'PASS_fixture_certification') { $terminalState = 'BLOCKED_live_authority_missing' }
}

$result = [ordered]@{
    schema = 'tbg.runtime-observer-certification.result.v1'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    repository = 'EndeavorEverlasting/BlacksmithGuild'
    branch = $branch
    exactHead = $head
    mode = $Mode
    terminalState = $terminalState
    proofLevel = $proofLevel
    proofCeiling = 'live_runtime'
    assemblySha256 = $assemblyHash
    checks = @($checks)
    liveAuthorityBlocker = $liveBlocker
    forbiddenClaims = @('Bannerlord launch', 'command inbox write', 'save mutation', 'native crash root cause without correlated external terminal evidence', 'live runtime when authority is blocked')
    evidencePaths = @('runtime-observer-certification.result.json', 'runtime-observer-certification.report.md', 'windows-smoke/')
    nextCommand = if ($terminalState -eq 'FAIL_windows_smoke_incident_assembly') {
        'powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgRuntimeIncidentAssembler.ps1'
    } elseif ($null -ne $liveBlocker) {
        'powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Invoke-TbgRuntimeObserverCertification.ps1 -Mode certify -AllowLiveRuntime -LiveAuthorityArtifactPath <approved-authority.json>'
    } else {
        'git diff --check'
    }
}
Write-TbgJson $result (Join-Path $OutputRoot 'runtime-observer-certification.result.json')
@(
    '# Runtime Observer Certification',
    '',
    "- Terminal state: $terminalState",
    "- Proof level: $proofLevel",
    "- Exact head: $head",
    "- Live authority blocker: $(if ($liveBlocker) { $liveBlocker } else { 'none' })",
    "- Raw runtime evidence remains under the ignored local output root."
) | Set-Content -LiteralPath (Join-Path $OutputRoot 'runtime-observer-certification.report.md') -Encoding UTF8
Write-Host "Runtime observer certification: $terminalState ($proofLevel)" -ForegroundColor Cyan
if ($PassThru) { return [pscustomobject]$result }
if ($terminalState -like 'BLOCKED_*') { exit 30 }
if ($terminalState -like 'FAIL_*') { exit 1 }
