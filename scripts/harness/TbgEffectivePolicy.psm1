Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-TbgProperty {
    param(
        [AllowNull()][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if ($null -eq $Object) { return $false }
    if ($Object -is [System.Collections.IDictionary]) { return $Object.Contains($Name) }
    return $null -ne $Object.PSObject.Properties[$Name]
}

function Get-TbgPropertyValue {
    param(
        [AllowNull()][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [AllowNull()][object]$Default = $null
    )

    if ($null -eq $Object) { return $Default }
    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) { return $Object[$Name] }
        return $Default
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { return $Default }
    return $property.Value
}

function ConvertTo-TbgBoolean {
    param(
        [AllowNull()][object]$Value,
        [bool]$Default = $false
    )

    if ($null -eq $Value) { return $Default }
    if ($Value -is [bool]) { return $Value }
    try { return [System.Convert]::ToBoolean($Value) }
    catch { return $Default }
}

function Resolve-TbgRepoRoot {
    param([string]$RepoRoot = '')

    $candidates = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
        $candidates.Add($RepoRoot)
    }
    else {
        $candidates.Add((Get-Location).Path)
        $candidates.Add((Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
    }

    foreach ($candidate in $candidates) {
        $cursor = [System.IO.Path]::GetFullPath($candidate)
        while (-not [string]::IsNullOrWhiteSpace($cursor)) {
            if (Test-Path -LiteralPath (Join-Path $cursor '.tbg/harness/manifest.json') -PathType Leaf) {
                return $cursor
            }

            $parent = Split-Path -Parent $cursor
            if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $cursor) { break }
            $cursor = $parent
        }
    }

    throw 'Could not locate .tbg/harness/manifest.json.'
}

function Read-TbgJsonFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Label is missing: $Path"
    }

    try { return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
    catch { throw "$Label is invalid JSON: $Path; $($_.Exception.Message)" }
}

function Add-TbgUniqueString {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$List,
        [AllowNull()][object[]]$Values
    )

    foreach ($value in @($Values)) {
        if ($null -eq $value) { continue }
        $text = [string]$value
        if ([string]::IsNullOrWhiteSpace($text)) { continue }
        if (-not $List.Contains($text)) { $List.Add($text) }
    }
}

function Get-TbgMapValues {
    param(
        [AllowNull()][object]$Map,
        [Parameter(Mandatory = $true)][string]$Key
    )

    if (-not (Test-TbgProperty -Object $Map -Name $Key)) { return @() }
    return @(Get-TbgPropertyValue -Object $Map -Name $Key)
}

function Get-TbgRowType {
    param(
        [AllowNull()][object]$InputObject,
        [string]$RequestedType
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedType) -and $RequestedType -ne 'auto') {
        return $RequestedType.ToLowerInvariant()
    }
    if ($null -eq $InputObject) { return 'profile' }

    $declared = [string](Get-TbgPropertyValue -Object $InputObject -Name 'rowType' -Default '')
    if (-not [string]::IsNullOrWhiteSpace($declared)) { return $declared.ToLowerInvariant() }

    $hook = [string](Get-TbgPropertyValue -Object $InputObject -Name 'hook' -Default '')
    if (-not [string]::IsNullOrWhiteSpace($hook)) { return $hook.ToLowerInvariant() }
    if (Test-TbgProperty -Object $InputObject -Name 'reviewSummary') { return 'review' }
    if (Test-TbgProperty -Object $InputObject -Name 'auditFinding') { return 'policy-audit' }

    $schema = [string](Get-TbgPropertyValue -Object $InputObject -Name 'schema' -Default '')
    if ($schema -eq 'tbg.workflow-contract.v1') { return 'workflow-contract' }
    return 'result'
}

