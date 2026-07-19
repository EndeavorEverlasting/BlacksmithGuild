# BlacksmithGuild AI Harness Entrypoint

## Fresh-agent sequence

1. Read `AGENTS.md` and the canonical `docs/harness-doctrine.md`.
2. Inspect `.tbg/harness/manifest.json`, `.gitignore`, current Git/worktree/PR state, recent branch and PR conventions, and fresh artifact packets.
3. Use `CODEBASE_MAP.md` to locate the smallest relevant product, harness, runtime, or evidence surface.
4. Read `.tbg/skills/manifest.json`, select one primary skill, and load only its required or composed skills.
5. Load the selected skill's workflow contract, authorities, validators, expected artifacts, freshness source, and proof ceiling.
6. Inspect existing tests, validators, scripts, docs, registries, schemas, hooks, and helpers before inventing another surface.
7. Use repository-owned entrypoints and preserve unrelated, unpublished, ignored-evidence, and sibling-worktree state.
8. Run the targeted validator first, then the applicable E2E profile and broader safe checks.
9. Verify produced outputs against the artifact registry and generated-output policy; raw runtime output remains ignored.
10. Emit `tbg.sprint-capsule.v1`, an English/operator report, and exact Git or PR evidence for continuation.

Prompts remain artifacts inside this system; they are not the harness and cannot replace repository mutation, validation, artifacts, or handoff proof.

## Fresh-agent acceptance

A fresh agent passes this entry contract only when it can:

- discover this front door through `.tbg/harness/manifest.json`;
- identify the active repo, branch or worktree, PR or sprint, lane, owned and forbidden scope, expected artifacts, and specified validation order;
- choose one primary skill and the narrowest matching workflow;
- run that workflow's targeted validators and the applicable composed E2E profile;
- avoid destructive cleanup, unscoped runtime mutation, stale proof, secrets, saves, raw logs, and generated runtime junk;
- produce registry-backed artifacts and an English/operator report;
- emit a schema-valid sprint capsule with the final Git or PR state and one exact next command.

`scripts/tbg/Test-TbgHarnessDoctrine.ps1` and `scripts/tbg/Test-TbgEndToEndHarness.ps1` enforce the tracked links in this sequence.

## Existing maturity

BlacksmithGuild already has a product-specialized harness: a v2 skill router, workflow contracts, artifact engine, state envelope, launcher/window identity, game-compatibility gates, repo-floor tooling, stale-PR recovery, and live runtime evidence lanes. The E2E and handoff layer extends those authorities; it does not replace them.

## Runtime observer routing

For a completed external observer run, use `runtime-incident-triage` for crash, process-loss, hang, WER, TaleWorlds, open-span, heartbeat, or observer-gap reconstruction. Use `runtime-evidence-certification` only to classify the bounded incident result's freshness and proof. Observer start/status and owned-lease stop remain under `launcher-lifecycle`; window quarantine remains under `window-lifecycle-runtime`; artifact trigger parsing remains under `local-artifact-engine`.

Triggers are read-only routes, not action authority. Window disappearance is not success, stale logs are not confirmed crashes, process presence is not cleanup authority, `incident_ready` is not live certification, and an observer gap is not negative evidence.

## One-click operator front door

The universal operator front door is `ForgeTest.cmd`. Double-click to run the safe default profile, or use:

```powershell
ForgeTest.cmd list           # list tests and profiles
ForgeTest.cmd status          # show current state
ForgeTest.cmd run             # run default profile
ForgeTest.cmd run --profile default-static  # run a specific profile
ForgeTest.cmd run --test core.skill-routing  # run one test
```

Tests are auto-discovered from `.tbg/harness/test-catalog.d/**/*.test.json`. No front-door edits needed when adding tests.

## Safe default

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\tbg\Invoke-TbgEndToEndValidation.ps1 -Profile default-static
```

The default profile runs the dependency-free and PowerShell contracts plus the existing skill-router validator. It does not launch Bannerlord, install a DLL, write the command inbox, or mutate a save.

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
