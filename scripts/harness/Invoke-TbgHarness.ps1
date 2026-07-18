param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("GetContext", "GetEffectivePolicy", "RenderEnglish", "ResolveWorkspace", "TestReadiness", "TestEnglishRenderer", "TestWorkspace", "ValidateCommand", "ValidateFile", "ValidateWorkflow", "ValidateDone")]
    [string]$Action,
    [string]$ContractId = "local-mcp-code-intelligence",
    [string]$CommandText = "",
    [string]$PathText = "",
    [string]$PrimaryRepo = "",
    [string]$TargetBranch = "",
    [int]$FoundationPr = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

switch ($Action) {
    "GetContext" {
        & (Join-Path $scriptDir "Get-TbgHarnessContext.ps1") -ContractId $ContractId -Json
    }
    "GetEffectivePolicy" {
        & (Join-Path $scriptDir "Get-TbgEffectivePolicyContext.ps1") -ProfileId $ContractId -Json
    }
    "RenderEnglish" {
        & (Join-Path $scriptDir "ConvertTo-TbgPolicyEnglish.ps1") -ProfileId $ContractId
    }
    "ResolveWorkspace" {
        if ([string]::IsNullOrWhiteSpace($TargetBranch)) {
            $TargetBranch = (& git branch --show-current).Trim()
        }
        & (Join-Path $scriptDir "Resolve-TbgSprintWorkspace.ps1") -PrimaryRepo $PrimaryRepo -TargetBranch $TargetBranch -FoundationPr $FoundationPr
    }
    "TestReadiness" {
        & (Join-Path $scriptDir "Test-TbgHarnessReadiness.ps1") -ContractId $ContractId
    }
    "TestEnglishRenderer" {
        & (Join-Path $scriptDir "Test-TbgEnglishRenderer.ps1")
    }
    "TestWorkspace" {
        & (Join-Path $scriptDir "Test-TbgSprintWorkspace.ps1")
    }
    "ValidateCommand" {
        if ([string]::IsNullOrWhiteSpace($CommandText)) { throw "-CommandText is required for ValidateCommand." }
        & (Join-Path $scriptDir "Test-TbgCommandSafety.ps1") -ContractId $ContractId -CommandText $CommandText
    }
    "ValidateFile" {
        if ([string]::IsNullOrWhiteSpace($PathText)) { throw "-PathText is required for ValidateFile." }
        & (Join-Path $scriptDir "Test-TbgFileSafety.ps1") -ContractId $ContractId -PathText $PathText
    }
    "ValidateWorkflow" {
        & (Join-Path $scriptDir "Test-TbgWorkflowGate.ps1") -ContractId $ContractId
    }
    "ValidateDone" {
        & (Join-Path $scriptDir "Test-TbgDoneGate.ps1") -ContractId $ContractId
    }
}
