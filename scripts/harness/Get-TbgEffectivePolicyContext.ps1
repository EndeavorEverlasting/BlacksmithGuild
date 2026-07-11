param(
    [string]$ProfileId = '',
    [string]$InputPath = '',
    [ValidateSet('auto', 'profile', 'result', 'review', 'policy-audit', 'workflow-contract', 'command-safety', 'file-safety')]
    [string]$RowType = 'auto',
    [switch]$Json
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

$context = Get-TbgEffectivePolicyContext -ProfileId $ProfileId -InputObject $inputObject -RowType $RowType -RepoRoot $repoRoot
if ($Json) {
    $context | ConvertTo-Json -Depth 30
}
else {
    $context
}
