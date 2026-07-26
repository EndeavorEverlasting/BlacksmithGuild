[CmdletBinding()]
param(
    [ValidateSet('inventory','candidate','fixture')][string]$Mode = 'inventory',
    [string]$RepoRoot = '',
    [string]$CandidateGameRoot = '',
    [string]$CandidateGameVersion = '',
    [string]$BaselineGameVersion = '',
    [string]$RegistryPath = '.tbg/state/version-upgrade-impact.registry.json',
    [string]$FixturePath = '',
    [string]$FixtureCaseId = '',
    [string]$OutputDirectory = 'artifacts/latest/version-upgrade-impact',
    [switch]$NoBuild,
    [switch]$NoExit,
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}
$RepoRoot = [IO.Path]::GetFullPath($RepoRoot)

function Resolve-TbgRepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([IO.Path]::IsPathRooted($Path)) { return $Path }
    return Join-Path $RepoRoot ($Path -replace '/', [IO.Path]::DirectorySeparatorChar)
}

function Ensure-TbgDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Get-TbgPropertyValue {
    param($Object, [Parameter(Mandatory = $true)][string]$Name, $Default = $null)
    if ($null -ne $Object -and $null -ne $Object.PSObject.Properties[$Name]) {
        return $Object.PSObject.Properties[$Name].Value
    }
    return $Default
}

function Get-TbgVersionText {
    param([AllowNull()][string]$Version)
    if ([string]::IsNullOrWhiteSpace($Version)) { return $null }
    $value = $Version.Trim()
    if ($value.StartsWith('v', [StringComparison]::OrdinalIgnoreCase)) { $value = $value.Substring(1) }
    if ($value -match '^(?<v>[0-9]+(?:\.[0-9]+){2,3})') { return $Matches.v }
    return $null
}

function Test-TbgVersionChanged {
    param([AllowNull()][string]$Baseline, [AllowNull()][string]$Candidate)
    if ([string]::IsNullOrWhiteSpace($Baseline) -or [string]::IsNullOrWhiteSpace($Candidate)) { return $false }
    $baselineParts = @($Baseline -split '\.')
    if ($baselineParts.Count -lt 4) {
        return -not ($Candidate -eq $Baseline -or $Candidate.StartsWith(($Baseline + '.'), [StringComparison]::OrdinalIgnoreCase))
    }
    return -not [string]::Equals($Baseline, $Candidate, [StringComparison]::OrdinalIgnoreCase)
}

