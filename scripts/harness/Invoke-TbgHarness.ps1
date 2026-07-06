param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("GetContext", "TestReadiness", "ValidateCommand", "ValidateFile", "ValidateWorkflow", "ValidateDone")]
    [string]$Action,
    [string]$ContractId = "local-mcp-code-intelligence",
    [string]$CommandText = "",
    [string]$PathText = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

switch ($Action) {
    "GetContext" {
        & (Join-Path $scriptDir "Get-TbgHarnessContext.ps1") -Json
    }
    "TestReadiness" {
        & (Join-Path $scriptDir "Test-TbgHarnessReadiness.ps1") -ContractId $ContractId
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
