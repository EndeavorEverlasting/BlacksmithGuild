[CmdletBinding()]
param(
    [ValidateSet('catalog','gate')][string]$Mode = 'catalog',
    [string[]]$SavePath = @(),
    [string]$TargetSavePath = '',
    [string]$GameVersion = '',
    [string]$RepoRoot = '',
    [string]$RegistryPath = '.tbg/state/save-compatibility.registry.json',
    [string]$GameCompatibilityResultPath = 'artifacts/latest/game-compatibility/game-compatibility.result.json',
    [string]$OutputDirectory = 'artifacts/latest/save-compatibility',
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

function Normalize-TbgExactVersion {
    param([AllowNull()][string]$Version)
    if ([string]::IsNullOrWhiteSpace($Version)) { return $null }
    $value = $Version.Trim()
    if ($value.StartsWith('v', [StringComparison]::OrdinalIgnoreCase)) { $value = $value.Substring(1) }
    if ($value -notmatch '^(?<a>[0-9]+)\.(?<b>[0-9]+)\.(?<c>[0-9]+)\.(?<d>[0-9]+)') { return $null }
    return '{0}.{1}.{2}.{3}' -f $Matches.a, $Matches.b, $Matches.c, $Matches.d
}

function Get-TbgSaveSha256 {
    param([Parameter(Mandatory = $true)][string]$LiteralPath)
    $stream = [IO.File]::Open($LiteralPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToUpperInvariant() }
        finally { $sha.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Read-TbgSaveHeaderBytes {
    param([Parameter(Mandatory = $true)][string]$LiteralPath, [Parameter(Mandatory = $true)][int]$MaximumBytes)
    $stream = [IO.File]::Open($LiteralPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try {
        $count = [Math]::Min([long]$MaximumBytes, $stream.Length)
        $buffer = New-Object byte[] ([int]$count)
        $read = $stream.Read($buffer, 0, $buffer.Length)
        if ($read -eq $buffer.Length) { return $buffer }
        if ($read -le 0) { return [byte[]]@() }
        $trimmed = New-Object byte[] $read
        [Array]::Copy($buffer, $trimmed, $read)
        return $trimmed
    }
    finally { $stream.Dispose() }
}

function Get-TbgDistinctVersionMatches {
    param([Parameter(Mandatory = $true)][string[]]$Texts, [Parameter(Mandatory = $true)][string]$Pattern)
    $versions = New-Object System.Collections.Generic.List[string]
    foreach ($text in $Texts) {
        foreach ($match in [regex]::Matches($text, $Pattern)) {
            $candidate = Normalize-TbgExactVersion -Version ([string]$match.Groups['version'].Value)
            if ($candidate -and -not $versions.Contains($candidate)) { $versions.Add($candidate) | Out-Null }
        }
    }
    return @($versions.ToArray())
}

function Get-TbgParsedSaveVersion {
    param([Parameter(Mandatory = $true)][string]$LiteralPath, [Parameter(Mandatory = $true)]$Registry)
    $bytes = Read-TbgSaveHeaderBytes -LiteralPath $LiteralPath -MaximumBytes ([int]$Registry.scan.maxHeaderBytes)
    $texts = @(
        [Text.Encoding]::ASCII.GetString($bytes),
        [Text.Encoding]::Unicode.GetString($bytes)
    )
    $tagged = @(Get-TbgDistinctVersionMatches -Texts $texts -Pattern ([string]$Registry.scan.taggedVersionRegex))
    $all = @(Get-TbgDistinctVersionMatches -Texts $texts -Pattern ([string]$Registry.scan.versionRegex))
    $selected = $null
    $status = 'unknown'
    if ($tagged.Count -eq 1) { $selected = $tagged[0]; $status = 'parsed_tagged' }
    elseif ($tagged.Count -gt 1) { $status = 'ambiguous' }
    elseif ($all.Count -eq 1) { $selected = $all[0]; $status = 'parsed_unique' }
    elseif ($all.Count -gt 1) { $status = 'ambiguous' }
    [pscustomobject][ordered]@{
        status = $status
        version = $selected
        taggedCandidates = $tagged
        candidates = $all
        bytesScanned = $bytes.Length
    }
}

function Get-TbgSaveRole {
    param([Parameter(Mandatory = $true)][string]$LeafName, [Parameter(Mandatory = $true)]$Registry)
    if (@($Registry.roles.approvedAliases) -contains $LeafName) { return 'approved_alias' }
    if ($LeafName -match [string]$Registry.roles.autosaveRegex) { return 'autosave' }
    if ($LeafName -match [string]$Registry.roles.disposableNameRegex) { return 'disposable_candidate' }
    return [string]$Registry.roles.defaultRole
}

function Compare-TbgSaveToGameVersion {
    param([AllowNull()][string]$SaveVersion, [AllowNull()][string]$ExactGameVersion, [string]$ParseStatus)
    if ($ParseStatus -eq 'ambiguous') {
        return [pscustomobject]@{ compatibility = 'ambiguous'; terminalState = 'BLOCKED_SAVE_VERSION_AMBIGUOUS' }
    }
    if ([string]::IsNullOrWhiteSpace($SaveVersion)) {
        return [pscustomobject]@{ compatibility = 'unknown'; terminalState = 'BLOCKED_SAVE_VERSION_UNKNOWN' }
    }
    if ([string]::IsNullOrWhiteSpace($ExactGameVersion)) {
        return [pscustomobject]@{ compatibility = 'game_unknown'; terminalState = 'BLOCKED_GAME_VERSION_UNKNOWN' }
    }
    $save = [version]$SaveVersion
    $game = [version]$ExactGameVersion
    $cmp = $save.CompareTo($game)
    if ($cmp -eq 0) { return [pscustomobject]@{ compatibility = 'exact'; terminalState = 'PASS_SAVE_VERSION_EXACT' } }
    if ($cmp -gt 0) { return [pscustomobject]@{ compatibility = 'newer'; terminalState = 'BLOCKED_SAVE_NEWER_THAN_GAME' } }
    return [pscustomobject]@{ compatibility = 'older'; terminalState = 'ATTENTION_SAVE_OLDER_THAN_GAME_RECERTIFY' }
}

$registryFullPath = Resolve-TbgRepoPath -Path $RegistryPath
if (-not (Test-Path -LiteralPath $registryFullPath -PathType Leaf)) { throw "Save compatibility registry missing: $registryFullPath" }
$registry = Get-Content -LiteralPath $registryFullPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop

if ([string]::IsNullOrWhiteSpace($GameVersion)) {
    $gameResultPath = Resolve-TbgRepoPath -Path $GameCompatibilityResultPath
    if (Test-Path -LiteralPath $gameResultPath -PathType Leaf) {
        $gameResult = Get-Content -LiteralPath $gameResultPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
        $installed = Get-TbgPropertyValue -Object $gameResult -Name 'locallyInstalledBuild'
        $GameVersion = [string](Get-TbgPropertyValue -Object $installed -Name 'gameExecutableVersion' -Default '')
        if ([string]::IsNullOrWhiteSpace($GameVersion)) {
            $GameVersion = [string](Get-TbgPropertyValue -Object $installed -Name 'nativeModuleVersion' -Default '')
        }
    }
}
$exactGameVersion = Normalize-TbgExactVersion -Version $GameVersion

$paths = New-Object System.Collections.Generic.List[string]
foreach ($candidate in @($SavePath)) {
    if (-not [string]::IsNullOrWhiteSpace($candidate)) { $paths.Add([IO.Path]::GetFullPath($candidate)) | Out-Null }
}
if (-not [string]::IsNullOrWhiteSpace($TargetSavePath)) {
    $targetFull = [IO.Path]::GetFullPath($TargetSavePath)
    if (-not $paths.Contains($targetFull)) { $paths.Add($targetFull) | Out-Null }
}
if ($paths.Count -eq 0) {
    $documents = [Environment]::GetFolderPath('MyDocuments')
    foreach ($segments in @(
        @('Mount and Blade II Bannerlord','Game Saves'),
        @('Mount and Blade II Bannerlord','Game Saves','Native')
    )) {
        $root = $documents
        foreach ($segment in $segments) { $root = Join-Path $root $segment }
        if (Test-Path -LiteralPath $root -PathType Container) {
            foreach ($file in Get-ChildItem -LiteralPath $root -Filter '*.sav' -File -ErrorAction SilentlyContinue) {
                if (-not $paths.Contains($file.FullName)) { $paths.Add($file.FullName) | Out-Null }
            }
        }
    }
}

$generatedUtc = [DateTime]::UtcNow.ToString('o')
$runId = 'save-compatibility-{0}-{1}' -f ([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')), ([Guid]::NewGuid().ToString('N').Substring(0,6))
$outputRoot = Resolve-TbgRepoPath -Path $OutputDirectory
$runRoot = Join-Path (Join-Path $outputRoot 'runs') $runId
Ensure-TbgDirectory -Path $runRoot
$eventsPath = Join-Path $runRoot 'events.jsonl'

function Add-TbgEvent {
    param([Parameter(Mandatory = $true)][string]$Type, [Parameter(Mandatory = $true)][string]$Message, $Data)
    $event = [ordered]@{ schema = 'TbgSaveCompatibilityEvent.v1'; timestampUtc = [DateTime]::UtcNow.ToString('o'); eventType = $Type; message = $Message; data = $Data }
    ($event | ConvertTo-Json -Depth 10 -Compress) | Add-Content -LiteralPath $eventsPath -Encoding UTF8
}

Add-TbgEvent -Type 'inspection.started' -Message 'Read-only save compatibility inspection started.' -Data @{ mode = $Mode; gameVersion = $exactGameVersion; saveCount = $paths.Count }

$records = New-Object System.Collections.Generic.List[object]
foreach ($path in @($paths.ToArray())) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $record = [pscustomobject][ordered]@{ path = $path; leafName = [IO.Path]::GetFileName($path); exists = $false; role = 'unknown'; length = $null; sha256 = $null; lastWriteUtc = $null; parseStatus = 'missing'; parsedSaveVersion = $null; versionCandidates = @(); compatibility = 'missing'; terminalState = 'BLOCKED_SAVE_NOT_FOUND'; autoLoadEligible = $false }
        $records.Add($record) | Out-Null
        Add-TbgEvent -Type 'save.observed' -Message "Save missing: $($record.leafName)" -Data $record
        continue
    }
    $before = Get-Item -LiteralPath $path
    $beforeWrite = $before.LastWriteTimeUtc
    $beforeLength = [long]$before.Length
    $beforeHash = Get-TbgSaveSha256 -LiteralPath $path
    $parsed = Get-TbgParsedSaveVersion -LiteralPath $path -Registry $registry
    $role = Get-TbgSaveRole -LeafName $before.Name -Registry $registry
    $comparison = Compare-TbgSaveToGameVersion -SaveVersion $parsed.version -ExactGameVersion $exactGameVersion -ParseStatus $parsed.status
    $roleEligible = @('approved_alias','disposable_candidate') -contains $role
    $autoLoadEligible = ($comparison.terminalState -eq 'PASS_SAVE_VERSION_EXACT') -and $roleEligible
    $after = Get-Item -LiteralPath $path
    $afterHash = Get-TbgSaveSha256 -LiteralPath $path
    if ($after.LastWriteTimeUtc -ne $beforeWrite -or [long]$after.Length -ne $beforeLength -or $afterHash -ne $beforeHash) {
        throw "Read-only contract violated while inspecting $($before.Name): bytes, length, or write timestamp changed."
    }
    $record = [pscustomobject][ordered]@{
        path = $path
        leafName = $before.Name
        exists = $true
        role = $role
        length = $beforeLength
        sha256 = $beforeHash
        lastWriteUtc = $beforeWrite.ToString('o')
        parseStatus = $parsed.status
        parsedSaveVersion = $parsed.version
        versionCandidates = @($parsed.candidates)
        taggedVersionCandidates = @($parsed.taggedCandidates)
        bytesScanned = [int]$parsed.bytesScanned
        compatibility = [string]$comparison.compatibility
        terminalState = [string]$comparison.terminalState
        autoLoadEligible = [bool]$autoLoadEligible
    }
    $records.Add($record) | Out-Null
    Add-TbgEvent -Type 'save.observed' -Message "Classified $($record.leafName) as $($record.terminalState)." -Data $record
}

$left = @($records | Where-Object { $_.leafName -eq 'BlacksmithGuildDevStart.sav' -and $_.exists } | Select-Object -First 1)
$right = @($records | Where-Object { $_.leafName -eq 'BlacksmithGuild_DevStart.sav' -and $_.exists } | Select-Object -First 1)
$pairState = 'not_present'
$pairIdentical = $null
if ($left.Count -gt 0 -or $right.Count -gt 0) {
    if ($left.Count -eq 0 -or $right.Count -eq 0) {
        $pairState = 'ATTENTION_APPROVED_ALIAS_PAIR_INCOMPLETE'
        $pairIdentical = $false
    }
    else {
        $pairIdentical = ([string]$left[0].sha256 -eq [string]$right[0].sha256) -and ([long]$left[0].length -eq [long]$right[0].length) -and ([string]$left[0].parsedSaveVersion -eq [string]$right[0].parsedSaveVersion)
        $pairState = if ($pairIdentical) { 'PASS_APPROVED_ALIAS_PAIR_IDENTICAL' } else { 'BLOCKED_APPROVED_ALIAS_PAIR_MISMATCH' }
        if (-not $pairIdentical) {
            $left[0].autoLoadEligible = $false
            $right[0].autoLoadEligible = $false
        }
    }
}
$pair = [pscustomobject][ordered]@{ terminalState = $pairState; byteIdentical = $pairIdentical; logicalAlias = if ($left.Count) { $left[0].leafName } else { $null }; nativeAlias = if ($right.Count) { $right[0].leafName } else { $null }; sha256 = if ($pairIdentical -eq $true) { $left[0].sha256 } else { $null }; parsedSaveVersion = if ($pairIdentical -eq $true) { $left[0].parsedSaveVersion } else { $null } }

$eligibleTargets = @($records | Where-Object { $_.autoLoadEligible -eq $true } | ForEach-Object { $_.leafName })
$targetGateState = $null
if ($Mode -eq 'gate') {
    if ([string]::IsNullOrWhiteSpace($TargetSavePath)) { $targetGateState = 'BLOCKED_SAVE_NOT_FOUND' }
    else {
        $targetFull = [IO.Path]::GetFullPath($TargetSavePath)
        $target = @($records | Where-Object { $_.path -eq $targetFull } | Select-Object -First 1)
        $targetGateState = if ($target.Count -eq 0) { 'BLOCKED_SAVE_NOT_FOUND' } else { [string]$target[0].terminalState }
        if ($target.Count -gt 0 -and $target[0].role -eq 'approved_alias' -and $pairState -eq 'BLOCKED_APPROVED_ALIAS_PAIR_MISMATCH') { $targetGateState = $pairState }
        elseif ($target.Count -gt 0 -and $target[0].role -eq 'approved_alias' -and $pairState -eq 'ATTENTION_APPROVED_ALIAS_PAIR_INCOMPLETE') { $targetGateState = $pairState }
        elseif ($target.Count -gt 0 -and $targetGateState -eq 'PASS_SAVE_VERSION_EXACT' -and -not $target[0].autoLoadEligible) { $targetGateState = 'BLOCKED_SAVE_ROLE_NOT_AUTOMATION_ELIGIBLE' }
    }
}

$terminalState = if ($Mode -eq 'catalog') { 'PASS_SAVE_CATALOG_CLASSIFIED' } else { $targetGateState }
$proofCeiling = 'real-file read-only parsing'
$result = [pscustomobject][ordered]@{
    schema = 'TbgSaveCompatibilityResult.v1'
    generatedUtc = $generatedUtc
    runId = $runId
    mode = $Mode
    gameVersion = $exactGameVersion
    terminalState = $terminalState
    proofCeiling = $proofCeiling
    saveRecords = @($records.ToArray())
    approvedAliasPair = $pair
    eligibleTargets = $eligibleTargets
    targetSavePath = if ($Mode -eq 'gate') { $TargetSavePath } else { $null }
    targetGateTerminalState = $targetGateState
    evidencePaths = [ordered]@{
        result = Join-Path $runRoot 'save-compatibility.result.json'
        report = Join-Path $runRoot 'save-compatibility.report.md'
        events = $eventsPath
    }
}

$resultPath = [string]$result.evidencePaths.result
$reportPath = [string]$result.evidencePaths.report
$result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resultPath -Encoding UTF8
$reportLines = New-Object System.Collections.Generic.List[string]
$reportLines.Add('# Save compatibility report') | Out-Null
$reportLines.Add('') | Out-Null
$reportLines.Add(('- Terminal state: `{0}`' -f $terminalState)) | Out-Null
$reportLines.Add(('- Mode: `{0}`' -f $Mode)) | Out-Null
$reportLines.Add(('- Game version: `{0}`' -f $exactGameVersion)) | Out-Null
$reportLines.Add(('- Proof ceiling: `{0}`' -f $proofCeiling)) | Out-Null
$reportLines.Add(('- Approved alias pair: `{0}`' -f $pairState)) | Out-Null
$reportLines.Add('') | Out-Null
$reportLines.Add('## Save classifications') | Out-Null
foreach ($record in @($records.ToArray())) {
    $reportLines.Add(('- `{0}`: role=`{1}` saveVersion=`{2}` state=`{3}` sha256=`{4}`' -f $record.leafName, $record.role, $record.parsedSaveVersion, $record.terminalState, $record.sha256)) | Out-Null
}
$reportLines.Add('') | Out-Null
$reportLines.Add('## Next executable gate') | Out-Null
if ($Mode -eq 'catalog') {
    $reportLines.Add('Select an explicit save and run this classifier in gate mode before launcher-lifecycle acts on it.') | Out-Null
}
elseif ($terminalState -eq 'PASS_SAVE_VERSION_EXACT') {
    $reportLines.Add('Launcher-lifecycle may consume this prelaunch gate, but must still prove the exact in-game save load boundary in the same run.') | Out-Null
}
else {
    $reportLines.Add('Do not launch this target save. Repair or select a compatible classified save, then rerun gate mode.') | Out-Null
}
$reportLines | Set-Content -LiteralPath $reportPath -Encoding UTF8

Ensure-TbgDirectory -Path $outputRoot
Copy-Item -LiteralPath $resultPath -Destination (Join-Path $outputRoot 'save-compatibility.result.json') -Force
Copy-Item -LiteralPath $reportPath -Destination (Join-Path $outputRoot 'save-compatibility.report.md') -Force
Add-TbgEvent -Type 'classification.completed' -Message "Save compatibility classification completed as $terminalState." -Data @{ terminalState = $terminalState; eligibleTargets = $eligibleTargets }

Write-Host "Save compatibility: $terminalState"
Write-Host "Game version: $exactGameVersion"
Write-Host "Result: $resultPath"
Write-Host "Report: $reportPath"

if ($PassThru) { $result }
if (-not $NoExit) {
    $exitCode = if ($terminalState -like 'PASS_*') { 0 } elseif ($terminalState -like 'ATTENTION_*') { 2 } else { 3 }
    exit $exitCode
}
