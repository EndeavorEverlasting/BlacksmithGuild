# Machine-Readable Handoff

BlacksmithGuild emits `tbg.sprint-capsule.v1` for bounded continuation without transferring product authority.

## AgentSwitchboard

AgentSwitchboard may schedule and coordinate the next lane, preserve branch/worktree/commit dependencies, select a compatible agent, and consume the validation/proof ceiling.

It may not override gameplay behavior, save safety, launcher doctrine, runtime certification, merge acceptance, or release authority.

## SysAdminSuite

SysAdminSuite may consume a capsule only for an explicitly authorized tandem operation such as workstation integration, shared harness validation, or evidence transport.

Structural validity alone does not grant readiness. The capsule contains `consumers.sysAdminSuite.ready`, the requested operation, and a reason. SysAdminSuite may not mutate Bannerlord, the module installation, game commands, or saves unless a separate cross-repository workflow grants that exact scope.

## Portability and privacy

The capsule excludes absolute repository, home, game, save, and run-output paths; credentials; provider state; raw logs; save payloads; and generated binaries.

The receiving process must re-inspect Git, worktree, runtime, and artifact freshness before mutation and may not exceed the capsule proof ceiling.

## Generation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\tbg\New-TbgSprintCapsule.ps1 `
  -SprintId harness-foundation `
  -Title 'BlacksmithGuild E2E and handoff foundation' `
  -Lane harness-maturity `
  -Mission 'Add composed validation and machine-readable continuation.' `
  -ProofLevel 'static test' `
  -ProofCeiling 'Repository and CI static-test proof only.' `
  -NextCommand 'git status --short'
```
