# BlacksmithGuild AI Harness Entrypoint

## Fresh-agent sequence

1. Read `AGENTS.md`.
2. Use `CODEBASE_MAP.md` to locate the smallest relevant surface.
3. Read `.tbg/skills/manifest.json` and select one primary skill.
4. Load its workflow contract, authorities, validators, artifacts, and proof ceiling.
5. Inspect current Git/worktree/PR state and fresh artifact packets.
6. Use repository-owned entrypoints.
7. Run targeted validation, then the applicable E2E profile.
8. Emit `tbg.sprint-capsule.v1` for continuation.

## Existing maturity

BlacksmithGuild already has a product-specialized harness: a v2 skill router, workflow contracts, artifact engine, state envelope, launcher/window identity, game-compatibility gates, repo-floor tooling, stale-PR recovery, and live runtime evidence lanes. The E2E and handoff layer extends those authorities; it does not replace them.

## Safe default

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\tbg\Invoke-TbgEndToEndValidation.ps1 -Profile default-static
```

The default profile runs the new dependency-free and PowerShell contracts plus the existing skill-router validator. It does not launch Bannerlord, install a DLL, write the command inbox, or mutate a save.

## Local build

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\tbg\Invoke-TbgEndToEndValidation.ps1 `
  -Profile local-build `
  -GameFolder 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord'
```

The runner uses `dotnet build -c Debug`; the Release install target is not invoked.

## Read-only runtime

`read-only-runtime` requires `-AllowLiveRuntime`. It runs the existing `ForgeAgentStatus.cmd` under a bounded child process and requires a fresh `artifacts/latest/tbg-chat-packet.json`. This proves a current read-only harness refresh, not command ACK or gameplay behavior.

## Disposable-save live certification

The profile is registered but fails closed until a specific workflow contract is supplied. No generic harness flag may authorize an unscoped save mutation.

Discovery uses `.tbg/harness/policies/disposable-save.policy.json` (name patterns + preferred leaves + active pin). Machine-local year-floor authority may exist only under gitignored `.local/disposable-save.operator.json` and must never ship as an end-user default.

## Handoff

`New-TbgSprintCapsule.ps1` emits a path-free capsule to the run root and `artifacts/latest/tbg-sprint-capsule.json`. AgentSwitchboard can coordinate from it. SysAdminSuite readiness remains false unless the operator explicitly authorizes a tandem operation.