function Test-TbgPatternMatch {
    param(
        [string]$Text,
        [object[]]$Patterns
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    foreach ($pattern in @($Patterns)) {
        if ($Text -match [string]$pattern) { return $true }
    }
    return $false
}

function Get-TbgEffectivePolicyContext {
    [CmdletBinding()]
    param(
        [string]$ProfileId = '',
        [AllowNull()][object]$InputObject = $null,
        [ValidateSet('auto', 'profile', 'result', 'review', 'policy-audit', 'workflow-contract', 'command-safety', 'file-safety')]
        [string]$RowType = 'auto',
        [string]$RepoRoot = ''
    )

    $root = Resolve-TbgRepoRoot -RepoRoot $RepoRoot
    $manifestRelative = '.tbg/harness/manifest.json'
    $manifest = Read-TbgJsonFile -Path (Join-Path $root $manifestRelative) -Label 'Harness manifest'

    if ([string]::IsNullOrWhiteSpace($ProfileId)) {
        $ProfileId = [string](Get-TbgPropertyValue -Object $manifest -Name 'defaultContractId' -Default '')
    }
    if ([string]::IsNullOrWhiteSpace($ProfileId)) { throw 'ProfileId is required because the manifest has no defaultContractId.' }

    $contractRelative = ".tbg/workflows/$ProfileId.contract.json"
    $contract = Read-TbgJsonFile -Path (Join-Path $root $contractRelative) -Label "Workflow contract '$ProfileId'"
    $manifestPaths = Get-TbgPropertyValue -Object $manifest -Name 'paths'
    $policyRoot = [string](Get-TbgPropertyValue -Object $manifestPaths -Name 'policies' -Default '.tbg/harness/policies')
    $reportingRelative = [string](Get-TbgPropertyValue -Object $manifestPaths -Name 'reportingPolicy' -Default "$policyRoot/policy-reporting.policy.json")

    $policyRelatives = [ordered]@{
        reporting = $reportingRelative
        command = "$policyRoot/command-safety.policy.json"
        file = "$policyRoot/file-safety.policy.json"
        runtime = "$policyRoot/runtime-scope.policy.json"
        evidence = "$policyRoot/evidence-gates.policy.json"
    }
    $reportingPolicy = Read-TbgJsonFile -Path (Join-Path $root $policyRelatives.reporting) -Label 'Policy reporting policy'
    $commandPolicy = Read-TbgJsonFile -Path (Join-Path $root $policyRelatives.command) -Label 'Command safety policy'
    $filePolicy = Read-TbgJsonFile -Path (Join-Path $root $policyRelatives.file) -Label 'File safety policy'
    $runtimePolicy = Read-TbgJsonFile -Path (Join-Path $root $policyRelatives.runtime) -Label 'Runtime scope policy'
    $evidencePolicy = Read-TbgJsonFile -Path (Join-Path $root $policyRelatives.evidence) -Label 'Evidence gates policy'

    $workflowId = [string](Get-TbgPropertyValue -Object $contract -Name 'id' -Default '')
    if ([string]::IsNullOrWhiteSpace($workflowId)) {
        $workflowId = [string](Get-TbgPropertyValue -Object $contract -Name 'workflow' -Default $ProfileId)
    }

    $allowedByContract = Get-TbgPropertyValue -Object $commandPolicy -Name 'allowPatternsByContract'
    $allowedCommands = @(Get-TbgMapValues -Map $allowedByContract -Key $ProfileId)
    $deniedCommands = @(Get-TbgPropertyValue -Object $commandPolicy -Name 'denyPatterns' -Default @())
    $requiresStopPatterns = @(Get-TbgPropertyValue -Object $commandPolicy -Name 'requiresForgeStopFirst' -Default @())

    $requiresInactiveRuntime = $false
    if (Test-TbgProperty -Object $contract -Name 'requiresInactiveRuntime') {
        $requiresInactiveRuntime = ConvertTo-TbgBoolean (Get-TbgPropertyValue -Object $contract -Name 'requiresInactiveRuntime')
    }
    elseif (Test-TbgProperty -Object $contract -Name 'requiresInactiveGame') {
        $requiresInactiveRuntime = ConvertTo-TbgBoolean (Get-TbgPropertyValue -Object $contract -Name 'requiresInactiveGame')
    }

    $sourceFiles = New-Object System.Collections.Generic.List[string]
    Add-TbgUniqueString -List $sourceFiles -Values @($manifestRelative, $contractRelative)
    Add-TbgUniqueString -List $sourceFiles -Values @($policyRelatives.Values)

    $guardrailRelative = [string](Get-TbgPropertyValue -Object $contract -Name 'runtimeStateGuardrail' -Default '')
    if (-not [string]::IsNullOrWhiteSpace($guardrailRelative)) {
        $guardrailPath = Join-Path $root $guardrailRelative
        if (Test-Path -LiteralPath $guardrailPath -PathType Leaf) {
            $guardrail = Read-TbgJsonFile -Path $guardrailPath -Label 'Runtime state guardrail'
            Add-TbgUniqueString -List $sourceFiles -Values @($guardrailRelative)
            $intents = Get-TbgPropertyValue -Object $guardrail -Name 'intents'
            $intent = Get-TbgPropertyValue -Object $intents -Name $workflowId
            if ($null -ne $intent -and (Test-TbgProperty -Object $intent -Name 'requiresInactiveGame')) {
                $requiresInactiveRuntime = ConvertTo-TbgBoolean (Get-TbgPropertyValue -Object $intent -Name 'requiresInactiveGame')
            }
        }
    }

    $requiresForgeStopFirst = $false
    if (Test-TbgProperty -Object $contract -Name 'requiresForgeStopFirst') {
        $requiresForgeStopFirst = ConvertTo-TbgBoolean (Get-TbgPropertyValue -Object $contract -Name 'requiresForgeStopFirst')
    }
    $commandText = [string](Get-TbgPropertyValue -Object $InputObject -Name 'commandText' -Default '')
    if (Test-TbgPatternMatch -Text $commandText -Patterns $requiresStopPatterns) { $requiresForgeStopFirst = $true }

    $artifactPaths = New-Object System.Collections.Generic.List[string]
    Add-TbgUniqueString -List $artifactPaths -Values @(Get-TbgPropertyValue -Object $InputObject -Name 'artifacts' -Default @())
    Add-TbgUniqueString -List $artifactPaths -Values @(Get-TbgPropertyValue -Object $contract -Name 'requiredArtifacts' -Default @())
    $requiredByContract = Get-TbgPropertyValue -Object $evidencePolicy -Name 'requiredArtifactsByContract'
    Add-TbgUniqueString -List $artifactPaths -Values @(Get-TbgMapValues -Map $requiredByContract -Key $ProfileId)

    $resultPath = [string](Get-TbgPropertyValue -Object $contract -Name 'resultPath' -Default '')
    if ([string]::IsNullOrWhiteSpace($resultPath)) {
        $resultCandidates = @($artifactPaths | Where-Object { $_ -like '*.result.json' } | Select-Object -First 1)
        if ($resultCandidates.Count -gt 0) { $resultPath = [string]$resultCandidates[0] }
    }
    if ([string]::IsNullOrWhiteSpace($resultPath)) {
        $resultPattern = [string](Get-TbgPropertyValue -Object $reportingPolicy -Name 'resultPathPattern' -Default 'artifacts/latest/{profileId}.result.json')
        $resultPath = $resultPattern.Replace('{profileId}', $ProfileId).Replace('{workflowId}', $workflowId)
    }
    Add-TbgUniqueString -List $artifactPaths -Values @($resultPath)

    $reportCandidates = @($artifactPaths | Where-Object { $_ -like '*.report.md' } | Select-Object -First 1)
    if ($reportCandidates.Count -gt 0) {
        $reportPath = [string]$reportCandidates[0]
    }
    else {
        $reportPattern = [string](Get-TbgPropertyValue -Object $reportingPolicy -Name 'reportPathPattern' -Default 'artifacts/latest/{profileId}.report.md')
        $reportPath = $reportPattern.Replace('{profileId}', $ProfileId).Replace('{workflowId}', $workflowId)
    }

    $runtimeByContract = Get-TbgPropertyValue -Object $runtimePolicy -Name 'allowedRuntimeByContract'
    $runtimeSurfaces = @(Get-TbgMapValues -Map $runtimeByContract -Key $ProfileId)
    $runtimeAllowed = ConvertTo-TbgBoolean (Get-TbgPropertyValue -Object $runtimePolicy -Name 'defaultRuntimeAllowed' -Default $false)
    if ($runtimeSurfaces.Count -gt 0) { $runtimeAllowed = $true }
    if ($requiresInactiveRuntime -or (Test-TbgProperty -Object $contract -Name 'runtimeCertPath')) { $runtimeAllowed = $true }

    $proofLevel = [string](Get-TbgPropertyValue -Object $contract -Name 'proofLevel' -Default '')
    if ([string]::IsNullOrWhiteSpace($proofLevel)) {
        if ($runtimeAllowed) {
            $proofLevel = [string](Get-TbgPropertyValue -Object $reportingPolicy -Name 'runtimeProofLevel' -Default 'runtime_contract')
        }
        else {
            $proofLevel = [string](Get-TbgPropertyValue -Object $reportingPolicy -Name 'defaultProofLevel' -Default 'static_harness')
        }
    }

    $validationMode = [string](Get-TbgPropertyValue -Object $contract -Name 'validationMode' -Default '')
    if ([string]::IsNullOrWhiteSpace($validationMode)) {
        if ($runtimeAllowed) {
            $validationMode = [string](Get-TbgPropertyValue -Object $reportingPolicy -Name 'runtimeValidationMode' -Default 'contract_and_runtime')
        }
        else {
            $validationMode = [string](Get-TbgPropertyValue -Object $reportingPolicy -Name 'defaultValidationMode' -Default 'offline')
        }
    }

    $blockedReason = [string](Get-TbgPropertyValue -Object $InputObject -Name 'blockedReason' -Default '')
    $nextPatchHint = [string](Get-TbgPropertyValue -Object $InputObject -Name 'nextPatchHint' -Default '')
    if (-not [string]::IsNullOrWhiteSpace($blockedReason) -and [string]::IsNullOrWhiteSpace($nextPatchHint)) {
        $blockers = Get-TbgPropertyValue -Object $contract -Name 'blockers'
        $nextPatchHint = [string](Get-TbgPropertyValue -Object $blockers -Name $blockedReason -Default '')
    }

    $contractScope = Get-TbgPropertyValue -Object $contract -Name 'scope'
    $rowKind = Get-TbgRowType -InputObject $InputObject -RequestedType $RowType
    $context = [pscustomobject][ordered]@{
        schema = 'tbg.harness.effective-policy-context.v1'
        profileId = $ProfileId
        workflowId = $workflowId
        policyId = [string](Get-TbgPropertyValue -Object $reportingPolicy -Name 'id' -Default 'effective-policy-english')
        policyIds = @(
            [string](Get-TbgPropertyValue -Object $commandPolicy -Name 'schema' -Default 'command-safety'),
            [string](Get-TbgPropertyValue -Object $filePolicy -Name 'schema' -Default 'file-safety'),
            [string](Get-TbgPropertyValue -Object $runtimePolicy -Name 'schema' -Default 'runtime-scope'),
            [string](Get-TbgPropertyValue -Object $evidencePolicy -Name 'schema' -Default 'evidence-gates')
        )
        lane = [string](Get-TbgPropertyValue -Object $contract -Name 'lane' -Default (Get-TbgPropertyValue -Object $reportingPolicy -Name 'lane' -Default 'harness/reporting/english-renderer'))
        rowType = $rowKind
        requiresInactiveRuntime = $requiresInactiveRuntime
        requiresForgeStopFirst = $requiresForgeStopFirst
        allowedCommands = @($allowedCommands)
        deniedCommands = @($deniedCommands)
        allowedCommandPatterns = @($allowedCommands)
        deniedCommandPatterns = @($deniedCommands)
        requiresForgeStopFirstPatterns = @($requiresStopPatterns)
        allowedScope = @(Get-TbgPropertyValue -Object $contractScope -Name 'allowed' -Default @())
        forbiddenScope = @(Get-TbgPropertyValue -Object $contractScope -Name 'forbidden' -Default @())
        runtimeAllowed = $runtimeAllowed
        runtimeSurfaces = @($runtimeSurfaces)
        resultPath = $resultPath
        reportPath = $reportPath
        artifactPaths = @($artifactPaths)
        proofLevel = $proofLevel
        blockedReason = $blockedReason
        nextPatchHint = $nextPatchHint
        validationMode = $validationMode
        validationCommands = @(Get-TbgPropertyValue -Object $contract -Name 'validationCommands' -Default @())
        terminalStates = @(Get-TbgPropertyValue -Object $contract -Name 'terminalStates' -Default (Get-TbgPropertyValue -Object $contract -Name 'validVerdicts' -Default @()))
        ciSurfacePaths = @(Get-TbgPropertyValue -Object $reportingPolicy -Name 'ciSurfacePaths' -Default @())
        sourceFiles = @($sourceFiles)
        consumerSurfaces = @(Get-TbgPropertyValue -Object $reportingPolicy -Name 'consumerSurfaces' -Default @())
        handoff = [pscustomobject][ordered]@{
            machineResultPath = $resultPath
            englishReportPath = $reportPath
            carries = @(Get-TbgPropertyValue -Object $reportingPolicy -Name 'handoffFields' -Default @('effectivePolicy', 'englishSummary', 'sourceFiles', 'consumerSurfaces', 'blockedReason', 'nextPatchHint'))
            sequence = @(Get-TbgPropertyValue -Object $reportingPolicy -Name 'runtimeTestHandoffSequence' -Default @('workspace-decision', 'effective-policy-context', 'linked-english-and-json-result'))
        }
        action = [string](Get-TbgPropertyValue -Object $InputObject -Name 'action' -Default '')
        hook = [string](Get-TbgPropertyValue -Object $InputObject -Name 'hook' -Default '')
        status = [string](Get-TbgPropertyValue -Object $InputObject -Name 'status' -Default '')
        verdict = [string](Get-TbgPropertyValue -Object $InputObject -Name 'verdict' -Default '')
        decision = [string](Get-TbgPropertyValue -Object $InputObject -Name 'decision' -Default '')
        commandText = $commandText
        pathText = [string](Get-TbgPropertyValue -Object $InputObject -Name 'pathText' -Default '')
        reason = [string](Get-TbgPropertyValue -Object $InputObject -Name 'reason' -Default '')
        findings = @(Get-TbgPropertyValue -Object $InputObject -Name 'findings' -Default @())
        missingPrereqs = @(Get-TbgPropertyValue -Object $InputObject -Name 'missingPrereqs' -Default @())
        reviewDecision = [string](Get-TbgPropertyValue -Object $InputObject -Name 'reviewDecision' -Default '')
        reviewSummary = [string](Get-TbgPropertyValue -Object $InputObject -Name 'reviewSummary' -Default '')
        auditDecision = [string](Get-TbgPropertyValue -Object $InputObject -Name 'auditDecision' -Default '')
        auditFinding = [string](Get-TbgPropertyValue -Object $InputObject -Name 'auditFinding' -Default '')
        summary = [string](Get-TbgPropertyValue -Object $InputObject -Name 'summary' -Default '')
    }

    return $context
}

function ConvertTo-TbgWords {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $value = $Text -replace '[_-]', ' '
    $value = $value -creplace '([a-z0-9])([A-Z])', '$1 $2'
    $value = $value -replace '\bprereqs\b', 'prerequisites'
    return $value.ToLowerInvariant()
}

function ConvertTo-TbgClause {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $value = $Text.Trim()
    $value = $value.TrimEnd('.', '!', '?')
    if ($value -cmatch '^[A-Z][a-z]') {
        $value = $value.Substring(0, 1).ToLowerInvariant() + $value.Substring(1)
    }
    return $value
}

function Complete-TbgSentence {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $value = $Text.Trim()
    if ($value -notmatch '[.!?]$') { $value += '.' }
    return $value
}

function Join-TbgEnglishList {
    param([object[]]$Items)

    $values = @($Items | ForEach-Object { if ($null -ne $_ -and -not [string]::IsNullOrWhiteSpace([string]$_)) { [string]$_ } })
    if ($values.Count -eq 0) { return '' }
    if ($values.Count -eq 1) { return $values[0] }
    if ($values.Count -eq 2) { return "$($values[0]) and $($values[1])" }
    return "$(($values[0..($values.Count - 2)] -join ', ')), and $($values[-1])"
}

function Get-TbgStatePhrase {
    param([string]$State)

    switch ($State.ToLowerInvariant()) {
        'pass' { return 'passed' }
        'ready' { return 'is ready' }
        'blocked' { return 'was blocked' }
        'blocked_by_policy' { return 'was blocked by policy' }
        'fail' { return 'failed' }
        'failed' { return 'failed' }
        'missing_prereqs' { return 'is missing prerequisites' }
        'repo_invalid' { return 'reported an invalid repository' }
        default {
            $words = ConvertTo-TbgWords -Text $State
            if ([string]::IsNullOrWhiteSpace($words)) { return 'reported no terminal state' }
            return "reported $words"
        }
    }
}

function ConvertTo-TbgPolicyEnglish {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][object]$Context
    )

    process {
        $schema = [string](Get-TbgPropertyValue -Object $Context -Name 'schema' -Default '')
        if ($schema -ne 'tbg.harness.effective-policy-context.v1') {
            throw "Unsupported effective policy context schema: $schema"
        }

        $profileId = [string](Get-TbgPropertyValue -Object $Context -Name 'profileId')
        $workflowId = [string](Get-TbgPropertyValue -Object $Context -Name 'workflowId' -Default $profileId)
        $rowType = [string](Get-TbgPropertyValue -Object $Context -Name 'rowType' -Default 'profile')
        $sentences = New-Object System.Collections.Generic.List[string]

        switch ($rowType.ToLowerInvariant()) {
            'profile' {
                $sentences.Add("The workflow uses the $profileId profile.")
            }
            'workflow-contract' {
                $sentences.Add("The $workflowId workflow contract uses the $profileId profile.")
            }
            'review' {
                $decision = ConvertTo-TbgWords -Text ([string](Get-TbgPropertyValue -Object $Context -Name 'reviewDecision' -Default 'recorded'))
                $summary = ConvertTo-TbgClause -Text ([string](Get-TbgPropertyValue -Object $Context -Name 'reviewSummary' -Default ''))
                $text = "The review for the $profileId profile was $decision"
                if (-not [string]::IsNullOrWhiteSpace($summary)) { $text += " because $summary" }
                $sentences.Add((Complete-TbgSentence -Text $text))
            }
            'policy-audit' {
                $decision = ConvertTo-TbgWords -Text ([string](Get-TbgPropertyValue -Object $Context -Name 'auditDecision' -Default 'recorded'))
                $finding = ConvertTo-TbgClause -Text ([string](Get-TbgPropertyValue -Object $Context -Name 'auditFinding' -Default ''))
                $text = "The policy audit for the $profileId profile was $decision"
                if (-not [string]::IsNullOrWhiteSpace($finding)) { $text += " because $finding" }
                $sentences.Add((Complete-TbgSentence -Text $text))
            }
            { $_ -in @('command-safety', 'file-safety') } {
                $hook = [string](Get-TbgPropertyValue -Object $Context -Name 'hook' -Default $rowType)
                $policyName = (ConvertTo-TbgWords -Text $hook)
                $decision = [string](Get-TbgPropertyValue -Object $Context -Name 'decision' -Default 'ask')
                $verb = 'held the request for review'
                if ($decision -eq 'allow') { $verb = 'allowed' }
                elseif ($decision -eq 'deny') { $verb = 'denied' }
                $subject = [string](Get-TbgPropertyValue -Object $Context -Name 'commandText' -Default '')
                if ([string]::IsNullOrWhiteSpace($subject)) {
                    $subject = [string](Get-TbgPropertyValue -Object $Context -Name 'pathText' -Default 'the request')
                }
                $reason = ConvertTo-TbgClause -Text ([string](Get-TbgPropertyValue -Object $Context -Name 'reason' -Default ''))
                $text = "The $policyName policy $verb $subject"
                if (-not [string]::IsNullOrWhiteSpace($reason)) { $text += " because $reason" }
                $sentences.Add((Complete-TbgSentence -Text $text))
            }
            default {
                $action = [string](Get-TbgPropertyValue -Object $Context -Name 'action' -Default '')
                if ([string]::IsNullOrWhiteSpace($action)) { $action = $workflowId }
                $status = [string](Get-TbgPropertyValue -Object $Context -Name 'status' -Default '')
                $verdict = [string](Get-TbgPropertyValue -Object $Context -Name 'verdict' -Default '')
                $state = $status
                if ([string]::IsNullOrWhiteSpace($state)) { $state = $verdict }
                $sentences.Add((Complete-TbgSentence -Text "The $action result for the $profileId profile $(Get-TbgStatePhrase -State $state)"))
                if (-not [string]::IsNullOrWhiteSpace($status) -and -not [string]::IsNullOrWhiteSpace($verdict) -and $verdict -notin @('PASS', 'BLOCKED', 'FAIL')) {
                    $sentences.Add((Complete-TbgSentence -Text "It recorded the $(ConvertTo-TbgWords -Text $verdict) verdict"))
                }
                $summary = ConvertTo-TbgClause -Text ([string](Get-TbgPropertyValue -Object $Context -Name 'summary' -Default ''))
                if (-not [string]::IsNullOrWhiteSpace($summary)) {
                    $sentences.Add((Complete-TbgSentence -Text "The result reports that $summary"))
                }
            }
        }

        $policyClauses = New-Object System.Collections.Generic.List[string]
        if (ConvertTo-TbgBoolean (Get-TbgPropertyValue -Object $Context -Name 'requiresInactiveRuntime' -Default $false)) {
            $policyClauses.Add('requires inactive runtime state before validation')
        }
        elseif ([string](Get-TbgPropertyValue -Object $Context -Name 'proofLevel' -Default '') -like 'static*') {
            $policyClauses.Add('uses static harness proof without claiming live runtime evidence')
        }
        if (ConvertTo-TbgBoolean (Get-TbgPropertyValue -Object $Context -Name 'requiresForgeStopFirst' -Default $false)) {
            $policyClauses.Add('requires ForgeStop before runtime-affecting commands')
        }
        $resultPath = [string](Get-TbgPropertyValue -Object $Context -Name 'resultPath' -Default '')
        if (-not [string]::IsNullOrWhiteSpace($resultPath)) {
            $policyClauses.Add("writes its machine result to $resultPath")
        }
        $validationMode = ConvertTo-TbgWords -Text ([string](Get-TbgPropertyValue -Object $Context -Name 'validationMode' -Default ''))
        if (-not [string]::IsNullOrWhiteSpace($validationMode)) {
            $policyClauses.Add("uses $validationMode validation")
        }
        if ($policyClauses.Count -gt 0) {
            $subject = 'The effective policy'
            if ($rowType -in @('profile', 'workflow-contract')) { $subject = 'It' }
            $sentences.Add((Complete-TbgSentence -Text "$subject $(Join-TbgEnglishList -Items @($policyClauses))"))
        }

        $blockedReason = ConvertTo-TbgClause -Text ([string](Get-TbgPropertyValue -Object $Context -Name 'blockedReason' -Default ''))
        if (-not [string]::IsNullOrWhiteSpace($blockedReason)) {
            $sentences.Add((Complete-TbgSentence -Text "The workflow is blocked because $blockedReason"))
        }

        $missingPrereqs = @(Get-TbgPropertyValue -Object $Context -Name 'missingPrereqs' -Default @())
        if ($missingPrereqs.Count -gt 0) {
            $missing = Join-TbgEnglishList -Items $missingPrereqs
            $sentences.Add((Complete-TbgSentence -Text "The result is missing the following prerequisites: $missing"))
        }

        $nextPatchHint = ConvertTo-TbgClause -Text ([string](Get-TbgPropertyValue -Object $Context -Name 'nextPatchHint' -Default ''))
        if (-not [string]::IsNullOrWhiteSpace($nextPatchHint)) {
            if ($nextPatchHint -match '^(run|inspect|fix|keep|retry|patch|wait|rerun|review)\s') {
                $sentences.Add((Complete-TbgSentence -Text "The next agent should $nextPatchHint"))
            }
            else {
                $sentences.Add((Complete-TbgSentence -Text "The next agent should use this patch guidance: $nextPatchHint"))
            }
        }

        return (@($sentences) -join ' ')
    }
}

