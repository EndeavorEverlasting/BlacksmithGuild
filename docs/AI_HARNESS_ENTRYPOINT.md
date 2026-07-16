# BlacksmithGuild AI Harness Entrypoint

## Fresh-agent sequence

1. Read `AGENTS.md`.
2. Read `CODEBASE_MAP.md`.
3. Route the request through `harness/api/agent-routing-manifest.json`.
4. Load only the selected skill and declared capabilities.
5. Inspect current Git/worktree/PR state.
6. Use repository-owned entrypoints.
7. Run targeted validation, then the applicable E2E profile.
8. Emit a machine-readable sprint capsule for continuation.

## Why this harness is product-specific

BlacksmithGuild is not a generic .NET library. It combines:

- a net472 Bannerlord module;
- build and install side effects;
- launch/session lifecycle;
- command inbox and ACK files;
- status and route-cert JSON;
- in-game behavior;
- disposable-save mutation doctrine;
- local-only game binaries and logs.

The harness therefore treats build, install, launch, command, ACK, behavior, persistence, and live certification as separate proof levels.

## Safe default

```powershell
pwsh -NoProfile -File .\scripts\Invoke-TbgHarnessE2E.ps1 -Profile default-static
```

This creates ignored evidence beneath `.local/harness-runs/` and does not launch Bannerlord, install a DLL, write a command inbox, or mutate a save.

## Local build profile

```powershell
pwsh -NoProfile -File .\scripts\Invoke-TbgHarnessE2E.ps1 `
  -Profile local-build `
  -GameFolder 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord'
```

The runner uses `dotnet build ... -c Debug` so the Release install target does not run.

## Live profiles

`read-only-runtime` and `disposable-save-live-cert` are defined but fail closed unless the operator supplies explicit authorization. They are not CI profiles.

A later live runner must use the repository's launcher/session, command inbox, exact ACK, status, behavior, and evidence contracts. It must never infer success from a visible window or process exit alone.

## Handoff

Use `scripts/New-TbgSprintCapsule.ps1` to produce `tbg-sprint-capsule/v1`. The capsule can be consumed by a later agent, AgentSwitchboard, or an explicitly authorized SysAdminSuite tandem lane. Consumers must re-inspect state and cannot exceed BlacksmithGuild's gameplay, save-safety, or runtime authority.
