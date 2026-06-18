# Sprint 000A wrapper — calls install-mod.ps1 with log check.
& (Join-Path $PSScriptRoot 'install-mod.ps1') -CheckLog @args
