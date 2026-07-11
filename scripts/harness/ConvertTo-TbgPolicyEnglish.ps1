param(
    [string]$ProfileId = '',
    [string]$InputPath = '',
    [ValidateSet('auto', 'profile', 'result', 'review', 'policy-audit', 'workflow-contract', 'command-safety', 'file-safety')]
    [string]$RowType = 'auto'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Import-Module (Join-Path $PSScriptRoot 'TbgEffectivePolicy.psm1') -Force

$inputObject = $null
if (-not [string]::IsNullOrWhiteSpace($InputPath)) {
    $resolvedInput = if ([System.IO.Path]::IsPathRooted($InputPath)) { $InputPath } else { Join-Path $repoRoot $InputPath }
    if (-not (Test-Path -LiteralPath $resolvedInput -PathType Leaf)) { throw "Input JSON is missing: $resolvedInput" }
    $inputObject = Get-Content -LiteralPath $resolvedInput -Raw | ConvertFrom-Json
}

$inputSchema = ''
if ($null -ne $inputObject -and $null -ne $inputObject.PSObject.Properties['schema']) {
    $inputSchema = [string]$inputObject.PSObject.Properties['schema'].Value
}
if ($inputSchema -eq 'tbg.harness.effective-policy-context.v1') {
    ConvertTo-TbgPolicyEnglish -Context $inputObject
}
else {
    $context = Get-TbgEffectivePolicyContext -ProfileId $ProfileId -InputObject $inputObject -RowType $RowType -RepoRoot $repoRoot
    ConvertTo-TbgPolicyEnglish -Context $context
}
