# Runtime Observer Certification

```text
[TBG | Sprint 8 | runtime observer live certification and final convergence | branch: cert/runtime-observer-live]
```

## Scope and boundary

- Repository: `EndeavorEverlasting/BlacksmithGuild`
- Exact head tested: `fad0c6b78c6d2c729df3941c67ea0184b5f4e8b6`
- Owned changes: certification runner, certification validator, fixture contract, and this handoff.
- Forbidden scope observed: no observer, span, schema, skill, capability, trigger, or product implementation was changed. No Bannerlord launch/stop/click, command-inbox write, save mutation, process termination, raw-log commit, or sanitized runtime capsule was performed.

## Certification result

The highest completed proof level is **build**. Static fixture validation and the non-Bannerlord Windows smoke portions passed, and Debug produced `BlacksmithGuild.dll` with SHA-256:

```text
b274a144c7e525b19124cfb36da2c8bcabad5e86da2c4e1b0a85e33cd3a9060a
```

The composed Windows smoke did **not** certify incident assembly. `Resolve-TbgRuntimeIncident.ps1` rejected the disposable observer output with `No valid events remain after quarantine.` The certification terminal state is `FAIL_windows_smoke_incident_assembly`. This is an implementation/evidence-boundary defect to resolve in a later, correctly owned observer or assembler sprint; Sprint 8 intentionally does not patch either surface.

Live observation was skipped. No current artifact proved explicit live-runtime authority, an `active_owned` session classification, fresh runtime correlation to this exact head, and operator acceptance. This is a separate fail-closed blocker; no Bannerlord attach was attempted.

## Scenarios and evidence

| Scenario | Result | Ceiling / claim |
|---|---|---|
| Composed static fixtures | passed | `static_test`; no product behavior or live-runtime claim |
| Window hook registration/disposal | passed | `harness`; disposable PowerShell process only |
| Disposable child start/exit plus observer lease | passed | `harness`; `cmd.exe` only |
| Bounded Windows event-log query | passed | `harness`; no unrelated-process attribution |
| Disposable incident assembly | failed | no incident certification; failure recorded |
| Debug build and assembly hash | passed | `build`; build does not prove loaded assembly |
| Live attach/observation | skipped/blocked | no live-runtime, ownership, or operator-acceptance claim |

Ignored local evidence from this run:

- `.local/tbg-runtime-observer-certification/sprint8-20260719/runtime-observer-certification.result.json`
- `.local/tbg-runtime-observer-certification/sprint8-20260719/runtime-observer-certification.report.md`
- `.local/tbg-runtime-observer-certification/sprint8-20260719/windows-smoke/`
- `.local/tbg-e2e-runs/20260719-105541-545/result.json`

No capsule was produced because this run did not observe a Bannerlord session or a runtime failure requiring remote reconstruction.

## Validation

Passed in required order through the Windows smoke attempt:

1. `Test-TbgRuntimeObserverCertification.ps1`
2. `Test-TbgRuntimeEventObservation.ps1`
3. `Test-TbgWindowEventListener.ps1`
4. `Test-TbgGameRuntimeObserver.ps1`
5. `Test-TbgRuntimeSpanInstrumentation.ps1`
6. `Test-TbgRuntimeIncidentAssembler.ps1`
7. `Test-TbgSkillRouting.ps1`
8. `Test-TbgArtifactEngine.ps1`
9. `Invoke-TbgEndToEndValidation.ps1 -Profile default-static`
10. `dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Debug`
11. `Invoke-TbgRuntimeObserverCertification.ps1 -Mode certify ...` — failed at incident assembly as recorded above.

`git diff --check` remains required after the documentation and certification-script changes.

## Next product decision and operator acceptance

1. Assign the observer/incident boundary failure to an owner allowed to change `Start-TbgGameRuntimeObserver.ps1` or `Resolve-TbgRuntimeIncident.ps1`. Preserve the disposable run and determine why its generated event timestamps or declarations are quarantined before attempting live observation.
2. After that fix is independently validated, an operator must provide a fresh, explicit authority artifact stating `authorization=explicit`, `sessionClassification=active_owned`, `operatorAccepted=true`, current `exactHead`, and an unexpired `expiresUtc`.
3. Only then run the bounded read-only observation command below. It must not be used to launch Bannerlord, write a command inbox, or mutate a save:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Invoke-TbgRuntimeObserverCertification.ps1 -Mode certify -AllowLiveRuntime -LiveAuthorityArtifactPath <approved-authority.json>
```

Current exact next command for the observed blocker:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgRuntimeIncidentAssembler.ps1
```
