# Focused offline regression for exact disposable-save startup and launcher intent separation.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

function Assert-Contains {
    param(
        [string]$Path,
        [string]$Needle,
        [string]$Reason
    )
    $text = Get-Content -LiteralPath (Join-Path $repoRoot $Path) -Raw -Encoding UTF8
    if (-not $text.Contains($Needle)) {
        throw "$Path missing '$Needle': $Reason"
    }
}

$autoLoaderPath = 'src\BlacksmithGuild\DevTools\QuickStart\DevSaveAutoLoader.cs'
$mainMenuPath = 'src\BlacksmithGuild\DevTools\QuickStart\MainMenuAutoLauncher.cs'
Assert-Contains $autoLoaderPath 'using SandBox;' 'the v1.4.6 SandBox game manager must be compile-bound'
Assert-Contains $autoLoaderPath 'MBSaveLoad.OnStartGame(loadResult);' 'vanilla save startup must initialize MBSaveLoad'
Assert-Contains $autoLoaderPath 'MBGameManager.StartNewGame(new SandBoxGameManager(loadResult));' 'loaded data must start a campaign'
Assert-Contains $autoLoaderPath '_exactSaveStartInProgress = true;' 'the StartNewGame Harmony prefix needs a recursion guard'
Assert-Contains $autoLoaderPath 'if (_exactSaveStartInProgress)' 'the exact save start must pass through the prefix once'
Assert-Contains $mainMenuPath 'if (DevToolsConfig.AutoLoadDevSave)' 'exact-save mode must be explicit'
Assert-Contains $mainMenuPath 'vanilla Continue is forbidden' 'an exact-load failure must fail closed'

$mainMenuText = Get-Content -LiteralPath (Join-Path $repoRoot $mainMenuPath) -Raw -Encoding UTF8
$exactBranchPattern = '(?s)if \(DevToolsConfig\.AutoLoadDevSave\).*?else if \(TryExecuteFirstAvailable\(ContinueOptionIds'
if ($mainMenuText -notmatch $exactBranchPattern) {
    throw 'Vanilla Continue must be reachable only as the else branch when exact dev-save loading is disabled.'
}

. (Join-Path $PSScriptRoot 'exact-save-launch-intent.ps1')
if ((Resolve-TbgLauncherSelectionIntent -InGameLaunchIntent continue -ExactSave) -ne 'play') {
    throw 'Exact in-game continue must select launcher PLAY.'
}
if ((Resolve-TbgLauncherSelectionIntent -InGameLaunchIntent continue) -ne 'continue') {
    throw 'Non-exact launch intent must remain unchanged.'
}
$invalidExactIntentBlocked = $false
try {
    Resolve-TbgLauncherSelectionIntent -InGameLaunchIntent play -ExactSave | Out-Null
}
catch {
    $invalidExactIntentBlocked = $true
}
if (-not $invalidExactIntentBlocked) {
    throw 'Exact-save launch must reject an in-game intent other than continue.'
}