function Get-TbgXmlModuleVersion {
    param([AllowNull()][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try {
        [xml]$xml = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        if ($null -ne $xml.Module.Version) { return [string]$xml.Module.Version.value }
    } catch { }
    return $null
}

function Convert-TbgSafePath {
    param([AllowNull()][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    try {
        $full = [IO.Path]::GetFullPath($Path)
        if ($full.StartsWith($RepoRoot, [StringComparison]::OrdinalIgnoreCase)) {
            return $full.Substring($RepoRoot.Length).TrimStart('\','/') -replace '\\','/'
        }
    } catch { }
    return [IO.Path]::GetFileName($Path)
}

function Resolve-TbgOwnerLane {
    param([string]$Path, [Parameter(Mandatory = $true)]$Registry, [string]$Default = 'implementation-completion')
    foreach ($route in @($Registry.pathRouting)) {
        if (-not [string]::IsNullOrWhiteSpace($Path) -and $Path -match [string]$route.regex) {
            return [string]$route.ownerLane
        }
    }
    return $Default
}

function New-TbgFinding {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$ProbeFamily,
        [Parameter(Mandatory = $true)][ValidateSet('info','attention','blocker')][string]$Severity,
        [Parameter(Mandatory = $true)][string]$TerminalState,
        [Parameter(Mandatory = $true)][string]$OwnerLane,
        [Parameter(Mandatory = $true)][string]$Summary,
        $Evidence,
        [Parameter(Mandatory = $true)][string]$RecommendedAction
    )
    [pscustomobject][ordered]@{
        id = $Id
        probeFamily = $ProbeFamily
        severity = $Severity
        terminalState = $TerminalState
        ownerLane = $OwnerLane
        summary = $Summary
        evidence = $Evidence
        recommendedAction = $RecommendedAction
    }
}

$registryFullPath = Resolve-TbgRepoPath -Path $RegistryPath
if (-not (Test-Path -LiteralPath $registryFullPath -PathType Leaf)) {
    throw "Version upgrade impact registry missing: $registryFullPath"
}
$registry = Get-Content -LiteralPath $registryFullPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop

$generatedUtc = [DateTime]::UtcNow.ToString('o')
$runId = 'version-upgrade-impact-{0}-{1}' -f ([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')), ([Guid]::NewGuid().ToString('N').Substring(0,6))
$outputRoot = Resolve-TbgRepoPath -Path $OutputDirectory
$runRoot = Join-Path (Join-Path $outputRoot 'runs') $runId
Ensure-TbgDirectory -Path $runRoot
$resultPath = Join-Path $runRoot 'version-upgrade-impact.result.json'
$reportPath = Join-Path $runRoot 'version-upgrade-impact.report.md'
$sprintPacketPath = Join-Path $runRoot 'version-upgrade-impact.sprint-packet.json'
$issueDraftPath = Join-Path $runRoot 'version-upgrade-impact.issue.md'
$sourceInventoryPath = Join-Path $runRoot 'version-upgrade-impact.source-inventory.json'
$compilerLogPath = Join-Path $runRoot 'candidate-build.log'

$fixture = $null
if ($Mode -eq 'fixture') {
    if ([string]::IsNullOrWhiteSpace($FixturePath) -or [string]::IsNullOrWhiteSpace($FixtureCaseId)) {
        throw 'Fixture mode requires -FixturePath and -FixtureCaseId.'
    }
    $fixtureFullPath = Resolve-TbgRepoPath -Path $FixturePath
    $fixtureRoot = Get-Content -LiteralPath $fixtureFullPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    $matches = @($fixtureRoot.cases | Where-Object { [string]$_.id -eq $FixtureCaseId })
    if ($matches.Count -ne 1) { throw "Fixture case '$FixtureCaseId' was not found exactly once." }
    $fixture = $matches[0]
}

$gameCompatibilityRegistryPath = Resolve-TbgRepoPath -Path ([string]$registry.baseline.gameCompatibilityRegistry)
$gameCompatibilityRegistry = Get-Content -LiteralPath $gameCompatibilityRegistryPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop

if ($Mode -eq 'fixture') {
    $BaselineGameVersion = [string]$fixture.baselineVersion
    $CandidateGameVersion = [string]$fixture.candidateVersion
}
elseif ([string]::IsNullOrWhiteSpace($BaselineGameVersion)) {
    $latestCompatibility = Resolve-TbgRepoPath -Path 'artifacts/latest/game-compatibility/game-compatibility.result.json'
    if (Test-Path -LiteralPath $latestCompatibility -PathType Leaf) {
        try {
            $compat = Get-Content -LiteralPath $latestCompatibility -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
            $installed = Get-TbgPropertyValue -Object $compat -Name 'locallyInstalledBuild'
            $BaselineGameVersion = [string](Get-TbgPropertyValue -Object $installed -Name 'gameExecutableVersion' -Default '')
            if ([string]::IsNullOrWhiteSpace($BaselineGameVersion)) {
                $BaselineGameVersion = [string](Get-TbgPropertyValue -Object $installed -Name 'nativeModuleVersion' -Default '')
            }
        } catch { }
    }
    if ([string]::IsNullOrWhiteSpace($BaselineGameVersion)) {
        $BaselineGameVersion = [string]$gameCompatibilityRegistry.repoSupportedBuild.gameVersionPrefix
    }
}
$BaselineGameVersion = Get-TbgVersionText -Version $BaselineGameVersion

if ($Mode -ne 'fixture' -and [string]::IsNullOrWhiteSpace($CandidateGameRoot) -and $Mode -eq 'candidate') {
    try {
        . (Join-Path $RepoRoot 'scripts/bannerlord-paths.ps1')
        $CandidateGameRoot = Get-BannerlordRootFromRepo -RepoRoot $RepoRoot
    } catch { }
}
if ($Mode -ne 'fixture' -and [string]::IsNullOrWhiteSpace($CandidateGameVersion) -and -not [string]::IsNullOrWhiteSpace($CandidateGameRoot)) {
    $gameExe = Join-Path $CandidateGameRoot 'bin/Win64_Shipping_Client/Bannerlord.exe'
    if (Test-Path -LiteralPath $gameExe -PathType Leaf) {
        try { $CandidateGameVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($gameExe).FileVersion } catch { }
    }
    if ([string]::IsNullOrWhiteSpace($CandidateGameVersion)) {
        $CandidateGameVersion = Get-TbgXmlModuleVersion -Path (Join-Path $CandidateGameRoot 'Modules/Native/SubModule.xml')
    }
}
if ($Mode -eq 'inventory' -and [string]::IsNullOrWhiteSpace($CandidateGameVersion)) {
    $CandidateGameVersion = $BaselineGameVersion
}
$CandidateGameVersion = Get-TbgVersionText -Version $CandidateGameVersion
$versionChanged = Test-TbgVersionChanged -Baseline $BaselineGameVersion -Candidate $CandidateGameVersion

$assemblyReferences = New-Object System.Collections.Generic.List[object]
$dynamicBindings = New-Object System.Collections.Generic.List[object]
$moduleDependencyDrift = New-Object System.Collections.Generic.List[object]
$compileErrors = New-Object System.Collections.Generic.List[object]
$compileAttempted = $false
$compileExitCode = $null
$compileReason = $null

if ($Mode -eq 'fixture') {
    foreach ($entry in @($fixture.assemblyReferences)) { $assemblyReferences.Add($entry) | Out-Null }
    foreach ($entry in @($fixture.dynamicBindings)) { $dynamicBindings.Add($entry) | Out-Null }
    foreach ($entry in @($fixture.moduleDependencyDrift)) { $moduleDependencyDrift.Add($entry) | Out-Null }
    $compileAttempted = [bool]$fixture.compile.attempted
    $compileExitCode = Get-TbgPropertyValue -Object $fixture.compile -Name 'exitCode'
    foreach ($entry in @($fixture.compile.errors)) { $compileErrors.Add($entry) | Out-Null }
}
else {
    foreach ($assembly in @($registry.candidateAssemblies)) {
        $candidatePath = if ([string]::IsNullOrWhiteSpace($CandidateGameRoot)) { $null } else { Join-Path $CandidateGameRoot (([string]$assembly.relativePath) -replace '/', [IO.Path]::DirectorySeparatorChar) }
        $exists = if ($null -eq $candidatePath) { $null } else { Test-Path -LiteralPath $candidatePath -PathType Leaf }
        $assemblyReferences.Add([pscustomobject][ordered]@{
            include = [string]$assembly.include
            relativePath = [string]$assembly.relativePath
            exists = $exists
        }) | Out-Null
    }

    $sourceRoot = Join-Path $RepoRoot 'src'
    if (Test-Path -LiteralPath $sourceRoot -PathType Container) {
        foreach ($file in Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Filter '*.cs' -ErrorAction SilentlyContinue) {
            $relative = Convert-TbgSafePath -Path $file.FullName
            $lineNumber = 0
            foreach ($line in Get-Content -LiteralPath $file.FullName -Encoding UTF8) {
                $lineNumber++
                foreach ($pattern in @($registry.dynamicBindingPatterns)) {
                    if ($line.Contains([string]$pattern)) {
                        $snippet = $line.Trim()
                        if ($snippet.Length -gt 180) { $snippet = $snippet.Substring(0,180) }
                        $dynamicBindings.Add([pscustomobject][ordered]@{
                            file = $relative
                            line = $lineNumber
                            pattern = [string]$pattern
                            snippet = $snippet
                        }) | Out-Null
                    }
                }
            }
        }
    }

    $repoModulePath = Resolve-TbgRepoPath -Path ([string]$registry.baseline.moduleManifest)
    $candidateNativeVersion = if ([string]::IsNullOrWhiteSpace($CandidateGameRoot)) { $null } else { Get-TbgXmlModuleVersion -Path (Join-Path $CandidateGameRoot 'Modules/Native/SubModule.xml') }
    if ($candidateNativeVersion -and (Test-Path -LiteralPath $repoModulePath -PathType Leaf)) {
        try {
            [xml]$moduleXml = Get-Content -LiteralPath $repoModulePath -Raw -Encoding UTF8
            foreach ($dependency in @($moduleXml.Module.DependedModules.DependedModule)) {
                $declared = [string]$dependency.DependentVersion
                if (-not [string]::IsNullOrWhiteSpace($declared) -and $declared -ne $candidateNativeVersion) {
                    $moduleDependencyDrift.Add([pscustomobject][ordered]@{
                        module = [string]$dependency.Id
                        declaredVersion = $declared
                        candidateVersion = $candidateNativeVersion
                    }) | Out-Null
                }
            }
        } catch { }
    }

    $missingAssemblies = @($assemblyReferences | Where-Object { $_.exists -eq $false })
    if ($Mode -eq 'candidate' -and -not $NoBuild -and $missingAssemblies.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($CandidateGameRoot)) {
        $dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
        if ($null -eq $dotnet) {
            $compileReason = 'dotnet_not_available'
        }
        else {
            $compileAttempted = $true
            $projectPath = Resolve-TbgRepoPath -Path ([string]$registry.baseline.sourceProject)
            $buildRoot = Join-Path $runRoot 'isolated-build'
            $buildOutput = Join-Path $buildRoot 'bin'
            $editorOutput = Join-Path $buildRoot 'weditor'
            Ensure-TbgDirectory -Path $buildOutput
            Ensure-TbgDirectory -Path $editorOutput
            $arguments = @(
                'build', $projectPath,
                '-c', 'Debug',
                '--nologo',
                "-p:GameFolder=$CandidateGameRoot",
                "-p:OutputPath=$buildOutput$([IO.Path]::DirectorySeparatorChar)",
                "-p:WEditorOutputPath=$editorOutput$([IO.Path]::DirectorySeparatorChar)"
            )
            $buildOutputLines = @(& $dotnet.Source @arguments 2>&1 | ForEach-Object { [string]$_ })
            $compileExitCode = $LASTEXITCODE
            $buildOutputLines | Set-Content -LiteralPath $compilerLogPath -Encoding UTF8
            foreach ($buildLine in $buildOutputLines) {
                if ($buildLine -match '^(?<file>.+?\.cs)\((?<line>[0-9]+),(?<column>[0-9]+)\):\s+error\s+(?<code>CS[0-9]+):\s+(?<message>.+?)(?:\s+\[.+\])?$') {
                    $compileErrors.Add([pscustomobject][ordered]@{
                        file = Convert-TbgSafePath -Path $Matches.file
                        line = [int]$Matches.line
                        column = [int]$Matches.column
                        code = $Matches.code
                        message = $Matches.message.Trim()
                    }) | Out-Null
                }
            }
            if ($compileExitCode -ne 0 -and $compileErrors.Count -eq 0) {
                $compileErrors.Add([pscustomobject][ordered]@{
                    file = 'src/BlacksmithGuild/BlacksmithGuild.csproj'
                    line = $null
                    column = $null
                    code = 'BUILD_FAILED'
                    message = 'Candidate build returned a nonzero exit code. Inspect candidate-build.log.'
                }) | Out-Null
            }
        }
    }
    elseif ($Mode -eq 'candidate' -and $NoBuild) {
        $compileReason = 'build_explicitly_skipped'
    }
}

$sourceInventory = [pscustomobject][ordered]@{
    schema = 'TbgVersionUpgradeSourceInventory.v1'
    generatedUtc = $generatedUtc
    baselineVersion = $BaselineGameVersion
    candidateVersion = $CandidateGameVersion
    assemblyReferences = @($assemblyReferences.ToArray())
    dynamicBindings = @($dynamicBindings.ToArray())
    moduleDependencyDrift = @($moduleDependencyDrift.ToArray())
}
$sourceInventory | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $sourceInventoryPath -Encoding UTF8

$findings = New-Object System.Collections.Generic.List[object]
foreach ($assembly in @($assemblyReferences.ToArray() | Where-Object { $_.exists -eq $false })) {
    $findings.Add((New-TbgFinding -Id ('assembly-missing-' + ([string]$assembly.include).Replace('.','-').ToLowerInvariant()) -ProbeFamily 'candidate_assembly_presence' -Severity blocker -TerminalState 'BLOCKED_CANDIDATE_ASSEMBLY_MISSING' -OwnerLane 'harness/game-version-observation' -Summary "Candidate game root is missing required assembly $($assembly.include)." -Evidence @{ assembly = $assembly.include; relativePath = $assembly.relativePath } -RecommendedAction 'Resolve the candidate installation/layout or update the project reference contract before attempting a candidate build.')) | Out-Null
}

foreach ($error in @($compileErrors.ToArray())) {
    $safeFile = [string]$error.file
    $owner = Resolve-TbgOwnerLane -Path $safeFile -Registry $registry
    $code = [string](Get-TbgPropertyValue -Object $error -Name 'code' -Default 'BUILD_FAILED')
    $findings.Add((New-TbgFinding -Id ('compile-' + $code.ToLowerInvariant() + '-' + $findings.Count) -ProbeFamily 'candidate_compile' -Severity blocker -TerminalState 'BLOCKED_CANDIDATE_COMPILE_FAILURE' -OwnerLane $owner -Summary "Candidate compile failure $code in $safeFile." -Evidence @{ file = $safeFile; line = (Get-TbgPropertyValue -Object $error -Name 'line'); code = $code; message = [string]$error.message } -RecommendedAction 'Repair the named API/source incompatibility against the candidate game assemblies, then rerun the candidate upgrade probe.')) | Out-Null
}

if ($Mode -eq 'candidate' -and -not $NoBuild -and @($assemblyReferences | Where-Object { $_.exists -eq $false }).Count -eq 0 -and -not $compileAttempted) {
    $findings.Add((New-TbgFinding -Id 'candidate-build-not-attempted' -ProbeFamily 'candidate_compile' -Severity blocker -TerminalState 'BLOCKED_CANDIDATE_COMPILE_FAILURE' -OwnerLane 'implementation-completion' -Summary 'Candidate compile was required but did not run.' -Evidence @{ reason = $compileReason } -RecommendedAction 'Restore dotnet/build prerequisites and rerun the candidate probe; do not promote compatibility without a candidate build.')) | Out-Null
}

foreach ($drift in @($moduleDependencyDrift.ToArray())) {
    $findings.Add((New-TbgFinding -Id ('module-dependency-' + ([string]$drift.module).ToLowerInvariant()) -ProbeFamily 'module_dependency_drift' -Severity attention -TerminalState 'ATTENTION_VERSION_CHANGE_REQUIRES_RECERTIFICATION' -OwnerLane 'harness/game-version-observation' -Summary "Tracked module dependency $($drift.module) declares $($drift.declaredVersion) while candidate Native reports $($drift.candidateVersion)." -Evidence @{ module = $drift.module; declaredVersion = $drift.declaredVersion; candidateVersion = $drift.candidateVersion } -RecommendedAction 'Verify the candidate module dependency contract and update packaging metadata only in a dedicated compatibility sprint after evidence confirms the required version.')) | Out-Null
}

if ($versionChanged) {
    foreach ($binding in @($dynamicBindings.ToArray())) {
        $owner = Resolve-TbgOwnerLane -Path ([string]$binding.file) -Registry $registry
        $findings.Add((New-TbgFinding -Id ('dynamic-binding-' + $findings.Count) -ProbeFamily 'dynamic_binding_inventory' -Severity attention -TerminalState 'ATTENTION_DYNAMIC_BINDING_REVIEW_REQUIRED' -OwnerLane $owner -Summary "Dynamic API binding requires candidate-version review in $($binding.file):$($binding.line)." -Evidence @{ file = $binding.file; line = $binding.line; pattern = $binding.pattern; snippet = $binding.snippet } -RecommendedAction 'Prove the reflected/Harmony/string-bound target against candidate metadata or a focused static/runtime contract; compile success alone is insufficient.')) | Out-Null
    }
    $findings.Add((New-TbgFinding -Id 'save-reclassification-required' -ProbeFamily 'save_reclassification' -Severity attention -TerminalState 'ATTENTION_VERSION_CHANGE_REQUIRES_RECERTIFICATION' -OwnerLane 'harness/save-compatibility' -Summary "Game version changed from $BaselineGameVersion to $CandidateGameVersion; prior save compatibility admission is stale." -Evidence @{ baselineVersion = $BaselineGameVersion; candidateVersion = $CandidateGameVersion } -RecommendedAction "Run .\ForgeSaveCompatibility.cmd -Mode catalog -GameVersion '$CandidateGameVersion' and gate the exact intended save before launcher-lifecycle acts.")) | Out-Null
    $findings.Add((New-TbgFinding -Id 'runtime-recertification-required' -ProbeFamily 'runtime_recertification' -Severity attention -TerminalState 'ATTENTION_VERSION_CHANGE_REQUIRES_RECERTIFICATION' -OwnerLane 'runtime-evidence-certification' -Summary "Version-sensitive runtime certification is stale for candidate $CandidateGameVersion." -Evidence @{ invalidatedFamilies = @($registry.runtimeCertFamiliesInvalidatedOnVersionChange) } -RecommendedAction 'After static/build and save gates pass, execute the canonical live-cert ladder on a separately authorized clean runtime session.')) | Out-Null
}

$blockers = @($findings | Where-Object severity -eq 'blocker')
$attentions = @($findings | Where-Object severity -eq 'attention')
$terminalState = if ($blockers.Count -gt 0) {
    'BLOCKED_VERSION_UPGRADE_GAPS'
}
elif ($Mode -eq 'inventory') {
    'PASS_UPGRADE_BASELINE_INVENTORIED'
}
elif ($versionChanged -or $attentions.Count -gt 0) {
    'ATTENTION_VERSION_CHANGE_REQUIRES_RECERTIFICATION'
}
else {
    'PASS_NO_ACTIONABLE_UPGRADE_GAPS'
}

$laneOrder = @(
    'harness/game-version-observation',
    'implementation-completion',
    'launcher-lifecycle',
    'route-visible-trade',
    'harness/save-compatibility',
    'runtime-evidence-certification'
)
$sprintCandidates = New-Object System.Collections.Generic.List[object]
foreach ($owner in $laneOrder) {
    $ownedFindings = @($findings | Where-Object { [string]$_.ownerLane -eq $owner })
    if ($ownedFindings.Count -eq 0) { continue }
    $slug = ($owner -replace '[^A-Za-z0-9]+','-').Trim('-').ToLowerInvariant()
    $candidateSlug = if ($CandidateGameVersion) { $CandidateGameVersion -replace '[^0-9A-Za-z]+','-' } else { 'unknown' }
    $dependency = switch ($owner) {
        'harness/game-version-observation' { 'candidate version/build metadata observed' }
        'implementation-completion' { 'candidate assembly presence resolved' }
        'launcher-lifecycle' { 'candidate compile blockers repaired' }
        'route-visible-trade' { 'candidate compile blockers repaired' }
        'harness/save-compatibility' { 'candidate exact version resolved and compile blockers triaged' }
        'runtime-evidence-certification' { 'candidate static/build gaps repaired and exact save gate re-certified' }
        default { 'candidate probe result available' }
    }
    $firstCommand = switch ($owner) {
        'harness/save-compatibility' { ".\ForgeSaveCompatibility.cmd -Mode catalog -GameVersion '$CandidateGameVersion'" }
        'runtime-evidence-certification' { '.\ForgeTest.cmd run --profile default-static' }
        default { '.\ForgeVersionUpgradeProbe.cmd -Mode candidate' }
    }
    $expectedArtifact = switch ($owner) {
        'harness/save-compatibility' { 'artifacts/latest/save-compatibility/save-compatibility.result.json' }
        'runtime-evidence-certification' { 'artifacts/latest/live-runtime-proof-admission/live-runtime-proof-admission.result.json plus a later authorized fresh live packet' }
        default { 'artifacts/latest/version-upgrade-impact/version-upgrade-impact.result.json' }
    }
    $completionGate = switch ($owner) {
        'harness/game-version-observation' { 'candidate assembly/dependency findings for this lane are cleared or replaced by a newer evidence-backed classification' }
        'harness/save-compatibility' { 'the intended save has a fresh candidate-version gate result and incompatible saves remain blocked' }
        'runtime-evidence-certification' { 'all static/build/save prerequisites pass and a later clean runtime run re-proves each invalidated certification family' }
        default { 'all findings assigned to this owner lane are absent or pass on a rerun against the same candidate version' }
    }
    $sprintCandidates.Add([pscustomobject][ordered]@{
        id = "upgrade-$candidateSlug-$slug"
        owner = $owner
        dependency = $dependency
        mission = "Resolve $($ownedFindings.Count) version-upgrade finding(s) for $owner against Bannerlord $CandidateGameVersion."
        findingIds = @($ownedFindings | ForEach-Object { $_.id })
        firstCommand = $firstCommand
        expectedArtifact = $expectedArtifact
        completionGate = $completionGate
    }) | Out-Null
}

$proofCeiling = 'candidate static/build compatibility'
$candidateBuild = [pscustomobject][ordered]@{
    attempted = [bool]$compileAttempted
    exitCode = $compileExitCode
    reason = $compileReason
    errorCount = $compileErrors.Count
    log = if (Test-Path -LiteralPath $compilerLogPath -PathType Leaf) { $compilerLogPath } else { $null }
}
$evidencePaths = [ordered]@{
    result = $resultPath
    report = $reportPath
    sprintPacket = $sprintPacketPath
    issueDraft = $issueDraftPath
    sourceInventory = $sourceInventoryPath
    compilerLog = if (Test-Path -LiteralPath $compilerLogPath -PathType Leaf) { $compilerLogPath } else { $null }
}
$result = [pscustomobject][ordered]@{
    schema = 'TbgVersionUpgradeImpactResult.v1'
    generatedUtc = $generatedUtc
    runId = $runId
    mode = $Mode
    baselineVersion = $BaselineGameVersion
    candidateVersion = $CandidateGameVersion
    versionChanged = [bool]$versionChanged
    terminalState = $terminalState
    proofCeiling = $proofCeiling
    candidateBuild = $candidateBuild
    findings = @($findings.ToArray())
    sprintCandidates = @($sprintCandidates.ToArray())
    evidencePaths = $evidencePaths
}
$result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resultPath -Encoding UTF8

$sprintPacket = [pscustomobject][ordered]@{
    schema = 'TbgVersionUpgradeSprintPacket.v1'
    generatedUtc = $generatedUtc
    sourceRunId = $runId
    baselineVersion = $BaselineGameVersion
    candidateVersion = $CandidateGameVersion
    terminalState = $terminalState
    dependencyOrder = @($sprintCandidates | ForEach-Object { $_.id })
    sprints = @($sprintCandidates.ToArray())
    proofCeiling = $proofCeiling
}
$sprintPacket | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $sprintPacketPath -Encoding UTF8

$report = New-Object System.Collections.Generic.List[string]
$report.Add('# Version upgrade impact report') | Out-Null
$report.Add('') | Out-Null
$report.Add("## Upgrade verdict") | Out-Null
$report.Add("- Baseline version: `$BaselineGameVersion`") | Out-Null
$report.Add("- Candidate version: `$CandidateGameVersion`") | Out-Null
$report.Add("- Version changed: `$versionChanged`") | Out-Null
$report.Add("- Terminal state: `$terminalState`") | Out-Null
$report.Add("- Proof ceiling: `$proofCeiling`") | Out-Null
$report.Add('') | Out-Null
$report.Add('## Probe findings') | Out-Null
if ($findings.Count -eq 0) { $report.Add('- None.') | Out-Null }
foreach ($finding in @($findings.ToArray())) {
    $report.Add("- **$($finding.severity)** `$($finding.probeFamily)` → `$($finding.ownerLane)`: $($finding.summary)") | Out-Null
}
$report.Add('') | Out-Null
$report.Add('## Actionable sprints') | Out-Null
if ($sprintCandidates.Count -eq 0) { $report.Add('- None.') | Out-Null }
foreach ($sprint in @($sprintCandidates.ToArray())) {
    $report.Add("### $($sprint.id)") | Out-Null
    $report.Add("- Owner: `$($sprint.owner)`") | Out-Null
    $report.Add("- Dependency: $($sprint.dependency)") | Out-Null
    $report.Add("- First command: `$($sprint.firstCommand)`") | Out-Null
    $report.Add("- Expected artifact: $($sprint.expectedArtifact)") | Out-Null
    $report.Add("- Completion gate: $($sprint.completionGate)") | Out-Null
}
$report.Add('') | Out-Null
$report.Add('## Claims not made') | Out-Null
$report.Add('- Compile success does not prove reflected/Harmony targets still bind.') | Out-Null
$report.Add('- Static/build success does not prove save load, launcher flow, campaign readiness, governor/trade behavior, or live runtime compatibility.') | Out-Null
$report.Add('- This probe never launches or updates Bannerlord and never installs the mod.') | Out-Null
$report | Set-Content -LiteralPath $reportPath -Encoding UTF8

$title = "Version upgrade probe: Bannerlord $BaselineGameVersion -> $CandidateGameVersion"
$issue = New-Object System.Collections.Generic.List[string]
$issue.Add("# $title") | Out-Null
$issue.Add('') | Out-Null
$issue.Add("Candidate version: `$CandidateGameVersion`") | Out-Null
$issue.Add("Probe state: `$terminalState`") | Out-Null
$issue.Add("Proof ceiling: `$proofCeiling`") | Out-Null
$issue.Add('') | Out-Null
$issue.Add('## Findings') | Out-Null
if ($findings.Count -eq 0) { $issue.Add('- No actionable findings.') | Out-Null }
foreach ($finding in @($findings.ToArray())) {
    $issue.Add("- [$($finding.severity)] **$($finding.ownerLane)** — $($finding.summary)") | Out-Null
}
$issue.Add('') | Out-Null
$issue.Add('## Actionable sprint order') | Out-Null
foreach ($sprint in @($sprintCandidates.ToArray())) {
    $issue.Add("### $($sprint.id)") | Out-Null
    $issue.Add("- Owner: `$($sprint.owner)`") | Out-Null
    $issue.Add("- Dependency: $($sprint.dependency)") | Out-Null
    $issue.Add("- Mission: $($sprint.mission)") | Out-Null
    $issue.Add("- First command: `$($sprint.firstCommand)`") | Out-Null
    $issue.Add("- Expected artifact: $($sprint.expectedArtifact)") | Out-Null
    $issue.Add("- Completion gate: $($sprint.completionGate)") | Out-Null
}
$issue.Add('') | Out-Null
$issue.Add('## Safety boundary') | Out-Null
$issue.Add('This issue was generated from sanitized static/build evidence. It authorizes no game launch, save mutation, mod install, runtime action, or proof promotion.') | Out-Null
$issue | Set-Content -LiteralPath $issueDraftPath -Encoding UTF8

Ensure-TbgDirectory -Path $outputRoot
Copy-Item -LiteralPath $resultPath -Destination (Join-Path $outputRoot 'version-upgrade-impact.result.json') -Force
Copy-Item -LiteralPath $reportPath -Destination (Join-Path $outputRoot 'version-upgrade-impact.report.md') -Force
Copy-Item -LiteralPath $sprintPacketPath -Destination (Join-Path $outputRoot 'version-upgrade-impact.sprint-packet.json') -Force
Copy-Item -LiteralPath $issueDraftPath -Destination (Join-Path $outputRoot 'version-upgrade-impact.issue.md') -Force
Copy-Item -LiteralPath $sourceInventoryPath -Destination (Join-Path $outputRoot 'version-upgrade-impact.source-inventory.json') -Force

Write-Host "Version upgrade impact: $terminalState"
Write-Host "Baseline: $BaselineGameVersion"
Write-Host "Candidate: $CandidateGameVersion"
Write-Host "Findings: $($findings.Count)"
Write-Host "Sprints: $($sprintCandidates.Count)"
Write-Host "Result: $resultPath"
Write-Host "Issue draft: $issueDraftPath"

if ($PassThru) { $result }
if (-not $NoExit) {
    $exitCode = if ($terminalState -like 'PASS_*') { 0 } elseif ($terminalState -like 'ATTENTION_*') { 2 } else { 3 }
    exit $exitCode
}
