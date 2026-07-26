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
if ([string]::IsNullOrWhiteSpace($RepoRoot)) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
$RepoRoot = [IO.Path]::GetFullPath($RepoRoot)

function Resolve-TbgRepoPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return $Path }
    Join-Path $RepoRoot ($Path -replace '/', [IO.Path]::DirectorySeparatorChar)
}
function Ensure-TbgDirectory([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { New-Item -ItemType Directory -Force -Path $Path | Out-Null }
}
function Get-TbgPropertyValue($Object, [string]$Name, $Default = $null) {
    if ($null -ne $Object -and $null -ne $Object.PSObject.Properties[$Name]) { return $Object.PSObject.Properties[$Name].Value }
    $Default
}
function Get-TbgVersionText([AllowNull()][string]$Version) {
    if ([string]::IsNullOrWhiteSpace($Version)) { return $null }
    $value = $Version.Trim()
    if ($value.StartsWith('v', [StringComparison]::OrdinalIgnoreCase)) { $value = $value.Substring(1) }
    if ($value -match '^(?<v>[0-9]+(?:\.[0-9]+){2,3})') { return $Matches.v }
    $null
}
function Test-TbgVersionChanged([AllowNull()][string]$Baseline, [AllowNull()][string]$Candidate) {
    if ([string]::IsNullOrWhiteSpace($Baseline) -or [string]::IsNullOrWhiteSpace($Candidate)) { return $false }
    $parts = @($Baseline -split '\.')
    if ($parts.Count -lt 4) { return -not ($Candidate -eq $Baseline -or $Candidate.StartsWith(($Baseline + '.'), [StringComparison]::OrdinalIgnoreCase)) }
    -not [string]::Equals($Baseline, $Candidate, [StringComparison]::OrdinalIgnoreCase)
}
function Get-TbgXmlModuleVersion([AllowNull()][string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try {
        [xml]$xml = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        if ($null -ne $xml.Module.Version) { return [string]$xml.Module.Version.value }
    } catch { }
    $null
}
function Convert-TbgSafePath([AllowNull()][string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    try {
        $full = [IO.Path]::GetFullPath($Path)
        if ($full.StartsWith($RepoRoot, [StringComparison]::OrdinalIgnoreCase)) {
            return ($full.Substring($RepoRoot.Length).TrimStart([char]'\',[char]'/') -replace '\\','/')
        }
    } catch { }
    [IO.Path]::GetFileName($Path)
}
function Resolve-TbgOwnerLane([string]$Path, $Registry, [string]$Default = 'implementation-completion') {
    foreach ($route in @($Registry.pathRouting)) {
        if (-not [string]::IsNullOrWhiteSpace($Path) -and $Path -match [string]$route.regex) { return [string]$route.ownerLane }
    }
    $Default
}
function New-TbgFinding([string]$Id, [string]$ProbeFamily, [string]$Severity, [string]$TerminalState, [string]$OwnerLane, [string]$Summary, $Evidence, [string]$RecommendedAction) {
    [pscustomobject][ordered]@{
        id = $Id; probeFamily = $ProbeFamily; severity = $Severity; terminalState = $TerminalState
        ownerLane = $OwnerLane; summary = $Summary; evidence = $Evidence; recommendedAction = $RecommendedAction
    }
}

$registryFullPath = Resolve-TbgRepoPath $RegistryPath
if (-not (Test-Path -LiteralPath $registryFullPath -PathType Leaf)) { throw "Version upgrade impact registry missing: $registryFullPath" }
$registry = Get-Content -LiteralPath $registryFullPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
$gameCompatibilityRegistry = Get-Content -LiteralPath (Resolve-TbgRepoPath ([string]$registry.baseline.gameCompatibilityRegistry)) -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop

$generatedUtc = [DateTime]::UtcNow.ToString('o')
$runId = 'version-upgrade-impact-{0}-{1}' -f ([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')), ([Guid]::NewGuid().ToString('N').Substring(0,6))
$outputRoot = Resolve-TbgRepoPath $OutputDirectory
$runRoot = Join-Path (Join-Path $outputRoot 'runs') $runId
Ensure-TbgDirectory $runRoot
$resultPath = Join-Path $runRoot 'version-upgrade-impact.result.json'
$reportPath = Join-Path $runRoot 'version-upgrade-impact.report.md'
$sprintPacketPath = Join-Path $runRoot 'version-upgrade-impact.sprint-packet.json'
$issueDraftPath = Join-Path $runRoot 'version-upgrade-impact.issue.md'
$sourceInventoryPath = Join-Path $runRoot 'version-upgrade-impact.source-inventory.json'
$compilerLogPath = Join-Path $runRoot 'candidate-build.log'

$fixture = $null
if ($Mode -eq 'fixture') {
    if ([string]::IsNullOrWhiteSpace($FixturePath) -or [string]::IsNullOrWhiteSpace($FixtureCaseId)) { throw 'Fixture mode requires -FixturePath and -FixtureCaseId.' }
    $fixtureRoot = Get-Content -LiteralPath (Resolve-TbgRepoPath $FixturePath) -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    $matches = @($fixtureRoot.cases | Where-Object { [string]$_.id -eq $FixtureCaseId })
    if ($matches.Count -ne 1) { throw "Fixture case '$FixtureCaseId' was not found exactly once." }
    $fixture = $matches[0]
    $BaselineGameVersion = [string]$fixture.baselineVersion
    $CandidateGameVersion = [string]$fixture.candidateVersion
}
elseif ([string]::IsNullOrWhiteSpace($BaselineGameVersion)) {
    $latestCompatibility = Resolve-TbgRepoPath 'artifacts/latest/game-compatibility/game-compatibility.result.json'
    if (Test-Path -LiteralPath $latestCompatibility -PathType Leaf) {
        try {
            $compat = Get-Content -LiteralPath $latestCompatibility -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
            $installed = Get-TbgPropertyValue $compat 'locallyInstalledBuild'
            $BaselineGameVersion = [string](Get-TbgPropertyValue $installed 'gameExecutableVersion' '')
            if ([string]::IsNullOrWhiteSpace($BaselineGameVersion)) { $BaselineGameVersion = [string](Get-TbgPropertyValue $installed 'nativeModuleVersion' '') }
        } catch { }
    }
    if ([string]::IsNullOrWhiteSpace($BaselineGameVersion)) { $BaselineGameVersion = [string]$gameCompatibilityRegistry.repoSupportedBuild.gameVersionPrefix }
}
$BaselineGameVersion = Get-TbgVersionText $BaselineGameVersion

if ($Mode -eq 'candidate' -and [string]::IsNullOrWhiteSpace($CandidateGameRoot)) {
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
    if ([string]::IsNullOrWhiteSpace($CandidateGameVersion)) { $CandidateGameVersion = Get-TbgXmlModuleVersion (Join-Path $CandidateGameRoot 'Modules/Native/SubModule.xml') }
}
if ($Mode -eq 'inventory' -and [string]::IsNullOrWhiteSpace($CandidateGameVersion)) { $CandidateGameVersion = $BaselineGameVersion }
$CandidateGameVersion = Get-TbgVersionText $CandidateGameVersion
$versionChanged = Test-TbgVersionChanged $BaselineGameVersion $CandidateGameVersion

$assemblyReferences = [System.Collections.Generic.List[object]]::new()
$dynamicBindings = [System.Collections.Generic.List[object]]::new()
$moduleDependencyDrift = [System.Collections.Generic.List[object]]::new()
$compileErrors = [System.Collections.Generic.List[object]]::new()
$compileAttempted = $false
$compileExitCode = $null
$compileReason = $null

if ($Mode -eq 'fixture') {
    foreach ($entry in @($fixture.assemblyReferences)) { $assemblyReferences.Add($entry) | Out-Null }
    foreach ($entry in @($fixture.dynamicBindings)) { $dynamicBindings.Add($entry) | Out-Null }
    foreach ($entry in @($fixture.moduleDependencyDrift)) { $moduleDependencyDrift.Add($entry) | Out-Null }
    $compileAttempted = [bool]$fixture.compile.attempted
    $compileExitCode = Get-TbgPropertyValue $fixture.compile 'exitCode'
    foreach ($entry in @($fixture.compile.errors)) { $compileErrors.Add($entry) | Out-Null }
}
else {
    foreach ($assembly in @($registry.candidateAssemblies)) {
        $candidatePath = if ([string]::IsNullOrWhiteSpace($CandidateGameRoot)) { $null } else { Join-Path $CandidateGameRoot (([string]$assembly.relativePath) -replace '/', [IO.Path]::DirectorySeparatorChar) }
        $exists = if ($null -eq $candidatePath) { $null } else { Test-Path -LiteralPath $candidatePath -PathType Leaf }
        $assemblyReferences.Add([pscustomobject][ordered]@{ include = [string]$assembly.include; relativePath = [string]$assembly.relativePath; exists = $exists }) | Out-Null
    }

    $sourceRoot = Join-Path $RepoRoot 'src'
    if (Test-Path -LiteralPath $sourceRoot -PathType Container) {
        foreach ($file in Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Filter '*.cs' -ErrorAction SilentlyContinue) {
            $relative = Convert-TbgSafePath $file.FullName
            $lineNumber = 0
            foreach ($line in Get-Content -LiteralPath $file.FullName -Encoding UTF8) {
                $lineNumber++
                foreach ($pattern in @($registry.dynamicBindingPatterns)) {
                    if ($line.Contains([string]$pattern)) {
                        $snippet = $line.Trim(); if ($snippet.Length -gt 180) { $snippet = $snippet.Substring(0,180) }
                        $dynamicBindings.Add([pscustomobject][ordered]@{ file = $relative; line = $lineNumber; pattern = [string]$pattern; snippet = $snippet }) | Out-Null
                    }
                }
            }
        }
    }

    $candidateNativeVersion = if ([string]::IsNullOrWhiteSpace($CandidateGameRoot)) { $null } else { Get-TbgXmlModuleVersion (Join-Path $CandidateGameRoot 'Modules/Native/SubModule.xml') }
    $repoModulePath = Resolve-TbgRepoPath ([string]$registry.baseline.moduleManifest)
    if ($candidateNativeVersion -and (Test-Path -LiteralPath $repoModulePath -PathType Leaf)) {
        try {
            [xml]$moduleXml = Get-Content -LiteralPath $repoModulePath -Raw -Encoding UTF8
            foreach ($dependency in @($moduleXml.Module.DependedModules.DependedModule)) {
                $declared = [string]$dependency.DependentVersion
                if (-not [string]::IsNullOrWhiteSpace($declared) -and $declared -ne $candidateNativeVersion) {
                    $moduleDependencyDrift.Add([pscustomobject][ordered]@{ module = [string]$dependency.Id; declaredVersion = $declared; candidateVersion = $candidateNativeVersion }) | Out-Null
                }
            }
        } catch { }
    }

    $missingAssemblies = @($assemblyReferences | Where-Object { $_.exists -eq $false })
    if ($Mode -eq 'candidate' -and -not $NoBuild -and $missingAssemblies.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($CandidateGameRoot)) {
        $dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
        if ($null -eq $dotnet) { $compileReason = 'dotnet_not_available' }
        else {
            $compileAttempted = $true
            $projectPath = Resolve-TbgRepoPath ([string]$registry.baseline.sourceProject)
            $buildRoot = Join-Path $runRoot 'isolated-build'; $buildOutput = Join-Path $buildRoot 'bin'; $editorOutput = Join-Path $buildRoot 'weditor'
            Ensure-TbgDirectory $buildOutput; Ensure-TbgDirectory $editorOutput
            $arguments = @('build',$projectPath,'-c','Debug','--nologo',("-p:GameFolder={0}" -f $CandidateGameRoot),("-p:OutputPath={0}{1}" -f $buildOutput,[IO.Path]::DirectorySeparatorChar),("-p:WEditorOutputPath={0}{1}" -f $editorOutput,[IO.Path]::DirectorySeparatorChar))
            $buildLines = @(& $dotnet.Source @arguments 2>&1 | ForEach-Object { [string]$_ })
            $compileExitCode = $LASTEXITCODE
            $buildLines | Set-Content -LiteralPath $compilerLogPath -Encoding UTF8
            foreach ($buildLine in $buildLines) {
                if ($buildLine -match '^(?<file>.+?\.cs)\((?<line>[0-9]+),(?<column>[0-9]+)\):\s+error\s+(?<code>CS[0-9]+):\s+(?<message>.+?)(?:\s+\[.+\])?$') {
                    $compileErrors.Add([pscustomobject][ordered]@{ file = Convert-TbgSafePath $Matches.file; line = [int]$Matches.line; column = [int]$Matches.column; code = $Matches.code; message = $Matches.message.Trim() }) | Out-Null
                }
            }
            if ($compileExitCode -ne 0 -and $compileErrors.Count -eq 0) { $compileErrors.Add([pscustomobject][ordered]@{ file = 'src/BlacksmithGuild/BlacksmithGuild.csproj'; line = $null; column = $null; code = 'BUILD_FAILED'; message = 'Candidate build returned a nonzero exit code. Inspect candidate-build.log.' }) | Out-Null }
        }
    }
    elseif ($Mode -eq 'candidate' -and $NoBuild) { $compileReason = 'build_explicitly_skipped' }
}

$sourceInventory = [pscustomobject][ordered]@{ schema = 'TbgVersionUpgradeSourceInventory.v1'; generatedUtc = $generatedUtc; baselineVersion = $BaselineGameVersion; candidateVersion = $CandidateGameVersion; assemblyReferences = @($assemblyReferences.ToArray()); dynamicBindings = @($dynamicBindings.ToArray()); moduleDependencyDrift = @($moduleDependencyDrift.ToArray()) }
$sourceInventory | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $sourceInventoryPath -Encoding UTF8

$findings = [System.Collections.Generic.List[object]]::new()
foreach ($assembly in @($assemblyReferences.ToArray() | Where-Object { $_.exists -eq $false })) {
    $findings.Add((New-TbgFinding ('assembly-missing-' + ([string]$assembly.include).Replace('.','-').ToLowerInvariant()) 'candidate_assembly_presence' 'blocker' 'BLOCKED_CANDIDATE_ASSEMBLY_MISSING' 'harness/game-version-observation' ("Candidate game root is missing required assembly {0}." -f $assembly.include) @{ assembly = $assembly.include; relativePath = $assembly.relativePath } 'Resolve the candidate installation/layout or update the project reference contract before attempting a candidate build.')) | Out-Null
}
foreach ($error in @($compileErrors.ToArray())) {
    $safeFile = [string]$error.file; $owner = Resolve-TbgOwnerLane $safeFile $registry; $code = [string](Get-TbgPropertyValue $error 'code' 'BUILD_FAILED')
    $findings.Add((New-TbgFinding ('compile-' + $code.ToLowerInvariant() + '-' + $findings.Count) 'candidate_compile' 'blocker' 'BLOCKED_CANDIDATE_COMPILE_FAILURE' $owner ("Candidate compile failure {0} in {1}." -f $code,$safeFile) @{ file = $safeFile; line = (Get-TbgPropertyValue $error 'line'); code = $code; message = [string]$error.message } 'Repair the named API/source incompatibility against the candidate game assemblies, then rerun the candidate upgrade probe.')) | Out-Null
}
if ($Mode -eq 'candidate' -and -not $NoBuild -and @($assemblyReferences | Where-Object { $_.exists -eq $false }).Count -eq 0 -and -not $compileAttempted) {
    $findings.Add((New-TbgFinding 'candidate-build-not-attempted' 'candidate_compile' 'blocker' 'BLOCKED_CANDIDATE_COMPILE_FAILURE' 'implementation-completion' 'Candidate compile was required but did not run.' @{ reason = $compileReason } 'Restore dotnet/build prerequisites and rerun the candidate probe; do not promote compatibility without a candidate build.')) | Out-Null
}
foreach ($drift in @($moduleDependencyDrift.ToArray())) {
    $findings.Add((New-TbgFinding ('module-dependency-' + ([string]$drift.module).ToLowerInvariant()) 'module_dependency_drift' 'attention' 'ATTENTION_VERSION_CHANGE_REQUIRES_RECERTIFICATION' 'harness/game-version-observation' ("Tracked module dependency {0} declares {1} while candidate Native reports {2}." -f $drift.module,$drift.declaredVersion,$drift.candidateVersion) @{ module = $drift.module; declaredVersion = $drift.declaredVersion; candidateVersion = $drift.candidateVersion } 'Verify the candidate module dependency contract and update packaging metadata only in a dedicated compatibility sprint after evidence confirms the required version.')) | Out-Null
}
if ($versionChanged) {
    foreach ($binding in @($dynamicBindings.ToArray())) {
        $owner = Resolve-TbgOwnerLane ([string]$binding.file) $registry
        $findings.Add((New-TbgFinding ('dynamic-binding-' + $findings.Count) 'dynamic_binding_inventory' 'attention' 'ATTENTION_DYNAMIC_BINDING_REVIEW_REQUIRED' $owner ("Dynamic API binding requires candidate-version review in {0}:{1}." -f $binding.file,$binding.line) @{ file = $binding.file; line = $binding.line; pattern = $binding.pattern; snippet = $binding.snippet } 'Prove the reflected/Harmony/string-bound target against candidate metadata or a focused static/runtime contract; compile success alone is insufficient.')) | Out-Null
    }
    $findings.Add((New-TbgFinding 'save-reclassification-required' 'save_reclassification' 'attention' 'ATTENTION_VERSION_CHANGE_REQUIRES_RECERTIFICATION' 'harness/save-compatibility' ("Game version changed from {0} to {1}; prior save compatibility admission is stale." -f $BaselineGameVersion,$CandidateGameVersion) @{ baselineVersion = $BaselineGameVersion; candidateVersion = $CandidateGameVersion } ("Run .\ForgeSaveCompatibility.cmd -Mode catalog -GameVersion '{0}' and gate the exact intended save before launcher-lifecycle acts." -f $CandidateGameVersion))) | Out-Null
    $findings.Add((New-TbgFinding 'runtime-recertification-required' 'runtime_recertification' 'attention' 'ATTENTION_VERSION_CHANGE_REQUIRES_RECERTIFICATION' 'runtime-evidence-certification' ("Version-sensitive runtime certification is stale for candidate {0}." -f $CandidateGameVersion) @{ invalidatedFamilies = @($registry.runtimeCertFamiliesInvalidatedOnVersionChange) } 'After static/build and save gates pass, execute the canonical live-cert ladder on a separately authorized clean runtime session.')) | Out-Null
}

$blockers = @($findings | Where-Object severity -eq 'blocker')
$attentions = @($findings | Where-Object severity -eq 'attention')
$terminalState = if ($blockers.Count -gt 0) { 'BLOCKED_VERSION_UPGRADE_GAPS' } elseif ($Mode -eq 'inventory') { 'PASS_UPGRADE_BASELINE_INVENTORIED' } elseif ($versionChanged -or $attentions.Count -gt 0) { 'ATTENTION_VERSION_CHANGE_REQUIRES_RECERTIFICATION' } else { 'PASS_NO_ACTIONABLE_UPGRADE_GAPS' }

$laneOrder = @('harness/game-version-observation','implementation-completion','launcher-lifecycle','route-visible-trade','harness/save-compatibility','runtime-evidence-certification')
$sprintCandidates = [System.Collections.Generic.List[object]]::new()
foreach ($owner in $laneOrder) {
    $owned = @($findings | Where-Object { [string]$_.ownerLane -eq $owner }); if ($owned.Count -eq 0) { continue }
    $slug = ($owner -replace '[^A-Za-z0-9]+','-').Trim('-').ToLowerInvariant(); $candidateSlug = if ($CandidateGameVersion) { $CandidateGameVersion -replace '[^0-9A-Za-z]+','-' } else { 'unknown' }
    $dependency = switch ($owner) { 'harness/game-version-observation' { 'candidate version/build metadata observed' } 'implementation-completion' { 'candidate assembly presence resolved' } 'launcher-lifecycle' { 'candidate compile blockers repaired' } 'route-visible-trade' { 'candidate compile blockers repaired' } 'harness/save-compatibility' { 'candidate exact version resolved and compile blockers triaged' } 'runtime-evidence-certification' { 'candidate static/build gaps repaired and exact save gate re-certified' } default { 'candidate probe result available' } }
    $firstCommand = switch ($owner) { 'harness/save-compatibility' { ".\ForgeSaveCompatibility.cmd -Mode catalog -GameVersion '$CandidateGameVersion'" } 'runtime-evidence-certification' { '.\ForgeTest.cmd run --profile default-static' } default { '.\ForgeVersionUpgradeProbe.cmd -Mode candidate' } }
    $expectedArtifact = switch ($owner) { 'harness/save-compatibility' { 'artifacts/latest/save-compatibility/save-compatibility.result.json' } 'runtime-evidence-certification' { 'artifacts/latest/live-runtime-proof-admission/live-runtime-proof-admission.result.json plus a later authorized fresh live packet' } default { 'artifacts/latest/version-upgrade-impact/version-upgrade-impact.result.json' } }
    $completionGate = switch ($owner) { 'harness/game-version-observation' { 'candidate assembly/dependency findings for this lane are cleared or replaced by a newer evidence-backed classification' } 'harness/save-compatibility' { 'the intended save has a fresh candidate-version gate result and incompatible saves remain blocked' } 'runtime-evidence-certification' { 'all static/build/save prerequisites pass and a later clean runtime run re-proves each invalidated certification family' } default { 'all findings assigned to this owner lane are absent or pass on a rerun against the same candidate version' } }
    $sprintCandidates.Add([pscustomobject][ordered]@{ id = "upgrade-$candidateSlug-$slug"; owner = $owner; dependency = $dependency; mission = ("Resolve {0} version-upgrade finding(s) for {1} against Bannerlord {2}." -f $owned.Count,$owner,$CandidateGameVersion); findingIds = @($owned | ForEach-Object { $_.id }); firstCommand = $firstCommand; expectedArtifact = $expectedArtifact; completionGate = $completionGate }) | Out-Null
}

$proofCeiling = 'candidate static/build compatibility'
$candidateBuild = [pscustomobject][ordered]@{ attempted = [bool]$compileAttempted; exitCode = $compileExitCode; reason = $compileReason; errorCount = $compileErrors.Count; log = if (Test-Path -LiteralPath $compilerLogPath -PathType Leaf) { $compilerLogPath } else { $null } }
$evidencePaths = [ordered]@{ result = $resultPath; report = $reportPath; sprintPacket = $sprintPacketPath; issueDraft = $issueDraftPath; sourceInventory = $sourceInventoryPath; compilerLog = if (Test-Path -LiteralPath $compilerLogPath -PathType Leaf) { $compilerLogPath } else { $null } }
$result = [pscustomobject][ordered]@{ schema = 'TbgVersionUpgradeImpactResult.v1'; generatedUtc = $generatedUtc; runId = $runId; mode = $Mode; baselineVersion = $BaselineGameVersion; candidateVersion = $CandidateGameVersion; versionChanged = [bool]$versionChanged; terminalState = $terminalState; proofCeiling = $proofCeiling; candidateBuild = $candidateBuild; findings = @($findings.ToArray()); sprintCandidates = @($sprintCandidates.ToArray()); evidencePaths = $evidencePaths }
$result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resultPath -Encoding UTF8

$sprintPacket = [pscustomobject][ordered]@{ schema = 'TbgVersionUpgradeSprintPacket.v1'; generatedUtc = $generatedUtc; sourceRunId = $runId; baselineVersion = $BaselineGameVersion; candidateVersion = $CandidateGameVersion; terminalState = $terminalState; dependencyOrder = @($sprintCandidates | ForEach-Object { $_.id }); sprints = @($sprintCandidates.ToArray()); proofCeiling = $proofCeiling }
$sprintPacket | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $sprintPacketPath -Encoding UTF8

$report = [System.Collections.Generic.List[string]]::new()
$report.Add('# Version upgrade impact report') | Out-Null; $report.Add('') | Out-Null; $report.Add('## Upgrade verdict') | Out-Null
$report.Add(('- Baseline version: `{0}`' -f $BaselineGameVersion)) | Out-Null
$report.Add(('- Candidate version: `{0}`' -f $CandidateGameVersion)) | Out-Null
$report.Add(('- Version changed: `{0}`' -f $versionChanged)) | Out-Null
$report.Add(('- Terminal state: `{0}`' -f $terminalState)) | Out-Null
$report.Add(('- Proof ceiling: `{0}`' -f $proofCeiling)) | Out-Null
$report.Add('') | Out-Null; $report.Add('## Probe findings') | Out-Null
if ($findings.Count -eq 0) { $report.Add('- None.') | Out-Null }
foreach ($finding in @($findings.ToArray())) { $report.Add(('- **{0}** `{1}` -> `{2}`: {3}' -f $finding.severity,$finding.probeFamily,$finding.ownerLane,$finding.summary)) | Out-Null }
$report.Add('') | Out-Null; $report.Add('## Actionable sprints') | Out-Null
if ($sprintCandidates.Count -eq 0) { $report.Add('- None.') | Out-Null }
foreach ($sprint in @($sprintCandidates.ToArray())) {
    $report.Add(('### {0}' -f $sprint.id)) | Out-Null; $report.Add(('- Owner: `{0}`' -f $sprint.owner)) | Out-Null; $report.Add(('- Dependency: {0}' -f $sprint.dependency)) | Out-Null; $report.Add(('- First command: `{0}`' -f $sprint.firstCommand)) | Out-Null; $report.Add(('- Expected artifact: {0}' -f $sprint.expectedArtifact)) | Out-Null; $report.Add(('- Completion gate: {0}' -f $sprint.completionGate)) | Out-Null
}
$report.Add('') | Out-Null; $report.Add('## Claims not made') | Out-Null; $report.Add('- Compile success does not prove reflected/Harmony targets still bind.') | Out-Null; $report.Add('- Static/build success does not prove save load, launcher flow, campaign readiness, governor/trade behavior, or live runtime compatibility.') | Out-Null; $report.Add('- This probe never launches or updates Bannerlord and never installs the mod.') | Out-Null
$report | Set-Content -LiteralPath $reportPath -Encoding UTF8

$title = 'Version upgrade probe: Bannerlord {0} -> {1}' -f $BaselineGameVersion,$CandidateGameVersion
$issue = [System.Collections.Generic.List[string]]::new(); $issue.Add(('# {0}' -f $title)) | Out-Null; $issue.Add('') | Out-Null; $issue.Add(('Candidate version: `{0}`' -f $CandidateGameVersion)) | Out-Null; $issue.Add(('Probe state: `{0}`' -f $terminalState)) | Out-Null; $issue.Add(('Proof ceiling: `{0}`' -f $proofCeiling)) | Out-Null; $issue.Add('') | Out-Null; $issue.Add('## Findings') | Out-Null
if ($findings.Count -eq 0) { $issue.Add('- No actionable findings.') | Out-Null }
foreach ($finding in @($findings.ToArray())) { $issue.Add(('- [{0}] **{1}** - {2}' -f $finding.severity,$finding.ownerLane,$finding.summary)) | Out-Null }
$issue.Add('') | Out-Null; $issue.Add('## Actionable sprint order') | Out-Null
foreach ($sprint in @($sprintCandidates.ToArray())) {
    $issue.Add(('### {0}' -f $sprint.id)) | Out-Null; $issue.Add(('- Owner: `{0}`' -f $sprint.owner)) | Out-Null; $issue.Add(('- Dependency: {0}' -f $sprint.dependency)) | Out-Null; $issue.Add(('- Mission: {0}' -f $sprint.mission)) | Out-Null; $issue.Add(('- First command: `{0}`' -f $sprint.firstCommand)) | Out-Null; $issue.Add(('- Expected artifact: {0}' -f $sprint.expectedArtifact)) | Out-Null; $issue.Add(('- Completion gate: {0}' -f $sprint.completionGate)) | Out-Null
}
$issue.Add('') | Out-Null; $issue.Add('## Safety boundary') | Out-Null; $issue.Add('This issue was generated from sanitized static/build evidence. It authorizes no game launch, save mutation, mod install, runtime action, or proof promotion.') | Out-Null
$issue | Set-Content -LiteralPath $issueDraftPath -Encoding UTF8

Ensure-TbgDirectory $outputRoot
Copy-Item -LiteralPath $resultPath -Destination (Join-Path $outputRoot 'version-upgrade-impact.result.json') -Force
Copy-Item -LiteralPath $reportPath -Destination (Join-Path $outputRoot 'version-upgrade-impact.report.md') -Force
Copy-Item -LiteralPath $sprintPacketPath -Destination (Join-Path $outputRoot 'version-upgrade-impact.sprint-packet.json') -Force
Copy-Item -LiteralPath $issueDraftPath -Destination (Join-Path $outputRoot 'version-upgrade-impact.issue.md') -Force
Copy-Item -LiteralPath $sourceInventoryPath -Destination (Join-Path $outputRoot 'version-upgrade-impact.source-inventory.json') -Force

Write-Host ('Version upgrade impact: {0}' -f $terminalState); Write-Host ('Baseline: {0}' -f $BaselineGameVersion); Write-Host ('Candidate: {0}' -f $CandidateGameVersion); Write-Host ('Findings: {0}' -f $findings.Count); Write-Host ('Sprints: {0}' -f $sprintCandidates.Count); Write-Host ('Result: {0}' -f $resultPath); Write-Host ('Issue draft: {0}' -f $issueDraftPath)
if ($PassThru) { $result }
if (-not $NoExit) { $exitCode = if ($terminalState -like 'PASS_*') { 0 } elseif ($terminalState -like 'ATTENTION_*') { 2 } else { 3 }; exit $exitCode }