function Write-TbgPolicyReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$ResultObject,
        [Parameter(Mandatory = $true)][string]$JsonPath,
        [string]$MarkdownPath = '',
        [string]$ProfileId = '',
        [string]$RowType = 'auto',
        [string]$RepoRoot = '',
        [AllowNull()][object]$Context = $null,
        [string]$Title = ''
    )

    $root = Resolve-TbgRepoRoot -RepoRoot $RepoRoot
    if ($null -eq $Context) {
        $Context = Get-TbgEffectivePolicyContext -ProfileId $ProfileId -InputObject $ResultObject -RowType $RowType -RepoRoot $root
    }
    $english = ConvertTo-TbgPolicyEnglish -Context $Context

    $ResultObject | Add-Member -NotePropertyName 'effectivePolicy' -NotePropertyValue $Context -Force
    $ResultObject | Add-Member -NotePropertyName 'englishSummary' -NotePropertyValue $english -Force
    $json = $ResultObject | ConvertTo-Json -Depth 30

    $jsonParent = Split-Path -Parent $JsonPath
    if (-not [string]::IsNullOrWhiteSpace($jsonParent)) {
        New-Item -ItemType Directory -Force -Path $jsonParent | Out-Null
    }
    Set-Content -LiteralPath $JsonPath -Value $json -Encoding UTF8

    if ([string]::IsNullOrWhiteSpace($MarkdownPath)) {
        $MarkdownPath = $JsonPath -replace '\.result\.json$', '.report.md'
        if ($MarkdownPath -eq $JsonPath) { $MarkdownPath = $JsonPath -replace '\.json$', '.report.md' }
        if ($MarkdownPath -eq $JsonPath) { $MarkdownPath = "$JsonPath.report.md" }
    }
    $markdownParent = Split-Path -Parent $MarkdownPath
    if (-not [string]::IsNullOrWhiteSpace($markdownParent)) {
        New-Item -ItemType Directory -Force -Path $markdownParent | Out-Null
    }

    if ([string]::IsNullOrWhiteSpace($Title)) {
        $Title = [string](Get-TbgPropertyValue -Object $ResultObject -Name 'action' -Default '')
        if ([string]::IsNullOrWhiteSpace($Title)) { $Title = [string](Get-TbgPropertyValue -Object $ResultObject -Name 'hook' -Default 'TBG policy report') }
    }
    $markdown = @(
        "# $Title",
        '',
        $english,
        '',
        '## Raw JSON (secondary)',
        '',
        '```json',
        $json,
        '```'
    ) -join "`r`n"
    Set-Content -LiteralPath $MarkdownPath -Value $markdown -Encoding UTF8

    return $json
}

Export-ModuleMember -Function Get-TbgEffectivePolicyContext, ConvertTo-TbgPolicyEnglish, Write-TbgPolicyReport
