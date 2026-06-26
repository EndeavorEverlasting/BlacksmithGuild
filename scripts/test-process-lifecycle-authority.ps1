# Offline regression: process lifecycle authority — session modes, termination classification, provenance.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'process-lifecycle-authority.ps1')

$bannerlordRoot = 'C:\Temp\forge-lifecycle-test'
$tmpLifecycle = Join-Path $env:TEMP "lifecycle-test-$PID"
if (Test-Path -LiteralPath $tmpLifecycle) { Remove-Item -LiteralPath $tmpLifecycle -Recurse -Force }
New-Item -ItemType Directory -Force -Path $tmpLifecycle | Out-Null

function Mock-LifecycleBannerlordRoot { return $tmpLifecycle }

# Forge.cmd passes FreshTestLaunch
$forgeCmd = Get-Content -LiteralPath (Join-Path $repoRoot 'Forge.cmd') -Raw
if ($forgeCmd -notmatch 'SessionAuthorityMode FreshTestLaunch') {
    throw 'Forge.cmd must pass -SessionAuthorityMode FreshTestLaunch'
}

# raw forge.ps1 -Launch keeps optional mode (no default FreshTestLaunch in file text for Forge.cmd only)
$forgePs1 = Get-Content -LiteralPath (Join-Path $repoRoot 'forge.ps1') -Raw
if ($forgePs1 -notmatch 'SessionAuthorityMode') { throw 'forge.ps1 missing SessionAuthorityMode param' }
if ($forgePs1 -match 'FreshTestLaunch.*default') { throw 'forge.ps1 must not default FreshTestLaunch on -Launch' }

# AttachOnly refuses close
$script:TbgProcessLifecycle = $null
Initialize-TbgProcessLifecycle -RunId 'test-attach' -BannerlordRoot $tmpLifecycle -SessionAuthorityMode AttachOnly | Out-Null
$fakeProc = [System.Diagnostics.Process]::GetCurrentProcess()
try {
    Request-TbgIntentionalTermination -Process $fakeProc -Reason 'test' -BannerlordRoot $tmpLifecycle -SessionAuthorityMode AttachOnly
    throw 'AttachOnly must refuse termination'
} catch {
    if ($_.Exception.Message -notmatch 'forbids terminating') { throw $_ }
}

# FreshTestLaunch permits marker before termination entry
$script:TbgProcessLifecycle = $null
Initialize-TbgProcessLifecycle -RunId 'test-fresh' -BannerlordRoot $tmpLifecycle -SessionAuthorityMode FreshTestLaunch | Out-Null
$script:TbgProcessLifecycle.preExistingProcesses = @(@{ pid = 99999; processName = 'Bannerlord' })
$script:TbgProcessLifecycle.intentionalTerminations = @(@{
    pid = 99999; processName = 'Bannerlord'; reason = 'test'; requestedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    method = 'CloseMainWindow'; forceKilled = $false; observedExitAtUtc = (Get-Date).ToUniversalTime().ToString('o')
})
Save-TbgProcessLifecycle -BannerlordRoot $tmpLifecycle | Out-Null
$lcPath = Get-TbgProcessLifecycleJsonPath -BannerlordRoot $tmpLifecycle
if (-not (Test-Path -LiteralPath $lcPath)) { throw 'lifecycle json must be written' }
$parsed = Get-Content -LiteralPath $lcPath -Raw | ConvertFrom-Json
if (@($parsed.intentionalTerminations).Count -lt 1) { throw 'intentionalTerminations missing' }

# intentional PID exit classification
$script:TbgProcessLifecycle = $parsed
$termForge = Invoke-TbgTerminationClassification -BannerlordRoot $tmpLifecycle -CyclePhase 'loading' `
    -Detection ([pscustomobject]@{ gameProcessRunning = $false })
if ($termForge.classification -ne 'intentional_forge_stop') {
    throw "expected intentional_forge_stop got $($termForge.classification)"
}

# owned cleanup
$script:TbgProcessLifecycle.sessionAuthorityMode = 'RunnerCleanup'
$termCleanup = Invoke-TbgTerminationClassification -BannerlordRoot $tmpLifecycle -CyclePhase 'cert' `
    -Detection ([pscustomobject]@{ gameProcessRunning = $false })
