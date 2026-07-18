param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("SessionStart", "PreBash", "PreFileWrite", "Stop", "RulesProposal")]
    [string]$Hook
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

switch ($Hook) {
    "SessionStart" { & (Join-Path $PSScriptRoot "Write-TbgSessionContext.ps1") }
    "PreBash" { & (Join-Path $PSScriptRoot "Test-TbgBashCommandSafety.ps1") }
    "PreFileWrite" { & (Join-Path $PSScriptRoot "Test-TbgFileWriteSafety.ps1") }
    "Stop" { & (Join-Path $PSScriptRoot "Test-TbgDoneGate.ps1") }
    "RulesProposal" { & (Join-Path $PSScriptRoot "Write-TbgClaudeRulesProposal.ps1") }
}
