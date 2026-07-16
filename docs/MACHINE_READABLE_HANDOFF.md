# Machine-Readable Handoff

BlacksmithGuild emits `tbg-sprint-capsule/v1` for bounded continuation.

## Consumers

### AgentSwitchboard

AgentSwitchboard may:

- schedule or coordinate the next bounded repository lane;
- preserve branch/worktree/commit dependencies;
- use the capsule's validation and proof ceiling;
- route a compatible agent.

It may not override BlacksmithGuild save safety, gameplay behavior, launcher doctrine, certification, or merge authority.

### SysAdminSuite

SysAdminSuite may consume a capsule only for an explicitly authorized tandem workflow, such as workstation/runtime integration or shared harness validation.

A capsule being structurally valid does not mean SysAdminSuite is automatically ready. The `consumers.sysadminsuite` record contains readiness and reason.

SysAdminSuite may not mutate the game, saves, Bannerlord installation, or BlacksmithGuild runtime unless the selected cross-repository workflow explicitly grants that scope.

## Privacy and portability

The capsule excludes:

- absolute repository, home, game, save, and output paths;
- credentials and provider state;
- raw logs and runtime JSON;
- personal save names or contents;
- generated binaries.

The receiving process must re-inspect current Git and runtime state before mutation.

## Generate

```powershell
pwsh -NoProfile -File .\scripts\New-TbgSprintCapsule.ps1 `
  -SprintId harness-foundation `
  -Title 'BlacksmithGuild AI harness foundation' `
  -Lane harness `
  -Mission 'Create schema-backed routing, E2E, and handoff contracts.' `
  -ProofLevel contract-proof `
  -ProofCeiling 'Repository and CI contract proof only.' `
  -NextCommand 'git status --short'
```