if ($termCleanup.classification -ne 'intentional_runner_cleanup') {
    throw "expected intentional_runner_cleanup got $($termCleanup.classification)"
}

# loading death without marker
$script:TbgProcessLifecycle = $null
Initialize-TbgProcessLifecycle -RunId 'test-load' -BannerlordRoot $tmpLifecycle -SessionAuthorityMode UserSession | Out-Null
$termLoad = Invoke-TbgTerminationClassification -BannerlordRoot $tmpLifecycle -CyclePhase 'loading' `
    -Detection ([pscustomobject]@{ gameProcessRunning = $false })
if ($termLoad.classification -ne 'process_disappeared_during_loading') {
    throw "expected process_disappeared_during_loading got $($termLoad.classification)"
}

# cert death without marker
$termCert = Invoke-TbgTerminationClassification -BannerlordRoot $tmpLifecycle -CyclePhase 'cert' `
    -Detection ([pscustomobject]@{ gameProcessRunning = $false })
if ($termCert.classification -ne 'process_disappeared_during_cert') {
    throw "expected process_disappeared_during_cert got $($termCert.classification)"
}

# launch selection actors
$script:TbgProcessLifecycle = $null
Initialize-TbgProcessLifecycle -RunId 'test-ls' -BannerlordRoot $tmpLifecycle -SessionAuthorityMode FreshTestLaunch | Out-Null
Write-TbgLaunchSelection -BannerlordRoot $tmpLifecycle -Actor 'script' -Intent 'continue' -ButtonText 'Continue' `
    -Method 'uia' -Confidence 92 -ProcessId 1234 -Hwnd 5678
$ls = (Read-TbgProcessLifecycle -BannerlordRoot $tmpLifecycle).launchSelection
if ($ls.actor -ne 'script' -or $ls.method -ne 'uia') { throw 'script UIA launchSelection failed' }

Write-TbgLaunchSelection -BannerlordRoot $tmpLifecycle -Actor 'user_or_external' -Intent 'play' -ButtonText 'Play' `
    -Method 'user_handoff' -Confidence 0
$lsUser = (Read-TbgProcessLifecycle -BannerlordRoot $tmpLifecycle).launchSelection
if ($lsUser.actor -ne 'user_or_external') { throw 'user_or_external launchSelection failed' }

# cancel file
$cancelPath = Join-Path $tmpLifecycle 'BlacksmithGuild_CancelRun.json'
@{ requestedAtUtc = (Get-Date).ToUniversalTime().ToString('o'); requestedBy = 'test'; reason = 'offline' } |
    ConvertTo-Json | Set-Content -LiteralPath $cancelPath -Encoding UTF8
if (-not (Test-TbgCancelRequested -BannerlordRoot $tmpLifecycle)) { throw 'cancel file must be detected' }
$termCancel = Invoke-TbgTerminationClassification -BannerlordRoot $tmpLifecycle -CyclePhase 'cert'
if ($termCancel.classification -ne 'cancelled') { throw 'cancel must classify cancelled' }

# install-mod / check paths never close (string contract)
$installText = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'install-mod.ps1') -Raw
if ($installText -notmatch 'FreshTestLaunch') { throw 'install-mod missing FreshTestLaunch hook' }
$attachRunner = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'run-town-to-town-trade-assist-cert.ps1') -Raw
if ($attachRunner -notmatch 'AttachOnly') { throw 'attach cert should reference attach-only semantics' }

Remove-Item -LiteralPath $tmpLifecycle -Recurse -Force -ErrorAction SilentlyContinue
Write-Host 'PASS offline process lifecycle authority regression'
