@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "SUBCOMMAND=%~1"

if "%SUBCOMMAND%"=="" (
    echo Usage: ForgeState.cmd ^<subcommand^>
    echo.
    echo Subcommands:
    echo   status      Show current state summary
    echo   compatibility Show latest Bannerlord compatibility state
    echo   ingest      Ingest sample events into the journal
    echo   route       Resolve actions for pending events
    echo   run         Run reducers and update projections
    echo   reconcile   Run the state reconciler
    echo   rebuild     Full replay rebuild and verify
    echo   doctor      Validate all schemas and registries
    echo   explain     Explain a state object or event
    echo   watch       Watch for changes and re-process
    exit /b 1
)

if "%SUBCOMMAND%"=="status" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%scripts\tbg\Read-TbgJournal.ps1"
    goto :done
)

if "%SUBCOMMAND%"=="compatibility" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%scripts\tbg\Invoke-TbgGameCompatibility.ps1" -Command status
    goto :done
)

if "%SUBCOMMAND%"=="ingest" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%SCRIPT_DIR%scripts\tbg\Write-TbgJournalEvent.ps1' -EventType 'system.generated' -SourceKind 'system' -SourceId 'forge-state' -CorrelationId 'ingest-session' -PayloadSchema 'TbgSystemStatus.v1' -Payload @{status='initialized'}"
    goto :done
)

if "%SUBCOMMAND%"=="route" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%scripts\tbg\Resolve-TbgAction.ps1" -EventType 'user.request' -SourceKind 'system' -SourceId 'forge-state'
    goto :done
)

if "%SUBCOMMAND%"=="run" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%scripts\tbg\Invoke-TbgReducer.ps1"
    goto :done
)

if "%SUBCOMMAND%"=="reconcile" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%scripts\tbg\Invoke-TbgReconciler.ps1"
    goto :done
)

if "%SUBCOMMAND%"=="rebuild" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%scripts\tbg\Build-TbgProjections.ps1"
    goto :done
)

if "%SUBCOMMAND%"=="doctor" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%scripts\tbg\Test-TbgJournal.ps1"
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%scripts\tbg\Test-TbgProviderCatalog.ps1"
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%scripts\tbg\Test-TbgStateEnvelope.ps1"
    goto :done
)

if "%SUBCOMMAND%"=="explain" (
    echo Explain requires a state object or event ID argument.
    echo Usage: ForgeState.cmd explain ^<object-or-event-id^>
    goto :done
)

if "%SUBCOMMAND%"=="watch" (
    echo Watch mode requires an active terminal session.
    echo Use: ForgeState.cmd run ^&^& ForgeState.cmd reconcile in a loop.
    goto :done
)

echo Unknown subcommand: %SUBCOMMAND%
exit /b 1

:done
endlocal