foreach ($sourceCheck in @(
    @{ Path = 'scripts\install-mod.ps1'; Needle = '-InGameLaunchIntent $LaunchIntent -ExactSave:($LaunchIntent -eq ''continue'')' },
    @{ Path = 'scripts\install-mod.ps1'; Needle = '-LaunchIntent $launcherSelectionIntent' },
    @{ Path = 'scripts\run-autonomous-assist-session.ps1'; Needle = '-LaunchIntent $launcherSelectionIntent' },
    @{ Path = 'scripts\run-autonomous-assist-session.ps1'; Needle = 'write-launch-intent.ps1' },
    @{ Path = 'scripts\run-pr11-town-travel-launch-attach-execute.ps1'; Needle = '-LaunchIntent $launcherSelectionIntent' },
    @{ Path = 'ForgeContinue.cmd'; Needle = 'write-launch-intent.ps1'' -LaunchIntent continue' },
    @{ Path = 'ForgeContinue.cmd'; Needle = 'launcher-frozen-context-nav.ps1'' -LaunchIntent play' },
    @{ Path = 'docs\dev-disposable-save.md'; Needle = '| **`ForgeContinue.cmd`** | PLAY | Exact approved dev-save Continue |' },
    @{ Path = 'docs\dev-disposable-save.md'; Needle = 'newer-save/version error remains operator-visible' }
)) {
    Assert-Contains $sourceCheck.Path $sourceCheck.Needle 'exact-save workflow must separate launcher selection from in-game intent'
}

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tmpRoot = [IO.Path]::GetFullPath(
    (Join-Path $tempBase "tbg-exact-save-pin-$PID-$([Guid]::NewGuid().ToString('N'))")
)
if (-not $tmpRoot.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Resolved test path escaped the temporary root: $tmpRoot"
}
$nativeRoot = Join-Path $tmpRoot 'Native'
New-Item -ItemType Directory -Force -Path $nativeRoot | Out-Null
try {
    $logicalPath = Join-Path $tmpRoot 'BlacksmithGuildDevStart.sav'
    $nativePath = Join-Path $nativeRoot 'BlacksmithGuild_DevStart.sav'
    $autosavePath = Join-Path $tmpRoot 'saveauto1.sav'
    [IO.File]::WriteAllBytes($logicalPath, [byte[]](0..255))
    Copy-Item -LiteralPath $logicalPath -Destination $nativePath
    [IO.File]::WriteAllBytes($autosavePath, [byte[]](255..0))
    $oldTime = (Get-Date).AddDays(-10)
    (Get-Item -LiteralPath $logicalPath).LastWriteTime = $oldTime
    (Get-Item -LiteralPath $nativePath).LastWriteTime = $oldTime
    (Get-Item -LiteralPath $autosavePath).LastWriteTime = (Get-Date).AddMinutes(5)
    $autosaveBefore = Get-Item -LiteralPath $autosavePath
    $autosaveBeforeTime = $autosaveBefore.LastWriteTimeUtc
    $autosaveBeforeHash = (Get-FileHash -LiteralPath $autosavePath -Algorithm SHA256).Hash

    $pinResult = & (Join-Path $PSScriptRoot 'pin-dev-save.ps1') -GameSavesRoot $tmpRoot -PassThru
    if (-not $pinResult -or -not $pinResult.byteIdentical) {
        throw 'Approved save pair pin did not return byte-identity proof.'
    }
    if ($pinResult.sha256 -ne (Get-FileHash -LiteralPath $logicalPath -Algorithm SHA256).Hash) {
        throw 'Approved save pin returned the wrong hash.'
    }
    if ((Get-Item -LiteralPath $logicalPath).LastWriteTimeUtc -le $oldTime.ToUniversalTime() -or
        (Get-Item -LiteralPath $nativePath).LastWriteTimeUtc -le $oldTime.ToUniversalTime()) {
        throw 'Both approved save paths must be pinned.'
    }
    if ((Get-Item -LiteralPath $autosavePath).LastWriteTimeUtc -ne $autosaveBeforeTime -or
        (Get-FileHash -LiteralPath $autosavePath -Algorithm SHA256).Hash -ne $autosaveBeforeHash) {
        throw 'Pinning the approved pair must not touch an arbitrary autosave.'
    }

    [IO.File]::WriteAllBytes($nativePath, [byte[]](1..32))
    $mismatchBlocked = $false
    try {
        & (Join-Path $PSScriptRoot 'pin-dev-save.ps1') -GameSavesRoot $tmpRoot | Out-Null
    }
    catch {
        $mismatchBlocked = ($_.Exception.Message -match 'not byte-identical')
    }
    if (-not $mismatchBlocked) {
        throw 'A non-identical approved save pair must fail closed.'
    }
}
finally {
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
}

$mismatchService = Get-Content -LiteralPath (
    Join-Path $repoRoot 'src\BlacksmithGuild\DevTools\QuickStart\ModuleMismatchAutoConfirmService.cs'
) -Raw -Encoding UTF8
if ($mismatchService -match 'newer save|newer version|save version') {
    throw 'Newer-save/version errors must remain operator-visible and must not be auto-dismissed.'
}

Write-Host 'Exact dev-save launch contract: PASS'
