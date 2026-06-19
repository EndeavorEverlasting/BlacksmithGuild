# Returns $true when Documents forge status indicates a clean PASS suitable for auto-launch.
function Test-ForgeCleanPass {
    param([string]$StatusJsonPath)

    if (-not (Test-Path -LiteralPath $StatusJsonPath)) {
        Write-Host "Forge status file not found: $StatusJsonPath" -ForegroundColor Yellow
        return $false
    }

    $status = Get-Content -LiteralPath $StatusJsonPath -Raw | ConvertFrom-Json
    $overall = [string]$status.overall
    Write-Host "Forge result: $overall" -ForegroundColor $(switch ($overall) { 'PASS' { 'Green' } 'WARN' { 'Yellow' } 'FAIL' { 'Red' } default { 'Gray' } })

    if ($overall -ne 'PASS') {
        if ($overall -eq 'WARN') {
            Write-Host 'Install may be blocked or checks reported warnings. Launcher will not be opened.' -ForegroundColor Yellow
        } else {
            Write-Host 'Launcher will not be opened.' -ForegroundColor Yellow
        }
        return $false
    }

    $installStep = @($status.steps | Where-Object { $_.name -eq 'install' })
    if ($installStep.Count -gt 0) {
        $installStatus = [string]$installStep[0].status
        if ($installStatus -eq 'BLOCKED') {
            Write-Host 'Install blocked because Bannerlord is running.' -ForegroundColor Yellow
            Write-Host 'Close Bannerlord, run Forge.cmd again.' -ForegroundColor Yellow
            Write-Host 'Launcher will not be opened.' -ForegroundColor Yellow
            return $false
        }
        if ($installStatus -ne 'PASS') {
            Write-Host "Install step status: $installStatus. Launcher will not be opened." -ForegroundColor Yellow
            return $false
        }
    }

    foreach ($procName in @('Bannerlord', 'TaleWorlds.MountAndBlade.Launcher')) {
        if (Get-Process -Name $procName -ErrorAction SilentlyContinue) {
            Write-Host "Bannerlord is already running ($procName). Launcher will not be opened." -ForegroundColor Yellow
            return $false
        }
    }

    $pendingPath = Join-Path $env:USERPROFILE 'Documents\Mount and Blade II Bannerlord\BlacksmithGuild_PendingReload.json'
    if (-not (Test-Path -LiteralPath $pendingPath)) {
        $csproj = Join-Path (Split-Path -Parent $PSScriptRoot) 'src\BlacksmithGuild\BlacksmithGuild.csproj'
        if ($csproj -match '<GameFolder>([^<]+)</GameFolder>') {
            $blRoot = $Matches[1] -replace '&amp;', '&'
            $pendingPath = Join-Path $blRoot 'BlacksmithGuild_PendingReload.json'
        }
    }
    if (Test-Path -LiteralPath $pendingPath) {
        try {
            $pending = Get-Content -LiteralPath $pendingPath -Raw | ConvertFrom-Json
            if ($pending.blockedByRunningGame -eq $true) {
                Write-Host 'Pending reload: blockedByRunningGame. Close Bannerlord and run Forge.cmd again.' -ForegroundColor Yellow
                Write-Host 'Launcher will not be opened.' -ForegroundColor Yellow
                return $false
            }
        } catch { }
    }

    return $true
}
